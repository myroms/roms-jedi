ecbuild_add_executable( TARGET  romsjedi_diffstates.x
                        SOURCES DiffStates.cc
                        LIBS    romsjedi)
#oops_output_json_schema(romsjedi_diffstates.x)

ecbuild_add_executable( TARGET  romsjedi_hofx_nomodel.x
                        SOURCES HofXNoModel.cc
                        LIBS    romsjedi )
#oops_output_json_schema(romsjedi_hofx_nomodel.x)

ecbuild_add_executable( TARGET  romsjedi_hofx.x
                        SOURCES HofX.cc
                        LIBS    romsjedi )
#oops_output_json_schema(romsjedi_hofx.x)

ecbuild_add_executable( TARGET  romsjedi_forecast.x
                        SOURCES Forecast.cc
                        LIBS    romsjedi )
#oops_output_json_schema(romsjedi_hofx.x)

ecbuild_add_executable( TARGET  romsjedi_error_covariance_training.x
                        SOURCES ErrorCovarianceTraining.cc
                        LIBS    romsjedi
                                saber )
#oops_output_json_schema(romsjedi_error_covariance_training.x)

#ecbuild_add_executable( TARGET  romsjedi_letkf.x
#                        SOURCES LETKF.cc
#                        LIBS    romsjedi )

#ecbuild_add_executable( TARGET  romsjedi_staticbinit.x
#                        SOURCES StaticBInit.cc
#                        LIBS    romsjedi )

#ecbuild_add_executable( TARGET  romsjedi_dirac.x
#                        SOURCES Dirac.cc
#                        LIBS    romsjedi )

#ecbuild_add_executable( TARGET  romsjedi_var.x
#                        SOURCES Var.cc
#                        LIBS    romsjedi )
