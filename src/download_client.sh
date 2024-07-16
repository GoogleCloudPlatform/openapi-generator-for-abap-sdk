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

#Remove any existing zip file
starting_dir=$(pwd)
cd out
echo -e "Removing any previously generated zip file"
rm -f Abap_Classes.zip
cd ..
cd out/gen_output/src/org/openapitools/api/
zip -r ../Abap_Classes.zip *

sleep 2
cd ~
cd ${starting_dir}/out/
mv gen_output/src/org/openapitools/Abap_Classes.zip .
zip -u Abap_Classes.zip interface.txt

sleep 2
cloudshell download Abap_Classes.zip 2>/dev/null
if [ $? -ne 0 ]; then
 echo -e "Error in downloading zip file, you can find the zip file in folder: openapi-abap-gen/out/"
fi
