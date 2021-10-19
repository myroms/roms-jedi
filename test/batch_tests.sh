#!/bin/bash

#######################################################################
## Batch script to run ROMS-JEDI Unit Test Cases with "mpirun"        #
##                                                                    #
## THIS SCRIPT NEEDS TO BE RUN FROM:                                  #
##                                                                    #
##      <root-dir>/roms-jedi/build/roms-jedi                          #
##                                                                    #
#######################################################################

export OOPS_TRACE=0                 # Set to 1 for tracing
export MAIN_DEBUG=1
export OOPS_DEBUG=1

export HDF5_USE_FILE_LOCKING=FALSE

MPIrun="mpirun -n 2"

# Run all avialable or specific tests

#ALL_TEST=0         # Run specific tests.
 ALL_TEST=1         # Run all tests. Then, check ./Testing/Temporary/LastTest.log or
                    #                            ./Testing/Temporary/LastTestsFailed.log

if [ ${ALL_TEST} -eq 1 ]; then
  cd ../                            # go back to <root_dir>/roms-jedi/build/roms-jedi
  ctest -E -V get_
# ctest -V -R romsjedi_coding_norms
else
  ${MPIrun} test_romsjedi_geometry testinput/geometry.yaml
  ${MPIrun} test_romsjedi_geometryiterator testinput/geometryiterator.yaml
  ${MPIrun} test_romsjedi_state testinput/state.yaml
  ${MPIrun} test_romsjedi_getvalues testinput/getvalues.yaml
  ${MPIrun} ../../bin/romsjedi_hofx_nomodel.x testinput/hofx_nomodel.yaml
  ${MPIrun} ../../bin/romsjedi_hofx.x testinput/hofx_4d.yaml
  ${MPIrun} test_romsjedi_increment testinput/increment.yaml
  ${MPIrun} test_romsjedi_model testinput/model.yaml
  ${MPIrun} ../../bin/romsjedi_forecast.x testinput/forecast_roms.yaml
fi

exit 0
