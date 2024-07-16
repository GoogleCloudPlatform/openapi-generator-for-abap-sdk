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

# Initialize variables (optional for clarity)
open_api_spec=""
bucket_name=""
force_execution=false

show_help() {
	cat <<EOF
Usage: $0 -i <open_api_spec> -b <bucket_name> [-f]

Options:
  -i <open_api_spec>    Path to the OPEN API Specification file to be processed (required).
  -b <bucket_name>      Name of the bucket where generated ABAP Code (Classes & Interfaces) to be stored (optional).
  -f                    Force execution (optional). If specified, Maven will be rebuilt.

Example:
  $0 -i petstore.yaml -b gs://storage_bucket -f
EOF
	exit 1
}

# Validate if build is ready or execution is in force mode
validate_build_status() {
	echo -e "\nValidating build status ..."
	if $force_execution; then
		echo -e "Force execution mode ..."
		echo -e "Initiating maven build"
		initiate_build_process
	else
		# Check if the abap generator jar already exists
		file_path="target/abap-gen-openapi-generator-1.0.0.jar"
		if [ -f "target/abap-gen-openapi-generator-1.0.0.jar" ]; then
			echo -e "Build artifact: ABAP Generator JAR already exists"
			echo -e "Proceeding with Generation!"
			cd ../../..
		else
			echo -e "Previous build artifact not found!"
			echo -e "Initiating maven build"
			initiate_build_process
		fi
	fi
}

# Function to run the maven build
initiate_build_process() {
	# If the logs of previous maven build exists, delete them
	rm maven_build_output.log &>/dev/null
	echo -e "\nRunning the Maven build ..."
	# To install the custom generator to our local maven repository
	mvn clean package -DskipTests >>maven_build_output.log
	# If the previous command ended unsuccessfully
	if [ $? -ne 0 ]; then
		echo -e "$(tput bold)$(tput setaf 1)ERROR: The maven build was UNSUCCESSFUL$(tput sgr0) $(tput sgr0) "
		cd ../../..
		# Exit with error code
		exit 1
	fi
	echo -e "\n$(tput setaf 2)Successfully executed the maven build!$(tput sgr0) "
	cd ../../..
}

validate_bucket_name() {
	echo -e "Validating bucket name ...."

	response_code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $(gcloud auth print-access-token)" \
		-H "User-Agent: Google-HTTP-ABAP-Client/1.7 abap-sdk/AuthType:I/Solution:OpenAPI-ClientGen-1.0/1.7 (GPN:abap-sdk; internal)" \
		"https://storage.googleapis.com/storage/v1/b/${bucket_name}")

	echo "Response Code: ${response_code}"

	if [[ "$response_code" == "404" ]]; then
		echo -e "$(tput bold)$(tput setaf 1)ERROR: Bucket not found!$(tput sgr0) $(tput sgr0) "
		cd ../../..
		# Exit with error code
		exit 1
	else
		if [[ "$response_code" == "200" ]]; then
			echo "Success: Bucket found!"
		else
			echo -e "$(tput bold)$(tput setaf 1)ERROR: Bucket could not be verified! Check if there are authorization issues!$(tput sgr0) $(tput sgr0) "
			cd ../../..
			# Exit with error code
			exit 1
		fi
	fi
}

# Function to execute the Open API Custom Generator
execute_generator() {
	# If the logs of previous execution of generator exists, delete them
	rm execute_generator_output.log &>/dev/null
	input_file=$open_api_spec
	output_folder=gen_output
	rm -r out/$output_folder
	# Command to execute the custom generator
	java -cp out/generators/abap-gen/target/abap-gen-openapi-generator-1.0.0.jar:openapi-generator-cli.jar org.openapitools.codegen.OpenAPIGenerator generate -g abap-gen -i $input_file -o ./out/"$output_folder" >>execute_generator_output.log
	# If the previous command ended unsuccessfully
	if [ $? -ne 0 ]; then
		echo "$(tput bold)$(tput setaf 1)ERROR: The generator execution was UNSUCCESSFUL$(tput sgr0) $(tput sgr0) "
		# Exit with error code
		exit 1
	fi
	echo "$(tput setaf 2)Successfully executed the generator!$(tput sgr0) "
	sleep 5
}

concatenateFiles() {
	# Adding the datatypes.txt to our interface.mustache
	current_dir_path=$(pwd)
	interface_template="$current_dir_path/gen_output/out/interface.txt"

	# Position in the interface to add the models or data types
	position=3
	rm temp.txt &>/dev/null
	# Get contents of the types file
	cp $interface_template temp.txt
	# Insert the contents into the target file at the specified position
	sed -i "${position}r datatypes.txt" "$interface_template"
	rm interface.txt &>/dev/null
	# Creating the file which will serve as an ABAP interface
	touch interface.txt
	cp $interface_template interface.txt
	cp temp.txt $interface_template
}

main() {

	# Parse input arguments
	while getopts ":i:b:fh" opt; do
		case ${opt} in
		i) open_api_spec="$OPTARG" ;;
		b) bucket_name="$OPTARG" ;;
		f) force_execution=true ;;
		h) show_help ;;
		\?)
		  echo "Invalid option: -$OPTARG" >&2
		  show_help
		  ;;
		:)
		 echo "Option -$OPTARG requires an argument." >&2
		 show_help
		 ;;
		esac
	done

	echo "-------------------------------------------------------------------------------"
	echo -e "$(tput bold)Executing ABAP Generator for Open API Specification$(tput sgr0) "
	echo "-------------------------------------------------------------------------------"

	# Validate Open API Specification is provided
	if [[ -z "$open_api_spec" ]]; then
		echo "Open API Specification File Path -i (file path) is required." >&2
		exit 1
	fi

	# If, bucket name is provided validate if the bucket actually exists
	if [[ -n "$bucket_name" ]]; then
		validate_bucket_name
	fi

	# Moving to location out/generators/abap-gen
	cd out/generators/abap-gen

	# Validate build status, initiate build if required
	validate_build_status

	echo "Generating the Models and the APIs using ABAP generator ..."

	# Call the execute_generator function
	execute_generator

	echo "Creating the ABAP interface file ... "
	cd out
	touch datatypes.txt
	# Providing permission to execute type_collector.sh
	chmod a+x type_collector.sh

	# Executing type_collector.sh
	sh ./type_collector.sh &>/dev/null

	# Call the concatenateFiles function
	concatenateFiles

	# Print a success message
	echo "$(tput setaf 2)All the model files have been read and concatenated into the interface file. $(tput sgr0)"

	echo "$(tput setaf 2)The ABAP classes have been created and stored in $(tput bold)'$output_folder'$(tput sgr0) $(tput setaf 2)folder.$(tput sgr0) "

	if [[ -n "$bucket_name" ]]; then
		# Copying ABAP Classes and Interface File to Storage Bucket
		echo -e "\n Copying ABAP Classes and Interface files to storage bucket: ${bucket_name}"
		gsutil cp gen_output/src/org/openapitools/api/*.abap gs://${bucket_name}

		# Create an interface file with timestamp as suffic
    	timestamp=$(date +'%Y-%m-%d_%H-%M-%S')

		# Create the filename with the timestamp suffix
    	intf_filename="interface"_"${timestamp}.txt" 

		# Copy Interface File to Storage Bucket
		gsutil cp interface.txt gs://${bucket_name}/${intf_filename}
	fi

	echo -e "\nDo you like to download files... (y/n)"
	read choice
	if [[ ${choice} == "y" ]]; then
	    cd ..
		chmod u+x download_client.sh
		./download_client.sh
		echo -e "\nScript Completed! Have a nice day :-)"
	else
		echo -e "\nYou can find the files in the folder: out/gen_output/src ..."
		echo -e "\nExiting Script! Have a nice day :-)"
	fi
}

main "$@"
