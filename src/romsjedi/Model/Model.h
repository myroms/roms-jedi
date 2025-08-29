/*
 * (C) Copyright 2019-2025 UCAR
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
#include <vector>

#include "oops/base/Variables.h"
#include "oops/util/Duration.h"
#include "oops/util/ObjectCounter.h"

#include "romsjedi/Geometry/Geometry.h"

// Forward declarations

namespace romsjedi {
  class ModelBias;
  class State;
}

// ----------------------------------------------------------------------------

namespace romsjedi {

  // ROMS Nonlinear Model Class

  class NLroms : public util::Printable,
                 private util::ObjectCounter<NLroms> {
   public:
    static const std::string classname() {return "romsjedi::NLROMS";}
    static std::vector<std::string> names() {return {"NLROMS"};}

    // Constructors / Destructor

    NLroms(const Geometry &, const eckit::Configuration &);
    ~NLroms();

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
    const Geometry & geom_;
    const oops::Variables vars_;
  };

}  // namespace romsjedi
#endif  // ROMSJEDI_MODEL_MODEL_H_
