 /*
 * (C) Copyright 2019-2024 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

 *!
 * \brief   Sets ROMS-JEDI application Geometry object.
 *
 * \details These C++ functions creates/clones/destroys the Geometry object
 *          for a particular ROMS-JEDI application.
 *
 * \author  Hernan G. Arango (Rutgers University)
 * \date    April 2021
 */

#include <algorithm>

#include "atlas/functionspace.h"
#include "atlas/mesh/actions/BuildHalo.h"
#include "atlas/mesh/Mesh.h"
#include "atlas/mesh/MeshBuilder.h"
#include "atlas/output/Gmsh.h"
#include "eckit/config/Configuration.h"
#include "eckit/config/YAMLConfiguration.h"
#include "oops/util/abor1_cpp.h"
#include "oops/util/Logger.h"

#include "romsjedi/Geometry/Geometry.h"
#include "romsjedi/GeometryIterator/GeometryIterator.h"

using oops::Log;

namespace romsjedi {

// -----------------------------------------------------------------------------
/// Geometry constructor.

  Geometry::Geometry(const eckit::Configuration & config,
                     const eckit::mpi::Comm & comm) : comm_(comm) {
    Log::trace() << classname() << ":Geometry setup starting"
                 << std::endl;
    roms_geom_init_f90(keyGeom_,
                       config,
                       &comm);
    Log::trace() << classname() << ":Geometry setup done"
                 << std::endl;

    // Setup the ATLAS FunctionSpace

    {
      using atlas::gidx_t;
      using atlas::idx_t;

      int num_nodes;
      int num_quad_elements;

      Log::trace() << classname() << ":Geometry ATLAS mesh starting"
                   << std::endl;

      roms_geom_get_mesh_size_f90(keyGeom_,
                                  num_nodes,
                                  num_quad_elements);

      std::vector<double> lons(num_nodes);
      std::vector<double> lats(num_nodes);
      std::vector<int> ghosts(num_nodes);
      std::vector<int> global_indices(num_nodes);
      std::vector<int> remote_indices(num_nodes);
      std::vector<int> partitions(num_nodes);

      const int num_quad_nodes = num_quad_elements * 4;
      std::vector<int> raw_quad_nodes(num_quad_nodes);

      roms_geom_gen_mesh_f90(keyGeom_,
                             num_nodes,
                             lons.data(),
                             lats.data(),
                             ghosts.data(),
                             global_indices.data(),
                             remote_indices.data(),
                             partitions.data(),
                             num_quad_nodes,
                             raw_quad_nodes.data());

      // Calculate global quadrilateral numbering offset per PET.

      std::vector<int> num_elements_per_rank(comm_.size());
      comm_.allGather(num_quad_elements,
                      num_elements_per_rank.begin(),
                      num_elements_per_rank.end());

      int global_element_index = 0;
      for (size_t i = 0; i < comm_.rank(); ++i) {
        global_element_index += num_elements_per_rank[i];
      }

      // Convert some of the temporary arrays into a form ATLAS expects

      std::vector<gidx_t> atlas_global_indices(num_nodes);
      std::transform(global_indices.begin(),
                     global_indices.end(),
                     atlas_global_indices.begin(),
                     [](const int index) {return atlas::gidx_t{index};});

      std::vector<idx_t> atlas_remote_indices(num_nodes);
      std::transform(remote_indices.begin(),
                     remote_indices.end(),
                     atlas_remote_indices.begin(),
                     [](const int index) {return atlas::idx_t{index};});

      // ROMS does not have triangles

      std::vector<std::array<gidx_t, 3>> tri_boundary_nodes{};
      std::vector<gidx_t> tri_global_indices{};

      std::vector<std::array<gidx_t, 4>> quad_boundary_nodes(num_quad_elements);
      std::vector<gidx_t> quad_global_indices(num_quad_elements);

      for (size_t quad = 0; quad < num_quad_elements; ++quad) {
        for (size_t i = 0; i < 4; ++i) {
          quad_boundary_nodes[quad][i] = raw_quad_nodes[4*quad + i];
        }
        quad_global_indices[quad] = global_element_index++;
      }

      // Build the mesh

      const atlas::idx_t remote_index_base = 1;  // 1-based indexing of Fortran

      eckit::LocalConfiguration config{};
      config.set("mpi_comm", comm_.name());

      const atlas::mesh::MeshBuilder mesh_builder{};

      atlas::Mesh mesh = mesh_builder(lons, lats,
                                      ghosts,
                                      atlas_global_indices,
                                      atlas_remote_indices,
                                      remote_index_base,
                                      partitions,
                                      tri_boundary_nodes,
                                      tri_global_indices,
                                      quad_boundary_nodes,
                                      quad_global_indices,
                                      config);

      atlas::mesh::actions::build_halo(mesh, 1);
      functionSpace_ = atlas::functionspace::NodeColumns(mesh, config);

      // Optionaly, Save output for viewing with Gmsh.
      // Enable viewing halos per task.

      if (config.getBool("gmsh save", false)) {
        std::string filename = config.getString("gmsh filename", "out.msh");
        atlas::output::Gmsh gmsh(filename,
                                 atlas::util::Config("coordinates", "xyz")
                                 | atlas::util::Config("ghost", true));
        gmsh.write(mesh);
      }
    }

    // Set ATLAS FunctionSpace in Fortran, and fill in the
    // geometry FieldSet from the fortran side.

    roms_geom_init_atlas_f90(keyGeom_,
                             functionSpace_.get(),
                             fields_.get());

    Log::trace() << classname() << ":Geometry ATLAS mesh done"
                 << std::endl;
  }

// -----------------------------------------------------------------------------
/// Geometry cloning.

  Geometry::Geometry(const Geometry & other)
    : comm_(other.comm_) {
    roms_geom_clone_f90(keyGeom_,
                        other.keyGeom_);

    functionSpace_ = atlas::functionspace::NodeColumns(other.functionSpace_);
    roms_geom_init_atlas_f90(keyGeom_,
                             functionSpace_.get(),
                             fields_.get());
  }

// -----------------------------------------------------------------------------
/// Geometry destructor.

  Geometry::~Geometry() {
    roms_geom_end_f90(keyGeom_);
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
/// It prints Geometry information.

  void Geometry::print(std::ostream & os) const {
    int nx, ny, nz;
    int tile;
    int LBi, UBi, LBj, UBj;
    int Istr, Iend, Jstr, Jend;

    roms_geom_info_f90(keyGeom_,
                       nx, ny, nz, tile,
                       LBi, UBi, LBj, UBj,
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
