#!/usr/bin/env python3

"""
OpenSecOps Foundation Environment Initialization Script

This script initializes a new OpenSecOps Foundation development environment by discovering
and setting up all Foundation components for development and deployment.

What it does:
- Discovers all Foundation-* repositories in the parent directory
- Runs git setup (./setup) for each component to configure dual-repository workflow
- Distributes latest deployment scripts via refresh mechanism
- Validates component configurations and dependencies
- Prepares the environment for unified deployment via deploy-all

This is typically run once when setting up a new development environment or when
onboarding new Foundation components to ensure they're properly integrated with
the deployment system.

Usage:
  ./init

The script provides a foundation-wide initialization that ensures all components
are ready for development and deployment within the OpenSecOps ecosystem.
"""

import os
import subprocess
import sys


# Define colors
YELLOW = "\033[93m"
LIGHT_BLUE = "\033[94m"
GREEN = "\033[92m"
RED = "\033[91m"
END = "\033[0m"
BOLD = "\033[1m"

def printc(color, string, **kwargs):
    print(f"{color}{string}{END}", **kwargs)


def check_software(software):
    try:
        subprocess.check_call([software, '--version'], stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
    except (FileNotFoundError, subprocess.CalledProcessError):
        return False
    return True


def get_required_python_version():
    with open('.python-version', 'r') as file:
        return file.read().strip()


def setup_python_environment(required_version):
    installed_versions = subprocess.check_output(['pyenv', 'versions', '--bare'], encoding='utf-8').splitlines()
    if required_version not in installed_versions:
        printc(YELLOW, f"Installing Python {required_version}... ", end="")
        subprocess.check_call(['pyenv', 'install', required_version])
    subprocess.check_call(['pyenv', 'local', required_version])


def _installer_root():
    # init.py lives at <Installer>/scripts/init.py; requirements.{in,txt}
    # live at <Installer>/. Resolve symlinks so this works whether init.py
    # is invoked via the top-level `./init` symlink or via `scripts/init.py`.
    return os.path.dirname(os.path.dirname(os.path.realpath(__file__)))


def _load_verifier():
    # Late-import the shared verifier so that sigstore (a pinned Python dep)
    # can be installed by install_python_packages() first. Returns the
    # verify_release function or None if import fails.
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        '_verify_release',
        os.path.join(os.path.dirname(os.path.realpath(__file__)), '_verify_release.py'))
    mod = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(mod)
    except ImportError:
        return None
    return mod.verify_release


def verify_installer_self(verifier):
    # Verify that the Installer's own checkout corresponds to a signed
    # GitHub Release. Closes the bootstrap gap: a customer who pulls a
    # tampered Installer would have their malicious init.py refuse to
    # proceed at this point (assuming the attacker hasn't also stripped
    # this check out — TOFU applies to first install only; every
    # subsequent update is verified before doing anything destructive).
    return verifier("Installer", repo_dir=_installer_root())


def _read_direct_deps_with_versions():
    """Return [(name, pinned_version), ...] for the Installer's direct deps.

    Direct-dep *names* come from requirements.in (one transitive layer below
    the boto3.in include). *Versions* come from the corresponding == pin in
    requirements.txt. Both files are read at customer-install time; their
    bytes are part of the cloned Installer repo, so no network access is
    needed for this step.
    """
    import re

    root = _installer_root()
    in_path = os.path.join(root, "requirements.in")
    txt_path = os.path.join(root, "requirements.txt")
    boto3_in_path = os.path.join(root, "templates", "boto3.in")

    direct_names = []

    def read_in_file(path):
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                stripped = line.strip()
                if not stripped or stripped.startswith("#"):
                    continue
                if stripped.startswith("-r "):
                    # Resolve relative include from the dir of `path`.
                    nested = os.path.join(os.path.dirname(path), stripped[3:].strip())
                    read_in_file(nested)
                    continue
                # Strip version specifiers / comments to get the bare name.
                name = re.split(r"[<>=!~;\s#]", stripped, 1)[0]
                if name and name not in direct_names:
                    direct_names.append(name)

    read_in_file(in_path)

    # Map name → pinned version from requirements.txt (only the direct
    # deps; transitives are present too but we don't display them).
    pinned = {}
    pin_re = re.compile(r"^([A-Za-z0-9._-]+)==(\S+?)\s*(?:\\)?\s*$")
    with open(txt_path, "r", encoding="utf-8") as f:
        for line in f:
            m = pin_re.match(line)
            if m:
                pinned[m.group(1).lower()] = m.group(2)

    return [(name, pinned.get(name.lower(), "?")) for name in direct_names]


def _all_direct_deps_at_pinned_versions(direct_deps):
    """Fast-path check: are all direct deps already importable at the
    exact pinned versions? Lets repeated `./init` runs skip the pip
    invocation when nothing has changed.
    """
    try:
        from importlib.metadata import version as get_version, PackageNotFoundError
    except ImportError:
        return False
    for name, pinned_version in direct_deps:
        try:
            if get_version(name) != pinned_version:
                return False
        except PackageNotFoundError:
            return False
    return True


def install_python_packages():
    """Install the Installer's pinned, hash-verified runtime deps.

    Deps + their hashes live in <Installer>/requirements.txt (committed,
    generated by the maintainer via compile-requirements.sh from
    requirements.in). The customer's pyenv-managed Python receives them
    via `pip install --require-hashes -r requirements.txt`, so
    tampering or PyPI substitution is detected at install time.
    """
    direct_deps = _read_direct_deps_with_versions()

    printc(GREEN, "Pinned, hash-verified Installer dependencies:")
    for name, version in direct_deps:
        printc(GREEN, f"  {name}=={version}")

    if _all_direct_deps_at_pinned_versions(direct_deps):
        printc(GREEN, "  ... already installed at pinned versions ✓")
        return

    req_path = os.path.join(_installer_root(), "requirements.txt")
    printc(GREEN, "  ... installing (hash-verified)... ", end="")
    subprocess.check_call(
        [sys.executable, "-m", "pip", "install",
         "--require-hashes", "-r", req_path],
        stdout=subprocess.DEVNULL,
    )
    printc(GREEN, "OK")

def clone_repo(url, path, name):
    if os.path.exists(path):
        printc(YELLOW, f"\rUpdating repo {name}... ", end="")
        # Get current commit hash before pulling
        before_pull = subprocess.run(['git', '-C', path, 'rev-parse', 'HEAD'], capture_output=True, text=True)
        before_commit_hash = before_pull.stdout.strip()
        subprocess.run(['git', '-C', path, 'pull', '--quiet'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        # Get current commit hash after pulling
        after_pull = subprocess.run(['git', '-C', path, 'rev-parse', 'HEAD'], capture_output=True, text=True)
        after_commit_hash = after_pull.stdout.strip()
        if before_commit_hash != after_commit_hash:
            printc(LIGHT_BLUE, "Changes")
        else:
            printc(GREEN, "No changes")
    else:
        printc(YELLOW, f"\rDownloading repo {path}... ", end="")
        subprocess.run(['git', 'clone', url, path, '--quiet'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        printc(GREEN, "OK")

     # Dynamically obtain the current working directory before any changes
    original_dir = os.getcwd()
    
    try:
        # Change to the repo directory only after successful cloning/updating
        os.chdir(path)
        
        # Check and set up the Python environment for the repo
        required_python_version = get_required_python_version()
        setup_python_environment(required_python_version)
        
        # Install necessary Python packages for the repo
        install_python_packages()
    finally:
        # Always revert to the original working directory
        os.chdir(original_dir)


def main():
    # Print header
    printc(LIGHT_BLUE + BOLD, "Setting up your OpenSecOps client workspace...")

    # Get the parent directory from the CWD
    current_dir = os.getcwd()
    parent_dir = os.path.dirname(current_dir)

    # Get the argument and convert it to lowercase
    if len(sys.argv) > 1:
        app = sys.argv[1].lower()
    else:
        # Check if any repos are installed for SOAR or Foundation
        installed_dirs = os.listdir(parent_dir)
        installed_soar_repos = [d for d in installed_dirs if d.startswith('SOAR')]
        installed_foundation_repos = [d for d in installed_dirs if d.startswith('Foundation')]

        if installed_soar_repos and installed_foundation_repos:
            printc(RED, "Both OpenSecOps SOAR and OpenSecOps Foundation repos are installed.")
            printc(RED, "Please specify 'SOAR' or 'Foundation' as an argument.")
            return
        elif installed_soar_repos:
            app = 'soar'
            printc(LIGHT_BLUE, "Only OpenSecOps SOAR is installed, assuming 'SOAR' is what you want.")
        elif installed_foundation_repos:
            app = 'foundation'
            printc(LIGHT_BLUE, "Only OpenSecOps Foundation is installed, assuming 'Foundation' is what you want.")
        else:
            printc(RED, "No OpenSecOps SOAR or OpenSecOps Foundation repos are installed.")
            printc(RED, "Please specify 'SOAR' or 'Foundation' as an argument.")
            return

    print()

    # Check for necessary software
    necessary_software = ['aws', 'sam', 'pyenv', 'git']
    printc(YELLOW, f"Checking prerequisites ({', '.join(necessary_software)})... ", end="")
    not_installed = []
    for software in necessary_software:
        if not check_software(software):
            not_installed += software
            printc(RED, f"Please install {software} before running this script.")
    if not_installed:
        return
    else:
        printc(GREEN, "OK")
    print()

    required_python_version = get_required_python_version()
    setup_python_environment(required_python_version)
    install_python_packages()

    # --- Release verification setup ---------------------------------------
    # sigstore was just pip-installed above, so the shared verifier module
    # can now be imported. On first-ever install (no sigstore yet at module
    # load time of init.py), this is the earliest point we can call it.
    verifier = _load_verifier()
    if verifier is None:
        printc(YELLOW,
            "sigstore not available; release verification is unavailable for this run. "
            "Re-run ./init to pick it up.")
    else:
        # Self-verify the Installer's own current checkout. If the customer
        # pulled a tampered Installer, this is where we catch it.
        printc(LIGHT_BLUE, "\nVerifying Installer release signature...")
        if not verify_installer_self(verifier):
            printc(RED, "Installer self-verification FAILED. Refusing to proceed.")
            return

    # We can now load toml
    import toml

    # Load configuration file based on the argument
    config_file = f"apps/{app}/repos.toml"
    if not os.path.exists(config_file):
        printc(RED, f"Configuration file {config_file} does not exist.")
        return

    config = toml.load(config_file)

    # Clone necessary repos, verifying each one's signed release as we go.
    # Eager check here means problems are surfaced at init rather than only
    # at deploy time (deploy.py runs the same verifier just-in-time too).
    base_url = config['GitHub']['source_base_url']
    verify_failures = []
    for repo in config['repos']:
        repo_name = repo['name']
        repo_url = base_url + repo_name + '.git'
        repo_path = os.path.join(parent_dir, repo_name)
        clone_repo(repo_url, repo_path, repo_name)
        if verifier is not None:
            if not verifier(repo_name, repo_dir=repo_path):
                verify_failures.append(repo_name)

    if verify_failures:
        printc(RED,
            f"\n{len(verify_failures)} component(s) failed release verification: "
            f"{', '.join(verify_failures)}")
        printc(RED,
            "Do not run ./deploy in these components until the issue is resolved.")

if __name__ == '__main__':
    main()
