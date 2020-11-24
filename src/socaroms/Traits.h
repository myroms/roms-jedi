/*
 * (C) Copyright 2019-2020 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef SOCAROMS_TRAITS_H_
#define SOCAROMS_TRAITS_H_

#include <string>

// TODO(template_impl) #include "socaroms/Covariance/Covariance.h"
#include "socaroms/Geometry/Geometry.h"
// TODO(template_impl) #include "socaroms/GeometryIterator/GeometryIterator.h"
// TODO(template_impl) #include "socaroms/GetValues/GetValues.h"
// TODO(template_impl) #include "socaroms/GetValues/LinearGetValues.h"
// TODO(template_impl) #include "socaroms/Increment/Increment.h"
// TODO(template_impl) #include "socaroms/ModelAux/ModelAuxControl.h"
// TODO(template_impl) #include "socaroms/ModelAux/ModelAuxCovariance.h"
// TODO(template_impl) #include "socaroms/ModelAux/ModelAuxIncrement.h"
// TODO(template_impl) #include "socaroms/State/State.h"

namespace socaroms {

  struct Traits{
    static std::string name() {return "socaroms";}
    static std::string nameCovar() {return "socaromsCovar";}
    static std::string nameCovar4D() {return "socaromsCovar";}

    // Interfaces that socaroms has to implement
    // ---------------------------------------------------
// TODO(template_impl) typedef socaroms::Covariance          Covariance;
    typedef socaroms::Geometry            Geometry;
// TODO(template_impl) typedef socaroms::GeometryIterator    GeometryIterator;
// TODO(template_impl) typedef socaroms::GetValues           GetValues;
// TODO(template_impl) typedef socaroms::Increment           Increment;
// TODO(template_impl) typedef socaroms::LinearGetValues     LinearGetValues;
// TODO(template_impl) typedef socaroms::ModelAuxControl     ModelAuxControl;
// TODO(template_impl) typedef socaroms::ModelAuxCovariance  ModelAuxCovariance;
// TODO(template_impl) typedef socaroms::ModelAuxIncrement   ModelAuxIncrement;
// TODO(template_impl) typedef socaroms::State               State;
  };
}  // namespace socaroms

#endif  // SOCAROMS_TRAITS_H_
