/*
 * (C) Copyright 2017-2025 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 *
 *!
 * \brief   C++ to Fortran binding functions for initializing, running, and
 *          finalizing ROMS tangent linear and adjoint kernels.
 *
 * \details These functions are used by the **LinearModel** Class to
 *          create/destroy, initialize, step, and finalize TLROMS and ADROMS
 *          for a particular JEDI applicationn.
 *
 * \author  Hernan G. Arango (Rutgers University)
 * \date    September 2021
 */

#ifndef ROMSJEDI_LINEARMODEL_LINEARMODELFORTRAN_H_
#define ROMSJEDI_LINEARMODEL_LINEARMODELFORTRAN_H_

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
    void roms_linearModel_create_f90(F90lm &,
                                     const F90geom &,
                                     const eckit::Configuration &);
    void roms_linearModel_delete_f90(F90lm &);

    void roms_linearModel_initialize_tl_f90(const F90lm &,
                                            const F90geom &,
                                            const F90flds &,
                                            const F90traj &,
                                            const F90traj &,
                                            const double &,
                                            const double &,
                                            util::DateTime * const *);
    void roms_linearModel_step_tl_f90(const F90lm &,
                                      const F90geom &,
                                      const F90flds &,
                                      const F90traj &,
                                      const F90traj &,
                                      const double &,
                                      const double &,
                                      util::DateTime * const *);
    void roms_linearModel_finalize_tl_f90(const F90lm &,
                                          const F90geom &,
                                          const F90flds &);


    void roms_linearModel_initialize_ad_f90(const F90lm &,
                                            const F90geom &,
                                            const F90flds &,
                                            const F90traj &,
                                            const F90traj &,
                                            const double &,
                                            const double &,
                                            util::DateTime * const *);
    void roms_linearModel_step_ad_f90(const F90lm &,
                                      const F90geom &,
                                      const F90flds &,
                                      const F90traj &,
                                      const F90traj &,
                                      const double &,
                                      const double &,
                                      util::DateTime * const *);
    void roms_linearModel_finalize_ad_f90(const F90lm &,
                                          const F90geom &,
                                          const F90flds &);
  }

}  // namespace romsjedi

#endif  // ROMSJEDI_LINEARMODEL_LINEARMODELFORTRAN_H_
