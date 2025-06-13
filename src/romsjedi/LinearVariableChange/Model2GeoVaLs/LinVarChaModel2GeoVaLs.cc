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
#include "romsjedi/LinearVariableChange/Model2GeoVaLs/LinVarChaModel2GeoVaLs.h"
#include "romsjedi/LinearVariableChange/Model2GeoVaLs/LinVarChaModel2GeoVaLsFortran.h"
#include "romsjedi/State/State.h"
#include "romsjedi/Traits.h"

namespace romsjedi {

  static LinearVariableChangeMaker<LinVarChaModel2GeoVaLs>
         makerLinearVariableChangeModel2GeoVaLs_("Model2GeoVaLs");

  static LinearVariableChangeMaker<LinVarChaModel2GeoVaLs>
         makerLinearVariableChangeModel2GeoVaLsDefault_("default");

// -----------------------------------------------------------------------------

  LinVarChaModel2GeoVaLs::LinVarChaModel2GeoVaLs(const State & bg,
                                                 const State & fg,
                                                 const Geometry & geom,
                                         const eckit::LocalConfiguration & conf)
    : LinearVariableChangeBase(), geom_(new Geometry(geom))
  {
    oops::Log::trace() << classname() << ":Constructor starting" << std::endl;
    roms_lvc_model2geovals_create_f90(keySelf_,
                                      geom_->toFortran(),
                                      bg.toFortran(),
                                      fg.toFortran(),
                                      conf);
    oops::Log::trace() << classname() << ":Constructor done" << std::endl;
  }

// -----------------------------------------------------------------------------

  LinVarChaModel2GeoVaLs::~LinVarChaModel2GeoVaLs() {
    oops::Log::trace() << classname() << ":Destructor starting" << std::endl;
    roms_lvc_model2geovals_delete_f90(keySelf_);
    oops::Log::trace() << classname() << ":Destructor done" << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinVarChaModel2GeoVaLs::multiply(const Increment & dxin,
                                        Increment & dxout) const {
    oops::Log::trace() << classname() << ":Multiply starting: "
                                      << dxin.validTime() << std::endl;
    roms_lvc_model2geovals_multiply_f90(keySelf_,
                                        geom_->toFortran(),
                                        dxin.toFortran(),
                                        dxout.toFortran());
    oops::Log::trace() << classname() << ":Multiply done" << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinVarChaModel2GeoVaLs::multiplyInverse(const Increment & dxin,
                                               Increment & dxout) const {
    oops::Log::trace() << classname() << ":multiplyInverse starting"
                       << std::endl;
    dxout = dxin;
    oops::Log::trace() << classname() << ":multiplyInverse done" << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinVarChaModel2GeoVaLs::multiplyAD(const Increment & dxin,
                                          Increment & dxout) const {
    oops::Log::trace() << classname() << ":multiplyAD starting: "
                                      << dxin.validTime() << std::endl;
    roms_lvc_model2geovals_multiplyAD_f90(keySelf_,
                                          geom_->toFortran(),
                                          dxin.toFortran(),
                                          dxout.toFortran());
    oops::Log::trace() << classname() << ":multiplyAD done" << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinVarChaModel2GeoVaLs::multiplyInverseAD(const Increment &dxin,
                                                 Increment & dxout) const {
    oops::Log::trace() << classname() << ":multiplyInverseAD starting"
                       << std::endl;
    dxout = dxin;
    oops::Log::trace() << classname() << ":multiplyInverseAD done" << std::endl;
  }

// -----------------------------------------------------------------------------

  void LinVarChaModel2GeoVaLs::print(std::ostream & os) const {
    os << classname() << " linear variable change";
  }

// -----------------------------------------------------------------------------

}  // namespace romsjedi
