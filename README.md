# README

This is the installer for OpenSecOps Foundation and OpenSecOps SOAR. It is used to prepare your
workspace, check that you have installed all prerequisites, download all repos required, 
and then build, install, and/or update them.


## Prerequisites

The following software must already be installed on your local computer (MacOS/Linux/Windows):

1. The `zsh` shell
2. The `aws` CLI (https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
3. The AWS `sam` CLI (https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html)
4. `pyenv` (https://github.com/pyenv/pyenv)
5. `git`


## Complete Installation Instructions

Please check out the `docs` directory before you begin, especially:
    * [The Foundation installation manual](docs/Foundation/OpenSecOps%20Foundation%20Installation%20Manual.docx.pdf)
    * [The SOAR installation manual](docs/SOAR/OpenSecOps%20SOAR%20-%20Installation%20Manual.docx.pdf)


## Initialisation
First create a folder on your laptop to contain all OpenSecOps repos. You can call it anything.
We call it OPENSECOPS-CLIENT-FOLDER. Clone this repository into the new folder.

Next `cd` into this repo and type:
```console
./init Foundation
```
or
```console
./init SOAR
```

The script will print something like this:
```console
Setting up your OpenSecOps client workspace

Checking that aws is installed... OK
Checking that sam is installed... OK
Checking that pyenv is installed... OK
Checking that git is installed... OK
Cheching that Python 3.12.2 is installed... Installing Python 3.12.2... OK
Checking that boto3 is installed... boto3 is now installed.
Checking that toml package is installed... toml package is now installed.
Checking that yq package is installed... yq package is now installed.
Downloading repo /Users/john_doe/Documents/Projects/AWS/OPENSECOPS-CLIENT-FOLDER/SOAR-sec-hub-configuration... OK
Downloading repo /Users/john_doe/Documents/Projects/AWS/OPENSECOPS-CLIENT-FOLDER/SOAR-detect-log-buckets... OK
Downloading repo /Users/john_doe/Documents/Projects/AWS/OPENSECOPS-CLIENT-FOLDER/SOAR... OK
...(etc)
```

The operation is idempotent, which means you can repeat it to update all repos, like this:
```console
./init SOAR
```

and get
```console
Setting up your OpenSecOps client workspace

Checking that aws is installed... OK
Checking that sam is installed... OK
Checking that pyenv is installed... OK
Checking that git is installed... OK
Cheching that Python 3.12.2 is installed... OK
Checking that boto3 is installed... OK
Checking that toml package is installed... OK
Checking that yq package is installed... OK
Updating repo SOAR-sec-hub-configuration... OK
Updating repo SOAR-detect-log-buckets... Changes
Updating repo SOAR... OK
```

If you only have one application installed, you can leave out the app name:
```console
./init
```
This will print:
```console
Setting up your OpenSecOps client workspace
Only OpenSecOps SOAR is installed, assuming 'SOAR' is what you want.

Checking that aws is installed... OK
Checking that sam is installed... OK
Checking that pyenv is installed... OK
Checking that git is installed... OK
Cheching that Python 3.12.2 is installed... OK
Checking that boto3 is installed... OK
Checking that toml package is installed... OK
Checking that yq package is installed... OK
Updating repo SOAR-sec-hub-configuration... OK
Updating repo SOAR-detect-log-buckets... OK
Updating repo SOAR... OK
```


## Configuration

Copy the example configuration files using the following command:

```console
cp -rf apps.example apps
```

NB: All local configuration files are excluded from source control. Any changes to them will remain 
on your local computer. You may want to back up them in a suitable, company-dependent location.

### apps/accounts.toml
Edit the contents to reflect your system. NB: enter the SSO profile name, not the name of the account.

### apps/foundation/sso-config
This directory contains subdirectories for configuring SSO groups, SSO Permission Sets, and to associate
them with your AWS accounts. You probably don't need to modify the contents of this directory, at
least not initially.

### apps/foundation/parameters.toml
Edit `parameters.toml` to your liking. All parameters are documented in the OpenSecOps Foundation SOP.

### apps/foundation/SCPs
This folder contains the Service Control Policies for OpenSecOps Foundation. Over time, you will want to
tailor them to your specific requirements.

### apps/foundation/RCPs
This folder contains the Resource Control Policies for OpenSecOps Foundation. Over time, you will want to
tailor them to your specific requirements.

### apps/soar/parameters.toml   
Edit `parameters.toml` to your liking. All parameters are documented in the OpenSecOps SOAR SOP.

### Repo suppression
If you don't want to deploy a certain repo, make a copy of the appropriate `repos.toml` and call it
`repos-local.toml`. A file by that name will supersede `repos.toml`. Then set `deploy = false` for the
repos you don't want to deploy.


## Deployment

First make sure that your SSO setup is configured with a default profile giving you AWSAdministratorAccess
to your AWS Organizations administrative account. This is necessary as the AWS cross-account role used 
during deployment only can be assumed from that account.

The first deploy will take a substantial amount of time to complete. Make sure the profile allows a session 
of at least two hours, as it might time out otherwise and will have to be restarted. Subsequent deployments 
will be much faster.

```console
aws sso login
```

To deploy all repos, type:

```console
./deploy-all
```
The above command takes an optional argument. If present, it must be either `Foundation` or `SOAR`, but you
can omit it if you only have one application installed. It also takes two optional switches, `--dry-run` and
`--verbose`. The former is useful to see the exact changes that will be made to the infrastructure for a new
version or when stack drift has occurred. For all available options, try `./deploy-all --help`.

You can also deploy a repo individually by doing a `cd` into it followed by:

```console
./deploy
```
This is equivalent to what the installer does during deployments. The above command takes the same switches 
as `deploy-all`, that is, `--dry-run` and `--verbose`.  For all available options, try `./deploy --help`.


## Update & Recovery

Essentially, all you need to do is go to your `Installer` folder in a terminal and then:

```
git pull
./deploy-all --dry-run
./deploy-all
```

You'll need to specify `Foundation` or `SOAR` as a parameter to `deploy-all` if you have more than one product installed.

If you want to update a single component, go to its repo directory and do:

```
./deploy --dry-run
./deploy
```

It’s generally prudent to do a dry run first to see what is going to change, but the dry run is of course completely optional.

NB: You can always delete all repositories, including the `Installer` one, provided you keep `Installer/apps` where all your configuration lives. There is no configuration in the individual repositories. 

If you delete the component repo directories, all you need to do is `./init` and fresh copies will be downloaded from opensecops.org’s central repositories.

