/*
 * (C) Copyright 2019-2021 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMSJEDI_TRAITS_H_
#define ROMSJEDI_TRAITS_H_

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

#include "romsjedi/AnalyticInit/AnalyticInit.h"
#include "romsjedi/Geometry/Geometry.h"
#include "romsjedi/GeometryIterator/GeometryIterator.h"
#include "romsjedi/GetValues/GetValues.h"
#include "romsjedi/GetValues/LinearGetValues.h"
#include "romsjedi/Increment/Increment.h"
#include "romsjedi/State/State.h"

// #include "romsjedi/Covariance/Covariance.h"
// #include "romsjedi/ModelAux/ModelAuxControl.h"
// #include "romsjedi/ModelAux/ModelAuxCovariance.h"
// #include "romsjedi/ModelAux/ModelAuxIncrement.h"

namespace romsjedi {

  struct Traits{
    static std::string name() {return "ROMSJEDI";}
    static std::string nameCovar() {return "romsjediCovar";}
    static std::string nameCovar4D() {return "romsjediCovar";}

    // Interfaces that roms has to implement
    // ---------------------------------------------------

    typedef romsjedi::Geometry            Geometry;
    typedef romsjedi::GeometryIterator    GeometryIterator;
    typedef romsjedi::GetValues           GetValues;
    typedef romsjedi::Increment           Increment;
    typedef romsjedi::LinearGetValues     LinearGetValues;
    typedef romsjedi::State               State;

//  typedef romsjedi::Covariance          Covariance;
//  typedef romsjedi::ModelAuxControl     ModelAuxControl;
//  typedef romsjedi::ModelAuxCovariance  ModelAuxCovariance;
//  typedef romsjedi::ModelAuxIncrement   ModelAuxIncrement;
  };

  struct ObsTraits {
    static std::string name()
                {return "UFO and IODA obs with ROMSJEDI::AnalyticInit";}

    typedef romsjedi::AnalyticInit    AnalyticInit;
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

}  // namespace romsjedi

#endif  // ROMSJEDI_TRAITS_H_
