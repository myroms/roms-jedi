/*
 * (C) Copyright 2019-2021 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 *
 *!
 * \brief   **GetValues**  C++ class for interpolating state at observation
 *          locations
 *
 * \details These C++ functions interpolates nonlinear, increment, or derived
 *          state vector at the **GeoVaLs** locations.
 *
 * \author  Hernan G. Arango (Rutgers University)
 * \date    June 2021
 */

#ifndef ROMSJEDI_GETVALUES_GETVALUES_H_
#define ROMSJEDI_GETVALUES_GETVALUES_H_

#include <memory>
#include <ostream>
#include <string>

#include "oops/util/DateTime.h"
#include "oops/util/ObjectCounter.h"
#include "oops/util/Printable.h"
#include "ufo/Locations.h"

#include "romsjedi/Fortran.h"
#include "romsjedi/AnalyticInit/AnalyticInit.h"

// Forward declarations

namespace oops {
  class Variables;
}

namespace romsjedi {
  class Geometry;
  class Model2GeoVaLs;
  class State;
}

namespace ufo {
  class GeoVaLs;
}

// -----------------------------------------------------------------------------

namespace romsjedi {

  // GetValues class: interpolate state to observation locations
  class GetValues : public util::Printable,
                    private util::ObjectCounter<GetValues> {
   public:
    static const std::string classname() {return "roms::GetValues";}

    // Constructors and Destructors.
    GetValues(const Geometry &,
              const ufo::Locations & locs,
              const eckit::Configuration & config);
    virtual ~GetValues();

    // Fills in GeoVaLs for all observations in the timeframe (t1, t2].
    void fillGeoVaLs(const State &,
                     const util::DateTime & t1,
                     const util::DateTime & t2,
                     ufo::GeoVaLs &) const;

    // Read interpolated GeoVaLs at observation location.
    void getValuesFromFile(const ufo::Locations &,
                           const oops::Variables &,
                           ufo::GeoVaLs &) const;

   private:
    void print(std::ostream &) const;
    F90getval keyGetValues_;
    ufo::Locations locs_;
    std::shared_ptr<const Geometry> geom_;
    std::unique_ptr<Model2GeoVaLs> model2geovals_;
  };
}  // namespace romsjedi

#endif  // ROMSJEDI_GETVALUES_GETVALUES_H_
