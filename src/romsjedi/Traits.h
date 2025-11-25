/*
 * (C) Copyright 2019-2025 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMSJEDI_TRAITS_H_
#define ROMSJEDI_TRAITS_H_

#include <string>

#include "oops/generic/UnstructuredInterpolator.h"
#include "ufo/obslocalization/ObsLocalization.h"

#include "romsjedi/ErrorCovariance/ErrorCovariance.h"
#include "romsjedi/Geometry/Geometry.h"
#include "romsjedi/GeometryIterator/GeometryIterator.h"
#include "romsjedi/Increment/Increment.h"
#include "romsjedi/LinearModel/LinearModel.h"
#include "romsjedi/LinearVariableChange/LinearVariableChange.h"
#include "romsjedi/Model/Model.h"
#include "romsjedi/ModelBias/ModelBias.h"
#include "romsjedi/ModelBias/ModelBiasCovariance.h"
#include "romsjedi/ModelBias/ModelBiasIncrement.h"
#include "romsjedi/ModelData/ModelData.h"
#include "romsjedi/NormGradient/NormGradient.h"
#include "romsjedi/State/State.h"
#include "romsjedi/VariableChange/VariableChange.h"

namespace romsjedi {

  struct Traits{
    static std::string name() {return "ROMSJEDI";}
    static std::string nameCovar() {return "romsjedi-ID";}

    // Interfaces that roms has to implement
    // ----------------------------------------------------------

    typedef oops::UnstructuredInterpolator LocalInterpolator;
    typedef ufo::ObsLocalization<GeometryIterator>   ObsLocalization;

    typedef romsjedi::ErrorCovariance      Covariance;
    typedef romsjedi::Geometry             Geometry;
    typedef romsjedi::GeometryIterator     GeometryIterator;
    typedef romsjedi::Increment            Increment;
    typedef romsjedi::LMroms               LinearModel;
    typedef romsjedi::LinearVariableChange LinearVariableChange;
    typedef romsjedi::NLroms               Model;
    typedef romsjedi::ModelBias            ModelAuxControl;
    typedef romsjedi::ModelBiasCovariance  ModelAuxCovariance;
    typedef romsjedi::ModelBiasIncrement   ModelAuxIncrement;
    typedef romsjedi::ModelData            ModelData;
    typedef romsjedi::NormGradient         NormGradient;
    typedef romsjedi::State                State;
    typedef romsjedi::VariableChange       VariableChange;
  };

}  // namespace romsjedi

#endif  // ROMSJEDI_TRAITS_H_
