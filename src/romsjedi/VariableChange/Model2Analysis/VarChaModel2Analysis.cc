/*
 * (C) Copyright 2017-2025 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#include <ostream>
#include <string>

#include "eckit/config/Configuration.h"
#include "oops/util/Logger.h"
#include "oops/util/Timer.h"

#include "romsjedi/Geometry/Geometry.h"
#include "romsjedi/State/State.h"
#include "romsjedi/VariableChange/Model2Analysis/VarChaModel2Analysis.h"
#include "romsjedi/VariableChange/Model2Analysis/VarChaModel2AnalysisFortran.h"

namespace romsjedi {

// -----------------------------------------------------------------------------

  static VariableChangeMaker<VarChaModel2Analysis>
            makerVariableChangeVarChaModel2Analysis_("Model2Analysis");

// -----------------------------------------------------------------------------

  VarChaModel2Analysis::VarChaModel2Analysis(const Geometry & resol,
                                             const eckit::Configuration & conf)
    : VariableChangeBase(), geom_(resol) {
  }

// -----------------------------------------------------------------------------

  VarChaModel2Analysis::~VarChaModel2Analysis() {}

// -----------------------------------------------------------------------------

  void VarChaModel2Analysis::changeVar(const State & xin,
                                       State & xout) const {
    util::Timer timer(classname(), "Model2Analysis");

    oops::Log::trace() << classname() << ":changeVar starting"
                       << std::endl;
    oops::Log::debug() << classname() << ":changeVar Input Fields: "
                       << xin << std::endl;

    roms_vc_model2analysis_changeVar_f90(keySelf_,
                                         geom_.toFortran(),
                                         xin.toFortran(),
                                         xout.toFortran());
    xout.validTime() = xin.validTime();

    oops::Log::debug() << classname() << ":changeVar Output Fields: "
                       << xout << std::endl;
    oops::Log::trace() << classname() << ":changeVar done"
                       << std::endl;
  }

// -----------------------------------------------------------------------------

  void VarChaModel2Analysis::changeVarInverse(const State & xin,
                                              State & xout) const {
    util::Timer timer(classname(), "Model2Analysis Inverse");

    oops::Log::trace() << classname() << ":changeVarInverse starting"
                       << std::endl;
    oops::Log::debug() << classname() << ":changeVarInverse Input Fields: "
                       << xin << std::endl;

    roms_vc_model2analysis_changeVarInverse_f90(keySelf_,
                                                geom_.toFortran(),
                                                xin.toFortran(),
                                                xout.toFortran());
    xout.validTime() = xin.validTime();

    oops::Log::debug() << classname() << ":changeVarInverse Output Fields: "
                       << xout << std::endl;
    oops::Log::trace() << classname() << ":changeVarInverse done"
                       << std::endl;
  }

// -----------------------------------------------------------------------------

  void VarChaModel2Analysis::print(std::ostream & os) const {
    os << classname() << ":print Variable Change";
  }

// -----------------------------------------------------------------------------

}  // namespace romsjedi
