# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#!/bin/bash
verbose=""

# Constants for version checking
REQUIRED_JAVA_VERSION="11"
REQUIRED_MAVEN_VERSION="3.3.4"

# Function to display help message
show_help() {
    echo "Usage: $0 [-h] [-v]"
    echo "  -h    Display this help message."
    echo "  -v    Enable verbose mode."
}

# Function to check for Java 11 or greater
check_java() {
    java_version=$(java -version 2>&1 >/dev/null)  # Redirect both output and error streams
    if [[ $? -eq 0 ]]; then 
        java_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}') 
        java_major=$(echo "$java_version" | cut -d. -f1)  
        if [[ $java_major -ge $REQUIRED_JAVA_VERSION ]]; then
            printf "\e[32m%s\e[0m\n" "Java $java_version is installed (version $REQUIRED_JAVA_VERSION or greater)"
        else
            printf "\e[31m%s\e[0m\n" "Command output (ERROR): Java is installed, but not version $REQUIRED_JAVA_VERSION or greater."
            exit 1
        fi
    else
        printf "\e[31m%s\e[0m\n" "Command output (ERROR): Java is not installed."
        exit 1
    fi
}

# Function to check for Maven 3.3.4 or greater
check_maven() {
    if command -v mvn &>/dev/null; then  
        mvn_version=$(mvn --version | grep Apache | awk '{print $3}') 
        if [[ "$(printf '%s\n' "$mvn_version" "$REQUIRED_MAVEN_VERSION" | sort -V | head -n1)" == "$REQUIRED_MAVEN_VERSION" ]]; then
            printf "\e[32m%s\e[0m\n" "Maven $mvn_version is installed (version $REQUIRED_MAVEN_VERSION or greater)"
        else
            printf "\e[31m%s\e[0m\n" "Command output (ERROR): Maven is installed, but not version $REQUIRED_MAVEN_VERSION or greater."
            exit 1
        fi
    else
        printf "\e[31m%s\e[0m\n" "Command output (ERROR): Maven is not installed."
        exit 1
    fi
}

# Function to check if GitHub CLI is installed and user has already run gh auth
check_github_cli() {
    if ! command -v gh &>/dev/null; then  
        printf "\e[31m%s\e[0m\n" "Command output (ERROR): GitHub CLI (gh) is not installed. Please install it before running this script."
        exit 1
    fi

    # Check if user is already authenticated
    if ! gh auth status &>/dev/null; then 
        printf "\e[31m%s\e[0m\n" "Command output (ERROR): You are not authenticated with GitHub CLI. Please run 'gh auth login' before running this script."
        exit 1
    fi

    printf "\e[32m%s\e[0m\n" "GitHub CLI (gh) is installed and authenticated"
}

run_command(){
    local command="$1"
    local success_msg="$2"
    local error_msg="$3"

    # Capture command output and store in a variable
    local output
    output=$(eval "$command" 2>&1)  # Capture both stdout and stderr

    if [ $? -eq 0 ]; then
        # Command succeeded
        if [ -n "$success_msg" ]; then
            printf "\e[32m%s\e[0m\n" "$success_msg"
        fi
        if [ -n "$verbose" ]; then
            # Verbose mode: Display additional details
            printf "Running command: %s\n" "$command"
            if [ -n "$output" ]; then
                printf "Command output:\n%s\n" "$output"
            fi
        fi
    else
        # Command failed
        if [ -n "$error_msg" ]; then
            printf "\e[31m%s\e[0m\n" "$error_msg"
            exit 1
        fi
        if [ -n "$verbose" ]; then
            # Verbose mode: Display additional details (even on error)
            printf "Running command: %s\n" "$command"
            if [ -n "$output" ]; then
                printf "Command output (ERROR):\n%s\n" "$output"
            fi
        fi
    fi
}

add_comment(){
    local comment=$1
    echo "$comment"
}

verify_prerequisites() {
    add_comment "Checking for Prerequisites.."
    check_java
    check_maven
    check_github_cli
}

pull_from_github(){
    github_repo_url="GoogleCloudPlatform/openapi-generator-for-abap-sdk"
    github_repo_name="openapi-generator-for-abap-sdk"

    add_comment "Cloning github repo..."
    run_command "gh repo clone $github_repo_url" "Git repository cloned successfully!" "Failed to clone Git repository"

    add_comment "Reorganizing folder structure..."
    run_command "mv $github_repo_name/src/*.mustache out/generators/abap-gen/src/main/resources/abap-gen"
    run_command "mv $github_repo_name/src/*.java out/generators/abap-gen/src/main/java/com/my/company/codegen"
    run_command "mv $github_repo_name/src/type_collector.sh out"
    run_command "mv $github_repo_name/src/*.sh ." "Successfully completed reorganization!" "Failed to reorganize the repository structure"
}

cleanup(){
    add_comment "Perform Cleanup..."
    run_command "rm -rf $github_repo_name" "Successfully completed cleanup!" "Failed to Cleanup resources!"    
}

main() {

    # Process command-line options
    while getopts ":hv" option; do
        case $option in
            h) show_help; exit 0 ;;
            v) verbose="X" ;;
            \?) echo "Invalid option: -$OPTARG"; show_help; exit 1 ;;
        esac
    done

    echo "================================================================"
    echo -e "$(tput bold)Install Open API Client Generator for ABAP SDK for Google Cloud$(tput sgr0)"
    echo "================================================================"
    
    add_comment "Run packaged parent generator..."
    run_command "java -jar openapi-generator-cli.jar meta -o out/generators/abap-gen -n abap-gen -p com.my.company.codegen" "Successfully ran packaged parent generator!" "Failed to run packaged parent generator!"

    cd out/generators/abap-gen

    verify_prerequisites 
    
    cd ../../..
    
    pull_from_github
    cleanup
    echo "================================================================"
}

main $*
