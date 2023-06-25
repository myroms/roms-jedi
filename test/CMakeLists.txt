# (C) Copyright 2017-2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Create input/output directories for the tests and symlinks for all files.

file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3denvar)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3denvar/4dfgat/dual)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3denvar/4dfgat/primal)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3denvar/regular/dual)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3denvar/regular/primal)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dhyb)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dhyb/4dfgat/dual)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dhyb/4dfgat/primal)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dhyb/regular/dual)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dhyb/regular/primal)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/3dfgat)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/3dfgat/dual)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/3dfgat/primal)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/4dfgat)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/4dfgat/dual)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/4dfgat/primal)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/regular)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/regular/dual)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/regular/primal)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/singleObs)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/singleObs/3dfgat)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/singleObs/4dfgat)
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
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/letkf)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/letkf/3dhyb)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/letkf/solver)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/letkf/split_observer)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/letkf/split_solver)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/makeobs)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/roms)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/testinput)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/testoutput)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/testref)

# Link to ROMS-JEDI application 'testinput'  subdirectories.

file(GLOB testinput "${ROMSJEDI_APPLICATION_DIR}/testinput/*.yaml")

foreach(FILENAME ${testinput})
  get_filename_component(yaml ${FILENAME} NAME)
  execute_process(COMMAND ${CMAKE_COMMAND} -E create_symlink
    ${ROMSJEDI_APPLICATION_DIR}/testinput/${yaml}
    ${CMAKE_CURRENT_BINARY_DIR}/testinput/${yaml} )
endforeach()

# Link to ROMS-JEDI application 'testref' subdirectories.

file(GLOB testref   "${ROMSJEDI_APPLICATION_DIR}/testref/*.ref")

foreach(FILENAME ${testref})
  get_filename_component(ref ${FILENAME} NAME)
  execute_process(COMMAND ${CMAKE_COMMAND} -E create_symlink
    ${ROMSJEDI_APPLICATION_DIR}/testref/${ref}
    ${CMAKE_CURRENT_BINARY_DIR}/testref/${ref} )
endforeach()

# Specify ROMS-JEDI metadata.

execute_process(COMMAND ${CMAKE_COMMAND} -E create_symlink
  ${CMAKE_CURRENT_SOURCE_DIR}/fields_metadata.yaml
  ${CMAKE_CURRENT_BINARY_DIR}/Data/fields_metadata.yaml )

# Make ROMS-JEDI application link.

string( TOLOWER ${ROMS_APP} romsjedi_app )

execute_process(COMMAND ${CMAKE_COMMAND} -E create_symlink
  ${ROMSJEDI_APPLICATION_DIR}
  ${CMAKE_CURRENT_BINARY_DIR}/Data/${romsjedi_app} )

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
  COMMAND      romsjedi_error_covariance_toolbox.x
  ARGS         testinput/parameters_bump_cor_nicas.yaml
  LIBS         romsjedi )

ecbuild_add_test(
  TARGET       test_romsjedi_bump_loc_parameters_cor_nicas
  MPI          2
  COMMAND      romsjedi_error_covariance_toolbox.x
  ARGS         testinput/parameters_bump_loc_cor_nicas.yaml
  LIBS         romsjedi )

ecbuild_add_test(
  TARGET       test_romsjedi_dirac_cov_nicas
  MPI          2
  COMMAND      romsjedi_error_covariance_toolbox.x
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
  COMMAND      romsjedi_error_covariance_toolbox.x
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
  TARGET       test_romsjedi_3dfgat_single_obs
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dfgat_single_obs.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_bump_parameters_cor_nicas )

ecbuild_add_test(
  TARGET       test_romsjedi_4dfgat_single_obs
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/4dfgat_single_obs.yaml
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
  TARGET       test_romsjedi_3dfgat_primal
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dfgat_primal.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_bump_parameters_cor_nicas )

ecbuild_add_test(
  TARGET       test_romsjedi_3fgat_dual
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dfgat_dual.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_bump_parameters_cor_nicas )

ecbuild_add_test(
  TARGET       test_romsjedi_4dfgat_primal
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/4dfgat_primal.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_bump_parameters_cor_nicas )

ecbuild_add_test(
  TARGET       test_romsjedi_4dfgat_dual
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/4dfgat_dual.yaml
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
  TEST_DEPENDS test_romsjedi_bump_loc_parameters_cor_nicas
               test_romsjedi_ens_pert )

ecbuild_add_test(
  TARGET       test_romsjedi_3denvar_regular_dual
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/3denvar_regular_dual.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_bump_loc_parameters_cor_nicas
               test_romsjedi_ens_pert )

ecbuild_add_test(
  TARGET       test_romsjedi_3denvar_4dfgat_primal
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/3denvar_4dfgat_primal.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_bump_loc_parameters_cor_nicas
               test_romsjedi_ens_pert )

ecbuild_add_test(
  TARGET       test_romsjedi_3denvar_4dfgat_dual
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/3denvar_4dfgat_dual.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_bump_loc_parameters_cor_nicas
               test_romsjedi_ens_pert )

ecbuild_add_test(
  TARGET       test_romsjedi_3dhyb_regular_primal
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dhyb_regular_primal.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_bump_parameters_cor_nicas
               test_romsjedi_bump_loc_parameters_cor_nicas
               test_romsjedi_ens_pert )

ecbuild_add_test(
  TARGET       test_romsjedi_3dhyb_regular_dual
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dhyb_regular_dual.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_bump_parameters_cor_nicas
               test_romsjedi_bump_loc_parameters_cor_nicas
               test_romsjedi_ens_pert )

ecbuild_add_test(
  TARGET       test_romsjedi_3dhyb_4dfgat_primal
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dhyb_4dfgat_primal.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_bump_parameters_cor_nicas
               test_romsjedi_bump_loc_parameters_cor_nicas
               test_romsjedi_ens_pert )

ecbuild_add_test(
  TARGET       test_romsjedi_3dhyb_4dfgat_dual
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dhyb_4dfgat_dual.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_bump_parameters_cor_nicas
               test_romsjedi_bump_loc_parameters_cor_nicas
               test_romsjedi_ens_pert )

#================================================================================
# ROMS-JEDI LETKF Assimilation applications
#================================================================================

ecbuild_add_test(
  TARGET       test_romsjedi_letkf
  MPI          2
  COMMAND      romsjedi_letkf.x
  ARGS         testinput/letkf.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_ens_pert )

ecbuild_add_test(
  TARGET       test_romsjedi_letkf_split_observer
  MPI          2
  COMMAND      romsjedi_letkf.x
  ARGS         testinput/letkf_split_observer.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_ens_pert )

ecbuild_add_test(
  TARGET       test_romsjedi_letkf_split_solver
  MPI          2
  COMMAND      romsjedi_letkf.x
  ARGS         testinput/letkf_split_solver.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_ens_pert
               test_romsjedi_letkf_split_observer )

ecbuild_add_test(
  TARGET       test_romsjedi_letkf_3dhyb
  MPI          2
  COMMAND      romsjedi_var.x
  ARGS         testinput/letkf_3dhyb.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_bump_parameters_cor_nicas
               test_romsjedi_bump_loc_parameters_cor_nicas
               test_romsjedi_letkf )
