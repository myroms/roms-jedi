/*
 * (C) Copyright 2019-2020 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#include "roms/ModelAux/ModelAuxControl.h"
#include "roms/ModelAux/ModelAuxIncrement.h"

#include "oops/util/abor1_cpp.h"

namespace roms {

// ----------------------------------------------------------------------------

  ModelAuxControl::ModelAuxControl(const Geometry &,
                                   const eckit::Configuration &) {
    util::abor1_cpp(
      "ModelAuxControl::ModelAuxControl() needs to be implemented.",
      __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  ModelAuxControl::ModelAuxControl(const Geometry &,
                                   const ModelAuxControl &) {
    util::abor1_cpp(
      "ModelAuxControl::ModelAuxControl() needs to be implemented.",
      __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  ModelAuxControl::ModelAuxControl(const ModelAuxControl &, const bool) {
    util::abor1_cpp(
      "ModelAuxControl::ModelAuxControl() needs to be implemented.",
      __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  ModelAuxControl::~ModelAuxControl() {
    util::abor1_cpp(
      "ModelAuxControl::~ModelAuxControl() needs to be implemented.",
      __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  ModelAuxControl & ModelAuxControl::operator+=(const ModelAuxIncrement & inc) {
    util::abor1_cpp(
      "ModelAuxControl::operator+=() needs to be implemented.",
      __FILE__, __LINE__);
    return *this;
  }
// ----------------------------------------------------------------------------

  void ModelAuxControl::print(std::ostream & os) const {
    os << "(TODO, print diagnostic info about the ModelAuxControl here)"
       << std::endl;
    util::abor1_cpp("ModelAuxControl::print() needs to be implemented.",
                    __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

}  // namespace roms
