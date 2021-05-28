! (C) Copyright 2020-2021 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
! Hernan G. Arango, Rutgers University, Apr 2021

MODULE roms_increment_mod_c

USE iso_c_binding
USE datetime_mod,               ONLY : datetime, c_f_datetime
USE fckit_configuration_module, ONLY : fckit_configuration
USE kinds,                      ONLY : kind_real
USE oops_variables_mod
!USE ufo_locs_mod_c,             ONLY : ufo_locs_registry
!USE ufo_locs_mod,               ONLY : ufo_locs
!USE ufo_geovals_mod_c,          ONLY : ufo_geovals_registry
!USE ufo_geovals_mod,            ONLY : ufo_geovals

USE roms_geom_mod,              ONLY : roms_geom
USE roms_geom_mod_c,            ONLY : roms_geom_registry
use roms_geom_iter_mod,         ONLY : roms_geom_iter, roms_geom_iter_registry
use roms_increment_mod
use roms_increment_reg
use roms_state_mod
use roms_state_reg

implicit none

PRIVATE

CONTAINS

! ------------------------------------------------------------------------------
!>  Creates increment object  

SUBROUTINE roms_increment_create_c (c_key_self, c_key_geom, c_vars) &
                              BIND (c, name='roms_increment_create_f90')

  integer(c_int),  intent(inout) :: c_key_self    !< Handle to field
  integer(c_int),     intent(in) :: c_key_geom    !< Geometry
  TYPE (c_ptr),value, intent(in) :: c_vars        !< List of variables

  TYPE (roms_increment), pointer :: self
  TYPE (roms_geom),      pointer :: geom
  TYPE (oops_variables)          :: vars

  CALL roms_geom_registry%get (c_key_geom, geom)
  CALL roms_increment_registry%init ()
  CALL roms_increment_registry%add (c_key_self)
  CALL roms_increment_registry%get (c_key_self,self)

  vars = oops_variables(c_vars)

  CALL self%create (geom, vars)

  END SUBROUTINE roms_increment_create_c

! ------------------------------------------------------------------------------
!>  Deletes increment object

SUBROUTINE roms_increment_delete_c (c_key_self) &
                              BIND (c, name='roms_increment_delete_f90')

  integer(c_int),  intent(inout) :: c_key_self

  TYPE (roms_increment), pointer :: self

  CALL roms_increment_registry%get (c_key_self, self)
  CALL self%delete ()
  CALL roms_increment_registry%remove (c_key_self)

END SUBROUTINE roms_increment_delete_c

! ------------------------------------------------------------------------------
!>  Set increment fields to unity

SUBROUTINE roms_increment_ones_c (c_key_self) &
                            BIND (c, name='roms_increment_ones_f90')

  integer(c_int),     intent(in) :: c_key_self

  TYPE (roms_increment), pointer :: self

  CALL roms_increment_registry%get (c_key_self, self)
  CALL self%ones ()

END SUBROUTINE roms_increment_ones_c

! ------------------------------------------------------------------------------
!>  Set increment fields to zero

SUBROUTINE roms_increment_zero_c (c_key_self) &
                            BIND (c, name='roms_increment_zero_f90')

  integer(c_int),     intent(in) :: c_key_self

  TYPE (roms_increment), pointer :: self

  CALL roms_increment_registry%get (c_key_self, self)
  CALL self%zeros ()

END SUBROUTINE roms_increment_zero_c

! ------------------------------------------------------------------------------
!>  Initialize increment with a Dirac delta function

SUBROUTINE roms_increment_dirac_c (c_key_self, c_conf) &
                             BIND (c, name='roms_increment_dirac_f90')

  integer(c_int),     intent(in) :: c_key_self
  TYPE (c_ptr),       intent(in) :: c_conf          !< Configuration

  TYPE (roms_increment), pointer :: self

  CALL roms_increment_registry%get (c_key_self, self)
  CALL self%dirac (fckit_configuration(c_conf))

END SUBROUTINE roms_increment_dirac_c

! ------------------------------------------------------------------------------
!>  Set increments to random values with a normal distribution

SUBROUTINE roms_increment_random_c (c_key_self) &
                              BIND (c, name='roms_increment_random_f90')

  integer(c_int),     intent(in) :: c_key_self

  TYPE (roms_increment), pointer :: self

  CALL roms_increment_registry%get (c_key_self, self)
  CALL self%random ()

END SUBROUTINE roms_increment_random_c

! ------------------------------------------------------------------------------
!>  Copy increment fields from RHS to SELF

SUBROUTINE roms_increment_copy_c (c_key_self, c_key_rhs) &
                            BIND (c, name='roms_increment_copy_f90')

  integer(c_int),     intent(in) :: c_key_self
  integer(c_int),     intent(in) :: c_key_rhs

  TYPE (roms_increment), pointer :: self
  TYPE (roms_increment), pointer :: rhs

  CALL roms_increment_registry%get (c_key_self, self)
  CALL roms_increment_registry%get (c_key_rhs, rhs)

  CALL self%copy (rhs)

END SUBROUTINE roms_increment_copy_c

! ------------------------------------------------------------------------------
!>  Add RHS increment fields to SELF

SUBROUTINE roms_increment_self_add_c (c_key_self, c_key_rhs) &
                                BIND (c, name='roms_increment_self_add_f90')

  integer(c_int),     intent(in) :: c_key_self
  integer(c_int),     intent(in) :: c_key_rhs

  TYPE (roms_increment), pointer :: self
  TYPE (roms_increment), pointer :: rhs

  CALL roms_increment_registry%get (c_key_self, self)
  CALL roms_increment_registry%get (c_key_rhs, rhs)

  CALL self%add (rhs)

END SUBROUTINE roms_increment_self_add_c

! ------------------------------------------------------------------------------
!>  Perfomr a Shur product between SELF and RHS

SUBROUTINE roms_increment_self_schur_c (c_key_self, c_key_rhs) &
                                  BIND (c, name='roms_increment_self_schur_f90')

  integer(c_int),     intent(in) :: c_key_self
  integer(c_int),     intent(in) :: c_key_rhs

  TYPE (roms_increment), pointer :: self
  TYPE (roms_increment), pointer :: rhs

  CALL roms_increment_registry%get (c_key_self, self)
  CALL roms_increment_registry%get (c_key_rhs, rhs)

  CALL self%schur (rhs)

END SUBROUTINE roms_increment_self_schur_c

! ------------------------------------------------------------------------------
!>  Subtract two set of increments (SELF - RHS)

SUBROUTINE roms_increment_self_sub_c (c_key_self, c_key_rhs) &
                                BIND (c, name='roms_increment_self_sub_f90')

  integer(c_int),     intent(in) :: c_key_self
  integer(c_int),     intent(in) :: c_key_rhs

  TYPE (roms_increment), pointer :: self
  TYPE (roms_increment), pointer :: rhs

  CALL roms_increment_registry%get (c_key_self, self)
  CALL roms_increment_registry%get (c_key_rhs, rhs)

  CALL self%sub (rhs)

END SUBROUTINE roms_increment_self_sub_c

! ------------------------------------------------------------------------------
!>  Multipjy increment fields by a constant

SUBROUTINE roms_increment_self_mul_c (c_key_self, c_zz) &
                                BIND (c, name='roms_increment_self_mul_f90')

  integer(c_int),     intent(in) :: c_key_self
  real(c_double),     intent(in) :: c_zz

  TYPE (roms_increment), pointer :: self
  real(kind=kind_real)           :: zz

  CALL roms_increment_registry%get (c_key_self, self)
  zz = c_zz

  CALL self%mul (zz)

END SUBROUTINE roms_increment_self_mul_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_increment_accumul_c (c_key_self, c_zz, c_key_rhs) &
                               BIND (c, name='roms_increment_accumul_f90')

  integer(c_int),     intent(in) :: c_key_self
  real(c_double),     intent(in) :: c_zz
  integer(c_int),     intent(in) :: c_key_rhs

  TYPE (roms_increment), pointer :: self
  TYPE (roms_state),     pointer :: rhs

  real(kind=kind_real)           :: zz

  CALL roms_increment_registry%get (c_key_self, self)
  CALL roms_state_registry%get (c_key_rhs, rhs)
  zz = c_zz

  CALL self%axpy (zz, rhs)

END SUBROUTINE roms_increment_accumul_c

! ------------------------------------------------------------------------------
!>  Add two increment fields (multiplying the RHS first by a constant)

SUBROUTINE roms_increment_axpy_c (c_key_self, c_zz, c_key_rhs) &
                            BIND (c, name='roms_increment_axpy_f90')

  integer(c_int),     intent(in) :: c_key_self
  real(c_double),     intent(in) :: c_zz
  integer(c_int),     intent(in) :: c_key_rhs

  TYPE (roms_increment), pointer :: self
  TYPE (roms_increment), pointer :: rhs
  real(kind=kind_real)           :: zz

  CALL roms_increment_registry%get (c_key_self, self)
  CALL roms_increment_registry%get (c_key_rhs, rhs)
  zz = c_zz

  CALL self%axpy (zz,rhs)

END SUBROUTINE roms_increment_axpy_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_increment_dot_prod_c (c_key_fld1, c_key_fld2, c_prod) &
                                bind (c, name='roms_increment_dot_prod_f90')

  integer(c_int),     intent(in) :: c_key_fld1, c_key_fld2
  real(c_double),  intent(inout) :: c_prod

  TYPE (roms_increment), pointer :: fld1, fld2
  real(kind=kind_real)           :: zz

  CALL roms_increment_registry%get (c_key_fld1, fld1)
  CALL roms_increment_registry%get (c_key_fld2, fld2)

  CALL fld1%dot_prod (fld2, zz)

  c_prod = zz

END SUBROUTINE roms_increment_dot_prod_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_increment_diff_incr_c (c_key_lhs, c_key_x1, c_key_x2) &
                                 BIND (c, name='roms_increment_diff_incr_f90')

  integer(c_int),     intent(in) :: c_key_lhs
  integer(c_int),     intent(in) :: c_key_x1
  integer(c_int),     intent(in) :: c_key_x2

  TYPE (roms_increment), pointer :: lhs
  TYPE (roms_state),     pointer :: x1
  TYPE (roms_state),     pointer :: x2

  CALL roms_increment_registry%get (c_key_lhs, lhs)
  CALL roms_state_registry%get (c_key_x1, x1)
  CALL roms_state_registry%get (c_key_x2,x2)
  CALL x1%diff_incr (x2, lhs)

END SUBROUTINE roms_increment_diff_incr_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_increment_change_resol_c (c_key_fld, c_key_rhs) &
                                    BIND (c, name='roms_increment_change_resol_f90')

  integer(c_int),     intent(in) :: c_key_fld
  integer(c_int),     intent(in) :: c_key_rhs

  TYPE (roms_increment), pointer :: fld, rhs

  CALL roms_increment_registry%get (c_key_fld, fld)
  CALL roms_increment_registry%get (c_key_rhs, rhs)

  IF ((SIZE(fld%geom%lonr,1) .eq. SIZE(rhs%geom%lonr,1)) .and. &
      (SIZE(fld%geom%latr,2) .eq. SIZE(rhs%geom%latr,2)) .and. &
      (fld%geom%N .eq. rhs%geom%N)) THEN
    CALL fld%copy (rhs)
  ELSE
!   CALL fld%convert (rhs)
  END IF

END SUBROUTINE roms_increment_change_resol_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_increment_read_file_c (c_key_fld, c_conf, c_dt) &
                                 BIND (c, name='roms_increment_read_file_f90')

  integer(c_int),     intent(in) :: c_key_fld    !< Fields
  TYPE (c_ptr),       intent(in) :: c_conf       !< Configuration
  TYPE (c_ptr),    intent(inout) :: c_dt         !< DateTime

  TYPE (roms_increment), pointer :: fld
  TYPE (datetime)                :: fdate

  CALL roms_increment_registry%get (c_key_fld, fld)
  CALL c_f_datetime (c_dt, fdate)
  CALL fld%read (fckit_configuration(c_conf), fdate)

END SUBROUTINE roms_increment_read_file_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_increment_write_file_c (c_key_fld, c_conf, c_dt) &
                                  BIND (c, name='roms_increment_write_file_f90')

  integer(c_int),     intent(in) :: c_key_fld    !< Fields
  TYPE (c_ptr),       intent(in) :: c_conf       !< Configuration
  TYPE (c_ptr),       intent(in) :: c_dt         !< DateTime

  TYPE (roms_increment), pointer :: fld
  TYPE (datetime)                :: fdate

  CALL roms_increment_registry%get (c_key_fld, fld)
  CALL c_f_datetime (c_dt, fdate)
  CALL fld%write (fckit_configuration(c_conf), fdate)

END SUBROUTINE roms_increment_write_file_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_increment_gpnorm_c (c_key_fld, kf, pstat) &
                              BIND (c, name='roms_increment_gpnorm_f90')

  integer(c_int),     intent(in) :: c_key_fld
  integer(c_int),     intent(in) :: kf
  real(c_double),  intent(inout) :: pstat(3*kf)

  TYPE (roms_increment), pointer :: fld
  real(kind=kind_real)           :: zstat(3, kf)
  integer                        :: ic, js, jf

  CALL roms_increment_registry%get (c_key_fld, fld)

  CALL fld%gpnorm (kf, zstat)

  ic=0
  DO jf = 1, kf
    DO js = 1, 3
      ic=ic+1
      pstat(ic) = zstat(js,jf)
    END DO
  END DO

END SUBROUTINE roms_increment_gpnorm_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_increment_rms_c (c_key_fld, prms) &
                           BIND (c, name='roms_increment_rms_f90')

  integer(c_int),     intent(in) :: c_key_fld
  real(c_double),  intent(inout) :: prms

  TYPE (roms_increment), pointer :: fld
  real(kind=kind_real)           :: zz

  CALL roms_increment_registry%get (c_key_fld, fld)

  CALL fld%dot_prod (fld, zz)
  prms = SQRT(zz)

END SUBROUTINE roms_increment_rms_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_increment_getpoint_c (c_key_fld, c_key_iter, values, values_len) &
                                BIND (c, name='roms_increment_getpoint_f90')

  integer(c_int),     intent(in) :: c_key_fld
  integer(c_int),     intent(in) :: c_key_iter
  integer(c_int),     intent(in) :: values_len
  real(c_double),  intent(inout) :: values(values_len)

  TYPE (roms_increment), pointer :: fld
  TYPE (roms_geom_iter), pointer :: iter

  CALL roms_increment_registry%get (c_key_fld, fld)
  CALL roms_geom_iter_registry%get (c_key_iter, iter)

  CALL fld%getpoint (iter, values)

END SUBROUTINE roms_increment_getpoint_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_increment_setpoint_c (c_key_fld, c_key_iter, values, values_len) &
                                BIND (c, name='roms_increment_setpoint_f90')

  integer(c_int),  intent(inout) :: c_key_fld
  integer(c_int),     intent(in) :: c_key_iter
  integer(c_int),     intent(in) :: values_len
  real(c_double),     intent(in) :: values(values_len)

  TYPE (roms_increment), pointer :: fld
  TYPE (roms_geom_iter), pointer :: iter

  CALL roms_increment_registry%get (c_key_fld, fld)
  CALL roms_geom_iter_registry%get (c_key_iter, iter)

  CALL fld%setpoint (iter, values)

END SUBROUTINE roms_increment_setpoint_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_incrementnum_c (c_key_fld, nx, ny, nz, nf) &
                          BIND (c,name='roms_increment_sizes_f90')

  integer(c_int),         intent(in) :: c_key_fld
  integer(kind=c_int), intent(inout) :: nx, ny, nz, nf

  TYPE (roms_increment),     pointer :: fld

  CALL roms_increment_registry%get (c_key_fld, fld)

  nx = SIZE(fld%geom%lonr,1)
  ny = SIZE(fld%geom%lonr,2)
  nz = fld%geom%N
  nf = SIZE(fld%fields)

END SUBROUTINE roms_incrementnum_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_increment_serial_size_c (c_key_self,c_key_geom,c_vec_size) &
                                   BIND (c, name='roms_increment_serial_size_f90')

  integer(c_int),     intent(in) :: c_key_self
  integer(c_int),     intent(in) :: c_key_geom
  integer(c_size_t), intent(out) :: c_vec_size

  TYPE (roms_increment), pointer :: self
  TYPE (roms_geom),      pointer :: geom

  integer                        :: vec_size

  CALL roms_increment_registry%get (c_key_self, self)
  CALL roms_geom_registry%get (c_key_geom, geom)

  CALL self%serial_size (geom, vec_size)
  c_vec_size = vec_size

END SUBROUTINE roms_increment_serial_size_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_increment_serialize_c (c_key_self, c_key_geom, c_vec_size, c_vec) &
                                 BIND (c, name='roms_increment_serialize_f90')

  integer(c_int),     intent(in) :: c_key_self
  integer(c_int),     intent(in) :: c_key_geom
  integer(c_size_t),  intent(in) :: c_vec_size
  real(c_double),    intent(out) :: c_vec(c_vec_size)

  type (roms_increment), pointer :: self
  type (roms_geom),      pointer :: geom
  integer                        :: vec_size

  vec_size = c_vec_size

  CALL roms_increment_registry%get (c_key_self, self)
  CALL roms_geom_registry%get (c_key_geom, geom)

  CALL self%serialize (geom, vec_size, c_vec)

END SUBROUTINE roms_increment_serialize_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_increment_deserialize_c (c_key_self, c_key_geom, c_vec_size, c_vec, c_index) &
                                   BIND (c, name='roms_increment_deserialize_f90')

  integer(c_int),       intent(in) :: c_key_self
  integer(c_int),       intent(in) :: c_key_geom
  integer(c_size_t),    intent(in) :: c_vec_size
  real(c_double),       intent(in) :: c_vec(c_vec_size)
  integer(c_size_t), intent(inout) :: c_index

  type(roms_increment),    pointer :: self
  type(roms_geom),         pointer :: geom
  integer                          :: vec_size, idx

  vec_size = c_vec_size
  idx = c_index

  CALL roms_increment_registry%get (c_key_self, self)
  CALL roms_geom_registry%get (c_key_geom, geom)

  CALL self%deserialize (geom, vec_size, c_vec, idx)
  c_index=idx

END SUBROUTINE roms_increment_deserialize_c

! ------------------------------------------------------------------------------

END MODULE roms_increment_mod_c
