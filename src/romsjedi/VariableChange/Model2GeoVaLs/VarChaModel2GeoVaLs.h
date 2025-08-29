/*
 * (C) Copyright 2021-2025 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMSJEDI_VARIABLECHANGE_MODEL2GEOVALS_VARCHAMODEL2GEOVALS_H_
#define ROMSJEDI_VARIABLECHANGE_MODEL2GEOVALS_VARCHAMODEL2GEOVALS_H_

#include <memory>
#include <ostream>
#include <string>

#include "eckit/config/Configuration.h"

#include "romsjedi/VariableChange/Base/VariableChangeBase.h"

namespace romsjedi {

  class VarChaModel2GeoVaLs: public VariableChangeBase {
   public:
    static const std::string classname() {
      return "romsjedi::VarChaModel2GeoVaLs";
    }

    VarChaModel2GeoVaLs(const Geometry &, const eckit::Configuration &);
    ~VarChaModel2GeoVaLs();

    void changeVar(const State &, State &) const override;
    void changeVarInverse(const State &, State &) const override;

   private:
    F90vc_M2G keySelf_;
    std::unique_ptr<Geometry> geom_;
    void print(std::ostream &) const override {}
  };
}  // namespace romsjedi

#endif  // ROMSJEDI_VARIABLECHANGE_MODEL2GEOVALS_VARCHAMODEL2GEOVALS_H_
