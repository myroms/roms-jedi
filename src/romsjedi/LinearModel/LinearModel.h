/*
 * (C) Copyright 2017-2025 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 *
 *!
 * \brief   **LinearModel** C++ Class to initialize, run, and finalize TLROMS
 *          and ADROMS
 *
 * \details These C++ functions creates/destroy, initialize, step, and finalize
 *          ROMS tangent linear and adjoint kernel objects to run a particular
 *          JEDI application.
 *
 * \author  Hernan G. Arango (Rutgers University)
 * \date    October 2021
 */

#pragma once

#include <map>
#include <ostream>
#include <string>
#include <vector>

#include "oops/util/DateTime.h"
#include "oops/util/Duration.h"
#include "oops/util/ObjectCounter.h"
#include "oops/util/Printable.h"

#include "romsjedi/Geometry/Geometry.h"
#include "romsjedi/Increment/Increment.h"
#include "romsjedi/ModelBias/ModelBias.h"
#include "romsjedi/ModelBias/ModelBiasIncrement.h"
#include "romsjedi/State/State.h"


// Forward declarations

namespace eckit {
  class Configuration;
}

namespace romsjedi {

// -----------------------------------------------------------------------------

  // ROMS Linear Model (tangent linear and Adjoint) definition.

  class LMroms : public util::Printable,
                 private util::ObjectCounter<LMroms> {
   public:
    static const std::string classname() {return "romsjedi::LMROMS";}
    static std::vector<std::string> names() {return {"LMROMS"};}

  // Constructor/destructor

    LMroms(const Geometry &, const eckit::Configuration &);
    ~LMroms();

  // Set the trajectory

    void setTrajectory(const State &, State &, const ModelBias &);

  // Run tangent linear and its adjoint

    void initializeTL(Increment &) const;
    void stepTL(Increment &, const ModelBiasIncrement &) const;
    void finalizeTL(Increment &) const;

    void initializeAD(Increment &) const;
    void stepAD(Increment &, ModelBiasIncrement &) const;
    void finalizeAD(Increment &) const;

  // Accessor functions

    const util::Duration & timeResolution() const {return tstep_;}
    const util::Duration & stepTrajectory() const {return steptraj_;}

   private:
    void print(std::ostream &) const;
    typedef std::map< util::DateTime, int >::iterator trajIter;
    typedef std::map< util::DateTime, int >::const_iterator trajICst;

  // Data

    const Geometry & geom_;
    F90flds keyFlds_;
    F90model keySelf_;
    util::Duration tstep_;
    util::Duration steptraj_;
    std::map< util::DateTime, F90traj> trajmap_;
  };

// -----------------------------------------------------------------------------

}  // namespace romsjedi
