# (C) Copyright 2017-2021 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Unit tests configuration files

list( APPEND roms_test_input
  testinput/geometry.yaml
  testinput/errorcovariance.yaml
  testinput/geometryiterator.yaml
  testinput/getvalues.yaml
  testinput/lineargetvalues.yaml
  testinput/linearmodel.yaml
  testinput/increment.yaml
  testinput/model.yaml
  testinput/modelaux.yaml
  testinput/state.yaml
  )

# Unit tests reference files

set( roms_test_ref
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
  testref/hofx_3d.test
  testref/hofx_3dcrtm.test
  testref/hofx_4d.test
  testref/hofx_4d_pseudo.test
  testref/hybridgain.test
  testref/letkf_observer.test
  testref/letkf_solver.test
  testref/makeobs.test
  testref/parameters_bump_cor_nicas.test
  testref/parameters_bump_cov_lct.test
)

# Tests data files

set( roms_data_files
  Data/fields_metadata.yaml
)

# Create input/output directories for the tests and symlinks for all files

file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/testinput)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/testoutput)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/testref)
foreach(FILENAME ${roms_data_files} ${roms_test_input} ${roms_test_ref})
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
  TARGET  test_roms_geometry
  MPI     2
  SOURCES executables/TestGeometry.cc
  ARGS    testinput/geometry.yml
  LIBS    roms )

# ecbuild_add_test(
#  TARGET  test_roms_geometryiterator
#  SOURCES executables/TestGeometryIterator.cc
#  ARGS    testinput/geometryiterator.yml
#  LIBS    roms )

ecbuild_add_test(
  TARGET  test_roms_getvalues
  SOURCES executables/TestGetValues.cc
  ARGS    testinput/getvalues.yml
  LIBS    roms )

# ecbuild_add_test(
#  TARGET  test_roms_lineargetvalues
#  SOURCES executables/TestLinearGetValues.cc
#  ARGS    testinput/lineargetvalues.yml
#  LIBS    roms )

ecbuild_add_test(
  TARGET  test_roms_state
  SOURCES executables/TestState.cc
  ARGS    testinput/state.yml
  LIBS    roms )


# TODO(template_impl) ecbuild_add_test(
# TODO(template_impl)   TARGET  test_roms_increment
# TODO(template_impl)   SOURCES executables/TestIncrement.cc
# TODO(template_impl)   ARGS    testinput/increment.yml
# TODO(template_impl)   LIBS    roms )

# TODO(template_impl) ecbuild_add_test(
# TODO(template_impl)   TARGET  test_roms_model
# TODO(template_impl)   SOURCES executables/TestModel.cc
# TODO(template_impl)   ARGS    testinput/model.yml
# TODO(template_impl)   LIBS    roms )

# TODO(template_impl) ecbuild_add_test(
# TODO(template_impl)   TARGET  test_roms_modelauxcontrol
# TODO(template_impl)   SOURCES executables/TestModelAuxControl.cc
# TODO(template_impl)   ARGS    testinput/modelaux.yml
# TODO(template_impl)   LIBS    roms )

# TODO(template_impl) ecbuild_add_test(
# TODO(template_impl)   TARGET  test_roms_errorcovariance
# TODO(template_impl)   SOURCES executables/TestErrorCovariance.cc
# TODO(template_impl)   ARGS    testinput/errorcovariance.yml
# TODO(template_impl)   LIBS    roms )

# TODO(template_impl) ecbuild_add_test(
# TODO(template_impl)   TARGET  test_roms_modelauxcovariance
# TODO(template_impl)   SOURCES executables/TestModelAuxCovariance.cc
# TODO(template_impl)   ARGS    testinput/modelaux.yml
# TODO(template_impl)   LIBS    roms )

# TODO(template_impl) ecbuild_add_test(
# TODO(template_impl)   TARGET  test_roms_modelauxincrement
# TODO(template_impl)   SOURCES executables/TestModelAuxIncrement.cc
# TODO(template_impl)   ARGS    testinput/modelaux.yml
# TODO(template_impl)   LIBS    roms )

# TODO(template_impl) ecbuild_add_test(
# TODO(template_impl)   TARGET  test_roms_linearmodel
# TODO(template_impl)   SOURCES executables/TestLinearModel.cc
# TODO(template_impl)   ARGS    testinput/linearmodel.yml
# TODO(template_impl)   LIBS    roms )
