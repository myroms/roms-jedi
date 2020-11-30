/*
 * (C) Copyright 2019-2020 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */
#include "roms/Traits.h"
#include "roms/Geometry/Geometry.h"
#include "roms/Model/Model.h"
#include "roms/ModelAux/ModelAuxControl.h"
#include "roms/State/State.h"

#include "oops/util/abor1_cpp.h"

namespace roms {

// ----------------------------------------------------------------------------

  static oops::ModelMaker<Traits, Model> modelmaker_("ROMS");

// ----------------------------------------------------------------------------

  Model::Model(const Geometry & geom, const eckit::Configuration & conf)
    : geom_(new Geometry(geom)), tstep_(conf.getString("tstep")),
      vars_(conf, "model variables") {
    util::abor1_cpp("Model::Model() needs to be implemented.",
                    __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  Model::~Model() {
    util::abor1_cpp("Model::~Model() needs to be implemented.",
                __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  void Model::initialize(State & xx) const {
    util::abor1_cpp("Model::initialize() needs to be implemented.",
                    __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  void Model::step(State & xx, const ModelAuxControl & xx_bias) const {
    util::abor1_cpp("Model::step() needs to be implemented.",
                    __FILE__, __LINE__);
    xx.validTime() += tstep_;
  }

// ----------------------------------------------------------------------------

  void Model::finalize(State & xx) const {
    util::abor1_cpp("Model::finalize() needs to be implemented.",
                     __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  void Model::print(std::ostream & os) const {
    os << "Geometry: "
       << "(TODO, print diagnostic info about the geometry here)"
       << std::endl;
    util::abor1_cpp("Model::print() needs to be implemented.",
                    __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

}  // namespace roms
