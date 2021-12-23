/*
 * (C) Copyright 2019-2020 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMSJEDI_MODELBIAS_MODELBIASCOVARIANCE_H_
#define ROMSJEDI_MODELBIAS_MODELBIASCOVARIANCE_H_

#include <ostream>
#include <string>

#include "eckit/config/LocalConfiguration.h"
#include "eckit/memory/NonCopyable.h"
#include "oops/util/ObjectCounter.h"
#include "oops/util/Printable.h"

// Forward declarations

namespace romsjedi {
  class Geometry;
  class ModelBias;
  class ModelBiasIncrement;
}

// -----------------------------------------------------------------------------

namespace romsjedi {

  class ModelBiasCovariance : public util::Printable,
                              private eckit::NonCopyable,
                              private util::ObjectCounter<ModelBiasCovariance> {
   public:
    static const std::string classname()
                                   {return "romsjedi::ModelBiasCovariance";}

/// Constructor, destructor

    ModelBiasCovariance(const eckit::Configuration & conf,
                        const Geometry &): conf_(conf) {}
    ~ModelBiasCovariance() {}

/// Linear algebra operators

    void linearize(const ModelBias &,
                   const Geometry &) {}
    void multiply(const ModelBiasIncrement &,
                  ModelBiasIncrement &) const {}
    void inverseMultiply(const ModelBiasIncrement &,
                         ModelBiasIncrement &) const {}
    void randomize(ModelBiasIncrement &) const {}

    const eckit::Configuration & config() const {return conf_;}

   private:
    void print(std::ostream & os) const {}
    const eckit::LocalConfiguration conf_;
  };

// -----------------------------------------------------------------------------

}  // namespace romsjedi

#endif  // ROMSJEDI_MODELBIAS_MODELBIASCOVARIANCE_H_

