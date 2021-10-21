/*
 * (C) Copyright 2019-2021 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */


#include "atlas/field.h"
#include "atlas/functionspace.h"
#include "atlas/grid.h"
#include "atlas/util/Config.h"

#include "eckit/config/YAMLConfiguration.h"
#include "oops/util/abor1_cpp.h"

#include "romsjedi/Geometry/Geometry.h"
#include "romsjedi/GeometryIterator/GeometryIterator.h"

namespace romsjedi {

// ----------------------------------------------------------------------------

  Geometry::Geometry(const GeometryParameters & params,
                     const eckit::mpi::Comm & comm) : comm_(comm) {
    // Geometry constructor
    roms_geom_setup_f90(keyGeom_, params.toConfiguration(), &comm);

    // Set ATLAS lon/lat field
    atlasFieldSet_.reset(new atlas::FieldSet());
    roms_geom_set_atlas_lonlat_f90(keyGeom_, atlasFieldSet_->get());
    atlas::Field atlasField = atlasFieldSet_->field("lonlat");

    // Create ATLAS function space
    atlasFunctionSpace_.reset(new atlas::functionspace::PointCloud(atlasField));

    // Set ATLAS function space pointer in Fortran
    roms_geom_set_atlas_functionspace_pointer_f90(keyGeom_,
                                                  atlasFunctionSpace_->get());

    // Fill ATLAS fieldset
    atlasFieldSet_.reset(new atlas::FieldSet());
    roms_geom_fill_atlas_fieldset_f90(keyGeom_, atlasFieldSet_->get());
  }

// ----------------------------------------------------------------------------

  Geometry::Geometry(const Geometry & other)
    : comm_(other.comm_) {
    roms_geom_clone_f90(keyGeom_, other.keyGeom_);
    atlasFunctionSpace_.reset(new atlas::functionspace::PointCloud(
                              other.atlasFunctionSpace_->lonlat()));
    roms_geom_set_atlas_functionspace_pointer_f90(keyGeom_,
                                                  atlasFunctionSpace_->get());
    atlasFieldSet_.reset(new atlas::FieldSet());
    for (int jfield = 0; jfield < other.atlasFieldSet_->size(); ++jfield) {
      atlas::Field atlasField = other.atlasFieldSet_->field(jfield);
      atlasFieldSet_->add(atlasField);
    }
  }

// ----------------------------------------------------------------------------

  Geometry::~Geometry() {
    roms_geom_delete_f90(keyGeom_);
  }

// ----------------------------------------------------------------------------

  GeometryIterator Geometry::begin() const {
    // return start of the geometry on this mpi tile
    int istr, iend, jstr, jend, nk;
    roms_geom_start_end_f90(keyGeom_, istr, iend, jstr, jend, nk);
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
    roms_geom_get_num_levels_f90(toFortran(), vars, lvls.size(), lvls.data());
    return lvls;
  }

// ----------------------------------------------------------------------------

  void Geometry::print(std::ostream & os) const {
    int nx, ny, nz;
    int tile;
    int LBi, UBi, LBj, UBj;
    int Istr, Iend, Jstr, Jend;
    roms_geom_info_f90(keyGeom_, nx, ny, nz, tile, LBi, UBi, LBj, UBj,
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

}  // namespace romsjedi
