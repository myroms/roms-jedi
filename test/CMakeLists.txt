# (C) Copyright 2017-2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Unit tests configuration files

list( APPEND romsjedi_test_input
  testinput/3dvar_fgat_DRPLanczos.yaml
  testinput/3dvar_fgat_RPCG.yaml
  testinput/3dvar_noLM.yaml
  testinput/3dvar_single_obs.yaml
  testinput/3dvar_zero_obs.yaml
  testinput/diffstates.yaml
  testinput/dirac_roms_cor_nicas.yaml
  testinput/enspert.yaml
  testinput/errorcovariance.yaml
  testinput/forecast_roms.yaml
  testinput/geometry.yaml
  testinput/geometryiterator.yaml
  testinput/getvalues.yaml
  testinput/hofx_nomodel.yaml
  testinput/hofx_4d.yaml
  testinput/increment.yaml
  testinput/lineargetvalues.yaml
  testinput/linearmodel.yaml
  testinput/makeobs_4d.yaml
  testinput/makeobs_4d_perturbed.yaml
  testinput/model.yaml
  testinput/obsop_name_map.yaml
  testinput/parameters_bump_cor_nicas.yaml
  testinput/parameters_bump_cov_nicas.yaml
  testinput/state.yaml
  )

# Unit tests reference files

set( romsjedi_test_ref
  testref/3dvar_fgat_DRPLanczos.ref
  testref/3dvar_fgat_RPCG.ref
  testref/3dvar_noLM.ref
  testref/3dvar_single_obs.ref
  testref/3dvar_zero_obs.ref
  testref/diffstates.ref
  testref/dirac_roms_cor_nicas.ref
  testref/enspert.ref
  testref/forecast_roms.ref
  testref/hofx_nomodel.ref
  testref/hofx_4d.ref
  testref/increment.ref
  testref/makeobs_4d.ref
  testref/makeobs_4d_perturbed.ref
  testref/parameters_bump_cor_nicas.ref
  testref/parameters_bump_cov_nicas.ref
)

# Tests data files

set( romsjedi_data_files
  Data/fields_metadata.yaml
  Data/obs/wc13_TS_20040103.nc4
  Data/obs/wc13_TS_20040105.nc4
  Data/obs/wc13_adt_20040103.nc4
  Data/obs/wc13_adt_20040105.nc4
  Data/obs/wc13_adt_single_obs_20040105.nc4
  Data/obs/wc13_ptemp_20040103.nc4
  Data/obs/wc13_salt_20040103.nc4
  Data/obs/wc13_salt_20040105.nc4
  Data/obs/wc13_sss_20040103.nc4
  Data/obs/wc13_sst_20040103.nc4
  Data/obs/wc13_sst_20040105.nc4
  Data/obs/wc13_sst_single_obs_20040105.nc4
  Data/obs/wc13_temp_20040103.nc4
  Data/obs/wc13_temp_20040105.nc4
  Data/obs/wc13_uv_sur_20040103.nc4
  Data/obs/wc13_usur_20040103.nc4
  Data/obs/wc13_vsur_20040103.nc4
)

# Create input/output directories for the tests and symlinks for all files

file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/fgat)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/fgat/DRPLanczos)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/fgat/RPCG)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/noLM)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/singleObs)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/zeroObs)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/bump)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/diff)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/dirac)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/ensembles)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/forecast)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/hofx)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/increment)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/makeobs)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/obs)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/roms)
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

# Copy BASH scripts to facilitate running of Unit Tests.

set( romsjedi_bash_scripts
  batch_tests.sh
  slurm_test.sh
)

foreach(FILENAME ${romsjedi_bash_scripts})
  execute_process(COMMAND ${CMAKE_COMMAND} -E copy
    ${CMAKE_CURRENT_SOURCE_DIR}/${FILENAME}
    ${CMAKE_CURRENT_BINARY_DIR}/${FILENAME} )
endforeach()

#================================================================================
# Unit Tests of ROMS-JEDI interface class objects
#================================================================================

ecbuild_add_test(
  TARGET       test_romsjedi_geometry
  MPI          2
  SOURCES      executables/TestGeometry.cc
  ARGS         testinput/geometry.yaml
  LIBS         romsjedi )

ecbuild_add_test(
 TARGET        test_romsjedi_geometryiterator
 MPI           2
 SOURCES       executables/TestGeometryIterator.cc
 ARGS          testinput/geometryiterator.yaml
 LIBS          romsjedi )

ecbuild_add_test(
  TARGET       test_romsjedi_state
  MPI          2
  SOURCES      executables/TestState.cc
  ARGS         testinput/state.yaml
  LIBS         romsjedi )

#ecbuild_add_test(
#  TARGET       test_romsjedi_getvalues
#  MPI          2
#  SOURCES      executables/TestGetValues.cc
#  ARGS         testinput/getvalues.yaml
#  LIBS         romsjedi )

ecbuild_add_test(
  TARGET       test_romsjedi_increment
  MPI          2
  SOURCES      executables/TestIncrement.cc
  ARGS         testinput/increment.yaml
  LIBS         romsjedi )

#ecbuild_add_test(
#  TARGET       test_romsjedi_lineargetvalues
#  MPI          2
#  SOURCES      executables/TestLinearGetValues.cc
#  ARGS         testinput/lineargetvalues.yaml
#  LIBS         romsjedi )

ecbuild_add_test(
  TARGET       test_romsjedi_model
  MPI          2
  SOURCES      executables/TestModel.cc
  ARGS         testinput/model.yaml
  LIBS         romsjedi )

ecbuild_add_test(
  TARGET       test_romsjedi_linearmodel
  MPI          2
  SOURCES      executables/TestLinearModel.cc
  ARGS         testinput/linearmodel.yaml
  LIBS         romsjedi )

ecbuild_add_test(
  TARGET       test_romsjedi_errorcovariance
  MPI          2
  SOURCES      executables/TestErrorCovariance.cc
  ARGS         testinput/errorcovariance.yaml
  LIBS         romsjedi )

#ecbuild_add_test(
#  TARGET       test_romsjedi_modelauxcontrol
#  SOURCES      executables/TestModelAuxControl.cc
#  ARGS         testinput/modelaux.yaml
#  LIBS         romsjedi )

#ecbuild_add_test(
#  TARGET       test_romsjedi_modelauxcovariance
#  SOURCES      executables/TestModelAuxCovariance.cc
#  ARGS         testinput/modelaux.yaml
#  LIBS         romsjedi )

#ecbuild_add_test(
#  TARGET       test_romsjedi_modelauxincrement
#  SOURCES      executables/TestModelAuxIncrement.cc
#  ARGS         testinput/modelaux.yaml
#  LIBS         romsjedi )

#================================================================================
# Unit Tests using the main ROMS-JEDI applications
#================================================================================

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
  TARGET       test_romsjedi_makeobs_4d
  MPI          2
  COMMAND      romsjedi_hofx.x
  ARGS         testinput/makeobs_4d.yaml
  TEST_DEPENDS test_romsjedi_hofx_4d )

ecbuild_add_test(
  TARGET       test_romsjedi_makeobs_4d_perturbed
  MPI          2
  COMMAND      romsjedi_hofx.x
  ARGS         testinput/makeobs_4d_perturbed.yaml
  TEST_DEPENDS test_romsjedi_hofx_4d )

ecbuild_add_test(
  TARGET       test_romsjedi_diffstates
  MPI          2
  COMMAND      romsjedi_diffstates.x
  ARGS         testinput/diffstates.yaml
  LIBS         romsjedi )

ecbuild_add_test(
  TARGET       test_romsjedi_forecast_roms
  MPI          2
  COMMAND      romsjedi_forecast.x
  ARGS         testinput/forecast_roms.yaml
  LIBS         romsjedi )

ecbuild_add_test(
  TARGET       test_bump_parameters_cor_nicas
  MPI          2
  COMMAND      romsjedi_error_covariance_training.x
  ARGS         testinput/parameters_bump_cor_nicas.yaml
  LIBS         romsjedi )

ecbuild_add_test(
  TARGET       test_dirac_roms_cor_nicas
  MPI          2
  COMMAND      romsjedi_dirac.x
  ARGS         testinput/dirac_roms_cor_nicas.yaml
  LIBS         romsjedi )

#================================================================================
# ROMS-JEDI Ensemble applications
#================================================================================

# Ensemble generation

ecbuild_add_test(
  TARGET       test_romsjedi_enspert
  MPI          2
  COMMAND      romsjedi_enspert.x
  ARGS         testinput/enspert.yaml
  LIBS         romsjedi )

#================================================================================
# ROMS-JEDI Data Assimilation applications
#================================================================================

ecbuild_add_test(
  TARGET       test_romsjedi_3dvar_zero_obs
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dvar_zero_obs.yaml
  LIBS         romsjedi )

ecbuild_add_test(
  TARGET       test_romsjedi_3dvar_single_obs
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dvar_single_obs.yaml
  LIBS         romsjedi )

ecbuild_add_test(
  TARGET       test_romsjedi_3dvar_noLM
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dvar_noLM.yaml
  LIBS         romsjedi )

ecbuild_add_test(
  TARGET       test_romsjedi_3dvar_fgat_DRPLanczos
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dvar_fgat_DRPLanczos.yaml
  LIBS         romsjedi )

ecbuild_add_test(
  TARGET       test_romsjedi_3dvar_fgat_RPCG
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dvar_fgat_RPCG.yaml
  LIBS         romsjedi )
