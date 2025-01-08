/*
 * (C) Copyright 2021-2025 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMSJEDI_LINEARVARIABLECHANGE_MODEL2GEOVALS_LINVARCHAMODEL2GEOVALSFORTRAN_H_
#define ROMSJEDI_LINEARVARIABLECHANGE_MODEL2GEOVALS_LINVARCHAMODEL2GEOVALSFORTRAN_H_

#include "eckit/config/Configuration.h"

#include "romsjedi/Fortran.h"

// -----------------------------------------------------------------------------

namespace romsjedi {

  extern "C" {
    void roms_lvc_model2geovals_create_f90(const F90lvc_M2G &,
                                           const F90geom &,
                                           const F90flds &,
                                           const F90flds &,
                                           const eckit::LocalConfiguration &);
    void roms_lvc_model2geovals_delete_f90(F90lvc_M2G &);
    void roms_lvc_model2geovals_multiply_f90(const F90lvc_M2G &,
                                             const F90geom &,
                                             const F90flds &,
                                             const F90flds &);
    void roms_lvc_model2geovals_multiplyAD_f90(const F90lvc_M2G &,
                                               const F90geom &,
                                               const F90flds &,
                                               const F90flds &);
  }
}  // namespace romsjedi

// -----------------------------------------------------------------------------

#endif  // ROMSJEDI_LINEARVARIABLECHANGE_MODEL2GEOVALS_LINVARCHAMODEL2GEOVALSFORTRAN_H_
