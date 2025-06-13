# (C) Copyright 2017-2025 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# ROMS-JEDI Drivers


ecbuild_add_executable( TARGET  romsjedi_addincrement.x
                        SOURCES AddIncrement.cc
                        LIBS    romsjedi
                      )

ecbuild_add_executable( TARGET  romsjedi_adjointforecast.x
                        SOURCES AdjointForecast.cc
                        LIBS    romsjedi
                      )

ecbuild_add_executable( TARGET  romsjedi_convertincrement.x
                        SOURCES ConvertIncrement.cc
                        LIBS    romsjedi
                                saber
                      )

ecbuild_add_executable( TARGET  romsjedi_diffstates.x
                        SOURCES DiffStates.cc
                        LIBS    romsjedi
                      )

ecbuild_add_executable( TARGET  romsjedi_eda.x
                        SOURCES EDA.cc
                        LIBS	romsjedi
                                saber
                      )

ecbuild_add_executable( TARGET  romsjedi_ens_hofx.x
                        SOURCES EnsHofX.cc
                        LIBS    romsjedi
                      )

ecbuild_add_executable( TARGET  romsjedi_ens_meanandvariance.x
                        SOURCES EnsMeanAndVariance.cc
                        LIBS    romsjedi
                      )

ecbuild_add_executable( TARGET  romsjedi_ens_pert.x
                        SOURCES GenEnsPertB.cc
                        LIBS    romsjedi
                      )

ecbuild_add_executable( TARGET  romsjedi_ens_recenter.x
                        SOURCES EnsRecenter.cc
                        LIBS    romsjedi
                      )

ecbuild_add_executable( TARGET  romsjedi_error_covariance_toolbox.x
                        SOURCES ErrorCovarianceToolbox.cc
                        LIBS    romsjedi
                                saber
                      )

ecbuild_add_executable( TARGET  romsjedi_forecast.x
                        SOURCES Forecast.cc
                        LIBS    romsjedi
                      )

ecbuild_add_executable( TARGET  romsjedi_hofx3d.x
                        SOURCES HofX3d.cc
                        LIBS    romsjedi
                      )

ecbuild_add_executable( TARGET  romsjedi_hofx4d.x
                        SOURCES HofX4d.cc
                        LIBS    romsjedi
                      )

ecbuild_add_executable( TARGET  romsjedi_hybridgain.x
                        SOURCES HybridGain.cc
                        LIBS    romsjedi
                      )

ecbuild_add_executable( TARGET  romsjedi_letkf.x
                        SOURCES LETKF.cc
                        LIBS    romsjedi
                      )

ecbuild_add_executable( TARGET  romsjedi_var.x
                        SOURCES Var.cc
                        LIBS    romsjedi
                                saber
                      )

# Error during: compilation:

#ecbuild_add_executable( TARGET  romsjedi_convertstate.x
#                        SOURCES ConvertState.cc
#                        LIBS    romsjedi
#                      )
# Users/arango/ocean/repository/git/roms-jedi/Bundle/oops/src/oops/runs/ConvertState.h(115): error: class "romsjedi::VariableChangeParametersWrapper" has no member "outputVariables"
#            varout = *varchangeparams.varChange.outputVariables.value();
