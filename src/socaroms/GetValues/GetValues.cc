/*
 * (C) Copyright 2019-2020 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#include "socaroms/Geometry/Geometry.h"
#include "socaroms/GetValues/GetValues.h"
#include "socaroms/State/State.h"

#include "eckit/config/Configuration.h"

#include "oops/base/Variables.h"
#include "oops/util/abor1_cpp.h"

#include "ufo/GeoVaLs.h"
#include "ufo/Locations.h"

namespace socaroms {

// ----------------------------------------------------------------------------

  GetValues::GetValues(const Geometry & geom,
                       const ufo::Locations & locs)
    : geom_(new Geometry(geom)), locs_(locs) {
    util::abor1_cpp("GetValues::GetValues() needs to be implemented.",
                    __FILE__, __LINE__);
  }

// -----------------------------------------------------------------------------

  GetValues::~GetValues() {
    util::abor1_cpp("GetValues::~GetValues() needs to be implemented.",
                     __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  void GetValues::fillGeoVaLs(const State & state,
                              const util::DateTime & t1,
                              const util::DateTime & t2,
                              ufo::GeoVaLs & geovals) const {
    util::abor1_cpp("GetValues::fillGeoVaLs() needs to be implemented.",
                     __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  void GetValues::print(std::ostream & os) const {
    os << "insert diagnostic information about getvalues"
      << std::endl;
    util::abor1_cpp("GetValues::print() needs to be implemented.",
                     __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

}  // namespace socaroms
