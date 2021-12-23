/*
 * (C) Copyright 2019-2021 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMSJEDI_MODELBIAS_MODELBIASINCREMENT_H_
#define ROMSJEDI_MODELBIAS_MODELBIASINCREMENT_H_

#include <iostream>
#include <vector>

#include "oops/util/Printable.h"
#include "oops/util/Serializable.h"

// Forward declarations

namespace eckit {
  class Configuration;
}

namespace romsjedi {
  class Geometry;
  class ModelBias;
  class ModelBiasCovariance;
}

//-----------------------------------------------------------------------------

namespace romsjedi {

  class ModelBiasIncrement : public util::Printable,
                             public util::Serializable {
   public:
    /// Constructor, destructor

    ModelBiasIncrement(const Geometry &,
                       const eckit::Configuration &) {}
    ModelBiasIncrement(const ModelBiasIncrement &,
                       const bool) {}
    ModelBiasIncrement(const ModelBiasIncrement &,
                       const eckit::Configuration &) {}
    ~ModelBiasIncrement() {}

    /// Linear algebra operators

    void diff(const ModelBias &, const ModelBias &) {}
    void zero() {}
    ModelBiasIncrement & operator=(const
                                   ModelBiasIncrement &) {return *this;}
    ModelBiasIncrement & operator+=(const
                                    ModelBiasIncrement &) {return *this;}
    ModelBiasIncrement & operator-=(const
                                    ModelBiasIncrement &) {return *this;}
    ModelBiasIncrement & operator*=(const double) {return *this;}
    void axpy(const double, const ModelBiasIncrement &) {}
    double dot_product_with(const ModelBiasIncrement &)
                            const {return 0.0;}

    /// Serialize and deserialize

    size_t serialSize() const override {return 0;}
    void serialize(std::vector<double> &) const override {}
    void deserialize(const std::vector<double> &, size_t &) override {}

    /// I/O and diagnostics

    void read(const eckit::Configuration &) {}
    void write(const eckit::Configuration &) const {}
    double norm() const {return 0.0;}

   private:
    explicit ModelBiasIncrement(const ModelBiasCovariance &);
    void print(std::ostream & os) const {}
  };

// -----------------------------------------------------------------------------

}  // namespace romsjedi

#endif  // ROMSJEDI_MODELBIAS_MODELBIASINCREMENT_H_
