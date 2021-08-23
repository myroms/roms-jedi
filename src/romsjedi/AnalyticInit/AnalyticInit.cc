/*
 * (C) Copyright 2017-2021 UCAR
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
#include "romsjedi/Geometry/Geometry.h"

#include "ufo/GeoVaLs.h"
#include "ufo/Locations.h"

namespace romsjedi {

// -----------------------------------------------------------------------------
/// Constructor.
// -----------------------------------------------------------------------------

  AnalyticInit::AnalyticInit(const eckit::Configuration & config)
    : config_(config) {}

// -----------------------------------------------------------------------------
/// Get analytical values at the observation locations
// -----------------------------------------------------------------------------

  void AnalyticInit::fillGeoVaLs(const ufo::Locations & locs,
                                 ufo::GeoVaLs & geovals) const {
    oops::Log::trace() << "AnalyticInit::analitic_init starting" << std::endl;
    if (config_.has("analytic_init")) {
      roms_analytic_init_f90(geovals.toFortran(),
                             locs,
                             config_);
    }
    oops::Log::trace() << "AnalyticInit::analytic_init done" << std::endl;
  }

// -----------------------------------------------------------------------------

}  // namespace romsjedi
