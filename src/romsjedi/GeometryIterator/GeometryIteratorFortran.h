/*
 * (C) Copyright 2019-2021 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 *
 *!
 * \brief   C++ to Fortran binding functions for ROMS-JEDI **GeometryIterator**
 *          Object
 *
 * \details The **GeometryIterator** Class uses the functions below to set and
 *          get state fields values at specified application grid points.
 *
 * \author  Hernan G. Arango (Rutgers University)
 * \date    October 2021
 */

#ifndef ROMSJEDI_GEOMETRYITERATOR_GEOMETRYITERATORFORTRAN_H_
#define ROMSJEDI_GEOMETRYITERATOR_GEOMETRYITERATORFORTRAN_H_

#include "romsjedi/Fortran.h"

namespace romsjedi {

  extern "C" {
    void roms_geom_iter_setup_f90(F90iter &,
                                  const F90geom &,
                                  const int &,
                                  const int &);
    void roms_geom_iter_clone_f90(F90iter &,
                                  const F90iter &);
    void roms_geom_iter_delete_f90(F90iter &);
    void roms_geom_iter_equals_f90(const F90iter &,
                                   const F90iter &,
                                   int &);
    void roms_geom_iter_current_f90(const F90iter &,
                                    double &,
                                    double &);
    void roms_geom_iter_next_f90(const F90iter &);
  }
}  // namespace romsjedi

#endif  // ROMSJEDI_GEOMETRYITERATOR_GEOMETRYITERATORFORTRAN_H_
