/*
 * (C) Copyright 2019-2025 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 *
 *!
 * \brief   Model error Class for ROMS
 *
 * \details This class is used to manipulate parameters of the model that
 *          can be estimated in the assimilation. This includes model bias
 *          for example, but could be used for other parameters to be
 *          estimated. It is sometimes referred to as augmented state or
 *          augmented control variable in the literature. The augmented
 *          state is understood here as an augmented 4D state.
 *
 * \author  Hernan G. Arango (Rutgers University)
 * \date    September 2021
 */

#ifndef ROMSJEDI_MODELBIAS_MODELBIAS_H_
#define ROMSJEDI_MODELBIAS_MODELBIAS_H_

#include <iostream>
#include <string>

#include "eckit/memory/NonCopyable.h"
#include "oops/util/ObjectCounter.h"
#include "oops/util/Printable.h"

// Forward declarations

namespace eckit {
  class Configuration;
}

namespace romsjedi {
  class Geometry;
  class ModelBiasIncrement;
}

// -----------------------------------------------------------------------------

namespace romsjedi {

  // Model Error for ROMS

  class ModelBias : public util::Printable,
                    private eckit::NonCopyable,
                    private util::ObjectCounter<ModelBias> {
   public:
    static const std::string classname() {return "romsjedi::ModelBias";}

    ModelBias(const Geometry &, const eckit::Configuration &) {}
    ModelBias(const Geometry &, const ModelBias &) {}
    ModelBias(const ModelBias &, const bool) {}
    ~ModelBias() {}

    ModelBias & operator+=(const ModelBiasIncrement &) {return *this;}

/// I/O and diagnostics

    void read(const eckit::Configuration &) {}
    void write(const eckit::Configuration &) const {}
    double norm() const {return 0.0;}

   private:
    void print(std::ostream & os) const {}
  };

// -----------------------------------------------------------------------------

}  // namespace romsjedi

#endif  // ROMSJEDI_MODELBIAS_MODELBIAS_H_
