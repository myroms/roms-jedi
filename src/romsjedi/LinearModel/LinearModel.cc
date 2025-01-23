/*
 * (C) Copyright 2017-2025 UCAR
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
      steptraj_(),
      trajmap_()
  {
  oops::Log::trace() << classname() << ":LinearModel starting" << std::endl;

  // Store time step

  tstep_ = util::Duration(config.getString("tstep"));
  steptraj_ = util::Duration(config.getString("trajectory.tstep",
                                              tstep_.toString()));

  oops::Log::debug() << classname() << ":LinearModel TL/AD Time Step = "
                     << tstep_.toSeconds() << " seconds" << std::endl;
  oops::Log::debug() << classname() << ":LinearModel Trajectory Step = "
                     << steptraj_.toSeconds() << " seconds" << std::endl;
  oops::Log::debug() << classname() << ":LinearModel MOD(steptraj, tstep) = "
                     << steptraj_ % tstep_ << std::endl;

  ASSERT(steptraj_ % tstep_ == 0);

  // Implementation

  roms_linearModel_create_f90(keySelf_,
                              resol.toFortran(),
                              config);
  oops::Log::trace() << classname() << ":LinearModel done" << std::endl;
  }

// -----------------------------------------------------------------------------

  LinearModel::~LinearModel() {
    oops::Log::trace() << classname() << ":~LinearModel starting" << std::endl;

  // Implementation

    roms_linearModel_delete_f90(keySelf_);

  // Clear trajectory

    for (trajIter jtra = trajmap_.begin(); jtra != trajmap_.end(); ++jtra) {
      roms_trajectory_destroy_f90(jtra->second);
    }
    oops::Log::trace() << classname() << ":~LinearModel done" << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinearModel::setTrajectory(const State & xx,
                                  State & xlr,
                                  const ModelBias & bias) {
    oops::Log::trace() << classname() << ":setTrajectory starting" << std::endl;

  // Interpolate to resolution of the trajectory
  // xlr.changeResolution(xx);

  // Set trajectory

    int keyTraj = 0;
    util::DateTime * dtp = &xlr.validTime();

    roms_trajectory_set_f90(keyTraj,
                            xlr.toFortran(),
                            &dtp);
    ASSERT(keyTraj != 0);
    trajmap_[xx.validTime()] = keyTraj;

    oops::Log::debug() << classname() << ":setTrajectory validTime = "
                       << *dtp << ", keyTraj = " << keyTraj << std::endl;
    oops::Log::trace() << classname() << ":setTrajectory done" << std::endl;
}

// -----------------------------------------------------------------------------

  void LinearModel::initializeTL(Increment & dx) const {
    oops::Log::trace() << "LinearModel::initializeTL starting" << std::endl;

  // Get stored NL trajectory map indices. The trajectory may be stored
  // at every timestep (high-memory requirements) or at "trajectory.tstep"
  // snapshots for time iterpolation.

    ASSERT(trajmap_.begin()->first <= dx.validTime());
    ASSERT(trajmap_.rbegin()->first >= dx.validTime());

    trajICst itra1 = trajmap_.find(dx.validTime());
    trajICst itra2 = itra1;

  // Compute NL trajectory linear time interpolation weights (fac1, fac2)
  // such that Fi = fac1 * F(itra1) + fac2 * F(itra2). Here, itra2 is a
  // dummy argument with zero weight.

    const double fac1 = 1.0;
    const double fac2 = 0.0;

    oops::Log::debug() << classname() << ":initializeTL validTime = "
                       << dx.validTime() << std::endl;
    oops::Log::debug() << classname() << ":intializeTL  itra1 = "
                       << itra1->second << ", dateTime: " << itra1->first
                       << ", fac1 = " << fac1 << std::endl;
    oops::Log::debug() << classname() << ":initializeTL  itra2 = "
                       << itra2->second << ", dateTime: " << itra2->first
                       << ", fac2 = " << fac2 << std::endl;

    ASSERT(fac1 * fac2 >= 0 && fac1 + fac2 > 0);

  // Initialize TLROMS.

    util::DateTime * dtp = &dx.validTime();
    roms_linearModel_initialize_tl_f90(keySelf_,
                                       dx.toFortran(),
                                       itra1->second,
                                       itra2->second,
                                       fac1,
                                       fac2,
                                       &dtp);
    oops::Log::trace() << classname() << ":initializeTL done" << std::endl;
}

// -----------------------------------------------------------------------------

  void LinearModel::stepTL(Increment & dx, const ModelBiasIncrement &) const {
    oops::Log::trace() << classname() << ":stepTL starting" << std::endl;

  // Get stored NL trajectory map indices. The trajectory may be stored
  // at every timestep (high-memory requirements) or at "trajectory.tstep"
  // snapshots for time iterpolation.

    ASSERT(trajmap_.begin()->first <= dx.validTime());
    ASSERT(trajmap_.rbegin()->first >= dx.validTime());

    const util::Duration delta((dx.validTime() -
                                trajmap_.begin()->first) % steptraj_);

    trajICst itra1 = trajmap_.find(dx.validTime() - delta);
    trajICst itra2 = trajmap_.find(dx.validTime() - delta + steptraj_);

  // Compute NL trajectory linear time interpolation weights (fac1, fac2)
  // such that F = fac1 * F1(itra1) + fac2 * F2(itra2).

    const util::Duration dt1(itra2->first - dx.validTime());
    const util::Duration dt2(dx.validTime() - itra1->first);
    const double fac1(static_cast<double>(dt1.toSeconds()) /
                      static_cast<double>(steptraj_.toSeconds()));
    const double fac2(static_cast<double>(dt2.toSeconds()) /
                      static_cast<double>(steptraj_.toSeconds()));

    oops::Log::debug() << classname() << ":stepTL validTime = "
                       << dx.validTime() << ", delta = "
                       << delta.toSeconds() << std::endl;
    oops::Log::debug() << classname() << ":stepTL  itra1 = "
                       << itra1->second << ", dateTime: " << itra1->first
                       << ", dt1 = " << dt1.toSeconds()
                       << ", fac1 = " << fac1 << std::endl;
    oops::Log::debug() << classname() << ":stepTL  itra2 = "
                       << itra2->second << ", dateTime: " << itra2->first
                       << ", dt2 = " << dt2.toSeconds()
                       << ", fac2 = " << fac2 << std::endl;

    ASSERT(fac1 * fac2 >= 0 && fac1 + fac2 > 0);

  // Timestep TLROMS Kernel.

    oops::Log::debug() << classname() << ":stepTL INPUT incremnent" << dx
                       << std::endl;

    util::DateTime * dtp = &dx.validTime();
    roms_linearModel_step_tl_f90(keySelf_,
                                 dx.toFortran(),
                                 itra1->second,
                                 itra2->second,
                                 fac1,
                                 fac2,
                                 &dtp);

  // Advance tangent linear increment clock.

    dx.validTime() += tstep_;

    oops::Log::debug() << classname() << ":stepTL OUTPUT incremnent" << dx
                       << std::endl;
    oops::Log::trace() << classname() << ":stepTL done" << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinearModel::finalizeTL(Increment & dx) const {
    oops::Log::trace() << classname() << ":finalizeTL starting" << std::endl;

  // Implementation

    roms_linearModel_finalize_tl_f90(keySelf_,
                                     dx.toFortran());
    oops::Log::trace() << classname() << ":finalizeTL done" << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinearModel::initializeAD(Increment & dx) const {
    oops::Log::trace() << classname() << ":initializeAD starting" << std::endl;

  // Get stored NL trajectory map indices. The trajectory may be stored
  // at every timestep (high-memory requirements) or at "trajectory.tstep"
  // snapshots for time iterpolation.

    ASSERT(trajmap_.begin()->first <= dx.validTime());
    ASSERT(trajmap_.rbegin()->first >= dx.validTime());

    trajICst itra1 = trajmap_.find(dx.validTime());
    trajICst itra2 = itra1;

  // Compute NL trajectory linear time interpolation weights (fac1, fac2)
  // such that Fi = fac1 * F(itra1) + fac2 * F(itra2). Here, itra2 is a
  // dummy argument with zero weight.

    const double fac1 = 1.0;
    const double fac2 = 0.0;

    oops::Log::debug() << classname() << ":initializeAD validTime = "
                       << dx.validTime() << std::endl;
    oops::Log::debug() << classname() << ":intializeAD  itra1 = "
                       << itra1->second << ", dateTime: " << itra1->first
                       << ", fac1 = " << fac1 << std::endl;
    oops::Log::debug() << classname() << ":initializeAD  itra2 = "
                       << itra2->second << ", dateTime: " << itra2->first
                       << ", fac2 = " << fac2 << std::endl;

    ASSERT(fac1 * fac2 >= 0 && fac1 + fac2 > 0);

  // Initialize ADROMS.

    util::DateTime * dtp = &dx.validTime();
    roms_linearModel_initialize_ad_f90(keySelf_,
                                       dx.toFortran(),
                                       itra1->second,
                                       itra2->second,
                                       fac1,
                                       fac2,
                                       &dtp);
    oops::Log::trace() << classname() << ":initializeAD done" << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinearModel::stepAD(Increment & dx, ModelBiasIncrement &) const {
    oops::Log::trace() << classname() << ":stepAD starting" << std::endl;

  // Advance backward adjoint increment clock.

    util::DateTime * dtp = &dx.validTime();
    dx.validTime() -= tstep_;

  // Get stored NL trajectory map indices. The trajectory may be stored
  // at every timestep (high-memory requirements) or at "trajectory.tstep"
  // snapshots for time iterpolation.

    ASSERT(trajmap_.begin()->first <= dx.validTime());
    ASSERT(trajmap_.rbegin()->first >= dx.validTime());

    const util::Duration delta((dx.validTime() -
                                trajmap_.begin()->first) % steptraj_);

    trajICst itra1 = trajmap_.find(dx.validTime() - delta);
    trajICst itra2 = trajmap_.find(dx.validTime() - delta + steptraj_);

  // Compute NL trajectory linear time interpolation weights (fac1, fac2)
  // such that Fi = fac1 * F(itra1) + fac2 * F(itra2).

    const util::Duration dt1(itra2->first - dx.validTime());
    const util::Duration dt2(dx.validTime() - itra1->first);
    const double fac1(static_cast<double>(dt1.toSeconds()) /
                      static_cast<double>(steptraj_.toSeconds()));
    const double fac2(static_cast<double>(dt2.toSeconds()) /
                      static_cast<double>(steptraj_.toSeconds()));

    oops::Log::debug() << classname() << ":stepAD validTime = "
                       << dx.validTime() << ", delta = "
                       << delta.toSeconds() << std::endl;
    oops::Log::debug() << classname() << ":stepAD  itra1 = "
                       << itra1->second << ", dateTime: " << itra1->first
                       << ", dt1 = " << dt1.toSeconds()
                       << ", fac1 = " << fac1 << std::endl;
    oops::Log::debug() << classname() << ":stepAD  itra2 = "
                       << itra2->second << ", dateTime: " << itra2->first
                       << ", dt2 = " << dt2.toSeconds()
                       << ", fac2 = " << fac2 << std::endl;

    ASSERT(fac1 * fac2 >= 0 && fac1 + fac2 > 0);

  // Timestep ADROMS kernel backward.

    oops::Log::debug() << classname() << ":stepAD INPUT incremnent" << dx
                       << std::endl;

    roms_linearModel_step_ad_f90(keySelf_,
                                 dx.toFortran(),
                                 itra1->second,
                                 itra2->second,
                                 fac1,
                                 fac2,
                                 &dtp);

    oops::Log::debug() << classname() << ":stepAD OUTPUT incremnent" << dx
                       << std::endl;
    oops::Log::trace() << classname() << ":stepAD done" << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinearModel::finalizeAD(Increment & dx) const {
    oops::Log::trace() << classname() << ":finalizeAD starting" << std::endl;

  // Implementation

    roms_linearModel_finalize_ad_f90(keySelf_,
                                     dx.toFortran());
    oops::Log::trace() << classname() << ":finalizeAD done" << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinearModel::print(std::ostream & os) const {
    oops::Log::trace() << classname() << ":print starting" << std::endl;

  // Print information about ROMS LinearModel object

    os << "ROMS LinearModel Trajectory, nstep=" << trajmap_.size() << std::endl;
    typedef std::map< util::DateTime, int >::const_iterator trajICst;
    if (trajmap_.size() > 0) {
      os << "ROMS LinearModel Trajectory: times are:";
      for (trajICst jtra = trajmap_.begin(); jtra != trajmap_.end(); ++jtra) {
        os << "  " << jtra->first;
      }
    }
    oops::Log::trace() << classname() << ":print done" << std::endl;
  }

// -----------------------------------------------------------------------------

}  // namespace romsjedi
