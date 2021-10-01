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

  void AnalyticInit::fillGeoVaLs(const ufo::Locations & locs,
                                 ufo::GeoVaLs & geovals) const {
    oops::Log::trace() << "AnalyticInit::analitic_init starting" << std::endl;
    roms_analytic_init_f90(geovals.toFortran(),
                           locs,
                           options_.T0, options_.S0, options_.U0, options_.V0);
    oops::Log::trace() << "AnalyticInit::analytic_init done" << std::endl;
  }

// -----------------------------------------------------------------------------

}  // namespace romsjedi
