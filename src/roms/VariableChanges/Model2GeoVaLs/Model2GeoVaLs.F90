! (C) Copyright 2020-2020 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
!>
!! \brief   Interpolates nonlinear and linearized state at observation locations
!!
!! \details These routines horizontally interpolates the nonlinear linear
!!          and tangent linear state vectors at the GeoVaLs locations:
!!          model ==> Observation.  Additionally, it performs the adjoint
!!          horizontal interpolation: Observations ==> model. Also, a change
!!          of variable is carried out if GeoVaLs has not a one-to-one
!!          relationship with the state vector.
!!
!! \author  Hernan G. Arango (Rutgers University)
!! \date    June 2021

MODULE roms_model2geovals_mod

USE iso_c_binding
USE kinds,                     ONLY : kind_real

USE roms_fields_metadata_mod
USE roms_fields_mod
USE roms_geom_mod
USE roms_geom_mod_c,           ONLY : roms_geom_registry
USE roms_increment_mod
USE roms_increment_reg
USE roms_state_mod
USE roms_state_reg

USE roms_geom_mod_c,           ONLY : roms_geom_registry

implicit none

PRIVATE

!-------------------------------------------------------------------------------
CONTAINS
!-------------------------------------------------------------------------------
!> Nonlinear kernel field transform for GeoVaLs. If the GeoVaLs has a one-to-one
!! relationship with the state vector, the field has an identity transform.

SUBROUTINE roms_model2geovals_changevar_f90 (c_key_geom,                     &
                                             c_key_xin,                      &
                                             c_key_xout)                     &
           BIND (c, name='roms_model2geovals_changevar_f90')

  integer (c_int), intent(in) :: c_key_geom          !< Key to geometry
  integer (c_int), intent(in) :: c_key_xin           !< Key to state (in)
  integer (c_int), intent(in) :: c_key_xout          !< Key to state (out)

  TYPE (roms_geom),   pointer :: geom
  TYPE (roms_state),  pointer :: xin, xout
  TYPE (roms_field),  pointer :: field
  integer                     :: Nsur, i

  CALL roms_geom_registry%get (c_key_geom, geom)
  CALL roms_state_registry%get (c_key_xin, xin)
  CALL roms_state_registry%get (c_key_xout, xout)

  DO i = 1, SIZE(xout%fields)

    SELECT CASE (xout%fields(i)%name)

      CASE ('sea_surface_temperature')                   !< SST
        CALL xin%get ('tocn', field)
        Nsur = field%N
        xout%fields(i)%val(:,:,1) = field%val(:,:,Nsur)

      CASE ('sea_surface_salinty')                       !< SSS
        CALL xin%get ('socn', field)
        Nsur = field%N
        xout%fields(i)%val(:,:,1) = field%val(:,:,Nsur)

      CASE DEFAULT                                       ! Identity Operator 
        CALL xin%get (xout%fields(i)%metadata%name, field)
        IF (field%metadata%getval_name .eq.                                  &
            xout%fields(i)%name) THEN                    !< full 3D field
          xout%fields(i)%val(:,:,:) = field%val(:,:,:)  
        ELSE IF (field%metadata%getval_name_surface .eq.                     &
                 xout%fields(i)%name) THEN               !< surface Z-index
          Nsur = field%N
          xout%fields(i)%val(:,:,1) = field%val(:,:,Nsur)
        ELSE
          CALL abor1_ftn ('roms_model2geovals_changevar_f90: error while '// &
                          ' processing '//TRIM(xout%fields(i)%name))
        END IF

    END SELECT

  END DO

END SUBROUTINE roms_model2geovals_changevar_f90

!-------------------------------------------------------------------------------
!> Tangent linear kernel field transform for GeoVaLs.

SUBROUTINE roms_model2geovals_linear_changevar_f90 (c_key_geom,              &
                                                    c_key_dxin,              &
                                                    c_key_dxout)             &
           BIND (c, name='roms_model2geovals_linear_changevar_f90')

  integer (c_int),    intent(in) :: c_key_geom       !< Key to geometry
  integer (c_int),    intent(in) :: c_key_dxin       !< Key to increment (in)
  integer (c_int),    intent(in) :: c_key_dxout      !< Key to increment (out)

  TYPE (roms_geom),      pointer :: geom
  TYPE (roms_increment), pointer :: dxin, dxout
  TYPE (roms_field),     pointer :: tl_field
  integer                        :: Nsur, i

  CALL roms_geom_registry%get (c_key_geom, geom)
  CALL roms_increment_registry%get (c_key_dxin, dxin)
  CALL roms_increment_registry%get (c_key_dxout, dxout)

  ! Identity operators

  DO i= 1, SIZE(dxout%fields)
    CALL dxin%get (dxout%fields(i)%metadata%name, tl_field)

    IF (tl_field%metadata%getval_name == dxout%fields(i)%name) THEN

      dxout%fields(i)%val(:,:,:) = tl_field%val(:,:,:)     !< full field
 
    ELSE IF (tl_field%metadata%getval_name_surface == dxout%fields(i)%name) THEN

      Nsur = tl_field%N
      dxout%fields(i)%val(:,:,1) = tl_field%val(:,:,Nsur)  !< surface field

    ELSE
      CALL abor1_ftn ('roms_model2geovals_linear_changevar_f90: error ' //   &
                      'processing ' // dxout%fields(i)%name)
    ENDIF
  END DO

END SUBROUTINE roms_model2geovals_linear_changevar_f90

!-------------------------------------------------------------------------------
!> Adjoint kernel field transform for GeoVaLs.

SUBROUTINE roms_model2geovals_linear_changevarAD_f90 (c_key_geom,            &
                                                      c_key_dxin,            &
                                                      c_key_dxout)           &
           BIND (c, name='roms_model2geovals_linear_changevarAD_f90')


  integer (c_int),    intent(in) :: c_key_geom       !< Key to geometry
  integer (c_int),    intent(in) :: c_key_dxin       !< Key to increment (in)
  integer (c_int),    intent(in) :: c_key_dxout      !< Key to increment (out)

  TYPE (roms_geom),      pointer :: geom
  TYPE (roms_increment), pointer :: dxin, dxout
  TYPE (roms_field),     pointer :: ad_field
  integer                        :: Nsur, i

  CALL roms_geom_registry%get (c_key_geom, geom)
  CALL roms_increment_registry%get (c_key_dxin, dxin)
  CALL roms_increment_registry%get (c_key_dxout, dxout)

  ! Identity operators.

  DO i= 1, SIZE(dxin%fields)
    CALL dxout%get (dxin%fields(i)%metadata%name, ad_field)

    IF (ad_field%metadata%getval_name == dxin%fields(i)%name) THEN

      ad_field%val = ad_field%val +                                          &
                     dxin%fields(i)%val                   !< full field

    ELSE IF (ad_field%metadata%getval_name_surface == dxin%fields(i)%name) THEN

      Nsur = ad_field%N
      ad_field%val(:,:,1) = ad_field%val(:,:,1) +                            &
                            dxin%fields(i)%val(:,:,Nsur)  !< surface only
    ELSE
      CALL abor1_ftn ('roms_model2geovals_linear_changevarAD_f90: error ' // &
                      'processing ' // dxin%fields(i)%name)
    END IF
  END DO

END SUBROUTINE roms_model2geovals_linear_changevarAD_f90

!-------------------------------------------------------------------------------

END MODULE
