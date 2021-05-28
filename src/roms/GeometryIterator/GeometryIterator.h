/*
 * (C) Copyright 2019-2021 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMS_GEOMETRYITERATOR_GEOMETRYITERATOR_H_
#define ROMS_GEOMETRYITERATOR_GEOMETRYITERATOR_H_

#include <iterator>
#include <string>

#include "roms/Fortran.h"

#include "oops/util/ObjectCounter.h"
#include "oops/util/Printable.h"

// Forward declarations

namespace eckit {
  namespace geometry {
    class Point2;
  }
}
namespace roms {
  class Geometry;
}


namespace roms {

// -----------------------------------------------------------------------------

  class GeometryIterator: public std::iterator<std::forward_iterator_tag,
                                               eckit::geometry::Point2>,
                          public util::Printable,
                          private util::ObjectCounter<GeometryIterator> {
   public:
    static const std::string classname() {return "roms::GeometryIterator";}

    // constructor / destructor

    GeometryIterator(const GeometryIterator &);
    explicit GeometryIterator(const Geometry & geom,
                              const int & iindex = 1, const int & jindex = 1);
    ~GeometryIterator();

    // other operators

    bool operator==(const GeometryIterator &) const;
    bool operator!=(const GeometryIterator &) const;
    eckit::geometry::Point2 operator*() const;
    GeometryIterator& operator++();

    F90iter & toFortran() {return keyIter_;}
    const F90iter & toFortran() const {return keyIter_;}

   private:
    void print(std::ostream &) const;
    F90iter keyIter_;
  };

}  // namespace roms

#endif  // ROMS_GEOMETRYITERATOR_GEOMETRYITERATOR_H_
