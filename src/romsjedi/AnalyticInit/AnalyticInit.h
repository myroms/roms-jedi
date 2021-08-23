/*
 * (C) Copyright 2017-2021 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 *
 *!
 * \brief   Fills **GeoVaLs** state variables with analytical expressions
 *
 * \details Gets analytical values at the observation locations. It is used to
 *          test the **GeoVaLs** interpolation. The **fillGeoVaLs** function
 *          needs the same arguments as the default OOPS function for the
 *          replacement to work.
 *
 * \author  Hernan G. Arango (Rutgers University)
 * \date    July 2021
 */

#ifndef ROMSJEDI_ANALYTICINIT_ANALYTICINIT_H_
#define ROMSJEDI_ANALYTICINIT_ANALYTICINIT_H_

#include "eckit/config/LocalConfiguration.h"
#include "romsjedi/Geometry/Geometry.h"

namespace ufo {
  class GeoVaLs;
  class Locations;
}

namespace romsjedi {

// -----------------------------------------------------------------------------
/// Fill GeoVaLs with analytic expressions.
// -----------------------------------------------------------------------------

  class AnalyticInit {
   public:
    explicit AnalyticInit(const eckit::Configuration &);
    void fillGeoVaLs(const ufo::Locations &,
                     ufo::GeoVaLs &) const;

   private:
    const eckit::LocalConfiguration config_;
  };

// -----------------------------------------------------------------------------

}  // namespace romsjedi

#endif  // ROMSJEDI_ANALYTICINIT_ANALYTICINIT_H_
