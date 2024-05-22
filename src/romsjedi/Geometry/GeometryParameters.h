/*
 * (C) Copyright 2024 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
*!
 * \brief   **Geometry** C++ class to set up ROMS-JEDI application
 *
 * \details Sets Parameters for the Geometry object
 *
 * \author  Hernan G. Arango (Rutgers University)
 * \date    May 2024
 */

#ifndef ROMSJEDI_GEOMETRY_GEOMETRYPARAMETERS_H_
#define ROMSJEDI_GEOMETRY_GEOMETRYPARAMETERS_H_

#include <string>

#include "oops/util/parameters/OptionalParameter.h"
#include "oops/util/parameters/Parameter.h"
#include "oops/util/parameters/Parameters.h"
#include "oops/util/parameters/RequiredParameter.h"

namespace romsjedi {

// -----------------------------------------------------------------------------

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
}  // namespace romsjedi

// -----------------------------------------------------------------------------

#endif  // ROMSJEDI_GEOMETRY_GEOMETRYPARAMETERS_H_
