/*
 Copyright 2024 Google LLC

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

      https://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */


 package com.my.company.codegen;
 import java.io.File;
 import java.util.*;
 import java.util.regex.Matcher;
 import java.util.regex.Pattern;

 import org.openapitools.codegen.*;
 import org.openapitools.codegen.model.*;
 
 public class AbapGenGenerator extends DefaultCodegen { // implements CodegenConfig {
 
   // map to keep track of short names assigned for types
   public Map<String, String> shortNamesForModels = new HashMap<>();
 
   // map to keep track of short names assigned for classes
   public Map<String, Vector<String>> shortNamesForApi = new HashMap<>();
 
   // source folder where to write the files
   protected String sourceFolder = "src";
   protected String apiVersion = "1.0.0";
   protected String intfName = "";
 
   public CodegenType getTag() {
     return CodegenType.OTHER;
   }
 
   public String getName() {
     return "abap-gen";
   }
 
   @Override
   public OperationsMap postProcessOperationsWithModels(
       OperationsMap objs, List<ModelMap> allModels) {
 
     OperationsMap results = super.postProcessOperationsWithModels(objs, allModels);
     OperationMap ops = objs.getOperations();
 
     List<CodegenOperation> opList = ops.getOperation();
     String abapClassName = ops.getClassname();
     abapClassName = editName(abapClassName, "");
     ops.setClassname(abapClassName);
     for (CodegenOperation co : opList) {
       co.operationId = editName(co.operationId, "");
 
       // baseName is the name of the client stubs
       co.baseName = editName(co.baseName, "");
       if (co.hasProduces == true){
        co.returnType = editType(co.returnType, "ty_");
       } else{
        co.returnType = "string";
       }

       List<CodegenParameter> params = co.allParams;
       for (CodegenParameter param : params) {
         param.paramName = editName(param.baseName, "");
         if (param.dataType == "STANDARD TABLE OF") {
           param.dataType = "ty_t_string";
         }
         if (param.isQueryParam == true) {
           if (param.isArray == true) {
             // For query parameters of array type
             param.baseName = editName(param.baseName, "it_q_");
           } else {
             // For query parameters of non-array type
             param.baseName = editName(param.baseName, "iv_q_");
           }
         } else if (param.isPathParam == true) {
           if (param.isArray == true) {
             // For path parameters of array type
             param.baseName = editName(param.baseName, "it_p_");
           } else {
             // For path parameters of non-array type
             param.baseName = editName(param.baseName, "iv_p_");
           }
         } else if (param.isBodyParam == true){
          param.dataType = editType(param.dataType, "ty_");
         }
       }
     }
 
     Object abapApiName = additionalProperties.get("appName");
     if (abapApiName instanceof String) {
       String abapApiNameStr = (String) abapApiName;
       abapApiNameStr = editName(abapApiNameStr, "");
       abapApiNameStr = escapeSpecialCharacters(abapApiNameStr);
       additionalProperties.put("appName", abapApiNameStr);
       intfName = abapApiNameStr;
     }
 
     return results;
   }
 
   // You can modify the models/types here
   @Override
   public ModelsMap postProcessModels(ModelsMap objs) {
     objs = super.postProcessModels(objs);
     List<ModelMap> models = objs.getModels();
     for (ModelMap mo : models) {
       CodegenModel cm = mo.getModel();
 
       if (!cm.name.equals(cm.classname)) {
         // This can be a case of inline schema generation
         // In this case check for title, if title is null add an additional property
         cm.classVarName = cm.name;
         cm.classFilename = cm.name;
       }
 
       for (CodegenProperty param : cm.vars) {
         if (languageSpecificPrimitives.contains(param.dataType) == false) {
           param.dataType = editType(param.dataType, "ty_");
         }
 
         param.baseName = editName(param.baseName, "");
 
         if (languageSpecificPrimitives.contains(param.complexType) == false) {
           if (param.complexType == "string") param.complexType = "STRING";
           else param.complexType = editType(param.complexType, "ty_");
         }
 
         param.description = extractDescription(param.unescapedDescription, 60);
       }
 
       String newClassVarName = editType(cm.classVarName, "ty_");
       additionalProperties.put("newClassVarName", newClassVarName);
     }
 
     return objs;
   }
 
   public String getHelp() {
     return "Hi this is the ABAP OpenAPI Generator for ABAP SDK for Google Cloud. It generates ABAP"
         + " code from OpenAPI specifications.";
   }
 
   public AbapGenGenerator() {
     super();
 
     // set the output folder here
     outputFolder = "generated-code/abap-gen";
 
     // TYPE MAPPING (maps the data types of the OpenAPI Generator to the data types
     // of the ABAP
     // GENERATOR)
     super.typeMapping = new HashMap<>();
     typeMapping.put("object", "REF TO DATA");
     typeMapping.put("AnyType", "REF TO DATA");
     typeMapping.put("string", "STRING");
     typeMapping.put("integer", "int4");
     typeMapping.put("number", "/goog/num_float");
     typeMapping.put("boolean", "abap_bool");
     typeMapping.put("array", "STANDARD TABLE OF");
     typeMapping.put("List", "STANDARD TABLE OF");
     typeMapping.put("long", "int8");
     typeMapping.put("DateTime", "STRING");
     typeMapping.put("Date", "STRING");
     typeMapping.put("UUID", "STRING");
     typeMapping.put("URI", "STRING");
     typeMapping.put("byte", "XSTRING");
 
     modelTemplateFiles.put(
         "model.mustache", // the template to use
         ".abap"); // the extension for each file to write
 
     apiTemplateFiles.put(
         "api.mustache", // the template to use
         ".abap"); // the extension for each file to write
 
     supportingFiles.add(new SupportingFile("interface.mustache", "out", "interface.txt"));
 
     templateDir = "abap-gen";
 
     apiPackage = "org.openapitools.api";
 
     modelPackage = "org.openapitools.model";
 
     Object abapApiName = additionalProperties.get("appName");
     if (abapApiName instanceof String) {
       String abapApiNameStr = (String) abapApiName;
       abapApiNameStr = editName(abapApiNameStr, "");
       additionalProperties.put("appName", abapApiNameStr);
       intfName = abapApiNameStr;
     }
 
     languageSpecificPrimitives =
         new HashSet<String>(
             Arrays.asList(
                 "array", 
                 "number",
                 "REF TO DATA",
                 "STRING",
                 "integer",
                 "int4",
                 "int8",
                 "XSTRING",
                 "/goog/num_float",
                 "abap_bool",
                 "List",
                 "OBJECT",
                 "AnyType",
                 "STANDARD TABLE OF"));
     /** Reserved words. Override this with reserved words specific to your language */
     /**
      * reservedWords = new HashSet<String>( Arrays.asList( "sample1", // replace with static values
      * "sample2"));
      */
     additionalProperties.put("apiVersion", apiVersion);
 
     /**
      * Supporting Files. You can write single files for the generator with the entire object tree
      * available. If the input file has a suffix of `.mustache it will be processed by the template
      * engine. Otherwise, it will be copied
      */
     /*supportingFiles.add(new SupportingFile("myFile.mustache", // the input template or file
         "", // the destination folder, relative `outputFolder`
         "myFile.sample") // the output file
     );*/
   }
 
   int shortenedNameLength = 30;
 
   @Override
   public String escapeReservedWord(String name) {
     if (this.reservedWordsMappings().containsKey(name)) {
       return this.reservedWordsMappings().get(name);
     }
     return "_" + name;
   }
 
   // Converts camel case variables to snake case
   // For example, abapGenerator will become abap_generator
   public static String convertCamelToSnake(String str) {
     // Regular Expression of type Camel case
     // eg: abcDef
     String regex = "([a-z])([A-Z]+)";
     // eg: abc_Def
     String replacement = "$1_$2";
     // Replace the given regex with replacement string and convert it to lower case.
     // eg: abcDef will become abc_Def, then will be converted to lower case :
     // abc_def
     str = str.replaceAll(regex, replacement).toLowerCase();
     return str;
   }
 
   public static String convertSentenceToSnake(String str) {
     int n = str.length();
     String str1 = "";
     for (int i = 0; i < n; i++) {
       // Converting space to underscore
       if (str.charAt(i) == ' ') str1 = str1 + '_';
       else
         // If not space, convert into lower character
         str1 = str1 + Character.toLowerCase(str.charAt(i));
     }
     return str1;
   }
 
   // Uniquifies the variables by replacing them with the numerical value
   // corresponding to the
   // variable in the short names map
   public String shortenedForm(int index) {
     // for short names of index 0 (First string to be added of the given
     // shortenedName) like
     // 000
     if (index == 0) return "000";
     String stringifiedIndex = Integer.toString(index);
     // for short names of index > 100
     if (index / 100 != 0) return stringifiedIndex;
     // for short names of index 10 to 99
     if (index / 10 != 0) return "0" + stringifiedIndex;
     // for short names of index 1 to 9
     return "00" + stringifiedIndex;
   }
 
   // Shortens the variables to a certain length
   // for example, if you set "trimLength" to 27, the string returned will be 27 +
   // 3
   // characters long (3 digits obtained from uniquifying using "shortenedForm"
   // function)
   public String truncateVariable(String name) {
     Vector<String> names = new Vector<>();
     // Number of characters that the shortened string should be trimmed to
     int trimLength = 27;
     // Cut the name to 27 characters
     String cutString = name.substring(0, Math.min(name.length(), trimLength));
     boolean flag = false;
     String shortenedName = "";
     int j;
     if (shortNamesForApi.containsKey(cutString)) {
       // Get the array of names with the given shortened name
       names = shortNamesForApi.get(cutString);
       for (j = 0; j < names.size(); j++) {
         if (names.get(j).equals(name)) {
           // cant use == check gfg
           // CASE 1: When the shortened name and the original name are already added in
           // the map
           flag = true;
           // Uniquify the shortened name by indexing
           shortenedName = cutString + shortenedForm(j);
           return shortenedName;
         }
       }
       if (flag == false) {
         // CASE 2: When the shortened name is in the map but the original name is not
         // Add the new name to the array of names with the given shortened name
         names.add(name);
         // Update the values in the shortNamesForApi map
         shortNamesForApi.put(cutString, names);
         // Uniquify the shortened name by indexing
         shortenedName = cutString + shortenedForm(names.size() - 1);
       }
     } else {
       // CASE 3: Neither short name nor original name are present in the map
       names.add(name);
       // Update the values in the shortNamesForApi map
       shortNamesForApi.put(cutString, names);
       // Uniquify the shortened name by indexing
       shortenedName = cutString + shortenedForm(names.size() - 1);
     }
     return shortenedName;
   }
 
   // Edits the names to suit ABAP naming convention
   // for example, openAPIAbapGenerator can become ty_openAPI_abap_generator
   public String editName(String name, String prefix) {
     // for reserved word or word starting with number, append _
     // Change the naming convention from camelCase to snake_case
     name = convertCamelToSnake(name);
     name = convertSentenceToSnake(name);
     // Add the corresponding prefices to the names
     name = prefix + name;
     // If the names are above 30 characters, truncate them to 30 and uniquify
     if (name.length() > shortenedNameLength) {
       name = truncateVariable(name);
     }
     if (isReservedWord(name) || name.matches("^\\d.*") || name.matches("^(@).*$")) {
       name = escapeReservedWord(name);
     }
     return name;
   }
 
   // Converts the names to a number corresponding to its position in the
   // shortNamesForModels map
   public String editType(String name, String prefix) {
     int index = shortNamesForModels.size();
     String newName = shortenedForm(index);
     // Add the corresponding prefices to the names
     newName = prefix + newName;
     if (!shortNamesForModels.containsKey(name)) {
       shortNamesForModels.put(name, newName);
       return newName;
     }
     newName = shortNamesForModels.get(name);
 
     return newName;
   }
 
   /**
    * Location to write model files. You can use the modelPackage() as defined when the class is
    * instantiated
    */
   public String modelFileFolder() {
     return outputFolder
         + "/"
         + sourceFolder
         + "/"
         + modelPackage().replace('.', File.separatorChar);
   }
 
   /**
    * Location to write api files. You can use the apiPackage() as defined when the class is
    * instantiated
    */
   @Override
   public String apiFileFolder() {
     return outputFolder + "/" + sourceFolder + "/" + apiPackage().replace('.', File.separatorChar);
   }
 
   /**
    * override with any special text escaping logic to handle unsafe characters so as to avoid code
    * injection
    *
    * @param input String to be cleaned up
    * @return string with unsafe characters removed or escaped
    */
   @Override
   public String escapeUnsafeCharacters(String input) {
     return input;
   }
 
   /**
    * Escape single and/or double quote to avoid code injection
    *
    * @param input String to be cleaned up
    * @return string with quotation mark removed or escaped
    */
   public String escapeQuotationMark(String input) {
     // return input.replace("\"", "\\\"");
     return input;
   }
 
   @Override
   public Map<String, Object> postProcessSupportingFileData(Map<String, Object> bundle) {
     bundle.put("intfName", intfName);
 
     return bundle;
   }
 
   public static String extractDescription(String text, int maxLength) {
 
     if (text == null) {
       return "";
     }
 
     String[] sentences = text.split("\\."); // Split into sentences
 
     StringBuilder description = new StringBuilder();
     int currentLength = 0;
     String descrStr = "";
 
     for (String sentence : sentences) {
       // Remove leading/trailing spaces and add period back
       sentence = sentence.trim() + ".";
 
       // Check if adding the sentence exceeds the maxLength
       if (currentLength + sentence.length() > maxLength) {
         if (currentLength == 0) {
           // If this is the first sentence and it's too long, truncate it
           description.append(sentence, 0, maxLength);
         }
         break; // Stop adding sentences
       }
 
       description.append(sentence);
       currentLength += sentence.length();
     }
 
     StringBuilder stringBuilder = new StringBuilder();
     stringBuilder.append("\"");
     stringBuilder.append(description.toString());
     descrStr = stringBuilder.toString();
     return descrStr;
   }

   public static String escapeSpecialCharacters(String text) {
    String escapedString = Pattern.compile("[*&$#%/]") // Define the characters to replace
    .matcher(text)
    .replaceAll("_"); 
    return escapedString;
   }
 }
 