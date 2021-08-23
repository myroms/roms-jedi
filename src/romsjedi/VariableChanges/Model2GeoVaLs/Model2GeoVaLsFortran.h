/*
 * (C) Copyright 2021-2021 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMSJEDI_VARIABLECHANGES_MODEL2GEOVALS_MODEL2GEOVALSFORTRAN_H_
#define ROMSJEDI_VARIABLECHANGES_MODEL2GEOVALS_MODEL2GEOVALSFORTRAN_H_

#include "romsjedi/Fortran.h"

namespace romsjedi {

  extern "C" {
    void roms_model2geovals_changevar_f90(const F90geom &,
                                          const F90flds &,
                                          F90flds &);
    void roms_model2geovals_linear_changevar_f90(const F90geom &,
                                                 const F90flds &,
                                                 F90flds &);
    void roms_model2geovals_linear_changevarAD_f90(const F90geom &,
                                                   const F90flds &,
                                                   F90flds &);
  }
}  // namespace romsjedi

#endif  // ROMSJEDI_VARIABLECHANGES_MODEL2GEOVALS_MODEL2GEOVALSFORTRAN_H_
