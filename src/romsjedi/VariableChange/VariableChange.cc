/*
 * (C) Copyright 2021-2025 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#include <ostream>
#include <string>

#include "oops/mpi/mpi.h"
#include "oops/util/Logger.h"
#include "oops/util/parameters/OptionalParameter.h"
#include "oops/util/parameters/Parameter.h"
#include "oops/util/parameters/Parameters.h"
#include "oops/util/parameters/RequiredParameter.h"

#include "romsjedi/Geometry/Geometry.h"
#include "romsjedi/State/State.h"
#include "romsjedi/VariableChange/VariableChange.h"

namespace romsjedi {

// -----------------------------------------------------------------------------

  VariableChange::VariableChange(const eckit::Configuration & config,
                                 const Geometry & geometry) {
    VariableChangeParametersWrapper params;
    params.deserialize(config);

  // Create the variable change

    variableChange_.reset(VariableChangeFactory::create(geometry,
                                  params.variableChangeParameters.value()));
  }

// -----------------------------------------------------------------------------

  VariableChange::~VariableChange() {}

// -----------------------------------------------------------------------------

  void VariableChange::changeVar(State & x,
                                 const oops::Variables & vars) const {
    oops::Log::trace() << classname() << ":changeVar starting"
                       << std::endl;
    oops::Log::debug() << classname() << ":changeVar State vector: "
                       << x.variables() << std::endl;

  // Create output state
    State xout(x.geometry(), vars, x.validTime());

  // Call variable change
    variableChange_->changeVar(x, xout);

  // Allocate any extra fields and remove fields no longer needed
    x.updateFields(vars);

  // Copy data from temporary state
    x = xout;

    oops::Log::trace() << classname() << ":changeVar done"
                       << std::endl;
  }

// -----------------------------------------------------------------------------

  void VariableChange::changeVarInverse(State & x,
                                        const oops::Variables & vars) const {
    oops::Log::trace() << "VariableChange::changeVarInverse starting"
                       << std::endl;

  // Create output state
    State xout(x.geometry(), vars, x.validTime());

  // Call variable change
    variableChange_->changeVarInverse(x, xout);

  // Allocate any extra fields and remove fields no longer needed
    x.updateFields(vars);

  // Copy data from temporary state
    x = xout;

    oops::Log::trace() << "VariableChange::changeVarInverse done"
                       << std::endl;
  }

// -----------------------------------------------------------------------------

  void VariableChange::print(std::ostream & os) const {
    os << *variableChange_;
  }

// -----------------------------------------------------------------------------

}  // namespace romsjedi
