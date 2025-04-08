#!/usr/bin/env python3

import os
import csv


def csv_to_string_list(file_path, delimiter=','):
    """Converts a CSV file into a list of strings, where each string is a raw row.

    Args:
        file_path: The path to the CSV file.
        delimiter: The delimiter used in the CSV file (defaults to comma).

    Returns:
        A list of strings, each representing a row from the CSV file.
    """

    string_list = []

    with open(file_path, 'r', newline='') as csvfile:
        reader = csv.reader(csvfile, delimiter=delimiter)

        for row in reader:
            string_list.append(delimiter.join(row))

    return string_list


def find_missing_strings(list1, list2):
    """
    Finds all strings present in sap_list but not in cortex_list.

    Args:
        sap_list: A list of strings.
        cortex_list: Another list of strings.

    Returns:
        A list of strings found in sap_list but not in cortex_list.
    """
    set1 = set(list1)
    set2 = set(list2)

    missing_strings = list(set2 - set1)

    print (missing_strings)
    
    return missing_strings


def comment_out_matching_lines(sap_file="sap_list.csv", cortex_file="cortex_list.csv", directory="../src/SAP/SAP_REPORTING/ecc"):
    """Finds .sql files with matching strings, comments out relevant lines, prints modified filenames.

    Args:
        search_strings: List of strings to search for (case-insensitive).
        directory: The directory to search in (defaults to the current directory).
    """

    # SAP csv to list
    sap_list = csv_to_string_list(sap_file)

    # Cortex csv to list
    cortex_list = csv_to_string_list(cortex_file)
    search_strings = find_missing_strings(sap_list, cortex_list)
    lowercase_search_strings = [s.lower() for s in search_strings]

    
    for filename in os.listdir(directory):
        if filename.endswith(".sql"):
            filepath = os.path.join(directory, filename)
            modified_lines = []

            with open(filepath, "r") as file:
                original_lines = file.readlines()  # Read all lines into memory

            for line in original_lines:
 
                # Case-insensitive comparison
                lowercase_line = line.lower()

                if any(s in lowercase_line for s in lowercase_search_strings):
                    modified_lines.append("--" + line)  # Comment out the line
                else:
                    modified_lines.append(line)  

            if modified_lines != original_lines:  # Check for changes
                with open(filepath, "w") as file:
                    file.writelines(modified_lines)
                print(f"Modified: {filename}")


if __name__ == "__main__":
    comment_out_matching_lines()
