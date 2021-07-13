/*
 * (C) Copyright 2019-2021 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#include "roms/Geometry/Geometry.h"
#include "roms/GeometryIterator/GeometryIterator.h"

#include "eckit/config/YAMLConfiguration.h"

#include "oops/util/abor1_cpp.h"

namespace roms {

// ----------------------------------------------------------------------------

  Geometry::Geometry(const eckit::Configuration & conf,
                     const eckit::mpi::Comm & comm)
    : comm_(comm) {
    const eckit::Configuration * configc = &conf;
    roms_geo_setup_f90(keyGeom_, &conf, &comm);
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

  GeometryIterator Geometry::begin() const {
    // return start of the geometry on this mpi tile
    int istr, iend, jstr, jend, nk;
    roms_geo_start_end_f90(keyGeom_, istr, iend, jstr, jend, nk);
    return GeometryIterator(*this, istr, jstr);
  }

// ----------------------------------------------------------------------------

  GeometryIterator Geometry::end() const {
    // return end of the geometry on this mpi tile
    // decided to return index out of bounds for the iterator loops to work
    return GeometryIterator(*this, -1, -1);
  }

// ----------------------------------------------------------------------------

  std::vector<size_t> Geometry::variableSizes(const oops::Variables & vars)
       const {
    std::vector<size_t> lvls(vars.size());
    roms_geo_get_num_levels_f90(toFortran(), vars, lvls.size(), lvls.data());
    return lvls;
  }

// ----------------------------------------------------------------------------

  void Geometry::print(std::ostream & os) const {
    int nx, ny, nz;
    int tile;
    int LBi, UBi, LBj, UBj;
    int Istr, Iend, Jstr, Jend;
    roms_geo_info_f90(keyGeom_, nx, ny, nz, tile, LBi, UBi, LBj, UBj,
                      Istr, Iend, Jstr, Jend);
    os << "Geometry::print" << std::endl;
    os << "  Lm = " << nx << ", Mm  = " << ny << ", N = " << nz << std::endl;
    os << "  tile = " << tile << ", LBi = " << LBi << ", UBi = " << UBi
                      << ", LBj = " << LBj << ", UBj = " << UBj << std::endl;
    os << "  tile = " << tile << ", Istr = " << Istr << ", Iend = " << Iend
                      << ", Jstr = " << Jstr << ", Jend = " << Jend;
  }

// ----------------------------------------------------------------------------

  std::vector<double> Geometry::verticalCoord(std::string &) const {
    util::abor1_cpp("Geometry::verticalCoord() needs to be implemented.",
                    __FILE__, __LINE__);
    return {};
  }

// ----------------------------------------------------------------------------

}  // namespace roms
