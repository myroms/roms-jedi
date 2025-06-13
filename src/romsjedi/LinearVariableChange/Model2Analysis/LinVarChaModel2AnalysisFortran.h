/*
 * (C) Copyright 2024-2025 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMSJEDI_LINEARVARIABLECHANGE_MODEL2ANALYSIS_LINVARCHAMODEL2ANALYSISFORTRAN_H_
#define ROMSJEDI_LINEARVARIABLECHANGE_MODEL2ANALYSIS_LINVARCHAMODEL2ANALYSISFORTRAN_H_

#include "romsjedi/Fortran.h"

// -----------------------------------------------------------------------------

namespace romsjedi {

  extern "C" {
    void roms_lvc_model2analysis_multiply_f90(const F90lvc_M2A &,
                                              const F90geom &,
                                              const F90flds &,
                                              const F90flds &);
    void roms_lvc_model2analysis_multiplyInverse_f90(const F90lvc_M2A &,
                                                     const F90geom &,
                                                     const F90flds &,
                                                     const F90flds &);
    void roms_lvc_model2analysis_multiplyAD_f90(const F90lvc_M2A &,
                                                const F90geom &,
                                                const F90flds &,
                                                const F90flds &);
    void roms_lvc_model2analysis_multiplyInverseAD_f90(const F90lvc_M2A &,
                                                       const F90geom &,
                                                       const F90flds &,
                                                       const F90flds &);
  }
}  // namespace romsjedi

// -----------------------------------------------------------------------------

#endif  // ROMSJEDI_LINEARVARIABLECHANGE_MODEL2ANALYSIS_LINVARCHAMODEL2ANALYSISFORTRAN_H_
