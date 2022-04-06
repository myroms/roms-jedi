/*
 * (C) Copyright 2017-2021 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 *
 *!
 * \brief   C++ to Fortran binding functions for creating, cloning, and
 *          destroying ROMS-JEDI **Geometry** object.
 *
 * \details These functions are used by the **Geometry** Class to create, clone
 *          destroy the application grid object.
 *
 * \author  Hernan G. Arango (Rutgers University)
 * \date    April 2021
 */

#ifndef ROMSJEDI_GEOMETRY_GEOMETRYFORTRAN_H_
#define ROMSJEDI_GEOMETRY_GEOMETRYFORTRAN_H_

#include "oops/base/Variables.h"
#include "romsjedi/Fortran.h"

// Forward declarations

namespace atlas {
  namespace field {
    class FieldSetImpl;
  }
  namespace functionspace {
    class FunctionSpaceImpl;
  }
}

namespace eckit {
  class Configuration;
}

// -----------------------------------------------------------------------------

namespace romsjedi {

  extern "C" {
    void roms_geom_create_f90(F90geom &,
                              const eckit::Configuration &,
                              const eckit::mpi::Comm *);

    void roms_geom_clone_f90(F90geom &,
                             const F90geom &);

    void roms_geom_delete_f90(F90geom &);

    void roms_geom_info_f90(const F90geom &,
                            int &, int &, int &, int &, int &, int &,
                            int &, int &, int &, int &, int &, int &);

    void roms_geom_start_end_f90(const F90geom &,
                                 int &, int &, int &, int &, int &, int &);

    void roms_geom_get_num_levels_f90(const F90geom &,
                                      const oops::Variables &,
                                      const size_t &,
                                      size_t[]);

    void roms_geom_set_atlas_lonlat_f90(const F90geom &,
                                        atlas::field::FieldSetImpl *,
                                        const bool &);

    void roms_geom_set_atlas_functionspace_pointer_f90(const F90geom &,
                                    atlas::functionspace::FunctionSpaceImpl *,
                                    atlas::functionspace::FunctionSpaceImpl *);

    void roms_geom_fill_atlas_fieldset_f90(const F90geom &,
                                           atlas::field::FieldSetImpl *);
  }
}  // namespace romsjedi

// -----------------------------------------------------------------------------

#endif  // ROMSJEDI_GEOMETRY_GEOMETRYFORTRAN_H_
