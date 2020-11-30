/*
 * (C) Copyright 2019-2020 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMS_MODEL_MODEL_H_
#define ROMS_MODEL_MODEL_H_

#include <memory>
#include <ostream>

#include "oops/util/Duration.h"
#include "oops/base/ModelBase.h"
#include "oops/base/Variables.h"
#include "oops/util/ObjectCounter.h"

// forward declarations
namespace roms {
  class Geometry;
  class ModelAuxControl;
  struct Traits;
}

// ----------------------------------------------------------------------------

namespace roms {

  // Model class
  class Model : public oops::ModelBase<Traits>,
                private util::ObjectCounter<Model>
  {
   public:
    // constructors / destructor
    Model(const Geometry &, const eckit::Configuration &);
    ~Model();

    // model stages
    void initialize(State &) const;
    void step(State &, const ModelAuxControl &) const;
    void finalize(State &) const;

    // accessors
    const util::Duration & timeResolution() const { return tstep_;}
    const oops::Variables & variables() const { return vars_; }

   private:
    void print(std::ostream &) const;

    const std::unique_ptr<Geometry> geom_;
    util::Duration tstep_;
    const oops::Variables vars_;
  };

}  // namespace roms
#endif  // ROMS_MODEL_MODEL_H_
