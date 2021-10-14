# (C) Copyright 2017-2021 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Unit tests configuration files

list( APPEND romsjedi_test_input
  testinput/errorcovariance.yaml
  testinput/geometry.yaml
  testinput/geometryiterator.yaml
  testinput/getvalues.yaml
  testinput/hofx_nomodel.yaml
  testinput/hofx_4d.yaml
  testinput/increment.yaml
  testinput/lineargetvalues.yaml
  testinput/linearmodel.yaml
  testinput/model.yaml
  testinput/state.yaml
  )

# Unit tests reference files

set( romsjedi_test_ref
  testref/3dhyb.test
  testref/3dhybfgat.test
  testref/3dvarbump.test
  testref/3dvar_godas.test
  testref/3dvar_roms.test
  testref/3dvarlowres_roms.test
  testref/3dvarfgat.test
  testref/3dvarfgat_pseudo.test
  testref/addincrement.test
  testref/balance_mask.test
  testref/checkpointmodel.test
  testref/convertstate.test
  testref/convertstate_changevar.test
  testref/diffstates.test
  testref/dirac_bump_cov.test
  testref/dirac_horizfilt.test
  testref/dirac_roms_cov.test
  testref/dirac_romshyb_cov.test
  testref/enshofx.test
  testref/enspert.test
  testref/ensrecenter.test
  testref/ensvariance.test
  testref/forecast_identity.test
  testref/forecast_mom6.test
  testref/forecast_mom6_bgc.test
  testref/forecast_pseudo.test
  testref/hofx_nomodel.test
  testref/hofx_3d.test
  testref/hofx_4d.test
  testref/hybridgain.test
  testref/letkf_observer.test
  testref/letkf_solver.test
  testref/makeobs.test
  testref/parameters_bump_cor_nicas.test
  testref/parameters_bump_cov_lct.test
)

# Tests data files

set( romsjedi_data_files
  Data/fields_metadata.yaml
  Data/Obs/wc13_adt_20040103.nc4
  Data/Obs/wc13_salt_20040103.nc4
  Data/Obs/wc13_sst_20040103.nc4
  Data/Obs/wc13_temp_20040103.nc4
)

# Create input/output directories for the tests and symlinks for all files

file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/Obs)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/testinput)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/testoutput)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/testref)
foreach(FILENAME ${romsjedi_data_files} ${romsjedi_test_input} ${romsjedi_test_ref})
  execute_process(COMMAND ${CMAKE_COMMAND} -E create_symlink
    ${CMAKE_CURRENT_SOURCE_DIR}/${FILENAME}
    ${CMAKE_CURRENT_BINARY_DIR}/${FILENAME} )
endforeach()

# Create symlink to jediroms_wc13 repository application

execute_process( COMMAND ${CMAKE_COMMAND} -E create_symlink
  ${ROMS_BUILD_DIR}/../../../jediroms_wc13
  ${CMAKE_CURRENT_BINARY_DIR}/jediroms_wc13 )

#================================================================================
# Tests of class interfaces
#================================================================================

ecbuild_add_test(
  TARGET  test_romsjedi_geometry
  MPI     2
  SOURCES executables/TestGeometry.cc
  ARGS    testinput/geometry.yaml
  LIBS    romsjedi )

ecbuild_add_test(
 TARGET  test_romsjedi_geometryiterator
 MPI     2
 SOURCES executables/TestGeometryIterator.cc
 ARGS    testinput/geometryiterator.yaml
 LIBS    romsjedi )

ecbuild_add_test(
  TARGET  test_romsjedi_getvalues
  MPI     2
  SOURCES executables/TestGetValues.cc
  ARGS    testinput/getvalues.yaml
  LIBS    romsjedi )

ecbuild_add_test(
  TARGET  test_romsjedi_increment
  MPI     2
  SOURCES executables/TestIncrement.cc
 ARGS    testinput/increment.yaml
 LIBS    romsjedi )

#ecbuild_add_test(
#  TARGET  test_romsjedi_lineargetvalues
#  MPI     2
#  SOURCES executables/TestLinearGetValues.cc
#  ARGS    testinput/lineargetvalues.yaml
#  LIBS    romsjedi )

ecbuild_add_test(
  TARGET  test_romsjedi_state
  MPI     2
  SOURCES executables/TestState.cc
  ARGS    testinput/state.yaml
  LIBS    romsjedi )

ecbuild_add_test(
  TARGET       test_romsjedi_hofx_nomodel
  MPI          2
  COMMAND      romsjedi_hofx_nomodel.x
  ARGS         testinput/hofx_nomodel.yaml
  TEST_DEPENDS test_romsjedi_geometry  )

ecbuild_add_test(
  TARGET       test_romsjedi_hofx_4d
  MPI          2
  COMMAND      romsjedi_hofx.x
  ARGS         testinput/hofx_4d.yaml
  TEST_DEPENDS test_romsjedi_geometry  )

ecbuild_add_test(
  TARGET  test_romsjedi_model
  MPI          2
  SOURCES executables/TestModel.cc
  ARGS    testinput/model.yaml
  LIBS    romsjedi )

# TODO(template_impl) ecbuild_add_test(
# TODO(template_impl)   TARGET  test_romsjedi_modelauxcontrol
# TODO(template_impl)   SOURCES executables/TestModelAuxControl.cc
# TODO(template_impl)   ARGS    testinput/modelaux.yaml
# TODO(template_impl)   LIBS    romsjedi )

# TODO(template_impl) ecbuild_add_test(
# TODO(template_impl)   TARGET  test_romsjedi_errorcovariance
# TODO(template_impl)   SOURCES executables/TestErrorCovariance.cc
# TODO(template_impl)   ARGS    testinput/errorcovariance.yaml
# TODO(template_impl)   LIBS    romsjedi )

# TODO(template_impl) ecbuild_add_test(
# TODO(template_impl)   TARGET  test_romsjedi_modelauxcovariance
# TODO(template_impl)   SOURCES executables/TestModelAuxCovariance.cc
# TODO(template_impl)   ARGS    testinput/modelaux.yaml
# TODO(template_impl)   LIBS    romsjedi )

# TODO(template_impl) ecbuild_add_test(
# TODO(template_impl)   TARGET  test_romsjedi_modelauxincrement
# TODO(template_impl)   SOURCES executables/TestModelAuxIncrement.cc
# TODO(template_impl)   ARGS    testinput/modelaux.yaml
# TODO(template_impl)   LIBS    romsjedi )

# TODO(template_impl) ecbuild_add_test(
# TODO(template_impl)   TARGET  test_romsjedi_linearmodel
# TODO(template_impl)   SOURCES executables/TestLinearModel.cc
# TODO(template_impl)   ARGS    testinput/linearmodel.yaml
# TODO(template_impl)   LIBS    romsjedi )
