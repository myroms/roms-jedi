/*
 * (C) Copyright 2019-2020 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMSJEDI_MODELAUX_MODELAUXINCREMENT_H_
#define ROMSJEDI_MODELAUX_MODELAUXINCREMENT_H_

#include <ostream>
#include <string>
#include <vector>

#include "oops/util/ObjectCounter.h"
#include "oops/util/Printable.h"
#include "oops/util/Serializable.h"

// Forward declarations

namespace eckit {
  class Configuration;
}

namespace romsjedi {
  class Geometry;
  class ModelAuxControl;
}

//-----------------------------------------------------------------------------

namespace romsjedi {

  // ModelAuxControl class
  class ModelAuxIncrement : public util::Printable,
                            public util::Serializable,
                            private util::ObjectCounter<ModelAuxIncrement> {
   public:
    static const std::string classname() {return "roms::ModelAuxIncrement";}

    // constructors / destructor
    ModelAuxIncrement(const ModelAuxIncrement &, const eckit::Configuration &);
    ModelAuxIncrement(const ModelAuxIncrement &, const bool);
    ModelAuxIncrement(const Geometry &, const eckit::Configuration &);
    ~ModelAuxIncrement();

    // math operators
    ModelAuxIncrement & operator*=(const double);
    ModelAuxIncrement & operator+=(const ModelAuxIncrement &);
    ModelAuxIncrement & operator-=(const ModelAuxIncrement &);
    void axpy(const double, const ModelAuxIncrement &);
    void diff(const ModelAuxControl &, const ModelAuxControl &);
    double dot_product_with(const ModelAuxIncrement &) const;
    double norm() const;
    void zero();

    // serialize (only needed for EDA?)
    size_t serialSize() const override;
    void serialize(std::vector<double> &) const override;
    void deserialize(const std::vector<double> &, size_t &) override;

   private:
    void print(std::ostream &) const;
  };
}  // namespace romsjedi
#endif  // ROMSJEDI_MODELAUX_MODELAUXINCREMENT_H_
