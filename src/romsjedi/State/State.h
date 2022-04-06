/*
 * (C) Copyright 2017-2022 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMSJEDI_STATE_STATE_H_
#define ROMSJEDI_STATE_STATE_H_

#include <memory>
#include <ostream>
#include <string>
#include <vector>

#include "oops/base/Variables.h"
#include "oops/base/WriteParametersBase.h"
#include "oops/util/DateTime.h"
#include "oops/util/Duration.h"
#include "oops/util/ObjectCounter.h"
#include "oops/util/Printable.h"
#include "oops/util/Serializable.h"
#include "oops/util/parameters/OptionalParameter.h"
#include "oops/util/parameters/Parameters.h"
#include "oops/util/parameters/RequiredParameter.h"

#include "romsjedi/Fortran.h"
#include "romsjedi/AnalyticInit/AnalyticInit.h"
#include "romsjedi/Geometry/Geometry.h"
#include "romsjedi/Increment/Increment.h"
#include "romsjedi/State/StateFortran.h"

// Forward declarations

namespace eckit {
  class Configuration;
}

namespace romsjedi {
  class Geometry;
  class Increment;
}

//-----------------------------------------------------------------------------

namespace romsjedi {

  /// \brief Parameters controlling reading state from a NetCDF file
  /// ('initial condition' or 'statefile') or generating state fields
  /// with analytic expressions ('state generate', 'state analytic init',
  /// 'analytic init').

  class StateParameters : public oops::Parameters {
    OOPS_CONCRETE_PARAMETERS(StateParameters, Parameters)

   public:
    typedef AnalyticInitParameters AnalyticParameters_;

    oops::OptionalParameter<AnalyticParameters_> analyticInit{
      "analytic init",
      "State analytic initialization",
      this};
    oops::OptionalParameter<std::string> FieldsDir{
      "fields_dir",
      "Input State directory",
      this};
    oops::OptionalParameter<std::string> FieldsFileName{
      "fields_filename",
      "Input State NetCDF filename",
      this};
    oops::OptionalParameter<int> FieldsRecord{
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

  /// \brief Parameters controlling writing state to NetCDF file(s).
  /// Output filenames are of form: 'prefix_exp_type_date.nc'.
  /// The properties 'date', 'iteration', and 'member' are already part
  /// of the schema, but 'frequency' is not. For now, an alias
  /// 'data_frequency' is created to avoid conflicting schemas.

  class StateWriteParameters : public oops::WriteParametersBase {
    OOPS_CONCRETE_PARAMETERS(StateWriteParameters, WriteParametersBase)

   public:
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

  /// ROMS model state
  /*!
   * A State contains everything that is needed to propagate the state
   * forward in time.
   */
  class State : public util::Printable,
                public util::Serializable,
                private util::ObjectCounter<State> {
   public:
     typedef StateParameters Parameters_;
     typedef StateWriteParameters WriteParameters_;

      static const std::string classname() {return "romsjedi::State";}

      /// Constructor, destructor

      State(const Geometry &,
            const oops::Variables &,
            const util::DateTime &);
      State(const Geometry &,
            const Parameters_ &);
      State(const Geometry &,
            const State &);
      State(const State &);
      virtual ~State();

      State & operator=(const State &);

      /// Needed by PseudoModel

      void updateTime(const util::Duration & dt) {time_ += dt;}

      /// Add or remove fields due to variable change

      void updateFields(const oops::Variables &);

      /// Rotations

      void rotate2north(const oops::Variables &,
                        const oops::Variables &) const;
      void rotate2grid(const oops::Variables &,
                       const oops::Variables &) const;

      /// Logarithmic and exponential transformations

      void logtrans(const oops::Variables &) const;
      void expontrans(const oops::Variables &) const;

      /// Interactions with Increment

      State & operator+=(const Increment &);

      /// I/O and diagnostics

      void read(const Parameters_ &);
      void analytic_init(const Parameters_ &);
      void write(const WriteParameters_ &) const;
      double norm() const;

      const util::DateTime & validTime() const;
      util::DateTime & validTime();

      /// Serialize and deserialize

      size_t serialSize() const override;
      void serialize(std::vector<double> &) const override;
      void deserialize(const std::vector<double> &, size_t &) override;

      /// Utilities

      std::shared_ptr<const Geometry> geometry() const;
      const oops::Variables & variables() const {return vars_;}

      /// Get values as Atlas FieldSet

      void getFieldSet(const oops::Variables &,
                       atlas::FieldSet &) const;

      int & toFortran() {return keyFlds_;}
      const int & toFortran() const {return keyFlds_;}

      /// Other

      void zero();
      void accumul(const double &, const State &);

  // Private methods and variables
   private:
    void print(std::ostream &) const override;
    F90flds keyFlds_;
    std::shared_ptr<const Geometry> geom_;
    oops::Variables vars_;
    util::DateTime time_;
  };

// -----------------------------------------------------------------------------

}  // namespace romsjedi

#endif  // ROMSJEDI_STATE_STATE_H_
