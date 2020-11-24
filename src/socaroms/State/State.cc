/*
 * (C) Copyright 2019-2020 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#include "socaroms/Geometry/Geometry.h"
#include "socaroms/State/State.h"

#include "eckit/config/Configuration.h"

#include "oops/base/Variables.h"
#include "oops/util/abor1_cpp.h"

#include "ufo/GeoVaLs.h"
#include "ufo/Locations.h"

namespace socaroms {

// ----------------------------------------------------------------------------

  State::State(const Geometry & geom, const eckit::Configuration & conf)
    : geom_(new Geometry(geom)), time_(conf.getString("date")),
      vars_(conf, "state variables") {
    util::abor1_cpp("State::State() needs to be implemented.",
                     __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  State::State(const Geometry & geom, const oops::Variables & vars,
               const util::DateTime & time)
    : geom_(new Geometry(geom)), time_(time), vars_(vars) {
    util::abor1_cpp("State::State() needs to be implemented.",
                    __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  State::State(const Geometry & geom, const State & other)
    : geom_(new Geometry(geom)), time_(other.time_), vars_(other.vars_) {
    // Change state resolution
    util::abor1_cpp("State::State() needs to be implemented.",
                    __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  State::State(const State & other)
    : geom_(new Geometry(*other.geom_)), time_(other.time_),
      vars_(other.vars_) {
    util::abor1_cpp("State::State() needs to be implemented.",
                     __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  State::~State() {
    util::abor1_cpp("State::~State() needs to be implemented.",
                    __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  State & State::operator+=(const Increment & dx)
  {
    util::abor1_cpp("State::operator+=(Increment) needs to be implemented.",
                    __FILE__, __LINE__);
    return *this;
  }

// ----------------------------------------------------------------------------

  void State::accumul(const double &, const State &) {
    util::abor1_cpp("State::accumul() needs to be implemented.",
                     __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  double State::norm() const {
    util::abor1_cpp("State::norm() needs to be implemented.",
                     __FILE__, __LINE__);
    return 0.0;
  }

// ----------------------------------------------------------------------------

  void State::zero() {
    util::abor1_cpp("State::zero() needs to be implemented.",
                    __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  void State::read(const eckit::Configuration & conf) {
     util::abor1_cpp("State::read() needs to be implemented.",
                     __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  void State::write(const eckit::Configuration & conf) const {
    util::abor1_cpp("State::write() needs to be implemented.",
                     __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  size_t State::serialSize() const {
    util::abor1_cpp("State::serialSize() needs to be implemented.",
                     __FILE__, __LINE__);
    return 0;
  }

// ----------------------------------------------------------------------------

  void State::serialize(std::vector<double> & vec) const {
    util::abor1_cpp("State::serialize() needs to be implemented.",
                     __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  void State::deserialize(const std::vector<double> & vec, size_t & s) {
    util::abor1_cpp("State::deserialize() needs to be implemented.",
                     __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  std::shared_ptr<const Geometry> State::geometry() const {return geom_;}

// ----------------------------------------------------------------------------

  void State::print(std::ostream & os) const {
    os << "insert diagnostic information about state here "
       << "(min/max/mean for each state var?)"
       << std::endl;

    util::abor1_cpp("State::print() needs to be implemented.",
                    __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

}  // namespace socaroms
