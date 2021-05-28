! (C) Copyright 2020-2021 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
! Hernan G. Arango, Rutgers University, Apr 2021

MODULE roms_increment_mod

USE kinds,                      ONLY : kind_real
USE fckit_configuration_module, ONLY : fckit_configuration
USE oops_variables_mod,         ONLY : oops_variables
USE datetime_mod

USE mod_ncparam,                ONLY : r3dvar, u3dvar, v3dvar
USE roms_fields_mod
!USE roms_convert_state_mod
USE roms_geom_mod,              ONLY : roms_geom
USE roms_geom_iter_mod,         ONLY : roms_geom_iter
USE white_noise_mod,            ONLY : white_noise3d

implicit none

PRIVATE

TYPE, PUBLIC, EXTENDS(roms_fields) :: roms_increment

  CONTAINS

  PROCEDURE :: getpoint  => roms_increment_getpoint
  PROCEDURE :: setpoint  => roms_increment_setpoint

  PROCEDURE :: dirac     => roms_increment_dirac
  PROCEDURE :: random    => roms_increment_random
  PROCEDURE :: schur     => roms_increment_schur
! PROCEDURE :: convert   => roms_increment_change_resol

END TYPE roms_increment

CONTAINS

! ------------------------------------------------------------------------------
!> Initialize fields with random normal distribution

SUBROUTINE roms_increment_random (self)

  CLASS (roms_increment), intent(inout) :: self

  TYPE (roms_field),            pointer :: field
  integer                               :: i, igtype, k, model, ng
  integer                               :: Istr, Iend, Jstr, Jend
  integer                               :: LBi, UBi, LBj, UBj, LBk, UBk
  integer                               :: Rscheme
  real(kind=kind_real)                  :: MinVal, MaxVal

  ! Get geometry parameters

  ng    = self%geom%ng        ! nested grid number
  model = self%geom%model     ! model kernel identifier
  LBi   = self%geom%LBi
  UBi   = self%geom%UBi
  LBj   = self%geom%LBj
  UBj   = self%geom%UBj

  ! Set random deviates with Gaussian distribution, [-1 1]

  Rscheme = 1              

  DO i = 1, SIZE(self%fields)

    LBk = LBOUND(self%fields(i)%val, DIM=3)
    UBk = UBOUND(self%fields(i)%val, DIM=3)

    SELECT CASE (self%fields(i)%name)
      CASE ('ssh', 'tocn', 'socn')
        Istr = self%geom%IstrR
        Iend = self%geom%IendR
        Jstr = self%geom%JstrR
        Jend = self%geom%JendR
        igtype = r3dvar
      CASE ('uocn')
        Istr = self%geom%IstrU
        Iend = self%geom%IendR
        Jstr = self%geom%JstrR
        Jend = self%geom%JendR
        igtype = u3dvar
      CASE ('vocn')
        Istr = self%geom%IstrR
        Iend = self%geom%IendR
        Jstr = self%geom%JstrV
        Jend = self%geom%JendR
        igtype = v3dvar
    END SELECT

    CALL white_noise3d (ng, model, igtype, Rscheme, &
                        Istr, Iend, Jstr, Jend, &
                        LBi, UBi, LBj, UBj, LBk, UBk, &
                        MinVal, MaxVal, self%fields(i)%val)
  END DO

  ! Mask out land, set to zero

  DO i = 1, SIZE(self%fields)

    field => self%fields(i)

    IF (.not.associated(field%mask) ) CYCLE

    DO k = 1, field%N
      field%val(:,:,k) = field%val(:,:,k) * field%mask(:,:)
    END DO

  END DO

  ! Update halo

  CALL self%update_halos ()

END SUBROUTINE roms_increment_random

! ------------------------------------------------------------------------------
!> Perform a Shur product between two sets of fields

SUBROUTINE roms_increment_schur (self, rhs)

  CLASS (roms_increment), intent(inout) :: self
  CLASS (roms_increment),    intent(in) :: rhs

  integer                               :: i

  ! Make sure fields are same name, size, and shape

  CALL self%check_congruent (rhs)

  ! Compute the Shur Product

  DO i = 1, SIZE(self%fields)
    self%fields(i)%val = self%fields(i)%val * rhs%fields(i)%val
  END DO

END SUBROUTINE roms_increment_schur

! ------------------------------------------------------------------------------

SUBROUTINE roms_increment_getpoint (self, geoiter, values)

  CLASS (roms_increment),   intent(in) :: self
  TYPE (roms_geom_iter),    intent(in) :: geoiter
  real(kind=kind_real),  intent(inout) :: values(:)

  integer                              :: ic, nf, nk
  TYPE (roms_field),           pointer :: field

  ! Get values

  ic = 0
  DO nf = 1, SIZE(self%fields)
    field => self%fields(nf)
    SELECT CASE (field%name)
      CASE ('ssh', 'uocn', 'vocn', 'tocn', 'socn')
        nk = field%N
        values(ic+1:ic+nk) = field%val(geoiter%iind, geoiter%jind,:)
        ic = ic + nk
    END SELECT
  END DO

END SUBROUTINE roms_increment_getpoint

! ------------------------------------------------------------------------------

SUBROUTINE roms_increment_setpoint (self, geoiter, values)

  CLASS (roms_increment), intent(inout) :: self
  TYPE (roms_geom_iter),     intent(in) :: geoiter
  real(kind=kind_real),      intent(in) :: values(:)

  integer                               :: ic, nf, nk
  TYPE (roms_field),            pointer :: field

  ! Set values

  ic = 0
  DO nf = 1, SIZE(self%fields)
    field => self%fields(nf)
    SELECT CASE (field%name)
      CASE ('ssh', 'uocn', 'vocn', 'tocn', 'socn')
        nk = field%N
        field%val(geoiter%iind, geoiter%jind,:) = values(ic+1:ic+nk)
        ic = ic + nk
    END SELECT
  END DO

END SUBROUTINE roms_increment_setpoint

! ------------------------------------------------------------------------------
!> Sets Dirac delta function at specified location(s)

SUBROUTINE roms_increment_dirac (self, f_conf)

  CLASS (roms_increment),         intent(inout) :: self
  TYPE (fckit_configuration), value, intent(in) :: f_conf   !< Configuration

  integer                                       :: Istr, Iend, Jstr, Jend
  integer                                       :: n, ndir, nk
 
  integer,                          allocatable :: ixdir(:), iydir(:), izdir(:)
  integer,                          allocatable :: ifdir(:)

  TYPE (roms_field),                    pointer :: field

  ! Get Diracs size

  ndir = f_conf%get_size("ixdir")

  IF (( f_conf%get_size("iydir") .ne. ndir ) .or. &
      ( f_conf%get_size("izdir") .ne. ndir ) .or. &
      ( f_conf%get_size("ifdir") .ne. ndir )) THEN
    CALL abor1_ftn ('roms_fields_dirac: inconsistent sizes for ixdir, iydir, izdir, and ifdir')
  END IF

  ! Allocation

  allocate ( ixdir(ndir) )
  allocate ( iydir(ndir) )
  allocate ( izdir(ndir) )
  allocate ( ifdir(ndir) )

  ! Get Diracs positions

  CALL f_conf%get_or_die ("ixdir", ixdir)
  CALL f_conf%get_or_die ("iydir", iydir)
  CALL f_conf%get_or_die ("izdir", izdir)
  CALL f_conf%get_or_die ("ifdir", ifdir)

  ! Get tile partition bounds

  Istr = self%geom%Istr
  Iend = self%geom%Iend
  Jstr = self%geom%Istr
  Jend = self%geom%Jend

  ! Setup Diracs

  CALL self%zeros ()

  DO n=1,ndir

    ! Skip this index if not in the bounds of this PE

    IF ((ixdir(n) > Iend) .or. (ixdir(n) < Istr)) CYCLE
    IF ((iydir(n) > Jend) .or. (iydir(n) < Jstr)) CYCLE

    field => null()

    SELECT CASE (ifdir(n))
      CASE (1)
        CALL self%get ("tocn", field)
      CASE (2)
        CALL self%get ("socn", field)
      CASE (3)
        CALL self%get ("ssh",  field)
      CASE default
        CALL abor1_ftn ('roms_fields_dirac: field type out range')
    END SELECT

    IF (associated(field)) THEN
      nk = 1
      IF (field%N > 1) nk = izdir(n)
      field%val(ixdir(n),iydir(n),izdir(n)) = 1.0_kind_real
    END IF

  END DO

END SUBROUTINE roms_increment_dirac

! ------------------------------------------------------------------------------
!>  Change resolution

SUBROUTINE roms_increment_change_resol (self, rhs)

  CLASS (roms_increment), intent(inout) :: self   !> target
  CLASS (roms_increment),    intent(in) :: rhs    !> source

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
