! (C) Copyright 2020-2021 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
! Hernan G. Arango, Rutgers University, Apr 2021

MODULE roms_state_mod

USE kinds,                      ONLY : kind_real

USE datetime_mod
USE fckit_configuration_module, ONLY : fckit_configuration
USE fckit_log_module,           ONLY : fckit_log
USE oops_variables_mod

USE roms_geom_mod,              ONLY : roms_geom
USE roms_field_mod,             ONLY : roms_field
USE roms_fields_mod,            ONLY : roms_fields
USE roms_fields_metadata_mod
!USE roms_fieldsutils_mod
USE roms_increment_mod,         ONLY : roms_increment
!USE roms_convert_state_mod

implicit none

!-------------------------------------------------------------------------------

TYPE, PUBLIC, EXTENDS(roms_fields) :: roms_state

  CONTAINS

  ! Increment operations

  PROCEDURE :: diff_incr    => roms_state_diff_incr
  PROCEDURE :: add_incr     => roms_state_add_incr

  ! Operations

  PROCEDURE :: rotate       => roms_state_rotate
  PROCEDURE :: convert      => roms_state_convert
  PROCEDURE :: logexpon     => roms_state_logexpon

END TYPE roms_state

!-------------------------------------------------------------------------------

PRIVATE

!-------------------------------------------------------------------------------
CONTAINS
!-------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
!> Rotate horizontal vector components to geographical or curvilinear 
!! coordinates.

SUBROUTINE roms_state_rotate (self, coordinate, uvars, vvars)

  CLASS (roms_state),    intent(inout) :: self        !> State object
  character (len=*),     intent(in   ) :: coordinate  !> "north" or "grid"
  TYPE (oops_variables), intent(in   ) :: uvars       !> U-component variables
  TYPE (oops_variables), intent(in   ) :: vvars       !> V-component variables

  integer                              :: i, k
  TYPE (roms_field), pointer           :: uocn, vocn
  real(kind=kind_real), allocatable    :: un(:,:,:), vn(:,:,:)
  character (len=64)                   :: u_names, v_names

  DO i=1, uvars%nvars()

    ! Get (u, v) vector components and make a copy

    u_names = TRIM(uvars%variable(i))
    v_names = TRIM(vvars%variable(i))

    IF (self%has(u_names).and.self%has(v_names)) THEN
      CALL fckit_log%info ("rotating "//TRIM(u_names)//" "//TRIM(v_names))
      CALL self%get (u_names, uocn)
      CALL self%get (v_names, vocn)
    ELSE                             ! skip if no pair found
      CALL fckit_log%info ("not rotating "//TRIM(u_names)//" "//TRIM(v_names))
      CYCLE
    END IF

    allocate (un(SIZE(uocn%val,1), SIZE(uocn%val,2), SIZE(uocn%val,3)))
    allocate (vn(SIZE(uocn%val,1), SIZE(uocn%val,2), SIZE(uocn%val,3)))
    un = uocn%val
    vn = vocn%val

    ! Rotate (uocn, vocn) vector components to geographical NORTH and EAST
    ! coordinates or numerical curvilinear (XI,ETA) coordinates.
    ! The ROMS rotation angle is an azimuth that is counterclockwise from
    ! true EAST, and defined at RHO-points.
    ! TODO: Do we to average to U- and V-points?

    SELECT CASE (TRIM(coordinate))
      CASE ("north")         ! rotate from (XI,ETA) to geographical coordinates
        DO k=1,uocn%N
          uocn%val(:,:,k) = (un(:,:,k) * self%geom%CosAngler(:,:)- &
                             vn(:,:,k) * self%geom%SinAngler(:,:)) * &
                            uocn%mask(:,:)

          vocn%val(:,:,k) = (vn(:,:,k) * self%geom%CosAngler(:,:)+ &
                             un(:,:,k) * self%geom%SinAngler(:,:)) * &
                            vocn%mask(:,:)
        END DO
      CASE ("grid")          ! rotate from geographical to (XI,ETA) coordinates
        DO k=1,uocn%N
          uocn%val(:,:,k) = (un(:,:,k) * self%geom%CosAngler(:,:)+ &
                             vn(:,:,k) * self%geom%SinAngler(:,:)) * &
                            uocn%mask(:,:)

          vocn%val(:,:,k) = (vn(:,:,k) * self%geom%CosAngler(:,:)- &
                             un(:,:,k) * self%geom%SinAngler(:,:)) * &
                            vocn%mask(:,:)
        END DO
    END SELECT

    deallocate (un, vn)

    ! Update halos

    CALL uocn%update_halo (self%geom)
    CALL vocn%update_halo (self%geom)

  END DO

END SUBROUTINE roms_state_rotate

! ------------------------------------------------------------------------------
!> It Adds a set of increments to the set of fields.

SUBROUTINE roms_state_add_incr (self, rhs)

  CLASS (roms_state),     intent(inout) :: self       !> State object
  CLASS (roms_increment), intent(in   ) :: rhs        !> SELF = SELF + RHS

  TYPE (roms_field), pointer            :: fld, fld_r
  TYPE (roms_fields), target            :: incr
  integer                               :: i

  ! Make sure "rhs" is a subset of "self".

  CALL rhs%check_subset (self)

  ! Make a copy of the increment

  CALL incr%copy (rhs)

  ! For each field that exists in "incr", add to "self".

  DO i = 1, SIZE(incr%fields)
    fld_r => incr%fields(i)
    CALL self%get (fld_r%name, fld)
    fld%val = fld%val + fld_r%val
  END DO

END SUBROUTINE roms_state_add_incr

! ------------------------------------------------------------------------------
!> Subtract two sets of fields, saving the results separately

SUBROUTINE roms_state_diff_incr (x1, x2, inc)

  CLASS (roms_state),     intent(in   ) :: x1         !> State-1 object
  CLASS (roms_state),     intent(in   ) :: x2         !> State-2 object
  CLASS (roms_increment), intent(inout) :: inc        !> Increment: x1 - x2

  TYPE (roms_field),            pointer :: f1, f2
  integer                               :: i

  ! Make sure fields correct shapes.

  CALL inc%check_subset (x2)
  CALL x2%check_subset (x1)

  ! Subtract.

  DO i = 1, SIZE(inc%fields)
    CALL x1%get (inc%fields(i)%name, f1)
    CALL x2%get (inc%fields(i)%name, f2)
    inc%fields(i)%val = f1%val - f2%val
  END DO

END SUBROUTINE roms_state_diff_incr

! ------------------------------------------------------------------------------
!> Convert State Application:  Interpolate between geometries

SUBROUTINE roms_state_convert (self, rhs)

  CLASS (roms_state),         intent(inout) :: self   !> Target State object
  CLASS (roms_state), target, intent(in   ) :: rhs    !> Source State object

  integer                           :: n
! TYPE (roms_convertstate_type)     :: convert_state
  TYPE (roms_field),        pointer :: field1, field2

! CALL rhs%get ("hocn", hocn1)
! CALL self%get ("hocn", hocn2)
! CALL convert_state%setup (rhs%geom, self%geom, hocn1, hocn2)

  DO n = 1, SIZE(rhs%fields)
    field1 => rhs%fields(n)
    CALL self%get (TRIM(field1%name), field2)
    IF (field1%metadata%io_file=="ocn") THEN
!     call convert_state%change_resol (field1, field2, rhs%geom, self%geom)
    END IF
  END DO

! CALL convert_state%clean ()

END SUBROUTINE roms_state_convert

! ------------------------------------------------------------------------------
!> Apply logarithmic or exponential transformations

SUBROUTINE roms_state_logexpon (self, transfunc, trvars)

  CLASS (roms_state),    intent(inout) :: self        !> State object
  character (len=*),     intent(in   ) :: transfunc   !> "log" or "expon"
  TYPE (oops_variables), intent(in   ) :: trvars      !> variables to transform

  TYPE (roms_field), pointer           :: trocn
  integer                              :: i
  real(kind=kind_real)                 :: min_val = 1e-6_kind_real
  real(kind=kind_real), allocatable    :: trn(:,:,:)
  character(len=64)                    :: tr_names

  DO i=1, trvars%nvars()

    ! Get a list variables to be transformed and make a copy

    tr_names = TRIM(trvars%variable(i))

    IF (self%has(tr_names)) THEN
      CALL fckit_log%info ("transforming "//TRIM(tr_names))
      CALL self%get (tr_names, trocn)
    ELSE                                 ! skip if no variable found
      CALL fckit_log%info ("not transforming "//TRIM(tr_names))
      CYCLE
    END IF

    allocate (trn(SIZE(trocn%val,1), SIZE(trocn%val,2), SIZE(trocn%val,3)))
    trn = trocn%val

    SELECT CASE(TRIM(transfunc))
      CASE ("log")                       ! apply logarithmic transformation
        trocn%val = LOG(trn + min_val)
      CASE ("expon")                     ! Apply exponential transformation
        trocn%val = EXP(trn) - min_val
    END SELECT

    ! Update halos

    CALL trocn%update_halo (self%geom)

    ! Deallocate "trn" for next variable

    deallocate (trn)

  END DO

END SUBROUTINE roms_state_logexpon

! ------------------------------------------------------------------------------

END MODULE roms_state_mod
