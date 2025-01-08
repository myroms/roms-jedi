! (C) Copyright 2020-2025 UCAR
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

!> ROMS-JEDI interface module association.

USE roms_field_mod,             ONLY : roms_field
USE roms_fieldsutils_mod,       ONLY : LdebugLinearModel2Geovals
USE roms_geom_mod,              ONLY : roms_geom
USE roms_increment_mod,         ONLY : roms_increment
USE roms_state_mod,             ONLY : roms_state

implicit none

!-------------------------------------------------------------------------------

TYPE, PUBLIC :: roms_lvc_model2geovals

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

  ! TODO: If background trajectory is required, get needed fields from state.

END SUBROUTINE roms_lvc_model2geovals_create

!-------------------------------------------------------------------------------
!> It destroys the Linear Variable Change to GeoVaLs object.

SUBROUTINE roms_lvc_model2geovals_delete (self)

  CLASS (roms_lvc_model2geovals), intent(inout) :: self  !< VarChange object

  ! TODO: If fields are defined in the object deallocate them here.

END SUBROUTINE roms_lvc_model2geovals_delete

! ------------------------------------------------------------------------------
!> It applies the multiply operator for the Linear Variable Change from
!  Model-to-GeoVaLs increments.

SUBROUTINE roms_lvc_model2geovals_multiply (self, geom, dxm, dxg)

  CLASS (roms_lvc_model2geovals), intent(inout) :: self  !< LinVarChange object
  TYPE (roms_geom),               intent(inout) :: geom  !< Geometry object
  TYPE (roms_increment),          intent(in   ) :: dxm   !< Model Increment
  TYPE (roms_increment),          intent(inout) :: dxg   !< GeoVaLs Increment

  TYPE (roms_field),                    pointer :: field_in, field_out

  integer                                       :: N, Nsur
  integer                                       :: counter, findex, i
  integer                                       :: inp_fields, out_fields

  integer,          dimension(SIZE(dxg%fields)) :: unFound

  real (kind=kind_real)                         :: stats(3)

  character (len=512)                           :: field_name

  ! Report variables to process.

  IF (LdebugLinearModel2Geovals) THEN
    inp_fields = SIZE(dxm%fields)
    IF (geom%f_comm%rank() .eq. 0)                                             &
      PRINT 10, 'ROMS_DEBUG roms_lvc_model2geovals::multiply:  Input',         &
                ' DXM Vars = ', (dxm%fields(i)%name, i=1,inp_fields)
    DO i = 1, inp_fields
      CALL dxm%fields(i)%stats (stats)
      IF (geom%f_comm%rank() .eq. 0)                                           &
        PRINT 20, dxm%fields(i)%name, stats(1), stats(2), INT(stats(3))
    END DO

    out_fields = SIZE(dxg%fields)
    IF (geom%f_comm%rank() .eq. 0)                                             &
      PRINT 10, 'ROMS_DEBUG roms_lvc_model2geovals::multiply:  Input',         &
                ' DXG Vars = ', (dxg%fields(i)%name, i=1,out_fields)
    DO i = 1, out_fields
      CALL dxg%fields(i)%stats (stats)
      IF (geom%f_comm%rank() .eq. 0)                                           &
        PRINT 20, dxg%fields(i)%name, stats(1), stats(2), INT(stats(3))
    END DO
 10 FORMAT (a, a, *(1x,a,','))
 20 FORMAT (2x,'- ',a35,':',t43,'Min = ',1p,e22.15,',  Max = ',1p,e22.15,      &
            ',  CheckSum = ', i0)
  END IF

  ! Identity Transform: Copy state variable values with a one-to-one
  !                     relationship.

  counter = 0
  unFound = 0

  DO i = 1, SIZE(dxg%fields)
    IF (dxm%has(dxg%fields(i)%name, findex)) THEN
      dxg%fields(i)%val = dxm%fields(findex)%val
    ELSE
      counter = counter + 1
      unFound(counter) = i
    END IF
  END DO

  ! Variable Changes Transform: There are unfound variables to process.

  IF (counter .gt. 0) THEN

    IF (LdebugLinearModel2Geovals .and. (geom%f_comm%rank() .eq. 0)) THEN
      PRINT 10,'ROMS_DEBUG roms_lvc_model2geovals::multiply:  ',               &
               'unFound Vars = ', (dxg%fields(unFound(i))%name, i=1,counter)
    END IF

    DO i = 1, counter

      field_name = dxg%fields(unFound(i))%name

      CALL dxg%get (TRIM(field_name), field_out)

      SELECT CASE (TRIM(field_name))

        CASE ('sea_surface_temperature')               !< SST

          IF (dxm%has('sea_water_potential_temperature', findex)) THEN
            CALL dxm%get ('sea_water_potnetial_temperature', field_in)
          ELSE
            CALL dxm%get ('sea_water_temperature', field_in)
          END IF
          Nsur = field_in%N
          field_out%val(:,:,1) = field_in%val(:,:,Nsur)
!         field_out%N = 1

        CASE ('sea_surface_salinity')                  !< SSS

          CALL dxm%get ('sea_water_salinity', field_in)
          Nsur = field_in%N
          field_out%val(:,:,1) = field_in%val(:,:,Nsur)
!         field_out%N = 1

        CASE DEFAULT

          CALL abor1_ftn ('roms_lvc_model2geovals_multiply: cannot find '//    &
                          'an option for processing field: '//TRIM(field_name))

      END SELECT

    END DO

  END IF  

  ! Report debugging information.

  IF (LdebugLinearModel2Geovals) THEN
    DO i = 1, SIZE(dxg%fields)
      CALL dxg%fields(i)%stats (stats)
      IF (geom%f_comm%rank() .eq. 0) THEN
        IF (i.eq.1) PRINT '(a)', 'ROMS_DEBUG roms_lvc_model2geovals::'//       &
                                 'multiply:  Output DXG Vars:'
        PRINT 20, dxg%fields(i)%name, stats(1), stats(2), INT(stats(3))
      END IF
    END DO
  END IF

END SUBROUTINE roms_lvc_model2geovals_multiply

! ------------------------------------------------------------------------------
!> It applies the adjoint multiply operator for the Linear Variable Change from
!  Model-to-GeoVaLs increments.

SUBROUTINE roms_lvc_model2geovals_multiplyAD (self, geom, dxg, dxm)

  CLASS (roms_lvc_model2geovals), intent(inout) :: self  !< VarChange object
  TYPE (roms_geom),               intent(in   ) :: geom  !< Geometry object
  TYPE (roms_increment),          intent(in   ) :: dxg   !< GeoVaLs Increment
  TYPE (roms_increment),          intent(inout) :: dxm   !< Model Increment

  TYPE (roms_field),                    pointer :: field_in, field_out

  integer                                       :: N, Nsur
  integer                                       :: counter, findex, i
  integer                                       :: inp_fields, out_fields

  integer,          dimension(SIZE(dxm%fields)) :: unFound

  real (kind=kind_real)                         :: stats(3)

  character (len=512)                           :: field_name

  ! Report variables to process.

  IF (LdebugLinearModel2Geovals) THEN
    inp_fields = SIZE(dxg%fields)
    IF (geom%f_comm%rank() .eq. 0)                                             &
      PRINT 10, 'ROMS_DEBUG roms_lvc_model2geovals::multiplyAD:  Input',       &
                ' DXG Vars = ', (dxg%fields(i)%name, i=1,inp_fields)
    DO i = 1, inp_fields
      CALL dxg%fields(i)%stats (stats)
      IF (geom%f_comm%rank() .eq. 0)                                           &
        PRINT 20, dxg%fields(i)%name, stats(1), stats(2), INT(stats(3))
    END DO

    out_fields = SIZE(dxm%fields)
    IF (geom%f_comm%rank() .eq. 0)                                             &
      PRINT 10, 'ROMS_DEBUG roms_lvc_model2geovals::multiplyAD:  Input',       &
                ' DXM Vars = ', (dxm%fields(i)%name, i=1,out_fields)
    DO i = 1, out_fields
      CALL dxm%fields(i)%stats (stats)
      IF (geom%f_comm%rank() .eq. 0)                                           &
        PRINT 20, dxm%fields(i)%name, stats(1), stats(2), INT(stats(3))
    END DO
 10 FORMAT (a, a, *(1x,a,','))
 20 FORMAT (2x,'- ',a35,':',t43,'Min = ',1p,e22.15,',  Max = ',1p,e22.15,      &
            ',  CheckSum = ', i0)
  END IF

  ! Apply the required adjoint variable change to variables in the DXM vector.
  ! In most cases, the number of variables in the DXM increment vector is larger
  ! the than in the DXG increment vector, which contains only fields associated
  ! with the observations for a particular data assimilation cycle.

  counter = 0
  unFound = 0

  DO i = 1, SIZE(dxm%fields)
    IF (dxg%has(dxm%fields(i)%name, findex)) THEN
      dxm%fields(i)%val = dxm%fields(i)%val + dxg%fields(findex)%val
    ELSE
      counter = counter + 1
      unFound(counter) = i
    END IF
  END DO

  ! Variable Changes Transform: There are unfound variables to process.

  IF (counter .gt. 0) THEN

    IF (LdebugLinearModel2Geovals .and. (geom%f_comm%rank() .eq. 0)) THEN
      PRINT 10,'ROMS_DEBUG roms_lvc_model2geovals::multiplyAD:  ',               &
               'unFound Vars = ', (dxm%fields(unFound(i))%name, i=1,counter)
    END IF

    DO i = 1, counter

      field_name = dxm%fields(unFound(i))%name

      CALL dxm%get (TRIM(field_name), field_out)

      SELECT CASE (TRIM(field_name))

        CASE ('sea_surface_temperature')               !< SST

          IF (dxg%has('sea_water_potential_temperature', findex)) THEN
            CALL dxg%get ('sea_water_potential_temperature', field_in)
          ELSE
            CALL dxg%get ('sea_water_temperature', field_in)
          END IF
          Nsur = field_in%N
          field_out%val(:,:,1) = field_out%val(:,:,1) + field_in%val(:,:,Nsur)
!         field_out%N = 1

        CASE ('sea_surface_salinity')                  !< SSS

          CALL dxg%get ('sea_water_salinity', field_in)
          Nsur = field_in%N
          field_out%val(:,:,1) = field_out%val(:,:,1) + field_in%val(:,:,Nsur)
!         field_out%N = 1

        CASE DEFAULT

          !  Check only for fields in the input increment DXG, which are
          !  associated with the observations to assimilate. Other fields
          !  do not require variable changes.

          IF (dxg%has(TRIM(field_name), findex)) THEN
            CALL abor1_ftn ('roms_lvc_model2geovals_multiplyAD: cannot ' //    &
                            'find an option for processing field: ' //         &
                            TRIM(field_name))
          END IF

      END SELECT

    END DO

  END IF

  ! Report debugging information.

  IF (LdebugLinearModel2Geovals) THEN
    DO i = 1, SIZE(dxm%fields)
      CALL dxm%fields(i)%stats (stats)
      IF (geom%f_comm%rank() .eq. 0) THEN
        IF (i.eq.1) PRINT '(a)', 'ROMS_DEBUG roms_lvc_model2geovals::'//       &
                                 'multiplyAD:  Output DXM Vars:'
        PRINT 20, dxm%fields(i)%name, stats(1), stats(2), INT(stats(3))
      END IF
    END DO
  END IF

END SUBROUTINE roms_lvc_model2geovals_multiplyAD

! ------------------------------------------------------------------------------

END MODULE roms_lvc_model2geovals_mod
