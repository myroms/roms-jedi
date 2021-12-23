/*
 * (C) Copyright 2017-2021 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#pragma once

#include "romsjedi/Fortran.h"

// Forward declarations

namespace eckit {
  class Configuration;
}

namespace util {
  class DateTime;
  class Duration;
}

namespace romsjedi {

  extern "C" {
    void roms_trajectory_set_f90(F90traj &,
                                 const F90flds &,
                                 util::DateTime * const *);
    void roms_trajectory_destroy_f90(F90traj &);
  }

// -----------------------------------------------------------------------------

}  // namespace romsjedi
