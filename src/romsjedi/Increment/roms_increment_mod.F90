! (C) Copyright 2020-2021 UCAR
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

USE atlas_module,               ONLY : atlas_fieldset, atlas_field, atlas_real
USE fckit_configuration_module, ONLY : fckit_configuration
USE oops_variables_mod,         ONLY : oops_variables
USE random_mod,                 ONLY : normal_distribution

USE datetime_mod

USE mod_ncparam,                ONLY : r3dvar, u3dvar, v3dvar
USE roms_fields_mod
!USE roms_convert_state_mod
USE roms_geom_mod,              ONLY : roms_geom
USE roms_geom_iter_mod,         ONLY : roms_geom_iter

implicit none

PRIVATE

TYPE, PUBLIC, EXTENDS(roms_fields) :: roms_increment

  CONTAINS

  ! Get/set a single point

  PROCEDURE :: getpoint   => roms_increment_getpoint
  PROCEDURE :: setpoint   => roms_increment_setpoint

  ! ATLAS

  PROCEDURE :: set_atlas  => roms_increment_set_atlas
  PROCEDURE :: to_atlas   => roms_increment_to_atlas
  PROCEDURE :: from_atlas => roms_increment_from_atlas

  ! Operators

  PROCEDURE :: dirac      => roms_increment_dirac
  PROCEDURE :: random     => roms_increment_random
  PROCEDURE :: schur      => roms_increment_schur
! PROCEDURE :: convert    => roms_increment_change_resol     ! TODO

END TYPE roms_increment

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
!> Initialize fields with random normal distribution.

SUBROUTINE roms_increment_random (self)

  CLASS (roms_increment), intent(inout) :: self       !< Increment object

  TYPE (roms_field),            pointer :: field

  integer, parameter                    :: rseed = 1
  integer                               :: Istr, Iend, Jstr, Jend
  integer                               :: i, k

  ! Set random values (interior points).

  Istr = self%geom%Istr
  Iend = self%geom%Iend
  Jstr = self%geom%Jstr
  Jend = self%geom%Jend

  DO i = 1, SIZE(self%fields)
    field => self%fields(i)
    CALL normal_distribution (field%val(Istr:Iend,Jstr:Jend,:),              &
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

  CLASS (roms_increment), intent(in   ) :: self       !< Increment object
  TYPE (roms_geom_iter),  intent(in   ) :: geoiter    !< geometry iterator
  real(kind=kind_real),   intent(inout) :: values(:)   

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
!> Set increment fields values from geometry iterator point data.

SUBROUTINE roms_increment_setpoint (self, geoiter, values)

  CLASS (roms_increment), intent(inout) :: self       !< Increment object
  TYPE (roms_geom_iter),  intent(in   ) :: geoiter    !< Geometry iterator
  real(kind=kind_real),   intent(in   ) :: values(:)

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

  CLASS (roms_increment),            intent(inout) :: self     !< Increment
  TYPE (fckit_configuration), value, intent(in   ) :: f_conf   !< Configuration

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
    CALL abor1_ftn ('roms_fields_dirac: inconsistent sizes for '//           &
                    'ixdir, iydir, izdir, and ifdir')
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
!> Defines increment fields in the ATLAS object.

SUBROUTINE roms_increment_set_atlas (self, geom, vars, afieldset)

  CLASS (roms_increment), intent(in   ) :: self       !< Increment object
  TYPE (roms_geom),       intent(in   ) :: geom       !< geometry object
  TYPE (oops_variables),  intent(in   ) :: vars       !< OOPS variables
  TYPE (atlas_fieldset),  intent(inout) :: afieldset  !< ATLAS fieldset

  TYPE (roms_field), pointer            :: field
  TYPE (atlas_field)                    :: afield

  logical                               :: var_found
  integer                               :: N, i, ivar
  character (len=1024)                  :: fieldname

  ! Create and add fields to ATLAS. Currently, ATLAS allows a single function
  ! space which is problematic with staggered C-grids. That is, ATLAS assumes
  ! that all the variables are at the same location.

  DO ivar = 1, vars%nvars()
    var_found = .FALSE.
    DO i=1, SIZE(self%fields)
      field => self%fields(i)
      IF (TRIM(vars%variable(ivar)) .eq. TRIM(field%name)) THEN
        IF (.not.afieldset%has_field(vars%variable(ivar))) THEN
          N = field%N
          IF (N .eq. 1) N = 0

          afield = geom%afunctionspace%create_field(name=vars%variable(ivar),  & 
                                                    kind=atlas_real(kind_real),&
                                                    levels=N)

          CALL afieldset%add (afield)                    ! add field
          CALL afield%final ()                           ! release pointer
        END IF
        var_found = .TRUE.
        EXIT
      END IF
    END DO

    IF (.not.var_found)                                                        &
      CALL abor1_ftn ('variable '//TRIM(vars%variable(ivar))//                 &
                      ' not found in increment')

  END DO

END SUBROUTINE roms_increment_set_atlas

! ------------------------------------------------------------------------------
!> Loads increment object data into ATLAS object.

SUBROUTINE roms_increment_to_atlas (self, geom, vars, afieldset)

  CLASS (roms_increment), intent(in   ) :: self       !< Increment object
  TYPE (roms_geom),       intent(in   ) :: geom       !< Geometry object
  TYPE (oops_variables),  intent(in   ) :: vars       !< OOPS variables
  TYPE (atlas_fieldset),  intent(inout) :: afieldset  !< ATLAS fieldset

  TYPE (roms_field), pointer            :: field
  TYPE (atlas_field)                    :: afield

  logical                               :: var_found
  integer                               :: Istr, Iend, Jstr, Jend
  integer                               :: N, i, ivar, k
  real (kind=kind_real), pointer        :: fldptr1(:), fldptr2(:,:)
  character (len=1024)                  :: fieldname

  ! Load fields increment data into the ATLAS object. Currently, ATLAS allows a
  ! single function space which is problematic with staggered C-grids. That is,
  ! ATLAS assumes that all the variables are at the same location.

  Istr = geom%IstrR
  Iend = geom%IendR
  Jstr = geom%JstrR
  Jend = geom%JendR

  DO ivar = 1, vars%nvars()
    var_found = .false.
    DO i = 1, SIZE(self%fields)
      field => self%fields(i)
      IF (TRIM(vars%variable(ivar)) .eq. TRIM(field%name)) THEN
        N = field%N
        IF (N.eq.1) N = 0

        IF (afieldset%has_field(vars%variable(ivar))) THEN
          afield = afieldset%field(vars%variable(ivar))        ! get field
        ELSE
          afield = geom%afunctionspace%create_field(name=vars%variable(ivar),  &
                                                    kind=atlas_real(kind_real),&
                                                    levels=N)  ! create field
          CALL afieldset%add (afield)                          ! add field
        end if

        ! Copy data.

        IF (N .eq. 0) THEN
          CALL afield%data (fldptr1)
          fldptr1 = RESHAPE(field%val(Istr:Iend, Jstr:Jend, 1),                &
                                      (/ (Iend-Istr+1)*(Jend-Jstr+1) /))
        ELSE
          CALL afield%data (fldptr2)
          DO k=1,N
            fldptr2(k,:) = RESHAPE(field%val(Istr:Iend, Jstr:Jend, k),         &
                                             (/ (Iend-Istr+1)*(Jend-Jstr+1) /))
          END DO
        END IF

        CALL afield%final ()                      ! release pointer
        var_found = .TRUE.
        EXIT
      END IF
    END DO

    IF (.not.var_found)                                                        &
      CALL abor1_ftn ('variable '//TRIM(vars%variable(ivar))//                 &
                      ' not found in increment')
  END DO

END SUBROUTINE roms_increment_to_atlas

! ------------------------------------------------------------------------------
!> Fills increment object with data from the ATLAS object.

SUBROUTINE roms_increment_from_atlas (self, geom, vars, afieldset)

  CLASS (roms_increment), intent(inout) :: self       !< Increment object
  TYPE (roms_geom),       intent(in   ) :: geom       !< Geometry object
  TYPE (oops_variables),  intent(in   ) :: vars       !< OOPS variables
  TYPE (atlas_fieldset),  intent(in   ) :: afieldset  !< ATLAS fieldset

  TYPE (roms_field), pointer            :: field
  TYPE (atlas_field)                    :: afield

  logical                               :: var_found
  integer                               :: Istr, Iend, Jstr, Jend
  integer                               :: N, i, ivar, k
  real (kind=kind_real), pointer        :: fldptr1(:), fldptr2(:,:)
  character (len=1024)                  :: fieldname

  ! Initialize increment fields to zero.

  CALL self%zeros ()

  ! Retrieve field increments from the ATLAS object. Currently, ATLAS allows a
  ! single function space which is problematic with staggered C-grids. That is,
  ! ATLAS assumes that all the variables are at the same location.

  Istr = geom%IstrR
  Iend = geom%IendR
  Jstr = geom%JstrR
  Jend = geom%JendR

  DO ivar = 1, vars%nvars()
    var_found = .FALSE.
    DO i = 1, SIZE(self%fields)
      field => self%fields(i)
      IF (TRIM(vars%variable(ivar)) .eq. TRIM(field%name)) THEN
        N = field%N
        IF (N .eq. 1) N = 0

        afield = afieldset%field(vars%variable(ivar))        ! get field

        ! Copy data.

        IF (N .eq. 0) THEN
          CALL afield%data (fldptr1)
          field%val(Istr:Iend,Jstr:Jend,1) = RESHAPE(fldptr1,                  &
                                                (/Iend-Istr+1, Jend-Jstr+1/))
        ELSE
          CALL afield%data (fldptr2)
          DO k = 1, N
            field%val(Istr:Iend,Jstr:Jend,k) = RESHAPE(fldptr2(k,:),           &
                                                  (/Iend-Istr+1, Jend-Jstr+1/))
          END DO
        END IF

        CALL afield%final ()                                 ! release pointer
        var_found = .TRUE.
        EXIT
      END IF
    END DO

    IF (.not.var_found)                                                        &
      CALL abor1_ftn ('variable '//TRIM(vars%variable(ivar))//                 &
                      ' not found in increment')

  END DO

END SUBROUTINE roms_increment_from_atlas

! ------------------------------------------------------------------------------
!>  Spatially interpolate increment object to SELF geometry using source RHS
!!  geometry. The number of vertical levels between source and target geometries
!!  must be the same.

SUBROUTINE roms_increment_change_resol (self, rhs)

  CLASS (roms_increment), intent(inout) :: self   !> Target grid and values
  CLASS (roms_increment), intent(in   ) :: rhs    !> Source grid and values

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
