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

# Function to run the maven build
run_maven_build() {
	# If the logs of previous maven build exists, delete them
	rm maven_build_output.log  &>/dev/null
	echo -n "Running the Maven build ..." 
	# To install the cudtom generator to our local maven repository
	mvn clean package -DskipTests >> maven_build_output.log
	# If the previous command ended unsuccessfully
	if [ $? -ne 0 ]; then
		echo -e "$(tput bold)$(tput setaf 1)ERROR: The maven build was UNSUCCESSFUL$(tput sgr0) $(tput sgr0) "
            	cd ../../..
		# Exit with error code
		return 1
	fi
	echo -e "\n$(tput setaf 2)Successfully executed the maven build!$(tput sgr0) "
	cd ../../..
	echo "Generating the Models and the APIs using ABAP generator ..."
	# Call the execute_generator function
	execute_generator
}

# Function to execute the Open API Custom Generator
execute_generator() {
	# If the logs of previous execution of generator exists, delete them
	rm execute_generator_output.log  &>/dev/null
	input_file=https://raw.githubusercontent.com/googlemaps/openapi-specification/main/dist/google-maps-platform-openapi3.json
	output_folder=gen_output
	rm -r out/$output_folder
	# Command to execute the custom generator
	java -cp out/generators/abap-gen/target/abap-gen-openapi-generator-1.0.0.jar:openapi-generator-cli.jar org.openapitools.codegen.OpenAPIGenerator generate -g abap-gen -i $input_file -o ./out/"$output_folder" >>execute_generator_output.log
    # If the previous command ended unsuccessfully
	if [ $? -ne 0 ]; then
		echo "$(tput bold)$(tput setaf 1)ERROR: The generator execution was UNSUCCESSFUL$(tput sgr0) $(tput sgr0) "
		# Exit with error code
		return 1
	fi
	echo "$(tput setaf 2)Successfully executed the generator!$(tput sgr0) "
	sleep 5
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
}

concatenateFiles() {
	# Adding the datatypes.txt to our interface.mustache
	current_dir_path=$(pwd)
	interface_template="$current_dir_path/gen_output/out/interface.txt"

	# Position in the interface to add the models or data types
	position=3
	rm temp.txt  &>/dev/null
	# Get contents of the types file
	cp $interface_template temp.txt
	# Insert the contents into the target file at the specified position
	sed -i "${position}r datatypes.txt" "$interface_template"
	rm interface.txt  &>/dev/null
	# Creating the file which will serve as an ABAP interface
	touch interface.txt
	cp $interface_template interface.txt
	cp temp.txt $interface_template
}

main() {
	echo "----------------------------------------------------------------------"
	echo -e "$(tput bold)Starting ABAP Generator$(tput sgr0) "
	echo "----------------------------------------------------------------------"
	# Moving to location out/generators/abap-gen
	cd open-api-generator/out/generators/abap-gen
	# call the maven build function
	run_maven_build
	echo "$(tput setaf 2)The ABAP classes have been created and stored in $(tput bold)'$output_folder'$(tput sgr0) $(tput setaf 2)folder.$(tput sgr0) "
}

main