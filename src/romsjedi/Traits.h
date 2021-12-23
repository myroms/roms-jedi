/*
 * (C) Copyright 2019-2021 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMSJEDI_TRAITS_H_
#define ROMSJEDI_TRAITS_H_

#include <string>

#include "romsjedi/ErrorCovariance/ErrorCovariance.h"
#include "romsjedi/Geometry/Geometry.h"
#include "romsjedi/GeometryIterator/GeometryIterator.h"
#include "romsjedi/GetValues/GetValues.h"
#include "romsjedi/GetValues/LinearGetValues.h"
#include "romsjedi/Increment/Increment.h"
#include "romsjedi/LinearVariableChange/LinearVariableChange.h"
#include "romsjedi/ModelBias/ModelBias.h"
#include "romsjedi/ModelBias/ModelBiasCovariance.h"
#include "romsjedi/ModelBias/ModelBiasIncrement.h"
#include "romsjedi/State/State.h"
#include "romsjedi/VariableChange/VariableChange.h"

namespace romsjedi {

  struct Traits{
    static std::string name() {return "ROMSJEDI";}
    static std::string nameCovar() {return "romsjedi-ID";}

    // Interfaces that roms has to implement
    // ----------------------------------------------------------

    typedef romsjedi::ErrorCovariance      Covariance;
    typedef romsjedi::Geometry             Geometry;
    typedef romsjedi::GeometryIterator     GeometryIterator;
    typedef romsjedi::GetValues            GetValues;
    typedef romsjedi::Increment            Increment;
    typedef romsjedi::LinearGetValues      LinearGetValues;
    typedef romsjedi::LinearVariableChange LinearVariableChange;
    typedef romsjedi::ModelBias            ModelAuxControl;
    typedef romsjedi::ModelBiasCovariance  ModelAuxCovariance;
    typedef romsjedi::ModelBiasIncrement   ModelAuxIncrement;
    typedef romsjedi::State                State;
    typedef romsjedi::VariableChange       VariableChange;
  };

}  // namespace romsjedi

#endif  // ROMSJEDI_TRAITS_H_
