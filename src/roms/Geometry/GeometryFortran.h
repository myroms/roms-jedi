/*
 * (C) Copyright 2017-2021 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMS_GEOMETRY_GEOMETRYFORTRAN_H_
#define ROMS_GEOMETRY_GEOMETRYFORTRAN_H_

#include "oops/base/Variables.h"
#include "roms/Fortran.h"

// Forward declarations

namespace eckit {
  class Configuration;
}

namespace roms {

  extern "C" {
    void roms_geo_setup_f90(F90geom &,
                            const eckit::Configuration * const &,
                            const eckit::mpi::Comm *);
    void roms_geo_clone_f90(F90geom &, const F90geom &);
    void roms_geo_delete_f90(F90geom &);
    void roms_geo_info_f90(const F90geom &, int &, int &, int &, int &, int &,
                           int &, int &, int &, int &, int &, int &, int &);
    void roms_geo_start_end_f90(const F90geom &, int &, int &, int &, int &,
                                int &);
    void roms_geo_get_num_levels_f90(const F90geom &, const oops::Variables &,
                                     const size_t &, size_t[]);
  }
}  // namespace roms

#endif  // ROMS_GEOMETRY_GEOMETRYFORTRAN_H_
