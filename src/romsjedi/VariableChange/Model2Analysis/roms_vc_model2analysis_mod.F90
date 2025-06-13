! (C) Copyright 2020-2025 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
!>
!! \brief   Nonlinear state variable change needed for Model2Analysis
!!
!! \details These routines perform the required variable transforms from
!!          Control to Analysis state vectors.
!!
!! \author  Hernan G. Arango (Rutgers University)
!! \date    November 2024

MODULE roms_vc_model2analysis_mod

USE kinds,                ONLY : kind_real

!> ROMS-JEDI interface module association.

USE roms_field_mod,       ONLY : roms_field
USE roms_fieldsutils_mod, ONLY : LdebugModel2Analysis
USE roms_geom_mod,        ONLY : roms_geom
USE roms_state_mod,       ONLY : roms_state
USE roms_utils_mod,       ONLY : vector_c_to_a,                                &
                                 vector_a_to_c

implicit none

TYPE, PUBLIC :: roms_vc_model2analysis

  CONTAINS

  PROCEDURE :: changeVar        => roms_vc_model2analysis_changeVar
  PROCEDURE :: changeVarInverse => roms_vc_model2analysis_changeVarInverse

END TYPE roms_vc_model2analysis

PRIVATE

!-------------------------------------------------------------------------------
CONTAINS
!-------------------------------------------------------------------------------

!-------------------------------------------------------------------------------
!> Perform required variable changes for Model to Analysis fields in the 
!! control state vector. If the Model2Analysis has a one-to-one relationship,
!! the field has an identity transform. 

SUBROUTINE roms_vc_model2analysis_changeVar (self, geom, xmod, xana)

  CLASS (roms_vc_model2analysis), intent(inout) :: self
  TYPE (roms_geom),               intent(in   ) :: geom
  TYPE (roms_state),              intent(in   ) :: xmod
  TYPE (roms_state),              intent(inout) :: xana

  TYPE (roms_field),                    pointer :: field
  TYPE (roms_field),                    pointer :: Uc, Vc

  logical                                       :: have_uaocn, have_vaocn
  logical                                       :: need_uaocn, need_vaocn

  integer                                       :: counter, findex, i
  integer                                       :: inp_fields, out_fields

  integer,         dimension(SIZE(xana%fields)) :: unFound

  real (kind=kind_real)                         :: stats(4)
  real (kind=kind_real),            allocatable :: Ua(:,:,:), Va(:,:,:)

  character (len=512)                           :: field_name

  ! Report variables to process.

  IF (LdebugModel2Analysis) THEN
    inp_fields  = SIZE(xmod%fields)
    IF (geom%f_comm%rank() .eq. 0)                                             &
      PRINT 10, 'ROMS_DEBUG roms_vc_model2analysis::changeVar:  Input',        &
                ' XMOD Vars = ', (xmod%fields(i)%name, i=1,inp_fields)
    DO i = 1, inp_fields
      CALL xmod%fields(i)%stats (stats)
      IF (geom%f_comm%rank() .eq. 0)                                           &
        PRINT 20, xmod%fields(i)%name, stats(1), stats(2), INT(stats(4))
    END DO

    out_fields = SIZE(xana%fields)
    IF (geom%f_comm%rank() .eq. 0)                                             &
      PRINT 10, 'ROMS_DEBUG roms_vc_model2analysis::changeVar:  Input',        &
                ' XANA Vars = ', (xana%fields(i)%name, i=1,out_fields)
    DO i = 1, out_fields
      CALL xana%fields(i)%stats (stats)
      IF (geom%f_comm%rank() .eq. 0)                                           &
        PRINT 20, xana%fields(i)%name, stats(1), stats(2), INT(stats(4))
    END DO
 10 FORMAT (a, a, *(1x,a,','))
 20 FORMAT (2x,'- ',a35,':',t43,'Min = ',1p,e22.15,',  Max = ',1p,e22.15,      &
            ',  CheckSum = ', i0)
  END IF

  ! Identity Transform: Copy state variable values with a one-to-one
  !                     relationship.

  counter = 0
  unFound = 0

  DO i = 1, SIZE(xana%fields)
    IF (xmod%has(xana%fields(i)%name, findex)) THEN
      xana%fields(i)%val = xmod%fields(findex)%val
    ELSE
      counter = counter + 1
      unFound(counter) = i
    END IF
  END DO

  ! Variable Changes Transform: There are unfound variables to process.

  IF (counter .gt. 0) THEN

    IF (LdebugModel2Analysis .and. (geom%f_comm%rank() .eq. 0)) THEN
      PRINT 10,'ROMS_DEBUG roms_vc_model2analysis::changeVar:  ',              &
               'unFound Vars = ', (xana%fields(unFound(i))%name, i=1,counter)
    END IF

    need_uaocn = xana%has('eastward_sea_water_velocity') .and.                 &
                 xmod%has('sea_water_x_velocity')
    need_vaocn = xana%has('northward_sea_water_velocity') .and.                &
                 xmod%has('sea_water_y_velocity')

    have_uaocn = .FALSE.
    have_vaocn = .FALSE.

    IF (need_uaocn .or. need_vaocn) THEN
      CALL xmod%get ('sea_water_x_velocity', Uc)
      CALL xmod%get ('sea_water_y_velocity', Vc)

      allocate ( Ua(geom%LBi:geom%UBi, geom%LBj:geom%UBj, geom%N) )
      allocate ( Va(geom%LBi:geom%UBi, geom%LBj:geom%UBj, geom%N) )

      Ua = 0.0_kind_real
      Va = 0.0_kind_real

      CALL vector_c_to_a (geom, Uc%val, Vc%val, Ua, Va)
      have_uaocn = .TRUE.
      have_vaocn = .TRUE.
    END IF

    ! Load the required variable changes.  

    DO i = 1, counter

      field_name = xana%fields(unFound(i))%metadata%name

      CALL xana%get (TRIM(field_name), field)

      SELECT CASE (TRIM(field_name))

        CASE ('eastward_sea_water_velocity')         !< A-grid

          IF (have_uaocn) THEN
            field%val = Ua
          END IF

        CASE ('northward_sea_water_velocity')        !< A-grid

          IF (have_vaocn) THEN
            field%val = Va
          END IF

        CASE DEFAULT

          CALL abor1_ftn ('roms_vc_model2analysis_changeVar: error while '//   &
                          'processing field: '//TRIM(field_name))

      END SELECT

    END DO

    IF ( allocated(Ua) )      deallocate (Ua)
    IF ( allocated(Va) )      deallocate (Va)

  END IF  

  ! Report debugging information.

  IF (LdebugModel2Analysis) THEN
    DO i = 1, SIZE(xana%fields)
      CALL xana%fields(i)%stats (stats)
      IF (geom%f_comm%rank() .eq. 0) THEN
        IF (i.eq.1) PRINT '(a)', 'ROMS_DEBUG roms_vc_model2analysis::'//       &
                                 'changeVar:  Output XANA Vars:'
        PRINT 20, xana%fields(i)%name, stats(1), stats(2), INT(stats(4))
      END IF
    END DO
  END IF

END SUBROUTINE roms_vc_model2analysis_changeVar

!-------------------------------------------------------------------------------
!> Perform required variable changes for Analysis to Model fields in the 
!! control state vector. If the Model2Analysis has a one-to-one relationship,
!! the field has an identity transform. 
!! It is the reverse transformation of "roms_vc_model2analysis_changeVar".

SUBROUTINE roms_vc_model2analysis_changeVarInverse (self, geom, xmod, xana)

  CLASS (roms_vc_model2analysis), intent(inout) :: self
  TYPE (roms_geom),               intent(in   ) :: geom
  TYPE (roms_state),              intent(in   ) :: xana
  TYPE (roms_state),              intent(inout) :: xmod

  TYPE (roms_field),                    pointer :: field
  TYPE (roms_field),                    pointer :: Ua, Va

  logical                                       :: have_uocn, have_vocn
  logical                                       :: need_uocn, need_vocn

  integer                                       :: counter, findex, i
  integer                                       :: inp_fields, out_fields

  integer,         dimension(SIZE(xmod%fields)) :: unFound

  real (kind=kind_real)                         :: stats(4)
  real (kind=kind_real),            allocatable :: Uc(:,:,:), Vc(:,:,:)

  character (len=512)                           :: field_name

  ! Report variables to process.

  IF (LdebugModel2Analysis) THEN
    inp_fields  = SIZE(xana%fields)
    IF (geom%f_comm%rank() .eq. 0)                                             &
      PRINT 10, 'ROMS_DEBUG roms_vc_model2analysis::changeVarInverse:  Input', &
                ' XANA Vars = ', (xana%fields(i)%name, i=1,inp_fields)
    DO i = 1, inp_fields
      CALL xana%fields(i)%stats (stats)
      IF (geom%f_comm%rank() .eq. 0)                                           &
        PRINT 20, xana%fields(i)%name, stats(1), stats(2), INT(stats(4))
    END DO

    out_fields = SIZE(xmod%fields)
    IF (geom%f_comm%rank() .eq. 0)                                             &
      PRINT 10, 'ROMS_DEBUG roms_vc_model2analysis::changeVarInverse:  Input', &
                ' XMOD Vars = ', (xmod%fields(i)%name, i=1,out_fields)
    DO i = 1, out_fields
      CALL xmod%fields(i)%stats (stats)
      IF (geom%f_comm%rank() .eq. 0)                                           &
        PRINT 20, xmod%fields(i)%name, stats(1), stats(2), INT(stats(4))
    END DO
 10 FORMAT (a, a, *(1x,a,','))
 20 FORMAT (2x,'- ',a35,':',t43,'Min = ',1p,e22.15,',  Max = ',1p,e22.15,      &
            ',  CheckSum = ', i0)
  END IF


  ! Identity Transform: Copy state variable values with a one-to-one
  !                     relationship.

  counter = 0
  unFound = 0

  DO i = 1, SIZE(xmod%fields)
    IF (xana%has(xmod%fields(i)%name, findex)) THEN
      xmod%fields(i)%val = xana%fields(findex)%val
    ELSE
      counter = counter + 1
      unFound(counter) = i
    END IF
  END DO

  ! Variable Changes Transform: There are unfound variables to process.

  IF (counter .gt. 0) THEN

    IF (LdebugModel2Analysis .and. (geom%f_comm%rank() .eq. 0)) THEN
      PRINT 10,'ROMS_DEBUG roms_vc_model2analysis::changeVarInverse:  ',       &
               'unFound Vars = ', (xmod%fields(unFound(i))%name, i=1,counter)
    END IF

    need_uocn = xmod%has('sea_water_x_velocity') .and.                         &
                xana%has('eastward_sea_water_velocity')
    need_vocn = xmod%has('sea_water_y_velocity') .and.                         &
                xana%has('northward_sea_water_velocity')

    have_uocn = .FALSE.
    have_vocn = .FALSE.

    IF (need_uocn .or. need_vocn) THEN
      CALL xana%get ('eastward_sea_water_velocity',  Ua)
      CALL xana%get ('northward_sea_water_velocity', Va)

      allocate ( Uc(geom%LBi:geom%UBi, geom%LBj:geom%UBj, geom%N) )
      allocate ( Vc(geom%LBi:geom%UBi, geom%LBj:geom%UBj, geom%N) )

      Uc = 0.0_kind_real
      Vc = 0.0_kind_real

      CALL vector_a_to_c (geom, Ua%val, Va%val, Uc, Vc)
      have_uocn = .TRUE.
      have_vocn = .TRUE.
    END IF

    ! Load the required variable changes.  

    DO i = 1, counter

      field_name = xmod%fields(unFound(i))%metadata%name

      CALL xmod%get (TRIM(field_name), field)

      SELECT CASE (TRIM(field_name))

        CASE ('sea_water_x_velocity')                !< C-grid

          IF (have_uocn) THEN
            field%val = Uc
          END IF

        CASE ('sea_water_y_velocity')                !< C-grid

          IF (have_vocn) THEN
            field%val = Vc
          END IF

        CASE DEFAULT

          CALL abor1_ftn ('roms_vc_model2analysis_changeVarInverse: error'//   &
                          ' while processing field: '//TRIM(field_name))

      END SELECT

    END DO

    IF ( allocated(Uc) )  deallocate (Uc)
    IF ( allocated(Vc) )  deallocate (Vc)

  END IF  

  ! Report debugging information.

  IF (LdebugModel2Analysis) THEN
    DO i = 1, SIZE(xmod%fields)
      CALL xmod%fields(i)%stats (stats)
      IF (geom%f_comm%rank() .eq. 0) THEN
        IF (i.eq.1) PRINT '(a)', 'ROMS_DEBUG roms_vc_model2analysis::'//       &
                                 'changeVarInverse:  Output XMOD Vars:'
        PRINT 20, xmod%fields(i)%name, stats(1), stats(2), INT(stats(4))
      END IF
    END DO
  END IF

END SUBROUTINE roms_vc_model2analysis_changeVarInverse

!-------------------------------------------------------------------------------

END MODULE roms_vc_model2analysis_mod
