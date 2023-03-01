# (C) Copyright 2017-2023 UCAR
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

ecbuild_add_executable( TARGET  romsjedi_dirac.x
                        SOURCES Dirac.cc
                        LIBS    romsjedi
                                saber
                      )

ecbuild_add_executable( TARGET  romsjedi_eda.x
                        SOURCES EDA.cc
                        LIBS	romsjedi
                                saber
                      )

ecbuild_add_executable( TARGET  romsjedi_enshofx.x
                        SOURCES EnsHofX.cc
                        LIBS    romsjedi
                      )

ecbuild_add_executable( TARGET  romsjedi_ensmeanvariance.x
                        SOURCES EnsMeanVariance.cc
                        LIBS    romsjedi
                      )

ecbuild_add_executable( TARGET  romsjedi_enspert.x
                        SOURCES GenEnsPertB.cc
                        LIBS    romsjedi
                      )

ecbuild_add_executable( TARGET  romsjedi_ensrecenter.x
                        SOURCES EnsRecenter.cc
                        LIBS    romsjedi
                      )

ecbuild_add_executable( TARGET  romsjedi_ensvariance.x
                        SOURCES EnsVariance.cc
                        LIBS    romsjedi
                      )

ecbuild_add_executable( TARGET  romsjedi_error_covariance_training.x
                        SOURCES ErrorCovarianceTraining.cc
                        LIBS    romsjedi
                                saber
                      )

ecbuild_add_executable( TARGET  romsjedi_forecast.x
                        SOURCES Forecast.cc
                        LIBS    romsjedi
                      )

ecbuild_add_executable( TARGET  romsjedi_hofx_nomodel.x
                        SOURCES HofXNoModel.cc
                        LIBS    romsjedi
                      )

ecbuild_add_executable( TARGET  romsjedi_hofx.x
                        SOURCES HofX.cc
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

ecbuild_add_executable( TARGET  romsjedi_staticbinit.x
                        SOURCES StaticBInit.cc
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
