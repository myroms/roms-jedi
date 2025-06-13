! (C) Copyright 2020-2025 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
!>
!! \brief   Linear increment variable change needed for Model2Analysis
!!
!! \details These routines perform the required variable transform from the
!!          Model to Analysis increments.
!!
!! \author  Hernan G. Arango (Rutgers University)
!! \date    November 2024

MODULE roms_lvc_model2analysis_mod

USE iso_c_binding

USE kinds,                      ONLY : kind_real

!> ROMS-JEDI interface module association.

USE roms_field_mod,             ONLY : roms_field
USE roms_fieldsutils_mod,       ONLY : LdebugLinearModel2Analysis
USE roms_geom_mod,              ONLY : roms_geom
USE roms_increment_mod,         ONLY : roms_increment
USE roms_state_mod,             ONLY : roms_state
USE roms_utils_mod,             ONLY : vector_c_to_a,                          &
                                       vector_c_to_a_ad

implicit none

!-------------------------------------------------------------------------------

TYPE, PUBLIC :: roms_lvc_model2analysis

  CONTAINS

  PROCEDURE :: multiply          => roms_lvc_model2analysis_multiply
  PROCEDURE :: multiplyAD        => roms_lvc_model2analysis_multiplyAD
  PROCEDURE :: multiplyInverse   => roms_lvc_model2analysis_multiplyInverse
  PROCEDURE :: multiplyInverseAD => roms_lvc_model2analysis_multiplyInverseAD

END TYPE roms_lvc_model2analysis

PRIVATE

!-------------------------------------------------------------------------------
CONTAINS
!-------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
!> It applies the multiply operator for the Linear Variable Change to
!! Model2Analysis increment.

SUBROUTINE roms_lvc_model2analysis_multiply (self, geom, dxmod, dxana)

  CLASS (roms_lvc_model2analysis), intent(inout) :: self  !< LinVarCha object
  TYPE (roms_geom),                intent(in   ) :: geom  !< Geometry object
  TYPE (roms_increment),           intent(in   ) :: dxmod !< Increment (in)
  TYPE (roms_increment),           intent(inout) :: dxana !< Increment (out)

  TYPE (roms_field),                     pointer :: field
  TYPE (roms_field),                     pointer :: Uc, Vc

  logical                                        :: have_uaocn, have_vaocn
  logical                                        :: need_uaocn, need_vaocn

  integer                                        :: counter, findex, i
  integer                                        :: inp_fields, out_fields

  integer,         dimension(SIZE(dxana%fields)) :: unFound

  real (kind=kind_real)                          :: stats(4)
  real (kind=kind_real),             allocatable :: Ua(:,:,:), Va(:,:,:)

  character (len=512)                            :: field_name

  ! Report variables to process.

  IF (LdebugLinearModel2Analysis) THEN
    inp_fields = SIZE(dxmod%fields)
    IF (geom%f_comm%rank() .eq. 0)                                             &
      PRINT 10, 'ROMS_DEBUG roms_lvc_model2analysis::multiply:  Input',        &
              ' DXMOD Vars = ', (dxmod%fields(i)%metadata%name, i=1,inp_fields)
    DO i = 1, inp_fields
      CALL dxmod%fields(i)%stats (stats)
      IF (geom%f_comm%rank() .eq. 0)                                           &
      PRINT 20, dxmod%fields(i)%name, stats(1), stats(2), INT(stats(4))
    END DO

    out_fields = SIZE(dxana%fields)
    IF (geom%f_comm%rank() .eq. 0)                                             &
      PRINT 10, 'ROMS_DEBUG roms_lvc_model2analysis::multiply:  Input',        &
              ' DXANA Vars = ', (dxana%fields(i)%metadata%name, i=1,out_fields)
    DO i = 1, out_fields
      CALL dxana%fields(i)%stats (stats)
      IF (geom%f_comm%rank() .eq. 0)                                           &
        PRINT 20, dxana%fields(i)%name, stats(1), stats(2), INT(stats(4))
    END DO
 10 FORMAT (a, a, *(1x,a,','))
 20 FORMAT (2x,'- ',a35,':',t43,'Min = ',1p,e22.15,',  Max = ',1p,e22.15,      &
            ',  CheckSum = ', i0)
  END IF

  ! Identity Transform: Copy state variable values with a one-to-one
  !                     relationship.

  counter = 0
  unFound = 0

  DO i = 1, SIZE(dxana%fields)
    IF (dxmod%has(dxana%fields(i)%name, findex)) THEN
      dxana%fields(i)%val = dxmod%fields(findex)%val
    ELSE
      counter = counter + 1
      unFound(counter) = i
    END IF
  END DO

  ! Variable Changes Transform: There are unfound variables to process.

  IF (counter .gt. 0) THEN

    IF (LdebugLinearModel2Analysis .and. (geom%f_comm%rank() .eq. 0)) THEN
      PRINT 10,'ROMS DEBUG roms_lvc_model2analysis::multiply:  ',              &
               'unFound Vars = ', (dxana%fields(unFound(i))%name, i=1,counter)
    END IF

    need_uaocn = dxana%has('eastward_sea_water_velocity') .and.                &
                 dxmod%has('sea_water_x_velocity')
    need_vaocn = dxana%has('northward_sea_water_velocity') .and.               &
                 dxmod%has('sea_water_y_velocity')

    have_uaocn = .FALSE.
    have_vaocn = .FALSE.

    IF (need_uaocn .or. need_vaocn) THEN
      CALL dxmod%get ('sea_water_x_velocity', Uc)
      CALL dxmod%get ('sea_water_y_velocity', Vc)

      allocate ( Ua(geom%LBi:geom%UBi, geom%LBj:geom%UBj, geom%N) )
      allocate ( Va(geom%LBi:geom%UBi, geom%LBj:geom%UBj, geom%N) )

      CALL vector_c_to_a (geom, Uc%val, Vc%val, Ua, Va)
      have_uaocn = .TRUE.
      have_vaocn = .TRUE.
    END IF

    ! Load the required linear variable changes. 

    DO i = 1, counter

      field_name = dxana%fields(unFound(i))%metadata%name

      CALL dxana%get (TRIM(field_name), field)

      SELECT CASE (TRIM(field_name))

        CASE ('eastward_sea_water_velocity')         !> A-grid

          IF (have_uaocn) THEN
            field%val = Ua
          END IF

        CASE ('northward_sea_water_velocity')        !> A-grid

          IF (have_uaocn) THEN
            field%val = Va
          END IF

        CASE DEFAULT

          CALL abor1_ftn ('roms_lvc_model2analysis_multiply: error while '//   &
                          'processing field: '//TRIM(field_name))

      END SELECT

    END DO

    IF ( allocated(Ua) )  deallocate (Ua)
    IF ( allocated(Va) )  deallocate (Va)

  END IF  

  ! Report debugging information.

  IF (LdebugLinearModel2Analysis) THEN
    DO i = 1, SIZE(dxana%fields)
      CALL dxana%fields(i)%stats (stats)
      IF (geom%f_comm%rank() .eq. 0) THEN
        IF (i.eq.1) PRINT '(a)', 'ROMS_DEBUG roms_lvc_model2analysis::'//      &
                                 'multiply:  Output DXANA Vars:'
        PRINT 20, dxana%fields(i)%name, stats(1), stats(2), INT(stats(4))
      END IF
    END DO
  END IF

END SUBROUTINE roms_lvc_model2analysis_multiply

! ------------------------------------------------------------------------------
!> It applies the adjoint multiply operator for the Linear Variable Change to
!! Model2Analysis increments.

SUBROUTINE roms_lvc_model2analysis_multiplyAD (self, geom, dxana, dxmod)

  CLASS (roms_lvc_model2analysis), intent(inout) :: self  !< LinVarChange object
  TYPE (roms_geom),                intent(in   ) :: geom  !< Geometry object
  TYPE (roms_increment),           intent(inout) :: dxana !< Input Increment
  TYPE (roms_increment),           intent(inout) :: dxmod !< Output Increment

  TYPE (roms_field),                     pointer :: field
  TYPE (roms_field),                     pointer :: Ua, Va

  logical                                        :: have_uocn, have_vocn
  logical                                        :: need_uocn, need_vocn

  integer                                        :: counter, findex, i
  integer                                        :: inp_fields, out_fields

  integer,         dimension(SIZE(dxmod%fields)) :: unFound

  real (kind=kind_real)                          :: stats(4)
  real (kind=kind_real),             allocatable :: Uc(:,:,:), Vc(:,:,:)

  character (len=512)                            :: field_name

  ! Report variables to process.

  IF (LdebugLinearModel2Analysis .and. (geom%f_comm%rank() .eq. 0)) THEN
    inp_fields = SIZE(dxana%fields)
    IF (geom%f_comm%rank() .eq. 0)                                             &
      PRINT 10, 'ROMS_DEBUG roms_lvc_model2analysis::multiplyAD:  Input',      &
              ' DXANA Vars = ', (dxana%fields(i)%metadata%name, i=1,inp_fields)
    DO i = 1, inp_fields
      CALL dxana%fields(i)%stats (stats)
      IF (geom%f_comm%rank() .eq. 0)                                           &
        PRINT 20, dxana%fields(i)%name, stats(1), stats(2), INT(stats(4))
    END DO

    out_fields = SIZE(dxmod%fields)
    IF (geom%f_comm%rank() .eq. 0)                                             &
      PRINT 10, 'ROMS_DEBUG roms_lvc_model2analysis::multiplyAD:  Input',      &
              ' DXMOD Vars = ', (dxmod%fields(i)%metadata%name, i=1,out_fields)
    DO i = 1, out_fields
      CALL dxmod%fields(i)%stats (stats)
      IF (geom%f_comm%rank() .eq. 0)                                           &
        PRINT 20, dxmod%fields(i)%name, stats(1), stats(2), INT(stats(4))
    END DO
 10 FORMAT (a, a, *(1x,a,','))
 20 FORMAT (2x,'- ',a35,':',t43,'Min = ',1p,e22.15,',  Max = ',1p,e22.15,      &
            ',  CheckSum = ', i0)
  END IF

  ! Identity Transform: Copy state variable values with a one-to-one
  !                     relationship.

  counter = 0
  unFound = 0

  CALL dxmod%zeros()

  DO i = 1, SIZE(dxmod%fields)
    IF (dxana%has(dxmod%fields(i)%name, findex)) THEN
      dxmod%fields(i)%val = dxmod%fields(i)%val + dxana%fields(findex)%val
    ELSE
      counter = counter + 1
      unFound(counter) = i
    END IF
  END DO

  ! Variable Changes Transform: There are unfound variables to process.

  IF (counter .gt. 0) THEN

    IF (LdebugLinearModel2Analysis .and. (geom%f_comm%rank() .eq. 0)) THEN
      PRINT 10,'ROMS DEBUG roms_lvc_model2analysis::multiplyAD:  ',            &
               'unFound Vars = ', (dxmod%fields(unFound(i))%name, i=1,counter)
    END IF

    need_uocn = dxmod%has('sea_water_x_velocity') .and.                        &
                dxana%has('eastward_sea_water_velocity')
    need_vocn = dxmod%has('sea_water_y_velocity') .and.                        &
                dxana%has('northward_sea_water_velocity')

    have_uocn = .FALSE.
    have_vocn = .FALSE.

    IF (need_uocn .or. need_vocn) THEN
      CALL dxana%get ('eastward_sea_water_velocity',  Ua)
      CALL dxana%get ('northward_sea_water_velocity', Va)

      allocate ( Uc(geom%LBi:geom%UBi, geom%LBj:geom%UBj, geom%N) )
      allocate ( Vc(geom%LBi:geom%UBi, geom%LBj:geom%UBj, geom%N) )

      Uc = 0.0_kind_real
      Vc = 0.0_kind_real

      CALL vector_c_to_a_ad (geom, Uc, Vc, Ua%val, Va%val)
      have_uocn = .TRUE.
      have_vocn = .TRUE.
    END IF

    ! Load the required linear variable changes. 

    DO i = 1, counter

      field_name = dxmod%fields(unFound(i))%metadata%name

      CALL dxmod%get (TRIM(field_name), field)

      SELECT CASE (TRIM(field_name))

        CASE ('sea_water_x_velocity')                !< A-grid

          IF (have_uocn) THEN
            field%val = field%val + Uc
          END IF

        CASE ('sea_water_y_velocity')                !< A-grid

          IF (have_vocn) THEN
            field%val = field%val + Vc
          END IF

        CASE DEFAULT

          CALL abor1_ftn ('roms_lvc_model2analysis_multiplyAD: error '//       &
                          'while processing field: '//TRIM(field_name))

      END SELECT

    END DO

    IF ( allocated(Uc) )  deallocate (Uc)
    IF ( allocated(Vc) )  deallocate (Vc)

  END IF

  ! Report debugging information.

  IF (LdebugLinearModel2Analysis) THEN
    DO i = 1, SIZE(dxmod%fields)
      CALL dxmod%fields(i)%stats (stats)
      IF (geom%f_comm%rank() .eq. 0) THEN
        IF (i.eq.1) PRINT '(a)', 'ROMS_DEBUG roms_lvc_model2analysis::'//      &
                                 'multiplyAD:  Output DXMOD Vars:'
        PRINT 20, dxmod%fields(i)%name, stats(1), stats(2), INT(stats(4))
      END IF
    END DO
  END IF

END SUBROUTINE roms_lvc_model2analysis_multiplyAD

! ------------------------------------------------------------------------------
!> It applies the multiply inverseoperator for the Linear Variable Change to
!! Model2Analysis increments.

SUBROUTINE roms_lvc_model2analysis_multiplyInverse (self, geom, dxana, dxmod)

  CLASS (roms_lvc_model2analysis), intent(inout) :: self  !< LinVarChange object
  TYPE (roms_geom),                intent(in   ) :: geom  !< Geometry object
  TYPE (roms_increment),           intent(in   ) :: dxana !< Input Increment
  TYPE (roms_increment),           intent(inout) :: dxmod !< Output Increment

  integer                                        :: counter, findex, i
  integer                                        :: inp_fields, out_fields

  integer,         dimension(SIZE(dxmod%fields)) :: unFound

  real (kind=kind_real)                          :: stats(4)

  ! Report variables to process.

  IF (LdebugLinearModel2Analysis .and. (geom%f_comm%rank() .eq. 0)) THEN
    inp_fields = SIZE(dxana%fields)
    IF (geom%f_comm%rank() .eq. 0)                                             &
      PRINT 10, 'ROMS_DEBUG roms_lvc_model2analysis::multiplyInverse:  Input', &
              ' DXANA Vars = ', (dxana%fields(i)%metadata%name, i=1,inp_fields)
    DO i = 1, inp_fields
      CALL dxana%fields(i)%stats (stats)
      IF (geom%f_comm%rank() .eq. 0)                                           &
        PRINT 20, dxana%fields(i)%name, stats(1), stats(2), INT(stats(4))
    END DO

    out_fields = SIZE(dxmod%fields)
    IF (geom%f_comm%rank() .eq. 0)                                             &
      PRINT 10, 'ROMS_DEBUG roms_lvc_model2analysis::multiplyInverse:  Input', &
              ' DXMOD Vars = ', (dxmod%fields(i)%metadata%name, i=1,out_fields)
    DO i = 1, out_fields
      CALL dxmod%fields(i)%stats (stats)
      IF (geom%f_comm%rank() .eq. 0)                                           &
        PRINT 20, dxmod%fields(i)%name, stats(1), stats(2), INT(stats(4))
    END DO
 10 FORMAT (a, a, *(1x,a,','))
 20 FORMAT (2x,'- ',a35,':',t43,'Min = ',1p,e22.15,',  Max = ',1p,e22.15,      &
            ',  CheckSum = ', i0)
  END IF

  ! Identity Transform: Copy state variable values with a one-to-one
  !                     relationship.

  counter = 0
  unFound = 0

  DO i = 1, SIZE(dxmod%fields)
    IF (dxana%has(dxmod%fields(i)%name, findex)) THEN
      dxmod%fields(i)%val = dxmod%fields(i)%val + dxana%fields(findex)%val
    ELSE
      counter = counter + 1
      unFound(counter) = i
    END IF
  END DO

  ! Report debugging information.

  IF (LdebugLinearModel2Analysis) THEN
    DO i = 1, SIZE(dxmod%fields)
      CALL dxmod%fields(i)%stats (stats)
      IF (geom%f_comm%rank() .eq. 0) THEN
        IF (i.eq.1) PRINT '(a)', 'ROMS_DEBUG roms_lvc_model2analysis::'//      &
                                 'multiplyInverse:  Output DXMOD Vars:'
        PRINT 20, dxmod%fields(i)%name, stats(1), stats(2), INT(stats(4))
      END IF
    END DO
  END IF

END SUBROUTINE roms_lvc_model2analysis_multiplyInverse

! ------------------------------------------------------------------------------
!> It applies the adjoint multiply inverse operator for the Linear Variable
!! Change to Model2Analysis increments.

SUBROUTINE roms_lvc_model2analysis_multiplyInverseAD (self, geom, dxmod, dxana)

  CLASS (roms_lvc_model2analysis), intent(inout) :: self  !< LinVarChange object
  TYPE (roms_geom),                intent(in   ) :: geom  !< Geometry object
  TYPE (roms_increment),           intent(in   ) :: dxmod !< Input Increment
  TYPE (roms_increment),           intent(inout) :: dxana !< Output Increment

  integer                                        :: counter, findex, i
  integer                                        :: inp_fields, out_fields

  integer,         dimension(SIZE(dxana%fields)) :: unFound

  real (kind=kind_real)                          :: stats(4)

  ! Report variables to process.

  IF (LdebugLinearModel2Analysis .and. (geom%f_comm%rank() .eq. 0)) THEN
    inp_fields = SIZE(dxmod%fields)
    IF (geom%f_comm%rank() .eq. 0)                                             &
      PRINT 10,'ROMS_DEBUG roms_lvc_model2analysis::multiplyInverseAD:  Input',&
              ' DXMOD Vars = ', (dxmod%fields(i)%metadata%name, i=1,inp_fields)
    DO i = 1, inp_fields
      CALL dxmod%fields(i)%stats (stats)
      PRINT 20, dxmod%fields(i)%name, stats(1), stats(2), INT(stats(4))
    END DO

    out_fields = SIZE(dxana%fields)
    IF (geom%f_comm%rank() .eq. 0)                                             &
      PRINT 10,'ROMS_DEBUG roms_lvc_model2analysis::multiplyInverseAD:  Input',&
              ' DXANA Vars = ', (dxana%fields(i)%metadata%name, i=1,out_fields)
    DO i = 1, out_fields
      CALL dxana%fields(i)%stats (stats)
      IF (geom%f_comm%rank() .eq. 0)                                           &
        PRINT 20, dxana%fields(i)%name, stats(1), stats(2), INT(stats(4))
    END DO
 10 FORMAT (a, a, *(1x,a,','))
 20 FORMAT (2x,'- ',a35,':',t43,'Min = ',1p,e22.15,',  Max = ',1p,e22.15,      &
            ',  CheckSum = ', i0)
  END IF

  ! Identity Transform: Copy state variable values with a one-to-one
  !                     relationship.

  counter = 0
  unFound = 0

  DO i = 1, SIZE(dxana%fields)
    IF (dxmod%has(dxana%fields(i)%name, findex)) THEN
      dxana%fields(i)%val = dxmod%fields(findex)%val
    ELSE
      counter = counter + 1
      unFound(counter) = i
    END IF
  END DO

  ! Report debugging information.

  IF (LdebugLinearModel2Analysis) THEN
    DO i = 1, SIZE(dxana%fields)
      CALL dxana%fields(i)%stats (stats)
      IF (geom%f_comm%rank() .eq. 0) THEN
        IF (i.eq.1) PRINT '(a)', 'ROMS_DEBUG roms_lvc_model2analysis::'//      &
                                 'multiplyInverseAD:  Output DXANA Vars:'
        PRINT 20, dxana%fields(i)%name, stats(1), stats(2), INT(stats(4))
      END IF
    END DO
  END IF

END SUBROUTINE roms_lvc_model2analysis_multiplyInverseAD

END MODULE roms_lvc_model2analysis_mod
