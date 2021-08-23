/*
 * (C) Copyright 2019-2020 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMSJEDI_COVARIANCE_COVARIANCE_H_
#define ROMSJEDI_COVARIANCE_COVARIANCE_H_

#include <ostream>
#include <string>

#include "oops/util/ObjectCounter.h"
#include "oops/util/Printable.h"

// Forward declarations

namespace eckit {
  class Configuration;
}
namespace oops {
  class Variables;
}
namespace romsjedi {
  class Geometry;
  class Increment;
  class State;
}

// ----------------------------------------------------------------------------

namespace romsjedi {

  // Fields class
  class Covariance : public util::Printable,
                     private util::ObjectCounter<Covariance> {
   public:
    static const std::string classname() {return "roms::Covariance";}

    // constructors/destructors
    Covariance(const Geometry &, const oops::Variables &,
                    const eckit::Configuration &,
                    const State &, const State &);
    ~Covariance();

    // math routines
    void inverseMultiply(const Increment &, Increment &) const;
    void multiply(const Increment &, Increment &) const;
    void randomize(Increment &) const;

   private:
    void print(std::ostream &) const;
  };

}  // namespace romsjedi

#endif  // ROMSJEDI_COVARIANCE_COVARIANCE_H_
