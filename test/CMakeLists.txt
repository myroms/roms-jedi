# (C) Copyright 2017-2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Unit tests configuration files

list( APPEND romsjedi_test_input
  testinput/3denvar_fgat_dual.yaml
  testinput/3denvar_fgat_primal.yaml
  testinput/3denvar_regular_dual.yaml
  testinput/3denvar_regular_primal.yaml
  testinput/3dhyb_fgat_dual.yaml
  testinput/3dhyb_fgat_primal.yaml
  testinput/3dhyb_regular_dual.yaml
  testinput/3dhyb_regular_primal.yaml
  testinput/3dvar_fgat_single_obs.yaml
  testinput/3dvar_regular_single_obs.yaml
  testinput/3dvar_fgat_dual.yaml
  testinput/3dvar_fgat_primal.yaml
  testinput/3dvar_regular_dual.yaml
  testinput/3dvar_regular_primal.yaml
  testinput/3dvar_zero_obs.yaml
  testinput/diffstates.yaml
  testinput/dirac_cov_nicas.yaml
  testinput/dirac_ens_cov_nicas.yaml
  testinput/ens_hofx.yaml
  testinput/ens_hofx_1.yaml
  testinput/ens_hofx_2.yaml
  testinput/ens_hofx_3.yaml
  testinput/ens_hofx_4.yaml
  testinput/ens_hofx_5.yaml
  testinput/ens_mean_variance.yaml
  testinput/ens_perturbation.yaml
  testinput/ens_recenter.yaml
  testinput/ens_variance.yaml
  testinput/error_covariance.yaml
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
  testinput/parameters_bump_loc_cor_nicas.yaml
  testinput/state.yaml
  )

# Unit tests reference files

set( romsjedi_test_ref
  testref/3denvar_fgat_dual.ref
  testref/3denvar_fgat_primal.ref
  testref/3denvar_regular_dual.ref
  testref/3denvar_regular_primal.ref
  testref/3dhyb_fgat_dual.ref
  testref/3dhyb_fgat_primal.ref
  testref/3dhyb_regular_dual.ref
  testref/3dhyb_regular_primal.ref
  testref/3dvar_fgat_single_obs.ref
  testref/3dvar_regular_single_obs.ref
  testref/3dvar_fgat_dual.ref
  testref/3dvar_fgat_primal.ref
  testref/3dvar_regular_dual.ref
  testref/3dvar_regular_primal.ref
  testref/3dvar_single_obs.ref
  testref/3dvar_zero_obs.ref
  testref/diffstates.ref
  testref/dirac_cov_nicas.ref
  testref/dirac_ens_cov_nicas.ref
  testref/ens_hofx.ref
  testref/ens_mean_variance.ref
  testref/ens_perturbation.ref
  testref/ens_recenter.ref
  testref/ens_variance.ref
  testref/forecast_roms.ref
  testref/hofx_nomodel.ref
  testref/hofx_4d.ref
  testref/increment.ref
  testref/makeobs_4d.ref
  testref/makeobs_4d_perturbed.ref
  testref/parameters_bump_cor_nicas.ref
  testref/parameters_bump_cov_nicas.ref
  testref/parameters_bump_loc_cor_nicas.ref
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
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3denvar)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3denvar/fgat/dual)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3denvar/fgat/primal)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3denvar/regular/dual)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3denvar/regular/primal)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dhyb)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dhyb/fgat/dual)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dhyb/fgat/primal)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dhyb/regular/dual)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dhyb/regular/primal)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/fgat)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/fgat/dual)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/fgat/primal)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/regular)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/regular/dual)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/regular/primal)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/singleObs)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/singleObs/fgat)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/singleObs/regular)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/zeroObs)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/bump)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/bump_loc)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/diff)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/dirac)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/ensembles)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/forecast)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/hofx)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/hofx/ensembles)
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
  TARGET       test_romsjedi_error_covariance
  MPI          2
  SOURCES      executables/TestErrorCovariance.cc
  ARGS         testinput/error_covariance.yaml
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
  TARGET       test_romsjedi_bump_parameters_cor_nicas
  MPI          2
  COMMAND      romsjedi_error_covariance_training.x
  ARGS         testinput/parameters_bump_cor_nicas.yaml
  LIBS         romsjedi )

ecbuild_add_test(
  TARGET       test_romsjedi_bump_loc_parameters_cor_nicas
  MPI          2
  COMMAND      romsjedi_error_covariance_training.x
  ARGS         testinput/parameters_bump_loc_cor_nicas.yaml
  LIBS         romsjedi )

ecbuild_add_test(
  TARGET       test_romsjedi_dirac_cov_nicas
  MPI          2
  COMMAND      romsjedi_dirac.x
  ARGS         testinput/dirac_cov_nicas.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_bump_parameters_cor_nicas )

#================================================================================
# ROMS-JEDI Ensemble applications
#================================================================================

# Ensemble generation

ecbuild_add_test(
  TARGET       test_romsjedi_ens_pert
  MPI          2
  COMMAND      romsjedi_ens_pert.x
  ARGS         testinput/ens_perturbation.yaml
  LIBS         romsjedi )

ecbuild_add_test(
  TARGET       test_romsjedi_ens_variance
  MPI          2
  COMMAND      romsjedi_ens_variance.x
  ARGS         testinput/ens_variance.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_ens_pert )

ecbuild_add_test(
  TARGET       test_romsjedi_ens_mean_variance
  MPI          2
  COMMAND      romsjedi_ens_mean_variance.x
  ARGS         testinput/ens_mean_variance.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_ens_pert )

ecbuild_add_test(
  TARGET       test_romsjedi_ens_recenter
  MPI          2
  COMMAND      romsjedi_ens_recenter.x
  ARGS         testinput/ens_recenter.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_ens_pert )

ecbuild_add_test(
  TARGET       test_romsjedi_ens_hofx
  MPI          6
  COMMAND      romsjedi_ens_hofx.x
  ARGS         testinput/ens_hofx.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_ens_pert )

ecbuild_add_test(
  TARGET       test_romsjedi_dirac_ens_cov_nicas
  MPI          2
  COMMAND      romsjedi_dirac.x
  ARGS         testinput/dirac_ens_cov_nicas.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_ens_pert
               test_romsjedi_bump_loc_parameters_cor_nicas )

#================================================================================
# ROMS-JEDI Variational Data Assimilation applications
#================================================================================

ecbuild_add_test(
  TARGET       test_romsjedi_3dvar_zero_obs
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dvar_zero_obs.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_bump_parameters_cor_nicas )

ecbuild_add_test(
  TARGET       test_romsjedi_3dvar_regular_single_obs
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dvar_regular_single_obs.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_bump_parameters_cor_nicas )

ecbuild_add_test(
  TARGET       test_romsjedi_3dvar_fgat_single_obs
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dvar_fgat_single_obs.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_bump_parameters_cor_nicas )

ecbuild_add_test(
  TARGET       test_romsjedi_3dvar_regular_primal
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dvar_regular_primal.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjed_bump_parameters_cor_nicas )

ecbuild_add_test(
  TARGET       test_romsjedi_3dvar_regular_dual
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dvar_regular_dual.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_bump_parameters_cor_nicas )

ecbuild_add_test(
  TARGET       test_romsjedi_3dvar_fgat_primal
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dvar_fgat_primal.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_bump_parameters_cor_nicas )

ecbuild_add_test(
  TARGET       test_romsjedi_3dvar_fgat_dual
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dvar_fgat_dual.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_bump_parameters_cor_nicas )

#================================================================================
# ROMS-JEDI Ensemble/Hybrid Variational Data Assimilation applications
#================================================================================

ecbuild_add_test(
  TARGET       test_romsjedi_3denvar_regular_primal
  MPI          2
  COMMAND      romsjedi_var.x
 ARGS         testinput/3denvar_regular_primal.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_bump_loc_parameters_cor_nicas )

ecbuild_add_test(
  TARGET       test_romsjedi_3denvar_regular_dual
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/3denvar_regular_dual.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_bump_loc_parameters_cor_nicas )

ecbuild_add_test(
  TARGET       test_romsjedi_3denvar_fgat_primal
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/3denvar_fgat_primal.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_bump_loc_parameters_cor_nicas )

ecbuild_add_test(
  TARGET       test_romsjedi_3denvar_fgat_dual
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/3denvar_fgat_dual.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_bump_loc_parameters_cor_nicas )

ecbuild_add_test(
  TARGET       test_romsjedi_3dhyb_regular_primal
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dhyb_regular_primal.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_bump_parameters_cor_nicas
               test_romsjedi_bump_loc_parameters_cor_nicas )

ecbuild_add_test(
  TARGET       test_romsjedi_3dhyb_regular_dual
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dhyb_regular_dual.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_bump_parameters_cor_nicas
               test_romsjedi_bump_loc_parameters_cor_nicas )

ecbuild_add_test(
  TARGET       test_romsjedi_3dhyb_fgat_primal
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dhyb_fgat_primal.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_bump_parameters_cor_nicas
               test_romsjedi_bump_loc_parameters_cor_nicas )

ecbuild_add_test(
  TARGET       test_romsjedi_3dhyb_fgat_dual
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dhyb_fgat_dual.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_bump_parameters_cor_nicas
               test_romsjedi_bump_loc_parameters_cor_nicas )
