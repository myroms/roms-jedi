/*
 * (C) Copyright 2020-2020 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMS_INCREMENT_INCREMENTFORTRAN_H_
#define ROMS_INCREMENT_INCREMENTFORTRAN_H_

#include "roms/Fortran.h"
#include "oops/base/Variables.h"

namespace eckit {
  class Configuration;
}

namespace util {
  class DateTime;
  class Duration;
}

namespace roms {

  extern "C" {
    void roms_increment_create_f90(F90flds &, const F90geom &,
                               const oops::Variables &);
    void roms_increment_delete_f90(F90flds &);
    void roms_increment_copy_f90(const F90flds &, const F90flds &);
    void roms_increment_ones_f90(const F90flds &);
    void roms_increment_zero_f90(const F90flds &);
    void roms_increment_self_add_f90(const F90flds &, const F90flds &);
    void roms_increment_self_sub_f90(const F90flds &, const F90flds &);
    void roms_increment_self_mul_f90(const F90flds &, const double &);
    void roms_increment_accumul_f90(const F90flds &, const double &,
                                    const F90flds &);
    void roms_increment_axpy_f90(const F90flds &, const double &,
                                 const F90flds &);
    void roms_increment_dot_prod_f90(const F90flds &, const F90flds &,
                                     double &);
    void roms_increment_self_schur_f90(const F90flds &, const F90flds &);
    void roms_increment_random_f90(const F90flds &);
    void roms_increment_dirac_f90(const F90flds &,
                              const eckit::Configuration * const &);
    void roms_increment_diff_incr_f90(const F90flds &, const F90flds &,
                                  const F90flds &);
    void roms_increment_change_resol_f90(const F90flds &, const F90flds &);
    void roms_increment_read_file_f90(const F90flds &,
                                  const eckit::Configuration * const &,
                                  util::DateTime * const *);
    void roms_increment_write_file_f90(const F90flds &,
                                   const eckit::Configuration * const &,
                                   const util::DateTime * const *);
    void roms_increment_gpnorm_f90(const F90flds &, const int &, double &);
    void roms_increment_getpoint_f90(const F90flds &, const F90iter &, double &,
                           const int &);
    void roms_increment_setpoint_f90(F90flds &, const F90iter &, const double &,
                           const int &);
    void roms_increment_sizes_f90(const F90flds &, int &,
                              int &, int &, int &);
    void roms_increment_rms_f90(const F90flds &, double &);
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
}  // namespace roms

#endif  // ROMS_INCREMENT_INCREMENTFORTRAN_H_
