/*
 * (C) Copyright 2021-2025 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#pragma once

#include <memory>
#include <ostream>
#include <string>

#include <boost/ptr_container/ptr_vector.hpp>

#include "oops/util/Printable.h"

#include "romsjedi/VariableChange/Base/VariableChangeBase.h"

namespace romsjedi {
  class Geometry;
  class State;

// -----------------------------------------------------------------------------

  class VariableChange : public util::Printable {
   public:
    static const std::string classname() {return "romsjedi::VariableChange";}

    explicit VariableChange(const eckit::Configuration &, const Geometry &);
    ~VariableChange();

    void changeVar(State &, const oops::Variables &) const;
    void changeVarInverse(State &, const oops::Variables &) const;

   private:
    void print(std::ostream &) const override;
    std::unique_ptr<VariableChangeBase> variableChange_;
  };

// -----------------------------------------------------------------------------

}  // namespace romsjedi
