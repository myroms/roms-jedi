/*
 * (C) Copyright 2019-2022 UCAR
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
#include "oops/util/parameters/OptionalParameter.h"
#include "oops/util/parameters/Parameter.h"
#include "oops/util/parameters/Parameters.h"
#include "oops/util/parameters/RequiredParameter.h"

#include "romsjedi/Fortran.h"
#include "romsjedi/Geometry/GeometryFortran.h"
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

  /// \brief Parameter used to initialize ROMS Geometry object

  class GeometryParameters : public oops::Parameters {
    OOPS_CONCRETE_PARAMETERS(GeometryParameters, Parameters)

   public:
    oops::RequiredParameter<std::string> projectDir{
      "project_dir", "Project directory", this};
    oops::RequiredParameter<std::string> romsStdinp{
      "roms_stdinp", "ROMS standard input file", this};
    oops::RequiredParameter<std::string> fldsMetadata{
      "fields metadata", "ROMS-JEDI fields metadata file", this};
    oops::RequiredParameter<int> ng{
      "ng", "ROMS nested grid number", this};
    oops::OptionalParameter<int> iteratorDimension{
      "iterator dimension", "Dimension of geometry iteractor", this};
  };

  // Geometry class

  class Geometry : public util::Printable,
                   private util::ObjectCounter<Geometry> {
   public:
    typedef GeometryParameters Parameters_;

    static const std::string classname() {return "romsjedi::Geometry";}

    // constructors and destructor

    explicit Geometry(const GeometryParameters & parameters,
                      const eckit::mpi::Comm &);
    Geometry(const Geometry &);
    ~Geometry();

    // accessors

    GeometryIterator begin() const;
    GeometryIterator end() const;
    int IteratorDimension() const;

    std::vector<size_t> variableSizes(const oops::Variables & vars) const;
    std::vector<double> verticalCoord(std::string &) const;

    int& toFortran() {return keyGeom_;}
    const int& toFortran() const {return keyGeom_;}
    const eckit::mpi::Comm & getComm() const {return comm_;}

    atlas::FunctionSpace * atlasFunctionSpace() const {
           return atlasFunctionSpace_.get();}
    atlas::FunctionSpace * atlasFunctionSpaceIncludingHalo() const {
           return atlasFunctionSpaceIncludingHalo_.get();}
    atlas::FieldSet * atlasFieldSet() const {
           return atlasFieldSet_.get();}
    void latlon(std::vector<double> &,
                std::vector<double> &,
                const bool) const;

   private:
    Geometry & operator=(const Geometry &);
    void print(std::ostream &) const;
    int keyGeom_;
    const eckit::mpi::Comm & comm_;
    std::unique_ptr<atlas::functionspace::PointCloud>
                   atlasFunctionSpace_;
    std::unique_ptr<atlas::functionspace::PointCloud>
                   atlasFunctionSpaceIncludingHalo_;
    std::unique_ptr<atlas::FieldSet> atlasFieldSet_;
  };
}  // namespace romsjedi

// -----------------------------------------------------------------------------

#endif  // ROMSJEDI_GEOMETRY_GEOMETRY_H_
