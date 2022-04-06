/*
 * (C) Copyright 2020-2022 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 *
 *!
 * \brief   C++ to Fortran binding functions for ROMS-JEDI **Increment** Object
 *
 * \details The **Increment** Class uses the functions below to implement
 *          several methods, such ad mathematical and algebraic operations,
 *          reading, and writing.
 *
 * \author  Hernan G. Arango (Rutgers University)
 * \date    October 2021
 */

#ifndef ROMSJEDI_INCREMENT_INCREMENTFORTRAN_H_
#define ROMSJEDI_INCREMENT_INCREMENTFORTRAN_H_

#include "oops/base/Variables.h"
#include "romsjedi/Fortran.h"

namespace atlas {
  namespace field {
    class FieldSetImpl;
  }
}

namespace eckit {
  class Configuration;
}

namespace util {
  class DateTime;
  class Duration;
}

//------------------------------------------------------------------------------

namespace romsjedi {

  extern "C" {
    void roms_increment_create_f90(F90flds &,
                                   const F90geom &,
                                   const oops::Variables &);
    void roms_increment_delete_f90(F90flds &);

    void roms_increment_copy_f90(const F90flds &,
                                 const F90flds &);

    void roms_increment_ones_f90(const F90flds &);

    void roms_increment_zero_f90(const F90flds &);

    void roms_increment_self_add_f90(const F90flds &,
                                     const F90flds &);

    void roms_increment_self_sub_f90(const F90flds &,
                                     const F90flds &);

    void roms_increment_self_mul_f90(const F90flds &,
                                     const double &);

    void roms_increment_accumul_f90(const F90flds &,
                                    const double &,
                                    const F90flds &);

    void roms_increment_axpy_f90(const F90flds &,
                                 const double &,
                                 const F90flds &);

    void roms_increment_dot_prod_f90(const F90flds &,
                                     const F90flds &,
                                     double &);

    void roms_increment_self_schur_f90(const F90flds &,
                                       const F90flds &);

    void roms_increment_random_f90(const F90flds &);

    void roms_increment_dirac_f90(const F90flds &,
                                  const eckit::Configuration &);

    void roms_increment_diff_incr_f90(const F90flds &,
                                      const F90flds &,
                                      const F90flds &);

    void roms_increment_change_resol_f90(const F90flds &,
                                         const F90flds &);

    void roms_increment_read_file_f90(const F90flds &,
                                      const eckit::Configuration &,
                                      util::DateTime * const *);

    void roms_increment_write_file_f90(const F90flds &,
                                       const eckit::Configuration &,
                                       const util::DateTime * const *);

    void roms_increment_update_fields_f90(F90flds &,
                                          const oops::Variables &);

    void roms_increment_set_atlas_f90(const F90flds &,
                                      const F90geom &,
                                      const oops::Variables &,
                                      atlas::field::FieldSetImpl *,
                                      const bool &);

    void roms_increment_to_atlas_f90(const F90flds &,
                                     const F90geom &,
                                     const oops::Variables &,
                                     atlas::field::FieldSetImpl *,
                                     const bool &);

    void roms_increment_from_atlas_f90(const F90flds &,
                                       const F90geom &,
                                       const oops::Variables &,
                                       const atlas::field::FieldSetImpl *,
                                       const bool &);

    void roms_increment_gpnorm_f90(const F90flds &,
                                   const int &,
                                   double &);

    void roms_increment_getpoint_f90(const F90flds &,
                                     const F90iter &,
                                     double &,
                                     const int &);

    void roms_increment_setpoint_f90(F90flds &,
                                     const F90iter &,
                                     const double &,
                                     const int &);

    void roms_increment_sizes_f90(const F90flds &,
                                  int &,
                                  int &,
                                  int &,
                                  int &);

    void roms_increment_rms_f90(const F90flds &,
                                double &);

    void roms_increment_serial_size_f90(const F90flds &,
                                        const F90geom &,
                                        size_t &);

    void roms_increment_serialize_f90(const F90flds &,
                                      const F90geom &,
                                      const size_t &,
                                      double[]);

    void roms_increment_deserialize_f90(const F90flds &,
                                        const F90geom &,
                                        const size_t &,
                                        const double[],
                                        size_t &);
  }
}  // namespace romsjedi

//------------------------------------------------------------------------------

#endif  // ROMSJEDI_INCREMENT_INCREMENTFORTRAN_H_
