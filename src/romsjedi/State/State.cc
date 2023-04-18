/*
 * (C) Copyright 2017-2022 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#include <algorithm>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

#include "atlas/field.h"

#include "eckit/exception/Exceptions.h"

#include "oops/base/Variables.h"
#include "oops/util/DateTime.h"
#include "oops/util/Duration.h"
#include "oops/util/Logger.h"

#include "romsjedi/Geometry/Geometry.h"
#include "romsjedi/Increment/Increment.h"
#include "romsjedi/State/State.h"
#include "romsjedi/State/StateFortran.h"

#include "ufo/GeoVaLs.h"
#include "ufo/Locations.h"

using oops::Log;

namespace romsjedi {

// -----------------------------------------------------------------------------
/// Constructor, destructor
// -----------------------------------------------------------------------------

  State::State(const Geometry & geom,
               const oops::Variables & vars,
               const util::DateTime & vt)
    : time_(vt),
      vars_(vars),
      geom_(new Geometry(geom))
  {
    roms_state_create_f90(keyFlds_,
                          geom_->toFortran(),
                          vars_);
    Log::debug() << classname() << ":State created " << vars_
                 << std::endl;
  }

// -----------------------------------------------------------------------------

  State::State(const Geometry & geom,
               const Parameters_ & params)
    : time_(params.date),
      vars_(params.vars),
      geom_(new Geometry(geom))
  {
    util::DateTime * dtp = &time_;
    oops::Variables vars(vars_);
    roms_state_create_f90(keyFlds_,
                          geom_->toFortran(),
                          vars);
    if (params.FieldsFileName.value() != boost::none) {
      Log::trace() << classname() << ":State read from file"
                   << std::endl;
      roms_state_read_file_f90(toFortran(),
                               params.toConfiguration(),
                               &dtp);
    } else if (params.analyticInit.value() != boost::none) {
      Log::trace() << classname() << ":State generated analytically"
                   << std::endl;
      roms_state_analytic_f90(toFortran(),
                              params.toConfiguration(),
                              &dtp);
    }
  }

// -----------------------------------------------------------------------------

  State::State(const Geometry & geom,
               const State & other)
    : vars_(other.vars_),
      time_(other.time_),
      geom_(new Geometry(geom))
  {
    roms_state_create_f90(keyFlds_,
                          geom_->toFortran(),
                          vars_);
    roms_state_change_resol_f90(toFortran(),
                                other.keyFlds_);
    Log::trace() << classname() << ":State created by interpolation"
                 << std::endl;
  }

// -----------------------------------------------------------------------------

  State::State(const State & other)
    : vars_(other.vars_),
      time_(other.time_),
      geom_(new Geometry(*other.geom_))
  {
    roms_state_create_f90(keyFlds_,
                          geom_->toFortran(),
                          vars_);
    roms_state_copy_f90(toFortran(),
                        other.toFortran());
    Log::trace() << classname() << ":State copied" << std::endl;
  }

// -----------------------------------------------------------------------------

  State::~State() {
    roms_state_delete_f90(toFortran());
    Log::trace() << classname() << ":State destructed" << std::endl;
  }

// -----------------------------------------------------------------------------
/// Basic operators
// -----------------------------------------------------------------------------

  State & State::operator=(const State & rhs) {
    time_ = rhs.time_;
    vars_ = rhs.variables();
    roms_state_copy_f90(toFortran(),
                        rhs.toFortran());
    return *this;
  }

// -----------------------------------------------------------------------------
/// Add or remove fields
// -----------------------------------------------------------------------------

  void State::updateFields(const oops::Variables & Vars) {
    vars_ = Vars;
    Log::trace() << classname() << ":updateFields starting"
                 << std::endl;
    Log::debug() << classname() << ":updateFields Variables to process: "
                 << Vars << std::endl;
    roms_state_update_fields_f90(toFortran(),
                                 vars_);
    Log::trace() << classname() << ":updateFields done"
                 << std::endl;
  }

// -----------------------------------------------------------------------------
/// Rotations
// -----------------------------------------------------------------------------

  void State::rotate2north(const oops::Variables & u,
                           const oops::Variables & v) const {
    roms_state_rotate2north_f90(toFortran(),
                                u, v);
    Log::trace() << classname() << ":rotate2north done"
                 << std::endl;
  }

// -----------------------------------------------------------------------------

  void State::rotate2grid(const oops::Variables & u,
                          const oops::Variables & v) const {
    roms_state_rotate2grid_f90(toFortran(),
                               u, v);
    Log::trace() << classname() << ":rotate2grid done"
                 << std::endl;
  }

// -----------------------------------------------------------------------------
/// Interactions with Increments
// -----------------------------------------------------------------------------

  State & State::operator+=(const Increment & dx) {
    ASSERT(validTime() == dx.validTime());
    // Interpolate increment to analysis grid
    Increment dx_hr(*geom_, dx);
    // Add increment to background state
    roms_state_add_incr_f90(toFortran(),
                            dx_hr.toFortran());
    return *this;
  }

// -----------------------------------------------------------------------------
/// I/O and diagnostics
// -----------------------------------------------------------------------------

  void State::read(const Parameters_ & params) {
    Log::trace() << classname() << ":read starting"
                 << std::endl;
    util::DateTime * dtp = &time_;
    roms_state_read_file_f90(toFortran(),
                             params.toConfiguration(),
                             &dtp);
    Log::trace() << classname() <<":read done"
                 << std::endl;
  }

// -----------------------------------------------------------------------------

  void State::analytic_init(const Parameters_ & params) {
    util::DateTime * dtp = &time_;
    Log::trace() << classname() << ":analytic_init starting"
                 << std::endl;
    roms_state_analytic_f90(toFortran(),
                            params.toConfiguration(),
                            &dtp);
    Log::trace() << classname() << ":analytic_init done"
                 << std::endl;
  }

// -----------------------------------------------------------------------------

  void State::write(const WriteParameters_ & params) const {
    const util::DateTime * dtp = &time_;
    Log::trace() << classname() << ":write starting"
                 << std::endl;
    roms_state_write_file_f90(toFortran(),
                              params.toConfiguration(),
                              &dtp);
    Log::trace() << classname() <<":write done"
                 << std::endl;
  }

// -----------------------------------------------------------------------------

  void State::print(std::ostream & os) const {
    os << std::endl << "  Valid time: " << validTime();
    int n0, nf;
    roms_state_sizes_f90(toFortran(),
                         n0, n0, n0, nf);
    std::vector<double> zstat(4*nf);
    roms_state_gstats_f90(toFortran(),
                          nf, zstat[0]);
    for (int jj = 0; jj < nf; ++jj) {
      os << std::endl << std::right << std::setw(34) << vars_[jj]
                      << std::setprecision(15)
                      << "   Min= "      << std::fixed << std::setw(21) <<
                                            std::right << zstat[4*jj]
                      << "   Max= "      << std::fixed << std::setw(21) <<
                                            std::right << zstat[4*jj+1]
                      << "   Mean= "     << std::fixed << std::setw(21) <<
                                            std::right << zstat[4*jj+2]
                      << "   CheckSum= " << std::fixed << std::right <<
                                            static_cast<int>(zstat[4*jj+3]);
    }
  }

// -----------------------------------------------------------------------------
/// Serialization
// -----------------------------------------------------------------------------

  size_t State::serialSize() const {
    size_t nn;
    roms_state_serial_size_f90(toFortran(),
                               geom_->toFortran(),
                               nn);
    nn += 1;                                      // Magic factor
    nn += time_.serialSize();                     // Date and time
    return nn;
  }

// -----------------------------------------------------------------------------

  constexpr double SerializeCheckValue = -54321.98765;
    void State::serialize(std::vector<double> & vect) const {
      // Serialize the field
      size_t nn;
      roms_state_serial_size_f90(toFortran(),
                                 geom_->toFortran(),
                                 nn);
      std::vector<double> vect_field(nn, 0);
      vect.reserve(vect.size() + nn + 1 + time_.serialSize());
      roms_state_serialize_f90(toFortran(),
                               geom_->toFortran(),
                               nn,
                               vect_field.data());
      vect.insert(vect.end(), vect_field.begin(), vect_field.end());
      // Magic value placed in serialization; used to validate deserialization
      vect.push_back(SerializeCheckValue);
      // Serialize the date and time
      time_.serialize(vect);
  }

// -----------------------------------------------------------------------------

  void State::deserialize(const std::vector<double> & vect, size_t & index) {
    // Deserialize the field
    roms_state_deserialize_f90(toFortran(),
                               geom_->toFortran(),
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
/// For accumulator
// -----------------------------------------------------------------------------

  void State::zero() {
    roms_state_zero_f90(toFortran());
  }

// -----------------------------------------------------------------------------

  void State::accumul(const double & zz,
                      const State & xx) {
    roms_state_axpy_f90(toFortran(),
                        zz,
                        xx.toFortran());
  }

// -----------------------------------------------------------------------------

  double State::norm() const {
    double zz = 0.0;
    roms_state_rms_f90(toFortran(),
                       zz);
    Log::debug() << classname() << ":norm, RMS = SQRT(SUM(x^2)) = "
                 << std::setprecision(15) << zz << std::endl;
    return zz;
  }

// -----------------------------------------------------------------------------
/// Logarithmic and exponential transformations
// -----------------------------------------------------------------------------

  void State::logtrans(const oops::Variables & trvar) const {
    Log::trace() << classname() << ":logtrans starting"
                 << std::endl;
    roms_state_logtrans_f90(toFortran(), trvar);
    Log::trace() << classname() << ":logtrans done"
                 << std::endl;
  }

// -----------------------------------------------------------------------------

  void State::expontrans(const oops::Variables & trvar) const {
    Log::trace() << classname() << ":expontrans starting"
                 << std::endl;
    roms_state_expontrans_f90(toFortran(), trvar);
    Log::trace() << classname() << ":expontrans done"
                 << std::endl;
  }

// -----------------------------------------------------------------------------

  void State::toFieldSet(atlas::FieldSet & fset) const {
    Log::trace() << classname() << ":toFieldSet starting"
                 << std::endl;
    Log::debug() << classname() << ":toFieldSet vars = " << vars_
                 << std::endl;
    roms_state_to_fieldset_f90(toFortran(),
                               geom_->toFortran(),
                               vars_,
                               fset.get());
    Log::trace() << classname() << ":toFieldSet done"
                 << std::endl;
  }

// -----------------------------------------------------------------------------

  void State::fromFieldSet(const atlas::FieldSet & fset) {
    Log::trace() << classname() << ":fromFieldSet starting"
                 << std::endl;
    Log::debug() << classname() << ":fromFieldSet vars = " << vars_
                 << std::endl;
    roms_state_from_fieldset_f90(toFortran(),
                                 geom_->toFortran(),
                                 vars_,
                                 fset.get());
    Log::trace() << classname() << ":fromFieldSet done"
                 << std::endl;
  }

// -----------------------------------------------------------------------------

  const util::DateTime & State::validTime() const {return time_;}

// -----------------------------------------------------------------------------

  util::DateTime & State::validTime() {return time_;}

// -----------------------------------------------------------------------------

  std::shared_ptr<const Geometry> State::geometry() const {return geom_;}

// -----------------------------------------------------------------------------

}  // namespace romsjedi
