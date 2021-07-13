/*
 * (C) Copyright 2017-2021 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 *
 *!
 * \brief   Interface to Fortran analytical initialization routine
 *
 * \details The interface compute analytical values at the observation
 *          locations.  It is used the test the GeoVaLs interpolation.
 *
 * \author  Hernan G. Arango (Rutgers University)
 * \date    July 2021
 */

#ifndef ROMS_ANALYTICINIT_ANALYTICINITFORTRAN_H_
#define ROMS_ANALYTICINIT_ANALYTICINITFORTRAN_H_

#include "roms/Fortran.h"

// Forward declarations

namespace eckit {
  class Configuration;
}

namespace ufo {
  class Locations;
}

namespace roms {

  extern "C" {
    void roms_analytic_init_f90(F90goms &,
                                const ufo::Locations &,
                                const eckit::Configuration &);
  }

}  // namespace roms
#endif  // ROMS_ANALYTICINIT_ANALYTICINITFORTRAN_H_

