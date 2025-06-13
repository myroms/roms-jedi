/*
 * (C) Copyright 2023-2025 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMSJEDI_MODELDATA_MODELDATA_H_
#define ROMSJEDI_MODELDATA_MODELDATA_H_

#pragma once

#include <string>
#include <vector>

#include "eckit/config/LocalConfiguration.h"
#include "oops/util/Printable.h"

namespace romsjedi {
  class Geometry;
}

// -----------------------------------------------------------------------------

namespace romsjedi {

  class ModelData : public util::Printable {
   public:
    static const std::string classname() {return "romsjedi::ModelData";}
    static const oops::Variables defaultVariables() {
      return oops::Variables(std::vector<std::string>(
                             {"sea_surface_height_above_geoid",
                              "eastward_sea_water_velocity",
                              "northward_sea_water_velocity",
                              "sea_water_potential_temperature",
                              "sea_water_salinity"}));
    }

    explicit ModelData(const Geometry &) {}
    ~ModelData() {}

    const eckit::LocalConfiguration modelData() const {
      return eckit::LocalConfiguration();}

   private:
    void print(std::ostream & os) const {}
  };

// -----------------------------------------------------------------------------

}  // namespace romsjedi

#endif  // ROMSJEDI_MODELDATA_MODELDATA_H_
