import os
import sys
from datetime import datetime
from datetime import timedelta


def format_2_dict(input: list) -> dict:
    input_dict = {}
    for i in input:
        line_cleaned = i.strip().replace("(",":").replace(")","").split(":")
        large_hash = line_cleaned[-1].split("/")[-1]
        assembly = f"{line_cleaned[2]}_{line_cleaned[0]}_{large_hash}"
        fcs_wd = line_cleaned[3]

        input_dict[assembly] = fcs_wd
    return input_dict


def read_log_get_node(input_file: str) -> str:
    with open(input_file) as input:
        for line in input:
            if line.startswith("Sender"):
                result = line.replace(">", "").split("@")[1]
                return result.strip()


def read_log_get_success(input_file: str) -> str:
    with open(input_file) as input:
        for line in input:
            if "Successfully completed." in line:
                return "SUCCESS"
            elif "Exited with exit code 1." in line:
                return "FAILED"


def read_log_get_time(input_file: str):
    started, ended = "", ""
    with open(input_file) as input:
        for line in input:
            if "Started at" in line:
                started = line.replace("Started at ", "")
            if "Results reported at" in line:
                ended = line.replace("Results reported at ", "")

    return started, ended


def get_time_delta(start, end):
    if start != "NA" and end != "NA":
        delta = (end - start)
        return delta.total_seconds() / 60
    else:
        return "NA"


def get_time_taken(stime: str, etime: str):
    input_date_format = "%a-%b-%d-%H:%M:%S-%Y"

    if stime != "":

        stime = "-".join(stime.strip().split(" "))
        stime_formatted = datetime.strptime(stime, input_date_format)
    else:
        stime_formatted = "NA"

    if etime != "":
        etime = "-".join(etime.strip().split(" "))
        etime_formatted = datetime.strptime(etime, input_date_format)
    else:
        etime_formatted = "NA"

    delta = get_time_delta(stime_formatted, etime_formatted)

    return stime_formatted, etime_formatted, delta


def get_log_file(input_dict: dict, file_name: str):
    new_dict = {}
    for x, y in input_dict.items():
        log_file = y + file_name
        if os.path.isfile(log_file):
            node = read_log_get_node(log_file)
            status = read_log_get_success(log_file)
            stime, etime = read_log_get_time(log_file)

            s, e, d = get_time_taken(stime, etime)

            new_dict[x] = {
                "node": node,
                "log_file": log_file,
                "status": status,
                "stime":s,
                "etime": e,
                "delta": d
            }

    return new_dict


def sort_dictionary(in_dict: dict) -> dict:
    # https://www.geeksforgeeks.org/python/python-sort-python-dictionaries-by-key-or-value/
    myKeys = list(in_dict.keys())
    myKeys.sort()

    # Sorted Dictionary
    sd = {i: in_dict[i] for i in myKeys}
    return sd


def print_dict(dict_of_dict: dict, data_amonut) -> None:
    for x, y in dict_of_dict.items():
        if data_amonut == "ALL":
            print(f"{x}\n\t- NODE: {y['node']}\n\t- STAT: {y['status']}\n\t- STIME: {y['stime']}\n\t- ETIME: {y['etime']}\n\t- DTIME: {y['delta']}\n\t- LOGS: {y['log_file']}\n")
        elif data_amonut == "FAILS":
            if y['status'] == "FAILED":
                print(f"{x}\n\t- NODE: {y['node']}\n\t- STAT: {y['status']}\n\t- STIME: {y['stime']}\n\t- ETIME: {y['etime']}\n\t- DTIME: {y['delta']}\n\t- LOGS: {y['log_file']}\n")
        elif data_amonut == "PASS":
            if y['status'] == "SUCCESS":
                print(f"{x}\n\t- NODE: {y['node']}\n\t- STAT: {y['status']}\n\t- STIME: {y['stime']}\n\t- ETIME: {y['etime']}\n\t- DTIME: {y['delta']}\n\t- LOGS: {y['log_file']}\n")

        else:
            sys.exit(1)

def get_node_counts(input_dict: dict) -> dict:
    node_dict = {}
    for x, y in input_dict.items():
        for i in ["SUCCESS", "FAILED"]:
            if y['node'] != None:
                if y['node'] + f' {i}' in node_dict and y['status'] == i:
                    node_dict[y['node'] + f' {i}'] += 1
                else:
                    node_dict[y['node']+ f' {i}'] = 1

    return node_dict


def print_node_dict(node_dict: dict) -> None:
    run_counter = 0
    success_counter = 0
    fail_counter = 0
    for x, y in node_dict.items():
        print(f"{x} \t- {y}")
        if "SUCCESS" in x:
            success_counter += y
            run_counter += y
        elif "FAILED" in x:
            fail_counter += y
            run_counter += y
    print(f"Total no. runs: {run_counter}")
    print(f"No. of failure: {fail_counter}")
    print(f"No. of success: {success_counter}")

def main(log_file, data_fullness):
    line_list = []
    search_4_file = "ASCC_FULL_OUTPUT/*/.command.log"

    with open(log_file) as input:
        for line in input:
            line_list.append(line)

    input_dict = format_2_dict(line_list)

    node_dict = get_log_file(input_dict, search_4_file)

    sorted_dict = sort_dictionary(node_dict)

    print_dict(sorted_dict, data_fullness)

    node_dict = get_node_counts(sorted_dict)

    print_node_dict(node_dict)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
