/*
 * (C) Copyright 2021-2025 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMSJEDI_VARIABLECHANGE_MODEL2ANALYSIS_VARCHAMODEL2ANALYSISFORTRAN_H_
#define ROMSJEDI_VARIABLECHANGE_MODEL2ANALYSIS_VARCHAMODEL2ANALYSISFORTRAN_H_

#include "romsjedi/Fortran.h"

namespace romsjedi {

  extern "C" {
    void roms_vc_model2analysis_changeVar_f90(const F90vc_M2A &,
                                              const F90geom &,
                                              const F90flds &,
                                              F90flds &);

    void roms_vc_model2analysis_changeVarInverse_f90(const F90vc_M2A &,
                                                     const F90geom &,
                                                     const F90flds &,
                                                     F90flds &);
  }
}  // namespace romsjedi

#endif  // ROMSJEDI_VARIABLECHANGE_MODEL2ANALYSIS_VARCHAMODEL2ANALYSISFORTRAN_H_
