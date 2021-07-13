/*
 * (C) Copyright 2020-2021 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 *
 *!
 * \brief   C++ to Fortran binding functions for interpolating the state at
 *          observation locations
 *
 * \details These functions are used by the **GetValues**  class to fill the
 *          state **GeoVaLs** at the observation locations.
 *
 * \author  Hernan G. Arango (Rutgers University)
 * \date    June 2021
 */

#ifndef ROMS_GETVALUES_GETVALUESFORTRAN_H_
#define ROMS_GETVALUES_GETVALUESFORTRAN_H_

#include "roms/Fortran.h"

// Forward declarations

namespace eckit {
  class Configuration;
}

namespace ufo {
  class Locations;
}

namespace util {
  class DateTime;
  class Duration;
}

namespace roms {

  extern "C" {
    void roms_getvalues_create_f90(F90getval &,
                                   const F90geom &,
                                   const ufo::Locations &);
    void roms_getvalues_delete_f90(F90getval &);
    void roms_getvalues_fill_geovals_f90(const F90getval &,
                                         const F90geom &,
                                         const F90flds &,
                                         const util::DateTime &,
                                         const util::DateTime &,
                                         const ufo::Locations &,
                                         const F90goms &);
    void roms_getvalues_fill_geovals_tl_f90(const F90getval &,
                                            const F90geom &,
                                            const F90flds &,
                                            const util::DateTime &,
                                            const util::DateTime &,
                                            const ufo::Locations &,
                                            const F90goms &);
    void roms_getvalues_fill_geovals_ad_f90(const F90getval &,
                                            const F90geom &,
                                            const F90flds &,
                                            const util::DateTime &,
                                            const util::DateTime &,
                                            const ufo::Locations &,
                                            const F90goms &);
  }
}  // namespace roms
#endif  // ROMS_GETVALUES_GETVALUESFORTRAN_H_
