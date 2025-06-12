#!/bin/bash
#
# git $Id$
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Copyright (c) 2002-2025 The ROMS Group                                :::
#   Licensed under a MIT/X style license                                :::
#   See License_ROMS.md                                                 :::
#::::::::::::::::::::::::::::::::::::::::::::::::::::: Hernan G. Arango :::
#                                                                       :::
# ROMS-JEDI Configuration BASH Script:                                  :::
#                                                                       :::
# It facilitates the configuratuon of any ROMS-JEDI application. It     :::
# two working sub-directories "Bundle_suffix" and "build_suffix"        :::
# containing all the necessary files to compile, link, and run. The     :::
# default application is "WC13" if not specified.                       :::
#                                                                       :::
# Bundle_suffix:  CMakeList.txt and source code                         :::
#                                                                       :::
# build_suffix:   Compiled code, execuatlables, YAML files, and data    :::
#                                                                       :::
#                   build_suffix/bin                                    :::
#                   build_suffix/roms-jedi/test                         :::
#                   build_suffix/roms-jedi/test/Data                    :::
#                                                                       :::
# Usage:                                                                :::
#                                                                       :::
#  jedi_config.sh suffix [options]                                      :::
#                                                                       :::
# Options:                                                              :::
#                                                                       :::
#  suffix                Configuration sub-directories suffix           :::
#                                                                       :::
#                           jedi_config.sh suffix                       :::
#                                                                       :::
#  -a app_name app_dir   Configure another ROMS-JEDI application        :::
#                                                                       :::
#                          jedi_config.sh suffix -a app_name app_dir    :::
#                                                                       :::
#                          where app_name is ROMS application CPP       :::
#                                app_dir  is application data path      :::
#                                                                       :::
#  -d                    Congifure 'ecbuild' with 'Debug' build type    :::
#                                                                       :::
#                          jedi_config.sh suffix -d                     :::
#                                                                       :::
# Example: (suffix = wc12)                                              :::
#                                                                       :::
#   jedi_config.sh wc12 -a WC12 /home/arango/ROMS/JediApps/wc12         :::
#                                                                       :::
#   It creates the "build_wc12" and "Bundle_wc12" sub-directories and   :::
#   the command line needed to start the configuration:                 :::
#                                                                       :::
#   cd build_wc12;                                                      :::
#   ecbuild -DMPIEXEC_EXECUTABLE=$MPIRUN ...                            :::
#                                                                       :::
# Sometimes during "ecbuild" configuration, we may get an error of      :::
# missing Python3::Python. Thus, we added the following macro to the    :::
# "ecbuild" command:                                                    :::
#                                                                       :::
#   -DPython3_EXECUTABLE="`which python3`"                              :::
#                                                                       :::
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

separator=`perl -e "print '<>' x 50;"`

debug=0
other_app=0
NUMPROC=12                 # number of processors other application

while [ $# -gt 0 ]
do
  case "$1" in
    -a )
      shift
      other_app=1
      ROMSAPP=`echo $1 | tr "[a-z]" "[A-Z]"`
      shift
      APP_DIR=$1
      shift
      ;;

    -d )
      shift
      debug=1
      ;;

    * )
      suffix=$1
      shift
      ;;
  esac
done

echo " "
echo "Current directory: ${PWD}"
echo " "

# Create "Bundle_" sub_directory.

Bundle=Bundle_${suffix}

if [[ ! -d ${Bundle} ]]; then
  mkdir ${Bundle}
else
 echo "Removing existing sub-diretory: ${Bundle}"
 /bin/rm -rf ${Bundle}
 mkdir ${Bundle}
fi
echo "Created sub-diretory: ${Bundle}"

# Create "build_" sub-directory.

build=build_${suffix}

if [[ ! -d ${build} ]]; then
  mkdir ${build}
else
 echo "Removing existing sub-diretory: ${build}"
 /bin/rm -rf ${build}
 mkdir ${build}
fi
echo "Created sub-diretory: ${build}"

# Copy ROMS-JEDI "bundle/.gitignore" and "bundle/CMakeLists.txt".

echo " "
cp -v bundle/.gitignore ${Bundle}
cp -v bundle/CMakeLists.txt ${Bundle}
echo " "

# Configure with "ecbuild".

if [[ ${debug} -eq 1 ]]; then
  echo "${separator}"
  echo "To configure 'ecbuild' with 'Debug' build you need to type:"
  echo " "
  if [[ ${other_app} -eq 1 ]]; then
    echo "cd ${build};"  
    if [[ "${ROMSAPP}" == "WC13" ]]; then
      echo ecbuild -DMPIEXEC_EXECUTABLE=\$MPIRUN -DMPIEXEC_NUMPROC_FLAG=\"-n\" -DPython3_EXECUTABLE=\"\`which python3\`\" -DROMS_APP=${ROMSAPP} -DROMS_APP_DIR=${APP_DIR} -DCMAKE_BUILD_TYPE=Debug ../${Bundle}
    else
      echo ecbuild -DMPIEXEC_EXECUTABLE=\$MPIRUN -DMPIEXEC_NUMPROC_FLAG=\"-n\" -DMPIEXEC_NUMPROC=12 -DPython3_EXECUTABLE=\"\`which python3\`\" -DROMS_APP=${ROMSAPP} -DROMS_APP_DIR=${APP_DIR} -DCMAKE_BUILD_TYPE=Debug ../${Bundle}
    fi
    echo "${separator}"
  else
    echo "cd ${build};"  
    echo ecbuild -DMPIEXEC_EXECUTABLE=\$MPIRUN -DMPIEXEC_NUMPROC_FLAG=\"-n\" -DPython3_EXECUTABLE=\"\`which python3\`\" -DCMAKE_BUILD_TYPE=Debug ../${Bundle}
    echo "${separator}"
  fi
else
  echo "${separator}"
  echo "To configure 'ecbuild' with 'Release' build you need to type:"
  echo " "
  if [[ ${other_app} -eq 1 ]]; then
    echo "cd ${build};"
    if [[ "${ROMSAPP}" == "WC13" ]]; then
      echo ecbuild -DMPIEXEC_EXECUTABLE=\$MPIRUN -DMPIEXEC_NUMPROC_FLAG=\"-n\" -DPython3_EXECUTABLE=\"\`which python3\`\" -DROMS_APP=${ROMSAPP} -DROMS_APP_DIR=${APP_DIR} -DCMAKE_BUILD_TYPE=Release ../${Bundle}
    else
      echo ecbuild -DMPIEXEC_EXECUTABLE=\$MPIRUN -DMPIEXEC_NUMPROC_FLAG=\"-n\" -DMPIEXEC_NUMPROC=12 -DPython3_EXECUTABLE=\"\`which python3\`\" -DROMS_APP=${ROMSAPP} -DROMS_APP_DIR=${APP_DIR} -DCMAKE_BUILD_TYPE=Release ../${Bundle}
    fi
    echo "${separator}"
  else
    echo "cd ${build};"  
    echo ecbuild -DMPIEXEC_EXECUTABLE=\$MPIRUN -DMPIEXEC_NUMPROC_FLAG=\"-n\" -DPython3_EXECUTABLE=\"\`which python3\`\" -DCMAKE_BUILD_TYPE=Release ../${Bundle}
    echo "${separator}"
  fi
fi
