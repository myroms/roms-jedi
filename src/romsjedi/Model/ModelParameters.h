/*
 * (C) Copyright 2019-2025 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 *
 *!
 * \brief   Integrates ROMS nonlinear model (NLM) kernel: NLROMS
 *
 * \details These routines creates/destroy, initialize, step, and finalize
 *          ROMS NLM kernel objects to run a particular JEDI application.
 *
 * \author  Hernan G. Arango (Rutgers University)
 * \date    September 2021
 */

#ifndef ROMSJEDI_MODEL_MODELPARAMETERS_H_
#define ROMSJEDI_MODEL_MODELPARAMETERS_H_

#include "oops/base/Variables.h"
#include "oops/interface/ModelBase.h"
#include "oops/util/Duration.h"
#include "oops/util/parameters/Parameters.h"
#include "oops/util/parameters/RequiredParameter.h"

namespace romsjedi {

// ----------------------------------------------------------------------------

  /// Model Parameters Class. The property 'name' is already part of the
  /// default schema.

  class ModelParameters : public oops::Parameters {
    OOPS_CONCRETE_PARAMETERS(ModelParameters, Parameters)

   public:
    oops::RequiredParameter<oops::Variables> vars{
      "model variables",
      "Model State variables to process",
      this};
    oops::RequiredParameter<util::Duration> tstep{
      "tstep",
      "Model time step",
      this};
    oops::RequiredParameter<util::Duration> SimulationLength{
      "simulation length",
      "Model simulation length period",
      this};
  };
}  // namespace romsjedi

// -----------------------------------------------------------------------------

#endif  // ROMSJEDI_MODEL_MODELPARAMETERS_H_
