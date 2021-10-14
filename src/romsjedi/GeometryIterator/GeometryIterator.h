/*
 * (C) Copyright 2019-2021 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 *!
 * \brief   **GeometryIterator** C++ Class for ROMS-JEDI interface
 *
 * \details It extract state fields values at specified application grid points.
 *
 * \author  Hernan G. Arango (Rutgers University)
 * \date    October 2021

 */

#ifndef ROMSJEDI_GEOMETRYITERATOR_GEOMETRYITERATOR_H_
#define ROMSJEDI_GEOMETRYITERATOR_GEOMETRYITERATOR_H_

#include <iterator>
#include <string>

#include "oops/util/ObjectCounter.h"
#include "oops/util/Printable.h"

#include "romsjedi/Fortran.h"

// Forward declarations

namespace eckit {
  namespace geometry {
    class Point2;
  }
}
namespace romsjedi {
  class Geometry;
}


namespace romsjedi {

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

}  // namespace romsjedi

#endif  // ROMSJEDI_GEOMETRYITERATOR_GEOMETRYITERATOR_H_
