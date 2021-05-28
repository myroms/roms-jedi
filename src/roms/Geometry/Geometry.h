/*
 * (C) Copyright 2019-2020 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMS_GEOMETRY_GEOMETRY_H_
#define ROMS_GEOMETRY_GEOMETRY_H_

#include <ostream>
#include <string>
#include <vector>

#include "eckit/mpi/Comm.h"

#include "oops/util/ObjectCounter.h"
#include "oops/util/Printable.h"

#include "roms/Fortran.h"
#include "roms/Geometry/GeometryFortran.h"
#include "roms/GeometryIterator/GeometryIterator.h"
#include "roms/GeometryIterator/GeometryIteratorFortran.h"

// Forward declarations

namespace eckit {
  class Configuration;
}

namespace roms {
  class GeometryIterator;
}

// ----------------------------------------------------------------------------

namespace roms {

  // Geometry class

  class Geometry : public util::Printable,
                   private util::ObjectCounter<Geometry> {
   public:
    static const std::string classname() {return "roms::Geometry";}

    // constructors and destructor

    explicit Geometry(const eckit::Configuration &, const eckit::mpi::Comm &);
    Geometry(const Geometry &);
    ~Geometry();

    // accessors

    GeometryIterator begin() const;
    GeometryIterator end() const;
    std::vector<double> verticalCoord(std::string &) const;

    int& toFortran() {return keyGeom_;}
    const int& toFortran() const {return keyGeom_;}
    const eckit::mpi::Comm & getComm() const {return comm_;}

   private:
    Geometry & operator=(const Geometry &);
    void print(std::ostream &) const;
    int keyGeom_;
    const eckit::mpi::Comm & comm_;
  };
}  // namespace roms

#endif  // ROMS_GEOMETRY_GEOMETRY_H_
