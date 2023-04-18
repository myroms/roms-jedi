! (C) Copyright 2020-2022 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
!>
!! \brief    Fortran and C++ binding interface for ROMS-JEDI Increment Class
!!
!! \details  Interoperability mechanism for the Increment Class that allows
!!           Fortran to invoke C++ functions and vice versa C++ to invoke
!!           Fortran procedures.
!!
!! \author   Hernan G. Arango (Rutgers University)
!! \date     October 2021

MODULE roms_increment_mod_c

USE iso_c_binding
USE kinds,                      ONLY : kind_real

USE atlas_module,               ONLY : atlas_fieldset
USE datetime_mod,               ONLY : datetime, c_f_datetime
USE fckit_configuration_module, ONLY : fckit_configuration
USE oops_variables_mod
USE ufo_geovals_mod_c,          ONLY : ufo_geovals_registry
USE ufo_geovals_mod,            ONLY : ufo_geovals

USE roms_geom_mod,              ONLY : roms_geom
USE roms_geom_reg,              ONLY : roms_geom_registry
USE roms_geomIterator_mod,      ONLY : roms_geomIterator
USE roms_geomIterator_reg,      ONLY : roms_geomIterator_registry
USE roms_increment_mod,         ONLY : roms_increment
USE roms_increment_reg,         ONLY : roms_increment_registry
USE roms_state_mod,             ONLY : roms_state
USE roms_state_reg,             ONLY : roms_state_registry

implicit none

PRIVATE

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
!>  Creates an increment object.

SUBROUTINE roms_increment_create_c (c_key_self, c_key_geom, c_vars)            &
                              BIND (c, name='roms_increment_create_f90')

  integer (c_int),     intent(inout) :: c_key_self  !< Increment object pointer
  integer (c_int),     intent(in   ) :: c_key_geom  !< Geometry object pointer
  TYPE (c_ptr), value, intent(in   ) :: c_vars      !< Variables list pointer

  TYPE (roms_increment), pointer     :: self
  TYPE (roms_geom),      pointer     :: geom
  TYPE (oops_variables)              :: vars

  CALL roms_geom_registry%get (c_key_geom, geom)
  CALL roms_increment_registry%init ()
  CALL roms_increment_registry%add (c_key_self)
  CALL roms_increment_registry%get (c_key_self,self)

  vars = oops_variables(c_vars)

  CALL self%create (geom, vars)

  END SUBROUTINE roms_increment_create_c

! ------------------------------------------------------------------------------
!>  Deletes increment object.

SUBROUTINE roms_increment_delete_c (c_key_self)                                &
                              BIND (c, name='roms_increment_delete_f90')

  integer (c_int), intent(inout) :: c_key_self      !< Increment object pointer

  TYPE (roms_increment), pointer :: self

  CALL roms_increment_registry%get (c_key_self, self)
  CALL self%delete ()
  CALL roms_increment_registry%remove (c_key_self)

END SUBROUTINE roms_increment_delete_c

! ------------------------------------------------------------------------------
!>  Set increment fields to unity.

SUBROUTINE roms_increment_ones_c (c_key_self)                                  &
                            BIND (c, name='roms_increment_ones_f90')

  integer (c_int),    intent(in) :: c_key_self      !< Increment object pointer

  TYPE (roms_increment), pointer :: self

  CALL roms_increment_registry%get (c_key_self, self)
  CALL self%ones ()

END SUBROUTINE roms_increment_ones_c

! ------------------------------------------------------------------------------
!>  Set increment fields to zero.

SUBROUTINE roms_increment_zero_c (c_key_self)                                &
                            BIND (c, name='roms_increment_zero_f90')

  integer (c_int),    intent(in) :: c_key_self      !< Increment object pointer

  TYPE (roms_increment), pointer :: self

  CALL roms_increment_registry%get (c_key_self, self)
  CALL self%zeros ()

END SUBROUTINE roms_increment_zero_c

! ------------------------------------------------------------------------------
!>  Initialize increment with a Dirac delta function.

SUBROUTINE roms_increment_dirac_c (c_key_self, c_conf)                         &
                             BIND (c, name='roms_increment_dirac_f90')

  integer (c_int),     intent(in) :: c_key_self     !< Increment object pointer
  TYPE (c_ptr), value, intent(in) :: c_conf         !< Configuration

  TYPE (roms_increment), pointer :: self

  CALL roms_increment_registry%get (c_key_self, self)
  CALL self%dirac (fckit_configuration(c_conf))

END SUBROUTINE roms_increment_dirac_c

! ------------------------------------------------------------------------------
!>  Set increments to random values with a normal distribution.

SUBROUTINE roms_increment_random_c (c_key_self)                                &
                              BIND (c, name='roms_increment_random_f90')

  integer (c_int),    intent(in) :: c_key_self      !< Increment object pointer

  TYPE (roms_increment), pointer :: self

  CALL roms_increment_registry%get (c_key_self, self)
  CALL self%random ()

END SUBROUTINE roms_increment_random_c

! ------------------------------------------------------------------------------
!>  Copy increment fields from RHS to SELF.

SUBROUTINE roms_increment_copy_c (c_key_self, c_key_rhs)                       &
                            BIND (c, name='roms_increment_copy_f90')

  integer (c_int),    intent(in) :: c_key_self      !< Increment object pointer
  integer (c_int),    intent(in) :: c_key_rhs       !< Increment object pointer

  TYPE (roms_increment), pointer :: self
  TYPE (roms_increment), pointer :: rhs

  CALL roms_increment_registry%get (c_key_self, self)
  CALL roms_increment_registry%get (c_key_rhs, rhs)

  CALL self%copy (rhs)

END SUBROUTINE roms_increment_copy_c

! ------------------------------------------------------------------------------
!>  Add RHS increment fields to SELF.

SUBROUTINE roms_increment_self_add_c (c_key_self, c_key_rhs)                   &
                                BIND (c, name='roms_increment_self_add_f90')

  integer (c_int),    intent(in) :: c_key_self      !< Increment object pointer
  integer (c_int),    intent(in) :: c_key_rhs       !< Increment object pointer

  TYPE (roms_increment), pointer :: self
  TYPE (roms_increment), pointer :: rhs

  CALL roms_increment_registry%get (c_key_self, self)
  CALL roms_increment_registry%get (c_key_rhs, rhs)

  CALL self%add (rhs)

END SUBROUTINE roms_increment_self_add_c

! ------------------------------------------------------------------------------
!>  Perform a Shur product between SELF and RHS increment objects.

SUBROUTINE roms_increment_self_schur_c (c_key_self, c_key_rhs)                 &
                                  BIND (c, name='roms_increment_self_schur_f90')

  integer (c_int),    intent(in) :: c_key_self      !< Increment object pointer
  integer (c_int),    intent(in) :: c_key_rhs       !< Increment object pointer

  TYPE (roms_increment), pointer :: self
  TYPE (roms_increment), pointer :: rhs

  CALL roms_increment_registry%get (c_key_self, self)
  CALL roms_increment_registry%get (c_key_rhs, rhs)

  CALL self%schur (rhs)

END SUBROUTINE roms_increment_self_schur_c

! ------------------------------------------------------------------------------
!>  Subtract two set of increments (SELF - RHS).

SUBROUTINE roms_increment_self_sub_c (c_key_self, c_key_rhs)                   &
                                BIND (c, name='roms_increment_self_sub_f90')

  integer (c_int),    intent(in) :: c_key_self      !< Increment object pointer
  integer (c_int),    intent(in) :: c_key_rhs       !< Increment object pointer

  TYPE (roms_increment), pointer :: self
  TYPE (roms_increment), pointer :: rhs

  CALL roms_increment_registry%get (c_key_self, self)
  CALL roms_increment_registry%get (c_key_rhs, rhs)

  CALL self%sub (rhs)

END SUBROUTINE roms_increment_self_sub_c

! ------------------------------------------------------------------------------
!>  Multiply increment fields by a constant.

SUBROUTINE roms_increment_self_mul_c (c_key_self, c_zz)                        &
                                BIND (c, name='roms_increment_self_mul_f90')

  integer (c_int),    intent(in) :: c_key_self      !< Increment object pointer
  real (c_double),    intent(in) :: c_zz            !< Constant pointer

  TYPE (roms_increment), pointer :: self
  real(kind=kind_real)           :: zz

  CALL roms_increment_registry%get (c_key_self, self)
  zz = c_zz

  CALL self%mul (zz)

END SUBROUTINE roms_increment_self_mul_c

! ------------------------------------------------------------------------------
!  Adds to increment fields the procduct of state fields time constant.

SUBROUTINE roms_increment_accumul_c (c_key_self, c_zz, c_key_rhs)              &
                               BIND (c, name='roms_increment_accumul_f90')

  integer (c_int),    intent(in) :: c_key_self      !< Increment object pointer
  real (c_double),    intent(in) :: c_zz            !< Constant pointer
  integer (c_int),    intent(in) :: c_key_rhs       !< Increment object pointer

  TYPE (roms_increment), pointer :: self
  TYPE (roms_state),     pointer :: rhs

  real (kind=kind_real)          :: zz

  CALL roms_increment_registry%get (c_key_self, self)
  CALL roms_state_registry%get (c_key_rhs, rhs)
  zz = c_zz

  CALL self%axpy (zz, rhs)

END SUBROUTINE roms_increment_accumul_c

! ------------------------------------------------------------------------------
!>  Adds two increment fields (multiplying the RHS first by a constant).

SUBROUTINE roms_increment_axpy_c (c_key_self, c_zz, c_key_rhs)                 &
                            BIND (c, name='roms_increment_axpy_f90')

  integer (c_int),    intent(in) :: c_key_self      !< Increment object pointer
  real (c_double),    intent(in) :: c_zz            !< Constant pointer
  integer (c_int),    intent(in) :: c_key_rhs       !< Increment object pointer

  TYPE (roms_increment), pointer :: self
  TYPE (roms_increment), pointer :: rhs
  real(kind=kind_real)           :: zz

  CALL roms_increment_registry%get (c_key_self, self)
  CALL roms_increment_registry%get (c_key_rhs, rhs)
  zz = c_zz

  CALL self%axpy (zz, rhs)

END SUBROUTINE roms_increment_axpy_c

! ------------------------------------------------------------------------------
!> Computes the global dot-product sum of two sets of increment fields.

SUBROUTINE roms_increment_dot_prod_c (c_key_fld1, c_key_fld2, c_prod)          &
                                BIND (c, name='roms_increment_dot_prod_f90')

  integer (c_int), intent(in   ) :: c_key_fld1      !< Field 1 object pointer 
  integer (c_int), intent(in   ) :: c_key_fld2      !< Field 2 object pointer 
  real (c_double), intent(inout) :: c_prod          !< dot product value pointer

  TYPE (roms_increment), pointer :: fld1, fld2
  real (kind=kind_real)          :: zz

  CALL roms_increment_registry%get (c_key_fld1, fld1)
  CALL roms_increment_registry%get (c_key_fld2, fld2)

  CALL fld1%dot_prod (fld2, zz)

  c_prod = zz

END SUBROUTINE roms_increment_dot_prod_c

! ------------------------------------------------------------------------------
!> Computes the increment fields by subracting state fields (x1 - x2).

SUBROUTINE roms_increment_diff_incr_c (c_key_lhs, c_key_x1, c_key_x2)          &
                                 BIND (c, name='roms_increment_diff_incr_f90')

  integer (c_int),    intent(in) :: c_key_lhs       !< Increment object pointer
  integer (c_int),    intent(in) :: c_key_x1        !< State 1 object pointer
  integer (c_int),    intent(in) :: c_key_x2        !< State 2 object pointer

  TYPE (roms_increment), pointer :: lhs
  TYPE (roms_state),     pointer :: x1
  TYPE (roms_state),     pointer :: x2

  CALL roms_increment_registry%get (c_key_lhs, lhs)
  CALL roms_state_registry%get (c_key_x1, x1)
  CALL roms_state_registry%get (c_key_x2, x2)
  CALL x1%diff_incr (x2, lhs)

END SUBROUTINE roms_increment_diff_incr_c

! ------------------------------------------------------------------------------
!> Interpolates increment object between geometries.
!! TODO: implement the spatial interpolation.

SUBROUTINE roms_increment_change_resol_c (c_key_fld, c_key_rhs)                 &
                              BIND (c, name='roms_increment_change_resol_f90')

  integer (c_int),    intent(in) :: c_key_fld       !< Increment object pointer
  integer (c_int),    intent(in) :: c_key_rhs       !< Increment object pointer

  TYPE (roms_increment), pointer :: fld, rhs

  CALL roms_increment_registry%get (c_key_fld, fld)
  CALL roms_increment_registry%get (c_key_rhs, rhs)

  IF ((SIZE(fld%geom%lonr,1) .eq. SIZE(rhs%geom%lonr,1)) .and.                 &
      (SIZE(fld%geom%latr,2) .eq. SIZE(rhs%geom%latr,2)) .and.                 &
      (fld%geom%N .eq. rhs%geom%N)) THEN
    CALL fld%copy (rhs)
  ELSE
!   CALL fld%convert (rhs)
  END IF

END SUBROUTINE roms_increment_change_resol_c

! ------------------------------------------------------------------------------
!> Loads increment object data into ATLAS object.

SUBROUTINE roms_increment_to_fieldset_c (c_key_self, c_key_geom, c_vars,       &
                                         c_afieldset)                          &
                          BIND (c, name='roms_increment_to_fieldset_f90')

  integer (c_int),     intent(in) :: c_key_self     !< Increment fields pointer
  integer (c_int),     intent(in) :: c_key_geom     !< Geometry pointer
  TYPE (c_ptr), value, intent(in) :: c_vars         !< List of Variables
  TYPE (c_ptr), value, intent(in) :: c_afieldset    !< ATLAS FieldSet

  TYPE (roms_increment), pointer  :: self
  TYPE (roms_geom),  pointer      :: geom
  TYPE (oops_variables)           :: vars
  TYPE (atlas_fieldset)           :: afieldset

  CALL roms_increment_registry%get (c_key_self, self)
  CALL roms_geom_registry%get (c_key_geom, geom)

  vars = oops_variables(c_vars)
  afieldset = atlas_fieldset(c_afieldset)

  CALL self%to_fieldset (geom, vars, afieldset)

END SUBROUTINE roms_increment_to_fieldset_c

! ------------------------------------------------------------------------------
!> Loads adjoint increment object data into ATLAS object.

SUBROUTINE roms_increment_to_fieldset_ad_c (c_key_self, c_key_geom, c_vars,    &
                                            c_afieldset)                       &
                          BIND (c, name='roms_increment_to_fieldset_ad_f90')

  integer (c_int),     intent(in) :: c_key_self     !< Increment fields pointer
  integer (c_int),     intent(in) :: c_key_geom     !< Geometry pointer
  TYPE (c_ptr), value, intent(in) :: c_vars         !< List of Variables
  TYPE (c_ptr), value, intent(in) :: c_afieldset    !< ATLAS FieldSet

  TYPE (roms_increment), pointer  :: self
  TYPE (roms_geom),  pointer      :: geom
  TYPE (oops_variables)           :: vars
  TYPE (atlas_fieldset)           :: afieldset

  CALL roms_increment_registry%get (c_key_self, self)
  CALL roms_geom_registry%get (c_key_geom, geom)

  vars = oops_variables(c_vars)
  afieldset = atlas_fieldset(c_afieldset)

  CALL self%to_fieldset_ad (geom, vars, afieldset)

END SUBROUTINE roms_increment_to_fieldset_ad_c

! ------------------------------------------------------------------------------
!> Fills increment object with data from the ATLAS object.

SUBROUTINE roms_increment_from_fieldset_c (c_key_self, c_key_geom, c_vars,     &
                                           c_afieldset)                        &
                          BIND (c, name='roms_increment_from_fieldset_f90')

  integer (c_int),     intent(in) :: c_key_self     !< Increment field pointer
  integer (c_int),     intent(in) :: c_key_geom     !< Geometry pointer
  TYPE (c_ptr), value, intent(in) :: c_vars         !< List of Variables
  TYPE (c_ptr), value, intent(in) :: c_afieldset    !< ATLAS FieldSet

  TYPE (roms_increment), pointer  :: self
  TYPE (roms_geom),  pointer      :: geom
  TYPE (oops_variables)           :: vars
  TYPE (atlas_fieldset)           :: afieldset

  CALL roms_increment_registry%get (c_key_self, self)
  CALL roms_geom_registry%get (c_key_geom, geom)

  vars = oops_variables(c_vars)
  afieldset = atlas_fieldset(c_afieldset)

  CALL self%from_fieldset (geom, vars, afieldset)

END SUBROUTINE roms_increment_from_fieldset_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_increment_read_file_c (c_key_fld, c_conf, c_dt)                &
                                 BIND (c, name='roms_increment_read_file_f90')

  integer (c_int),     intent(in   ) :: c_key_fld   !< Fields object pointer
  TYPE (c_ptr), value, intent(in   ) :: c_conf      !< Configuration pointer
  TYPE (c_ptr),        intent(inout) :: c_dt        !< DateTime pointer

  TYPE (roms_increment), pointer     :: fld
  TYPE (datetime)                    :: fdate

  CALL roms_increment_registry%get (c_key_fld, fld)
  CALL c_f_datetime (c_dt, fdate)
  CALL fld%read (fckit_configuration(c_conf), fdate)

END SUBROUTINE roms_increment_read_file_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_increment_write_file_c (c_key_fld, c_conf, c_dt)               &
                                  BIND (c, name='roms_increment_write_file_f90')

  integer (c_int),     intent(in) :: c_key_fld      !< Fields object pointer
  TYPE (c_ptr), value, intent(in) :: c_conf         !< Configuration pointer
  TYPE (c_ptr),        intent(in) :: c_dt           !< DateTime pointer

  TYPE (roms_increment), pointer  :: fld
  TYPE (datetime)                 :: fdate

  CALL roms_increment_registry%get (c_key_fld, fld)
  CALL c_f_datetime (c_dt, fdate)
  CALL fld%write (fckit_configuration(c_conf), fdate)

END SUBROUTINE roms_increment_write_file_c

! ------------------------------------------------------------------------------
!> Calculates increment statistics for each field.

SUBROUTINE roms_increment_gstats_c (c_key_fld, kf, pstat)                      &
                              BIND (c, name='roms_increment_gstats_f90')

  integer (c_int),    intent(in) :: c_key_fld       !< Fields object pointer
  integer (c_int),    intent(in) :: kf              !< number of fields pointer
  real (c_double), intent(inout) :: pstat(4*kf)     !< statistics pointer

  TYPE (roms_increment), pointer :: fld
  real (kind=kind_real)          :: zstat(4, kf)
  integer                        :: ic, js, jf

  CALL roms_increment_registry%get (c_key_fld, fld)

  CALL fld%gstats (kf, zstat)

  ic=0
  DO jf = 1, kf
    DO js = 1, 4
      ic=ic+1
      pstat(ic) = zstat(js,jf)
    END DO
  END DO

END SUBROUTINE roms_increment_gstats_c

! ------------------------------------------------------------------------------
!> Computes the energy norm per unit area (10^6 J/m2) for the state increment
!  vector.

SUBROUTINE roms_increment_norm_c (c_key_fld, Enorm)                             &
                           BIND (c, name='roms_increment_norm_f90')

  integer (c_int), intent(in   ) :: c_key_fld       !< Fields object pointer
  real (c_double), intent(inout) :: Enorm           !< Energy norm pointer

  TYPE (roms_increment), pointer :: fld

  CALL roms_increment_registry%get (c_key_fld, fld)

  CALL fld%norm (Enorm)

END SUBROUTINE roms_increment_norm_c

! ------------------------------------------------------------------------------
!> Gets increment values at specified grid points (GeometryIterator).

SUBROUTINE roms_increment_getpoint_c (c_key_fld, c_key_iter, values,           &
                                      values_len)                              &
                                BIND (c, name='roms_increment_getpoint_f90')

  integer (c_int),    intent(in   ) :: c_key_fld       !< Increment object
  integer (c_int),    intent(in   ) :: c_key_iter      !< GeometryIterator
  integer (c_int),    intent(in   ) :: values_len
  real (c_double),    intent(inout) :: values(values_len)

  TYPE (roms_increment),    pointer :: fld
  TYPE (roms_geomIterator), pointer :: iter

  CALL roms_increment_registry%get (c_key_fld, fld)
  CALL roms_geomIterator_registry%get (c_key_iter, iter)

  CALL fld%getpoint (iter, values)

END SUBROUTINE roms_increment_getpoint_c

! ------------------------------------------------------------------------------
!> Sets grid points (GeometryIterator) for which increment values are needed.

SUBROUTINE roms_increment_setpoint_c (c_key_fld, c_key_iter, values,           &
                                      values_len)                              &
                                BIND (c, name='roms_increment_setpoint_f90')

  integer (c_int),    intent(inout) :: c_key_fld          !< Increment object
  integer (c_int),    intent(in   ) :: c_key_iter         !< GeomtryIterator
  integer (c_int),    intent(in   ) :: values_len
  real (c_double),    intent(in   ) :: values(values_len)

  TYPE (roms_increment),    pointer :: fld
  TYPE (roms_geomIterator), pointer :: iter

  CALL roms_increment_registry%get (c_key_fld, fld)
  CALL roms_geomIterator_registry%get (c_key_iter, iter)

  CALL fld%setpoint (iter, values)

END SUBROUTINE roms_increment_setpoint_c

! ------------------------------------------------------------------------------
!  Computes the increment object spatial dimensions and number of fields. 

SUBROUTINE roms_incrementnum_c (c_key_fld, nx, ny, nz, nf)                     &
                          BIND (c, name='roms_increment_sizes_f90')

  integer (c_int),      intent(in   ) :: c_key_fld      !< Fields object pointer
  integer (kind=c_int), intent(inout) :: nx, ny, nz, nf

  TYPE (roms_increment), pointer      :: fld

  CALL roms_increment_registry%get (c_key_fld, fld)

  nx = SIZE(fld%geom%lonr,1)
  ny = SIZE(fld%geom%lonr,2)
  nz = fld%geom%N
  nf = SIZE(fld%fields)

END SUBROUTINE roms_incrementnum_c

! ------------------------------------------------------------------------------
!> Computes the number of elements in the packed increment vector.

SUBROUTINE roms_increment_serial_size_c (c_key_self, c_key_geom, c_vec_size)   &
                                 BIND (c, name='roms_increment_serial_size_f90')

  integer (c_int),    intent(in ) :: c_key_self     !< Increment object pointer
  integer (c_int),    intent(in ) :: c_key_geom     !< Geometry object pointer
  integer (c_size_t), intent(out) :: c_vec_size     !< Increment vector length

  TYPE (roms_increment), pointer  :: self
  TYPE (roms_geom),      pointer  :: geom

  integer                         :: vec_size

  CALL roms_increment_registry%get (c_key_self, self)
  CALL roms_geom_registry%get (c_key_geom, geom)

  CALL self%serial_size (geom, vec_size)
  c_vec_size = vec_size

END SUBROUTINE roms_increment_serial_size_c

! ------------------------------------------------------------------------------
!> Packs the increment object into a vector.

SUBROUTINE roms_increment_serialize_c (c_key_self, c_key_geom, c_vec_size,     &
                                       c_vec)                                  &
                                 BIND (c, name='roms_increment_serialize_f90')

  integer (c_int),    intent(in ) :: c_key_self     !< Increment object pointer
  integer (c_int),    intent(in ) :: c_key_geom     !< Geometry object pointer
  integer (c_size_t), intent(in ) :: c_vec_size
  real (c_double),    intent(out) :: c_vec(c_vec_size)

  type (roms_increment), pointer  :: self
  type (roms_geom),      pointer  :: geom
  integer                         :: vec_size

  vec_size = c_vec_size

  CALL roms_increment_registry%get (c_key_self, self)
  CALL roms_geom_registry%get (c_key_geom, geom)

  CALL self%serialize (geom, vec_size, c_vec)

END SUBROUTINE roms_increment_serialize_c

! ------------------------------------------------------------------------------
!> Unpacks the all fields in the increment vector.

SUBROUTINE roms_increment_deserialize_c (c_key_self, c_key_geom, c_vec_size,   &
                                         c_vec, c_index)                       &
                                 BIND (c, name='roms_increment_deserialize_f90')

  integer (c_int),    intent(in   ) :: c_key_self   !< Increment object pointer
  integer (c_int),    intent(in   ) :: c_key_geom   !< Geometry object pointer
  integer (c_size_t), intent(in   ) :: c_vec_size
  real (c_double),    intent(in   ) :: c_vec(c_vec_size)
  integer (c_size_t), intent(inout) :: c_index

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
!> Add or remove fields because of VariableChange object elsewhere.

SUBROUTINE roms_increment_update_fields_c (c_key_self, c_vars)                 &
                          BIND (c, name='roms_increment_update_fields_f90')

  integer (c_int),     intent(inout) :: c_key_self  !< State fields pointer
  TYPE (c_ptr), value, intent(in   ) :: c_vars      !< List of variables

  TYPE (roms_increment), pointer     :: self
  TYPE (oops_variables)              :: vars

  CALL roms_increment_registry%get (c_key_self, self)

  vars = oops_variables(c_vars)
  CALL self%update_fields (vars)

END SUBROUTINE roms_increment_update_fields_c

! ------------------------------------------------------------------------------

END MODULE roms_increment_mod_c
