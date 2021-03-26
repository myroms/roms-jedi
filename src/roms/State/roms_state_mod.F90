! (C) Copyright 2020-2020 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

module roms_state_mod

use roms_geom_mod
use roms_fields_mod
use roms_increment_mod
use roms_convert_state_mod
use oops_variables_mod
use kinds,                  only: kind_real
use fckit_log_module,       only: fckit_log

implicit none

private

type, public, extends(roms_fields) :: roms_state

contains

  ! Constructors / Destructors
 
  procedure :: create    => roms_state_create

  ! Increment operations

  procedure :: diff_incr => roms_state_diff_incr
  procedure :: add_incr  => roms_state_add_incr

  ! Misc

  procedure :: rotate    => roms_state_rotate
  procedure :: convert   => roms_state_convert
  procedure :: logexpon  => roms_state_logexpon

end type

!------------------------------------------------------------------------------
contains
!------------------------------------------------------------------------------

!------------------------------------------------------------------------------
!> Create state object

subroutine roms_state_create(self, geom, vars)

  class(roms_state),         intent(inout) :: self
  type(roms_geom),  pointer, intent(inout) :: geom
  type(oops_variables),      intent(inout) :: vars

  ! Initialization fields by base class

  call self%roms_fields%create(geom, vars)

end subroutine roms_state_create

! ------------------------------------------------------------------------------
!> Rotate horizontal vector

subroutine roms_state_rotate(self, coordinate, uvars, vvars)

  class(roms_state),  intent(inout) :: self
  character(len=*),      intent(in) :: coordinate ! "north" or "grid"
  type(oops_variables),  intent(in) :: uvars
  type(oops_variables),  intent(in) :: vvars

  integer :: z, i
  type(roms_field),         pointer :: uocn, vocn
  real(kind=kind_real), allocatable :: un(:,:,:), vn(:,:,:)
  character(len=64)                 :: u_names, v_names

  do i=1, uvars%nvars()

    ! Get (u, v) pair and make a copy

    u_names = trim(uvars%variable(i))
    v_names = trim(vvars%variable(i))

    if (self%has(u_names).and.self%has(v_names)) then
      call fckit_log%info("rotating "//trim(u_names)//" "//trim(v_names))
      call self%get(u_names, uocn)
      call self%get(v_names, vocn)
    else   ! skip if no pair found
      call fckit_log%info("not rotating "//trim(u_names)//" "//trim(v_names))
      cycle
    end if

    allocate(un(size(uocn%val,1),size(uocn%val,2),size(uocn%val,3)))
    allocate(vn(size(uocn%val,1),size(uocn%val,2),size(uocn%val,3)))
    un = uocn%val
    vn = vocn%val

    select case(trim(coordinate))
    case("north")   ! rotate (uocn, vocn) to geo north
      do z=1,uocn%nz
        uocn%val(:,:,z) = &
        (self%geom%cos_rot(:,:)*un(:,:,z) + self%geom%sin_rot(:,:)*vn(:,:,z)) * uocn%mask(:,:)
        vocn%val(:,:,z) = &
        (- self%geom%sin_rot(:,:)*un(:,:,z) + self%geom%cos_rot(:,:)*vn(:,:,z)) * vocn%mask(:,:)
      end do
    case("grid")
      do z=1,uocn%nz
        uocn%val(:,:,z) = &
        (self%geom%cos_rot(:,:)*un(:,:,z) - self%geom%sin_rot(:,:)*vn(:,:,z)) * uocn%mask(:,:)
        vocn%val(:,:,z) = &
        (self%geom%sin_rot(:,:)*un(:,:,z) + self%geom%cos_rot(:,:)*vn(:,:,z)) * vocn%mask(:,:)
      end do
    end select

    deallocate(un, vn)

    ! update halos

    call uocn%update_halo(self%geom)
    call vocn%update_halo(self%geom)

  end do

end subroutine roms_state_rotate


! ------------------------------------------------------------------------------
!> Add a set of increments to the set of fields

subroutine roms_state_add_incr(self, rhs)

  class(roms_state),  intent(inout) :: self
  class(roms_increment), intent(in) :: rhs

  type(roms_field), pointer         :: fld, fld_r
  integer                           :: i, k

  real(kind=kind_real)              :: min_ice = 1e-6_kind_real
  real(kind=kind_real)              :: amin = 1e-6_kind_real
  real(kind=kind_real)              :: amax = 10.0_kind_real
  real(kind=kind_real), allocatable :: alpha(:,:), aice_bkg(:,:), aice_ana(:,:)
  type(roms_fields)                 :: incr

  ! Make sure rhs is a subset of self

  call rhs%check_subset(self)

  ! Make a copy of the increment

  call incr%copy(rhs)

  ! For each field that exists in incr, add to self

  do i=1,size(incr%fields)
    fld_r => incr%fields(i)
    call self%get(fld_r%name, fld)
    fld%val = fld%val + fld_r%val
  end do

end subroutine roms_state_add_incr

! ------------------------------------------------------------------------------
!> subtract two sets of fields, saving the results separately

subroutine roms_state_diff_incr(x1, x2, inc)

  class(roms_state),        intent(in) :: x1
  class(roms_state),        intent(in) :: x2
  class(roms_increment), intent(inout) :: inc

  integer                              :: i
  type(roms_field),            pointer :: f1, f2

  ! Make sure fields correct shapes

  call inc%check_subset(x2)
  call x2%check_subset(x1)

  ! Subtract

  do i=1,size(inc%fields)
    call x1%get(inc%fields(i)%name, f1)
    call x2%get(inc%fields(i)%name, f2)
    inc%fields(i)%val = f1%val - f2%val
  end do

end subroutine roms_state_diff_incr

! ------------------------------------------------------------------------------
!> ConvertState app:  Interpolate between geometries

subroutine roms_state_convert(self, rhs)

  class(roms_state), intent(inout) :: self  ! target
  class(roms_state),    intent(in) :: rhs   ! source

  integer                          :: n
  type(roms_convertstate_type)     :: convert_state
  type(roms_field), pointer        :: field1, field2, hocn1, hocn2

  call rhs%get("hocn", hocn1)
  call self%get("hocn", hocn2)
  call convert_state%setup(rhs%geom, self%geom, hocn1, hocn2)

  do n = 1, size(rhs%fields)
    field1 => rhs%fields(n)
    call self%get(trim(field1%name),field2)
    if (field1%io_file=="ocn" .or. field1%io_file=="sfc" .or. field1%io_file=="ice")  &
    call convert_state%change_resol(field1, field2, rhs%geom, self%geom)
  end do

  call convert_state%clean()

end subroutine roms_state_convert

! ------------------------------------------------------------------------------
!> Apply logarithmic and exponential transformations

subroutine roms_state_logexpon(self, transfunc, trvars)

  class(roms_state),  intent(inout) :: self
  character(len=*),      intent(in) :: transfunc ! "log" or "expon"
  type(oops_variables),  intent(in) :: trvars

  integer                           :: z, i
  type(roms_field),         pointer :: trocn
  real(kind=kind_real), allocatable :: trn(:,:,:)
  real(kind=kind_real)              :: min_val = 1e-6_kind_real
  character(len=64)                 :: tr_names

  do i=1, trvars%nvars()

    ! Get a list variables to be transformed and make a copy

    tr_names = trim(trvars%variable(i))
    if (self%has(tr_names)) then
      call fckit_log%info("transforming "//trim(tr_names))
      call self%get(tr_names, trocn)
    else   ! skip if no variable found
      call fckit_log%info("not transforming "//trim(tr_names))
      cycle
    end if

    allocate(trn(size(trocn%val,1),size(trocn%val,2),size(trocn%val,3)))
    trn = trocn%val

    select case(trim(transfunc))
    case("log")   ! apply logarithmic transformation
      trocn%val = log(trn + min_val)
    case("expon") ! Apply exponential transformation
      trocn%val = exp(trn) - min_val
    end select

    ! Update halos

    call trocn%update_halo(self%geom)

    ! Deallocate trn for next variable

    deallocate(trn)
  end do

end subroutine roms_state_logexpon

! ------------------------------------------------------------------------------

end module
