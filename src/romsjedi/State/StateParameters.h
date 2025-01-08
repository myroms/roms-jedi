/*
 * (C) Copyright 2024-2025 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
*!
 * \brief   **State**  C++ Class:
 *
 * \details Sets Parameters for the State object
 *
 * \author  Hernan G. Arango (Rutgers University)
 * \date    May 2024
 */

#ifndef ROMSJEDI_STATE_STATEPARAMETERS_H_
#define ROMSJEDI_STATE_STATEPARAMETERS_H_

#include <string>

#include "oops/base/ParameterTraitsVariables.h"
#include "oops/base/Variables.h"
#include "oops/util/DateTime.h"
#include "oops/util/Duration.h"
#include "oops/util/parameters/OptionalParameter.h"
#include "oops/util/parameters/Parameter.h"
#include "oops/util/parameters/Parameters.h"
#include "oops/util/parameters/RequiredParameter.h"

namespace romsjedi {

// -----------------------------------------------------------------------------

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

  class StateWriteParameters : public oops::Parameters {
    OOPS_CONCRETE_PARAMETERS(StateWriteParameters, Parameters)

   public:
    oops::OptionalParameter<bool> singleTimeRecord{
      "single_record",
      "State is written into single time record file",
      this};
    oops::OptionalParameter<util::Duration> filePolicy{
      "file_policy",
      "State output new file creation policy time interval for "
      "single or multiple files",
      this};
    oops::OptionalParameter<util::Duration> dataFrequency{
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
    oops::OptionalParameter<util::Duration> forecastLength{
      "forecast length",
      "Alias to application forecast length needed in file creation policy",
      this};
  };
}  // namespace romsjedi

// -----------------------------------------------------------------------------

#endif  // ROMSJEDI_STATE_STATEPARAMETERS_H_
