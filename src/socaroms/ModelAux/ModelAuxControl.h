/*
 * (C) Copyright 2019-2020 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef SOCAROMS_MODELAUX_MODELAUXCONTROL_H_
#define SOCAROMS_MODELAUX_MODELAUXCONTROL_H_

#include <ostream>
#include <string>

#include "oops/util/ObjectCounter.h"
#include "oops/util/Printable.h"

// forward declarations
namespace eckit {
  class Configuration;
}
namespace socaroms {
  class Geometry;
  class ModelAuxIncrement;
}

//-----------------------------------------------------------------------------

namespace socaroms {

  // ModelAuxControl class
  class ModelAuxControl : public util::Printable,
                          private util::ObjectCounter<ModelAuxControl> {
   public:
    static const std::string classname() {return "socaroms::ModelAuxControl";}

    // constructors / destructor
    ModelAuxControl(const Geometry &, const eckit::Configuration &);
    ModelAuxControl(const Geometry &, const ModelAuxControl &);
    ModelAuxControl(const ModelAuxControl &, const bool);
    ~ModelAuxControl();

    // math operators
    ModelAuxControl & operator +=(const ModelAuxIncrement &);

   private:
    void print(std::ostream & os) const;
  };
}  // namespace socaroms
#endif  // SOCAROMS_MODELAUX_MODELAUXCONTROL_H_
