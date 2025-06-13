! (C) Copyright 2018-2025 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
!>
!! \brief    Fortran and C++ binding interface for Model2Analysis variable change
!!
!! \details  Interoperability mechanism for the Model2GeoVals variable change
!!           Class that allows Fortran to invoke C++ functions and vice versa
!!           C++ to invoke Fortran procedures.
!!
!! \author   Hernan G. Arango (Rutgers University)
!! \date     December 2024

MODULE roms_vc_model2analysis_c

USE iso_c_binding

USE roms_geom_mod,              ONLY : roms_geom
USE roms_geom_reg,              ONLY : roms_geom_registry
USE roms_state_mod,             ONLY : roms_state
USE roms_state_reg,             ONLY : roms_state_registry
USE roms_vc_model2analysis_mod, ONLY : roms_vc_model2analysis
USE roms_vc_model2analysis_reg, ONLY : roms_vc_model2analysis_registry

implicit none

PRIVATE

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
!>  Perform variable change for Model2Analysis: Control to Analysis vector.

SUBROUTINE roms_vc_model2analysis_changeVar_c (c_key_self, c_key_geom,         &
                                               c_key_xctl, c_key_xana)         &
                        BIND (c, name='roms_vc_model2analysis_changeVar_f90')

  integer (c_int),        intent(inout) :: c_key_self  !< Model2Geoval object
  integer (c_int),        intent(in   ) :: c_key_geom  !< Geometry object
  integer (c_int),        intent(in   ) :: c_key_xctl  !< State control object
  integer (c_int),        intent(inout) :: c_key_xana  !< State analysis object

  TYPE (roms_vc_model2analysis), pointer :: self
  TYPE (roms_geom),              pointer :: geom
  TYPE (roms_state),             pointer :: xctl
  TYPE (roms_state),             pointer :: xana

  CALL roms_vc_model2analysis_registry%init ()
  CALL roms_vc_model2analysis_registry%add (c_key_self)
  CALL roms_vc_model2analysis_registry%get (c_key_self, self)

  CALL roms_geom_registry%get (c_key_geom, geom)
  CALL roms_state_registry%get (c_key_xctl, xctl)
  CALL roms_state_registry%get (c_key_xana, xana)

  CALL self%changeVar (geom, xctl, xana)

END SUBROUTINE roms_vc_model2analysis_changeVar_c

! ------------------------------------------------------------------------------
!>  Perform inverse variable change for Model2Analysis: Analysis to Control
!>  vector

SUBROUTINE roms_vc_model2analysis_changeVarInverse_c (c_key_self, c_key_geom,  &
                                                      c_key_xana, c_key_xctl)  &
                 BIND (c, name='roms_vc_model2analysis_changeVarInverse_f90')

  integer (c_int),        intent(inout) :: c_key_self  !< Model2Geoval object
  integer (c_int),        intent(in   ) :: c_key_geom  !< Geometry object
  integer (c_int),        intent(in   ) :: c_key_xana  !< State analysis object
  integer (c_int),        intent(inout) :: c_key_xctl  !< State control object

  TYPE (roms_vc_model2analysis), pointer :: self
  TYPE (roms_geom),              pointer :: geom
  TYPE (roms_state),             pointer :: xana
  TYPE (roms_state),             pointer :: xctl

  CALL roms_vc_model2analysis_registry%get (c_key_self, self)

  CALL roms_geom_registry%get (c_key_geom, geom)
  CALL roms_state_registry%get (c_key_xana, xana)
  CALL roms_state_registry%get (c_key_xctl, xctl)

  CALL self%changeVarInverse (geom, xana, xctl)

END SUBROUTINE roms_vc_model2analysis_changeVarInverse_c

! ------------------------------------------------------------------------------

END MODULE roms_vc_model2analysis_c
