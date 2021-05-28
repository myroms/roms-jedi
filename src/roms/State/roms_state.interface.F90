! (C) Copyright 2020-2021 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
! Hernan G. Arango, Rutgers University, Apr 2021

!> Interfaces to be called from C++ for Fortran handling of model fields

! ------------------------------------------------------------------------------

MODULE roms_state_mod_c

USE iso_c_binding

USE datetime_mod,               ONLY : datetime, c_f_datetime
USE fckit_configuration_module, ONLY : fckit_configuration
USE kinds,                      ONLY : kind_real
USE oops_variables_mod
USE roms_geom_mod_c,            ONLY : roms_geom_registry
USE roms_geom_mod,              ONLY : roms_geom
USE roms_increment_mod
USE roms_increment_reg
USE roms_state_mod
USE roms_state_reg
USE ufo_geovals_mod_c,          ONLY : ufo_geovals_registry
USE ufo_geovals_mod,            ONLY : ufo_geovals

implicit none

PRIVATE

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

SUBROUTINE roms_state_create_c (c_key_self, c_key_geom, c_vars) &
                          BIND (c, name='roms_state_create_f90')

  integer(c_int),  intent(inout) :: c_key_self  !< Handle to field
  integer(c_int),     intent(in) :: c_key_geom  !< Geometry
  TYPE (c_ptr),value, intent(in) :: c_vars      !< List of variables

  TYPE (roms_state),     pointer :: self
  TYPE (roms_geom),      pointer :: geom
  TYPE (oops_variables)          :: vars

  CALL roms_geom_registry%get (c_key_geom, geom)
  CALL roms_state_registry%init ()
  CALL roms_state_registry%add (c_key_self)
  CALL roms_state_registry%get (c_key_self, self)

  vars = oops_variables(c_vars)
  CALL self%create (geom, vars)

END SUBROUTINE roms_state_create_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_state_delete_c (c_key_self) &
                          BIND (c, name='roms_state_delete_f90')

  integer(c_int),  intent(inout) :: c_key_self

  TYPE (roms_state),     pointer :: self

  CALL roms_state_registry%get (c_key_self, self)
  CALL self%delete ()
  CALL roms_state_registry%remove (c_key_self)

END SUBROUTINE roms_state_delete_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_state_zero_c (c_key_self) &
                        BIND (c, name='roms_state_zero_f90')

  integer(c_int),  intent(in) :: c_key_self

  TYPE (roms_state),  pointer :: self

  CALL roms_state_registry%get (c_key_self, self)
  CALL self%zeros ()

END SUBROUTINE roms_state_zero_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_state_copy_c (c_key_self, c_key_rhs) &
                        BIND (c, name='roms_state_copy_f90')

  integer(c_int),  intent(in) :: c_key_self
  integer(c_int),  intent(in) :: c_key_rhs

  TYPE (roms_state),  pointer :: self
  TYPE (roms_state),  pointer :: rhs

  CALL roms_state_registry%get (c_key_self, self)
  CALL roms_state_registry%get (c_key_rhs, rhs)

  CALL self%copy(rhs)

END SUBROUTINE roms_state_copy_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_state_axpy_c (c_key_self, c_zz, c_key_rhs) &
                        BIND (c, name='roms_state_axpy_f90')

  integer(c_int),  intent(in) :: c_key_self
  real(c_double),  intent(in) :: c_zz
  integer(c_int),  intent(in) :: c_key_rhs

  TYPE (roms_state),  pointer :: self
  real(kind=kind_real)        :: zz
  TYPE (roms_state),  pointer :: rhs

  CALL roms_state_registry%get (c_key_self, self)
  CALL roms_state_registry%get (c_key_rhs, rhs)
  zz = c_zz

  CALL self%axpy (zz, rhs)

END SUBROUTINE roms_state_axpy_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_state_add_incr_c (c_key_self, c_key_rhs) &
                            BIND (c, name='roms_state_add_incr_f90')

  integer(c_int),     intent(in) :: c_key_self
  integer(c_int),     intent(in) :: c_key_rhs

  TYPE (roms_state),     pointer :: self
  TYPE (roms_increment), pointer :: rhs

  CALL roms_state_registry%get (c_key_self, self)
  CALL roms_increment_registry%get (c_key_rhs, rhs)

  CALL self%add_incr (rhs)

END SUBROUTINE roms_state_add_incr_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_state_read_file_c (c_key_fld, c_conf, c_dt) &
                             BIND (c, name='roms_state_read_file_f90')

  integer(c_int),  intent(in) :: c_key_fld  !< Fields
  TYPE (c_ptr),    intent(in) :: c_conf     !< Configuration
  TYPE (c_ptr), intent(inout) :: c_dt       !< DateTime

  TYPE (roms_state),  pointer :: fld
  TYPE (datetime)             :: fdate

  CALL roms_state_registry%get (c_key_fld, fld)
  CALL c_f_datetime (c_dt, fdate)
  CALL fld%read (fckit_configuration(c_conf), fdate)

END SUBROUTINE roms_state_read_file_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_state_write_file_c (c_key_fld, c_conf, c_dt) &
                              BIND (c, name='roms_state_write_file_f90')

  integer(c_int),  intent(in) :: c_key_fld  !< Fields
  TYPE (c_ptr),    intent(in) :: c_conf     !< Configuration
  TYPE (c_ptr),    intent(in) :: c_dt       !< DateTime

  TYPE (roms_state),  pointer :: fld
  TYPE (datetime)             :: fdate

  CALL roms_state_registry%get (c_key_fld, fld)
  CALL c_f_datetime (c_dt, fdate)
  CALL fld%write (fckit_configuration(c_conf), fdate)

END SUBROUTINE roms_state_write_file_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_state_gpnorm_c (c_key_fld, kf, pstat) &
                          BIND (c, name='roms_state_gpnorm_f90')

  integer(c_int),     intent(in) :: c_key_fld
  integer(c_int),     intent(in) :: kf
  real(c_double),  intent(inout) :: pstat(3*kf)

  TYPE (roms_state),     pointer :: fld
  real(kind=kind_real)           :: zstat(3, kf)
  integer :: jj, js, jf

  CALL roms_state_registry%get (c_key_fld, fld)

  CALL fld%gpnorm (kf, zstat)

  jj=0
  DO jf = 1, kf
    DO js = 1, 3
      jj=jj+1
      pstat(jj) = zstat(js,jf)
    END DO
  END DO

END SUBROUTINE roms_state_gpnorm_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_state_rms_c (c_key_fld, prms) &
                       BIND (c, name='roms_state_rms_f90')

  integer(c_int),     intent(in) :: c_key_fld
  real(c_double),  intent(inout) :: prms

  TYPE (roms_state),     pointer :: fld
  real(kind=kind_real)           :: zz

  CALL roms_state_registry%get (c_key_fld, fld)

  CALL fld%dot_prod (fld, zz)
  prms = SQRT(zz)

END SUBROUTINE roms_state_rms_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_state_rotate2grid_c (c_key_self, c_uvars, c_vvars) &
                               BIND (c, name='roms_state_rotate2grid_f90')

  integer(c_int),  intent(in)     :: c_key_self
  TYPE (c_ptr), value, intent(in) :: c_uvars
  TYPE (c_ptr), value, intent(in) :: c_vvars

  TYPE (roms_state),      pointer :: self
  TYPE (oops_variables)           :: uvars, vvars

  uvars = oops_variables(c_uvars)
  vvars = oops_variables(c_vvars)

  CALL roms_state_registry%get (c_key_self, self)
  CALL self%rotate (coordinate="grid", uvars=uvars, vvars=vvars)

END SUBROUTINE roms_state_rotate2grid_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_state_rotate2north_c (c_key_self, c_uvars, c_vvars) &
                                BIND (c, name='roms_state_rotate2north_f90')

  integer(c_int),      intent(in) :: c_key_self
  TYPE (c_ptr), value, intent(in) :: c_uvars
  TYPE (c_ptr), value, intent(in) :: c_vvars

  TYPE (roms_state),      pointer :: self
  TYPE (oops_variables)           :: uvars, vvars

  uvars = oops_variables(c_uvars)
  vvars = oops_variables(c_vvars)

  CALL roms_state_registry%get (c_key_self, self)
  CALL self%rotate (coordinate="north", uvars=uvars, vvars=vvars)

END SUBROUTINE roms_state_rotate2north_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_state_sizes_c (c_key_fld, nx, ny, nz, nf) &
                         BIND (c, name='roms_state_sizes_f90')

  integer(c_int),         intent(in) :: c_key_fld
  integer(kind=c_int), intent(inout) :: nx, ny, nz, nf

  TYPE (roms_state),         pointer :: fld

  CALL roms_state_registry%get (c_key_fld, fld)

  nx = SIZE(fld%geom%lonr, 1)
  ny = SIZE(fld%geom%lonr, 2)
  nz = fld%geom%N
  nf = SIZE(fld%fields)

END SUBROUTINE roms_state_sizes_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_state_change_resol_c (c_key_fld, c_key_rhs) &
                                BIND (c, name='roms_state_change_resol_f90')

  integer(c_int),  intent(in) :: c_key_fld
  integer(c_int),  intent(in) :: c_key_rhs

  TYPE (roms_state),  pointer :: fld, rhs

  CALL roms_state_registry%get (c_key_fld, fld)
  CALL roms_state_registry%get (c_key_rhs, rhs)

  ! TODO (Guillaume or Travis) implement == in geometry or something to that effect.
  
  IF ((SIZE(fld%geom%lonr,1) .eq. SIZE(rhs%geom%lonr,1)) .and. &
      (SIZE(fld%geom%latr,2) .eq. SIZE(rhs%geom%latr,2)) .and. &
      (fld%geom%N .eq. rhs%geom%N)) THEN
    CALL fld%copy (rhs)
  ELSE
    call fld%convert (rhs)
  ENDIF

END SUBROUTINE roms_state_change_resol_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_state_serial_size_c (c_key_self, c_key_geom, c_vec_size) &
                               BIND (c, name='roms_state_serial_size_f90')

  integer(c_int),     intent(in) :: c_key_self
  integer(c_int),     intent(in) :: c_key_geom
  integer(c_size_t), intent(out) :: c_vec_size

  TYPE (roms_state),     pointer :: self
  TYPE (roms_geom),      pointer :: geom
  integer                        :: vec_size

  CALL roms_state_registry%get (c_key_self, self)
  CALL roms_geom_registry%get (c_key_geom, geom)

  CALL self%serial_size (geom, vec_size)
  c_vec_size = vec_size

END SUBROUTINE roms_state_serial_size_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_state_serialize_c (c_key_self, c_key_geom, c_vec_size, c_vec) &
                             BIND (c, name='roms_state_serialize_f90')

  implicit none

  integer(c_int),    intent(in) :: c_key_self
  integer(c_int),    intent(in) :: c_key_geom
  integer(c_size_t), intent(in) :: c_vec_size
  real(c_double),   intent(out) :: c_vec(c_vec_size)

  TYPE (roms_state),    pointer :: self
  TYPE (roms_geom),     pointer :: geom

  integer                       :: vec_size

  vec_size = c_vec_size
  CALL roms_state_registry%get (c_key_self, self)
  CALL roms_geom_registry%get (c_key_geom, geom)

  CALL self%serialize (geom, vec_size, c_vec)

END SUBROUTINE roms_state_serialize_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_state_deserialize_c (c_key_self, c_key_geom, c_vec_size, c_vec, c_index) &
                               BIND (c, name='roms_state_deserialize_f90')

  integer(c_int),       intent(in) :: c_key_self
  integer(c_int),       intent(in) :: c_key_geom
  integer(c_size_t),    intent(in) :: c_vec_size
  real(c_double),       intent(in) :: c_vec(c_vec_size)
  integer(c_size_t), intent(inout) :: c_index

  TYPE (roms_state),       pointer :: self
  TYPE (roms_geom),        pointer :: geom
  integer :: vec_size, idx

  vec_size = c_vec_size
  idx = c_index
  CALL roms_state_registry%get (c_key_self, self)
  CALL roms_geom_registry%get (c_key_geom, geom)

  CALL self%deserialize (geom, vec_size, c_vec, idx)
  c_index = idx

END SUBROUTINE roms_state_deserialize_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_state_logtrans_c (c_key_self, c_trvars) &
                            BIND (c, name='roms_state_logtrans_f90')

  integer(c_int),      intent(in) :: c_key_self
  TYPE (c_ptr), value, intent(in) :: c_trvars

  TYPE (roms_state),      pointer :: self
  TYPE (oops_variables)           :: trvars

  trvars = oops_variables(c_trvars)

  CALL roms_state_registry%get (c_key_self, self)
  CALL self%logexpon (transfunc="log", trvars=trvars)

END SUBROUTINE roms_state_logtrans_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_state_expontrans_c (c_key_self, c_trvars) &
                              BIND (c, name='roms_state_expontrans_f90')

  integer(c_int),      intent(in) :: c_key_self
  TYPE (c_ptr), value, intent(in) :: c_trvars

  TYPE (roms_state),      pointer :: self
  TYPE (oops_variables)           :: trvars

  trvars = oops_variables(c_trvars)

  CALL roms_state_registry%get (c_key_self, self)
  CALL self%logexpon (transfunc="expon", trvars=trvars)

END SUBROUTINE roms_state_expontrans_c

! ------------------------------------------------------------------------------

END MODULE roms_state_mod_c
