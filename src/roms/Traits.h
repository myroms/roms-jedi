/*
 * (C) Copyright 2019-2021 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMS_TRAITS_H_
#define ROMS_TRAITS_H_

#include <string>

#include "roms/Geometry/Geometry.h"
#include "roms/GeometryIterator/GeometryIterator.h"
#include "roms/Increment/Increment.h"
#include "roms/State/State.h"

// #include "roms/Covariance/Covariance.h"
// #include "roms/GetValues/GetValues.h"
// #include "roms/GetValues/LinearGetValues.h"
// #include "roms/ModelAux/ModelAuxControl.h"
// #include "roms/ModelAux/ModelAuxCovariance.h"
// #include "roms/ModelAux/ModelAuxIncrement.h"

namespace roms {

  struct Traits{
    static std::string name() {return "ROMS";}
    static std::string nameCovar() {return "romsCovar";}
    static std::string nameCovar4D() {return "romsCovar";}

    // Interfaces that roms has to implement
    // ---------------------------------------------------

    typedef roms::Geometry            Geometry;
    typedef roms::GeometryIterator    GeometryIterator;
    typedef roms::State               State;
    typedef roms::Increment           Increment;

//  typedef roms::Covariance          Covariance;
//  typedef roms::GetValues           GetValues;
//  typedef roms::LinearGetValues     LinearGetValues;
//  typedef roms::ModelAuxControl     ModelAuxControl;
//  typedef roms::ModelAuxCovariance  ModelAuxCovariance;
//  typedef roms::ModelAuxIncrement   ModelAuxIncrement;
  };
}  // namespace roms

#endif  // ROMS_TRAITS_H_
