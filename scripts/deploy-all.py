#!/usr/bin/env python3

import os
import subprocess
import sys
import toml
import argparse


# Define colors
YELLOW = "\033[93m"
LIGHT_BLUE = "\033[94m"
GREEN = "\033[92m"
RED = "\033[91m"
GRAY = "\033[90m"
END = "\033[0m"
BOLD = "\033[1m"


def printc(color, string, **kwargs):
    print(f"{color}{string}{END}", **kwargs)


def check_aws_sso_session():
    try:
        # Try to get the user's identity
        subprocess.run(['aws', 'sts', 'get-caller-identity'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except subprocess.CalledProcessError:
        # If the command failed, the user is not logged in
        printc(RED, "You do not have a valid AWS SSO session. Please run 'aws sso login' and try again.")
        return False

    # If the command succeeded, the user is logged in
    return True


def deploy_repo(repo, parent_dir, dry_run, verbose):
    repo_name = repo['name']
    repo_path = os.path.join(parent_dir, repo_name)
    open_source = repo.get('open_source')
    credits = repo.get('credits')
    url = repo.get('url')
    deploy = repo.get('deploy', True)

    printc(LIGHT_BLUE, "")
    printc(LIGHT_BLUE, "")
    printc(LIGHT_BLUE, "================================================================================================")
    printc(LIGHT_BLUE, "")
    printc(LIGHT_BLUE, f"        Deploying {repo_name}...")

    if open_source:
        printc(GRAY, '')      
        printc(GRAY, f"        Forked from open source:")      
    if credits:
        printc(GRAY, f"        - {credits}")      
    if url:
        printc(GRAY, f"        - {url}")      

    printc(LIGHT_BLUE, "")
    printc(LIGHT_BLUE, "------------------------------------------------------------------------------------------------")
    printc(LIGHT_BLUE, "")

    if not deploy:
        printc(GREEN, 'Deployment suppressed.')
        printc(GREEN, '')
        return True

    # Save the original working directory
    original_cwd = os.getcwd()

    try:
        # Check if the repo exists
        if not os.path.exists(repo_path):
            printc(RED, f"Repo {repo_path} does not exist.")
            return False
        
        print()
        repo_name = repo_path.split('/')[-1]
        printc(LIGHT_BLUE, f"Processing {repo_name}...")

        # Check if the deploy script exists
        deploy_script = os.path.join(repo_path, 'scripts', 'deploy.py')
        if not os.path.exists(deploy_script):
            printc(YELLOW, f"This repo has no deploy script. Skipping.")
            return False

        # Check if the config-deploy.toml file exists
        config_deploy = os.path.join(repo_path, 'config-deploy.toml')
        if not os.path.exists(config_deploy):
            printc(YELLOW, f"This repo has no config-deploy.toml file. Skipping.")
            return False

        # Change the current working directory to the repo
        os.chdir(repo_path)

        # Execute the deploy script
        printc(LIGHT_BLUE + BOLD, f"Deploying repo {repo_path}...")
        subprocess.run(['python3', deploy_script] + (['--dry-run'] if dry_run else []) + (['--verbose'] if verbose else []), check=True)
    except Exception as e:
        printc(RED, f"An error occurred while deploying repo {repo_path}: {str(e)}")
        return False
    finally:
        # Restore the original working directory
        os.chdir(original_cwd)

    return True


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("app", nargs='?', default=None, help="The application to deploy.")
    parser.add_argument("--dry-run", action="store_true", help="Perform a dry run of the deployment.")
    parser.add_argument("--verbose", action="store_true", help="Print verbose output.")
    args = parser.parse_args()

    # Check that the user is logged in
    if not check_aws_sso_session():
        return

    # Print header
    printc(LIGHT_BLUE + BOLD, "Deploying your Delegat AB application...")

    # Get the parent directory from the CWD
    current_dir = os.getcwd()
    parent_dir = os.path.dirname(current_dir)

    # Get the argument and convert it to lowercase
    if args.app:
        app = args.app.lower()
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

    # Load configuration file based on the argument
    config_file = f"apps/{app}/repos-local.toml"
    if not os.path.exists(config_file):
        config_file = f"apps/{app}/repos.toml"
        if not os.path.exists(config_file):
            printc(RED, f"Configuration file {config_file} does not exist.")
            return

    if args.verbose:
        printc(GRAY, f"Using repo file {config_file}...")

    config = toml.load(config_file)

    # Deploy the repos
    for repo in config['repos']:
        if not deploy_repo(repo, parent_dir, args.dry_run, args.verbose):
            printc(RED, "Deployment failed. Stopping further deployments.")
            break


if __name__ == '__main__':
    main()
