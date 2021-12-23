! (C) Copyright 2020-2021 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
!>
!! \brief   Linearized state variable change needed for GeoVals
!!
!! \details These routines perform the required variable transform of the
!!          linearized state vector(TL and AD) needed for the interpolation
!!          of the observations at the GeoVals locations.
!!
!! \author  Hernan G. Arango (Rutgers University)
!! \date    December 2021

MODULE roms_lvc_model2geovals_mod

USE iso_c_binding
USE kinds,                      ONLY : kind_real

USE fckit_configuration_module, ONLY : fckit_configuration

USE roms_geom_mod,              ONLY : roms_geom
USE roms_increment_mod,         ONLY : roms_increment
USE roms_state_mod,             ONLY : roms_state

implicit none

TYPE, PUBLIC :: roms_lvc_model2geovals

  integer :: ng                            ! nested grid number
  integer :: tile                          ! domain parallel partition tile

  integer :: LBi, UBi, LBj, UBj, LBk, UBk  ! array(i,j,k) allocation bounds
  integer :: N                             ! number of vertical levels

  integer :: IstrR, IendR, JstrR, JendR    ! tile RHO-cell full indices range
  integer :: Istr,  Iend,  Jstr,  Jend     ! computational RHO-indices
  integer :: IstrU, JstrV                  ! computational U- and V-indices

  CONTAINS

  PROCEDURE :: create     => roms_lvc_model2geovals_create
  PROCEDURE :: delete     => roms_lvc_model2geovals_delete
  PROCEDURE :: multiply   => roms_lvc_model2geovals_multiply
  PROCEDURE :: multiplyAD => roms_lvc_model2geovals_multiplyAD

END TYPE roms_lvc_model2geovals

PRIVATE

!-------------------------------------------------------------------------------
CONTAINS
!-------------------------------------------------------------------------------

!-------------------------------------------------------------------------------
!> It creates the Linear Variable Change to GeoVaLs object.

SUBROUTINE roms_lvc_model2geovals_create (self, geom, bg, fg, conf)

  CLASS (roms_lvc_model2geovals), intent(inout) :: self  !< VarChange object
  TYPE (roms_geom),               intent(in   ) :: geom  !< Geometry
  TYPE (roms_state),              intent(in   ) :: bg    !< Background State
  TYPE (roms_state),              intent(in   ) :: fg    !< Foreground State
  TYPE (fckit_configuration),     intent(in   ) :: conf  !< Configuration

  !> Domain decomposition ranges and indices.

  self%ng   = geom%ng
  self%tile = geom%tile

  self%LBi = geom%LBi                   ! lower bound I-dimension
  self%UBi = geom%UBi                   ! upper bound I-dimension
  self%LBj = geom%LBj                   ! lower bound J-dimension
  self%UBj = geom%UBj                   ! upper bound J-dimension

  self%N   = geom%N                     ! number of vertical levels
  self%LBk = 1                          ! lower bound K-dimension
  self%UBk = geom%N                     ! upper bound K-dimension

  self%IstrR = geom%IstrR               ! full range I-starting (RHO-points)
  self%IendR = geom%IendR               ! full range I-ending   (RHO-points)
  self%JstrR = geom%JstrR               ! full range J-starting (RHO-points)
  self%JendR = geom%JendR               ! full range J-ending   (RHO-points)

  self%Istr = geom%Istr                 ! full range I-starting (PSI-, U-points)
  self%Iend = geom%Iend                 ! full range I-ending   (PSI-points)
  self%Jstr = geom%Jstr                 ! full range J-starting (PSI-, V-points)
  self%Jend = geom%Jend                 ! full range J-ending   (PSI-points)

  self%IstrU = geom%IstrU               ! computational I-starting (U-points)
  self%JstrV = geom%JstrV               ! computational J-starting (V-points)

  ! TODO: If background trajectory is required, get needed fields from state.

END SUBROUTINE roms_lvc_model2geovals_create

!-------------------------------------------------------------------------------
!> It destroys the Linear Variable Change to GeoVaLs object.

SUBROUTINE roms_lvc_model2geovals_delete (self)

  CLASS (roms_lvc_model2geovals), intent(inout) :: self  !< VarChange object

  ! TODO: If fields are defined in the object deallocate them here.

END SUBROUTINE roms_lvc_model2geovals_delete

! ------------------------------------------------------------------------------
!> It applies the multiply operator for the Linear Variable Change to
!  GeoVaLs object.

SUBROUTINE roms_lvc_model2geovals_multiply (self, geom, dxm, dxg)

  CLASS (roms_lvc_model2geovals), intent(inout) :: self  !< VarChange object
  TYPE (roms_geom),               intent(inout) :: geom  !< Geometry
  TYPE (roms_increment),          intent(in   ) :: dxm   !< Increment (in)
  TYPE (roms_increment),          intent(inout) :: dxg   !< Increment (out)

  ! TODO: For now, apply identity operator.

  dxg = dxm

END SUBROUTINE roms_lvc_model2geovals_multiply

! ------------------------------------------------------------------------------
!> It applies the adjoint multiply operator for the Linear Variable Change to
!  GeoVaLs object.

SUBROUTINE roms_lvc_model2geovals_multiplyAD (self, geom, dxg, dxm)

  CLASS (roms_lvc_model2geovals), intent(inout) :: self  !< VarChange object
  TYPE (roms_geom),               intent(inout) :: geom  !< Geometry
  TYPE (roms_increment),          intent(in   ) :: dxg   !< Increment (in)
  TYPE (roms_increment),          intent(inout) :: dxm   !< Increment (out)

  ! TODO: For now, apply identity operator.

  dxm = dxg

END SUBROUTINE roms_lvc_model2geovals_multiplyAD

!-------------------------------------------------------------------------------

END MODULE roms_lvc_model2geovals_mod
