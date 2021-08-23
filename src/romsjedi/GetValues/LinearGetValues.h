/*
 * (C) Copyright 2019-2021 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 *
 * Hernan G. Arango, Rutgers University, Jun 2021
 */

#ifndef ROMSJEDI_GETVALUES_LINEARGETVALUES_H_
#define ROMSJEDI_GETVALUES_LINEARGETVALUES_H_

#include <memory>
#include <ostream>
#include <string>

#include "oops/util/ObjectCounter.h"
#include "oops/util/Printable.h"

#include "romsjedi/Fortran.h"

#include "ufo/Locations.h"

// Forward declarations

namespace romsjedi {
  class Geometry;
  class Increment;
  class State;
  class Model2GeoVaLs;
  class LinearModel2GeoVaLs;
}

namespace ufo {
  class GeoVaLs;
  class Locations;
}

// -----------------------------------------------------------------------------

namespace romsjedi {

  // GetValues class: interpolate state to observation locations
  class LinearGetValues : public util::Printable,
                          private util::ObjectCounter<LinearGetValues> {
   public:
    static const std::string classname() {return "roms::LinearGetValues";}

    // Constructor, Destructor
    LinearGetValues(const Geometry &, const ufo::Locations &,
                    const eckit::Configuration &);
    virtual ~LinearGetValues();

    // Trajectory for the linearized interpolation
    void setTrajectory(const State & state,
                      const util::DateTime & t1,
                      const util::DateTime & t2,
                      ufo::GeoVaLs & geovals); // NOLINT

    // Forward and backward interpolation
    void fillGeoVaLsTL(const Increment & inc,
                       const util::DateTime & t1,
                       const util::DateTime & t2,
                       ufo::GeoVaLs & geovals) const; // NOLINT

    void fillGeoVaLsAD(Increment & inc,   // NOLINT
                       const util::DateTime & t1,
                       const util::DateTime & t2,
                       const ufo::GeoVaLs & geovals) const;

   private:
    void print(std::ostream &) const;
    F90getval keyLinearGetValues_;
    ufo::Locations locs_;
    std::shared_ptr<const Geometry> geom_;
    std::unique_ptr<Model2GeoVaLs> model2geovals_;
    std::unique_ptr<LinearModel2GeoVaLs> linearmodel2geovals_;
  };
}  // namespace romsjedi

#endif  // ROMSJEDI_GETVALUES_LINEARGETVALUES_H_
