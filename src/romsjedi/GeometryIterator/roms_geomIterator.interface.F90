!
! (C) Copyright 2019-2025 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
!>
!! \brief    Fortran and C++ binding interface for ROMS-JEDI GeometryIterator
!!           Class
!!
!! \details  Interoperability mechanism for the **GeometryIterator** Class that
!!           allows Fortran to invoke C++ functions and vice versa C++ to invoke
!!           Fortran procedures.
!!
!! \author   Hernan G. Arango (Rutgers University)
!! \date     October 2021

MODULE roms_geomIterator_mod_c

USE iso_c_binding

USE kinds

USE roms_geom_mod,         ONLY : roms_geom
USE roms_geom_reg,         ONLY : roms_geom_registry
USE roms_geomIterator_mod
USE roms_geomIterator_reg, ONLY : roms_geomIterator_registry

implicit none

PRIVATE

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------
  
! ------------------------------------------------------------------------------
!> Setup geometry iterator

SUBROUTINE roms_geomIterator_setup_c (c_key_self, c_key_geom,                  &
                                      c_Iindex, c_Jindex, c_Kindex)            &
                             BIND (c, name='roms_geomIterator_setup_f90')

  integer (c_int),    intent(inout) :: c_key_self   !< GeometryIterator object
  integer (c_int),    intent(in   ) :: c_key_geom   !< Geometry object
  integer (c_int),    intent(in   ) :: c_Iindex     !< I-index pointer
  integer (c_int),    intent(in   ) :: c_Jindex     !< J-index pointer
  integer (c_int),    intent(in   ) :: c_Kindex     !< K-index pointer

  TYPE (roms_geomIterator), pointer :: self
  TYPE (roms_geom),         pointer :: geom

  ! Interface

  CALL roms_geomIterator_registry%init ()
  CALL roms_geomIterator_registry%add (c_key_self)
  CALL roms_geomIterator_registry%get (c_key_self, self)
  CALL roms_geom_registry%get (c_key_geom, geom)

  ! Call Fortran routine

  CALL self%setup (geom, c_Iindex, c_Jindex, c_Kindex)

END SUBROUTINE roms_geomIterator_setup_c

! ------------------------------------------------------------------------------
!> It clones GeometryIterator object.

SUBROUTINE roms_geomIterator_clone_c (c_key_self, c_key_other)                 &
                                BIND (c, name='roms_geomIterator_clone_f90')

  integer (c_int),    intent(inout) :: c_key_self    !< GeometryIterator
  integer (c_int),    intent(in   ) :: c_key_other   !< Other GeometryIterator

  TYPE (roms_geomIterator), pointer :: self, other

  ! Interface

  CALL roms_geomIterator_registry%get (c_key_other, other)
  CALL roms_geomIterator_registry%init ()
  CALL roms_geomIterator_registry%add (c_key_self)
  CALL roms_geomIterator_registry%get (c_key_self, self)

  ! Call Fortran routine

  CALL self%clone (other)

END SUBROUTINE roms_geomIterator_clone_c

! ------------------------------------------------------------------------------
!> It deletes (deallocates) GeometryIterator object.

SUBROUTINE roms_geomIterator_delete_c (c_key_self)                             &
                                 BIND (c, name='roms_geomIterator_delete_f90')

  integer (c_int), intent(inout) :: c_key_self   !< Geometry iterator

  ! Interface.

  CALL roms_geomIterator_registry%remove (c_key_self)

END SUBROUTINE roms_geomIterator_delete_c

! ------------------------------------------------------------------------------
!> It checks equality between two GeometryIterator objects.

SUBROUTINE roms_geomIterator_equals_c (c_key_self, c_key_other, c_equals)      &
                                 BIND (c, name='roms_geomIterator_equals_f90')

  integer (c_int),    intent(inout) :: c_key_self   !< Geometry iterator
  integer (c_int),    intent(in   ) :: c_key_other  !< Other geometry iterator
  integer (c_int),    intent(inout) :: c_equals     !< Equality flag

  TYPE (roms_geomIterator), pointer :: self,other

  ! Interface.

  CALL roms_geomIterator_registry%get (c_key_self, self)
  CALL roms_geomIterator_registry%get (c_key_other, other)

  ! Call Fortran routine.

  CALL self%equals (other, c_equals)

END SUBROUTINE roms_geomIterator_equals_c

! ------------------------------------------------------------------------------
!> It gets GeometryIterator current lat/lon locations.

SUBROUTINE roms_geomIterator_current_c (c_key_self, c_lon, c_lat, c_depth)     &
                               BIND (c, name='roms_geomIterator_current_f90')

  integer (c_int),    intent(in   ) :: c_key_self   !< GeometryIterator object
  real (c_double),    intent(inout) :: c_lat        !< Latitude
  real (c_double),    intent(inout) :: c_lon        !< Longitude
  real (c_double),    intent(inout) :: c_depth      !< Depth

  TYPE (roms_geomIterator), pointer :: self

  ! Interface.

  CALL roms_geomIterator_registry%get (c_key_self, self)

  ! Call Fortran routine.

  CALL self%current (c_lon, c_lat, c_depth)

END SUBROUTINE roms_geomIterator_current_c

! ------------------------------------------------------------------------------
!> It updates GeometryIterator to next point.

SUBROUTINE roms_geomIterator_next_c (c_key_self)                               &
                               BIND (c, name='roms_geomIterator_next_f90')

  integer (c_int),       intent(in) :: c_key_self   !< GeometryIterator object

  TYPE (roms_geomIterator), pointer :: self

  ! Interface.

  CALL roms_geomIterator_registry%get (c_key_self, self)

  ! Call Fortran routine.

  CALL self%next ()

END SUBROUTINE roms_geomIterator_next_c

! ------------------------------------------------------------------------------
!> Sets the dimension of the iterator: 2D or 3D. 

SUBROUTINE roms_geomIterator_dimension_c (c_key_geom, c_val)                   &
                             BIND (c, name='roms_geomIterator_dimension_f90')

  integer (c_int),      intent( in) :: c_key_geom   !< GeometryIterator object
  integer (c_int),      intent(out) :: c_val

  TYPE (roms_geom),         pointer :: geom

  CALL roms_geom_registry%get (c_key_geom, geom)

  c_val = geom%iterator_dimension               ! [2] = 2D,  [3] = 3D 

END SUBROUTINE roms_geomIterator_dimension_c

! ------------------------------------------------------------------------------

END MODULE roms_geomIterator_mod_c
