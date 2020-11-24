/*
 * (C) Copyright 2019-2020 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */


#include "socaroms/GetValues/LinearGetValues.h"
#include "socaroms/State/State.h"
#include "socaroms/Geometry/Geometry.h"
#include "socaroms/Increment/Increment.h"

#include "eckit/config/Configuration.h"

#include "oops/base/Variables.h"
#include "oops/util/abor1_cpp.h"

#include "ufo/GeoVaLs.h"
#include "ufo/Locations.h"

namespace socaroms {

// ----------------------------------------------------------------------------

  LinearGetValues::LinearGetValues(const Geometry & geom,
                                   const ufo::Locations & locs)
    : geom_( new Geometry(geom)), locs_(locs) {
    util::abor1_cpp(
      "LinearGetValues::LinearGetValues() needs to be implemented.",
      __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  LinearGetValues::~LinearGetValues() {
    util::abor1_cpp(
      "LinearGetValues::~LinearGetValues() needs to be implemented.",
      __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  void LinearGetValues::fillGeoVaLsAD(Increment & inc,
                                      const util::DateTime & t1,
                                      const util::DateTime & t2,
                                      const ufo::GeoVaLs & geovals) const {
    util::abor1_cpp(
      "LinearGetValues::fillGeoVaLsAD() needs to be implemented.",
      __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  void LinearGetValues::fillGeoVaLsTL(const Increment & inc,
                                      const util::DateTime & t1,
                                      const util::DateTime & t2,
                                      ufo::GeoVaLs & geovals) const {
    util::abor1_cpp("LinearGetValues::fillGeoVaLsTL() needs to be implemented.",
                    __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  void LinearGetValues::setTrajectory(const State & state,
                                      const util::DateTime & t1,
                                      const util::DateTime & t2,
                                      ufo::GeoVaLs & geovals) {
    util::abor1_cpp("LinearGetValues::setTrajectory() needs to be implemented.",
                    __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  void LinearGetValues::print(std::ostream & os) const {
    os << "insert diagnostic information about LinearGetValues"
       << std::endl;
    util::abor1_cpp("LinearGetValues::print() needs to be implemented.",
                    __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

}  // namespace socaroms
