! (C) Copyright 2020-2025 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
!>
!! \brief    Fortran and C++ binding interface for Model2Analysis Linear
!!           Variable Change
!!
!! \details  Interoperability mechanism for the Model2Analysis Linear Variable
!!           Change Class that allows Fortran to invoke C++ functions and vice
!!           versa C++ to invoke Fortran procedures.
!!
!! \author   Hernan G. Arango (Rutgers University)
!! \date     November 2024

MODULE roms_lvc_model2analysis_c

USE iso_c_binding

USE fckit_configuration_module, ONLY : fckit_configuration

!> ROMS-JEDI interface module association

USE roms_geom_mod,               ONLY : roms_geom
USE roms_geom_reg,               ONLY : roms_geom_registry
USE roms_increment_mod,          ONLY : roms_increment
USE roms_increment_reg,          ONLY : roms_increment_registry
USE roms_lvc_model2analysis_mod, ONLY : roms_lvc_model2analysis
USE roms_lvc_model2analysis_reg, ONLY : roms_lvc_model2analysis_registry
USE roms_state_mod,              ONLY : roms_state
USE roms_state_reg,              ONLY : roms_state_registry

implicit none

PRIVATE

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
!> Binding interface to the multiply operator for the Linear Variable Change
!! from Model-to-Analysis increments.

SUBROUTINE roms_lvc_model2analysis_multiply_c (c_key_self,                     &
                                               c_key_geom,                     &
                                               c_key_dxmod,                    &
                                               c_key_dxana)                    &
                BIND (c, name='roms_lvc_model2analysis_multiply_f90')

  integer (c_int),          intent(inout) :: c_key_self   !< LinVarCha object
  integer (c_int),          intent(in   ) :: c_key_geom   !< Geometry object
  integer (c_int),          intent(in   ) :: c_key_dxmod  !< Model Increment
  integer (c_int),          intent(in   ) :: c_key_dxana  !< Analyis Increment

  TYPE (roms_lvc_model2analysis), pointer :: self
  TYPE (roms_geom),               pointer :: geom
  TYPE (roms_increment),          pointer :: dxmod
  TYPE (roms_increment),          pointer :: dxana

  CALL roms_lvc_model2analysis_registry%init ()
  CALL roms_lvc_model2analysis_registry%add (c_key_self)
  CALL roms_lvc_model2analysis_registry%get (c_key_self, self)

  CALL roms_geom_registry%get (c_key_geom, geom)
  CALL roms_increment_registry%get (c_key_dxmod, dxmod)
  CALL roms_increment_registry%get (c_key_dxana, dxana)

  CALL self%multiply (geom, dxmod, dxana)

END SUBROUTINE roms_lvc_model2analysis_multiply_c

! ------------------------------------------------------------------------------
!> Binding interface to the adjoint multiply operator for the Linear Variable
!! change from Model-to-Analysis increments.

SUBROUTINE roms_lvc_model2analysis_multiplyAD_c (c_key_self,                   &
                                                 c_key_geom,                   &
                                                 c_key_dxana,                  &
                                                 c_key_dxmod)                  &
                BIND (c, name='roms_lvc_model2analysis_multiplyAD_f90')

  integer (c_int),             intent(in) :: c_key_self   !< LinVarCha object
  integer (c_int),             intent(in) :: c_key_geom   !< geometry object
  integer (c_int),             intent(in) :: c_key_dxana  !< Analysis Increment
  integer (c_int),             intent(in) :: c_key_dxmod  !< Model Increment

  TYPE (roms_lvc_model2analysis), pointer :: self
  TYPE (roms_geom),               pointer :: geom
  TYPE (roms_increment),          pointer :: dxana
  TYPE (roms_increment),          pointer :: dxmod

  CALL roms_lvc_model2analysis_registry%get (c_key_self, self)
  CALL roms_geom_registry%get (c_key_geom, geom)
  CALL roms_increment_registry%get (c_key_dxana, dxana)
  CALL roms_increment_registry%get (c_key_dxmod, dxmod)

  CALL self%multiplyAD (geom, dxana, dxmod)

END SUBROUTINE roms_lvc_model2analysis_multiplyAD_c

! ------------------------------------------------------------------------------
!> Binding interface to the multiply operator for the Linear Variable change
!! from Model-to-Analysis increments.

SUBROUTINE roms_lvc_model2analysis_multiplyInverse_c (c_key_self,              &
                                                      c_key_geom,              &
                                                      c_key_dxana,             &
                                                      c_key_dxmod)             &
                BIND (c, name='roms_lvc_model2analysis_multiplyInverse_f90')

  integer (c_int),          intent(inout) :: c_key_self   !< LinVarCha object
  integer (c_int),             intent(in) :: c_key_geom   !< geometry object
  integer (c_int),             intent(in) :: c_key_dxana  !< Analysis Increment
  integer (c_int),             intent(in) :: c_key_dxmod  !< Model Increment

  TYPE (roms_lvc_model2analysis), pointer :: self
  TYPE (roms_geom),               pointer :: geom
  TYPE (roms_increment),          pointer :: dxana
  TYPE (roms_increment),          pointer :: dxmod

  ! HGA: For some reason, I need to add to registry again to avoid 
  ! a segementation error in "linkedList_c.f" line 61 due to "Attempt
  ! to use pointer NEXT when it is not associated with a target". Weird!

  CALL roms_lvc_model2analysis_registry%add (c_key_self)
  CALL roms_lvc_model2analysis_registry%get (c_key_self, self)

  CALL roms_geom_registry%get (c_key_geom, geom)
  CALL roms_increment_registry%get (c_key_dxana, dxana)
  CALL roms_increment_registry%get (c_key_dxmod, dxmod)

  CALL self%multiplyInverse (geom, dxana, dxmod)

END SUBROUTINE roms_lvc_model2analysis_multiplyInverse_c

! ------------------------------------------------------------------------------
!> Binding interface to the adjoint multiply inverse operator for the Linear
!! Variable change from Model-to-Analysis increments.

SUBROUTINE roms_lvc_model2analysis_multiplyInverseAD_c (c_key_self,            &
                                                        c_key_geom,            &
                                                        c_key_dxmod,           &
                                                        c_key_dxana)           &
                BIND (c, name='roms_lvc_model2analysis_multiplyInverseAD_f90')

  integer (c_int),             intent(in) :: c_key_self   !< LinVarCha object
  integer (c_int),             intent(in) :: c_key_geom   !< geometry object
  integer (c_int),             intent(in) :: c_key_dxmod  !< Model Increment
  integer (c_int),             intent(in) :: c_key_dxana  !< Analysis Increment

  TYPE (roms_lvc_model2analysis), pointer :: self
  TYPE (roms_geom),               pointer :: geom
  TYPE (roms_increment),          pointer :: dxmod
  TYPE (roms_increment),          pointer :: dxana

  CALL roms_lvc_model2analysis_registry%get (c_key_self, self)
  CALL roms_geom_registry%get (c_key_geom, geom)
  CALL roms_increment_registry%get (c_key_dxmod, dxmod)
  CALL roms_increment_registry%get (c_key_dxana, dxana)

  CALL self%multiplyInverseAD (geom, dxmod, dxana)

END SUBROUTINE roms_lvc_model2analysis_multiplyInverseAD_c

! ------------------------------------------------------------------------------

END MODULE roms_lvc_model2analysis_c
