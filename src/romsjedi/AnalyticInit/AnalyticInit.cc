/*
 * (C) Copyright 2017-2023 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 *
 *!
 * \brief   Analytical state initialization at the observation locations
 *
 * \details Gets analytical values at the observation locations. It is used to
 *          test the **GeoVaLs** interpolation. The **fillGeoVaLs** function
 *          needs the same arguments as the default OOPS function for the
 *          replacement to work.
 *
 * \author  Hernan G. Arango (Rutgers University)
 * \date    July 2021
 */

#include "oops/util/Logger.h"

#include "romsjedi/AnalyticInit/AnalyticInit.h"
#include "romsjedi/AnalyticInit/AnalyticInitFortran.h"

namespace romsjedi {

  static oops::AnalyticInitMaker<ufo::ObsTraits, AnalyticInit>
         makerAnalytic_("ana_ocnfields");

// -----------------------------------------------------------------------------
/// Constructor.
// -----------------------------------------------------------------------------

  AnalyticInit::AnalyticInit(const Parameters_ & options)
    : options_(options) {}

// -----------------------------------------------------------------------------
/// Get analytical values at the observation locations
// -----------------------------------------------------------------------------

  void AnalyticInit::fillGeoVaLs(const ufo::SampledLocations & locs,
                                 ufo::GeoVaLs & geovals) const {
    oops::Log::trace() << "AnalyticInit::fillGeoVals starting" << std::endl;
    const int method_len = options_.method.value().length();
    const char* method_str = options_.method.value().c_str();
    roms_analytic_geovals_f90(geovals.toFortran(),
                              locs,
                              method_len, method_str,
                              options_.T0, options_.S0,
                              options_.U0, options_.V0);
    oops::Log::trace() << "AnalyticInit::fillGeoVals done" << std::endl;
  }

// -----------------------------------------------------------------------------

}  // namespace romsjedi
