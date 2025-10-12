#!/bin/bash
#
# git $Id$
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Copyright (c) 2002-2025 The ROMS Group                                :::
#   Licensed under a MIT/X style license                                :::
#   See License_ROMS.md                                                 :::
#::::::::::::::::::::::::::::::::::::::::::::::::::::: Hernan G. Arango :::
#                                                                       :::
# ROMS-JEDI Unit Test Reference file update BASH script:                ::: 
#                                                                       :::
# It updates the reference file for a specific ROMS-JEDI Unit Test,     :::
# or a list of ROMS-JEDI Unit Tests from the LastTestsFailed.log file.  :::
# As the JEDI building blocks and the ROMS-JEDI interface evolve, the   :::
# regression data values for each test case may need to be updated.     :::
# This script facilitates such a task, which must be executed from      :::
# the "roms-jedi/build/roms-jedi/test" sub-directory.                   :::
#                                                                       :::
# Usage:                                                                :::
#                                                                       :::
#   update_testref.sh  yaml_file                                        :::
#                                                                       :::
# or                                                                    :::
#                                                                       :::
#   update_testref.sh                                                   :::
#                                                                       :::
# Options:                                                              :::
#                                                                       :::
#   yaml_file     ROMS-JEDI Unit Test input YAML filename               :::
#                                                                       :::
# Example: (executed from roms-jedi/build/roms-jedi/test)               :::                           
#                                                                       :::
#   update_testref.sh testinput/4dvar_bump.yaml                         :::
# or                                                                    :::
#   update_testref.sh 4dvar_bump.yaml                                   :::
# or                                                                    :::
#   update_testref.sh 4dvar_bump                                        :::
# or                                                                    :::
#   update_testref.sh                                                   :::
#                                                                       :::
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

from_file=1
file="../Testing/Temporary/LastTestsFailed.log"

separator=`perl -e "print '<>' x 50;"`

if [[ "$#" -eq 1 ]]; then
  testname=`basename $1 .yaml`
  tests=("${testname}")
  from_file=0
  echo $tests
fi

echo " "
echo "Current directory: ${PWD}"
echo " "

# Fill the "tests" array if the faild tests log file exists.

if [[ ${from_file} -eq 1 ]]; then
  if [[ ! -f "${file}" ]]; then
    echo "Failed test log file ${file} not found."
    exit 1
  fi

  while IFS= read -r line || [[ -n "${line}" ]]
  do
   testname=$(sed 's/.*:test_romsjedi_//' <<< "${line}")
   tests+=("${testname}")
  done < "${file}"
fi

# Update the reference files listed in the tests array

for prefix in "${tests[@]}"
do
  out_file=testoutput/${prefix}.out
  ref_file=testref/${prefix}.ref
  
  if [[ ! -f ${out_file} ]]; then
    echo "Cannot find: ${PWD}/${out_file}"
  else
    cp -fv ${out_file} ${ref_file}
  fi
done
