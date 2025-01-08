! (C) Copyright 2020-2025 UCAR
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

USE kinds,                ONLY : kind_real

USE roms_field_mod,       ONLY : roms_field
USE roms_fieldsutils_mod, ONLY : LdebugModel2Geovals
USE roms_geom_mod,        ONLY : roms_geom
USE roms_state_mod,       ONLY : roms_state

implicit none

TYPE, PUBLIC :: roms_vc_model2geovals

  CONTAINS

  PROCEDURE :: changevar => roms_vc_model2geovals_changeVar

END TYPE roms_vc_model2geovals

PRIVATE

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

  TYPE (roms_field),                   pointer :: field_in, field_out

  integer                                      :: Nsur
  integer                                      :: counter, findex, i
  integer                                      :: in_fields, out_fields

  integer,        dimension(SIZE(xout%fields)) :: unFound

  real (kind=kind_real)                        :: stats(3)

  character (len=512)                          :: field_name

  ! Report variables to process.

  IF (LdebugModel2Geovals) THEN
    in_fields  = SIZE(xin%fields)
    IF (geom%f_comm%rank() .eq. 0)                                             &
      PRINT 10, 'ROMS_DEBUG roms_vc_model2geovals::changeVar:  Input',         &
                ' XIN  Vars = ', (xin%fields(i)%name, i=1,in_fields)
    DO i = 1, in_fields
      CALL xin%fields(i)%stats (stats)
      IF (geom%f_comm%rank() .eq. 0)                                           &
        PRINT 20, xin%fields(i)%name, stats(1), stats(2), INT(stats(3))
    END DO

    out_fields = SIZE(xout%fields)
    IF (geom%f_comm%rank() .eq. 0)                                             &
      PRINT 10, 'ROMS_DEBUG roms_vc_model2geovals::changeVar:  Input',         &
                ' XOUT Vars = ', (xout%fields(i)%name, i=1,out_fields)
    DO i = 1, out_fields
      CALL xout%fields(i)%stats (stats)
      IF (geom%f_comm%rank() .eq. 0)                                           &
        PRINT 20, xout%fields(i)%name, stats(1), stats(2), INT(stats(3))
    END DO
 10 FORMAT (a, a, *(1x,a,','))
 20 FORMAT (2x,'- ',a35,':',t43,'Min = ',1p,e22.15,',  Max = ',1p,e22.15,      &
            ',  CheckSum = ', i0)
  END IF

  ! Identity Transform: Copy state variable values with a one-to-one
  !                     relationship.

  counter = 0
  unFound = 0

  DO i = 1, SIZE(xout%fields)
    IF (xin%has(xout%fields(i)%name, findex)) THEN
      xout%fields(i)%val = xin%fields(findex)%val
    ELSE
      counter = counter + 1
      unFound(counter) = i
    END IF
  END DO

  ! Variable Changes Transform: There are unfound variables to process.

  IF (counter .gt. 0) THEN

    IF (LdebugModel2Geovals .and. (geom%f_comm%rank() .eq. 0)) THEN
      PRINT 10,'ROMS_DEBUG roms_vc_model2geovals::changeVar:  ',               &
               'unFound Vars = ', (xout%fields(unFound(i))%name, i=1,counter)
    END IF

    DO i = 1, counter

      field_name = xout%fields(unFound(i))%name

      CALL xout%get (TRIM(field_name), field_out)

      SELECT CASE (TRIM(field_name))

        CASE ('sea_surface_temperature')               !< SST

          IF (xin%has('sea_water_potential_temperature', findex)) THEN
            CALL xin%get ('sea_water_potential_temperature', field_in)
          ELSE
            CALL xin%get ('sea_water_temperature', field_in)
          END IF
          Nsur = field_in%N
          field_out%val(:,:,1) = field_in%val(:,:,Nsur)
          field_out%N = 1

        CASE ('sea_surface_salinity')                  !< SSS

          CALL xin%get ('sea_water_salinity', field_in)
          Nsur = field_in%N
          field_out%val(:,:,1) = field_in%val(:,:,Nsur)
          field_out%N = 1

        CASE DEFAULT

          !  Check only for fields in the input increment XOUT, which are
          !  associated with the observations to assimilate. Other fields
          !  do not require variable changes.

          IF (xout%has(TRIM(field_name), findex)) THEN
            CALL abor1_ftn ('roms_vc_model2geovals_changeVar: cannot '//       &
                            'find an option for processing field: '//          &
                            TRIM(field_name))
          END IF

      END SELECT

    END DO

  END IF

  ! Report debugging information.

  IF (LdebugModel2Geovals) THEN
    DO i = 1, SIZE(xout%fields)
      CALL xout%fields(i)%stats (stats)
      IF (geom%f_comm%rank() .eq. 0) THEN
        IF (i.eq.1) PRINT '(a)', 'ROMS_DEBUG roms_vc_model2geovals::'//        &
                                 'changeVar:  Output XOUT Vars:'
        PRINT 20, xout%fields(i)%name, stats(1), stats(2), INT(stats(3))
      END IF
    END DO
  END IF

END SUBROUTINE roms_vc_model2geovals_changeVar

!-------------------------------------------------------------------------------

END MODULE roms_vc_model2geovals_mod
