/*
 * (C) Copyright 2017-2025 UCAR
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

#ifndef ROMSJEDI_STATE_STATE_H_
#define ROMSJEDI_STATE_STATE_H_

#include <memory>
#include <ostream>
#include <string>
#include <vector>

#include "oops/base/Variables.h"
#include "oops/util/DateTime.h"
#include "oops/util/Duration.h"
#include "oops/util/ObjectCounter.h"
#include "oops/util/Printable.h"
#include "oops/util/Serializable.h"

#include "romsjedi/Fortran.h"
#include "romsjedi/AnalyticInit/AnalyticInit.h"
#include "romsjedi/Geometry/Geometry.h"
#include "romsjedi/Increment/Increment.h"
#include "romsjedi/State/StateFortran.h"
#include "romsjedi/State/StateParameters.h"

// Forward declarations

namespace eckit {
  class Configuration;
}

namespace ufo {
  class GeoVaLs;
}

namespace romsjedi {
  class Geometry;
  class Increment;
}

//-----------------------------------------------------------------------------

namespace romsjedi {

  /// ROMS model state
  /*!
   * A State contains everything that is needed to propagate the state
   * forward in time.
   */

  class State : public util::Printable,
                public util::Serializable,
                private util::ObjectCounter<State> {
   public:
      static const std::string classname() {return "romsjedi::State";}

      /// Constructor, destructor

      State(const Geometry &,
            const oops::Variables &,
            const util::DateTime &);
      State(const Geometry &,
            const eckit::Configuration &);
      State(const Geometry &,
            const State &);
      State(const oops::Variables &,
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

      void read(const eckit::Configuration &);
      void analytic_init(const eckit::Configuration &);
      void write(const eckit::Configuration &) const;
      double norm() const;

      const util::DateTime & validTime() const;
      util::DateTime & validTime();

      /// Serialize and deserialize

      size_t serialSize() const override;
      void serialize(std::vector<double> &) const override;
      void deserialize(const std::vector<double> &, size_t &) override;

      /// Utilities

      const Geometry & geometry() const;
      const oops::Variables & variables() const {return vars_;}

      /// Get values as Atlas FieldSet

      void toFieldSet(atlas::FieldSet &) const;
      void fromFieldSet(const atlas::FieldSet &);

      int & toFortran() {return keyFlds_;}
      const int & toFortran() const {return keyFlds_;}

      /// Other

      void zero();
      void accumul(const double &, const State &);

  // Private methods and variables

   private:
    void print(std::ostream &) const override;
    F90flds keyFlds_;
    const Geometry & geom_;
    oops::Variables vars_;
    util::DateTime time_;
  };

// -----------------------------------------------------------------------------

}  // namespace romsjedi

#endif  // ROMSJEDI_STATE_STATE_H_
