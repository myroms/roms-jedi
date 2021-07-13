/*
 * (C) Copyright 2019-2021 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 *
 *!
 * \brief Interpolates linearized state at observation locations
 *
 * \details These routines horizontally interpolates tangent linear state vector
 *          at the GeoVaLs locations: model ==> Observation. Similarly, they
 *          performs the adjoint of the horizontal interpolation:
 *          Observations ==> model.
 *
 * \autor Hernan G. Arango (Rutgers University)
 */

#include "roms/Geometry/Geometry.h"
#include "roms/GetValues/GetValuesFortran.h"
#include "roms/GetValues/LinearGetValues.h"
#include "roms/Increment/Increment.h"
#include "roms/State/State.h"
#include "roms/VariableChanges/Model2GeoVaLs/Model2GeoVaLs.h"
#include "roms/VariableChanges/Model2GeoVaLs/LinearModel2GeoVaLs.h"

#include "oops/util/DateTime.h"
#include "oops/util/Logger.h"

#include "ufo/GeoVaLs.h"
#include "ufo/Locations.h"

namespace roms {

// -----------------------------------------------------------------------------
//  Constructor
// -----------------------------------------------------------------------------

  LinearGetValues::LinearGetValues(const Geometry & geom,
                                   const ufo::Locations & locs,
                                   const eckit::Configuration &config)
    : locs_(locs), geom_(new Geometry(geom)),
    model2geovals_(new Model2GeoVaLs(geom, config)) {
    oops::Log::trace() << "LinearGetValues::LinearGetValues starting"
                       << std::endl;
    roms_getvalues_create_f90(keyLinearGetValues_,
                              geom.toFortran(),
                              locs);
    oops::Log::trace() << "LinearGetValues::LinearGetValues done"
                       << std::endl;
  }

// -----------------------------------------------------------------------------
/// Destructor
// -----------------------------------------------------------------------------

  LinearGetValues::~LinearGetValues() {
    oops::Log::trace() << "LinearGetValues::~LinearGetValues starting"
                       << std::endl;
    roms_getvalues_delete_f90(keyLinearGetValues_);
    oops::Log::trace() << "LinearGetValues::~LinearGetValues done"
                       << std::endl;
  }

// -----------------------------------------------------------------------------
/// Interpolate state to observation locations
// -----------------------------------------------------------------------------

  void LinearGetValues::setTrajectory(const State & state,
                                      const util::DateTime & t1,
                                      const util::DateTime & t2,
                                      ufo::GeoVaLs & geovals) {
    oops::Log::trace() << "LinearGetValues::setTrajectory starting"
                       << std::endl;
    std::unique_ptr<State> varChangeState;
    const State * state_ptr;

    // Do variable change if it has not already been done.
    if ( geovals.getVars() <= state.variables() ) {
      state_ptr = &state;
    } else {
      varChangeState.reset(new State(*geom_, geovals.getVars(),
                                     state.validTime()));
      model2geovals_->changeVar(state, *varChangeState);
      state_ptr = varChangeState.get();
    }

    eckit::LocalConfiguration conf;
    linearmodel2geovals_.reset(new LinearModel2GeoVaLs(state, state,
                                                       *geom_, conf));

    roms_getvalues_fill_geovals_f90(keyLinearGetValues_,
                                    geom_->toFortran(),
                                    state.toFortran(),
                                    t1, t2, locs_,
                                    geovals.toFortran());
    oops::Log::trace() << "LinearGetValues::setTrajectory done"
                       << std::endl;
  }

// -----------------------------------------------------------------------------
/// Interpolate tangent linear state to observation locations
// -----------------------------------------------------------------------------

  void LinearGetValues::fillGeoVaLsTL(const Increment & incr,
                                      const util::DateTime & t1,
                                      const util::DateTime & t2,
                                      ufo::GeoVaLs & geovals) const {
    oops::Log::trace() << "LinearGetValues::fillGeoVaLsTL starting"
                       << std::endl;
    Increment incrGeovals(*geom_, geovals.getVars(), incr.validTime());
    linearmodel2geovals_->multiply(incr, incrGeovals);
    roms_getvalues_fill_geovals_tl_f90(keyLinearGetValues_,
                                       geom_->toFortran(),
                                       incrGeovals.toFortran(),
                                       t1, t2, locs_,
                                       geovals.toFortran());
    oops::Log::trace() << "LinearGetValues::fillGeoVaLsTL done"
                       << std::endl;
  }

// -----------------------------------------------------------------------------
/// Backward (adjoint) interpolation of observations to adjoint state
// -----------------------------------------------------------------------------

  void LinearGetValues::fillGeoVaLsAD(Increment & incr,
                                      const util::DateTime & t1,
                                      const util::DateTime & t2,
                                      const ufo::GeoVaLs & geovals) const {
    oops::Log::trace() << "LinearGetValues::fillGeoVaLsAD starting"
                       << std::endl;
    Increment incrGeovals(*geom_, geovals.getVars(), incr.validTime());
    roms_getvalues_fill_geovals_ad_f90(keyLinearGetValues_,
                                       geom_->toFortran(),
                                       incrGeovals.toFortran(),
                                       t1, t2, locs_,
                                       geovals.toFortran());
    linearmodel2geovals_->multiplyAD(incrGeovals, incr);
    oops::Log::trace() << "LinearGetValues::fillGeoVaLsAD done"
                       << std::endl;
  }

// -----------------------------------------------------------------------------
/// Report
// -----------------------------------------------------------------------------

  void LinearGetValues::print(std::ostream & os) const {
    os << "LinearGetValues for roms-jedi" << std::endl;
  }

// -----------------------------------------------------------------------------

}  // namespace roms
