#!/bin/bash
# run multiple instances of rsync across a SOURCE/TARGET sync

# remove ending / if it exists
SOURCE=$(sed 's/\/$//' <<< "${1}")
TARGET=$(sed 's/\/$//' <<< "${2}")

# depth to traverse, how many threads to run, time to check threads are running
DEPTH="1"
THREADS="5"
SLEEP="5"

# remember depth of source directory
SRCDEPTH=$(awk -F'/' '{print NF}' <<< "${SOURCE}")

# Find all folders in the SOURCE directory DEPTH specified
find "${SOURCE}" -maxdepth "${DEPTH}" -type d | while read -r DIR
do
    DIRDEPTH=$(awk -F'/' '{print NF}' <<< "${DIR}")
    # Make sure to ignore the parent folder
    if [[ "${DIRDEPTH}" -gt "${SRCDEPTH}" ]]
    then
        SUBFOLDER=$(sed "s/$(sed -e 's/[\/&]/\\&/g' <<< "${SOURCE}")//" <<< "${DIR}") 
        if [[ ! -d "${TARGET}${SUBFOLDER}" ]]
        then
            # create TARGET subfolders, copy permissions from SOURCE
            mkdir -p "${TARGET}${SUBFOLDER}"
            chown --reference="${SOURCE}${SUBFOLDER}" "${TARGET}${SUBFOLDER}"
            chmod --reference="${SOURCE}${SUBFOLDER}" "${TARGET}${SUBFOLDER}"
        fi
        # Check there are the correct number of rsync 'threads' running
        while [[ "$(pgrep -c [r]sync)" -gt "${THREADS}" ]]
        do
            sleep "${SLEEP}"
        done
        # Run rsync in background for the current SUBFOLDER and move on to the next one
        nohup rsync -a "${SOURCE}/${SUBFOLDER}/" "${TARGET}/${SUBFOLDER}/" </dev/null >/dev/null 2>&1 &
    fi
done

# Find all files above the maxdepth level and rsync them as well
find "${SOURCE}" -maxdepth "${DEPTH}" -type f -print0 | rsync -a --files-from=- --from0 ./ "${TARGET}/"
