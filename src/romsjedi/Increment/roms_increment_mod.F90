! (C) Copyright 2020-2023 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
!>
!! \brief    **Increment** Class Fortran ROMS-JEDI interface 
!!
!! \details  It implements several methods in each field of the **Increment**
!!           object, such as mathematical and algebraic operations, reading,
!!           and writing. Thus, there is a fair amount of overlap with the
!!           **Fields** and **State** objects.
!!
!! \author   Hernan G. Arango (Rutgers University)
!! \date     October 2021

MODULE roms_increment_mod

USE kinds,                      ONLY : kind_real

USE fckit_configuration_module, ONLY : fckit_configuration
USE fckit_mpi_module,           ONLY : fckit_mpi_comm
USE oops_variables_mod,         ONLY : oops_variables
USE random_mod,                 ONLY : normal_distribution

USE datetime_mod

USE mod_ncparam,                ONLY : r2dvar
USE roms_field_mod,             ONLY : roms_field
USE roms_fields_mod,            ONLY : roms_fields
USE roms_fieldsutils_mod,       ONLY : LdebugFields
!USE roms_convert_state_mod
USE roms_geom_mod,              ONLY : roms_geom
USE roms_geomIterator_mod,      ONLY : roms_geomIterator

implicit none

! ------------------------------------------------------------------------------

TYPE, PUBLIC, EXTENDS(roms_fields) :: roms_increment

  CONTAINS

  ! Get/set a single point

  PROCEDURE :: getpoint   => roms_increment_getpoint
  PROCEDURE :: setpoint   => roms_increment_setpoint

  ! Operators

  PROCEDURE :: dirac      => roms_increment_dirac
  PROCEDURE :: random     => roms_increment_random
  PROCEDURE :: schur      => roms_increment_schur
! PROCEDURE :: convert    => roms_increment_change_resol     ! TODO

END TYPE roms_increment

! ------------------------------------------------------------------------------

PRIVATE

! Local MPI communicator.

TYPE (fckit_mpi_comm) :: my_comm

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
!> Initialize fields with random normal distribution.

SUBROUTINE roms_increment_random (self)

  CLASS (roms_increment), target, intent(inout) :: self    !< Increment object

  TYPE (roms_field), pointer                    :: field

  integer, parameter                            :: rseed = 1
  integer                                       :: IstrD, IendD, JstrD, JendD
  integer                                       :: i, k

  ! Set random values (interior points).

  DO i = 1, SIZE(self%fields)
    field => self%fields(i)

    IstrD = field%bounds%IstrD
    IendD = field%bounds%IendD
    JstrD = field%bounds%JstrD
    JendD = field%bounds%JendD

    CALL normal_distribution (field%val(IstrD:IendD, JstrD:JendD, :),          &
                              0.0_kind_real, 1.0_kind_real, rseed)
  END DO

  ! Apply land/sea mask

  DO i = 1, SIZE(self%fields)
    field => self%fields(i)
    IF (.not.associated(field%mask)) CYCLE
    DO k = 1, field%N
      field%val(:,:,k) = field%val(:,:,k) * field%mask(:,:)
    END DO
  END DO

END SUBROUTINE roms_increment_random

! ------------------------------------------------------------------------------
!> Perform a Shur product between two sets of increment fields.

SUBROUTINE roms_increment_schur (self, rhs)

  CLASS (roms_increment), intent(inout) :: self       !< Increment object
  CLASS (roms_increment), intent(in   ) :: rhs        !< Increment object

  integer                               :: i

  ! Make sure fields are same name, size, and shape

  CALL self%check_congruent (rhs)

  ! Compute the Shur Product

  DO i = 1, SIZE(self%fields)
    self%fields(i)%val = self%fields(i)%val * rhs%fields(i)%val
  END DO

END SUBROUTINE roms_increment_schur

! ------------------------------------------------------------------------------
!> Get increment fields values at geometry iterator points.

SUBROUTINE roms_increment_getpoint (self, geoiter, values)

  CLASS (roms_increment), target, intent(in   ) :: self      !< Increment object
  TYPE (roms_geomIterator),       intent(in   ) :: geoiter   !< GeometryIterator
  real (kind=kind_real),          intent(inout) :: values(:)   

  TYPE (roms_field), pointer                    :: field
  integer                                       :: ic, nf, nk

  ! Get values

  ic = 0
  DO nf = 1, SIZE(self%fields)
    field => self%fields(nf)
    SELECT CASE (field%name)
      CASE ('ssh', 'uocn', 'vocn', 'tocn', 'socn')
        nk = field%N
        values(ic+1:ic+nk) = field%val(geoiter%Iindex, geoiter%Jindex,:)
        ic = ic + nk
    END SELECT
  END DO

END SUBROUTINE roms_increment_getpoint

! ------------------------------------------------------------------------------
!> Set increment fields values from geometry iterator point data.

SUBROUTINE roms_increment_setpoint (self, geoiter, values)

  CLASS (roms_increment), target, intent(inout) :: self      !< Increment object
  TYPE (roms_geomIterator),       intent(in   ) :: geoiter   !< GeometryIterator
  real (kind=kind_real),          intent(in   ) :: values(:)

  TYPE (roms_field), pointer                    :: field
  integer                                       :: ic, nf, nk

  ! Set values

  ic = 0
  DO nf = 1, SIZE(self%fields)
    field => self%fields(nf)
    SELECT CASE (field%name)
      CASE ('ssh', 'uocn', 'vocn', 'tocn', 'socn')
        nk = field%N
        field%val(geoiter%Iindex, geoiter%Jindex,:) = values(ic+1:ic+nk)
        ic = ic + nk
    END SELECT
  END DO

END SUBROUTINE roms_increment_setpoint

! ------------------------------------------------------------------------------
!> Sets Dirac delta function impulses at the specified location(s).

SUBROUTINE roms_increment_dirac (self, f_conf)

  CLASS (roms_increment),            intent(inout) :: self     !< Increment
  TYPE (fckit_configuration), value, intent(in   ) :: f_conf   !< Configuration

  TYPE (roms_field),                       pointer :: field

  integer,                             allocatable :: ixdir(:), iydir(:)
  integer,                             allocatable :: izdir(:)
  integer                                          :: IstrD, IendD, JstrD, JendD
  integer                                          :: n, ndir
  character (len=32),                  allocatable :: ifdir(:)
  character (len=:),                   allocatable :: fieldname(:)


  ! Get Diracs size.

  ndir = f_conf%get_size("ixdir")

  IF (( f_conf%get_size("iydir") .ne. ndir ) .or. &
      ( f_conf%get_size("izdir") .ne. ndir ) .or. &
      ( f_conf%get_size("ifdir") .ne. ndir )) THEN
    CALL abor1_ftn ('roms_fields_dirac: inconsistent sizes for '//             &
                    'ixdir, iydir, izdir, and ifdir')
  END IF

  ! Allocation.

  allocate ( ixdir(ndir) )
  allocate ( iydir(ndir) )
  allocate ( izdir(ndir) )
  allocate ( ifdir(ndir) )

  ! Get Diracs delta function impulses locations in terms of (i,j,k) grid cells.

  CALL f_conf%get_or_die ("ixdir", ixdir)
  CALL f_conf%get_or_die ("iydir", iydir)
  CALL f_conf%get_or_die ("izdir", izdir)

  CALL f_conf%get_or_die ("ifdir", fieldname)
  ifdir = fieldname
  DEALLOCATE (fieldname)

  ! Get tile partition bounds.

  IstrD = self%geom%bounds(r2dvar)%IstrD
  IendD = self%geom%bounds(r2dvar)%IendD
  JstrD = self%geom%bounds(r2dvar)%JstrD
  JendD = self%geom%bounds(r2dvar)%JendD

  IF (LdebugFields .and. (my_comm%rank() .eq. 0)) THEN
    PRINT 10, 'ROMS_DEBUG: roms_increment::dirac: tile = ', self%geom%tile,    &
              '  IstrD = ', IstrD,                                             &
              ', IendD = ', IendD,                                             &
              ', JstrD = ', JstrD,                                             &
              ', JendD = ', JendD,                                             &
              ', ixdir = ', ixdir,                                             &
              ', iydir = ', iydir,                                             &
              ', izdir = ', iydir,                                             &
              ', ifdir = ', ifdir
    10 FORMAT (a, i3, 7(a, i0, 1x), a, a)
  END IF

  ! Setup Diracs.

  CALL self%zeros ()

  DO n=1,ndir

    ! Skip this index if not in the bounds of this parallel partition.

    IF ((ixdir(n) > IendD) .or. (ixdir(n) < IstrD)) CYCLE
    IF ((iydir(n) > JendD) .or. (iydir(n) < JstrD)) CYCLE

    field => null()

    CALL self%get (TRIM(ifdir(n)), field)

    field%val(ixdir(n),iydir(n),izdir(n)) = 1.0_kind_real

  END DO

END SUBROUTINE roms_increment_dirac

! ------------------------------------------------------------------------------
!>  Spatially interpolate increment object to SELF geometry using source RHS
!!  geometry. The number of vertical levels between source and target geometries
!!  must be the same.

SUBROUTINE roms_increment_change_resol (self, rhs)

  CLASS (roms_increment),         intent(inout) :: self   !> Target grid/values
  CLASS (roms_increment), target, intent(in   ) :: rhs    !> Source grid/values

! TYPE (roms_convertstate_type)         :: convert_state
  TYPE (roms_field),            pointer :: field1, field2

  integer                               :: n

! CALL rhs%get ("hocn", hocn1)
! CALL self%get ("hocn", hocn2)

! CALL convert_state%setup (rhs%geom, self%geom, hocn1, hocn2)

  DO n = 1, size(rhs%fields)
    field1 => rhs%fields(n)
    CALL self%get (TRIM(field1%name), field2)
!   CALL convert_state%change_resol2d (field1, field2, rhs%geom, self%geom)
  END DO

! CALL convert_state%clean ()

END SUBROUTINE roms_increment_change_resol

! ------------------------------------------------------------------------------

END MODULE roms_increment_mod
