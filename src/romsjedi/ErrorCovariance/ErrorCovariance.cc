/*
 * (C) Copyright 2017-2025 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 *
 *!
 * \brief   **ErrorCovariance Class** C++ ROMS-JEDI interface
 *
 * \details It implements the Error Covariance methods as the identity matrix.
 *          However, rhe error covariance is modeled using BUMP factory method
 *          in SABER.
 *
 * \author  Hernan G. Arango (Rutgers University)
 * \date    November 2021
 */

#include <cmath>
#include <ostream>

#include "eckit/config/Configuration.h"
#include "oops/base/Variables.h"
#include "oops/util/Logger.h"

#include "romsjedi/ErrorCovariance/ErrorCovariance.h"
#include "romsjedi/Geometry/Geometry.h"
#include "romsjedi/Increment/Increment.h"
#include "romsjedi/State/State.h"

// -----------------------------------------------------------------------------
namespace romsjedi {
// -----------------------------------------------------------------------------

ErrorCovariance::ErrorCovariance(const Geometry & geom,
                                 const oops::Variables &,
                                 const eckit::Configuration & conf,
                                 const State &,
                                 const State &) {
  oops::Log::trace() << "ErrorCovariance created" << std::endl;
}

// -----------------------------------------------------------------------------

ErrorCovariance::~ErrorCovariance() {
  oops::Log::trace() << "ErrorCovariance destructed" << std::endl;
}

// -----------------------------------------------------------------------------

void ErrorCovariance::multiply(const Increment & dxin,
                               Increment & dxout) const {
  dxout = dxin;  // Identity Matrix
  oops::Log::trace() << "ErrorCovariance multiply" << std::endl;
}

// -----------------------------------------------------------------------------

void ErrorCovariance::inverseMultiply(const Increment & dxin,
                                      Increment & dxout) const {
  dxout = dxin;  // Identity Matrix
  oops::Log::trace() << "ErrorCovariance inverse multiply" << std::endl;
}

// -----------------------------------------------------------------------------

void ErrorCovariance::randomize(Increment & dx) const {
  dx.random();
  oops::Log::trace() << "ErrorCovariance randomize" << std::endl;
}

// ----------------------------------------------------------------------------

  void ErrorCovariance::print(std::ostream & os) const {
    os << "ErrorCovariance::print not implemented";
  }

// -----------------------------------------------------------------------------

}  // namespace romsjedi
