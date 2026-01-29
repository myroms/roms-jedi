/*
 * (C) Copyright 2017-2025 UCAR
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

#include "eckit/config/LocalConfiguration.h"
#include "oops/util/Logger.h"

#include "romsjedi/AnalyticInit/AnalyticInit.h"
#include "romsjedi/AnalyticInit/AnalyticInitFortran.h"

namespace romsjedi {

  static ufo::AnalyticInitMaker<AnalyticInit>
         makerAnalytic_("ana_ocnfields");

// -----------------------------------------------------------------------------
/// Constructor.
// -----------------------------------------------------------------------------

  AnalyticInit::AnalyticInit(const eckit::Configuration & config)
  : config_(config) {}

// -----------------------------------------------------------------------------
/// Get analytical values at the observation locations
// -----------------------------------------------------------------------------

  void AnalyticInit::fillGeoVaLs(const ufo::SampledLocations & locs,
                                 ufo::GeoVaLs & geovals) const {
    oops::Log::trace() << "AnalyticInit::fillGeoVals starting" << std::endl;

    const int method_len = config_.getString("method").length();
    const char* method_str = config_.getString("method").c_str();
    const double T0 = config_.getDouble("T0");
    const double S0 = config_.getDouble("S0");
    const double U0 = config_.getDouble("U0");
    const double V0 = config_.getDouble("V0");

    roms_analytic_geovals_f90(geovals.toFortran(),
                              locs,
                              method_len, method_str,
                              T0, S0, U0, V0);
    oops::Log::trace() << "AnalyticInit::fillGeoVals done" << std::endl;
  }

// -----------------------------------------------------------------------------

}  // namespace romsjedi
