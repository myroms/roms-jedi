!
! (C) Copyright 2017-2021 UCAR
! 
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0. 
!
!>
!! \brief   Interface to Fortran **GeoVaLs** analytical state initialization
!!
!! \details The interface takes an existing GeoVaLs object and fill values of
!!          the ROMS state fields with analytical expression. It is only
!!          processed when the keyword **analytic_init** is found in the
!!          YAML configurations. It is intended for testing the interpolation
!!          of the state at the observation locations.
!!
!! \author  Hernan G. Arango (Rutgers University)
!! \date    July 2021

MODULE ROMS_analyticinit_mod_c

USE iso_c_binding
USE kinds,                      ONLY : kind_real

USE roms_analyticinit_mod,      ONLY : roms_analytic_init

USE ufo_geovals_mod,            ONLY : ufo_geovals
USE ufo_geovals_mod_c,          ONLY : ufo_geovals_registry
USE ufo_locations_mod,          ONLY : ufo_locations

implicit none

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------
!> Analytic initialization of GeoVaLs.

SUBROUTINE roms_analytic_init_c (c_key_geovals, c_locs, T0, S0, U0, V0)      &
                           BIND (c, name='roms_analytic_init_f90')

  integer (c_int),       intent(in) :: c_key_geovals  !< Key to UFO GeoVaLs
  TYPE (c_ptr), value,   intent(in) :: c_locs         !< Key to UFO locations
  real (kind=kind_real), intent(in) :: T0             !< background temperature
  real (kind=kind_real), intent(in) :: S0             !< background salinity
  real (kind=kind_real), intent(in) :: U0             !< background U-velocity
  real (kind=kind_real), intent(in) :: V0             !< background V-velocity

  TYPE (ufo_geovals), pointer     :: geovals
  TYPE (ufo_locations)            :: locs

  ! Get objects.

  CALL ufo_geovals_registry%get (c_key_geovals, geovals)
  locs = ufo_locations(c_locs)

  ! Call method

  CALL roms_analytic_init (geovals, locs, T0, S0, U0, V0)

END SUBROUTINE roms_analytic_init_c

! ------------------------------------------------------------------------------

END MODULE roms_analyticinit_mod_c
