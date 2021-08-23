/*
 * (C) Copyright 2019-2020 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMSJEDI_GEOMETRY_GEOMETRY_H_
#define ROMSJEDI_GEOMETRY_GEOMETRY_H_

#include <fstream>
#include <memory>
#include <ostream>
#include <string>
#include <vector>

#include "eckit/mpi/Comm.h"

#include "oops/util/ObjectCounter.h"
#include "oops/util/Printable.h"

#include "romsjedi/Fortran.h"
#include "romsjedi/Geometry/GeometryFortran.h"
#include "romsjedi/GeometryIterator/GeometryIterator.h"
#include "romsjedi/GeometryIterator/GeometryIteratorFortran.h"

// Forward declarations

namespace atlas {
  class FieldSet;
  class FunctionSpace;
  namespace functionspace {
    class PointCloud;
  }
}

namespace eckit {
  class Configuration;
}

namespace oops {
  class Variables;
}

namespace romsjedi {
  class GeometryIterator;
}

// ----------------------------------------------------------------------------

namespace romsjedi {

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
    std::vector<size_t> variableSizes(const oops::Variables & vars) const;
    std::vector<double> verticalCoord(std::string &) const;

    int& toFortran() {return keyGeom_;}
    const int& toFortran() const {return keyGeom_;}
    const eckit::mpi::Comm & getComm() const {return comm_;}

    atlas::FunctionSpace * atlasFunctionSpace() const;
    atlas::FieldSet * atlasFieldSet() const;

   private:
    Geometry & operator=(const Geometry &);
    void print(std::ostream &) const;
    int keyGeom_;
    const eckit::mpi::Comm & comm_;
    std::unique_ptr<atlas::functionspace::PointCloud> atlasFunctionSpace_;
    std::unique_ptr<atlas::FieldSet> atlasFieldSet_;
  };
}  // namespace romsjedi

#endif  // ROMSJEDI_GEOMETRY_GEOMETRY_H_
