#!/bin/sh

JSON_FILE="master_targets.json"
OUTPUT_FILE="targets.json"

CLONE_MASTER_DIR="clones-project-v1.2.1"
CLONE_MASTER_BIN="clone-master-linux"

if [ ! -f "$JSON_FILE" ]; then
    echo "ERROR: JSON file not found: $JSON_FILE"
    exit 1
fi

command -v jq >/dev/null 2>&1 || {
    echo "ERROR: jq is not installed"
    exit 1
}

rm -f "$OUTPUT_FILE"

usage()
{
    cat << EOF
Usage:
    $0 --orig_issue_version <version> \
       --target_version <version1[,version2,...]> \
       --orig_target <platform,opco,modelName> \
       --issue <ISSUE> \
       [--filter_opco <OPCO>] \
       [--filter_project <PROJECT>] \
       [--dry-run]

    $0 --show_targets

Required options:
    --orig_issue_version
        Version where the original issue exists.

    --target_version
        Comma-separated list of target versions.

        Only versions specified here will
        generate clone targets.

    --orig_target
        Original target:
            platform,opco,modelName

    --issue
        Original issue to clone.

        Supported formats:
            GRUDZDGOS-<ticket ID> (GEN8)
            MAINSTR-<ticket ID>   (MAIN)
            GENXPON-<ticket ID>   (GENX)

Optional options:
    --filter_opco
        Restrict generated clone targets
        to a single OPCO.

        Supported values:

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

    --filter_project
        Restrict generated clone targets
        to a single project.

        Supported values:

            GRUDZDGOS
            MAINSTR
            GENXPON

    --filter_model
        Restrict generated clone targets
        to a single modelName.

    --dry-run
        Generate and display clone targets.
        Create targets.json.
        Do not invoke Clone Master.

    --show_targets
        Display the contents of
        master_targets.json and exit.

        This option must be used
        exclusively.

    --help
        Display this help message.
EOF
}

ORIG_ISSUE_VERSION=""
TARGET_VERSIONS=""
TARGET=""
ISSUE=""
FILTER_OPCO=""
FILTER_PROJECT=""
FILTER_MODEL=""
DRY_RUN=0
SHOW_TARGETS=0
OTHER_OPTIONS_USED=0

while [ $# -gt 0 ]
do
    case "$1" in
        --orig_issue_version)
            OTHER_OPTIONS_USED=1
            [ "$#" -ge 2 ] || {
                echo "ERROR: Missing value for --orig_issue_version"
                exit 1
            }
            ORIG_ISSUE_VERSION="$2"
            shift 2
            ;;

        --target_version)
            OTHER_OPTIONS_USED=1
            [ "$#" -ge 2 ] || {
                echo "ERROR: Missing value for --target_version"
                exit 1
            }
            TARGET_VERSIONS="$2"
            shift 2
            ;;

        --orig_target)
            OTHER_OPTIONS_USED=1
            [ "$#" -ge 2 ] || {
                echo "ERROR: Missing value for --orig_target"
                exit 1
            }
            TARGET="$2"
            shift 2
            ;;

        --issue)
            OTHER_OPTIONS_USED=1
            [ "$#" -ge 2 ] || {
                echo "ERROR: Missing value for --issue"
                exit 1
            }
            ISSUE="$2"
            shift 2
            ;;

        --filter_opco)
            OTHER_OPTIONS_USED=1
            [ "$#" -ge 2 ] || {
                echo "ERROR: Missing value for --filter_opco"
                exit 1
            }
            FILTER_OPCO="$2"
            shift 2
            ;;

        --filter_project)
            OTHER_OPTIONS_USED=1
            [ "$#" -ge 2 ] || {
                echo "ERROR: Missing value for --filter_project"
                exit 1
            }
            FILTER_PROJECT="$2"
            shift 2
            ;;

        --filter_model)
            OTHER_OPTIONS_USED=1
            [ "$#" -ge 2 ] || {
                echo "ERROR: Missing value for --filter_model"
                exit 1
            }
            FILTER_MODEL="$2"
            shift 2
            ;;

        --dry-run)
            OTHER_OPTIONS_USED=1

            if [ "$DRY_RUN" -eq 1 ]; then
                echo "ERROR: --dry-run specified more than once"
                exit 1
            fi

            DRY_RUN=1
            shift
            ;;

        --show_targets)
            if [ "$SHOW_TARGETS" -eq 1 ]; then
                echo "ERROR: --show_targets specified more than once"
                exit 1
            fi

            SHOW_TARGETS=1
            shift
            ;;

        --help|-h)
            usage
            exit 0
            ;;

        *)
            echo "ERROR: Unknown option '$1'"
            echo
           usage
            exit 1            ;;
    esac
done

if [ "$SHOW_TARGETS" -eq 1 ]; then

    if [ "$#" -ne 0 ]; then
        echo "ERROR: --show_targets does not accept arguments"
        exit 1
    fi

    if [ -n "$ORIG_ISSUE_VERSION" ] ||
       [ -n "$TARGET_VERSIONS" ] ||
       [ -n "$TARGET" ] ||
       [ -n "$ISSUE" ] ||
       [ -n "$FILTER_OPCO" ] ||
       [ -n "$FILTER_PROJECT" ] ||
       [ -n "$FILTER_MODEL" ] ||
       [ "$DRY_RUN" -eq 1 ]; then
        echo "ERROR: --show_targets must be used exclusively"
        exit 1
    fi

	printf "\n"
	printf "========================================================================\n"
	printf " Master Targets Information\n"
	printf "========================================================================\n\n"

	printf "Version      : %s\n" "$(jq -r '.master_file_version' master_targets.json)"
	printf "Last Updated : %s\n" "$(jq -r '.master_file_updated' master_targets.json)"

	printf "\n========================================================================\n"
    printf " Available Targets\n"
	printf "========================================================================\n"

    echo

	jq -r '
	[
	  .versions[]
	  | .project as $project
	  | .name as $version
	  | .active_targets[]
	  | {
		  project: $project,
		  version: $version,
		  platform: .platform,
		  opco: .opco,
		  model: .modelName,
		  model_extra1: (.modelNameExtra1 // "")
		}
	]
	| sort_by(.project, .version, .opco, .model)
	| .[]
	| [
		.project,
		.version,
		.platform,
		.opco,
		.model,
		.model_extra1
	  ]
	| @tsv
	' $JSON_FILE |
	awk -F '\t' '
	BEGIN {
		printf "%-10s %-8s %-8s %-10s %-12s %-12s\n",
			   "PROJECT","VERSION","PLATFORM","OPCO","MODEL","MODEL_EXTRA1"

		print "========================================================================"
	}
	{
		current_project = $1
		current_version = $2

		if (prev_project != "" && current_project != prev_project) {
			print ""
			print "========================================================================"
			print "========================================================================"
			print ""
		}
		else if (prev_version != "" && current_version != prev_version) {
			print "------------------------------------------------------------------------"
		}

		printf "%-10s %-8s %-8s %-10s %-12s %-12s\n",
			   $1, $2, $3, $4, $5, $6

		prev_project = current_project
		prev_version = current_version
	}'

    exit 0
fi

if [ -z "$ORIG_ISSUE_VERSION" ] ||
   [ -z "$TARGET_VERSIONS" ] ||
   [ -z "$TARGET" ] ||
   [ -z "$ISSUE" ]; then
    echo "ERROR: Missing required parameter(s)"
    echo
    usage
    exit 1
fi

case "$TARGET_VERSIONS" in
    *,|,*|*,,*)
        echo "ERROR: Invalid --target_version format"
        exit 1
        ;;
esac

DUPLICATES=$(echo "$TARGET_VERSIONS" | tr ',' '\n' | sort | uniq -d)

if [ -n "$DUPLICATES" ]; then
    echo "ERROR: Duplicate version(s) specified:"
    echo "$DUPLICATES"
    exit 1
fi

if [ -n "$FILTER_OPCO" ]; then
    case "$FILTER_OPCO" in
        MEO|SFR|TELEVES|GENERIC|AUS|ADO|CBB|HOT|OMT|MSS)
            ;;
        *)
            echo "ERROR: Invalid --filter_opco value '$FILTER_OPCO'"
            echo "Supported values:"
            echo "  MEO SFR TELEVES GENERIC AUS ADO CBB HOT OMT MSS"
            exit 1
            ;;
    esac
fi

if [ -n "$FILTER_PROJECT" ]; then
    case "$FILTER_PROJECT" in
        GRUDZDGOS|MAINSTR|GENXPON)
            ;;
        *)
            echo "ERROR: Invalid --filter_project value '$FILTER_PROJECT'"
            echo "Supported values:"
            echo "  GRUDZDGOS MAINSTR GENXPON"
            exit 1
            ;;
    esac
fi

case "$ISSUE" in
    GRUDZDGOS-*|MAINSTR-*|GENXPON-*)
        ISSUE_NUM=${ISSUE#*-}

        if ! echo "$ISSUE_NUM" | grep -Eq '^[1-9][0-9]*$'; then
            echo "ERROR: Invalid issue '$ISSUE'"
            exit 1
        fi
        ;;
    *)
        echo "ERROR: Invalid issue '$ISSUE'"
        exit 1
        ;;
esac

OLDIFS=$IFS
IFS=,
set -- $TARGET
IFS=$OLDIFS

if [ $# -ne 3 ]; then
    echo "ERROR: Invalid --orig_target format"
    echo "Expected: platform,opco,modelName"
    exit 1
fi

PLATFORM=$1
OPCO=$2
MODEL=$3

if ! jq -e \
    --arg version "$ORIG_ISSUE_VERSION" \
    '.versions[] | select(.name == $version)' \
    "$JSON_FILE" >/dev/null
then
    echo "ERROR: Original issue version '$ORIG_ISSUE_VERSION' not found in $JSON_FILE"
    exit 1
fi

if ! jq -e \
    --arg version "$ORIG_ISSUE_VERSION" \
    --arg platform "$PLATFORM" \
    --arg opco "$OPCO" \
    --arg model "$MODEL" '
    .versions[]
    | select(.name == $version)
    | .active_targets[]
    | select(
        .platform == $platform and
        .opco == $opco and
        .modelName == $model
    )
' "$JSON_FILE" >/dev/null
then
    echo "ERROR: Target '$TARGET' not found under original issue version '$ORIG_ISSUE_VERSION'"
    exit 1
fi

TMP_OBJECTS=$(mktemp) || {
    echo "ERROR: Failed to create temporary file"
    exit 1
}

cleanup()
{
    rm -f "$TMP_OBJECTS"
}

trap cleanup EXIT INT TERM HUP

OLDIFS=$IFS
IFS=','
set -- $TARGET_VERSIONS
IFS=$OLDIFS

for VERSION in "$@"
do
    if ! jq -e \
        --arg version "$VERSION" \
        '.versions[] | select(.name == $version)' \
        "$JSON_FILE" >/dev/null
    then
        echo "ERROR: Version '$VERSION' not found. Exiting"
        exit 1
    fi

    if [ "$VERSION" = "$ORIG_ISSUE_VERSION" ]; then

        if [ -n "$FILTER_OPCO" ]; then
            FILTER='
                select(.opco == $filter_opco)
                | select(
                    (.platform != $platform) or
                    (.opco != $opco) or
                    (.modelName != $model)
                )
            '
        else
            FILTER='
                select(
                    (.platform != $platform) or
                    (.opco != $opco) or
                    (.modelName != $model)
                )
            '
        fi

    else

        if [ -n "$FILTER_OPCO" ]; then
            FILTER='select(.opco == $filter_opco)'
        else
            FILTER='.'
        fi

    fi

	if [ -n "$FILTER_MODEL" ]; then
		MODEL_FILTER='select(.modelName == $filter_model)'
	else
		MODEL_FILTER='.'
	fi

    jq -c \
        --arg version "$VERSION" \
        --arg platform "$PLATFORM" \
        --arg opco "$OPCO" \
        --arg model "$MODEL" \
        --arg filter_opco "$FILTER_OPCO" \
        --arg filter_project "$FILTER_PROJECT" \
		--arg filter_model "$FILTER_MODEL" \
        "
        .versions[]
        | select(.name == \$version)
        | select(
            \$filter_project == \"\"
            or .project == \$filter_project
        )
        | . as \$v
		| \$v.active_targets[]
		| $MODEL_FILTER
		| $FILTER
		| {
            project: \$v.project,
            fixVersions: [\$version],
            affectsVersions: [\$version],
            labels: ( [.platform, .opco, .modelName, .modelNameExtra1]| map(select(.)) ),
            linkType: \"Cloners\"
        }
        " "$JSON_FILE" >> "$TMP_OBJECTS" || {
            echo "ERROR: Failed to process version '$VERSION'"
            exit 1
        }
done

ENTRY_COUNT=$(wc -l < "$TMP_OBJECTS")

if [ "$ENTRY_COUNT" -eq 0 ]; then
    echo "INFO: No clone targets generated. Exiting."
    exit 1
fi

jq -s '.' "$TMP_OBJECTS" > "$OUTPUT_FILE" || {
    echo "ERROR: Failed to create $OUTPUT_FILE"
    exit 1
}

TOTAL_CLONES=$(jq length "$OUTPUT_FILE") || {
    echo "ERROR: Failed to read generated $OUTPUT_FILE"
    exit 1
}

jq -r \
    --arg issue "$ISSUE" '
    group_by(.fixVersions[0] + "|" + .project)[]
    | "Preparing to clone original issue \($issue)"
      + " for project "
      + .[0].project
      + ": "
      + (map(.labels | join(",")) | join(" "))
      + " for version \""
      + .[0].fixVersions[0]
	  + "\""
' "$OUTPUT_FILE"

echo "Total clones to create: $TOTAL_CLONES"

echo "Created $OUTPUT_FILE"

if [ "$DRY_RUN" -eq 1 ]; then
    echo "Dry-run mode enabled."
    echo "$OUTPUT_FILE generated successfully."
    echo "Clone Master invocation skipped."
    exit 0
fi

mv $OUTPUT_FILE $CLONE_MASTER_DIR

cd $CLONE_MASTER_DIR

if [ ! -e "$CLONE_MASTER_BIN" ]; then
    echo "ERROR: Clone Master script not found: $CLONE_MASTER_BIN"
    exit 1
fi

if [ ! -f "$CLONE_MASTER_BIN" ]; then
    echo "ERROR: Clone Master path is not a regular file: $CLONE_MASTER_BIN"
    exit 1
fi

if [ ! -x "$CLONE_MASTER_BIN" ]; then
    echo "ERROR: Clone Master script is not executable: $CLONE_MASTER_BIN"
    exit 1
fi

echo "Calling Clone Master..."

"./$CLONE_MASTER_BIN" "$ISSUE"
CLONE_MASTER_RC=$?

if [ "$CLONE_MASTER_RC" -ne 0 ]; then
    echo "ERROR: Clone Master failed with return code $CLONE_MASTER_RC"
    exit "$CLONE_MASTER_RC"
fi

cd -

echo "Clone Master Done!"
