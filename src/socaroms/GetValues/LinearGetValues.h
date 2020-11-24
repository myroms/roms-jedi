/*
 * (C) Copyright 2019-2020 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef SOCAROMS_GETVALUES_LINEARGETVALUES_H_
#define SOCAROMS_GETVALUES_LINEARGETVALUES_H_

#include <memory>
#include <ostream>
#include <string>

#include "oops/util/ObjectCounter.h"
#include "oops/util/Printable.h"

#include "ufo/Locations.h"

// forward declarations

namespace ufo {
  class GeoVaLs;
  class Locations;
}
namespace socaroms {
  class Geometry;
  class Increment;
  class State;
}

// ----------------------------------------------------------------------------

namespace socaroms {

  // GetValues class: interpolate state to observation locations
  class LinearGetValues : public util::Printable,
                    private util::ObjectCounter<LinearGetValues> {
   public:
    static const std::string classname() {return "socaroms::LinearGetValues";}

    // constructors, destructors
    LinearGetValues(const Geometry &, const ufo::Locations &);
    virtual ~LinearGetValues();

    // Forward and backward interpolation
    void fillGeoVaLsAD(Increment & inc,   // NOLINT
                       const util::DateTime & t1,
                       const util::DateTime & t2,
                       const ufo::GeoVaLs & geovals) const;
    void fillGeoVaLsTL(const Increment & inc,
                       const util::DateTime & t1,
                       const util::DateTime & t2,
                       ufo::GeoVaLs & geovals) const; // NOLINT

    // Trajectory for the linearized interpolation
    void setTrajectory(const State & state,
                      const util::DateTime & t1,
                      const util::DateTime & t2,
                      ufo::GeoVaLs & geovals); // NOLINT

   private:
    void print(std::ostream &) const;

    std::shared_ptr<const Geometry> geom_;
    ufo::Locations locs_;
  };
}  // namespace socaroms

#endif  // SOCAROMS_GETVALUES_LINEARGETVALUES_H_
