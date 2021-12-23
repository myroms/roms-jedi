/*
 * (C) Copyright 2019-2021 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 *
 *!
 * \brief   **GeometryIterator** Class C++ ROMS-JEDI interface
 *
 * \details It implements the **GeometryIterator** object to extract state
 *          fields values at specified grid points.
 *
 * \author  Hernan G. Arango (Rutgers University)
 * \date    October 2021
 */

#include "eckit/config/Configuration.h"
#include "eckit/geometry/Point3.h"
#include "oops/util/Logger.h"

#include "romsjedi/Geometry/Geometry.h"
#include "romsjedi/GeometryIterator/GeometryIterator.h"
#include "romsjedi/GeometryIterator/GeometryIteratorFortran.h"

// -----------------------------------------------------------------------------

namespace romsjedi {

// -----------------------------------------------------------------------------

  GeometryIterator::GeometryIterator(const GeometryIterator& iter) {
    roms_geomIterator_clone_f90(keyIter_,
                                iter.toFortran());
  }

// -----------------------------------------------------------------------------

  GeometryIterator::GeometryIterator(const Geometry& geom,
                                     const int & Iindex,
                                     const int & Jindex,
                                     const int & Kindex) {
    roms_geomIterator_setup_f90(keyIter_,
                                geom.toFortran(),
                                Iindex, Jindex, Kindex);
  }

// -----------------------------------------------------------------------------

  GeometryIterator::~GeometryIterator() {
    roms_geomIterator_delete_f90(keyIter_);
  }

// -----------------------------------------------------------------------------

  bool GeometryIterator::operator==(const GeometryIterator & other) const {
    int equals = 0;
    roms_geomIterator_equals_f90(keyIter_,
                                 other.toFortran(),
                                 equals);
    return (equals == 1);
  }

// -----------------------------------------------------------------------------

  bool GeometryIterator::operator!=(const GeometryIterator & other) const {
    int equals = 0;
    roms_geomIterator_equals_f90(keyIter_,
                                 other.toFortran(),
                                 equals);
    return (equals == 0);
  }

// -----------------------------------------------------------------------------

  eckit::geometry::Point3 GeometryIterator::operator*() const {
    double lat, lon, depth;
    roms_geomIterator_current_f90(keyIter_,
                                  lon, lat, depth);
    return eckit::geometry::Point3(lon, lat, depth);
  }

// -----------------------------------------------------------------------------

GeometryIterator& GeometryIterator::operator++() {
  roms_geomIterator_next_f90(keyIter_);
  return *this;
}

// -----------------------------------------------------------------------------

  int GeometryIterator::iteratorDimension() const {
    int dimension;
    roms_geomIterator_dimension_f90(keyIter_,
                                    dimension);
    return dimension;
  }


// -----------------------------------------------------------------------------

  void GeometryIterator::print(std::ostream & os) const {
    double lat, lon, depth;
    roms_geomIterator_current_f90(keyIter_,
                                  lon, lat, depth);
    os << "GeometryIterator, lat/lon/depth: " << lat << " / " << lon
                                              << " / " << depth  << std::endl;
  }

// -----------------------------------------------------------------------------

}  // namespace romsjedi
