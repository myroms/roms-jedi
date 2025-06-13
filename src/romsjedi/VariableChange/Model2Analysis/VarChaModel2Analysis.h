/*
 * (C) Copyright 2017-2025 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMSJEDI_VARIABLECHANGE_MODEL2ANALYSIS_VARCHAMODEL2ANALYSIS_H_
#define ROMSJEDI_VARIABLECHANGE_MODEL2ANALYSIS_VARCHAMODEL2ANALYSIS_H_

#include <memory>
#include <ostream>
#include <string>

#include "eckit/config/Configuration.h"
#include "romsjedi/Geometry/Geometry.h"
#include "romsjedi/Traits.h"
#include "romsjedi/VariableChange/Base/VariableChangeBase.h"

namespace romsjedi {

// -----------------------------------------------------------------------------

  class VarChaModel2Analysis: public VariableChangeBase {
   public:
    static const std::string classname() {
      return "romsjedi::VarChaModel2Analysis";
    }

    VarChaModel2Analysis(const Geometry &, const eckit::Configuration &);
    ~VarChaModel2Analysis();

    void changeVar(const State &,
                   State &) const override;
    void changeVarInverse(const State &,
                          State &) const override;

   private:
    const Geometry & geom_;
    F90vc_M2A keySelf_;
    void print(std::ostream &) const override;
  };

// -----------------------------------------------------------------------------

}  // namespace romsjedi

#endif  // ROMSJEDI_VARIABLECHANGE_MODEL2ANALYSIS_VARCHAMODEL2ANALYSIS_H_
