/*
 * (C) Copyright 2021-2025 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMSJEDI_LINEARVARIABLECHANGE_MODEL2GEOVALS_LINVARCHAMODEL2GEOVALS_H_
#define ROMSJEDI_LINEARVARIABLECHANGE_MODEL2GEOVALS_LINVARCHAMODEL2GEOVALS_H_

#include <memory>
#include <ostream>
#include <string>

#include "romsjedi/LinearVariableChange/Base/LinearVariableChangeBase.h"

// Forward declarations

namespace eckit {
  class Configuration;
}

namespace romsjedi {
  class Geometry;
  class Increment;
  class State;
}

namespace romsjedi {

// -----------------------------------------------------------------------------

  class LinVarChaModel2GeoVaLs: public LinearVariableChangeBase {
   public:
    static const std::string classname() {
      return "romsjedi::LinVarChaModel2GeoVaLs";}

    explicit LinVarChaModel2GeoVaLs(const State &,
                                    const State &,
                                    const Geometry &,
                                    const eckit::LocalConfiguration &);
    ~LinVarChaModel2GeoVaLs();

    void multiply(const Increment &,
                  Increment &) const override;
    void multiplyInverse(const Increment &,
                         Increment &) const override;
    void multiplyAD(const Increment &,
                    Increment &) const override;
    void multiplyInverseAD(const Increment &,
                           Increment &) const override;

   private:
    F90lvc_M2G keySelf_;
    std::shared_ptr<const Geometry> geom_;
    void print(std::ostream &) const override;
  };

}  // namespace romsjedi

// -----------------------------------------------------------------------------

#endif  // ROMSJEDI_LINEARVARIABLECHANGE_MODEL2GEOVALS_LINVARCHAMODEL2GEOVALS_H_
