/*
 * (C) Copyright 2019-2020 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#include <vector>

#include "roms/Geometry/Geometry.h"
#include "roms/Increment/Increment.h"

#include "oops/base/LocalIncrement.h"
#include "oops/util/abor1_cpp.h"

#include "ufo/GeoVaLs.h"
#include "ufo/Locations.h"

namespace roms {

// ----------------------------------------------------------------------------

  Increment::Increment(const Geometry & geom,
                       const oops::Variables & vars,
                       const util::DateTime & vt)
    : geom_(new Geometry(geom)), time_(vt), vars_(vars) {
    util::abor1_cpp("Increment::Increment() needs to be implemented.",
                    __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  Increment::Increment(const Geometry & geom, const Increment & other)
    : geom_(new Geometry(geom)), time_(other.time_), vars_(other.vars_) {
    util::abor1_cpp("Increment::Increment() needs to be implemented.",
                     __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  Increment::Increment(const Increment & other, const bool copy)
    : geom_(new Geometry(*other.geom_)), time_(other.time_),
      vars_(other.vars_) {
    util::abor1_cpp("Increment::Increment() needs to be implemented.",
                      __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  Increment::Increment(const Increment & other)
    : geom_(new Geometry(*other.geom_)), time_(other.time_),
      vars_(other.vars_) {
    util::abor1_cpp("Increment::Increment() needs to be implemented.",
                      __FILE__, __LINE__);
  }
// ----------------------------------------------------------------------------

  Increment::~Increment() {
    util::abor1_cpp("Increment::~Increment() needs to be implemented.",
                     __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  Increment & Increment::operator =(const Increment &) {
    util::abor1_cpp("Increment::operator= needs to be implemented.",
                    __FILE__, __LINE__);
    return *this;
  }

// ----------------------------------------------------------------------------

  Increment & Increment::operator -=(const Increment &) {
    util::abor1_cpp("Increment::operator-= needs to be implemented.",
                    __FILE__, __LINE__);
    return *this;
  }

// ----------------------------------------------------------------------------

  Increment & Increment::operator +=(const Increment &) {
    util::abor1_cpp("Increment::operator+= needs to be implemented.",
                    __FILE__, __LINE__);
    return *this;
  }

// ----------------------------------------------------------------------------

  Increment & Increment::operator *=(const double &) {
    util::abor1_cpp("Increment::operator*= needs to be implemented.",
                    __FILE__, __LINE__);
    return *this;
  }

// ----------------------------------------------------------------------------

  void Increment::accumul(const double & zz, const State & xx) {
    util::abor1_cpp("Increment::accuml() needs to be implemented.",
                     __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  void Increment::axpy(const double &, const Increment &, const bool check) {
    util::abor1_cpp("Increment::axpy() needs to be implemented.",
                    __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  void Increment::diff(const State & x1, const State & x2) {
    util::abor1_cpp("Increment::diff() needs to be implemented.",
                     __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  double Increment::dot_product_with(const Increment &) const {
    util::abor1_cpp("Increment::dot_product_with() needs to be implemented.",
                    __FILE__, __LINE__);
    return 0.0;
  }

// ----------------------------------------------------------------------------

  double Increment::norm() const {
    util::abor1_cpp("Increment::norm() needs to be implemented.",
                     __FILE__, __LINE__);
    return 0.0;
  }

// ----------------------------------------------------------------------------

  void Increment::random() {
    util::abor1_cpp("Increment::random() needs to be implemented.",
                    __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  void Increment::schur_product_with(const Increment & ) {
    util::abor1_cpp("Increment::schur_product_with() needs to be implemented.",
                    __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  void Increment::zero() {
    util::abor1_cpp("Increment::zero() needs to be implemented.",
                    __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  void Increment::zero(const util::DateTime & time) {
    zero();
    time_ = time;
  }

// ----------------------------------------------------------------------------

  void Increment::ones() {
    util::abor1_cpp("Increment::ones() needs to be implemented.",
                    __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  void Increment::dirac(const eckit::Configuration & conf) {
    util::abor1_cpp("Increment::dirac() needs to be implemented.",
                    __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  oops::LocalIncrement Increment::getLocal(const GeometryIterator & iter) const
  {
    util::abor1_cpp("Increment::getLocal() needs to be implemented.",
                    __FILE__, __LINE__);
    std::vector<double> vals;
    std::vector<int> varlens;
    return oops::LocalIncrement(vars_, vals, varlens);
  }

// ----------------------------------------------------------------------------

  void Increment::setLocal(const oops::LocalIncrement & values,
                           const GeometryIterator & iter) {
    util::abor1_cpp("Increment::setLocal() needs to be implemented.",
                    __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  size_t Increment::serialSize() const {
    util::abor1_cpp("Increment::serialSize() needs to be implemented.",
                     __FILE__, __LINE__);
    return 0;
  }

// ----------------------------------------------------------------------------

  void Increment::serialize(std::vector<double> & vec) const {
    util::abor1_cpp("Increment::serialize() needs to be implemented.",
                     __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  void Increment::deserialize(const std::vector<double> & vec, size_t & s) {
    util::abor1_cpp("Increment::deserialize() needs to be implemented.",
                     __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  void Increment::print(std::ostream & os) const {
    os << "Increment: "
       << "(TODO, print diagnostic info about the increment here)"
       << std::endl;
    util::abor1_cpp("Increment::print() needs to be implemented.",
                    __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  void Increment::read(const eckit::Configuration & conf) {
    util::abor1_cpp("Increment::read() needs to be implemented.",
                    __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  void Increment::write(const eckit::Configuration & conf) const {
    util::abor1_cpp("Increment::write() needs to be implemented.",
                    __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------
}  // namespace roms
