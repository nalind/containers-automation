
# This file is intended for sourcing by the cirrus-ci_retrospective workflow
# It should not be used under any other context.

source $(dirname ${BASH_SOURCE[0]})/github_common.sh || exit 1

# Cirrus-CI Build status codes that represent completion
COMPLETE_STATUS_RE='FAILED|COMPLETED|ABORTED|ERRORED'

# Shell variables used throughout this workflow
prn=
tid=
sha=
tst=
was_pr='false'
do_intg='false'

dbg_ccir() {
    dbg "Shell variables set:"
    dbg "Cirrus-CI ran on pr: $was_pr"
    dbg "Monitor PR Number: ${prn}"
    dbg "Monitor SHA: ${sha}"
    dbg "Action Task ID was: ${tid}"
    dbg "Action Task Status: ${tst}"
    dbg "Do integration testing: ${do_intg}"
}

# usage: load_ccir <path to cirrus-ci_retrospective.json>
load_ccir() {
    local dirpath="$1"
    local ccirjson="$1/cirrus-ci_retrospective.json"

    [[ -d "$dirpath" ]] || \
        die "Expecting a directory path '$dirpath'"
    [[ -r "$ccirjson" ]] || \
        die "Can't read file '$ccirjson'"

    [[ -n "$MONITOR_TASK" ]] || \
        die "Expecting \$MONITOR_TASK to be non-empty"
    [[ -n "$ACTION_TASK" ]] || \
        die "Expecting \$MONITOR_TASK to be non-empty"

    dbg "--Loading Cirrus-CI monitoring task $MONITOR_TASK--"
    dbg "$(jq --indent 4 '.[] | select(.name == "'${MONITOR_TASK}'")' $ccirjson)"
    bst=$(jq --raw-output '.[] | select(.name == "'${MONITOR_TASK}'") | .build.status' "$ccirjson")
    prn=$(jq --raw-output '.[] | select(.name == "'${MONITOR_TASK}'") | .build.pullRequest' "$ccirjson")
    sha=$(jq --raw-output '.[] | select(.name == "'${MONITOR_TASK}'") | .build.changeIdInRepo' "$ccirjson")

    dbg "--Loadinng Cirrus-CI action task $ACTION_TASK--"
    dbg "$(jq --indent 4 '.[] | select(.name == "'${ACTION_TASK}'")' $ccirjson)"
    tid=$(jq --raw-output '.[] | select(.name == "'${ACTION_TASK}'") | .id' "$ccirjson")
    tst=$(jq --raw-output '.[] | select(.name == "'${ACTION_TASK}'") | .status' "$ccirjson")

    for var in bst prn sha; do
        [[ -n "${!var}" ]] || \
            die "Expecting \$$var to be non-empty after loading $ccirjson" 42
    done

    was_pr='false'
    do_intg='false'
    if [[ -n "$prn" ]] && [[ "$prn" != "null" ]] && [[ $prn -gt 0 ]]; then
        dbg "Detected pull request $prn"
        was_pr='true'
        # Don't race vs another cirrus-ci build triggered _after_ GH action workflow started
        # since both may share the same check_suite. e.g. task re-run or manual-trigger
        if echo "$bst" | grep -E -q "$COMPLETE_STATUS_RE"; then
            if [[ -n "$tst" ]] && [[ "$tst" == "PAUSED" ]]; then
                dbg "Detected action status $tst"
                do_intg='true'
            fi
        else
            warn "Unexpected build status '$bst', was a task re-run or manually triggered?"
        fi
    fi
    dbg_ccir
}

set_ccir() {
    for varname in prn tid sha tst was_pr do_intg; do
        set_out_var $varname "${!varname}"
    done
}
