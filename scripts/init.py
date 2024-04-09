#!/usr/bin/env python3

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
        printc(GREEN, "OK")
    subprocess.check_call(['pyenv', 'local', required_version])


def check_package(package):
    try:
        __import__(package)
    except ImportError:
        return False
    return True


def install_package(package):
    subprocess.check_call([sys.executable, "-m", "pip3", "install", package])


def install_python_packages():
    # Check for necessary Python packages
    necessary_packages = ['boto3', 'toml', 'yq']
    for package in necessary_packages:
        printc(YELLOW, f"Checking that {package} is installed... ", end="")
        if not check_package(package):
            install_package(package)
            printc(GREEN, f"{package} is now installed.")
        else:
            printc(GREEN, f"{package} is already installed.")


def clone_repo(url, path):
    if os.path.exists(path):
        printc(YELLOW, f"\rUpdating repo {path}... ", end="")
        subprocess.run(['git', '-C', path, 'pull', '--quiet'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
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
    printc(LIGHT_BLUE + BOLD, "Setting up your Delegat AB client workspace")

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
            printc(RED, "Both Delegat SOAR and Delegat Foundation repos are installed.")
            printc(RED, "Please specify 'SOAR' or 'Foundation' as an argument.")
            return
        elif installed_soar_repos:
            app = 'soar'
            printc(LIGHT_BLUE, "Only Delegat SOAR is installed, assuming 'SOAR' is what you want.")
        elif installed_foundation_repos:
            app = 'foundation'
            printc(LIGHT_BLUE, "Only Delegat Foundation is installed, assuming 'Foundation' is what you want.")
        else:
            printc(RED, "No Delegat SOAR or Delegat Foundation repos are installed.")
            printc(RED, "Please specify 'SOAR' or 'Foundation' as an argument.")
            return

    print()

    # Check for necessary software
    necessary_software = ['aws', 'sam', 'pyenv', 'git']
    for software in necessary_software:
        printc(YELLOW, f"Checking that {software} is installed... ", end="")
        if not check_software(software):
            printc(RED, f"Please install {software} before running this script.")
            return
        printc(GREEN, "OK")

    required_python_version = get_required_python_version()
    setup_python_environment(required_python_version)
    install_python_packages()

    # We can now load toml
    import toml

    # Load configuration file based on the argument
    config_file = f"apps/{app}/repos.toml"
    if not os.path.exists(config_file):
        printc(RED, f"Configuration file {config_file} does not exist.")
        return

    config = toml.load(config_file)

    # Clone necessary repos
    base_url = config['GitHub']['delegat_base_url']
    for repo in config['repos']:
        repo_name = repo['name']
        repo_url = base_url + repo_name + '.git'
        repo_path = os.path.join(parent_dir, repo_name)
        clone_repo(repo_url, repo_path)

if __name__ == '__main__':
    main()
