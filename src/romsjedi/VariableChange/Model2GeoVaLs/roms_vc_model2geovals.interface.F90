! (C) Copyright 2020-2021 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
!>
!! \brief    Fortran and C++ binding interface for Model2GeoVaLs variable change
!!
!! \details  Interoperability mechanism for the Model2GeoVals variable change
!!           Class that allows Fortran to invoke C++ functions and vice versa
!!           C++ to invoke Fortran procedures.
!!
!! \author   Hernan G. Arango (Rutgers University)
!! \date     December 2021

MODULE roms_vc_model2geovals_c

USE iso_c_binding

USE roms_geom_mod,             ONLY : roms_geom
USE roms_geom_reg,             ONLY : roms_geom_registry
USE roms_state_mod,            ONLY : roms_state
USE roms_state_reg,            ONLY : roms_state_registry
USE roms_vc_model2geovals_mod, ONLY : roms_vc_model2geovals
USE roms_vc_model2geovals_reg, ONLY : roms_vc_model2geovals_registry

implicit none

PRIVATE

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
!>  Perform variable change for Model2GeoVaLs.

SUBROUTINE roms_vc_model2geovals_changevar_c (c_key_self, c_key_geom,          &
                                              c_key_xin, c_key_xout)           &
                         BIND (c, name='roms_vc_model2geovals_changevar_f90')

  integer (c_int),        intent(inout) :: c_key_self  !< Model2Geoval object
  integer (c_int),        intent(in   ) :: c_key_geom  !< Geometry object
  integer (c_int),        intent(in   ) :: c_key_xin   !< State (in)  object
  integer (c_int),        intent(inout) :: c_key_xout  !< State (out) object

  TYPE (roms_vc_model2geovals), pointer :: self
  TYPE (roms_geom),             pointer :: geom
  TYPE (roms_state),            pointer :: xin
  TYPE (roms_state),            pointer :: xout

  CALL roms_geom_registry%get (c_key_geom, geom)
  CALL roms_state_registry%get (c_key_xin, xin)
  CALL roms_state_registry%get (c_key_xout, xout)

  CALL roms_vc_model2geovals_registry%init ()
  CALL roms_vc_model2geovals_registry%add (c_key_self)
  CALL roms_vc_model2geovals_registry%get (c_key_self, self)

  CALL self%changevar (geom, xin, xout)

END SUBROUTINE roms_vc_model2geovals_changevar_c

! ------------------------------------------------------------------------------

END MODULE roms_vc_model2geovals_c
