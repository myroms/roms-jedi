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

#ifndef ROMSJEDI_ANALYTICINIT_ANALYTICINITFORTRAN_H_
#define ROMSJEDI_ANALYTICINIT_ANALYTICINITFORTRAN_H_

#include <string>

#include "romsjedi/Fortran.h"

// Forward declarations

namespace ufo {
  class Locations;
}

namespace romsjedi {

  extern "C" {
    void roms_analytic_geovals_f90(F90goms &,
                                   const ufo::Locations &,
                                   const int &, const char *,
                                   const double & T0,
                                   const double & S0,
                                   const double & U0,
                                   const double & V0);
  }

}  // namespace romsjedi
#endif  // ROMSJEDI_ANALYTICINIT_ANALYTICINITFORTRAN_H_

