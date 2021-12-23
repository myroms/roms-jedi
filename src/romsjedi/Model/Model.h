/*
 * (C) Copyright 2019-2021 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 *
 *!
 * \brief   **Model**  C++ class to initialize, run, and finalize NLROMS
 *
 * \details These C++ functions creates/destroy, initialize, step, and finalize
 *          ROMS NLM kernel objects to run a particular JEDI application.
 *
 * \author  Hernan G. Arango (Rutgers University)
 * \date    September 2021
 */

#ifndef ROMSJEDI_MODEL_MODEL_H_
#define ROMSJEDI_MODEL_MODEL_H_

#include <memory>
#include <ostream>
#include <string>

#include "oops/util/Duration.h"
#include "oops/interface/ModelBase.h"
#include "oops/base/Variables.h"
#include "oops/util/ObjectCounter.h"
#include "oops/util/parameters/Parameters.h"
#include "oops/util/parameters/RequiredParameter.h"

// Forward declarations

namespace romsjedi {
  class Geometry;
  class ModelAuxControl;
  struct Traits;
}

// ----------------------------------------------------------------------------

namespace romsjedi {

  /// Model Parameters Class. The property 'name' is already part of the
  /// default schema.

  class ModelParameters : public oops::ModelParametersBase {
    OOPS_CONCRETE_PARAMETERS(ModelParameters, ModelParametersBase)

   public:
    oops::RequiredParameter<oops::Variables> vars{
      "model variables",
      "Model State variables to process",
      this};
    oops::RequiredParameter<util::Duration> tstep{
      "tstep",
      "Model time step",
      this};
    oops::RequiredParameter<util::Duration> SimulationLength{
      "simulation length",
      "Model simulation length period",
      this};
  };

  // ROMS NLM Model Class

  class Model : public oops::interface::ModelBase<Traits>,
                private util::ObjectCounter<Model> {
   public:
    typedef ModelParameters Parameters_;

    static const std::string classname() {return "romsjedi::Model";}

    // Constructors / Destructor

    Model(const Geometry &, const ModelParameters &);
    ~Model();

    // Model stages: Initialze, Step, and Finalize

    void initialize(State &) const;
    void step(State &, const ModelBias &) const;
    void finalize(State &) const;

    // Utilities

    const util::Duration & timeResolution() const { return tstep_;}
    const oops::Variables & variables() const { return vars_; }

   private:
    void print(std::ostream &) const;
    int keyConfig_;
    util::Duration tstep_;
    std::unique_ptr<const Geometry> geom_;
    const oops::Variables vars_;
  };

}  // namespace romsjedi
#endif  // ROMSJEDI_MODEL_MODEL_H_
