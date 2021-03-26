/*
 * (C) Copyright 2019-2020 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#include "roms/Geometry/Geometry.h"
#include "roms/GeometryIterator/GeometryIterator.h"

#include "eckit/config/Configuration.h"

#include "oops/util/abor1_cpp.h"

namespace roms {

// ----------------------------------------------------------------------------

  Geometry::Geometry(const eckit::Configuration & conf,
                     const eckit::mpi::Comm & comm)
    : comm_(comm) {
    const eckit::Configuration * configc = &conf;
    roms_geo_setup_f90(keyGeom_, &configc, &comm);
  }

// ----------------------------------------------------------------------------

  Geometry::Geometry(const Geometry & other)
    : comm_(other.comm_) {
    roms_geo_clone_f90(keyGeom_, other.keyGeom_);
  }

// ----------------------------------------------------------------------------

  Geometry::~Geometry() {
    roms_geo_delete_f90(keyGeom_);
  }

// ----------------------------------------------------------------------------

/* TODO(template_impl)
  GeometryIterator Geometry::begin() const {
    util::abor1_cpp("Geometry::begin() needs to be implemented.",
                    __FILE__, __LINE__);
    return GeometryIterator(*this, 0, 0);
  }
TODO(template_impl) */

// ----------------------------------------------------------------------------

/* TODO(template_impl)
  GeometryIterator Geometry::end() const {
    util::abor1_cpp("Geometry::end() needs to be implemented.",
                    __FILE__, __LINE__);
    return GeometryIterator(*this, 0, 0);
  }
TODO(template_impl) */

// ----------------------------------------------------------------------------
  void Geometry::print(std::ostream & os) const {
    /*    util::abor1_cpp("Geometry::print() needs to be implemented.",
	  __FILE__, __LINE__); */
    os << "Geometry: "
       << "(TODO, print diagnostic info about the geometry here)"
       << std::endl;
  }

// ----------------------------------------------------------------------------
  std::vector<double> Geometry::verticalCoord(std::string &) const {
    util::abor1_cpp("Geometry::verticalCoord() needs to be implemented.",
                    __FILE__, __LINE__);
    return {};
  }

// ----------------------------------------------------------------------------

}  // namespace roms
