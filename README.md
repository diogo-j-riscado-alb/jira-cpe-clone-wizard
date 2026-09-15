# Clone Wizard

A command-line utility that generates clone targets from `master_targets.json` and optionally invokes **Clone Master** to create cloned issues automatically. Based on user-specified versions, targets, and filters, the script generates a `targets.json` file containing the clone definitions.

---

# Overview

`clone-wizard.sh` helps automate issue cloning across multiple:

- Projects
- Software versions
- OPCOs
- Device models

The script:

1. Validates input parameters.
2. Reads available targets from `master_targets.json`.
3. Generates matching clone targets.
4. Creates `targets.json`.
5. Optionally invokes `clone-master-linux` to perform the actual cloning.

---

# Features

- Support for multiple target versions.
- Target filtering by OPCO.
- Target filtering by project.
- Target filtering by model.
- Dry-run mode.
- Validation of issue IDs and target definitions.
- Listing available targets.
- Automatic inclusion of `modelNameExtra1` labels when present.
- POSIX shell compatible.

---

# Requirements

## Dependencies

### jq

The script requires:

```bash
jq
```

### Input JSON

The following file must exist in the current directory:

```text
master_targets.json
```

### Clone Master

To perform actual cloning:

```text
clones-project-v1.2.1/
└── clone-master-linux
```

---

# Usage

## Clone Issues

```bash
./clone-wizard.sh \
    --orig_issue_version <version> \
    --target_version <version1[,version2,...]> \
    --orig_target <platform,opco,modelName> \
    --issue <ISSUE> \
    [--filter_opco <OPCO>] \
    [--filter_project <PROJECT>] \
    [--filter_model <MODEL>] \
    [--dry-run]
```

## Show Available Targets

```bash
./clone-wizard.sh --show_targets
```

---

# Parameters

## Required Parameters

### `--orig_issue_version`

Version where the original issue currently exists.

### `--target_version`

Comma-separated list of versions where clones should be generated.

### `--orig_target`

Format:

```text
platform,opco,modelName
```

### `--issue`

Supported formats:

```text
GRUDZDGOS-1234
MAINSTR-5678
GENXPON-9999
```

## Optional Parameters

### `--filter_opco`

Supported values:

```text
MEO
SFR
TELEVES
GENERIC
AUS
ADO
CBB
HOT
OMT
MSS
```

### `--filter_project`

Supported values:

```text
GRUDZDGOS
MAINSTR
GENXPON
```

### `--filter_model`

Restrict generated targets to a specific model.

### `--dry-run`

Generate targets without invoking Clone Master.

### `--show_targets`

Displays all available targets.

---

# Output File

The script generates:

```text
targets.json
```

Example:

```json
{
  "project": "GENXPON",
  "fixVersions": ["8.1.0"],
  "affectsVersions": ["8.1.0"],
  "labels": ["GPON","MEO","GR241AG","GR241AGV2"],
  "linkType": "Cloners"
}
```

---

# Exit Codes

- 0: Success
- 1: Validation or processing error
- Clone Master return code: propagated to caller
