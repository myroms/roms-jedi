/*
 * (C) Copyright 2021-2025 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMSJEDI_LINEARVARIABLECHANGE_MODEL2ANALYSIS_LINVARCHAMODEL2ANALYSIS_H_
#define ROMSJEDI_LINEARVARIABLECHANGE_MODEL2ANALYSIS_LINVARCHAMODEL2ANALYSIS_H_

#include <memory>
#include <ostream>
#include <string>

#include "eckit/config/Configuration.h"

#include "romsjedi/LinearVariableChange/Base/LinearVariableChangeBase.h"

namespace romsjedi {
  class Geometry;
  class Increment;
  class State;

// -----------------------------------------------------------------------------

  class LinVarChaModel2Analysis: public LinearVariableChangeBase {
   public:
    static const std::string classname() {
      return "romsjedi::LinVarChaModel2Analysis";}

    explicit LinVarChaModel2Analysis(const State &,
                            const State &,
                            const Geometry &,
                            const eckit::LocalConfiguration &);
    ~LinVarChaModel2Analysis();

    void multiply(const Increment &,
                  Increment &) const override;
    void multiplyInverse(const Increment &,
                         Increment &) const override;

    void multiplyAD(const Increment &,
                    Increment &) const override;
    void multiplyInverseAD(const Increment &,
                           Increment &) const override;

   private:
    const Geometry & geom_;
    F90lvc_M2A keySelf_;
    void print(std::ostream &) const override;
  };

}  // namespace romsjedi

// -----------------------------------------------------------------------------

#endif  // ROMSJEDI_LINEARVARIABLECHANGE_MODEL2ANALYSIS_LINVARCHAMODEL2ANALYSIS_H_
