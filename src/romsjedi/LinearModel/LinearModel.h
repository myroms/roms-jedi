/*
 * (C) Copyright 2017-2021 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 *
 *!
 * \brief   **LinearModel** C++ Class to initialize, run, and finalize TLROMS
 *          and ADROMS
 *
 * \details These C++ functions creates/destroy, initialize, step, and finalize
 *          ROMS tangent linear and adjoint kernel objects to run a particular
 *          JEDI application.
 *
 * \author  Hernan G. Arango (Rutgers University)
 * \date    October 2021
 */

#pragma once

#include <map>
#include <ostream>
#include <string>

#include "oops/interface/LinearModelBase.h"
#include "oops/util/DateTime.h"
#include "oops/util/Duration.h"
#include "oops/util/ObjectCounter.h"
#include "oops/util/Printable.h"
#include "oops/util/parameters/Parameters.h"
#include "oops/util/parameters/RequiredParameter.h"

#include "romsjedi/Traits.h"

// Forward declarations

namespace eckit {
  class Configuration;
}

namespace romsjedi {

// -----------------------------------------------------------------------------

  /// Linear Model Parameters Class. The property 'name' is already part of
  /// the default schema.

  class LinearModelParameters : public oops::LinearModelParametersBase {
    OOPS_CONCRETE_PARAMETERS(LinearModelParameters, LinearModelParametersBase)

   public:
    oops::RequiredParameter<oops::Variables> lmvars{
      "lm variables",
      "Linear Model State variables to process",
      this};
    oops::RequiredParameter<util::DateTime> date{
      "date",
      "Linear Model initial condition date/time",
      this};
    oops::RequiredParameter<util::Duration> tstep{
      "tstep",
      "Linear Model time step",
      this};
    oops::RequiredParameter<util::Duration> SimulationLength{
      "simulation length",
      "Model simulation length period",
      this};
    oops::RequiredParameter<eckit::LocalConfiguration> traj{
      "trajectory",
      "Nonlinear Trajectory parameters",
      this};
  };

  // ROMS Linear Model definition.

  class LinearModel: public oops::interface::LinearModelBase<Traits>,
                     private util::ObjectCounter<LinearModel> {
   public:
    typedef LinearModelParameters Parameters_;

    static const std::string classname() {return "romsjedi::LinearModel";}

  // Constructor/destructor

    LinearModel(const Geometry &, const LinearModelParameters &);
    ~LinearModel();

  // Set the trajectory

    void setTrajectory(const State &, State &, const ModelBias &) override;

  // Run tangent linear and its adjoint

    void initializeTL(Increment &) const override;
    void stepTL(Increment &, const ModelBiasIncrement &) const override;
    void finalizeTL(Increment &) const override;

    void initializeAD(Increment &) const override;
    void stepAD(Increment &, ModelBiasIncrement &) const override;
    void finalizeAD(Increment &) const override;

  // Accessor functions

    const util::Duration & timeResolution() const override {return tstep_;}
    const oops::Variables & variables() const override {return lmvars_;}

   private:
    void print(std::ostream &) const override;
    typedef std::map< util::DateTime, int >::iterator trajIter;
    typedef std::map< util::DateTime, int >::const_iterator trajICst;

  // Data

    F90flds keyFlds_;
    F90model keySelf_;
    util::Duration tstep_;
    std::map< util::DateTime, F90traj> trajmap_;
    const oops::Variables lmvars_;
  };

// -----------------------------------------------------------------------------

}  // namespace romsjedi
