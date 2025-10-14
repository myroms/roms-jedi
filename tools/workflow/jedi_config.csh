#!/bin/csh -f
#
# git $Id$
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Copyright (c) 2002-2025 The ROMS Group                                :::
#   Licensed under a MIT/X style license                                :::
#   See License_ROMS.md                                                 :::
#::::::::::::::::::::::::::::::::::::::::::::::::::::: Hernan G. Arango :::
#                                                                       :::
# ROMS-JEDI Configuration CSH Script:                                   :::
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
#  jedi_config.csh suffix [options]                                     :::
#                                                                       :::
# Options:                                                              :::
#                                                                       :::
#  suffix                Configuration sub-directories suffix           :::
#                                                                       :::
#                           jedi_config.csh suffix                      :::
#                                                                       :::
#  -a app_name app_dir   Configure another ROMS-JEDI application        :::
#                                                                       :::
#                          jedi_config.csh suffix -a app_name app_dir   :::
#                                                                       :::
#                          where app_name is ROMS application CPP       :::
#                                app_dir  is application data path      :::
#                                                                       :::
#  -d                    Congifure 'ecbuild' with 'Debug' build type    :::
#                                                                       :::
#                          jedi_config.csh suffix -d                    :::
#                                                                       :::
#  -n_min NP_min         Minimum number of MPI processes for tests      :::
#                          NP_min = 2 by default                        :::
#                                                                       :::
#  -n NP                 Number of MPI processes for costly algorithms  :::
#                          NP = 12 by default                           :::
#                                                                       :::
# Example: (suffix = wc12)                                              :::
#                                                                       :::
#   jedi_config.csh wc12 -a WC12 /home/arango/ROMS/JediApps/wc12 -n 16  :::
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

set separator = `perl -e "print '<>' x 50;"`

set debug = 0
set other_app = 0
set min_set = 0
set max_set = 0
set NP_min = 2
set NP = 12              # number of processors other application

while ( ($#argv) > 0 )
  switch ($1)
    case "-a"
      set other_app = 1
      shift
      set ROMSAPP = `echo $1 | tr "[a-z]" "[A-Z]"`
      shift
      set APP_DIR = $1
      shift
    breaksw

    case "-d"
      set debug = 1
      shift
    breaksw

    case "-n_min"
      shift
      set min_set = 1
      set NP_min = $1
      shift
    breaksw

    case "-n"
      shift
      set max_set = 1
      set NP = $1
      shift
    breaksw

    case "*":
      set suffix = $1
      shift
     breaksw

  endsw
end

set procs_conf = ""
if ( ${min_set} == 1 ) then
  set procs_conf = "${procs_conf} -DMPIEXEC_NUMPROC_MIN=${NP_min}"
endif
if ( ${max_set} == 1 ) then
  set procs_conf = "${procs_conf} -DMPIEXEC_NUMPROC=${NP}"
endif


echo " "
echo "Current directory: ${PWD}"
echo " "

# Create "Bundle_" sub_directory.

set Bundle=Bundle_${suffix}

if (! -d ${Bundle}) then
  mkdir ${Bundle}
else
 echo "Removing existing sub-diretory: ${Bundle}"
 /bin/rm -rf ${Bundle}
 mkdir ${Bundle}
endif
echo "Created sub-diretory: ${Bundle}"

# Create "build_" sub-directory.

set build=build_${suffix}

if (! -d ${build}) then
  mkdir ${build}
else
 echo "Removing existing sub-diretory: ${build}"
 /bin/rm -rf ${build}
 mkdir ${build}
endif
echo "Created sub-diretory: ${build}"

# Copy ROMS-JEDI "bundle/.gitignore" and "bundle/CMakeLists.txt".

echo " "
cp -v bundle/.gitignore ${Bundle}
cp -v bundle/CMakeLists.txt ${Bundle}
echo " "

# Configure with "ecbuild".

if ( ${debug} == 1 ) then
  echo "${separator}"
  echo "To configure 'ecbuild' with 'Debug' build, you need to type:"
  echo " "
  echo "cd ${build};"  
  if ( ${other_app} == 1 ) then
    if ( ${ROMSAPP} == "WC13" ) then
      echo ecbuild -DMPIEXEC_EXECUTABLE=\$MPIRUN -DMPIEXEC_NUMPROC_FLAG=\"-n\" ${procs_conf} -DPython3_EXECUTABLE=\"\`which python3\`\" -DROMS_APP=${ROMSAPP} -DROMS_APP_DIR=${APP_DIR} -DCMAKE_BUILD_TYPE=Debug ../${Bundle}
    else
      echo ecbuild -DMPIEXEC_EXECUTABLE=\$MPIRUN -DMPIEXEC_NUMPROC_FLAG=\"-n\" ${procs_conf} -DPython3_EXECUTABLE=\"\`which python3\`\" -DROMS_APP=${ROMSAPP} -DROMS_APP_DIR=${APP_DIR} -DCMAKE_BUILD_TYPE=Debug ../${Bundle}
    endif
  else
    echo ecbuild -DMPIEXEC_EXECUTABLE=\$MPIRUN -DMPIEXEC_NUMPROC_FLAG=\"-n\" ${procs_conf} -DPython3_EXECUTABLE=\"\`which python3\`\" -DCMAKE_BUILD_TYPE=Debug ../${Bundle}
  endif
  echo "${separator}"
else
  echo "${separator}"
  echo "To configure 'ecbuild' with 'Release' build, you need to type:"
  echo " "
  echo "cd ${build};"
  if ( ${other_app} == 1 ) then
    if ( ${ROMSAPP} == "WC13" ) then
      echo ecbuild -DMPIEXEC_EXECUTABLE=\$MPIRUN -DMPIEXEC_NUMPROC_FLAG=\"-n\" ${procs_conf} -DPython3_EXECUTABLE=\"\`which python3\`\" -DROMS_APP=${ROMSAPP} -DROMS_APP_DIR=${APP_DIR} -DCMAKE_BUILD_TYPE=Release ../${Bundle}
    else
      echo ecbuild -DMPIEXEC_EXECUTABLE=\$MPIRUN -DMPIEXEC_NUMPROC_FLAG=\"-n\" ${procs_conf} -DPython3_EXECUTABLE=\"\`which python3\`\" -DROMS_APP=${ROMSAPP} -DROMS_APP_DIR=${APP_DIR} -DCMAKE_BUILD_TYPE=Release ../${Bundle}
    endif
  else
    echo ecbuild -DMPIEXEC_EXECUTABLE=\$MPIRUN -DMPIEXEC_NUMPROC_FLAG=\"-n\" ${procs_conf} -DPython3_EXECUTABLE=\"\`which python3\`\" -DCMAKE_BUILD_TYPE=Release ../${Bundle}
  endif
  echo "${separator}"
endif
