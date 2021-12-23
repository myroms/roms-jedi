! (C) Copyright 2020-2021 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
!>
!! \brief   C++ interface to Fortran **LinearGetValues** interpolation at
!!          observation locations
!!
!! \details This interface include methods to generate analytic and tangent
!!          linear state **GeoVaLs** at observation locations. It also performs
!!          the adjoint of the **GeoVaLs** interpolation.
!!
!! \author  Hernan G. Arango (Rutgers University)
!! \date    December 2021

! ------------------------------------------------------------------------------

MODULE roms_lineargetvalues_mod_c

USE iso_c_binding

USE datetime_mod
USE fckit_configuration_module, ONLY : fckit_configuration

USE ufo_locations_mod
USE ufo_geovals_mod
USE ufo_geovals_mod_c,          ONLY : ufo_geovals_registry

USE roms_fields_mod,            ONLY : roms_fields
USE roms_geom_mod,              ONLY : roms_geom
USE roms_geom_reg,              ONLY : roms_geom_registry
USE roms_increment_mod,         ONLY : roms_increment
USE roms_increment_reg,         ONLY : roms_increment_registry
USE roms_lineargetvalues_mod,   ONLY : roms_lineargetvalues
USE roms_lineargetvalues_reg,   ONLY : roms_lineargetvalues_registry
USE roms_state_mod,             ONLY : roms_state
USE roms_state_reg,             ONLY : roms_state_registry

implicit none

PRIVATE

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------

SUBROUTINE roms_lineargetvalues_create_c (c_key_self, c_key_geom, c_locs)      &
                         BIND (c, name='roms_lineargetvalues_create_f90')

  integer (c_int),       intent(inout) :: c_key_self   !< Key to self
  integer (c_int),       intent(in   ) :: c_key_geom   !< Key to geometry
  TYPE (c_ptr),   value, intent(in   ) :: c_locs       !< Obs locations

  TYPE (roms_lineargetvalues), pointer :: self
  TYPE (roms_geom),            pointer :: geom
  TYPE (ufo_locations)                 :: locs

  CALL roms_lineargetvalues_registry%init ()
  CALL roms_lineargetvalues_registry%add (c_key_self)
  CALL roms_lineargetvalues_registry%get (c_key_self, self)
  CALL roms_geom_registry%get (c_key_geom, geom)

  locs = ufo_locations(c_locs)

  CALL self%create(geom, locs)

END SUBROUTINE roms_lineargetvalues_create_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_lineargetvalues_delete_c (c_key_self)                          &
                         BIND (c, name='roms_lineargetvalues_delete_f90')

  integer (c_int),       intent(inout) :: c_key_self   !< Key to self

  TYPE (roms_lineargetvalues), pointer :: self

  CALL roms_lineargetvalues_registry%get (c_key_self, self)

  CALL self%delete ()

  CALL roms_lineargetvalues_registry%remove (c_key_self)

END SUBROUTINE roms_lineargetvalues_delete_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_lineargetvalues_set_trajectory_c (c_key_self, c_key_geom,      &
                                                  c_key_state, c_t1, c_t2,     &
                                                  c_locs, c_key_geovals)       &
                      BIND (c, name='roms_lineargetvalues_set_trajectory_f90')

  integer (c_int),          intent(in) :: c_key_self
  integer (c_int),          intent(in) :: c_key_geom
  integer (c_int),          intent(in) :: c_key_state
  TYPE (c_ptr),      value, intent(in) :: c_t1
  TYPE (c_ptr),      value, intent(in) :: c_t2
  TYPE (c_ptr),      value, intent(in) :: c_locs
  integer (c_int),          intent(in) :: c_key_geovals

  TYPE (roms_lineargetvalues), pointer :: self
  TYPE (roms_geom),            pointer :: geom
  TYPE (roms_state),           pointer :: state
  TYPE (datetime)                      :: t1
  TYPE (datetime)                      :: t2
  TYPE (ufo_locations)                 :: locs
  TYPE (ufo_geovals),          pointer :: geovals

  CALL roms_lineargetvalues_registry%get (c_key_self, self)
  CALL roms_geom_registry%get (c_key_geom, geom)
  CALL roms_state_registry%get (c_key_state, state)
  CALL c_f_datetime (c_t1, t1)
  CALL c_f_datetime (c_t2, t2)

  locs = ufo_locations (c_locs)
  CALL ufo_geovals_registry%get (c_key_geovals, geovals)

  CALL self%set_trajectory (geom, state, t1, t2, locs, geovals)

END SUBROUTINE roms_lineargetvalues_set_trajectory_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_lineargetvalues_fill_geovals_tl_c (c_key_self, c_key_geom,     &
                                                   c_key_inc, c_t1, c_t2,      &
                                                   c_locs, c_key_geovals)      &
                      BIND (c, name='roms_lineargetvalues_fill_geovals_tl_f90')

  integer (c_int),          intent(in) :: c_key_self
  integer (c_int),          intent(in) :: c_key_geom
  integer (c_int),          intent(in) :: c_key_inc
  TYPE (c_ptr),      value, intent(in) :: c_t1
  TYPE (c_ptr),      value, intent(in) :: c_t2
  TYPE (c_ptr),      value, intent(in) :: c_locs
  integer (c_int),          intent(in) :: c_key_geovals

  TYPE (roms_lineargetvalues), pointer :: self
  TYPE (roms_geom),            pointer :: geom
  TYPE (roms_increment),       pointer :: inc
  TYPE (datetime)                      :: t1
  TYPE (datetime)                      :: t2
  TYPE (ufo_locations)                 :: locs
  TYPE (ufo_geovals),          pointer :: geovals

  CALL roms_lineargetvalues_registry%get (c_key_self, self)
  CALL roms_geom_registry%get (c_key_geom, geom)
  CALL roms_increment_registry%get (c_key_inc, inc)
  CALL c_f_datetime (c_t1, t1)
  CALL c_f_datetime (c_t2, t2)

  locs = ufo_locations(c_locs)
  CALL ufo_geovals_registry%get (c_key_geovals, geovals)

  CALL self%fill_geovals_tl (geom, inc, t1, t2, locs, geovals)

END SUBROUTINE roms_lineargetvalues_fill_geovals_tl_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_lineargetvalues_fill_geovals_ad_c (c_key_self, c_key_geom,     &
                                                   c_key_inc, c_t1, c_t2,      &
                                                   c_locs, c_key_geovals)      &
                      BIND (c, name='roms_lineargetvalues_fill_geovals_ad_f90')

  integer (c_int),          intent(in) :: c_key_self
  integer (c_int),          intent(in) :: c_key_geom
  integer (c_int),          intent(in) :: c_key_inc
  TYPE (c_ptr),      value, intent(in) :: c_t1
  TYPE (c_ptr),      value, intent(in) :: c_t2
  TYPE (c_ptr),      value, intent(in) :: c_locs
  integer (c_int),          intent(in) :: c_key_geovals

  TYPE (roms_lineargetvalues), pointer :: self
  TYPE (roms_geom),            pointer :: geom
  TYPE (roms_increment),       pointer :: inc
  TYPE (datetime)                      :: t1
  TYPE (datetime)                      :: t2
  TYPE (ufo_locations)                 :: locs
  TYPE (ufo_geovals),          pointer :: geovals

  CALL roms_lineargetvalues_registry%get (c_key_self, self)
  CALL roms_geom_registry%get (c_key_geom, geom)
  CALL roms_increment_registry%get (c_key_inc, inc)
  CALL c_f_datetime (c_t1, t1)
  CALL c_f_datetime (c_t2, t2)

  locs = ufo_locations(c_locs)
  CALL ufo_geovals_registry%get (c_key_geovals, geovals)

  CALL self%fill_geovals_ad (geom, inc, t1, t2, locs, geovals)

END SUBROUTINE roms_lineargetvalues_fill_geovals_ad_c

! ------------------------------------------------------------------------------

END MODULE roms_lineargetvalues_mod_c
