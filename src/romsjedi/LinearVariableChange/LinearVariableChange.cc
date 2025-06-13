/*
 * (C) Copyright 2021-2025 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#include <ostream>
#include <string>

#include "eckit/config/Configuration.h"

#include "oops/util/Logger.h"

#include "romsjedi/Geometry/Geometry.h"
#include "romsjedi/Increment/Increment.h"
#include "romsjedi/LinearVariableChange/LinearVariableChange.h"
#include "romsjedi/State/State.h"

using oops::Log;

namespace romsjedi {

// -----------------------------------------------------------------------------

  LinearVariableChange::LinearVariableChange(const Geometry & geom,
                                             const eckit::Configuration &
                                                          config)
    : geom_(new Geometry(geom)),
      linearVariableChange_()
  {
    params_.deserialize(config);
    eckit::LocalConfiguration variableChangeConfig = params_.toConfiguration();
  }

// -----------------------------------------------------------------------------

  LinearVariableChange::~LinearVariableChange() {}

// -----------------------------------------------------------------------------

  void LinearVariableChange::changeVarTraj(const State & xfg,
                                           const oops::Variables & vars) {
    Log::trace() << classname() << ":changeVarTraj starting" << std::endl;
    Log::debug() << classname() << ":changeVarTraj: OOPS " << vars << std::endl;
    Log::debug() << classname() << ":changeVarTraj: xfg" << xfg<< std::endl;

  // Create the variable change

    linearVariableChange_.reset(LinearVariableChangeFactory::create(
                          xfg, xfg, *geom_,
                          params_.linearVariableChangeParameters.value()));
    Log::trace() << classname() << ":changeVarTraj done" << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinearVariableChange::changeVarTL(Increment & dx,
                                         const oops::Variables & vars) const {
    Log::trace() << classname() << ":changeVarTL starting" << std::endl;
    Log::debug() << classname() << ":changeVarTL: OOPS " << vars << std::endl;

  // If all OOPS variables already in incoming increment, remove no longer
  // needed fields

    Log::debug() << classname() << ":changeVarTL: Increment "
                 << dx.variables() << std::endl;
    if (vars <= dx.variables()) {
      Log::debug() << classname() << ":changeVarTL not required; "
                   << "all increment variables are available" << std::endl;
      dx.updateFields(vars);
      Log::debug() << classname() << ":changeVarTL: " << dx << std::endl;
      Log::trace() << classname() << ":changeVarTL done (identity)"
                   << std::endl;
      return;
    }

  // Create output state

    Increment dxout(dx.geometry(), vars, dx.validTime());

  // Call variable change

    linearVariableChange_->multiply(dx, dxout);

  // Allocate any extra fields and remove fields no longer needed

    dx.updateFields(vars);

  // Copy data from temporary state

    dx = dxout;

    Log::debug() << classname() << ":changeVarTL: " << dx << std::endl;
    Log::trace() << classname() << ":changeVarTL done" << dx << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinearVariableChange::changeVarInverseTL(Increment & dx,
                                           const oops::Variables & vars) const {
    Log::trace() << classname() << ":changeVarInverseTL starting" << std::endl;
    Log::debug() << classname() << ":changeVarInverseTL: OOPS " << vars
                 << std::endl;

  // If all OOPS variables already in incoming increment, remove no longer
  // needed fields

    if (vars <= dx.variables()) {
      Log::debug() << classname() << ":changeVarInverseTL not required; "
                   << "all increment variables are available" << std::endl;
      dx.updateFields(vars);
      Log::debug() << classname() << ":changeVarInverseTL: " << dx << std::endl;
      oops::Log::trace() << classname() << ":changeVarInverseTL done (identity)"
                         << std::endl;
      return;
    }

  // Create output state

    Increment dxout(dx.geometry(), vars, dx.validTime());

  // Call variable change

    linearVariableChange_->multiplyInverse(dx, dxout);

  // Allocate any extra fields and remove fields no longer needed

    dx.updateFields(vars);

  // Copy data from temporary state

    dx = dxout;

    Log::debug() << classname() << ":changeVarInverseTL: " << dx << std::endl;
    Log::trace() << classname() << ":changeVarInverseTL done" << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinearVariableChange::changeVarAD(Increment & dx,
                                         const oops::Variables & vars) const {
    Log::trace() << classname() << ":changeVarAD starting" << std::endl;
    Log::debug() << classname() << ":changeVarAD: OOPS " << vars << std::endl;

  // If all OOPS variables already in incoming increment, remove no longer
  // needed fields

    Log::debug() << classname() << ":changeVarAD: Increment "
                 << dx.variables() << std::endl;
    if (vars <= dx.variables()) {
      Log::debug() << classname() << ":changeVarAD not required; "
                   << "all increment variables are available" << std::endl;
      dx.updateFields(vars);
      Log::debug() << classname() << ":changeVarAD: " << dx << std::endl;
      Log::trace() << classname() << ":changeVarAD done (identity)"
                   << std::endl;
      return;
    }

  // Create output state

    Increment dxout(dx.geometry(), vars, dx.validTime());

  // Call variable change

    linearVariableChange_->multiplyAD(dx, dxout);

  // Allocate any extra fields and remove fields no longer needed

    dx.updateFields(vars);

  // Copy data from temporary state

    dx = dxout;

    Log::debug() << classname() << ":changeVarAD: " << dx << std::endl;
    Log::trace() << classname() << ":changeVarAD done" << std::endl;
}

// -----------------------------------------------------------------------------

  void LinearVariableChange::changeVarInverseAD(Increment & dx,
                                           const oops::Variables & vars) const {
    Log::trace() << classname() << ":changeVarInverseAD starting" << std::endl;
    Log::debug() << classname() << ":changeVarInverseAD: OOPS " << vars
                 << std::endl;

  // If all OOPS variables already in incoming increment, remove no longer
  // needed fields

    if (vars <= dx.variables()) {
      Log::debug() << classname() << ":changeVarInverseAD not required; "
                   << "all increment variables are available" << std::endl;
      dx.updateFields(vars);
      Log::debug() << classname() << ":changeVarInverseAD: " << dx << std::endl;
      Log::trace() << classname() << ":changeVarInverseAD done (identity)"
                   << std::endl;
      return;
    }

  // Create output state

    Increment dxout(dx.geometry(), vars, dx.validTime());

  // Call variable change

    linearVariableChange_->multiplyInverseAD(dx, dxout);

  // Allocate any extra fields and remove fields no longer needed

    dx.updateFields(vars);

  // Copy data from temporary state

    dx = dxout;

    Log::debug() << classname() << ":changeVarInverseAD: " << dx << std::endl;
    Log::trace() << classname() << ":changeVarInverseAD done" << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinearVariableChange::print(std::ostream & os) const {
    os << "ROMS-JEDI variable change";
  }

// -----------------------------------------------------------------------------

}  // namespace romsjedi
