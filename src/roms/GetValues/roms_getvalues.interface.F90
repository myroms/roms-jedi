! (C) Copyright 2020-2021 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
!>
!! \brief   C++ interface to Fortran **GetValues** interpolation at observation
!!          locations
!!
!! \details This inteface include methods to generate analytic, nonlinear,
!!          and tangent linear state **GeoVaLs** at observation locations.
!!          It also performs tha adjoint of the **GeoVaLs** interpolation.
!!
!! \author  Hernan G. Arango (Rutgers University)
!! \date    July 2021

 MODULE roms_getvalue_mod_c

USE iso_c_binding

USE duration_mod
USE oops_variables_mod

USE datetime_mod,               ONLY : datetime, c_f_datetime
USE fckit_configuration_module, ONLY : fckit_configuration

USE roms_geom_mod,              ONLY : roms_geom
USE roms_geom_mod_c,            ONLY : roms_geom_registry
USE roms_getvalues_mod
USE roms_getvalues_reg
USE roms_state_mod
USE roms_state_reg
USE roms_increment_mod
USE roms_increment_reg

USE ufo_geovals_mod_c,          ONLY : ufo_geovals_registry
USE ufo_geovals_mod,            ONLY : ufo_geovals
USE ufo_locations_mod

implicit none

PRIVATE

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------
!> Creates GetValues object to interpolates model at observation locations.

SUBROUTINE roms_getvalues_create_c (c_key_self, c_key_geom, c_locs)          &
                              BIND (c, name='roms_getvalues_create_f90')

  integer (c_int),     intent(inout) :: c_key_self      !< Key to self
  integer (c_int),     intent(in   ) :: c_key_geom      !< Key to geometry
  TYPE (c_ptr), value, intent(in   ) :: c_locs          !< obs locations

  TYPE (roms_getvalues),     pointer :: self
  TYPE (roms_geom),          pointer :: geom
  TYPE (ufo_locations)               :: locs

! Create object

  CALL roms_getvalues_registry%init ()
  CALL roms_getvalues_registry%add (c_key_self)
  CALL roms_getvalues_registry%get (c_key_self, self)

! Others.

  CALL roms_geom_registry%get (c_key_geom, geom)
  locs = ufo_locations(c_locs)

! Call method.

  CALL self%create (geom, locs)

END SUBROUTINE roms_getvalues_create_c

! ------------------------------------------------------------------------------
!> Deletes GetValues object.

SUBROUTINE roms_getvalues_delete_c (c_key_self)                              &
                              BIND (c, name='roms_getvalues_delete_f90')

  integer (c_int), intent(inout) :: c_key_self      !< Key to self

  TYPE (roms_getvalues), pointer :: self

  ! Get object.

  CALL roms_getvalues_registry%get (c_key_self, self)

  ! Call method.

  CALL self%delete()

  ! Remove object.

  CALL roms_getvalues_registry%remove(c_key_self)

END SUBROUTINE roms_getvalues_delete_c

! ------------------------------------------------------------------------------
!> Interpolates nonlinear model at observation locations.

SUBROUTINE roms_getvalues_fill_geovals_c (c_key_self, c_key_geom,            &
                                          c_key_state, c_t1, c_t2,           &
                                          c_locs, c_key_geovals)             &
                          BIND (c, name='roms_getvalues_fill_geovals_f90')

  integer (c_int),     intent(in) :: c_key_self     !< Key to self
  integer (c_int),     intent(in) :: c_key_geom     !< Key to geometry
  integer (c_int),     intent(in) :: c_key_state    !< Key to state
  TYPE (c_ptr), value, intent(in) :: c_t1           !< Key to time window start
  TYPE (c_ptr), value, intent(in) :: c_t2           !< Key to time window end
  TYPE (c_ptr), value, intent(in) :: c_locs         !< Key to UFO obs locations
  integer (c_int),     intent(in) :: c_key_geovals  !< Key to UFO GeoVaLs object

  TYPE (roms_getvalues),  pointer :: self
  TYPE (roms_geom),       pointer :: geom
  TYPE (roms_state),      pointer :: state
  TYPE (datetime)                 :: t1
  TYPE (datetime)                 :: t2
  TYPE (ufo_locations)            :: locs
  TYPE (ufo_geovals),     pointer :: geovals

  ! Get objects.

  CALL roms_getvalues_registry%get (c_key_self, self)
  CALL roms_geom_registry%get (c_key_geom, geom)
  CALL roms_state_registry%get (c_key_state, state)
  CALL c_f_datetime (c_t1, t1)
  CALL c_f_datetime (c_t2, t2)
  locs = ufo_locations(c_locs)
  CALL ufo_geovals_registry%get (c_key_geovals, geovals)

  ! Call method.

  CALL self%fill_geovals (geom, state, t1, t2, locs, geovals)

END SUBROUTINE roms_getvalues_fill_geovals_c

! ------------------------------------------------------------------------------
!> Interpolates tangent linear model at observation locations.

SUBROUTINE roms_getvalues_fill_geovals_tl_c (c_key_self, c_key_geom,         &
                                             c_key_incr, c_t1, c_t2,         &
                                             c_locs, c_key_geovals)          &
                          BIND (c, name='roms_getvalues_fill_geovals_tl_f90')

  integer (c_int),     intent(in) :: c_key_self     !< Key to self
  integer (c_int),     intent(in) :: c_key_geom     !< Key to geometry
  integer (c_int),     intent(in) :: c_key_incr     !< Key to increment
  TYPE (c_ptr), value, intent(in) :: c_t1           !< Key to time window start
  TYPE (c_ptr), value, intent(in) :: c_t2           !< Key to time window end
  TYPE (c_ptr), value, intent(in) :: c_locs         !< Key to UFO obs locations
  integer (c_int),     intent(in) :: c_key_geovals  !< Key to UFO GeoVaLs object

  TYPE (roms_getvalues),  pointer :: self
  TYPE (roms_geom),       pointer :: geom
  TYPE (roms_increment),  pointer :: incr
  TYPE (datetime)                 :: t1
  TYPE (datetime)                 :: t2
  TYPE (ufo_locations),   pointer :: locs
  TYPE (ufo_geovals),     pointer :: geovals

! Get objects.

  CALL roms_getvalues_registry%get (c_key_self, self)
  CALL roms_geom_registry%get (c_key_geom, geom)
  CALL roms_increment_registry%get (c_key_incr, incr)
  CALL c_f_datetime (c_t1, t1)
  CALL c_f_datetime (c_t2, t2)
  locs = ufo_locations(c_locs)
  CALL ufo_geovals_registry%get (c_key_geovals, geovals)

! Call method.

  CALL self%fill_geovals(geom, incr, t1, t2, locs, geovals)

END SUBROUTINE roms_getvalues_fill_geovals_tl_c

! ------------------------------------------------------------------------------
!> Interpolates adjoint model at observation locations

SUBROUTINE roms_getvalues_fill_geovals_ad_c (c_key_self, c_key_geom,         &
                                             c_key_incr, c_t1, c_t2,         &
                                             c_locs, c_key_geovals)          &
                          BIND (c, name='roms_getvalues_fill_geovals_ad_f90')

  integer (c_int),     intent(in) :: c_key_self     !< Key to self
  integer (c_int),     intent(in) :: c_key_geom     !< Key to geometry
  integer (c_int),     intent(in) :: c_key_incr     !< Key to increment
  TYPE (c_ptr), value, intent(in) :: c_t1           !< Key to time window start
  TYPE (c_ptr), value, intent(in) :: c_t2           !< Key to time window end
  TYPE (c_ptr), value, intent(in) :: c_locs         !< Key to UFO obs locations
  integer (c_int),     intent(in) :: c_key_geovals  !< Key to UFO GeoVaLs object

  TYPE (roms_getvalues),  pointer :: self
  TYPE (roms_geom),       pointer :: geom
  TYPE (roms_increment),  pointer :: incr
  TYPE (datetime)                 :: t1
  TYPE (datetime)                 :: t2
  TYPE (ufo_locations),   pointer :: locs
  TYPE (ufo_geovals),     pointer :: geovals

! Get objects.

  CALL roms_getvalues_registry%get (c_key_self, self)
  CALL roms_geom_registry%get (c_key_geom, geom)
  CALL roms_increment_registry%get (c_key_incr, incr)
  CALL c_f_datetime (c_t1, t1)
  CALL c_f_datetime (c_t2, t2)
  locs = ufo_locations(c_locs)
  CALL ufo_geovals_registry%get (c_key_geovals, geovals)

! Call method.

  CALL self%fill_geovals_ad (geom, incr, t1, t2, locs, geovals)

END SUBROUTINE roms_getvalues_fill_geovals_ad_c

END MODULE roms_getvalue_mod_c
