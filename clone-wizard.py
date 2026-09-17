#!/usr/bin/env python3

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from collections import defaultdict

JSON_FILE = "master_targets.json"
OUTPUT_FILE = "targets.json"
CLONE_MASTER_DIR = "clones-project-v1.2.1"
CLONE_MASTER_BIN = "clone-master-win.exe"

VALID_OPCOS = {
    "MEO",
    "SFR",
    "TELEVES",
    "GENERIC",
    "AUS",
    "ADO",
    "CBB",
    "HOT",
    "OMT",
    "MSS",
}

VALID_PROJECTS = {
    "GRUDZDGOS",
    "MAINSTR",
    "GENXPON",
}


def error(msg):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def load_json():
    if not os.path.isfile(JSON_FILE):
        error(f"JSON file not found: {JSON_FILE}")

    with open(JSON_FILE, "r", encoding="utf-8") as f:
        return json.load(f)


def validate_issue(issue):
    if not re.match(r"^(GRUDZDGOS|MAINSTR|GENXPON)-[1-9][0-9]*$", issue):
        error(f"Invalid issue '{issue}'")


def parse_versions(version_string):
    if not version_string:
        return []

    parts = version_string.split(",")

    if "" in parts:
        error("Invalid --target_version format")

    duplicates = sorted(
        set(v for v in parts if parts.count(v) > 1)
    )

    if duplicates:
        print("ERROR: Duplicate version(s) specified:")
        for d in duplicates:
            print(d)
        sys.exit(1)

    return parts


def get_version(json_data, version_name):
    for version in json_data["versions"]:
        if version["name"] == version_name:
            return version
    return None


def validate_orig_target(version_obj, platform, opco, model):
    for target in version_obj["active_targets"]:
        if (
            target.get("platform") == platform and
            target.get("opco") == opco and
            target.get("modelName") == model
        ):
            return

    error(
        f"Target '{platform},{opco},{model}' "
        f"not found under version "
        f"'{version_obj['name']}'"
    )


def print_show_targets(json_data):

    print()
    print("========================================================================")
    print(" Master Targets Information")
    print("========================================================================")
    print()

    print(
        f"Version      : "
        f"{json_data.get('master_file_version','')}"
    )

    print(
        f"Last Updated : "
        f"{json_data.get('master_file_updated','')}"
    )

    print()
    print("========================================================================")
    print(" Available Targets")
    print("========================================================================")
    print()

    rows = []

    for version in json_data["versions"]:
        for target in version["active_targets"]:

            rows.append({
                "project": version["project"],
                "version": version["name"],
                "platform": target.get("platform", ""),
                "opco": target.get("opco", ""),
                "model": target.get("modelName", ""),
                "extra": target.get("modelNameExtra1", ""),
            })

    rows.sort(
        key=lambda x: (
            x["project"],
            x["version"],
            x["opco"],
            x["model"]
        )
    )

    print(
        f"{'PROJECT':10} "
        f"{'VERSION':8} "
        f"{'PLATFORM':8} "
        f"{'OPCO':10} "
        f"{'MODEL':12} "
        f"{'MODEL_EXTRA1':12}"
    )

    print("========================================================================")

    prev_project = None
    prev_version = None

    for row in rows:

        if (
            prev_project is not None and
            row["project"] != prev_project
        ):
            print()
            print("========================================================================")
            print("========================================================================")
            print()

        elif (
            prev_version is not None and
            row["version"] != prev_version
        ):
            print("------------------------------------------------------------------------")

        print(
            f"{row['project']:10} "
            f"{row['version']:8} "
            f"{row['platform']:8} "
            f"{row['opco']:10} "
            f"{row['model']:12} "
            f"{row['extra']:12}"
        )

        prev_project = row["project"]
        prev_version = row["version"]
		

def build_parser():

    parser = argparse.ArgumentParser(
        description="Clone Wizard",
        add_help=True
    )

    parser.add_argument(
        "--orig_issue_version"
    )

    parser.add_argument(
        "--target_version"
    )

    parser.add_argument(
        "--orig_target"
    )

    parser.add_argument(
        "--issue"
    )

    parser.add_argument(
        "--filter_opco"
    )

    parser.add_argument(
        "--filter_project"
    )

    parser.add_argument(
        "--filter_model"
    )

    parser.add_argument(
        "--dry-run",
        action="store_true",
        dest="dry_run"
    )

    parser.add_argument(
        "--show_targets",
        action="store_true"
    )

    return parser


def validate_args(args):

    if args.show_targets:

        used = any([
            args.orig_issue_version,
            args.target_version,
            args.orig_target,
            args.issue,
            args.filter_opco,
            args.filter_project,
            args.filter_model,
            args.dry_run
        ])

        if used:
            error(
                "--show_targets must be used exclusively"
            )

        return

    required = [
        args.orig_issue_version,
        args.target_version,
        args.orig_target,
        args.issue
    ]

    if any(not x for x in required):
        error("Missing required parameter(s)")

    if args.filter_opco:

        if args.filter_opco not in VALID_OPCOS:
            error(
                f"Invalid --filter_opco value "
                f"'{args.filter_opco}'"
            )

    if args.filter_project:

        if args.filter_project not in VALID_PROJECTS:
            error(
                f"Invalid --filter_project value "
                f"'{args.filter_project}'"
            )

    validate_issue(args.issue)


def parse_orig_target(value):

    parts = value.split(",")

    if len(parts) != 3:
        error(
            "Invalid --orig_target format. "
            "Expected: platform,opco,modelName"
        )

    return (
        parts[0],
        parts[1],
        parts[2]
    )


def validate_versions_exist(
    json_data,
    orig_issue_version,
    versions
):

    orig_version = get_version(
        json_data,
        orig_issue_version
    )

    if orig_version is None:
        error(
            f"Original issue version "
            f"'{orig_issue_version}' "
            f"not found"
        )

    for version in versions:

        if get_version(
            json_data,
            version
        ) is None:

            error(
                f"Version '{version}' not found"
            )

    return orig_version
	
def target_matches(
    target,
    filter_opco,
    filter_model
):

    if (
        filter_opco and
        target.get("opco") != filter_opco
    ):
        return False

    if (
        filter_model and
        target.get("modelName") != filter_model
    ):
        return False

    return True


def build_labels(target):

    labels = [
        target.get("platform"),
        target.get("opco"),
        target.get("modelName"),
        target.get("modelNameExtra1")
    ]

    return [
        x for x in labels
        if x not in (None, "")
    ]


def generate_targets(
    json_data,
    orig_issue_version,
    versions,
    platform,
    opco,
    model,
    filter_opco,
    filter_project,
    filter_model
):

    results = []

    for version_name in versions:

        version_obj = get_version(
            json_data,
            version_name
        )

        if (
            filter_project and
            version_obj["project"] !=
            filter_project
        ):
            continue

        for target in version_obj[
            "active_targets"
        ]:

            if not target_matches(
                target,
                filter_opco,
                filter_model
            ):
                continue

            exclude_original = (
                version_name ==
                orig_issue_version
            )

            if exclude_original:

                if (
                    target.get("platform")
                    == platform
                    and
                    target.get("opco")
                    == opco
                    and
                    target.get("modelName")
                    == model
                ):
                    continue

            entry = {
                "project":
                    version_obj["project"],

                "fixVersions":
                    [version_name],

                "affectsVersions":
                    [version_name],

                "labels":
                    build_labels(target),

                "linkType":
                    "Cloners"
            }

            results.append(entry)

    return results
	
def write_targets_json(entries):

    with open(
        OUTPUT_FILE,
        "w",
        encoding="utf-8"
    ) as f:

        json.dump(
            entries,
            f,
            indent=4
        )


def print_summary(entries, issue):

    groups = defaultdict(list)

    for entry in entries:

        key = (
            entry["project"],
            entry["fixVersions"][0]
        )

        groups[key].append(entry)

    for (
        project,
        version
    ), items in groups.items():

        labels = []

        for item in items:

            labels.append(
                ",".join(item["labels"])
            )

        print(
            f"Preparing to clone "
            f"original issue {issue} "
            f"for project {project}: "
            f"{' '.join(labels)} "
            f'for version "{version}"'
        )

    print(
        f"Total clones to create: "
        f"{len(entries)}"
    )

    print(
        f"Created {OUTPUT_FILE}"
    )
	
def run_clone_master(issue):

    target_file = os.path.join(
        CLONE_MASTER_DIR,
        OUTPUT_FILE
    )

    shutil.move(
        OUTPUT_FILE,
        target_file
    )

    clone_bin = os.path.join(
        CLONE_MASTER_DIR,
        CLONE_MASTER_BIN
    )

    if not os.path.exists(clone_bin):
        error(
            f"Clone Master script "
            f"not found: {clone_bin}"
        )

    if not os.path.isfile(clone_bin):
        error(
            f"Clone Master path is "
            f"not a regular file: "
            f"{clone_bin}"
        )

    print("Calling Clone Master...")

    rc = subprocess.call(
        [clone_bin, issue],
        cwd=CLONE_MASTER_DIR
    )

    if rc != 0:
        error(
            f"Clone Master failed "
            f"with return code {rc}"
        )

    print("Clone Master Done!")


def main():

    parser = build_parser()

    args = parser.parse_args()

    validate_args(args)

    json_data = load_json()

    if args.show_targets:
        print_show_targets(json_data)
        return

    versions = parse_versions(
        args.target_version
    )

    (
        platform,
        opco,
        model
    ) = parse_orig_target(
        args.orig_target
    )

    orig_version = (
        validate_versions_exist(
            json_data,
            args.orig_issue_version,
            versions
        )
    )

    validate_orig_target(
        orig_version,
        platform,
        opco,
        model
    )

    entries = generate_targets(
        json_data,
        args.orig_issue_version,
        versions,
        platform,
        opco,
        model,
        args.filter_opco,
        args.filter_project,
        args.filter_model
    )

    if not entries:

        print(
            "INFO: No clone targets "
            "generated. Exiting."
        )

        sys.exit(1)

    write_targets_json(entries)

    print_summary(
        entries,
        args.issue
    )

    if args.dry_run:

        print(
            "Dry-run mode enabled."
        )

        print(
            "Clone Master invocation "
            "skipped."
        )

        return

    run_clone_master(
        args.issue
    )


if __name__ == "__main__":
    main()
