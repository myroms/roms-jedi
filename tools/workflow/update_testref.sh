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
# It updates the reference file for a specific ROMS-JEDI Unit Test.     :::
# As the JEDI build blocks and the ROMS-JEDI interface evolve, the      :::
# regression data values for each test case may need to be updated.     :::
# This script facilitates such a task, which must be executed from      :::
# the "roms-jedi/build/roms-jedi/test" sub-directory.                   :::
#                                                                       :::
# Usage:                                                                :::
#                                                                       :::
#   update_testref.sh  yaml_file                                        :::
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
#                                                                       :::
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

prefix=`basename $1 .yaml`

echo " "
echo "Current directory: ${PWD}"
echo " "

out_file=testoutput/${prefix}.out
ref_file=testref/${prefix}.ref

if [[ ! -f ${out_file} ]]; then
  echo "Cannot find: $(PWD)/${out_file}"
else
  cp -fv ${out_file} ${ref_file}
fi

