!
! (C) Copyright 2019-2021 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
!>
!! \brief    **GeometryIterator** ClassFortran ROMS-JEDI interface
!!
!! \details  It implements several methods to set and get state fields values
!!           at specified application grid points.
!!
!! \author   Hernan G. Arango (Rutgers University)
!! \date     October 2021

! Hernan G. Arango, Rutgers University, Apr 2021

MODULE roms_geomIterator_mod

USE iso_c_binding

USE kinds

USE roms_geom_mod, ONLY : roms_geom

implicit none

PRIVATE

TYPE, PUBLIC :: roms_geomIterator

  TYPE (roms_geom), pointer :: geom => null()   !< Geometry
  integer :: Iindex = 1                         !< I-index, lon(Iindex,Jindex)
  integer :: Jindex = 1                         !< J-index, lat(Iindex,Jindex)
  integer :: Kindex = 1                         !< K-index, vertical dimension

  CONTAINS

  PROCEDURE :: setup   => roms_geomIterator_setup
  PROCEDURE :: clone   => roms_geomIterator_clone
  PROCEDURE :: equals  => roms_geomIterator_equals
  PROCEDURE :: current => roms_geomIterator_current
  PROCEDURE :: next    => roms_geomIterator_next

END TYPE roms_geomIterator

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
!> It sets the GeometryIterator object.

SUBROUTINE roms_geomIterator_setup (self, geom, Iindex, Jindex, Kindex)

  CLASS (roms_geomIterator),  intent(inout) :: self        !< Geometry iterator
  TYPE (roms_geom), pointer,  intent(in   ) :: geom        !< Geometry
  integer,                    intent(in   ) :: Iindex      !< I-index
  integer,                    intent(in   ) :: Jindex      !< J-index
  integer,                    intent(in   ) :: Kindex      !< K-index

  ! Associate geometry

  self%geom => geom

  ! Define iind/jind for local tile

  self%Iindex = Iindex
  self%Jindex = Jindex
  self%Kindex = Kindex

END SUBROUTINE roms_geomIterator_setup

! ------------------------------------------------------------------------------
!> It clones the GeometryIterator.

SUBROUTINE roms_geomIterator_clone (self, other)

  CLASS (roms_geomIterator), intent(inout) :: self   !< Geometry iterator
  TYPE (roms_geomIterator),  intent(in   ) :: other  !< Other geometry iterator

  ! Associate geometry.

  self%geom => other%geom

  ! Copy Iindex/Jindex/Kindex.

  self%Iindex = other%Iindex
  self%Jindex = other%Jindex
  self%Kindex = other%Kindex

END SUBROUTINE roms_geomIterator_clone

! ------------------------------------------------------------------------------
!> It checks equality betwenn two GeometryIterator objects.

SUBROUTINE roms_geomIterator_equals (self, other, equals)

  CLASS (roms_geomIterator), intent(in ) :: self    !< Geometry iterator
  TYPE (roms_geomIterator),  intent(in ) :: other   !< Other geometry iterator
  integer,                   intent(out) :: equals  !< Equality flag

  ! Initialization.

  equals = 0

  ! Check equality.

  IF (associated(self%geom, other%geom)) THEN
    SELECT CASE (self%geom%iterator_dimension)
      CASE (2)                                             ! 2D iterator
        IF ((self%Iindex .eq. other%Iindex) .and.                              &
            (self%Jindex .eq. other%Jindex)) equals = 1
      CASE (3)                                             ! 3D iterator
        IF ((self%Iindex .eq. other%Iindex) .and.                              &
            (self%Jindex .eq. other%Jindex) .and.                              &
            (self%Kindex .eq. other%Kindex)) equals = 1
      CASE DEFAULT
        CALL abor1_ftn ('roms_geomIterator::equals: ' //                       &
                        'Unknown geom%iterator_dimension')
    END SELECT
  END IF

END SUBROUTINE roms_geomIterator_equals

! ------------------------------------------------------------------------------
!> It gets GeometryIterator object current lat/lon at RHO-points.

SUBROUTINE roms_geomIterator_current (self, lon, lat, depth)

  CLASS (roms_geomIterator), intent(in ) :: self  !< GeometryIterator object
  real (kind_real),          intent(out) :: lat   !< Latitude
  real (kind_real),          intent(out) :: lon   !< Longitude
  real (kind_real),          intent(out) :: depth !< Depth

  ! Check Iindex/Jindex.

  IF ((self%Iindex .eq. -1) .and. (self%Jindex .eq. -1)) THEN

    lat = self%geom%latr(self%geom%Iend, self%geom%Jend)   ! special case
    lon = self%geom%lonr(self%geom%Iend, self%geom%Jend)   ! {-1,-1} means
                                                           ! end of the grid

  ELSE IF ((self%Iindex .lt. self%geom%Istr) .or.                              &
           (self%Iindex .gt. self%geom%Iend) .or.                              &
           (self%Jindex .lt. self%geom%Jstr) .or.                              &
           (self%Jindex .gt. self%geom%Jend)) THEN

    CALL abor1_ftn ('roms_geomIterator_current: iterator out of bounds')

  ELSE                                                     ! inside of the grid

    lat = self%geom%latr(self%Iindex, self%Jindex)
    lon = self%geom%lonr(self%Iindex, self%Jindex)

  END IF

  ! check Kindex.

  SELECT CASE (self%geom%iterator_dimension)
    CASE (2)                                               ! 2D iterator
      depth = 0.0_kind_real
    CASE (3)                                               ! 3D iterator
      IF (self%Kindex .eq. -1) THEN
        depth = self%geom%z_r(self%geom%Istr, self%geom%Jstr, self%geom%N)
      ELSE IF (self%Kindex == 0) then
        depth = 0.0_kind_real
      ELSE IF ((self%Kindex .lt. 0) .or. (self%Kindex .gt. self%geom%N)) THEN
        CALL abor1_ftn ('roms_geomIterator::current: ' //                      &
                        'depth iterator out of bounds')
      ELSE
        depth = self%geom%z_r(self%Iindex, self%Jindex, self%Kindex)
      END IF
    CASE DEFAULT
      CALL abor1_ftn ('roms_geomIterator::current: ' //                        &
                      'Unknown geom%iterator_dimension')
  END SELECT

END SUBROUTINE roms_geomIterator_current

! ------------------------------------------------------------------------------
!> It update GeometryIterator object to next point.

SUBROUTINE roms_geomIterator_next (self)

  CLASS (roms_geomIterator), intent(inout) :: self    !< GeometryIterator Object

  integer                                  :: Iindex, Jindex, Kindex

  Iindex = self%Iindex
  Jindex = self%Jindex
  Kindex = self%Kindex

  ! Increment horizontal array indices by 1

  SELECT CASE (self%geom%iterator_dimension)
    CASE (2)                                                ! 2D iterator
      IF (Iindex .lt. self%geom%Iend) THEN
        Iindex = Iindex + 1
      ELSE IF (Iindex .eq. self%geom%Iend) THEN
        Iindex = self%geom%Istr
        Jindex = Jindex + 1
      END IF

      IF (Jindex .gt. self%geom%Jend) THEN
        Iindex = -1
        Jindex = -1
      END IF
    CASE (3)                                                ! 3D iterator
      IF (Iindex .lt. self%geom%Iend) THEN
        Iindex = Iindex + 1
      ELSE IF (Iindex .eq. self%geom%Iend) THEN
        Iindex = self%geom%Istr
        IF (Jindex .lt. self%geom%Jend) THEN
          Jindex = Jindex + 1
        ELSE IF (Jindex .eq. self%geom%Jend) THEN
          Jindex = self%geom%Jstr
          Kindex = Kindex + 1
        END IF                                              ! J-loop
      END IF                                                ! I-loop

      IF (kindex .gt. self%geom%N) THEN
        Iindex = -1
        Kindex = -1
        Kindex = -1
      END IF                                                ! K-loop
    CASE DEFAULT
      CALL abor1_ftn ('roms_geomIterator::next: ' //                           &
                      'Unknown geom%iterator_dimension')      
  END SELECT

  self%Iindex = Iindex
  self%Jindex = Jindex
  self%Kindex = Kindex

END SUBROUTINE roms_geomIterator_next

! ------------------------------------------------------------------------------

END MODULE roms_geomIterator_mod
