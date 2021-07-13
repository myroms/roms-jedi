/*
 * (C) Copyright 2021-2021  UCAR.
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMS_VARIABLECHANGES_MODEL2GEOVALS_MODEL2GEOVALS_H_
#define ROMS_VARIABLECHANGES_MODEL2GEOVALS_MODEL2GEOVALS_H_

#include <memory>
#include <string>

#include "oops/base/VariableChangeBase.h"

#include "roms/Traits.h"

namespace roms {

  class Model2GeoVaLs: public oops::VariableChangeBase<Traits> {
   public:
    static const std::string classname() {return "roms::Model2GeoVaLs";}

    Model2GeoVaLs(const Geometry &, const eckit::Configuration &);
    ~Model2GeoVaLs();

    void changeVar(const State &, State &) const override;
    void changeVarInverse(const State &, State &) const override;

   private:
    std::unique_ptr<Geometry> geom_;
    void print(std::ostream &) const override {}
  };
}  // namespace roms

#endif  // ROMS_VARIABLECHANGES_MODEL2GEOVALS_MODEL2GEOVALS_H_
