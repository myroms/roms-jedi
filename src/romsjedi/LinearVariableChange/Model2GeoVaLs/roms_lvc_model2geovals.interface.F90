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

MODULE roms_lvc_model2geovals_c

USE iso_c_binding

USE fckit_configuration_module, ONLY : fckit_configuration


USE roms_geom_mod,              ONLY : roms_geom
USE roms_geom_reg,              ONLY : roms_geom_registry
USE roms_increment_mod,         ONLY : roms_increment
USE roms_increment_reg,         ONLY : roms_increment_registry
USE roms_state_mod,             ONLY : roms_state
USE roms_state_reg,             ONLY : roms_state_registry
USE roms_lvc_model2geovals_mod, ONLY : roms_lvc_model2geovals
USE roms_lvc_model2geovals_reg, ONLY : roms_lvc_model2geovals_registry

implicit none

PRIVATE

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

!-------------------------------------------------------------------------------
!> Binding interface to create the Linear Variable Change to GeoVaLs object.

SUBROUTINE roms_lvc_model2geovals_create_c (c_key_self,                        &
                                            c_key_geom,                        &
                                            c_key_bg,                          &
                                            c_key_fg,                          &
                                            c_conf)                            &
                          BIND (c, name='roms_lvc_model2geovals_create_f90')

  integer (c_int),         intent(inout) :: c_key_self  !< Key to self object
  integer (c_int),         intent(in   ) :: c_key_geom  !< Key to geometry
  integer (c_int),         intent(in   ) :: c_key_bg    !< Key to background
  integer (c_int),         intent(in   ) :: c_key_fg    !< Key to foreground
  TYPE (c_ptr),     value, intent(in   ) :: c_conf      !< Key to configuration

  TYPE (roms_lvc_model2geovals), pointer :: self
  TYPE (roms_geom),              pointer :: geom
  TYPE (roms_state),             pointer :: bg
  TYPE (roms_state),             pointer :: fg
  TYPE (fckit_configuration)             :: conf

  CALL roms_lvc_model2geovals_registry%init ()
  CALL roms_lvc_model2geovals_registry%add (c_key_self)
  CALL roms_lvc_model2geovals_registry%get (c_key_self, self)
  CALL roms_geom_registry%get (c_key_geom, geom)
  CALL roms_state_registry%get (c_key_bg, bg)
  CALL roms_state_registry%get (c_key_fg, fg)

  conf = fckit_configuration(c_conf)

  CALL self%create (geom, bg, fg, conf)

END SUBROUTINE roms_lvc_model2geovals_create_c

!-------------------------------------------------------------------------------
!> Binding interface to destroy the Linear Variable Change to GeoVaLs object.

SUBROUTINE roms_lvc_model2geovals_delete_c (c_key_self)                        &
                          BIND (c, name='roms_lvc_model2geovals_delete_f90')

  INTEGER (c_int),         intent(inout) :: c_key_self  !< Key to self object

  TYPE (roms_lvc_model2geovals), pointer :: self

  CALL roms_lvc_model2geovals_registry%get (c_key_self, self)

  CALL self%delete ()

  CALL roms_lvc_model2geovals_registry%remove (c_key_self)

END SUBROUTINE roms_lvc_model2geovals_delete_c

! ------------------------------------------------------------------------------
!> Binding interface to the multiply operator for the Linear Variable Change to
!  GeoVaLs object.

SUBROUTINE roms_lvc_model2geovals_multiply_c (c_key_self,                      &
                                              c_key_geom,                      &
                                              c_key_dxin,                      &
                                              c_key_dxout)                     &
                          BIND (c, name='roms_lvc_model2geovals_multiply_f90')

  integer (c_int),            intent(in) :: c_key_self  !< Key to self object
  integer (c_int),            intent(in) :: c_key_geom  !< Key to Geometry
  integer (c_int),            intent(in) :: c_key_dxin  !< Key to Increment
  integer (c_int),            intent(in) :: c_key_dxout !< Key to Increment

  TYPE (roms_lvc_model2geovals), pointer :: self
  TYPE (roms_geom),              pointer :: geom
  TYPE (roms_increment),         pointer :: dxin
  TYPE (roms_increment),         pointer :: dxout

  CALL roms_lvc_model2geovals_registry%get (c_key_self, self)
  CALL roms_geom_registry%get (c_key_geom, geom)
  CALL roms_increment_registry%get (c_key_dxin, dxin)
  CALL roms_increment_registry%get (c_key_dxout, dxout)

  CALL self%multiply (geom, dxin, dxout)

END SUBROUTINE roms_lvc_model2geovals_multiply_c

! ------------------------------------------------------------------------------
!> Binding interface to the adjoint multiply operator for the Linear Variable
!  Change to GeoVaLs object.

SUBROUTINE roms_lvc_model2geovals_multiplyAD_c (c_key_self,                    &
                                                c_key_geom,                    &
                                                c_key_dxin,                    &
                                                c_key_dxout)                   &
                BIND (c, name='roms_lvc_model2geovals_multiplyAD_f90')

  integer (c_int),            intent(in) :: c_key_self  !< Key to self object
  integer (c_int),            intent(in) :: c_key_geom  !< Key to geometry
  integer (c_int),            intent(in) :: c_key_dxin  !< Key to Increment
  integer (c_int),            intent(in) :: c_key_dxout !< Key to Increment

  TYPE (roms_lvc_model2geovals), pointer :: self
  TYPE (roms_geom),              pointer :: geom
  TYPE (roms_increment),         pointer :: dxin
  TYPE (roms_increment),         pointer :: dxout

  CALL roms_lvc_model2geovals_registry%get (c_key_self, self)
  CALL roms_geom_registry%get (c_key_geom, geom)
  CALL roms_increment_registry%get (c_key_dxin, dxout)
  CALL roms_increment_registry%get (c_key_dxin, dxout)

  CALL self%multiplyAD (geom, dxin, dxout)

END SUBROUTINE roms_lvc_model2geovals_multiplyAD_c

! ------------------------------------------------------------------------------

END MODULE roms_lvc_model2geovals_c
