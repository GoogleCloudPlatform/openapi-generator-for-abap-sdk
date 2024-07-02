# Open API Client Generator for ABAP SDK for Google Cloud

This tool helps you build ABAP SDK Client Stubs (Classes) for APIs with Open API Specification.

This tool can be executed from Google Cloud Shell or locally from your Linux or MacOS machine. If you are running locally ensure you have the following prerequisites already installed.

If you are running on Google Cloud Shell, then do not worry as the Shell comes pre-installed and is a developer ready environment.

To get started perform the following steps:


# Step 1: Install the Open API Client Generator

To install the open API Client Generator, open the cloud shell and run the following code:


```
mkdir openapi-abap-gen
cd openapi-abap-gen
wget https://repo1.maven.org/maven2/org/openapitools/openapi-generator-cli/7.0.0/openapi-generator-cli-7.0.0.jar -O openapi-generator-cli.jar
```


This code create a new directory and downloads the open api generator jar file in it


# Step 2: Download the installation script from this repo


```
https://raw.githubusercontent.com/GoogleCloudPlatform/oas-generator-abap-sdk-for-google-cloid/main/src/install_abap_gen.sh
```



# Step 3: Execute the installation script


```
chmod u+x

./install_abap_gen.sh
```


Chmod u+x is required to provide you with execution permission.

This script clones this repository and reorganizes folder structures and prepares ABAP SDK for Google Cloud Client Generator


# Step 4: Execute the generation script

To execute the generation script you can pass the URL or the file path of the Open API Specification, an example with the open api specification of pet store is shown below:


```
./abap_gen_start.sh https://github.com/swagger-api/swagger-petstore/blob/master/src/main/resources/openapi.yaml
```


You can download the files locally on to your machine or store the files in a cloud storage bucket, to do that you can choose to execute the generation script with additional options as described below


## Option 1: Push the generated ABAP Classes and Interfaces to Cloud Storage Bucket

To push the generated code, that is ABAP Classes and the Interface file which contains all the type definitions referenced by the ABAP Classes (Clients) run the following command


```
./download_client.sh -s <bucket name>
```



## Option 2: Download the generated ABAP Classes and Interface File

To download the generated code directly on your local machine from Google Cloud Shell, run the following command


```
./download_client.sh
```



# Step 5: [Optional] Clean up

To clean up, simple go to the parent folder in your cloud shell and execute the command:


```
rm -rf openapi-abap-gen
```

