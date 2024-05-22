/*
 * (C) Copyright 2019-2024 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
*!
 * \brief   **Geometry** C++ class to set up ROMS-JEDI application
 *
 * \details These C++ functions creates/clones/destroys the Geometry object
 *          for a particular ROMS-JEDI application.
 *
 * \author  Hernan G. Arango (Rutgers University)
 * \date    April 2021
 */

#ifndef ROMSJEDI_GEOMETRY_GEOMETRY_H_
#define ROMSJEDI_GEOMETRY_GEOMETRY_H_

#include <fstream>
#include <memory>
#include <ostream>
#include <string>
#include <vector>

#include "atlas/field.h"
#include "atlas/functionspace.h"
#include "eckit/config/Configuration.h"
#include "eckit/config/LocalConfiguration.h"
#include "eckit/mpi/Comm.h"
#include "oops/util/ObjectCounter.h"
#include "oops/util/Printable.h"

#include "romsjedi/Fortran.h"
#include "romsjedi/Geometry/GeometryFortran.h"
#include "romsjedi/Geometry/GeometryParameters.h"
#include "romsjedi/GeometryIterator/GeometryIterator.h"
#include "romsjedi/GeometryIterator/GeometryIteratorFortran.h"

// Forward declarations

namespace oops {
  class Variables;
}

namespace romsjedi {
  class GeometryIterator;
}

// -----------------------------------------------------------------------------

namespace romsjedi {

  // Geometry class

  class Geometry : public util::Printable,
                   private util::ObjectCounter<Geometry> {
   public:
    static const std::string classname() {return "romsjedi::Geometry";}

    // constructors and destructor

    Geometry(const GeometryParameters &,
             const eckit::mpi::Comm &);
    Geometry(const eckit::Configuration &,
             const eckit::mpi::Comm &);
    Geometry(const Geometry &);
    ~Geometry();

    // Negative depths; vertical levels are bottom (k=1) to top (k=N)

    bool levelsAreTopDown() const {return false;}

    // Accessors

    GeometryIterator begin() const;
    GeometryIterator end() const;
    int IteratorDimension() const;

    std::vector<size_t> variableSizes(const oops::Variables & vars) const;
    std::vector<double> verticalCoord(std::string &) const;

    int& toFortran() {return keyGeom_;}
    const int& toFortran() const {return keyGeom_;}
    const eckit::mpi::Comm & getComm() const {return comm_;}

    const atlas::FunctionSpace & functionSpace() const {return functionSpace_;}
    // atlas::FunctionSpace & functionSpace() {return functionSpace_;}

    const atlas::FieldSet & fields() const {return fields_;}
    // atlas::FieldSet & fields() {return fields_;}

   private:
    Geometry & operator=(const Geometry &);
    void print(std::ostream &) const;

    int keyGeom_;
    const eckit::mpi::Comm & comm_;

    atlas::functionspace::NodeColumns functionSpace_;
    atlas::FieldSet fields_;
  };
}  // namespace romsjedi

// -----------------------------------------------------------------------------

#endif  // ROMSJEDI_GEOMETRY_GEOMETRY_H_
