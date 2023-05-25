! (C) Copyright 2020-2023 UCAR
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

USE roms_field_mod,             ONLY : roms_field
USE roms_fieldsutils_mod,       ONLY : LdebugLinearModel2Geovals
USE roms_geom_mod,              ONLY : roms_geom,                              &
                                       roms_tile
USE roms_increment_mod,         ONLY : roms_increment
USE roms_state_mod,             ONLY : roms_state

implicit none

!-------------------------------------------------------------------------------

TYPE, PUBLIC :: roms_lvc_model2geovals

  integer :: ng                            ! nested grid number
  integer :: tile                          ! domain parallel partition tile

  integer :: LBi, UBi, LBj, UBj, LBk, UBk  ! array(i,j,k) allocation bounds
  integer :: N                             ! number of vertical levels

  TYPE (roms_tile) :: bounds(4)            ! tile indices range

  CONTAINS

  PROCEDURE :: create     => roms_lvc_model2geovals_create
  PROCEDURE :: delete     => roms_lvc_model2geovals_delete
  PROCEDURE :: multiply   => roms_lvc_model2geovals_multiply
  PROCEDURE :: multiplyAD => roms_lvc_model2geovals_multiplyAD

END TYPE roms_lvc_model2geovals

!-------------------------------------------------------------------------------
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

  !> Domain decomposition ranges and indices.

  self%ng   = geom%ng
  self%tile = geom%tile

  self%LBi = geom%LBi                   ! lower bound I-dimension
  self%UBi = geom%UBi                   ! upper bound I-dimension
  self%LBj = geom%LBj                   ! lower bound J-dimension
  self%UBj = geom%UBj                   ! upper bound J-dimension

  self%N   = geom%N                     ! number of vertical levels
  self%LBk = 1                          ! lower bound K-dimension
  self%UBk = geom%N                     ! upper bound K-dimension

  self%bounds = geom%bounds             ! tile indices range

  ! TODO: If background trajectory is required, get needed fields from state.

END SUBROUTINE roms_lvc_model2geovals_create

!-------------------------------------------------------------------------------
!> It destroys the Linear Variable Change to GeoVaLs object.

SUBROUTINE roms_lvc_model2geovals_delete (self)

  CLASS (roms_lvc_model2geovals), intent(inout) :: self  !< VarChange object

  ! TODO: If fields are defined in the object deallocate them here.

END SUBROUTINE roms_lvc_model2geovals_delete

! ------------------------------------------------------------------------------
!> It applies the multiply operator for the Linear Variable Change to
!  GeoVaLs object.

SUBROUTINE roms_lvc_model2geovals_multiply (self, geom, dxm, dxg)

  USE strings_mod, ONLY : join_string                    !< ROMS strings module

  CLASS (roms_lvc_model2geovals), intent(inout) :: self  !< VarChange object
  TYPE (roms_geom),               intent(inout) :: geom  !< Geometry
  TYPE (roms_increment),          intent(in   ) :: dxm   !< Increment (in)
  TYPE (roms_increment),          intent(inout) :: dxg   !< Increment (out)

  TYPE (roms_field),                    pointer :: field

  integer                                       :: Nsur, i
  integer                                       :: lstr1, lstr2
  real (kind=kind_real)                         :: stats(3)
  character (len=:), allocatable                :: dxg_vars(:), dxm_vars(:)
  character (len=524)                           :: dxg_string, dxm_string

  ! Debug input and output increment metadata.

  IF (LdebugLinearModel2Geovals .and. (geom%f_comm%rank() .eq. 0)) THEN
    ALLOCATE (character(len=1024) :: dxg_vars(SIZE(dxg%fields)))
    DO i = 1, SIZE(dxg%fields)
      dxg_vars(i) = dxg%fields(i)%name
    END DO 
    CALL join_string (dxg_vars, SIZE(dxg%fields), dxg_string, lstr1)

    ALLOCATE (character(len=1024) :: dxm_vars(SIZE(dxm%fields)))
    DO i = 1, SIZE(dxm%fields)
      dxm_vars(i) = dxm%fields(i)%name
    END DO 
    CALL join_string (dxm_vars, SIZE(dxm%fields), dxm_string, lstr2)

    PRINT '(5a)', 'ROMS_DEBUG roms_lvc_model2geovals::multiply:',              &
                  ' output DXG vars: ', dxg_string(1:lstr1),                   &
                  ' | input DXM vars: ', dxm_string(1:lstr2)
  END IF

  ! Apply the required linear variable change to variables in the DXG vector.
  ! Here, the number of variables in the increment vectors DXM and DXG state
  ! vectors are the same (usually, we have  ssh, uocn, vocn, tocn, and socn).

  DO i = 1, SIZE(dxg%fields)

    IF (LdebugLinearModel2Geovals .and. (geom%f_comm%rank() .eq. 0)) THEN
    ! PRINT '(8a)', 'ROMS_DEBUG roms_lvc_model2geovals::multiply: '//          &
    !               'Changing DXG name = ', dxg%fields(i)%name,                &
    !               ', metadata%name = ',                                      &
    !               dxg%fields(i)%metadata%name,                               &
    !               ', metadata%getval_name = ',                               &
    !               dxg%fields(i)%metadata%getval_name,                        &
    !               ', metadata%getval_name_surface = ',                       &
    !               dxg%fields(i)%metadata%getval_name_surface
    END IF

    CALL dxm%get (dxg%fields(i)%metadata%name, field)

    IF ((dxg%fields(i)%name .eq. field%metadata%name) .or.                     &
        (dxg%fields(i)%name .eq. field%metadata%getval_name)) THEN

      ! Loading full field.

      dxg%fields(i)%val(:,:,:) = field%val(:,:,:)

    ELSE IF (dxg%fields(i)%name .eq. field%metadata%getval_name_surface) THEN

      ! Loading surface field.

      Nsur = field%N
      dxg%fields(i)%val(:,:,1) = field%val(:,:,Nsur)

    ELSE

      CALL abor1_ftn ('roms_lvc_model2geovals_multiply: error while '//        &
                      'processing field: '//TRIM(dxg%fields(i)%name))
    END IF

    IF (LdebugLinearModel2Geovals) THEN
      CALL dxg%fields(i)%stats (stats)
      IF (geom%f_comm%rank() .eq. 0) THEN
        PRINT 10, dxg%fields(i)%name, stats(1), stats(2), INT(stats(3))
 10     FORMAT (2x,'- ',a35,':',t43,'Min = ',1p,e22.15,',  Max = ',1p,e22.15,  &
                ',  CheckSum = ', i0)
      END IF
    END IF

  END DO

END SUBROUTINE roms_lvc_model2geovals_multiply

! ------------------------------------------------------------------------------
!> It applies the adjoint multiply operator for the Linear Variable Change to
!  GeoVaLs object.

SUBROUTINE roms_lvc_model2geovals_multiplyAD (self, geom, dxg, dxm)

  USE strings_mod, ONLY : join_string                    !< ROMS strings module

  CLASS (roms_lvc_model2geovals), intent(inout) :: self  !< VarChange object
  TYPE (roms_geom),               intent(inout) :: geom  !< Geometry
  TYPE (roms_increment),          intent(in   ) :: dxg   !< Increment (in)
  TYPE (roms_increment),          intent(inout) :: dxm   !< Increment (out)

  TYPE (roms_field),                    pointer :: field

  integer                                       :: Nsur, i
  integer                                       :: lstr1, lstr2
  real (kind=kind_real)                         :: stats(3)
  character (len=:), allocatable                :: dxg_vars(:), dxm_vars(:)
  character (len=524)                           :: dxg_string, dxm_string

  ! Debug input and output increment metadata.

  IF (LdebugLinearModel2Geovals .and. (geom%f_comm%rank() .eq. 0)) THEN
    ALLOCATE (character(len=1024) :: dxg_vars(SIZE(dxg%fields)))
    DO i = 1, SIZE(dxg%fields)
      dxg_vars(i) = dxg%fields(i)%name
    END DO 
    CALL join_string (dxg_vars, SIZE(dxg%fields), dxg_string, lstr1)

    ALLOCATE (character(len=1024) :: dxm_vars(SIZE(dxm%fields)))
    DO i = 1, SIZE(dxm%fields)
      dxm_vars(i) = dxm%fields(i)%name
    END DO 
    CALL join_string (dxm_vars, SIZE(dxm%fields), dxm_string, lstr2)

    PRINT '(5a)', 'ROMS_DEBUG roms_lvc_model2geovals::multiplyAD:',            &
                  ' input DXG vars: ', dxg_string(1:lstr1),                    &
                  ' | output DXM vars: ', dxm_string(1:lstr2)
  END IF

  ! Apply the required adjoint variable change to variables in the DXM vector.
  ! In most cases, the number of variables in the DXM state vector (ssh, uocn,
  ! vocn, tocn, and socn) is larger the than in the DXG increment vector, which
  ! contains the observed variables (sea_water_temperature, sea_water_salinity,
  ! sea_surface_temperature, and sea_surface_height_above_geoid)

  DO i = 1, SIZE(dxg%fields)

    IF (LdebugLinearModel2Geovals .and. (geom%f_comm%rank() .eq. 0)) THEN
    ! PRINT '(8a)', 'ROMS_DEBUG roms_lvc_model2geovals::multiplyAD: '//        &
    !               'Updating DXM name = ', dxg%fields(i)%name,                &
    !               ', metadata%name = ',                                      &
    !               dxg%fields(i)%metadata%name,                               &
    !               ', metadata%getval_name = ',                               &
    !               dxg%fields(i)%metadata%getval_name,                        &
    !               ', metadata%getval_name_surface = ',                       &
    !               dxg%fields(i)%metadata%getval_name_surface
    END IF

    CALL dxm%get (dxg%fields(i)%metadata%name, field)

    IF ((dxg%fields(i)%name .eq. field%metadata%name) .or.                     &
        (dxg%fields(i)%name .eq. field%metadata%getval_name)) THEN

      ! Adjoint of load full field.

      field%val = field%val + dxg%fields(i)%val

    ELSE IF (dxg%fields(i)%name .eq. field%metadata%getval_name_surface) THEN

      ! Adjoint of load surface field.

      Nsur = field%N
      field%val(:,:,Nsur) = field%val(:,:,Nsur) +                              &
                            dxg%fields(i)%val(:,:,1)

    ELSE

      CALL abor1_ftn ('roms_lvc_model2geovals_multiplyAD: error while '//      &
                          'processing field: '//TRIM(dxg%fields(i)%name))

    END IF

    IF (LdebugLinearModel2Geovals) THEN
      CALL field%stats (stats)
      IF (geom%f_comm%rank() .eq. 0) THEN
        PRINT 10, field%name, stats(1), stats(2), INT(stats(3))
 10     FORMAT (2x,'- ',a35,':',t43,'Min = ',1p,e22.15,',  Max = ',1p,e22.15,    &
                ',  CheckSum = ', i0)
      END IF
    END IF

  END DO

END SUBROUTINE roms_lvc_model2geovals_multiplyAD

! ------------------------------------------------------------------------------

END MODULE roms_lvc_model2geovals_mod
