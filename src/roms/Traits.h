/*
 * (C) Copyright 2019-2020 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMS_TRAITS_H_
#define ROMS_TRAITS_H_

#include <string>

// TODO(template_impl) #include "roms/Covariance/Covariance.h"
#include "roms/Geometry/Geometry.h"
// TODO(template_impl) #include "roms/GeometryIterator/GeometryIterator.h"
// TODO(template_impl) #include "roms/GetValues/GetValues.h"
// TODO(template_impl) #include "roms/GetValues/LinearGetValues.h"
// TODO(template_impl) #include "roms/Increment/Increment.h"
// TODO(template_impl) #include "roms/ModelAux/ModelAuxControl.h"
// TODO(template_impl) #include "roms/ModelAux/ModelAuxCovariance.h"
// TODO(template_impl) #include "roms/ModelAux/ModelAuxIncrement.h"
// TODO(template_impl) #include "roms/State/State.h"

namespace roms {

  struct Traits{
    static std::string name() {return "roms";}
    static std::string nameCovar() {return "romsCovar";}
    static std::string nameCovar4D() {return "romsCovar";}

    // Interfaces that roms has to implement
    // ---------------------------------------------------
// TODO(template_impl) typedef roms::Covariance          Covariance;
    typedef roms::Geometry            Geometry;
// TODO(template_impl) typedef roms::GeometryIterator    GeometryIterator;
// TODO(template_impl) typedef roms::GetValues           GetValues;
// TODO(template_impl) typedef roms::Increment           Increment;
// TODO(template_impl) typedef roms::LinearGetValues     LinearGetValues;
// TODO(template_impl) typedef roms::ModelAuxControl     ModelAuxControl;
// TODO(template_impl) typedef roms::ModelAuxCovariance  ModelAuxCovariance;
// TODO(template_impl) typedef roms::ModelAuxIncrement   ModelAuxIncrement;
// TODO(template_impl) typedef roms::State               State;
  };
}  // namespace roms

#endif  // ROMS_TRAITS_H_
