/*
 * (C) Copyright 2021-2021  UCAR.
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#include <ostream>
#include <string>

#include "oops/util/abor1_cpp.h"
#include "oops/util/Logger.h"

#include "romsjedi/Geometry/Geometry.h"
#include "romsjedi/State/State.h"
#include "romsjedi/Traits.h"
#include "romsjedi/VariableChange/Model2GeoVaLs/VarChaModel2GeoVaLs.h"
#include "romsjedi/VariableChange/Model2GeoVaLs/VarChaModel2GeoVaLsFortran.h"

namespace romsjedi {

// -----------------------------------------------------------------------------

  static VariableChangeMaker<VarChaModel2GeoVaLs>
            makerVariableChangeVarChaModel2GeoVaLs_("VarChaModel2GeoVaLs");

  static VariableChangeMaker<VarChaModel2GeoVaLs>
            makerVariableChangeDefault_("default");

// -----------------------------------------------------------------------------

  VarChaModel2GeoVaLs::VarChaModel2GeoVaLs(const Geometry & geom,
                                           const eckit::Configuration & conf)
    : geom_(new Geometry(geom)) {
  }

// -----------------------------------------------------------------------------

  VarChaModel2GeoVaLs::~VarChaModel2GeoVaLs() {}

// -----------------------------------------------------------------------------

  void VarChaModel2GeoVaLs::changeVar(const State & xin,
                                      State & xout) const {
    oops::Log::trace() << classname() << " changeVar start" << std::endl;
    roms_vc_model2geovals_changevar_f90(keySelf_,
                                        geom_->toFortran(),
                                        xin.toFortran(),
                                        xout.toFortran());
    oops::Log::trace() << classname() << " changeVar done" << std::endl;
  }

// -----------------------------------------------------------------------------

  void VarChaModel2GeoVaLs::changeVarInverse(const State & xin,
                                             State & xout) const {
    util::Timer timer(classname(), "changeVarInverse");
    oops::Log::trace() << classname() << " changeVarInverse starting"
                                      << std::endl;
    xout = xin;
    xout.validTime() = xin.validTime();
    oops::Log::trace() << classname() << " changeVarInverse done"
                                      << std::endl;
  }

// -----------------------------------------------------------------------------

}  // namespace romsjedi
