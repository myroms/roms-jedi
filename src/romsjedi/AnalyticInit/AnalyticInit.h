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

#include <string>

#include "oops/interface/AnalyticInitBase.h"
#include "oops/util/parameters/RequiredParameter.h"

#include "ufo/ObsTraits.h"

namespace ufo {
  class GeoVaLs;
  class Locations;
}

namespace romsjedi {

  class AnalyticInitParameters : public oops::AnalyticInitParametersBase {
    OOPS_CONCRETE_PARAMETERS(AnalyticInitParameters,
                             AnalyticInitParametersBase)

   public:
    oops::RequiredParameter<double> T0{
      "T0",
      "Background temperature (C) scale factor",
      this};
    oops::RequiredParameter<double> S0{
      "S0",
      "Background salinity scale factor",
      this};
    oops::RequiredParameter<double> U0{
      "U0",
      "Background zonal velocity (m/s) scale factor",
      this};
    oops::RequiredParameter<double> V0{
      "V0",
      "Background meridional velocity (m/s) scale factor",
      this};
  };

// -----------------------------------------------------------------------------
/// Fill GeoVaLs with analytic expressions.
// -----------------------------------------------------------------------------

  class AnalyticInit :
        public oops::interface::AnalyticInitBase<ufo::ObsTraits> {
   public:
    typedef AnalyticInitParameters Parameters_;

    explicit AnalyticInit(const Parameters_ &);
    void fillGeoVaLs(const ufo::Locations &,
                     ufo::GeoVaLs &) const override;

   private:
    const Parameters_ options_;
  };

// -----------------------------------------------------------------------------

}  // namespace romsjedi

#endif  // ROMSJEDI_ANALYTICINIT_ANALYTICINIT_H_
