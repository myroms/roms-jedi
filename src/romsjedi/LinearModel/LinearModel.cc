/*
 * (C) Copyright 2017-2021 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 *
 *!
 * \brief   **LinearModel** Class, ROMS-JEDI interface: TLROMS and ADROMS
 *
 * \details It initializes, run, and finalizes ROMS tangent linear (TLROMS) and
 *          adjoint (ADROMS) dynamical/numerical kernels.
 *
 * \author  Hernan G. Arango (Rutgers University)
 * \date    October 2021
 */

#include <vector>

#include "eckit/config/LocalConfiguration.h"

#include "oops/util/abor1_cpp.h"
#include "oops/util/DateTime.h"
#include "oops/util/Logger.h"

#include "romsjedi/Traits.h"
#include "romsjedi/Geometry/Geometry.h"
#include "romsjedi/Increment/Increment.h"
#include "romsjedi/LinearModel/LinearModel.h"
#include "romsjedi/LinearModel/LinearModelFortran.h"
#include "romsjedi/LinearModel/TrajectoryFortran.h"
#include "romsjedi/State/State.h"

namespace romsjedi {

// -----------------------------------------------------------------------------

  static oops::interface::LinearModelMaker<Traits, LinearModel>
                          linearModelmaker_("LMROMS");

// -----------------------------------------------------------------------------

  LinearModel::LinearModel(const Geometry & resol,
                           const eckit::Configuration & config)
    : keySelf_(0),
      tstep_(),
      trajmap_()
  {
  oops::Log::trace() << "LinearModel::LinearModel starting" << std::endl;

  // Store time step

  tstep_ = util::Duration(config.getString("tstep"));

  // Implementation

  roms_linearModel_create_f90(keySelf_,
                              resol.toFortran(),
                              config);
  oops::Log::trace() << "LinearModel::LinearModel done" << std::endl;
  }

// -----------------------------------------------------------------------------

  LinearModel::~LinearModel() {
    oops::Log::trace() << "LinearModel::~LinearModel starting" << std::endl;

  // Implementation

    roms_linearModel_delete_f90(keySelf_);

  // Clear trajectory

    for (trajIter jtra = trajmap_.begin(); jtra != trajmap_.end(); ++jtra) {
      roms_trajectory_destroy_f90(jtra->second);
    }
    oops::Log::trace() << "LinearModel::~LinearModel done" << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinearModel::setTrajectory(const State & xx, State & xlr,
                                  const ModelBias & bias) {
    oops::Log::trace() << "LinearModel::setTrajectory starting" << std::endl;

  // Interpolate to resolution of the trajectory
  // xlr.changeResolution(xx);

  // Set trajecotry

    int keyTraj = 0;
    util::DateTime * dtp = &xlr.validTime();
    roms_trajectory_set_f90(keyTraj,
                            xlr.toFortran(),
                            &dtp);
    ASSERT(keyTraj != 0);
    trajmap_[xx.validTime()] = keyTraj;

    oops::Log::trace() << "LinearModel::setTrajectory done" << std::endl;
}

// -----------------------------------------------------------------------------

  void LinearModel::initializeTL(Increment & dx) const {
    oops::Log::trace() << "LinearModel::initializeTL starting" << std::endl;

  // Implementation

    util::DateTime * dtp = &dx.validTime();
    roms_linearModel_initialize_tl_f90(keySelf_,
                                       dx.toFortran(),
                                       &dtp);
    oops::Log::trace() << "LinearModel::initializeTL done" << std::endl;
}

// -----------------------------------------------------------------------------

  void LinearModel::stepTL(Increment & dx, const ModelBiasIncrement &) const {
    oops::Log::trace() << "LinearModel::stepTL starting" << std::endl;

  // Get NL trajectory index from stored map.

    typedef std::map< util::DateTime, int >::const_iterator trajICst;

    trajICst itra = trajmap_.find(dx.validTime());

  // Check if NL trajectory is available at valid date/time.

    if (itra == trajmap_.end()) {
      oops::Log::error() << "LinearModel::stepTL: trajectory lacking at time "
                         << dx.validTime() << std::endl;
      ABORT("LinearModel:stepTL: trajectory not available");
    }

    oops::Log::debug() << "LinearModel::stepTL: Got NL Trajectory index "
                       << itra->second << " for time "
                       << itra->first << std::endl;

  // Advance TLROMS. Recall that ROMS kernels have a predictor/corrector
  // time-stepping scheme with multiple time indices.
  //
  // The initial increment is updated on the first timestep to apply the
  // lateral boundary conditions and compute the vertically integrated
  // (barotropic) momentum. However, we haven't figured out how to pass the
  // updated initial increment back to OOPS in the current design.

    oops::Log::debug() << "LinearModel::stepTL INPUT incremnent:" << dx
                       << std::endl;

    util::DateTime * dtp = &dx.validTime();
    roms_linearModel_step_tl_f90(keySelf_,
                                 dx.toFortran(),
                                 itra->second,
                                 &dtp);

  // Advance forward increment clock.

    dx.validTime() += tstep_;

    oops::Log::debug() << "LinearModel::stepTL OUTPUT incremnent:" << dx
                       << std::endl;
    oops::Log::trace() << "LinearModel::stepTL done" << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinearModel::finalizeTL(Increment & dx) const {
    oops::Log::trace() << "LinearModel::finalizeTL starting" << std::endl;

  // Implementation

    roms_linearModel_finalize_tl_f90(keySelf_,
                                     dx.toFortran());
    oops::Log::trace() << "LinearModel::finalizeTL done" << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinearModel::initializeAD(Increment & dx) const {
    oops::Log::trace() << "LinearModel::initializeAD starting" << std::endl;

  // Implementation

    util::DateTime * dtp = &dx.validTime();
    roms_linearModel_initialize_ad_f90(keySelf_,
                                       dx.toFortran(),
                                       &dtp);
    oops::Log::trace() << "LinearModel::initializeAD done" << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinearModel::stepAD(Increment & dx, ModelBiasIncrement &) const {
    oops::Log::trace() << "LinearModel::stepAD starting" << std::endl;

  // Advance backward increment clock.

    util::DateTime * dtp = &dx.validTime();
    dx.validTime() -= tstep_;

  // Get NL trajectory index from stored map.

    trajICst itra = trajmap_.find(dx.validTime());

  // Check if NL trajectory is available at valid date/time.

    if (itra == trajmap_.end()) {
      oops::Log::error() << "LinearModel::stepAD: trajectory lacking at time "
                         << dx.validTime() << std::endl;
      ABORT("LinearModel::stepAD: trajectory not available");
    }

    oops::Log::debug() << "LinearModel::stepTL: Got NL Trajectory index "
                       << itra->second << " for time "
                       << itra->first << std::endl;

  // Advance ADROMS. Recall that ROMS kernels have a predictor/corrector
  // time-stepping scheme with multiple time indices.
  //
  // On the first step, AD_ADVANCE is false in "ad_main3d", and ADROMS is not
  // time stepped. Then, it computes the adjoint of the delayed output step.
  // Thus, the strategy here is to advance an additional timestep.

    oops::Log::debug() << "LinearModel::stepAD INPUT incremnent:" << dx
                       << std::endl;

    roms_linearModel_step_ad_f90(keySelf_,
                                 dx.toFortran(),
                                 itra->second,
                                 &dtp);

    oops::Log::debug() << "LinearModel::stepAD OUTPUT incremnent:" << dx
                       << std::endl;
    oops::Log::trace() << "LinearModel::stepAD done" << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinearModel::finalizeAD(Increment & dx) const {
    oops::Log::trace() << "LinearModel::finalizeAD starting" << std::endl;

  // Implementation

    roms_linearModel_finalize_ad_f90(keySelf_,
                                     dx.toFortran());
    oops::Log::trace() << "LinearModel::finalizeAD done" << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinearModel::print(std::ostream & os) const {
    oops::Log::trace() << "LinearModel::print starting" << std::endl;

  // Print information about ROMS LinearModel object

    os << "ROMS LinearModel Trajectory, nstep=" << trajmap_.size() << std::endl;
    typedef std::map< util::DateTime, int >::const_iterator trajICst;
    if (trajmap_.size() > 0) {
      os << "ROMS LinearModel Trajectory: times are:";
      for (trajICst jtra = trajmap_.begin(); jtra != trajmap_.end(); ++jtra) {
        os << "  " << jtra->first;
      }
    }
    oops::Log::trace() << "LinearModel::print done" << std::endl;
  }

// -----------------------------------------------------------------------------

}  // namespace romsjedi
