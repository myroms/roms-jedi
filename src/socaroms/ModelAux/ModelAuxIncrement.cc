/*
 * (C) Copyright 2019-2020 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#include "socaroms/ModelAux/ModelAuxIncrement.h"
#include "socaroms/ModelAux/ModelAuxControl.h"

#include "oops/util/abor1_cpp.h"

namespace socaroms {

// ----------------------------------------------------------------------------

  ModelAuxIncrement::ModelAuxIncrement(const ModelAuxIncrement &,
                                       const eckit::Configuration &) {
    util::abor1_cpp(
      "ModelAuxIncrement::ModelAuxIncrement() needs to be implemented.",
      __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  ModelAuxIncrement::ModelAuxIncrement(const ModelAuxIncrement &, const bool) {
    util::abor1_cpp(
       "ModelAuxIncrement::ModelAuxIncrement() needs to be implemented.",
       __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  ModelAuxIncrement::ModelAuxIncrement(const Geometry &,
                                       const eckit::Configuration &) {
    util::abor1_cpp(
      "ModelAuxIncrement::ModelAuxIncrement() needs to be implemented.",
      __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  ModelAuxIncrement::~ModelAuxIncrement() {
    util::abor1_cpp(
      "ModelAuxIncrement::~ModelAuxIncrement() needs to be implemented.",
      __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------
  void ModelAuxIncrement::diff(const ModelAuxControl &,
                               const ModelAuxControl &) {
    util::abor1_cpp(
      "ModelAuxIncrement::diff() needs to be implemented.",
      __FILE__, __LINE__);
  }
// ----------------------------------------------------------------------------

  void ModelAuxIncrement::zero() {
    util::abor1_cpp(
      "ModelAuxIncrement::zero() needs to be implemented.",
      __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  ModelAuxIncrement & ModelAuxIncrement::operator*=(const double) {
    util::abor1_cpp(
      "ModelAuxIncrement::operator*=() needs to be implemented.",
      __FILE__, __LINE__);
    return *this;
  }

// ----------------------------------------------------------------------------

  ModelAuxIncrement & ModelAuxIncrement::operator+=(const ModelAuxIncrement &) {
    util::abor1_cpp(
      "ModelAuxIncrement::operator+=() needs to be implemented.",
      __FILE__, __LINE__);
    return *this;
  }

// ----------------------------------------------------------------------------

  ModelAuxIncrement & ModelAuxIncrement::operator-=(const ModelAuxIncrement &) {
    util::abor1_cpp(
      "ModelAuxIncrement::operator-=() needs to be implemented.",
      __FILE__, __LINE__);
    return *this;
  }

// ----------------------------------------------------------------------------

  double ModelAuxIncrement::norm() const {
    util::abor1_cpp(
      "ModelAuxIncrement::norm() needs to be implemented.",
      __FILE__, __LINE__);
    return 0.0;
  }

// ----------------------------------------------------------------------------

  void ModelAuxIncrement::axpy(const double, const ModelAuxIncrement &) {
    util::abor1_cpp(
      "ModelAuxIncrement::axpy() needs to be implemented.",
      __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  double ModelAuxIncrement::dot_product_with(const ModelAuxIncrement &) const {
    util::abor1_cpp(
      "ModelAuxIncrement::dot_product_with() needs to be implemented.",
      __FILE__, __LINE__);
    return 0.0;
  }

// ----------------------------------------------------------------------------

  size_t ModelAuxIncrement::serialSize() const {
    util::abor1_cpp("ModelAuxIncrement::serialSize() needs to be implemented.",
                     __FILE__, __LINE__);
    return 0;
  }

// ----------------------------------------------------------------------------

  void ModelAuxIncrement::serialize(std::vector<double> & vec) const {
    util::abor1_cpp("ModelAuxIncrement::serialize() needs to be implemented.",
                     __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  void ModelAuxIncrement::deserialize(const std::vector<double> & vec,
                                      size_t & s) {
    util::abor1_cpp("ModelAuxIncrement::deserialize() needs to be implemented.",
                     __FILE__, __LINE__);
  }

// ----------------------------------------------------------------------------

  void ModelAuxIncrement::print(std::ostream & os) const {
    util::abor1_cpp("ModelAuxIncrement::print() needs to be implemented.",
                    __FILE__, __LINE__);
    os << "(TODO, print diagnostic info about the ModelAuxIncrement here)"
       << std::endl;
  }

// ----------------------------------------------------------------------------

}  // namespace socaroms
