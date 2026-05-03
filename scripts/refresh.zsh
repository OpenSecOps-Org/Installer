#!/usr/bin/env zsh

: '
OpenSecOps Foundation Component Script Distribution System

This script distributes core deployment scripts from the Installer to all Foundation components,
ensuring consistent deployment behavior and capabilities across the OpenSecOps ecosystem.

What it distributes:
- deploy.py: Main deployment orchestration script with parameter resolution
- setup.zsh: Git repository setup utilities for dual-repository workflow  
- publish.zsh: Publication workflow for clean release management
- .gitignore: Standardized ignore patterns for Foundation components

The refresh mechanism maintains script consistency while allowing each component to have 
its own repository and development workflow. This ensures all components have the latest
deployment capabilities and bug fixes.

Usage:
    ./refresh [--dev] [--push] [REPO_name]

Options:
    --dev: Run the script in development mode. In this mode, the script creates symlinks 
        for the scripts in the REPO without the file extension, and copies the example 
        deployment and changelog files to the REPO if they do not already exist.

    --push: Push the changes to the remote repository after all changes have been made to 
        a directory.

    REPO_name: The name of a specific REPO to process. If not provided, the script will 
        process all directories in the outer REPO that start with the names in APP_DIRECTORIES.

Example:
    ./scriptname --dev --push Foundation-MyApp
'

OUTER_FOLDER=".."
APP_DIRECTORIES=("Foundation" "SOAR")
SCRIPTS=(
    "setup.zsh"
    "deploy.py"
    "publish.zsh"
    "compile-requirements.sh"
    "_check-requirements.sh"
    "_scan-updates.sh"
    "_generate-security-md.sh"
    "_aggregate-sbom.sh"
    "_requirements_lib.sh"
)
# Files whose basename starts with `_` are distributed but PRIVATE —
# no top-level symlink is created for them in --dev mode. This covers
# both sourced helpers (_requirements_lib.sh) and executable scripts
# that publish.zsh's pre-flight gate or rare debug runs invoke
# directly, e.g. `scripts/_check-requirements.sh`. Keeping the top
# level uncluttered is a deliberate design choice; the user-facing
# surface in each component repo is intentionally narrow.
SECURITY_TEMPLATE_FILE="templates/SECURITY.md.template"
BOTO3_IN_FILE="templates/boto3.in"
DEPLOY_EXAMPLE_FILE="templates/config-deploy.toml.example"
CHANGELOG_EXAMPLE_FILE="templates/CHANGELOG.md.example"
LICENSE_FILE="LICENSE.txt"
APP_TYPE_MAP=("Foundation:foundation" "SOAR:soar")

# Define colors
YELLOW="\033[93m"
LIGHT_BLUE="\033[94m"
GREEN="\033[92m"
RED="\033[91m"
END="\033[0m"
BOLD="\033[1m"


# Define a function to push changes
push_changes() {
    local repo=$1

    echo -e "${YELLOW}Pushing changes to the remote repository for $repo${END}"
    cd "$repo"

    # # Check for uncommitted changes
    # if [[ -n $(git status --porcelain) ]]; then
    #     echo -e "${RED}There are uncommitted changes in $repo. Please commit them before running this script.${END}"
    #     cd -
    #     return
    # fi

    git add .
    git commit -m "Dev scripts and files updated by automation."
    git push origin main
    cd -
}


# Optional exact REPO name as parameter
FILTER=""
DEV_MODE=false

# Process parameters
for arg in "$@"
do
    if [[ "$arg" == "--dev" ]]
    then
        DEV_MODE=true
    elif [[ "$arg" == "--push" ]]
    then
        PUSH_CHANGES=true
    elif [[ -z "$FILTER" ]]
    then
        FILTER="$arg"
    fi
done

# If exact REPO name is provided, process only that REPO. Otherwise, process all directories.
if [[ -z "$FILTER" ]]
then
    TARGET_DIRECTORIES=()
    for REPO in "${OUTER_FOLDER}"/*
    do
        if [[ -d "$REPO" ]]
        then
            BASE_DIR_NAME=$(basename "$REPO")
            for APP_PREFIX in "${APP_DIRECTORIES[@]}"
            do
                if [[ "$BASE_DIR_NAME" == "$APP_PREFIX"* ]]
                then
                    TARGET_DIRECTORIES+=("$REPO")
                    break
                fi
            done
        fi
    done
else
    TARGET_DIRECTORIES=("${OUTER_FOLDER}/${FILTER}")
fi

for REPO in "${TARGET_DIRECTORIES[@]}"
do
    if [[ -d "$REPO" ]]
    then
        echo -e "${LIGHT_BLUE}-------------------------------------${END}"
        echo -e "${LIGHT_BLUE}Processing $REPO${END}"

        BASE_DIR_NAME=$(basename "$REPO")
        APP_TYPE="unknown"

        for app_mapping in "${APP_TYPE_MAP[@]}"
        do
            DIR_PREFIX="${app_mapping%%:*}"
            if [[ "$BASE_DIR_NAME" == "$DIR_PREFIX"* ]]
            then
                APP_TYPE="${app_mapping##*:}"
                break
            fi
        done

        # Detect boto3 usage BEFORE distributing scripts/ — refresh's own
        # deploy.py imports boto3, so detecting after distribution would
        # false-positive every repo. The honest signal is whether the
        # repo's pre-existing application code (outside the refresh-
        # managed scripts/ tree) imports boto3 or botocore. See
        # the boto3 distribution-detection rule.
        NEEDS_BOTO3_IN=false
        if find "$REPO" \( \
                -name .git -o -name .aws-sam -o -name .venv \
                -o -name venv -o -name node_modules \
                -o -name __pycache__ -o -name .pytest_cache \
                -o -name scripts \
            \) -prune -o -type f -name '*.py' -print0 2>/dev/null \
            | xargs -0 grep -lE '^[[:space:]]*(import|from)[[:space:]]+(boto3|botocore)\b' 2>/dev/null \
            | head -1 | grep -q .
        then
            NEEDS_BOTO3_IN=true
        fi

        # Check if scripts folder exists in the given REPO and delete it
        if [[ -d "$REPO/scripts" ]]
        then
            echo -e "${YELLOW}Removing existing scripts REPO in $REPO${END}"
            rm -rf "$REPO/scripts"
        fi

        # Create a new scripts REPO
        echo -e "${YELLOW}Creating new scripts REPO in $REPO${END}"
        mkdir "$REPO/scripts"

        # In DEV_MODE, sweep stale top-level symlinks pointing into scripts/
        # before recreating. Catches the case where a script was removed from
        # the SCRIPTS list — the old top-level symlink would otherwise dangle.
        if [[ "$DEV_MODE" == true ]]
        then
            for existing in "$REPO"/*(@N); do
                target=$(readlink "$existing" 2>/dev/null) || continue
                if [[ "$target" == scripts/* ]]; then
                    rm -f "$existing"
                fi
            done
        fi

        # Copy the scripts and make them executable
        for SCRIPT in "${SCRIPTS[@]}"
        do
            echo -e "${YELLOW}Copying $SCRIPT to the new scripts REPO and setting it as executable${END}"
            cp "scripts/$SCRIPT" "$REPO/scripts/"
            chmod +x "$REPO/scripts/$SCRIPT"

            # If DEV_MODE is true, create symlink without extension in the REPO.
            # Use ln -sf so re-runs of refresh are idempotent (the previous
            # symlink, if any, has already been swept above; this is belt-and-
            # braces against races / incomplete sweeps).
            #
            # Files whose basename starts with `_` are sourced helpers
            # (e.g. _requirements_lib.sh) — distributed to scripts/ but
            # NOT exposed as a top-level executable symlink.
            if [[ "$DEV_MODE" == true && "$(basename "$SCRIPT")" != _* ]]
            then
                echo -e "${YELLOW}Creating symlink for $SCRIPT in the REPO without file extension${END}"
                SCRIPT_BASE_NAME=$(basename "$SCRIPT")
                SCRIPT_BASE_NAME="${SCRIPT_BASE_NAME%.*}"
                ln -sf "scripts/${SCRIPT}" "${REPO}/${SCRIPT_BASE_NAME}"
            fi
        done

        # Copy README
        echo -e "${YELLOW}Copying README.md to the new scripts REPO${END}"
        cp "scripts/README.md" "$REPO/scripts/README.md"

        # Copy .gitignore to the new REPO
        echo -e "${YELLOW}Copying .gitignore to the new REPO${END}"
        cp ".gitignore" "$REPO/"

        # Copy SECURITY.md.template (byte-identical canonical source —
        # always overwrite, every refresh run, like .gitignore). The
        # local generate-security-md.sh in each repo reads this template
        # plus the local .security-config.toml to render SECURITY.md.
        echo -e "${YELLOW}Copying $SECURITY_TEMPLATE_FILE to $REPO/SECURITY.md.template${END}"
        cp "$SECURITY_TEMPLATE_FILE" "$REPO/SECURITY.md.template"

        # Conditionally distribute boto3.in — applies the boto3
        # distribution-detection rule. The detection itself ran earlier
        # (above the scripts/ wipe) so it sees the repo's original
        # application code, not refresh-distributed tooling.
        #
        # Stale removal: if a repo's last boto3-using Python file
        # disappears, refresh leaves any existing boto3.in in place and
        # logs that no signal was found — `git rm` is a deliberate
        # maintainer action, not a tool action.
        if [[ "$NEEDS_BOTO3_IN" == true ]]
        then
            echo -e "${YELLOW}boto3 import detected — copying $BOTO3_IN_FILE to $REPO/boto3.in${END}"
            cp "$BOTO3_IN_FILE" "$REPO/boto3.in"
        elif [[ -f "$REPO/boto3.in" ]]
        then
            echo -e "${YELLOW}no boto3 usage detected; existing $REPO/boto3.in left in place — git rm if you're sure${END}"
        fi

        # If DEV_MODE is true, copy example deploy and changelog config file to the main REPO if it does not exist
        if [[ "$DEV_MODE" == true ]]
        then
            if [[ ! -e "$REPO/config-deploy.toml" ]]
            then
                echo -e "${YELLOW}Copying $DEPLOY_EXAMPLE_FILE to $REPO/config-deploy.toml with substitutions${END}"

                # Read the contents of the file into a variable
                file_content=$(cat "$DEPLOY_EXAMPLE_FILE")

                # Remove the prefix from $BASE_DIR_NAME
                SHORTENED_BASE_DIR_NAME=${BASE_DIR_NAME#*-}

                # Perform the string substitutions
                file_content=$(perl -pe "s/([^-]+)-<repo>/\1-${SHORTENED_BASE_DIR_NAME}/g" <<< "$file_content")
                file_content=${file_content//<repo>/$BASE_DIR_NAME}
                file_content=${file_content//<app>/$APP_TYPE}

                # Write the result to config-deploy.toml
                echo "$file_content" > "$REPO/config-deploy.toml"
            fi

            if [[ ! -e "$REPO/CHANGELOG.md" ]]
            then
                echo -e "${YELLOW}Copying $CHANGELOG_EXAMPLE_FILE to $REPO/CHANGELOG.md${END}"
                cp "$CHANGELOG_EXAMPLE_FILE" "$REPO/CHANGELOG.md"
            fi

            echo -e "${YELLOW}Copying $LICENSE_FILE to $REPO/$LICENSE_FILE${END}"
            cp "$LICENSE_FILE" "$REPO/$LICENSE_FILE"
        fi

        # If PUSH_CHANGES is true, push the changes to the remote repository
        if [[ "$PUSH_CHANGES" == true ]]
        then
            push_changes "$REPO"
        fi

        echo -e "${GREEN}Finished processing $REPO${END}"
        echo -e "${LIGHT_BLUE}-------------------------------------${END}"
    else
        echo -e "${RED}REPO $REPO not found${END}"
    fi
done
