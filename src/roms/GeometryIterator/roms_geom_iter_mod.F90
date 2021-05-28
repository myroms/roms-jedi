!
! (C) Copyright 2019-2021 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
! Hernan G. Arango, Rutgers University, Apr 2021

MODULE roms_geom_iter_mod

USE iso_c_binding
USE kinds
USE roms_geom_mod, ONLY : roms_geom

implicit none

PRIVATE

PUBLIC :: roms_geom_iter
PUBLIC :: roms_geom_iter_clone
PUBLIC :: roms_geom_iter_current
PUBLIC :: roms_geom_iter_equals
PUBLIC :: roms_geom_iter_next
PUBLIC :: roms_geom_iter_registry
PUBLIC :: roms_geom_iter_setup

TYPE :: roms_geom_iter
  TYPE (roms_geom), pointer :: geom => null()   !< Geometry
  integer :: Iind = 1                           !< I-index, e.g. lon(Iind,Jind)
  integer :: Jind = 1                           !< J-index, e.g. lat(Iind,Jind)
END TYPE roms_geom_iter

#define LISTED_TYPE roms_geom_iter

!> Linked list interface - defines registry_t type

#include "oops/util/linkedList_i.f"

!> Global registry

TYPE (registry_t) :: roms_geom_iter_registry

CONTAINS

! ------------------------------------------------------------------------------
! Public
! ------------------------------------------------------------------------------

!> Linked list implementation

#include "oops/util/linkedList_c.f"

! ------------------------------------------------------------------------------
!> Setup for the geometry iterator

SUBROUTINE roms_geom_iter_setup (self, geom, Iind, Jind)

  TYPE (roms_geom_iter),     intent(inout) :: self         !< Geometry iterator
  TYPE (roms_geom), pointer, intent(   in) :: geom         !< Geometry
  integer,                   intent(   in) :: Iind, Jind   !< I- and J-indices

  ! Associate geometry

  self%geom => geom

  ! Define iind/jind for local tile

  self%Iind = Iind
  self%Jind = Jind

END SUBROUTINE roms_geom_iter_setup

! ------------------------------------------------------------------------------
!> Clone for the geometry iterator

SUBROUTINE roms_geom_iter_clone (self, other)

  TYPE (roms_geom_iter), intent(inout) :: self    !< Geometry iterator
  TYPE (roms_geom_iter), intent(   in) :: other   !< Other geometry iterator

  ! Associate geometry

  self%geom => other%geom

  ! Copy Iind/Jind

  self%Iind = other%Iind
  self%Jind = other%Jind

END SUBROUTINE roms_geom_iter_clone

! ------------------------------------------------------------------------------
!> Check for the geometry iterator equality

SUBROUTINE roms_geom_iter_equals (self, other, equals)

  TYPE (roms_geom_iter), intent( in) :: self     !< Geometry iterator
  TYPE (roms_geom_iter), intent( in) :: other    !< Other geometry iterator
  integer,               intent(out) :: equals   !< Equality flag

  ! Initialization

  equals = 0

  ! Check equality

  IF (associated(self%geom, other%geom) .and. &
      (self%Iind == other%Iind) .and. (self%Jind == other%Jind)) THEN
    equals = 1
  END IF

END SUBROUTINE roms_geom_iter_equals

! ------------------------------------------------------------------------------
!> Get geometry iterator current lat/lon

SUBROUTINE roms_geom_iter_current (self, lon, lat)

  TYPE (roms_geom_iter), intent( in) :: self   !< Geometry iterator
  real(kind_real),       intent(out) :: lat    !< Latitude
  real(kind_real),       intent(out) :: lon    !< Longitude

  ! Check Iind/Jind

  IF ((self%Iind == -1) .and. (self%Jind == -1)) THEN

    lat = self%geom%latr(self%geom%Iend, self%geom%Jend)   ! special case {-1,-1}
    lon = self%geom%lonr(self%geom%Iend, self%geom%Jend)   ! means end of the grid

  ELSE IF ((self%Iind < self%geom%Istr) .or. (self%Iind > self%geom%Iend) .or. &
           (self%Jind < self%geom%Jstr) .or. (self%Jind > self%geom%Jend)) THEN

    CALL abor1_ftn ('roms_geom_iter_current: iterator out of bounds')

  ELSE                                                     ! inside of the grid

    lat = self%geom%latr(self%Iind, self%Jind)
    lon = self%geom%lonr(self%Iind, self%Jind)

  END IF

END SUBROUTINE roms_geom_iter_current

! ------------------------------------------------------------------------------
!> Update geometry iterator to next point

SUBROUTINE roms_geom_iter_next (self)

  TYPE (roms_geom_iter), intent(inout) :: self   !< Geometry iterator

  integer                              :: Iind, Jind

  Iind = self%Iind
  Jind = self%Jind

! DO WHILE ((Iind.lt.self%geom%Istr) .and. (Jind.lt.self%geom%Jend))

  ! increment by 1

    IF (Iind.lt.self%geom%Iend) THEN 
      Iind = Iind + 1
    ELSE IF (Iind.eq.self%geom%Iend) THEN
      Iind = self%geom%Iend
      Jind = Jind + 1
    END IF

  ! Skip this point if it is on land

!   IF (self%geom%mask2d(Iind,Jind).lt.1)     then 
!     CYCLE
!   ELSE
!     EXIT
!   END IF

! END DO

  IF (Jind > self%geom%Jend) THEN
    Iind=-1
    Jind=-1
  END IF

  self%Iind = Iind
  self%Jind = Jind

END SUBROUTINE roms_geom_iter_next

! ------------------------------------------------------------------------------

END MODULE roms_geom_iter_mod
