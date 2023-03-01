/*
 * (C) Copyright 2022-2023 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMSJEDI_NORMGRADIENT_NORMGRADIENT_H_
#define ROMSJEDI_NORMGRADIENT_NORMGRADIENT_H_

#include <memory>
#include <ostream>
#include <string>

#include "oops/util/ObjectCounter.h"
#include "oops/util/Printable.h"
#include "romsjedi/Geometry/Geometry.h"
#include "romsjedi/Increment/Increment.h"
#include "romsjedi/State/State.h"

namespace eckit {
  class Configuration;
}

namespace romsjedi {
  class Geometry;
  class Increment;
  class State;

// -----------------------------------------------------------------------------

class NormGradient : public util::Printable,
                    private util::ObjectCounter<NormGradient> {
 public:
  static const std::string classname() {return "romsjedi::NormGradient";}

  NormGradient(const Geometry &, const State &, const eckit::Configuration &) {}
  virtual ~NormGradient() {}

  void apply(Increment &) const {}

// Private
 private:
  void print(std::ostream & os) const
    {os << " NormGradient: print not implemented yet.";}
};

// -----------------------------------------------------------------------------

}  // namespace romsjedi

#endif  // ROMSJEDI_NORMGRADIENT_NORMGRADIENT_H_
