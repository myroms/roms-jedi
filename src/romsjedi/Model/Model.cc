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

#include "eckit/config/Configuration.h"
#include "eckit/exception/Exceptions.h"

#include "oops/base/ParameterTraitsVariables.h"
#include "oops/util/abor1_cpp.h"
#include "oops/util/DateTime.h"
#include "oops/util/Logger.h"

#include "romsjedi/Traits.h"
#include "romsjedi/Geometry/Geometry.h"
#include "romsjedi/Model/Model.h"
#include "romsjedi/Model/ModelFortran.h"
#include "romsjedi/Model/ModelParameters.h"
#include "romsjedi/ModelBias/ModelBias.h"
#include "romsjedi/State/State.h"

using oops::Log;

namespace romsjedi {

// ----------------------------------------------------------------------------

  static oops::interface::ModelMaker<Traits, Model> modelmaker_("ROMS");

// ----------------------------------------------------------------------------

  Model::Model(const Geometry & resol,
               const eckit::Configuration & config)
    : keyConfig_(0),
      tstep_(0),
      geom_(new Geometry(resol)),
      vars_(config, "model variables")
  {
    Log::trace() << classname() << ":Model starting" << std::endl;

    ModelParameters params;
    params.deserialize(config);
    tstep_ = util::Duration(config.getString("tstep"));

    Log::debug() << classname() << ":Model variables: " << vars_ << std::endl;
    Log::debug() << classname() << ":Model NL Time Step = "
                                << tstep_.toSeconds() << std::endl;

    roms_model_create_f90(config,
                          geom_->toFortran(),
                          keyConfig_);

    oops::Log::trace() << classname() << ":Model done" << std::endl;
  }

// ----------------------------------------------------------------------------

  Model::~Model() {
  Log::trace() << classname() << ":~Model starting" << std::endl;

  roms_model_delete_f90(keyConfig_);

  Log::trace() << classname() << ":~Model done" << std::endl;
  }

// ----------------------------------------------------------------------------

  void Model::initialize(State & xx) const {
  util::DateTime * dtp = &xx.validTime();

  Log::trace() << classname() << ":initialize starting" << std::endl;

  roms_model_initialize_f90(keyConfig_,
                            xx.toFortran(),
                            &dtp);

  Log::trace() << classname() << ":initialize done" << std::endl;
  }

// ----------------------------------------------------------------------------

  void Model::step(State & xx,
                   const ModelBias &) const {
    Log::trace() << classname() << ":step starting" << std::endl;

    xx.validTime() += tstep_;
    util::DateTime * dtp = &xx.validTime();
    Log::debug() << classname() << ":step validTime = " << xx.validTime()
                                << std::endl;

    roms_model_step_f90(keyConfig_,
                        xx.toFortran(),
                        geom_->toFortran(),
                        &dtp);

    Log::trace() << classname() << ":step done" << std::endl;
  }

// ----------------------------------------------------------------------------

  void Model::finalize(State & xx) const {
    Log::trace() << classname() << ":finalize starting" << std::endl;

    roms_model_finalize_f90(keyConfig_, xx.toFortran());

    Log::trace() << classname() << ":finalize done" << std::endl;
  }

// ----------------------------------------------------------------------------

  void Model::print(std::ostream & os) const {
    os << "Model::print not implemented";
  }

// ----------------------------------------------------------------------------

}  // namespace romsjedi
