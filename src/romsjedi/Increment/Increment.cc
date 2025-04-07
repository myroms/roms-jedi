/*
 * (C) Copyright 2017-2025 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 *
 *!
 * \brief   **Increment Class** C++ ROMS-JEDI interface
 *
 * \details It implements several methods in each field of the **Increment**
 *          object, such as mathematical and algebraic operations, reading,
 *          and writing. Thus, there is a fair amount of overlap with the
 *          **Fields** and **State** objects.
 *
 * \author  Hernan G. Arango (Rutgers University)
 * \date    October 2021
 */

#include <algorithm>
#include <iomanip>
#include <ios>
#include <iostream>
#include <numeric>
#include <sstream>
#include <string>
#include <vector>

#include "atlas/field.h"

#include "eckit/config/LocalConfiguration.h"
#include "eckit/exception/Exceptions.h"

#include "oops/base/Variables.h"
#include "oops/util/DateTime.h"
#include "oops/util/Duration.h"
#include "oops/util/FieldSetOperations.h"
#include "oops/util/Logger.h"

#include "ufo/GeoVaLs.h"

#include "romsjedi/Geometry/Geometry.h"
#include "romsjedi/GeometryIterator/GeometryIterator.h"
#include "romsjedi/Increment/Increment.h"
#include "romsjedi/State/State.h"

using oops::Log;

namespace romsjedi {

// -----------------------------------------------------------------------------
/// Constructors, desructor
// -----------------------------------------------------------------------------

  Increment::Increment(const Geometry & geom,
                       const oops::Variables & vars,
                       const util::DateTime & vt)
    : time_(vt),
      vars_(vars),
      geom_(geom)
  {
    Log::trace() << classname() << ":Increment create from geom/vars starting"
                 << std::endl;
    roms_increment_create_f90(keyFlds_,
                              geom_.toFortran(),
                              vars_);

    roms_increment_zero_f90(toFortran());
    Log::trace() << classname() << ":Increment constructed"
                 << std::endl;
  }

// -----------------------------------------------------------------------------

  Increment::Increment(const Geometry & geom,
                       const Increment & other)
    : time_(other.time_),
      vars_(other.vars_),
      geom_(geom)
  {
    Log::trace() << classname() << ":Increment create from other starting"
                 << std::endl;
    roms_increment_create_f90(keyFlds_,
                              geom_.toFortran(),
                              vars_);

    roms_increment_change_resol_f90(toFortran(),
                                    other.keyFlds_);
    Log::trace() << classname() << ":Increment constructed from other"
                 << std::endl;
  }

// -----------------------------------------------------------------------------

  Increment::Increment(const Increment & other,
                       const bool copy)
    : time_(other.time_),
      vars_(other.vars_),
      geom_(other.geom_)
  {
    Log::trace() << classname() << ":Increment create from bool copy starting"
                 << std::endl;
    roms_increment_create_f90(keyFlds_,
                              geom_.toFortran(),
                              vars_);

    if (copy) {
      roms_increment_copy_f90(toFortran(),
                              other.toFortran());
    } else {
      roms_increment_zero_f90(toFortran());
    }
    Log::trace() << classname() << ":Increment copy-created"
                 << std::endl;
  }

// -----------------------------------------------------------------------------

  Increment::Increment(const Increment & other)
    : time_(other.time_),
      vars_(other.vars_),
      geom_(other.geom_)
  {
    Log::trace() << classname() << ":Increment create copy from other starting"
                 << std::endl;
    roms_increment_create_f90(keyFlds_,
                              geom_.toFortran(),
                              vars_);

    roms_increment_copy_f90(toFortran(),
                            other.toFortran());
    Log::trace() << classname() << ":Increment copy-created"
                 << std::endl;
  }

// -----------------------------------------------------------------------------

  Increment::~Increment() {
    roms_increment_delete_f90(toFortran());
    Log::trace() << classname() << ":Increment destructed"
                 << std::endl;
  }

// -----------------------------------------------------------------------------
/// Basic operators
// -----------------------------------------------------------------------------

  void Increment::diff(const State & x1,
                       const State & x2) {
    ASSERT(this->validTime() == x1.validTime());
    ASSERT(this->validTime() == x2.validTime());
    State x1_at_geomres(geom_, x1);
    State x2_at_geomres(geom_, x2);
    roms_increment_diff_incr_f90(toFortran(),
                                 x1_at_geomres.toFortran(),
                                 x2_at_geomres.toFortran());
  }

// -----------------------------------------------------------------------------

  Increment & Increment::operator=(const Increment & rhs) {
    time_ = rhs.time_;
    roms_increment_copy_f90(toFortran(),
                            rhs.toFortran());
    return *this;
  }

// -----------------------------------------------------------------------------

  Increment & Increment::operator+=(const Increment & dx) {
    ASSERT(this->validTime() == dx.validTime());
    roms_increment_self_add_f90(toFortran(),
                                dx.toFortran());
    return *this;
  }

// -----------------------------------------------------------------------------

  Increment & Increment::operator-=(const Increment & dx) {
    ASSERT(this->validTime() == dx.validTime());
    roms_increment_self_sub_f90(toFortran(),
                                dx.toFortran());
    return *this;
  }

// -----------------------------------------------------------------------------

  Increment & Increment::operator*=(const double & zz) {
    roms_increment_self_mul_f90(toFortran(),
                                zz);
    return *this;
  }

// -----------------------------------------------------------------------------

  void Increment::ones() {
    roms_increment_ones_f90(toFortran());
  }

// -----------------------------------------------------------------------------

  void Increment::sqrt() {
    oops::Log::trace() << classname() << ":sqrt starting" 
                       << std::endl;
    atlas::FieldSet fset{};
    toFieldSet(fset);
    util::sqrtFieldSet(fset);
    fromFieldSet(fset);
    oops::Log::trace() << classname() << ":sqrt done"
                       << std::endl;
  }

// -----------------------------------------------------------------------------

  void Increment::zero() {
    roms_increment_zero_f90(toFortran());
  }

// -----------------------------------------------------------------------------

  void Increment::dirac(const eckit::Configuration & config) {
    roms_increment_dirac_f90(toFortran(),
                             config);
    Log::trace() << classname() << ":dirac initialized"
                 << std::endl;
  }

// -----------------------------------------------------------------------------

  void Increment::zero(const util::DateTime & vt) {
    zero();
    time_ = vt;
  }

// -----------------------------------------------------------------------------

  void Increment::axpy(const double & zz,
                       const Increment & dx,
                       const bool check) {
    ASSERT(!check || validTime() == dx.validTime());
    roms_increment_axpy_f90(toFortran(),
                            zz,
                            dx.toFortran());
  }

// -----------------------------------------------------------------------------

  void Increment::accumul(const double & zz,
                          const State & xx) {
    roms_increment_accumul_f90(toFortran(),
                               zz,
                               xx.toFortran());
  }

// -----------------------------------------------------------------------------

  void Increment::schur_product_with(const Increment & dx) {
    roms_increment_self_schur_f90(toFortran(),
                                  dx.toFortran());
  }

// -----------------------------------------------------------------------------

  double Increment::dot_product_with(const Increment & other) const {
    double zz;
    roms_increment_dot_prod_f90(toFortran(),
                                other.toFortran(),
                                zz);
    Log::debug() << classname() << ":dot_product_with = "
                 << std::setprecision(15) << zz << std::endl;
    return zz;
  }

// -----------------------------------------------------------------------------

  void Increment::random() {
    roms_increment_random_f90(toFortran());
    Log::trace() << classname() << ":random field initialization"
                 << std::endl;
  }

// -----------------------------------------------------------------------------

  oops::LocalIncrement Increment::getLocal(
                        const GeometryIterator & iter) const {
    int nx, ny, nz, nf;
    roms_increment_sizes_f90(toFortran(),
                             nx, ny, nz, nf);

    oops::Variables fieldNames = vars_;

    std::vector<int> varlens(fieldNames.size());
    for (unsigned int ii = 0; ii < fieldNames.size(); ii++) {
      varlens[ii] = nz;
    }

    int lenvalues = std::accumulate(varlens.begin(), varlens.end(), 0);
    std::vector<double> values(lenvalues);


    // Get variable values

    roms_increment_getpoint_f90(keyFlds_,
                                iter.toFortran(),
                                values[0],
                                values.size());

    return oops::LocalIncrement(oops::Variables(fieldNames), values, varlens);
  }

// -----------------------------------------------------------------------------

  void Increment::setLocal(const oops::LocalIncrement & values,
                           const GeometryIterator & iter) {
    const std::vector<double> vals = values.getVals();
    roms_increment_setpoint_f90(toFortran(),
                                iter.toFortran(),
                                vals[0],
                                vals.size());
  }

// -----------------------------------------------------------------------------

  void Increment::updateFields(const oops::Variables & Vars) {
    vars_ = Vars;
    Log::trace() << classname() << ":updateFields starting"
                 << std::endl;
    Log::debug() << classname() << " Vars in: " << Vars
                 << std::endl;
    roms_increment_update_fields_f90(toFortran(),
                                     vars_);
    Log::trace() << classname() << ":updateFields done"
                 << std::endl;
  }

// -----------------------------------------------------------------------------
/// ATLAS
// -----------------------------------------------------------------------------

  void Increment::toFieldSet(atlas::FieldSet & fset) const {
    Log::trace() << classname() << ":toFieldSet starting"
                 << std::endl;
    Log::debug() << classname() << ":toFieldSet vars = " << vars_
                 << std::endl;
    roms_increment_to_fieldset_f90(toFortran(),
                                   geom_.toFortran(),
                                   vars_,
                                   fset.get());
    Log::trace() << classname() << ":toFieldSet done"
                 << std::endl;
  }

// -----------------------------------------------------------------------------

  void Increment::fromFieldSet(const atlas::FieldSet & fset) {
    Log::trace() << classname() << ":fromFieldSet starting"
                 << std::endl;
    Log::debug() << classname() << ":fromFieldSet vars = " << vars_
                 << std::endl;
    roms_increment_from_fieldset_f90(toFortran(),
                                     geom_.toFortran(),
                                     vars_,
                                     fset.get());
    Log::trace() << classname() << ":fromFieldSet done"
                 << std::endl;
  }

// -----------------------------------------------------------------------------
/// I/O and diagnostics
// -----------------------------------------------------------------------------

  void Increment::read(const eckit::Configuration & config) {
    util::DateTime * dtp = &time_;
    roms_increment_read_file_f90(toFortran(),
                                 config,
                                 &dtp);
  }

// -----------------------------------------------------------------------------

  void Increment::write(const eckit::Configuration & config) const {
    const util::DateTime * dtp = &time_;
    roms_increment_write_file_f90(toFortran(),
                                  config,
                                  &dtp);
  }

// -----------------------------------------------------------------------------

  void Increment::print(std::ostream & os) const {
    os << std::endl << "  Valid time: " << validTime();
    int n0, nf;
    roms_increment_sizes_f90(keyFlds_,
                             n0, n0, n0, nf);

    std::vector<double> zstat(4*nf);
    roms_increment_gstats_f90(keyFlds_,
                              nf,
                              zstat[0]);

    for (int jj = 0; jj < nf; ++jj) {
      os << std::endl << std::right << std::setw(60) << vars_[jj]
                      << std::setprecision(15)
                      << "   Min= "      << std::fixed << std::setw(21) <<
                                            std::right << zstat[4*jj]
                      << "   Max= "      << std::fixed << std::setw(21) <<
                                            std::right << zstat[4*jj+1]
                      << "   Mean= "     << std::fixed << std::setw(21) <<
                                            std::right << zstat[4*jj+2];
      //              << "   CheckSum= " << std::fixed << std::right <<
      //                                    static_cast<int>(zstat[4*jj+3]);
    }
  }

// -----------------------------------------------------------------------------

  double Increment::norm() const {
    double zz = 0.0;
    roms_increment_norm_f90(toFortran(),
                            zz);
    Log::debug() << classname() << ":norm zz = "
                 << std::setprecision(15)  << zz << std::endl;
    return zz;
  }

// -----------------------------------------------------------------------------

  const util::DateTime & Increment::validTime() const {return time_;}

// -----------------------------------------------------------------------------

  util::DateTime & Increment::validTime() {return time_;}

// -----------------------------------------------------------------------------

  void Increment::updateTime(const util::Duration & dt) {time_ += dt;}

// -----------------------------------------------------------------------------

  size_t Increment::serialSize() const {
    size_t nn;
    roms_increment_serial_size_f90(toFortran(),
                                   geom_.toFortran(),
                                   nn);
    nn += 1;
    nn += time_.serialSize();
    return nn;
  }

// -----------------------------------------------------------------------------

  constexpr double SerializeCheckValue = -54321.98765;
  void Increment::serialize(std::vector<double> & vect) const {
    // Serialize the field

    size_t nn;
    roms_increment_serial_size_f90(toFortran(),
                                   geom_.toFortran(),
                                   nn);

    std::vector<double> vect_field(nn, 0);
    vect.reserve(vect.size() + nn + 1 + time_.serialSize());
    roms_increment_serialize_f90(toFortran(),
                                 geom_.toFortran(),
                                 nn,
                                 vect_field.data());
    vect.insert(vect.end(), vect_field.begin(), vect_field.end());

    // Magic value placed in serialization; used to validate deserialization

    vect.push_back(SerializeCheckValue);

    // Serialize the date and time
    time_.serialize(vect);
  }

// -----------------------------------------------------------------------------

  void Increment::deserialize(const std::vector<double> & vect,
                              size_t & index) {
    // Deserialize the field

    roms_increment_deserialize_f90(toFortran(),
                                   geom_.toFortran(),
                                   vect.size(),
                                   vect.data(),
                                   index);

    // Use magic value to validate deserialization

    ASSERT(vect.at(index) == SerializeCheckValue);
    ++index;

    // Deserialize the date and time

    time_.deserialize(vect, index);
  }

// -----------------------------------------------------------------------------

}  // namespace romsjedi
