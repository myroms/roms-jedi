/*
 * (C) Copyright 2019-2023 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

 *!
 * \brief   Sets ROMS-JEDI application Geometry object.
 *
 * \details These C++ functions creates/clones/destroys the Geometry object
 *          for a particular ROMS-JEDI application.
 *
 * \author  Hernan G. Arango (Rutgers University)
 * \date    April 2021
 */

#include "atlas/field.h"
#include "atlas/functionspace.h"
#include "atlas/grid.h"
#include "atlas/util/Config.h"

#include "eckit/config/Configuration.h"
#include "eckit/config/YAMLConfiguration.h"
#include "oops/util/abor1_cpp.h"

#include "romsjedi/Geometry/Geometry.h"
#include "romsjedi/GeometryIterator/GeometryIterator.h"

namespace romsjedi {

// -----------------------------------------------------------------------------
/// Geometry constructor.

  Geometry::Geometry(const eckit::Configuration & config,
                     const eckit::mpi::Comm & comm) : comm_(comm) {
    roms_geom_create_f90(keyGeom_,
                         config,
                         &comm);

    // Set ATLAS lon/lat field with and without halos

    atlas::FieldSet lonlat;
    roms_geom_set_lonlat_f90(keyGeom_,
                             lonlat.get());

    functionSpace_ = atlas::functionspace::PointCloud
                            (lonlat->field("lonlat"));
    functionSpaceIncHalo_ = atlas::functionspace::PointCloud
                                   (lonlat->field("lonlat_inc_halos"));

    // Set ATLAS function space pointer in Fortran

    roms_geom_set_atlas_functionspace_pointer_f90(keyGeom_,
                                                  functionSpace_.get(),
                                                  functionSpaceIncHalo_.get());

    // Fill ATLAS fieldset

    roms_geom_to_fieldset_f90(keyGeom_,
                              fields_.get());
  }

// -----------------------------------------------------------------------------
/// Geometry cloning.

  Geometry::Geometry(const Geometry & other)
    : comm_(other.comm_) {
    roms_geom_clone_f90(keyGeom_,
                        other.keyGeom_);


    functionSpace_ = atlas::functionspace::PointCloud
                            (other.functionSpace_->lonlat());
    functionSpaceIncHalo_ = atlas::functionspace::PointCloud
                                   (other.functionSpaceIncHalo_->lonlat());
    roms_geom_set_atlas_functionspace_pointer_f90(keyGeom_,
                                                  functionSpace_.get(),
                                                  functionSpaceIncHalo_.get());

    fields_ = atlas::FieldSet();
    for (int jfield = 0; jfield < other.fields_->size(); ++jfield) {
      atlas::Field atlasField = other.fields_->field(jfield);
      fields_->add(atlasField);
    }
  }

// -----------------------------------------------------------------------------
/// Geometry destructor.

  Geometry::~Geometry() {
    roms_geom_delete_f90(keyGeom_);
  }

// -----------------------------------------------------------------------------
/// It returns START of the geometry on "this" mpi tile.

  GeometryIterator Geometry::begin() const {
    int istr, iend, jstr, jend, kstr, kend;
    roms_geom_start_end_f90(keyGeom_,
                            istr, iend, jstr, jend, kstr, kend);
    if (IteratorDimension() == 3) kstr = 0;
    return GeometryIterator(*this, istr, jstr, kstr);
  }

// -----------------------------------------------------------------------------
/// It return END of the geometry on "this" mpi tile.

  GeometryIterator Geometry::end() const {
    return GeometryIterator(*this, -1, -1, -1);
  }

// -----------------------------------------------------------------------------
/// It returns dimension of the iterator
///   If 2, iterator is over vertical columns
///   If 3, iterator is over 3D points

  int Geometry::IteratorDimension() const {
    int rv;
    roms_geomIterator_dimension_f90(keyGeom_, rv);
    return rv;
  }

// -----------------------------------------------------------------------------
/// It gets the number of vertical level for each field in the variable list.

  std::vector<size_t> Geometry::variableSizes(const oops::Variables & vars)
       const {
    std::vector<size_t> lvls(vars.size());
    roms_geom_get_num_levels_f90(toFortran(),
                                 vars,
                                 lvls.size(),
                                 lvls.data());
    return lvls;
  }


// -----------------------------------------------------------------------------
/// It returns the latitudes/longitudes according to the halo switch.

void Geometry::latlon(std::vector<double> & lats,
                      std::vector<double> & lons,
                      const bool halo) const {
  const atlas::FunctionSpace * fspace;
  if (halo) {
    fspace = &functionSpaceIncHalo_;
  } else {
    fspace = &functionSpace_;
  }
  const auto lonlat = atlas::array::make_view<double, 2>(fspace->lonlat());
  const size_t npts = fspace->size();
  lats.resize(npts);
  lons.resize(npts);
  for (size_t jj = 0; jj < npts; ++jj) {
    lats[jj] = lonlat(jj, 1);
    lons[jj] = lonlat(jj, 0);
    if (lons[jj] < 0.0) lons[jj] += 360.0;
  }
}

// -----------------------------------------------------------------------------
/// It prints Geometry information.

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

// -----------------------------------------------------------------------------

  std::vector<double> Geometry::verticalCoord(std::string &) const {
    util::abor1_cpp("Geometry::verticalCoord() needs to be implemented.",
                    __FILE__, __LINE__);
    return {};
  }

// -----------------------------------------------------------------------------

}  // namespace romsjedi
