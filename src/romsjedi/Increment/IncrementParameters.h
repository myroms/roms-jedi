/*
 * (C) Copyright 2024 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
*!
 * \brief   **Increment**  C++ Class: Difference between two states
 *
 * \details Sets Parameters for the Increment object
 *
 * \author  Hernan G. Arango (Rutgers University)
 * \date    May 2024
 */

#ifndef ROMSJEDI_INCREMENT_INCREMENTPARAMETERS_H_
#define ROMSJEDI_INCREMENT_INCREMENTPARAMETERS_H_

#include <string>
#include <vector>

#include "oops/base/WriteParametersBase.h"
#include "oops/util/parameters/OptionalParameter.h"
#include "oops/util/parameters/Parameter.h"
#include "oops/util/parameters/Parameters.h"
#include "oops/util/parameters/RequiredParameter.h"

namespace romsjedi {

// -----------------------------------------------------------------------------

  /// \brief Parameters passed to the Increment::dirac() method.
  /// Grid indices where the field is to be set to 1. Otherwise,
  /// zero elsewhere.

  class DiracParameters : public oops::Parameters {
    OOPS_CONCRETE_PARAMETERS(DiracParameters, Parameters)

   public:
    oops::RequiredParameter<std::vector<int>> ixdir{
      "ixdir",
      "Dirac Impulse grid x-direction index vector",
      this};
    oops::RequiredParameter<std::vector<int>> iydir{
      "iydir",
      "Dirac Impulse grid y-direction index vector",
      this};
    oops::RequiredParameter<std::vector<int>> izdir{
      "izdir",
      "Dirac Impulse grid z-direction index vector",
      this};
    oops::RequiredParameter<std::vector<std::string>> ifdir{
      "ifdir",
      "State fields vector to perturb with Dirac Impulse",
      this};
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

#endif  // ROMSJEDI_INCREMENT_INCREMENTPARAMETERS_H_
