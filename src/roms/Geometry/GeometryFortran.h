/*
 * (C) Copyright 2017-2020 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMS_GEOMETRY_GEOMETRYFORTRAN_H_
#define ROMS_GEOMETRY_GEOMETRYFORTRAN_H_

#include "roms/Fortran.h"

// Forward declarations

namespace eckit {
  class Configuration;
}

namespace roms {

  extern "C" {
    void roms_geo_setup_f90(F90geom &,
                            const eckit::Configuration * const *,
                            const eckit::mpi::Comm *);
    void roms_geo_clone_f90(F90geom &, const F90geom &);
    void roms_geo_delete_f90(F90geom &);
  }
}  // namespace roms

#endif  // ROMS_GEOMETRY_GEOMETRYFORTRAN_H_
