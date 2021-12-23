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
 * \details These functions are used by the **LinearGetValues**  class to
 *          fill the state **GeoVaLs** at the observation locations.
 *
 * \author  Hernan G. Arango (Rutgers University)
 * \date    June 2021
 */

#ifndef ROMSJEDI_GETVALUES_LINEARGETVALUESFORTRAN_H_
#define ROMSJEDI_GETVALUES_LINEARGETVALUESFORTRAN_H_

#include "romsjedi/Fortran.h"

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

// -----------------------------------------------------------------------------

namespace romsjedi {

  extern "C" {
    void roms_lineargetvalues_create_f90(F90lingetval &,
                                         const F90geom &,
                                         const ufo::Locations &);

    void roms_lineargetvalues_delete_f90(F90getval &);

    void roms_lineargetvalues_set_trajectory_f90(const F90lingetval &,
                                                 const F90geom &,
                                                 const F90flds &,
                                                 const util::DateTime &,
                                                 const util::DateTime &,
                                                 const ufo::Locations &,
                                                 const F90goms &);

    void roms_lineargetvalues_fill_geovals_tl_f90(const F90lingetval &,
                                                  const F90geom &,
                                                  const F90flds &,
                                                  const util::DateTime &,
                                                  const util::DateTime &,
                                                  const ufo::Locations &,
                                                  const F90goms &);

    void roms_lineargetvalues_fill_geovals_ad_f90(const F90lingetval &,
                                                  const F90geom &,
                                                  const F90flds &,
                                                  const util::DateTime &,
                                                  const util::DateTime &,
                                                  const ufo::Locations &,
                                                  const F90goms &);
  }
}  // namespace romsjedi

// -----------------------------------------------------------------------------

#endif  // ROMSJEDI_GETVALUES_LINEARGETVALUESFORTRAN_H_
