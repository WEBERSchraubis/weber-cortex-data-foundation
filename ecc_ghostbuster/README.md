# ECC GhostBuster - automatic removal of non existing Cortex fields

Sometimes, Cortex installation on top of tables coming from older SAP ECC systems can be cumbersome, as there are a few fields missing in older version and this might cause Cortex installation failures during the deployment of reporting views.

This python script allows you to compare fields in customer raw SAP tables with fields expected by the cortex framework and identify missing ones. It can also automatically comment out all rows in reporting views containing all missing fields in the local cloned Cortex installation folder. 

Please note, it is a non productive project and has a lot of improvement potentials. Happy to incorporate any feedback.

## Preparation steps

Cortex data foundation installation can be run for the full scope or for the partial scope (e.g. just selected Looker dashboards). The description below assumes that the full Cortex data foundation installation is being executed. In case you need a partial installation, please, refer to this document that describes an example of how to identify all needed tables and views for a partial installation: go/partialcortex
The description below also assumes SAP ECC flavour of Cortex. 

1. Retrieve all tables needed for the Cortex data foundation installation and share it with the customer. One of the possible options to do it quickly is promt Genimi as follows:

"From the following yaml file, extract all table names in the base_table field. Leave out tables from the block {% if sql_flavour.upper() == 'S4' %}. Return as a comma separated list.

yaml file:
<here comes the code from cdc_settings.yaml for the Cortex version you plan to install, e.g. https://github.com/GoogleCloudPlatform/cortex-dag-generator/blob/fbf65bfd7331578127db5c115e8aa22489db6eea/cdc_settings.yaml>"


Here is an example: https://gemini.google.com/corp/share/d8a0d10a2364

Add the table DD03L to the resulting list.

Share the table list with the customer. Your customer will now need to replicate those tables into their BQ instance into SAP_RAW dataset before Cortex data foundation can be installed.

2. Extract tables and fields from your local Cortex installation with the test data. You should use the installation with the same Cortex version, which you plan to install in the customer project (you might need to substitute the list of tables in the WHERE clause with the tables found for your Cortex version or scope in step 1).

`SELECT table_name || '.' || column_name AS table_field
FROM <PROJECT_ID>.<CORTEX_SAP_RAW>.INFORMATION_SCHEMA.COLUMNS
WHERE table_name IN ("anla", "ankt", "faglflexa", "konv", "mseg", "prps", "vbuk", "vbup", "msfd", "fagl_011pc", "fagl_011qt", "fagl_011zc", "adr6", "adrc", "adrct", "bkpf", "afko", "afpo", "aufk", "bseg", "but000", "but020", "cepc", "cepct", "csks", "cskt", "ekbe", "ekes", "eket", "ekkn", "ekko", "ekpo", "jest", "kna1", "lfa1", "likp", "lips", "makt", "mara", "marc", "mard", "mast", "mbew", "mbewh", "mcha", "rbco", "rbkp", "rseg", "setleaf", "setnode", "setheadert", "setheader", "ska1", "skat", "stas", "stko", "stpo", "t001", "t001k", "t001l", "t001w", "t002", "t005", "t005k", "t005s", "t005t", "t006", "t006a", "t006t", "t009", "t009b", "t023", "t023t", "t024", "t024e", "t134", "t134t", "t148t", "t156t", "t157e", "t161", "t161t", "t179", "t179t", "t881", "t881t", "tcurc", "tcurf", "tcurr", "tcurt", "tcurx", "tspa", "tspat", "tj02t", "tka02", "tvarvc", "tvfst", "tvko", "tvkot", "tvlst", "tvtw", "tvtwt", "vbak", "vbap", "vbep", "vbfa", "vbpa", "vbrk", "vbrp", "mch1", "mska", "mslb", "msku", "mkol", "dd03l")
ORDER BY table_name, column_name;`

Do not forget to substitute <PROJECT_ID> with your project ID and <CORTEX_SAP_RAW> with your SAP raw dataset name.

Save the result to a csv file cortex_list.csv.

3. After the customer is done with the tables replication (see the first point), extract tables and fields from the customer enviroment using the same query as in the step 2, but in the customer project ID and customer raw dataset ID. Save the result to a csv file sap_list.csv.

4. Clone Cortex data foundation repository including all submodules. 

git clone --recursive <cortex_repo_url>

Put the following files into the root folder (cortex-data-foundation) of the cloned repo:
- [ecc_ghostbuster.py](https://gitlab.com/ekakruse/ecc_ghostbuster/-/blob/main/ecc_ghostbuster.py?ref_type=heads) 
- cortex_list.csv
- sap_list.csv

You can also review the source code of [ecc_ghostbuster.py](https://gitlab.com/ekakruse/ecc_ghostbuster/-/blob/main/ecc_ghostbuster.py?ref_type=heads) to check the sap_file and cortex_file parameters of the method comment_out_matching_lines  point to the right files containing a list of tables and fields that you have extracted. Parameter directory="./src/SAP/SAP_REPORTING/ecc" points to the directory where sql files for the ecc flavour of Cortex views are located. You can correct this value if it is different in your case.

## How to run

To run the script, you need to install python if not done yet.

In the command line run the following:

chmod +x ecc_ghostbuster.py
./ecc_ghostbuster.py 

As the result, the script will print out:
- The found delta between Cortex expected and SAP ECC existing fields
- Names of Cortex views affected by this 

It will also comment out the rows containing the non existing fields in the affected views automatically.
I recommend to double check the changes done in each Cortex sql view before running the Cortex installation in the next step.

## Known limitations

The script just takes "table.field" and seaches for them in sql files. In case a missing field is referenced differently, it might not be found. 

As the script comments out the whole row containing a found "table.field" expression, it works fine when a row contains this isolated field in the SELECT SQL statement (which is usually the case in Cortex Views SQL files), but it might not work as expected in more complex SQL script. I recommend to check each changed file to validate the changes before running the Cortex installation.
