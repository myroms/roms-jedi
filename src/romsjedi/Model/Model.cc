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

#include "romsjedi/Geometry/Geometry.h"
#include "romsjedi/Model/Model.h"
#include "romsjedi/Model/ModelFortran.h"
#include "romsjedi/Model/ModelParameters.h"
#include "romsjedi/ModelBias/ModelBias.h"
#include "romsjedi/State/State.h"

using oops::Log;

namespace romsjedi {

// ----------------------------------------------------------------------------

  NLroms::NLroms(const Geometry & geom,
                 const eckit::Configuration & config)
    : geom_(geom),
      keyConfig_(0),
      tstep_(0),
      vars_(config, "model variables")
  {
    Log::trace() << classname() << ":NLroms starting" << std::endl;

    ModelParameters params;
    params.deserialize(config);
    tstep_ = util::Duration(config.getString("tstep"));

    Log::debug() << classname() << ":NLroms variables: " << vars_ << std::endl;
    Log::debug() << classname() << ":NLroms Time Step = "
                                << tstep_.toSeconds() << std::endl;

    roms_model_create_f90(config,
                          geom_.toFortran(),
                          keyConfig_);

    oops::Log::trace() << classname() << ":NLroms done" << std::endl;
  }

// ----------------------------------------------------------------------------

  NLroms::~NLroms() {
  Log::trace() << classname() << ":~NLroms starting" << std::endl;

  roms_model_delete_f90(keyConfig_);

  Log::trace() << classname() << ":~NLroms done" << std::endl;
  }

// ----------------------------------------------------------------------------

  void NLroms::initialize(State & xx) const {
  util::DateTime * dtp = &xx.validTime();

  Log::trace() << classname() << ":initialize starting" << std::endl;

  roms_model_initialize_f90(keyConfig_,
                            xx.toFortran(),
                            geom_.toFortran(),
                            &dtp);

  Log::trace() << classname() << ":initialize done" << std::endl;
  }

// ----------------------------------------------------------------------------

  void NLroms::step(State & xx,
                   const ModelBias &) const {
    Log::trace() << classname() << ":step starting" << std::endl;

    xx.validTime() += tstep_;
    util::DateTime * dtp = &xx.validTime();
    Log::debug() << classname() << ":step validTime = " << xx.validTime()
                                << std::endl;

    roms_model_step_f90(keyConfig_,
                        xx.toFortran(),
                        geom_.toFortran(),
                        &dtp);

    Log::trace() << classname() << ":step done" << std::endl;
  }

// ----------------------------------------------------------------------------

  void NLroms::finalize(State & xx) const {
    Log::trace() << classname() << ":finalize starting" << std::endl;

    roms_model_finalize_f90(keyConfig_, xx.toFortran());

    Log::trace() << classname() << ":finalize done" << std::endl;
  }

// ----------------------------------------------------------------------------

  void NLroms::print(std::ostream & os) const {
    os << "NLroms::print not implemented";
  }

// ----------------------------------------------------------------------------

}  // namespace romsjedi
