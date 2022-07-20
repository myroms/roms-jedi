/*
 * (C) Copyright 2021-2022 UCAR.
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#include <ostream>
#include <string>

#include "romsjedi/Geometry/Geometry.h"
#include "romsjedi/Increment/Increment.h"
#include "romsjedi/LinearVariableChange/LinearVariableChange.h"
#include "romsjedi/State/State.h"

namespace romsjedi {

// -----------------------------------------------------------------------------

  LinearVariableChange::LinearVariableChange(const Geometry & geom,
                                             const Parameters_ & params)
    : geom_(new Geometry(geom)),
      params_(params),
      linearVariableChange_() {}

// -----------------------------------------------------------------------------

  LinearVariableChange::~LinearVariableChange() {}

// -----------------------------------------------------------------------------

  void LinearVariableChange::changeVarTraj(const State & xfg,
                                           const oops::Variables & vars) {
    oops::Log::trace() << "LinearVariableChange::changeVarTraj starting"
                       << std::endl;

  // Create the variable change

    linearVariableChange_.reset(LinearVariableChangeFactory::create(
                          xfg, xfg, *geom_,
                          params_.linearVariableChangeParameters.value()));
    oops::Log::trace() << "LinearVariableChange::changeVarTraj done"
                       << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinearVariableChange::changeVarTL(Increment & dx,
                                         const oops::Variables & vars) const {
    oops::Log::trace() << "LinearVariableChange::changeVarTL starting"
                       << std::endl;

  // Create output state
    Increment dxout(*dx.geometry(), vars, dx.validTime());

  // Call variable change
    linearVariableChange_->multiply(dx, dxout);

  // Allocate any extra fields and remove fields no longer needed
    dx.updateFields(vars);

  // Copy data from temporary state
    dx = dxout;

    oops::Log::trace() << "LinearVariableChange::changeVarTL done" << dx
                       << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinearVariableChange::changeVarInverseTL(Increment & dx,
                                           const oops::Variables & vars) const {
    oops::Log::trace() << "LinearVariableChange::changeVarInverseTL starting"
                       << std::endl;

  // Create output state
    Increment dxout(*dx.geometry(), vars, dx.validTime());

  // Call variable change
    linearVariableChange_->multiplyInverse(dx, dxout);

  // Allocate any extra fields and remove fields no longer needed
    dx.updateFields(vars);

  // Copy data from temporary state
    dx = dxout;

    oops::Log::trace() << "LinearVariableChange::changeVarInverseTL done"
                       << std::endl;
}

// -----------------------------------------------------------------------------

  void LinearVariableChange::changeVarAD(Increment & dx,
                                         const oops::Variables & vars) const {
    oops::Log::trace() << "LinearVariableChange::changeVarAD starting"
                       << std::endl;

  // Create output state
    Increment dxout(*dx.geometry(), vars, dx.validTime());

  // Call variable change
    linearVariableChange_->multiplyAD(dx, dxout);

  // Allocate any extra fields and remove fields no longer needed
    dx.updateFields(vars);

  // Copy data from temporary state
    dx = dxout;

    oops::Log::trace() << "LinearVariableChange::changeVarAD done" << std::endl;
}

// -----------------------------------------------------------------------------

  void LinearVariableChange::changeVarInverseAD(Increment & dx,
                                           const oops::Variables & vars) const {
    oops::Log::trace() << "LinearVariableChange::changeVarInverseAD starting"
                       << std::endl;

  // Create output state
    Increment dxout(*dx.geometry(), vars, dx.validTime());

  // Call variable change
    linearVariableChange_->multiplyInverseAD(dx, dxout);

  // Allocate any extra fields and remove fields no longer needed
    dx.updateFields(vars);

  // Copy data from temporary state
    dx = dxout;

    oops::Log::trace() << "LinearVariableChange::changeVarInverseAD done"
                       << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinearVariableChange::print(std::ostream & os) const {
    os << "ROMS-JEDI variable change";
  }

// -----------------------------------------------------------------------------

}  // namespace romsjedi
