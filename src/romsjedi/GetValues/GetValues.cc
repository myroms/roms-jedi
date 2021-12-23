/*
 * (C) Copyright 2019-2021 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 *
 *!
 * \brief   Interpolates ROMS state at observation locations
 *
 * \details These routines horizontally interpolates nonlinear, increment,
 *          or derived state vector at the GeoVaLs locations:
 *          model ==> Observation.
 *
 * \author  Hernan G. Arango (Rutgers University)
 * \date    June 2021
 */

#include "eckit/config/LocalConfiguration.h"

#include "ioda/ObsSpace.h"

#include "oops/mpi/mpi.h"
#include "oops/util/DateTime.h"
#include "oops/util/Logger.h"

#include "romsjedi/Geometry/Geometry.h"
#include "romsjedi/GetValues/GetValues.h"
#include "romsjedi/GetValues/GetValuesFortran.h"
#include "romsjedi/State/State.h"

#include "ufo/GeoVaLs.h"
#include "ufo/Locations.h"

namespace romsjedi {

// -----------------------------------------------------------------------------
/// Constructor.
// -----------------------------------------------------------------------------

  GetValues::GetValues(const Geometry & geom,
                       const ufo::Locations & locs,
                       const eckit::Configuration & config)
    : locs_(locs), geom_(new Geometry(geom)) {
    oops::Log::trace() << "GetValues::GetValues starting" << std::endl;
    roms_getvalues_create_f90(keyGetValues_, geom.toFortran(), locs);
    oops::Log::trace() << "GetValues::GetValues done" << std::endl;
  }

// -----------------------------------------------------------------------------
/// Destructor.
// -----------------------------------------------------------------------------

  GetValues::~GetValues() {
    oops::Log::trace() << "GetValues::~GetValues starting" << std::endl;
    roms_getvalues_delete_f90(keyGetValues_);
    oops::Log::trace() << "GetValues::~GetValues done" << std::endl;
  }

// -----------------------------------------------------------------------------
/// Get state values at the observation locations.
// -----------------------------------------------------------------------------

  void GetValues::fillGeoVaLs(const State & state,
                              const util::DateTime & t1,
                              const util::DateTime & t2,
                              ufo::GeoVaLs & geovals) const {
    oops::Log::trace() << "GetValues::fillGeoVaLs starting" << std::endl;
    roms_getvalues_fill_geovals_f90(keyGetValues_,
                                    geom_->toFortran(),
                                    state.toFortran(),
                                    t1, t2, locs_,
                                    geovals.toFortran());
    oops::Log::trace() << "GetValues::fillGeoVaLs done" << geovals << std::endl;
  }

// -----------------------------------------------------------------------------
/// Report.
// -----------------------------------------------------------------------------

  void GetValues::print(std::ostream & os) const {
    os << "GetValues for roms-jedi" << std::endl;
  }

// -----------------------------------------------------------------------------

}  // namespace romsjedi
