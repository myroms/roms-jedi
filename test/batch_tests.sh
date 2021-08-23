#!/bin/bash

#######################################################################
## Batch script to run ROMS-JEDI Unit Test Cases with "mpirun"        #
##                                                                    #
## THIS SCRIPT NEEDS TO BE RUN FROM:                                  #
##                                                                    #
##      <root-dir>/roms-jedi/build/roms-jedi                          #
##                                                                    #
#######################################################################

export OOPS__TRACE=1
export MAIN_DEBUG=1
export OOPS_DEBUG=1

module purge
module load jedi
module list
ulimit -s unlimited

export HDF5_USE_FILE_LOCKING=FALSE

MPIrun="mpirun -n 2"

# Run all avialable or specific tests

#ALL_TEST=0         # Run specific tests. Then, check ./log.tests
 ALL_TEST=1         # Run all tests. Then, check ./Testing/Temporary/LastTest.log or
                    #                            ./Testing/Temporary/LastTestsFailed.log

if [ ${ALL_TEST} -eq 1 ]; then
  cd ../                            # go back to <root_dir>/roms-jedi/build/roms-jedi
  ctest -E -V get_
# ctest -V -R romsjedi_coding_norms
else
  ${MPIrun} test_romsjedi_geometry testinput/geometry.yaml
  ${MPIrun} test_romsjedi_state testinput/state.yaml
  ${MPIrun} test_romsjedi_getvalues testinput/getvalues.yaml
  ${MPIrun} ../../bin/romsjedi_hofx_nomodel.x testinput/hofx_3d.yaml
fi

exit 0
