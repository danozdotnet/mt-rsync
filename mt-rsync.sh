#!/bin/bash
# run multiple instances of rsync across a SOURCE/TARGET sync

# remove ending / if they exist
SOURCE=$(sed 's/\/$//' <<< "${1}")
TARGET=$(sed 's/\/$//' <<< "${2}")

# if target does not exist, create it
if [[ ! -d "${TARGET}" ]]
then
  mkdir "${TARGET}"
fi

# depth to traverse, how many processes to run, time to check threads are running
DEPTH="1"
PROCS="5"
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
    # work out subfolder
    SUBFOLDER=$(sed "s/$(sed 's/[\/&]/\\&/g' <<< "${SOURCE}")//" <<< "${DIR}") 
    if [[ ! -d "${TARGET}${SUBFOLDER}" ]]
    then
      # create TARGET subfolders, copy permissions from SOURCE
      mkdir -p "${TARGET}${SUBFOLDER}"
      chown --reference="${SOURCE}${SUBFOLDER}" "${TARGET}${SUBFOLDER}"
      chmod --reference="${SOURCE}${SUBFOLDER}" "${TARGET}${SUBFOLDER}"
    fi

    # Check there are the correct number of rsync processes are running
    while [[ "$(pgrep -c [r]sync)" -gt "${PROCS}" ]]
    do
      sleep "${SLEEP}"
    done
  
    # Run rsync in background for the current SUBFOLDER and move on to the next one
    nohup rsync -a "${SOURCE}${SUBFOLDER}/" "${TARGET}${SUBFOLDER}/" </dev/null >/dev/null 2>&1 &
  fi
done

# Find all files above the maxdepth level and rsync them so they're not forgotten
find "${SOURCE}" -maxdepth "${DEPTH}" -type f -print0 | rsync -a --files-from=- --from0 ./ "${TARGET}/"
