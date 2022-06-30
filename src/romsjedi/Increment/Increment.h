/*
 * (C) Copyright 2017-2022 UCAR.
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

#include "atlas/field.h"

#include "oops/base/LocalIncrement.h"
#include "oops/util/DateTime.h"
#include "oops/util/dot_product.h"
#include "oops/util/Duration.h"
#include "oops/util/ObjectCounter.h"
#include "oops/util/Printable.h"
#include "oops/util/Serializable.h"
#include "oops/util/parameters/Parameters.h"
#include "oops/util/parameters/RequiredParameter.h"

#include "romsjedi/Fortran.h"
#include "romsjedi/Geometry/Geometry.h"
#include "romsjedi/GeometryIterator/GeometryIterator.h"
#include "romsjedi/Increment/IncrementFortran.h"
#include "romsjedi/State/State.h"

// Forward declarations

namespace eckit {
  class Configuration;
}

namespace oops {
  class Variables;
}

namespace romsjedi {
  class ModelBiasIncrement;
  class Geometry;
  class State;
}

// -----------------------------------------------------------------------------

namespace romsjedi {

  /// \brief Parameters passed to the Increment::dirac() method.
  /// Grid indices where the field is to be set to 1. Otherwise,
  /// zero elsewhere.

  class IncrementDiracParameters : public oops::Parameters {
    OOPS_CONCRETE_PARAMETERS(IncrementDiracParameters, Parameters)

   public:
    oops::RequiredParameter<std::vector<int>> ixdir{"ixdir", this};
  };


  /// \brief Parameters passed to the Increment::read method.

  class IncrementReadParameters : public oops::Parameters {
    OOPS_CONCRETE_PARAMETERS(IncrementReadParameters, Parameters)

   public:
    oops::RequiredParameter<std::string> FieldsDir{
      "fields_dir",
      "Input State directory",
      this};
    oops::RequiredParameter<std::string> FieldsFileName{
      "fields_filename",
      "Input State NetCDF filename",
      this};
    oops::RequiredParameter<int> FieldsRecord{
      "fields_record",
      "State NetCDF time record to read and process",
      this};
    oops::RequiredParameter<util::DateTime> date{
      "date",
      "Date to assign to analytical or read State fields",
      this};
    oops::RequiredParameter<oops::Variables> vars{
      "state variables",
      "State variables to process",
      this};
  };

  /// \brief Parameters controlling writing Increment to NetCDF file(s).
  /// Output filenames are of form: 'prefix_exp_type_date.nc'.
  /// The properties 'date', 'iteration', and 'member' are already part
  /// of the schema, but 'frequency' is not. For now, an alias
  /// 'data_frequency' is created to avoid conflicting schemas.

  class IncrementWriteParameters : public oops::WriteParametersBase {
    OOPS_CONCRETE_PARAMETERS(IncrementWriteParameters, WriteParametersBase)

   public:
    oops::OptionalParameter<std::string> Bparameter{
      "parameter",
      "Background Error Covariance parameter",
      this};
    oops::RequiredParameter<util::Duration> filePolicy{
      "file_policy",
      "State output new file creation policy time interval for "
      "single or multiple files",
      this};
    oops::RequiredParameter<util::Duration> dataFrequency{
      "data_frequency",
      "State data writing frequency",
      this};
    oops::RequiredParameter<std::string> dataDir{
      "data_dir",
      "State output file(s) directory",
      this};
    oops::RequiredParameter<std::string> prefix{
      "prefix",
      "NetCDF filename prefix",
      this};
    oops::RequiredParameter<std::string> exp{
      "exp",
      "State 'exp' label used in the generation of filename(s)",
      this};
    oops::RequiredParameter<std::string> type{
      "type",
      "State 'type' label used in the generation of filename(s)",
      this};
    oops::RequiredParameter<util::Duration> forecastLength{
      "forecast length",
      "Alias to application forecast length needed in file creation policy",
      this};
  };

  /// Increment Class

  class Increment : public util::Printable,
                    private util::ObjectCounter<Increment> {
   public:
     typedef IncrementDiracParameters DiracParameters_;
     typedef IncrementReadParameters  ReadParameters_;
     typedef IncrementWriteParameters WriteParameters_;

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
  void dirac(const DiracParameters_ &);

  /// Getpoint/Setpoint

  oops::LocalIncrement getLocal(const GeometryIterator &) const;
  void setLocal(const oops::LocalIncrement &,
                const GeometryIterator &);

  /// Add or remove fields due to variable change

  void updateFields(const oops::Variables &);

  /// ATLAS

  void toFieldSet(atlas::FieldSet &) const;
  void toFieldSetAD(const atlas::FieldSet &);
  void fromFieldSet(const atlas::FieldSet &);

  /// I/O and diagnostics

  void read(const ReadParameters_ &);
  void write(const WriteParameters_ &) const;
  double norm() const;

  /// Other

  void accumul(const double &, const State &);

  /// Serialize and deserialize

  size_t serialSize() const;
  void serialize(std::vector<double> &) const;
  void deserialize(const std::vector<double> &,
                   size_t &);

  /// Utilities

  std::shared_ptr<const Geometry> geometry() const;

  const util::DateTime & validTime() const;
  util::DateTime & validTime();
  void updateTime(const util::Duration & dt);

  int & toFortran() {return keyFlds_;}
  const int & toFortran() const {return keyFlds_;}

  /// Private methods and variables

   private:
    void print(std::ostream &) const;

    F90flds keyFlds_;
    std::shared_ptr<const Geometry> geom_;
    oops::Variables vars_;
    util::DateTime time_;
  };

// -----------------------------------------------------------------------------

}  // namespace romsjedi

#endif  // ROMSJEDI_INCREMENT_INCREMENT_H_
