/*
 * (C) Copyright 2017-2025 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 *
 *!
 * \brief   **Increment**  C++ Class: Difference between two states
 *
 * \details The Increment contains everything that is needed by
 *          the tangent-linear and adjoint models. Some fields that are
 *          present in a State may not be present in an Increment.
 *
 * \author  Hernan G. Arango (Rutgers University)
 * \date    October 2021
 */

#ifndef ROMSJEDI_INCREMENT_INCREMENT_H_
#define ROMSJEDI_INCREMENT_INCREMENT_H_

#include <memory>
#include <ostream>
#include <string>
#include <vector>

#include "eckit/config/Configuration.h"

#include "oops/base/LocalIncrement.h"
#include "oops/base/Variables.h"
#include "oops/util/DateTime.h"
#include "oops/util/dot_product.h"
#include "oops/util/Duration.h"
#include "oops/util/ObjectCounter.h"
#include "oops/util/Printable.h"
#include "oops/util/Serializable.h"

#include "romsjedi/Fortran.h"
#include "romsjedi/Geometry/Geometry.h"
#include "romsjedi/GeometryIterator/GeometryIterator.h"
#include "romsjedi/Increment/IncrementFortran.h"
#include "romsjedi/Increment/IncrementParameters.h"
#include "romsjedi/State/State.h"

// Forward declarations

namespace atlas {
  class FieldSet;
}

namespace eckit {
  class Configuration;
}

namespace ufo {
  class GeoVaLs;
}

namespace romsjedi {
  class ModelBiasIncrement;
  class Geometry;
  class State;
}

// -----------------------------------------------------------------------------

namespace romsjedi {

  /// Increment Class

  class Increment : public util::Printable,
                    private util::ObjectCounter<Increment> {
   public:
     static const std::string classname() {return "romsjedi::Increment";}

  /// Constructor, destructor

  Increment(const Geometry &,
            const oops::Variables &,
            const util::DateTime &);
  Increment(const Geometry &,
            const Increment &);
  Increment(const Increment &,
            const bool);
  Increment(const Increment &);
  virtual ~Increment();

  /// Basic operators

  void diff(const State &, const State &);
  void ones();
  void zero();
  void zero(const util::DateTime &);
  Increment & operator =(const Increment &);
  Increment & operator+=(const Increment &);
  Increment & operator-=(const Increment &);
  Increment & operator*=(const double &);
  void axpy(const double &,
            const Increment &,
            const bool check = true);
  double dot_product_with(const Increment &) const;
  void schur_product_with(const Increment &);
  void random();
  void dirac(const eckit::Configuration &);

  /// Getpoint/Setpoint

  oops::LocalIncrement getLocal(const GeometryIterator &) const;
  void setLocal(const oops::LocalIncrement &,
                const GeometryIterator &);

  /// Add or remove fields due to variable change

  void updateFields(const oops::Variables &);

  /// ATLAS

  void toFieldSet(atlas::FieldSet &) const;
  void fromFieldSet(const atlas::FieldSet &);

  /// I/O and diagnostics

  void read(const eckit::Configuration &);
  void write(const eckit::Configuration &) const;
  double norm() const;
  std::vector<double> rmsByLevel(const std::string &) const;

  /// Other

  void accumul(const double &, const State &);

  /// Serialize and deserialize

  size_t serialSize() const;
  void serialize(std::vector<double> &) const;
  void deserialize(const std::vector<double> &,
                   size_t &);

  /// Utilities

  const Geometry & geometry() const {return geom_;}

  const util::DateTime & validTime() const;
  util::DateTime & validTime();
  void updateTime(const util::Duration & dt);

  int & toFortran() {return keyFlds_;}
  const int & toFortran() const {return keyFlds_;}

  /// Private methods and variables

  const oops::Variables & variables() const {return vars_;}
  const util::DateTime & time() const {return time_;}

   private:
    typedef DiracParameters          DiracParameters_;
    typedef IncrementReadParameters  ReadParameters_;
    typedef IncrementWriteParameters WriteParameters_;

    void print(std::ostream &) const;

    F90flds keyFlds_;
    const Geometry & geom_;
    oops::Variables vars_;
    util::DateTime time_;
  };

// -----------------------------------------------------------------------------

}  // namespace romsjedi

#endif  // ROMSJEDI_INCREMENT_INCREMENT_H_
