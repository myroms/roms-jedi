!
! (C) Copyright 2019-2021 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
! Hernan G. Arango, Rutgers University, Apr 2021

MODULE roms_geom_iter_interface

USE iso_c_binding
USE kinds
USE roms_geom_iter_mod
USE roms_geom_mod_c,   ONLY : roms_geom_registry
USE roms_geom_mod,     ONLY : roms_geom

implicit none

PRIVATE

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------
  
! ------------------------------------------------------------------------------
!> Setup geometry iterator

SUBROUTINE roms_geom_iter_setup_c (c_key_self, c_key_geom, c_iindex, c_jindex) &
                             BIND (c, name='roms_geom_iter_setup_f90')

  integer(c_int),  intent(inout) :: c_key_self   !< Geometry iterator
  integer(c_int),  intent(   in) :: c_key_geom   !< Geometry
  integer(c_int),  intent(   in) :: c_iindex     !< Index
  integer(c_int),  intent(   in) :: c_jindex     !< Index

  TYPE (roms_geom_iter), pointer :: self
  TYPE (roms_geom),      pointer :: geom

  ! Interface

  CALL roms_geom_iter_registry%init ()
  CALL roms_geom_iter_registry%add (c_key_self)
  CALL roms_geom_iter_registry%get (c_key_self, self)
  CALL roms_geom_registry%get (c_key_geom, geom)

  ! Call Fortran routine

  CALL roms_geom_iter_setup (self, geom, c_iindex, c_jindex)

END SUBROUTINE roms_geom_iter_setup_c

! ------------------------------------------------------------------------------
!> Clone geometry iterator

SUBROUTINE roms_geom_iter_clone_c (c_key_self, c_key_other) &
                             BIND (c, name='roms_geom_iter_clone_f90')

  integer(c_int),  intent(inout) :: c_key_self    !< Geometry iterator
  integer(c_int),  intent(   in) :: c_key_other   !< Other geometry iterator

  ! Local variables

  TYPE (roms_geom_iter), pointer :: self, other

  ! Interface

  CALL roms_geom_iter_registry%get (c_key_other, other)
  CALL roms_geom_iter_registry%init ()
  CALL roms_geom_iter_registry%add (c_key_self)
  CALL roms_geom_iter_registry%get (c_key_self, self)

  ! Call Fortran routine

  CALL roms_geom_iter_clone (self, other)

END SUBROUTINE roms_geom_iter_clone_c

! ------------------------------------------------------------------------------
!> Delete geometry iterator

SUBROUTINE roms_geom_iter_delete_c (c_key_self) &
                              BIND (c, name='roms_geom_iter_delete_f90')

  integer(c_int), intent(inout) :: c_key_self   !< Geometry iterator

  ! Clear interface

  CALL roms_geom_iter_registry%remove (c_key_self)

END SUBROUTINE roms_geom_iter_delete_c

! ------------------------------------------------------------------------------
!> Check geometry iterator equality

SUBROUTINE roms_geom_iter_equals_c (c_key_self, c_key_other, c_equals) &
                              BIND (c, name='roms_geom_iter_equals_f90')

  integer(c_int),  intent(inout) :: c_key_self   !< Geometry iterator
  integer(c_int),  intent(   in) :: c_key_other  !< Other geometry iterator
  integer(c_int),  intent(inout) :: c_equals     !< Equality flag

! Local variables

  TYPE (roms_geom_iter), pointer :: self,other

! Interface

  CALL roms_geom_iter_registry%get (c_key_self, self)
  CALL roms_geom_iter_registry%get (c_key_other, other)

! Call Fortran routine

  CALL roms_geom_iter_equals (self, other, c_equals)

END SUBROUTINE roms_geom_iter_equals_c

! ------------------------------------------------------------------------------
!> Get geometry iterator current lat/lon

SUBROUTINE roms_geom_iter_current_c (c_key_self, c_lon, c_lat) &
                               BIND (c, name='roms_geom_iter_current_f90')

  integer(c_int),  intent(   in) :: c_key_self   !< Geometry iterator
  real(c_double),  intent(inout) :: c_lat        !< Latitude
  real(c_double),  intent(inout) :: c_lon        !< Longitude

  ! Local variables

  TYPE (roms_geom_iter), pointer :: self

  ! Interface

  CALL roms_geom_iter_registry%get (c_key_self, self)

  ! Call Fortran routine

  CALL roms_geom_iter_current (self, c_lon, c_lat)

END SUBROUTINE roms_geom_iter_current_c

! ------------------------------------------------------------------------------
!> Update geometry iterator to next point

SUBROUTINE roms_geom_iter_next_c (c_key_self) &
                            BIND (c, name='roms_geom_iter_next_f90')

  integer(c_int),     intent(in) :: c_key_self   !< Geometry iterator

  TYPE (roms_geom_iter), pointer :: self

  ! Interface

  CALL roms_geom_iter_registry%get (c_key_self, self)

  ! Call Fortran routine

  CALL roms_geom_iter_next (self)

END SUBROUTINE roms_geom_iter_next_c

! ------------------------------------------------------------------------------

END MODULE roms_geom_iter_interface
