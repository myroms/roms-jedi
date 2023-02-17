! (C) Copyright 2020-2023 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
!>
!! \brief   Nonlinear state variable change needed for GeoVals
!!
!! \details These routines perform the required variable transform of the
!!          nonlinear state vector needed for the interpolation of the
!!          observations at the GeoVals locations.
!!
!! \author  Hernan G. Arango (Rutgers University)
!! \date    June 2021

MODULE roms_vc_model2geovals_mod

USE kinds,               ONLY : kind_real

USE roms_field_mod,      ONLY : roms_field
USE roms_geom_mod,       ONLY : roms_geom
USE roms_state_mod,      ONLY : roms_state

implicit none

TYPE, PUBLIC :: roms_vc_model2geovals

  CONTAINS

  PROCEDURE :: changevar => roms_vc_model2geovals_changeVar

END TYPE roms_vc_model2geovals

PRIVATE

! Switch for printing fields information during debugging.

logical :: LdebugModel2Geovals = .FALSE.

!-------------------------------------------------------------------------------
CONTAINS
!-------------------------------------------------------------------------------

!-------------------------------------------------------------------------------
!> Nonlinear kernel field transform for GeoVaLs. If the GeoVaLs has a one-to-one
!! relationship with the state vector, the field has an identity transform.

SUBROUTINE roms_vc_model2geovals_changeVar (self, geom, xin, xout)

  CLASS (roms_vc_model2geovals), intent(inout) :: self
  TYPE (roms_geom),              intent(in   ) :: geom
  TYPE (roms_state),             intent(in   ) :: xin
  TYPE (roms_state),             intent(inout) :: xout

  TYPE (roms_field),                   pointer :: field
  integer                                      :: Nsur, i

  ! Apply the require variable change.

  DO i = 1, SIZE(xout%fields)

    IF (LdebugModel2Geovals .and. (geom%f_comm%rank() .eq. 0)) THEN
      PRINT '(8a)', 'ROMS_DEBUG roms_vc_model2geovals::changeVar: '//          &
                    'field name = ', xout%fields(i)%name,                      &
                    ', metadata%name = ',                                      &
                    xout%fields(i)%metadata%name,                              &
                    ', metadata%getval_name = ',                               &
                    xout%fields(i)%metadata%getval_name,                       &
                    ', metadata%getval_name_surface = ',                       &
                    xout%fields(i)%metadata%getval_name_surface
    END IF

    SELECT CASE (xout%fields(i)%name)

      CASE ('sea_surface_temperature')                  !< SST
        CALL xin%get ('tocn', field)
        Nsur = field%N
        xout%fields(i)%val(:,:,1) = field%val(:,:,Nsur)

      CASE ('sea_surface_salinty')                      !< SSS
        CALL xin%get ('socn', field)
        Nsur = field%N
        xout%fields(i)%val(:,:,1) = field%val(:,:,Nsur)

      CASE ('model_level_depth_at_cell_center')
        CALL xin%get ('zocn_r', field)
        xout%fields(i)%val = field%val

      CASE ('unvarying_model_level_depth_at_cell_center')
        CALL xin%get ('z0ocn_r', field)
        xout%fields(i)%val = field%val

      CASE DEFAULT                                       ! Identity Operator 
        CALL xin%get (xout%fields(i)%metadata%name, field)
        IF (field%metadata%getval_name .eq.                                    &
            xout%fields(i)%name) THEN                    !< full 3D field
          xout%fields(i)%val(:,:,:) = field%val(:,:,:)  
        ELSE IF (field%metadata%getval_name_surface .eq.                       &
                 xout%fields(i)%name) THEN               !< surface Z-index
          Nsur = field%N
          xout%fields(i)%val(:,:,1) = field%val(:,:,Nsur)
        ELSE
          CALL abor1_ftn ('roms_vc_model2geovals_changevar: error while '//    &
                          'processing field: '//TRIM(xout%fields(i)%name))
        END IF

    END SELECT

  END DO

END SUBROUTINE roms_vc_model2geovals_changeVar

!-------------------------------------------------------------------------------

END MODULE roms_vc_model2geovals_mod
