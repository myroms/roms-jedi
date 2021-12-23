/*
 * (C) Copyright 2017-2021 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMSJEDI_ERRORCOVARIANCE_ERRORCOVARIANCE_H_
#define ROMSJEDI_ERRORCOVARIANCE_ERRORCOVARIANCE_H_

#include <memory>
#include <ostream>
#include <string>

#include <boost/scoped_ptr.hpp>
#include "eckit/config/Configuration.h"
#include "eckit/memory/NonCopyable.h"
#include "oops/util/DateTime.h"
#include "oops/util/ObjectCounter.h"
#include "oops/util/Printable.h"

#include "romsjedi/Geometry/Geometry.h"

// Forward declarations

namespace oops {
  class Variables;
}

namespace romsjedi {
  class Increment;
  class State;

// -----------------------------------------------------------------------------

  class ErrorCovariance : public util::Printable,
                          private eckit::NonCopyable,
                          private util::ObjectCounter<ErrorCovariance> {
   public:
    static const std::string classname() {return "romsjedi::ErrorCovariance";}

    ErrorCovariance(const Geometry &,
                    const oops::Variables &,
                    const eckit::Configuration &,
                    const State &, const State &);
    ~ErrorCovariance();

    void linearize(const State &,
                   const Geometry &);
    void multiply(const Increment &,
                  Increment &) const;
    void inverseMultiply(const Increment &,
                         Increment &) const;
    void randomize(Increment &) const;

   private:
    void print(std::ostream &) const;
    boost::scoped_ptr<const Geometry> geom_;
  };

// -----------------------------------------------------------------------------

}  // namespace romsjedi

#endif  // ROMSJEDI_ERRORCOVARIANCE_ERRORCOVARIANCE_H_
