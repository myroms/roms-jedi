# (C) Copyright 2017-2025 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Create input/output directories for the tests and symlinks for all files.

file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data)

file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/dual)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/primal)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/singleObs)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dvar/zeroObs)

file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dfgat)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dfgat/dual)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dfgat/primal)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dfgat/singleObs)

file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/4dfgat)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/4dfgat/dual)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/4dfgat/primal)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/4dfgat/singleObs)

file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3denvar)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3denvar/4dfgat/dual)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3denvar/4dfgat/primal)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3denvar/nofgat/dual)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3denvar/nofgat/primal)

file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dhyb)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dhyb/4dfgat/dual)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dhyb/4dfgat/primal)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dhyb/nofgat/dual)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/3dhyb/nofgat/primal)

file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/4dvar)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/4dvar/bump)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/4dvar/diffusion)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/4dvar/singleObs)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/4dvar/singleObs/bump)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/4dvar/singleObs/diffusion)

file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/letkf)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/letkf/3dhyb)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/letkf/solver)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/letkf/splitObserver)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/letkf/splitSolver)

file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/bump)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/bump_loc)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/diffusion)

file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/difference)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/dirac)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/ensembles)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/forecast)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/increment)

file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/hofx)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/hofx/3d)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/hofx/4d)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/hofx/ensembles)

file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/makeobs)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/makeobs/truth)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/makeobs/perturbed)

file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/roms)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Data/trajectory)

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
  MPI          ${MPI_NCPUS}
  SOURCES      executables/TestGeometry.cc
  ARGS         testinput/geometry.yaml
  LIBS         romsjedi )

ecbuild_add_test(
 TARGET        test_romsjedi_geometryiterator
 MPI           ${MPI_NCPUS}
 SOURCES       executables/TestGeometryIterator.cc
 ARGS          testinput/geometryiterator.yaml
 LIBS          romsjedi )

ecbuild_add_test(
  TARGET       test_romsjedi_state
  MPI          ${MPI_NCPUS}
  SOURCES      executables/TestState.cc
  ARGS         testinput/state.yaml
  LIBS         romsjedi )

ecbuild_add_test(
  TARGET       test_romsjedi_increment
  MPI          ${MPI_NCPUS}
  SOURCES      executables/TestIncrement.cc
  ARGS         testinput/increment.yaml
  LIBS         romsjedi )

#ecbuild_add_test(
#  TARGET       test_romsjedi_model
#  MPI          ${MPI_NCPUS}
#  SOURCES      executables/TestModel.cc
#  ARGS         testinput/model.yaml
#  LIBS         romsjedi )

ecbuild_add_test(
  TARGET       test_romsjedi_linearmodel
  MPI          ${MPI_NCPUS}
  SOURCES      executables/TestLinearModel.cc
  ARGS         testinput/linearmodel.yaml
  LIBS         romsjedi )

ecbuild_add_test(
   TARGET       test_romsjedi_variableChange
   MPI          ${MPI_NCPUS}
   SOURCES      executables/TestVariableChange.cc
   ARGS         testinput/variableChange.yaml
   LIBS         romsjedi )

#ecbuild_add_test(
#   TARGET       test_romsjedi_linearVariableChange
#   MPI          ${MPI_NCPUS}
#   SOURCES      executables/TestLinearVariableChange.cc
#   ARGS         testinput/linearVariableChange.yaml
#   LIBS         romsjedi )

#================================================================================
# Unit Tests using the main ROMS-JEDI applications
#================================================================================

ecbuild_add_test(
  TARGET       test_romsjedi_hofx_3d
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_hofx3d.x
  ARGS         testinput/hofx_3d.yaml
  TEST_DEPENDS test_romsjedi_geometry  )

ecbuild_add_test(
  TARGET       test_romsjedi_hofx_4d
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_hofx4d.x
  ARGS         testinput/hofx_4d.yaml
  TEST_DEPENDS test_romsjedi_geometry  )

ecbuild_add_test(
  TARGET       test_romsjedi_makeobs
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_hofx4d.x
  ARGS         testinput/makeobs.yaml
  TEST_DEPENDS test_romsjedi_hofx_4d )

ecbuild_add_test(
  TARGET       test_romsjedi_makeobs_perturbed
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_hofx4d.x
  ARGS         testinput/makeobs_perturbed.yaml
  TEST_DEPENDS test_romsjedi_hofx_4d )

ecbuild_add_test(
  TARGET       test_romsjedi_diffstates
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_diffstates.x
  ARGS         testinput/diffstates.yaml
  LIBS         romsjedi )

ecbuild_add_test(
  TARGET       test_romsjedi_forecast_roms
  MPI          ${MPI_NCPUS_MAX}
  COMMAND      romsjedi_forecast.x
  ARGS         testinput/forecast_roms.yaml
  LIBS         romsjedi )

ecbuild_add_test(
  TARGET       test_romsjedi_parameters_bump_cor_nicas
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_error_covariance_toolbox.x
  ARGS         testinput/parameters_bump_cor_nicas.yaml
  LIBS         romsjedi )

ecbuild_add_test(
  TARGET       test_romsjedi_parameters_bump_cor_nicas_max
  MPI          ${MPI_NCPUS_MAX}
  COMMAND      romsjedi_error_covariance_toolbox.x
  ARGS         testinput/parameters_bump_cor_nicas_max.yaml
  LIBS         romsjedi )

ecbuild_add_test(
  TARGET       test_romsjedi_parameters_diffusion
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_error_covariance_toolbox.x
  ARGS         testinput/parameters_diffusion.yaml
  LIBS         romsjedi )

ecbuild_add_test(
  TARGET       test_romsjedi_parameters_bump_loc_cor_nicas
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_error_covariance_toolbox.x
  ARGS         testinput/parameters_bump_loc_cor_nicas.yaml
  LIBS         romsjedi )

ecbuild_add_test(
  TARGET       test_romsjedi_parameters_bump_loc_cor_nicas_max
  MPI          ${MPI_NCPUS_MAX}
  COMMAND      romsjedi_error_covariance_toolbox.x
  ARGS         testinput/parameters_bump_loc_cor_nicas_max.yaml
  LIBS         romsjedi )

ecbuild_add_test(
  TARGET       test_romsjedi_dirac_cov_nicas
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_error_covariance_toolbox.x
  ARGS         testinput/dirac_cov_nicas.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_parameters_bump_cor_nicas )

ecbuild_add_test(
  TARGET       test_romsjedi_dirac_diffusion
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_error_covariance_toolbox.x
  ARGS         testinput/dirac_diffusion.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_parameters_diffusion )

#================================================================================
# ROMS-JEDI Ensemble applications
#================================================================================

# Ensemble generation

ecbuild_add_test(
  TARGET       test_romsjedi_ens_perturbation
  MPI          ${MPI_NCPUS_MAX}
  COMMAND      romsjedi_ens_pert.x
  ARGS         testinput/ens_perturbation.yaml
  LIBS         romsjedi )

ecbuild_add_test(
  TARGET       test_romsjedi_ens_meanandvariance
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_ens_meanandvariance.x
  ARGS         testinput/ens_meanandvariance.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_ens_perturbation )

ecbuild_add_test(
  TARGET       test_romsjedi_ens_recenter
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_ens_recenter.x
  ARGS         testinput/ens_recenter.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_ens_perturbation )

ecbuild_add_test(
  TARGET       test_romsjedi_ens_hofx
  MPI          ${MPI_3xNCPUS}
  COMMAND      romsjedi_ens_hofx.x
  ARGS         testinput/ens_hofx.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_ens_perturbation )

ecbuild_add_test(
  TARGET       test_romsjedi_dirac_ens_cov_nicas
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_error_covariance_toolbox.x
  ARGS         testinput/dirac_ens_cov_nicas.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_ens_perturbation
               test_romsjedi_parameters_bump_loc_cor_nicas )

#================================================================================
# ROMS-JEDI Variational Data Assimilation applications
#================================================================================

ecbuild_add_test(
  TARGET       test_romsjedi_3dvar_zeroObs
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dvar_zeroObs.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_parameters_bump_cor_nicas )

ecbuild_add_test(
  TARGET       test_romsjedi_3dvar_singleObs
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dvar_singleObs.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_parameters_bump_cor_nicas )

ecbuild_add_test(
  TARGET       test_romsjedi_3dvar_primal
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dvar_primal.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjed_parameters_bump_cor_nicas )

ecbuild_add_test(
  TARGET       test_romsjedi_3dvar_dual
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dvar_dual.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_parameters_bump_cor_nicas )

ecbuild_add_test(
  TARGET       test_romsjedi_3dfgat_singleObs
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dfgat_singleObs.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_parameters_bump_cor_nicas )

ecbuild_add_test(
  TARGET       test_romsjedi_3dfgat_primal
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dfgat_primal.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_parameters_bump_cor_nicas )

ecbuild_add_test(
  TARGET       test_romsjedi_3dfgat_dual
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dfgat_dual.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_parameters_bump_cor_nicas )

ecbuild_add_test(
  TARGET       test_romsjedi_4dfgat_singleObs
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_var.x
  ARGS         testinput/4dfgat_singleObs.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_parameters_bump_cor_nicas )

ecbuild_add_test(
  TARGET       test_romsjedi_4dfgat_primal
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_var.x
  ARGS         testinput/4dfgat_primal.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_parameters_bump_cor_nicas )

ecbuild_add_test(
  TARGET       test_romsjedi_4dfgat_dual
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_var.x
  ARGS         testinput/4dfgat_dual.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_parameters_bump_cor_nicas )

ecbuild_add_test(
  TARGET       test_romsjedi_4dvar_singleObs_bump
  MPI          ${MPI_NCPUS_MAX}
  COMMAND      romsjedi_var.x
  ARGS         testinput/4dvar_singleObs_bump.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_parameters_bump_cor_nicas )

ecbuild_add_test(
  TARGET       test_romsjedi_4dvar_singleObs_diffusion
  MPI          ${MPI_NCPUS_MAX}
  COMMAND      romsjedi_var.x
  ARGS         testinput/4dvar_singleObs_diffusion.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_parameters_diffusion )

ecbuild_add_test(
  TARGET       test_romsjedi_4dvar_bump
  MPI          ${MPI_NCPUS_MAX}
  COMMAND      romsjedi_var.x
  ARGS         testinput/4dvar_bump.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_parameters_bump_cor_nicas )

ecbuild_add_test(
  TARGET       test_romsjedi_4dvar_diffusion
  MPI          ${MPI_NCPUS_MAX}
  COMMAND      romsjedi_var.x
  ARGS         testinput/4dvar_diffusion.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_parameters_diffusion )

#================================================================================
# ROMS-JEDI Ensemble/Hybrid Variational Data Assimilation applications
#================================================================================

ecbuild_add_test(
  TARGET       test_romsjedi_3denvar_nofgat_primal
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_var.x
  ARGS         testinput/3denvar_nofgat_primal.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_parameters_bump_loc_cor_nicas
               test_romsjedi_ens_perturbation )

ecbuild_add_test(
  TARGET       test_romsjedi_3denvar_nofgat_dual
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_var.x
  ARGS         testinput/3denvar_nofgat_dual.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_parameters_bump_loc_cor_nicas
               test_romsjedi_ens_perturbation )

ecbuild_add_test(
  TARGET       test_romsjedi_3denvar_4dfgat_primal
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_var.x
  ARGS         testinput/3denvar_4dfgat_primal.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_parameters_bump_loc_cor_nicas
               test_romsjedi_ens_perturbation )

ecbuild_add_test(
  TARGET       test_romsjedi_3denvar_4dfgat_dual
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_var.x
  ARGS         testinput/3denvar_4dfgat_dual.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_parameters_bump_loc_cor_nicas
               test_romsjedi_ens_perturbation )

ecbuild_add_test(
  TARGET       test_romsjedi_3dhyb_nofgat_primal
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dhyb_nofgat_primal.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_parameters_bump_cor_nicas
               test_romsjedi_parameters_bump_loc_cor_nicas
               test_romsjedi_ens_perturbation )

ecbuild_add_test(
  TARGET       test_romsjedi_3dhyb_nofgat_dual
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dhyb_nofgat_dual.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_parameters_bump_cor_nicas
               test_romsjedi_parameters_bump_loc_cor_nicas
               test_romsjedi_ens_perturbation )

ecbuild_add_test(
  TARGET       test_romsjedi_3dhyb_4dfgat_primal
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dhyb_4dfgat_primal.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_parameters_bump_cor_nicas
               test_romsjedi_parameters_bump_loc_cor_nicas
               test_romsjedi_ens_perturbation )

ecbuild_add_test(
  TARGET       test_romsjedi_3dhyb_4dfgat_dual
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_var.x
  ARGS         testinput/3dhyb_4dfgat_dual.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_parameters_bump_cor_nicas
               test_romsjedi_parameters_bump_loc_cor_nicas
               test_romsjedi_ens_perturbation )

#================================================================================
# ROMS-JEDI LETKF Assimilation applications
#================================================================================

ecbuild_add_test(
  TARGET       test_romsjedi_letkf_solver
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_letkf.x
  ARGS         testinput/letkf_solver.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_ens_perturbation )

ecbuild_add_test(
  TARGET       test_romsjedi_letkf_splitObserver
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_letkf.x
  ARGS         testinput/letkf_splitObserver.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_ens_perturbation )

ecbuild_add_test(
  TARGET       test_romsjedi_letkf_splitSolver
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_letkf.x
  ARGS         testinput/letkf_splitSolver.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_ens_perturbation
               test_romsjedi_letkf_splitObserver )

ecbuild_add_test(
  TARGET       test_romsjedi_letkf_3dhyb
  MPI          ${MPI_NCPUS}
  COMMAND      romsjedi_var.x
  ARGS         testinput/letkf_3dhyb.yaml
  LIBS         romsjedi
  TEST_DEPENDS test_romsjedi_parameters_bump_cor_nicas
               test_romsjedi_parameters_bump_loc_cor_nicas
               test_romsjedi_letkf_solver )
