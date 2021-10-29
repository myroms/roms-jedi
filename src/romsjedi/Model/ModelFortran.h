/*
 * (C) Copyright 2017-2021 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 *
 *!
 * \brief   C++ to Fortran binding functions for initializing, running, and
 *          finalizing ROMS nonlinear kernel
 *
 * \details These functions are used by the **Model** class to creates/destroy,
 *          initialize, step, and finalize ROMS for a particular JEDI
 *          applicationn.
 *
 * \author  Hernan G. Arango (Rutgers University)
 * \date    September 2021
 */

#ifndef ROMSJEDI_MODEL_MODELFORTRAN_H_
#define ROMSJEDI_MODEL_MODELFORTRAN_H_

#include "romsjedi/Fortran.h"

// Forward declarations

namespace eckit {
  class Configuration;
}

namespace romsjedi {

  extern "C" {
    void roms_model_create_f90(const eckit::Configuration &,
                               const F90geom &,
                               F90model &);
    void roms_model_delete_f90(F90model &);
    void roms_model_initialize_f90(const F90model &,
                                   const F90flds &);
    void roms_model_step_f90(const F90model &,
                             const F90flds &,
                             const F90geom &,
                             util::DateTime * const *);
    void roms_model_finalize_f90(const F90model &,
                                 const F90flds &);
  }

}  // namespace romsjedi

#endif  // ROMSJEDI_MODEL_MODELFORTRAN_H_
