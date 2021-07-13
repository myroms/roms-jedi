/*
 * (C) Copyright 2019-2021 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMS_TRAITS_H_
#define ROMS_TRAITS_H_

#include <string>

#include "ioda/ObsSpace.h"
#include "ioda/ObsVector.h"

#include "ufo/GeoVaLs.h"
#include "ufo/LinearObsOperator.h"
#include "ufo/Locations.h"
#include "ufo/ObsBias.h"
#include "ufo/ObsBiasCovariance.h"
#include "ufo/ObsBiasIncrement.h"
#include "ufo/ObsDiagnostics.h"
#include "ufo/ObsOperator.h"

#include "roms/AnalyticInit/AnalyticInit.h"
#include "roms/Geometry/Geometry.h"
#include "roms/GeometryIterator/GeometryIterator.h"
#include "roms/GetValues/GetValues.h"
#include "roms/GetValues/LinearGetValues.h"
#include "roms/Increment/Increment.h"
#include "roms/State/State.h"

// #include "roms/Covariance/Covariance.h"
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
    typedef roms::GetValues           GetValues;
    typedef roms::Increment           Increment;
    typedef roms::LinearGetValues     LinearGetValues;
    typedef roms::State               State;

//  typedef roms::Covariance          Covariance;
//  typedef roms::ModelAuxControl     ModelAuxControl;
//  typedef roms::ModelAuxCovariance  ModelAuxCovariance;
//  typedef roms::ModelAuxIncrement   ModelAuxIncrement;
  };

  struct ObsTraits {
    static std::string name()
                {return "UFO and IODA obs with ROMS::AnalyticInit";}

    typedef roms::AnalyticInit        AnalyticInit;
    typedef ufo::GeoVaLs              GeoVaLs;
    typedef ufo::LinearObsOperator    LinearObsOperator;
    typedef ufo::Locations            Locations;
    typedef ufo::ObsBias              ObsAuxControl;
    typedef ufo::ObsBiasCovariance    ObsAuxCovariance;
    typedef ufo::ObsBiasIncrement     ObsAuxIncrement;
    typedef ufo::ObsDiagnostics       ObsDiagnostics;
    typedef ufo::ObsOperator          ObsOperator;

    typedef ioda::ObsSpace            ObsSpace;
    typedef ioda::ObsVector           ObsVector;
    template <typename DATA> using ObsDataVector = ioda::ObsDataVector<DATA>;
  };

}  // namespace roms

#endif  // ROMS_TRAITS_H_
