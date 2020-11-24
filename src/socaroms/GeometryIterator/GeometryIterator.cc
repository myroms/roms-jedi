/*
 * (C) Copyright 2019-2020 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */


#include "socaroms/Geometry/Geometry.h"
#include "socaroms/GeometryIterator/GeometryIterator.h"

#include "eckit/config/Configuration.h"
#include "eckit/geometry/Point2.h"

#include "oops/util/abor1_cpp.h"

namespace socaroms {

// ----------------------------------------------------------------------------

  GeometryIterator::GeometryIterator(const Geometry& geom,
                                     const int & iindex, const int & jindex) {
    util::abor1_cpp(
      "GeometryIterator::GeometryIterator() needs to be implemented.",
      __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  GeometryIterator::GeometryIterator(const GeometryIterator& iter) {
    util::abor1_cpp(
      "GeometryIterator::GeometryIterator() needs to be implemented.",
      __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  GeometryIterator::~GeometryIterator() {
    util::abor1_cpp(
      "GeometryIterator::~GeometryIterator() needs to be implemented.",
      __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  bool GeometryIterator::operator==(const GeometryIterator &) const {
    util::abor1_cpp(
      "GeometryIterator::operator==() needs to be implemented.",
      __FILE__, __LINE__);
    return false;
  }

// ----------------------------------------------------------------------------

  bool GeometryIterator::operator!=(const GeometryIterator &) const {
    util::abor1_cpp(
      "GeometryIterator::operator!=() needs to be implemented.",
      __FILE__, __LINE__);
    return false;
  }

// ----------------------------------------------------------------------------

  GeometryIterator& GeometryIterator::operator++() {
    util::abor1_cpp(
      "GeometryIterator::operator++() needs to be implemented.",
      __FILE__, __LINE__);
    return *this;
  }

// ----------------------------------------------------------------------------

  eckit::geometry::Point2 GeometryIterator::operator*() const {
    util::abor1_cpp("GeometryIterator::operator*() needs to be implemented.",
                     __FILE__, __LINE__);
    return eckit::geometry::Point2(0.0, 0.0);
  }

// ----------------------------------------------------------------------------

  void GeometryIterator::print(std::ostream  & os) const {
    util::abor1_cpp("GeometryIterator::print() needs to be implemented.",
                    __FILE__, __LINE__);
    os << "(TODO, print diagnostic info about the GeometryIterator here)"
       << std::endl;
  }

// ----------------------------------------------------------------------------

}  // namespace socaroms
