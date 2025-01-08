/*
 * (C) Copyright 2017-2025 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef ROMSJEDI_FORTRAN_H_
#define ROMSJEDI_FORTRAN_H_

namespace romsjedi {

  typedef int F90bmat;        // ErrorCovariance key type
  typedef int F90flds;        // Fields key type
  typedef int F90geom;        // Geometry key type
  typedef int F90getval;      // GetValues key type
  typedef int F90goms;        // GeoVaLs key type
  typedef int F90iter;        // GeometryIterator key type
  typedef int F90lingetval;   // LinearGetValues key type
  typedef int F90lm;          // LinearModel key type
  typedef int F90lvc_M2G;     // LinearVarChange Model2GeoVaLs key type
  typedef int F90model;       // Model key type
  typedef int F90traj;        // LinearModel trajectory key type
  typedef int F90varchange;   // VarChange key type
  typedef int F90vc_M2G;      // VarChange Model2GeoVaLs key type

}  // namespace romsjedi

#endif  // ROMSJEDI_FORTRAN_H_
