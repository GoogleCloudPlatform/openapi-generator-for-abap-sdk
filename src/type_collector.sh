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

file_is_read() {
  present=0
  file_to_find="$1"

  for file in "${read_files[@]}"; do
    #check if the element matches the search value
    echo "right now array contains ${#read_files[@]} values" >>type_output.txt
    if [[ "$file" == "$file_to_find" ]]; then
      echo "${file} Array contains $file_to_find" >>type_output.txt
      present=1
      break
    fi
  done
  echo "Array does not contain $1" >>type_output.txt
  return "$present"
}

# Function to add files to datatypes.txt
reader_rec() {
  echo "The filename is $1" >>type_output.txt
  file_is_read "$1"

  # If file is found in the array read_files
  if [[ $? -eq 1 ]]; then
    # The file has been read and appended to the output file
    echo "$1 is found in read_files" >>type_output.txt
  else
    # These files have not been appended
    # Imports is the list of dependencies of the file. We have to append the imports of the file before appending the file
    # -o only outputs the lines with the following pattern (IMPORT: ). P is used to recognize regular expressions
    imports=$(grep -oP '(?<=IMPORT: )\w+' "$directory_name/$1.abap")

    # If there are no imports
    if [[ -z "$imports" ]]; then
      # All of the dependencies of the file have been added to the output
      # So we can now add the file to the output
      echo "No more inputs needed for $1" >>type_output.txt
      # Reading the contents of the file
      file_contents=$(cat "$directory_name/$1.abap")
      # Adding it to the output file
      echo "$file_contents" >> datatypes.txt
      # Adding the file to the list of read_files
      read_files+=("$1")
      echo "$1 has been added to the output" >>type_output.txt
    else
      # Looping through the imports
      for import in $imports; do
        file_is_read "$1"
        if [[ $? -eq 0 ]]; then
          # These are the imports that have not been appended to the output
          # So we have to add the imports to the output before adding our file
          echo "Adding the import " $import >>type_output.txt
          # Recursive call to add the import files to the output file
          reader_rec $import
        else
          # The import is present in the output
          echo $import " present in read_files" >>type_output.txt
        fi
      done
      # All of the files imports have been added to the outputfile
      # Append the file contents to the output file
      if [[ -f "$directory_name/$1.abap" ]]; then
        while IFS= read -r line; do
          if [[ $line == "*end_of_type*" ]]; then
            break
          else
            echo "$line" >>datatypes.txt
          fi
        done <"$directory_name/$1.abap"
        read_files+=("$1")
        echo "$1 has been added to the output" >>type_output.txt
      else
        echo "$FILE does not exist"
      fi
    fi
  fi
}

main() {
  # The list of files the have been added to the output file
  read_files=()
  # Remove the types_output.txt
  rm -rf type_output.txt
  rm -rf datatypes.txt
  rm -rf interface.txt
  # Get the current directory
  current_directory=$(pwd)

  output_folder=maps_output
  # Get the name of the directory to read files from
  directory_name="$output_folder/src/org/openapitools/model"
  # Check if the directory exists
  if [[ ! -d "$directory_name" ]]; then
    echo "The directory $directory_name does not exist."
    exit 1
  fi
  # Get the list of files in the directory
  files=$(ls -1 $directory_name)
  # Loop through the list of files
  for file in $files; do
    filename=$(basename "$file")
    filename="${filename%.*}"
    reader_rec $filename
  done
}

main
