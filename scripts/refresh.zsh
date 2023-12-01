#!/bin/zsh

: '
This script is used to manage and deploy applications in multiple directories.
It copies scripts and .gitignore files to the specified REPO or to all directories.

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
SCRIPTS=("setup.zsh" "deploy.py" "publish.zsh")
DEPLOY_EXAMPLE_FILE="config-deploy.toml.example"
CHANGELOG_EXAMPLE_FILE="CHANGELOG.md.example"
LICENSE_FILE="LICENSE.md"
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

        # Check if scripts folder exists in the given REPO and delete it
        if [[ -d "$REPO/scripts" ]]
        then
            echo -e "${YELLOW}Removing existing scripts REPO in $REPO${END}"
            rm -rf "$REPO/scripts"
        fi

        # Create a new scripts REPO
        echo -e "${YELLOW}Creating new scripts REPO in $REPO${END}"
        mkdir "$REPO/scripts"

        # Copy the scripts and make them executable
        for SCRIPT in "${SCRIPTS[@]}"
        do
            echo -e "${YELLOW}Copying $SCRIPT to the new scripts REPO and setting it as executable${END}"
            cp "scripts/$SCRIPT" "$REPO/scripts/"
            chmod +x "$REPO/scripts/$SCRIPT"

            # If DEV_MODE is true, create symlink without extension in the REPO
            if [[ "$DEV_MODE" == true ]]
            then
                echo -e "${YELLOW}Creating symlink for $SCRIPT in the REPO without file extension${END}"
                SCRIPT_BASE_NAME=$(basename "$SCRIPT")
                SCRIPT_BASE_NAME="${SCRIPT_BASE_NAME%.*}"
                ln -s "scripts/${SCRIPT}" "${REPO}/${SCRIPT_BASE_NAME}"
            fi
        done

        # Copy README
        echo -e "${YELLOW}Copying README.md to the new scripts REPO${END}"
        cp "scripts/README.md" "$REPO/scripts/README.md"

        # Copy .gitignore to the new REPO
        echo -e "${YELLOW}Copying .gitignore to the new REPO${END}"
        cp ".gitignore" "$REPO/"

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

            echo -e "${YELLOW}Copying $LICENSE to $REPO/$LICENSE_FILE${END}"
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
