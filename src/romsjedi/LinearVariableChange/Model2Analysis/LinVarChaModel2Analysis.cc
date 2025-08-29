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
#include "oops/util/Timer.h"

#include "romsjedi/Geometry/Geometry.h"
#include "romsjedi/Increment/Increment.h"
#include "romsjedi/LinearVariableChange/Model2Analysis/LinVarChaModel2Analysis.h"
#include "romsjedi/LinearVariableChange/Model2Analysis/LinVarChaModel2AnalysisFortran.h"
#include "romsjedi/State/State.h"

namespace romsjedi {

// -----------------------------------------------------------------------------

  static LinearVariableChangeMaker<LinVarChaModel2Analysis>
         makerLinearVariableChangeLinVarModel2Analysis_("Model2Analysis");

// -----------------------------------------------------------------------------

  LinVarChaModel2Analysis::LinVarChaModel2Analysis(const State & bg,
                                                   const State & fg,
                                                   const Geometry & resol,
                                    const eckit::LocalConfiguration & conf)
    : LinearVariableChangeBase(), geom_(resol) {
  }

// -----------------------------------------------------------------------------

  LinVarChaModel2Analysis::~LinVarChaModel2Analysis() {}

// -----------------------------------------------------------------------------

  void LinVarChaModel2Analysis::multiply(const Increment & dxin,
                                         Increment & dxout) const {
    util::Timer timer(classname(), "multiply");

    oops::Log::trace() << classname() << ":multiply starting" << std::endl;

    roms_lvc_model2analysis_multiply_f90(keySelf_,
                                         geom_.toFortran(),
                                         dxin.toFortran(),
                                         dxout.toFortran());

    oops::Log::trace() << classname() << ":multiply done" << std::endl;
  }


// -----------------------------------------------------------------------------

  void LinVarChaModel2Analysis::multiplyInverse(const Increment & dxin,
                                                Increment & dxout) const {
    oops::Log::trace() << classname() << ":multiplyInverse starting"
                       << std::endl;

    roms_lvc_model2analysis_multiplyInverse_f90(keySelf_,
                                                geom_.toFortran(),
                                                dxin.toFortran(),
                                                dxout.toFortran());

    oops::Log::trace() << classname() << ":multiplyInverse done"
                       << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinVarChaModel2Analysis::multiplyAD(const Increment & dxin,
                                           Increment & dxout) const {
    util::Timer timer(classname(), "multiplyAD");

    oops::Log::trace() << classname() << ":multiplyAD starting"
                       << std::endl;

    roms_lvc_model2analysis_multiplyAD_f90(keySelf_,
                                           geom_.toFortran(),
                                           dxin.toFortran(),
                                           dxout.toFortran());

    oops::Log::trace() << classname() << ":multiplyAD done"
                       << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinVarChaModel2Analysis::multiplyInverseAD(const Increment &dxin,
                                                  Increment & dxout) const {
    oops::Log::trace() << classname() << ":multiplyInverseAD starting"
                       << std::endl;

    roms_lvc_model2analysis_multiplyInverseAD_f90(keySelf_,
                                                  geom_.toFortran(),
                                                  dxin.toFortran(),
                                                  dxout.toFortran());

    oops::Log::trace() << classname() << ":multiplyInverseAD done"
                       << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinVarChaModel2Analysis::print(std::ostream & os) const {
    os << classname() << " Linear Variable Change";
  }

// -----------------------------------------------------------------------------

}  // namespace romsjedi
