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
    Log::trace() << "LinearVariableChange::changeVarTraj starting"
                 << std::endl;
    Log::debug() << "LinearVariableChange::changeVarTraj: " << vars
                 << std::endl;
    Log::debug() << "LinearVariableChange::changeVarTraj: xfg" << xfg
                 << std::endl;

  // Create the variable change

    linearVariableChange_.reset(LinearVariableChangeFactory::create(
                          xfg, xfg, *geom_,
                          params_.linearVariableChangeParameters.value()));
    Log::trace() << "LinearVariableChange::changeVarTraj done"
                 << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinearVariableChange::changeVarTL(Increment & dx,
                                         const oops::Variables & vars) const {
    Log::trace() << "LinearVariableChange::changeVarTL starting" << std::endl;
    Log::debug() << "LinearVariableChange::changeVarTL: " << vars << std::endl;

  // If all variables already in incoming state, remove no longer needed fields
    if (vars <= dx.variables()) {
      dx.updateFields(vars);
      oops::Log::trace() << "LinearVariableChange::changeVarTL done"
                         << " (identity)" << std::endl;
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

    Log::debug() << "LinearVariableChange::changeVarTL: " << dx << std::endl;
    Log::trace() << "LinearVariableChange::changeVarTL done" << dx
                 << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinearVariableChange::changeVarInverseTL(Increment & dx,
                                           const oops::Variables & vars) const {
    Log::trace() << "LinearVariableChange::changeVarInverseTL starting"
                 << std::endl;
    Log::debug() << "LinearVariableChange::changeVarInverseTL: " << vars
                 << std::endl;

  // If all variables already in incoming state, remove no longer needed fields
    if (vars <= dx.variables()) {
      dx.updateFields(vars);
      oops::Log::trace() << "LinearVariableChange::changeVarInverseTL done"
                         << " (identity)"<< std::endl;
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

    Log::debug() << "LinearVariableChange::changeVarInverseTL: " << dx
                 << std::endl;
    Log::trace() << "LinearVariableChange::changeVarInverseTL done"
                 << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinearVariableChange::changeVarAD(Increment & dx,
                                         const oops::Variables & vars) const {
    Log::trace() << "LinearVariableChange::changeVarAD starting" << std::endl;
    Log::debug() << "LinearVariableChange::changeVarAD: " << vars << std::endl;

  // If all variables already in incoming state, remove no longer needed fields
    if (vars <= dx.variables()) {
      dx.updateFields(vars);
      oops::Log::trace() << "LinearVariableChange::changeVarAD done"
                         << " (identity)" << std::endl;
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

    Log::debug() << "LinearVariableChange::changeVarAD: " << dx << std::endl;
    Log::trace() << "LinearVariableChange::changeVarAD done" << std::endl;
}

// -----------------------------------------------------------------------------

  void LinearVariableChange::changeVarInverseAD(Increment & dx,
                                           const oops::Variables & vars) const {
    Log::trace() << "LinearVariableChange::changeVarInverseAD starting"
                 << std::endl;
    Log::debug() << "LinearVariableChange::changeVarInverseAD: " << vars
                 << std::endl;

  // If all variables already in incoming state, remove no longer needed fields
    if (vars <= dx.variables()) {
      dx.updateFields(vars);
      oops::Log::trace() << "LinearVariableChange::changeVarInverseAD done"
                         << " (identity)" << std::endl;
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

    Log::debug() << "LinearVariableChange::changeVarInverseAD: " << dx
                 << std::endl;
    Log::trace() << "LinearVariableChange::changeVarInverseAD done"
                 << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinearVariableChange::print(std::ostream & os) const {
    os << "ROMS-JEDI variable change";
  }

// -----------------------------------------------------------------------------

}  // namespace romsjedi
