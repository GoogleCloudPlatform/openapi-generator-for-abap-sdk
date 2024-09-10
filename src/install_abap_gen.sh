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

# Constants for version checking (adjust if needed)
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
        fi
    else
        printf "\e[31m%s\e[0m\n" "Command output (ERROR): Java is not installed."
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
        fi
    else
        printf "\e[31m%s\e[0m\n" "Command output (ERROR): Maven is not installed."
    fi
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

run_command_old() {
    local CMD=$1
    local success_msg=$2
    local error_msg=$3
    output=$(${CMD} 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo -e "$(tput bold)$(tput setaf 1)ERROR: ${error_msg}$(tput sgr0) $(tput sgr0)"
        exit 1  # Exit with an error code
    else
        echo -e "\n$(tput setaf 2)SUCCESS: ${success_msg}$(tput sgr0) "
    fi      
    if [ ! -z "$verbose" ]; then
        echo "----------------------------------------------------------------"
        echo "Running Command: ${CMD}"
        echo "Command Output: "
        echo "$output"
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
}

execute_generator(){
    add_comment "Execute OpenAPI Generator..."
    # cd ../../..
    run_command "java -cp out/generators/abap-gen/target/abap-gen-openapi-generator-1.0.0.jar:openapi-generator-cli.jar org.openapitools.codegen.OpenAPIGenerator generate -g abap-gen -i https://raw.githubusercontent.com/googlemaps/openapi-specification/main/dist/google-maps-platform-openapi3.json -o ./out/maps_output" "Successfully executed OpenAPI Generator!" "Failed to execute OpenAPI generator!"
}

pull_from_github(){
    github_repo_url="GoogleCloudPlatform/openapi-generator-for-abap-sdk"
    github_repo_name="openapi-generator-for-abap-sdk"

    add_comment "Cloning github repo..."
    run_command "gh repo clone $github_repo_url" "Git repository cloned successfully!" "Failed to clone Git repository"

    add_comment "Reorganizing folder structure..."
    run_command "rm $github_repo_name/my_file.mustache"
    run_command "mv $github_repo_name/*.mustache out/generators/abap-gen/src/main/resources/abap-gen"
    run_command "mv $github_repo_name/*.java out/generators/abap-gen/src/main/java/com/my/company/codegen"
    run_command "mv $github_repo_name/type_collector.sh out"
    run_command "mv $github_repo_name/*.sh ." "Successfully completed reorganization!" "Failed to reorganize the repository structure"
}

create_target_folder(){
    # create a test folder inside current directory to test functionality.
    add_comment "Creating Target Folder..."

    run_command "rm -rf $directory"
    run_command "mkdir $directory" "Successfully created Target Folder!" "Failed to create Target Folder"
    run_command "cp openapi-generator-cli.jar $directory"
    cd $directory
}

cleanup(){
    add_comment "Perform Cleanup..."
    rm openapi-generator-cli.jar
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


