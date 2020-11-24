/*
 * (C) Copyright 2019-2020 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef SOCAROMS_STATE_STATE_H_
#define SOCAROMS_STATE_STATE_H_

#include <memory>
#include <ostream>
#include <string>
#include <vector>

#include "eckit/mpi/Comm.h"

#include "oops/base/Variables.h"
#include "oops/util/DateTime.h"
#include "oops/util/ObjectCounter.h"
#include "oops/util/Printable.h"
#include "oops/util/Serializable.h"

// forward declarations
namespace eckit {
  class Configuration;
}
namespace ufo {
  class GeoVaLs;
  class Locations;
}
namespace socaroms {
  class Geometry;
  class Increment;
}

// ----------------------------------------------------------------------------

namespace socaroms {

  // State class
  class State : public util::Printable,
                public util::Serializable,
                private util::ObjectCounter<State> {
   public:
    static const std::string classname() {return "socaroms::State";}

    // constructors, destructors
    State(const Geometry &, const eckit::Configuration &);
    State(const Geometry &, const oops::Variables &,
          const util::DateTime &);
    State(const Geometry &, const State &);
    State(const State &);
    ~State();

    // math operators
    State & operator+=(const Increment &);
    void accumul(const double &, const State &);
    double norm() const;
    void zero();

    // I/O
    void read(const eckit::Configuration &);
    void write(const eckit::Configuration &) const;

    // time manipulation
    void updateTime(const util::Duration & dt) { time_ += dt; }
    const util::DateTime & validTime() const { return time_; }
    util::DateTime & validTime() { return time_; }

    // serialize (only needed for EDA?)
    size_t serialSize() const override;
    void serialize(std::vector<double> &) const override;
    void deserialize(const std::vector<double> &, size_t &) override;

    // other accessors
    std::shared_ptr<const Geometry> geometry() const;
    const oops::Variables & variables() const { return vars_; }

   private:
    void print(std::ostream &) const;

    std::shared_ptr<const Geometry> geom_;
    oops::Variables vars_;
    util::DateTime time_;
  };
}  // namespace socaroms

#endif  // SOCAROMS_STATE_STATE_H_
