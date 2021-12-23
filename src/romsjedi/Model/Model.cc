/*
 * (C) Copyright 2019-2021 UCAR
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

#include "eckit/config/Configuration.h"
#include "eckit/exception/Exceptions.h"

#include "oops/util/abor1_cpp.h"
#include "oops/util/DateTime.h"
#include "oops/util/Logger.h"

#include "romsjedi/Traits.h"
#include "romsjedi/Geometry/Geometry.h"
#include "romsjedi/Model/Model.h"
#include "romsjedi/Model/ModelFortran.h"
#include "romsjedi/ModelBias/ModelBias.h"
#include "romsjedi/State/State.h"

using oops::Log;

namespace romsjedi {

// ----------------------------------------------------------------------------

  static oops::interface::ModelMaker<Traits, Model> modelmaker_("ROMS");

// ----------------------------------------------------------------------------

  Model::Model(const Geometry & resol,
               const ModelParameters & params)
    : keyConfig_(0),
      tstep_(params.tstep),
      geom_(new Geometry(resol)),
      vars_(params.vars)
  {
    Log::trace() << "Model::Model" << std::endl;
    Log::trace() << "Model vars: " << vars_ << std::endl;
    roms_model_create_f90(params.toConfiguration(),
                          geom_->toFortran(),
                          keyConfig_);
    oops::Log::trace() << "Model created" << std::endl;
  }

// ----------------------------------------------------------------------------

  Model::~Model() {
  roms_model_delete_f90(keyConfig_);
  oops::Log::trace() << "Model destructed" << std::endl;
  }

// ----------------------------------------------------------------------------

  void Model::initialize(State & xx) const {
  util::DateTime * dtp = &xx.validTime();
  roms_model_initialize_f90(keyConfig_,
                            xx.toFortran(),
                            &dtp);
  oops::Log::debug() << "Model::initialize" << std::endl;
  }

// ----------------------------------------------------------------------------

  void Model::step(State & xx,
                   const ModelBias &) const {
    xx.validTime() += tstep_;
    Log::trace() << "Model::Time: " << xx.validTime() << std::endl;
    util::DateTime * dtp = &xx.validTime();
    roms_model_step_f90(keyConfig_,
                        xx.toFortran(),
                        geom_->toFortran(),
                        &dtp);
    oops::Log::debug() << "Model::step" << std::endl;
  }

// ----------------------------------------------------------------------------

  void Model::finalize(State & xx) const {
    roms_model_finalize_f90(keyConfig_, xx.toFortran());
    oops::Log::debug() << "Model::finalize" << std::endl;
  }

// ----------------------------------------------------------------------------

  void Model::print(std::ostream & os) const {
    os << "Model::print not implemented";
  }

// ----------------------------------------------------------------------------

}  // namespace romsjedi
