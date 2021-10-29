! (C) Copyright 2020-2021 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
!>
!! \brief    Fortran and C++ binding interface for ROMS-JEDI State class
!!
!! \details  Interoperability mechanism for the State class that allows
!!           Fortran to invoke C++ functions and vice versa C++ to invoke
!!           Fortran procedures.
!!
!! \author   Hernan G. Arango (Rutgers University)
!! \date     April 2021

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
!> Create state fields object.

SUBROUTINE roms_state_create_c (c_key_self, c_key_geom, c_vars)              &
                          BIND (c, name='roms_state_create_f90')

  integer (c_int),     intent(inout) :: c_key_self  !< State fields pointer
  integer (c_int),     intent(in   ) :: c_key_geom  !< Geometry pointer
  TYPE (c_ptr), value, intent(in   ) :: c_vars      !< Variables list pointer

  TYPE (roms_state), pointer         :: self
  TYPE (roms_geom),  pointer         :: geom
  TYPE (oops_variables)              :: vars

  CALL roms_geom_registry%get (c_key_geom, geom)
  CALL roms_state_registry%init ()
  CALL roms_state_registry%add (c_key_self)
  CALL roms_state_registry%get (c_key_self, self)

  vars = oops_variables(c_vars)
  CALL self%create (geom, vars)

END SUBROUTINE roms_state_create_c

! ------------------------------------------------------------------------------
!> Deallocate state fields.

SUBROUTINE roms_state_delete_c (c_key_self)                                  &
                          BIND (c, name='roms_state_delete_f90')

  integer (c_int), intent(inout) :: c_key_self   !< State fields pointer

  TYPE (roms_state), pointer     :: self

  CALL roms_state_registry%get (c_key_self, self)
  CALL self%delete ()
  CALL roms_state_registry%remove (c_key_self)

END SUBROUTINE roms_state_delete_c

! ------------------------------------------------------------------------------
!> Set state fields to zero.

SUBROUTINE roms_state_zero_c (c_key_self)                                    &
                        BIND (c, name='roms_state_zero_f90')

  integer (c_int), intent(in) :: c_key_self   !< State fields pointer

  TYPE (roms_state),  pointer :: self

  CALL roms_state_registry%get (c_key_self, self)
  CALL self%zeros ()

END SUBROUTINE roms_state_zero_c

! ------------------------------------------------------------------------------
!> Copy state fields: LHS = RHS

SUBROUTINE roms_state_copy_c (c_key_self, c_key_rhs)                         &
                        BIND (c, name='roms_state_copy_f90')

  integer (c_int), intent(in) :: c_key_self   !< output state fields pointer
  integer (c_int), intent(in) :: c_key_rhs    !< input  state fields pointer

  TYPE (roms_state),  pointer :: self
  TYPE (roms_state),  pointer :: rhs

  CALL roms_state_registry%get (c_key_self, self)
  CALL roms_state_registry%get (c_key_rhs, rhs)

  CALL self%copy (rhs)

END SUBROUTINE roms_state_copy_c

! ------------------------------------------------------------------------------
!> Compute LHS = LHS + zz * RHS

SUBROUTINE roms_state_axpy_c (c_key_self, c_zz, c_key_rhs)                   &
                        BIND (c, name='roms_state_axpy_f90')

  integer (c_int),  intent(in) :: c_key_self   !< LHS state fields pointer
  real (c_double),  intent(in) :: c_zz         !< multiplication constant
  integer (c_int),  intent(in) :: c_key_rhs    !< LRS state fields pointer

  TYPE (roms_state),  pointer  :: self
  real (kind=kind_real)        :: zz
  TYPE (roms_state),  pointer  :: rhs

  CALL roms_state_registry%get (c_key_self, self)
  CALL roms_state_registry%get (c_key_rhs, rhs)
  zz = c_zz

  CALL self%axpy (zz, rhs)

END SUBROUTINE roms_state_axpy_c

! ------------------------------------------------------------------------------
!> Add a set of increments to the set fields: SELF(i) = SELF(i) + RHS(i)

SUBROUTINE roms_state_add_incr_c (c_key_self, c_key_rhs) &
                            BIND (c, name='roms_state_add_incr_f90')

  integer (c_int),     intent(in) :: c_key_self    !< state fields pointer
  integer (c_int),     intent(in) :: c_key_rhs     !< fields increment pointer

  TYPE (roms_state),     pointer :: self
  TYPE (roms_increment), pointer :: rhs

  CALL roms_state_registry%get (c_key_self, self)
  CALL roms_increment_registry%get (c_key_rhs, rhs)

  CALL self%add_incr (rhs)

END SUBROUTINE roms_state_add_incr_c

! ------------------------------------------------------------------------------
!> Initialize state fields by reading from an input NetCDF file if "statefile"
!! has "read_from_file: 1" or with analytical expressions if "state generate"
!! has "analytic init.method: ana_ocnfields" and "read_from_file: 0" in the
!! YAML configuration file.

SUBROUTINE roms_state_read_file_c (c_key_fld, c_conf, c_dt) &
                             BIND (c, name='roms_state_read_file_f90')

  integer (c_int),     intent(in   ) :: c_key_fld  !< State fields pointer
  TYPE (c_ptr), value, intent(in   ) :: c_conf     !< Configuration pointer
  TYPE (c_ptr),        intent(inout) :: c_dt       !< DateTime pointer

  TYPE (roms_state),  pointer        :: fld
  TYPE (datetime)                    :: fdate

  CALL roms_state_registry%get (c_key_fld, fld)
  CALL c_f_datetime (c_dt, fdate)
  CALL fld%read (fckit_configuration(c_conf), fdate)

END SUBROUTINE roms_state_read_file_c

! ------------------------------------------------------------------------------
!> Initialize state fields with analytical expressions.
!!
!! It is activated if  "state generate" has "read_from_file: 0" and the keyword
!! "analytic init.method" has as value "ana_ocnfields" or "uniform_ocnfields"
!! in the YAML configuration file. This routine is a duplicated method for
!! analytic initialization to that of the fields class 'roms_fields". That is,
!! calls to self%analytic_init and self%analytic are identical since since the
!! state class "roms_state" is  and extension of "roms_fields". Therefore,
!! this interface is not needed.

SUBROUTINE roms_state_analytic_c (c_key_state, c_conf, c_dt)                 &
                            BIND (c, name='roms_state_analytic_f90')

  integer (c_int),     intent(in   ) :: c_key_state  !< State fields pointer
  TYPE (c_ptr), value, intent(in   ) :: c_conf       !< Configuration pointer
  TYPE (c_ptr),        intent(inout) :: c_dt         !< DateTime pointer

  TYPE (roms_state), pointer         :: self
  TYPE (datetime)                    :: fdate

  CALL roms_state_registry%get (c_key_state, self)
  CALL c_f_datetime (c_dt, fdate)
  CALL self%analytic (fckit_configuration(c_conf), fdate)

END SUBROUTINE roms_state_analytic_c

! ------------------------------------------------------------------------------
!> Write out state fields into NetCDF file.

SUBROUTINE roms_state_write_file_c (c_key_fld, c_conf, c_dt)                 &
                              BIND (c, name='roms_state_write_file_f90')

  integer (c_int),      intent(in) :: c_key_fld   !< State fields pointer
  TYPE  (c_ptr), value, intent(in) :: c_conf      !< Configuration pointer
  TYPE  (c_ptr),        intent(in) :: c_dt        !< DateTime pointer

  TYPE (roms_state), pointer       :: fld
  TYPE (datetime)                  :: fdate
  TYPE (fckit_configuration)       :: f_conf

  CALL roms_state_registry%get (c_key_fld, fld)
  CALL c_f_datetime (c_dt, fdate)
  f_conf = fckit_configuration (c_conf)
! CALL fld%write (fckit_configuration(c_conf), fdate)
  CALL fld%write (f_conf, fdate)

END SUBROUTINE roms_state_write_file_c

! ------------------------------------------------------------------------------
!> Calculate global statistics for each state field: min, max, and  avg.

SUBROUTINE roms_state_gpnorm_c (c_key_fld, kf, pstat)                        &
                          BIND (c, name='roms_state_gpnorm_f90')

  integer (c_int),  intent(in   ) :: c_key_fld    !< State fields pointer
  integer (c_int),  intent(in   ) :: kf           !< fields number pointer
  real (c_double),  intent(inout) :: pstat(3*kf)  !< statistics pointer

  TYPE (roms_state), pointer      :: fld
  real (kind=kind_real)           :: zstat(3, kf)
  integer                         :: jj, js, jf

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
!> Calculate the squared-root of the dot-product sum of a field to itself:
!! unnormalized RMS.

SUBROUTINE roms_state_rms_c (c_key_fld, prms)                                &
                       BIND (c, name='roms_state_rms_f90')

  integer (c_int),  intent(in   ) :: c_key_fld    !< State fields pointer
  real (c_double),  intent(inout) :: prms         !< RMS pointer

  TYPE (roms_state), pointer      :: fld
  real(kind=kind_real)            :: psum

  CALL roms_state_registry%get (c_key_fld, fld)

  ! Squared-root of the dot-product sum. Notice that we are not calling
  ! fld%rms that will give prms = SQRT(psum/norm), where norm = npts.

  CALL fld%dot_prod (fld, psum)
  prms = SQRT(psum)

END SUBROUTINE roms_state_rms_c

! ------------------------------------------------------------------------------
!> Rotate vector fields from geographical to curvilinear coordinates.

SUBROUTINE roms_state_rotate2grid_c (c_key_self, c_uvars, c_vvars)           &
                               BIND (c, name='roms_state_rotate2grid_f90')

  integer (c_int),     intent(in) :: c_key_self    !< State fields pointer
  TYPE (c_ptr), value, intent(in) :: c_uvars       !< U-component variables
  TYPE (c_ptr), value, intent(in) :: c_vvars       !< V-component variables

  TYPE (roms_state),      pointer :: self
  TYPE (oops_variables)           :: uvars, vvars

  uvars = oops_variables(c_uvars)
  vvars = oops_variables(c_vvars)

  CALL roms_state_registry%get (c_key_self, self)
  CALL self%rotate (coordinate="grid", uvars=uvars, vvars=vvars)

END SUBROUTINE roms_state_rotate2grid_c

! ------------------------------------------------------------------------------
!> Rotate vector fields from curvilinear to geographical coordinates.

SUBROUTINE roms_state_rotate2north_c (c_key_self, c_uvars, c_vvars)          &
                                BIND (c, name='roms_state_rotate2north_f90')

  integer (c_int),     intent(in) :: c_key_self    !< State fields pointer
  TYPE (c_ptr), value, intent(in) :: c_uvars       !< U-component variables
  TYPE (c_ptr), value, intent(in) :: c_vvars       !< V-component variables

  TYPE (roms_state),      pointer :: self
  TYPE (oops_variables)           :: uvars, vvars

  uvars = oops_variables(c_uvars)
  vvars = oops_variables(c_vvars)

  CALL roms_state_registry%get (c_key_self, self)
  CALL self%rotate (coordinate="north", uvars=uvars, vvars=vvars)

END SUBROUTINE roms_state_rotate2north_c

! ------------------------------------------------------------------------------
!> Get length of the dimensions of a state 3D-field.

SUBROUTINE roms_state_sizes_c (c_key_fld, nx, ny, nz, nf)                    &
                         BIND (c, name='roms_state_sizes_f90')

  integer (c_int),      intent(in   ) :: c_key_fld    !< State fields pointer
  integer (kind=c_int), intent(inout) :: nx           !< X-dimension
  integer (kind=c_int), intent(inout) :: ny           !< Y-dimension
  integer (kind=c_int), intent(inout) :: nz           !< Z-dimension
  integer (kind=c_int), intent(inout) :: nf           !< number of fields

  TYPE (roms_state),         pointer :: fld

  CALL roms_state_registry%get (c_key_fld, fld)

  nx = SIZE(fld%geom%lonr, DIM=1)
  ny = SIZE(fld%geom%lonr, DIM=2)
  nz = fld%geom%N
  nf = SIZE(fld%fields)

END SUBROUTINE roms_state_sizes_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_state_change_resol_c (c_key_fld, c_key_rhs)                  &
                                BIND (c, name='roms_state_change_resol_f90')

  integer (c_int), intent(in) :: c_key_fld    !< LHS state fields pointer
  integer (c_int), intent(in) :: c_key_rhs    !< RHS state fields pointer

  TYPE (roms_state),  pointer :: fld, rhs

  CALL roms_state_registry%get (c_key_fld, fld)
  CALL roms_state_registry%get (c_key_rhs, rhs)

  ! TODO: implement == in geometry or something to that effect.
  
  IF ((SIZE(fld%geom%lonr,1) .eq. SIZE(rhs%geom%lonr,1)) .and. &
      (SIZE(fld%geom%latr,2) .eq. SIZE(rhs%geom%latr,2)) .and. &
      (fld%geom%N .eq. rhs%geom%N)) THEN
    CALL fld%copy (rhs)
  ELSE
    CALL fld%convert (rhs)
  ENDIF

END SUBROUTINE roms_state_change_resol_c

! ------------------------------------------------------------------------------
!> Compute the number of elements in the packed (serialized) state vector.

SUBROUTINE roms_state_serial_size_c (c_key_self, c_key_geom, c_vec_size)     &
                               BIND (c, name='roms_state_serial_size_f90')

  integer (c_int),    intent(in ) :: c_key_self    !< State fields pointer
  integer (c_int),    intent(in ) :: c_key_geom    !< Geometry pointer
  integer (c_size_t), intent(out) :: c_vec_size    !< number of elements

  TYPE (roms_state), pointer      :: self
  TYPE (roms_geom), pointer       :: geom
  integer                         :: vec_size

  CALL roms_state_registry%get (c_key_self, self)
  CALL roms_geom_registry%get (c_key_geom, geom)

  CALL self%serial_size (geom, vec_size)
  c_vec_size = vec_size

END SUBROUTINE roms_state_serial_size_c

! ------------------------------------------------------------------------------
!> Pack all the fields into 1D state vector.

SUBROUTINE roms_state_serialize_c (c_key_self, c_key_geom, c_vec_size, c_vec) &
                             BIND (c, name='roms_state_serialize_f90')

  integer (c_int),    intent(in ) :: c_key_self         !< State fields pointer
  integer (c_int),    intent(in ) :: c_key_geom         !< Geometry pointer
  integer (c_size_t), intent(in ) :: c_vec_size         !< State vector length
  real (c_double),    intent(out) :: c_vec(c_vec_size)  !< State vector

  TYPE (roms_state), pointer      :: self
  TYPE (roms_geom), pointer       :: geom

  integer                         :: vec_size

  vec_size = c_vec_size
  CALL roms_state_registry%get (c_key_self, self)
  CALL roms_geom_registry%get (c_key_geom, geom)

  CALL self%serialize (geom, vec_size, c_vec)

END SUBROUTINE roms_state_serialize_c

! ------------------------------------------------------------------------------
!> Unpack all fields from state vector.

SUBROUTINE roms_state_deserialize_c (c_key_self, c_key_geom,                 &
                                     c_vec_size, c_vec, c_index)             &
                               BIND (c, name='roms_state_deserialize_f90')

  integer (c_int),    intent(in   ) :: c_key_self        !< State fields pointer
  integer (c_int),    intent(in   ) :: c_key_geom        !< Geometry pointer
  integer (c_size_t), intent(in   ) :: c_vec_size        !< State vector length
  real (c_double),    intent(in   ) :: c_vec(c_vec_size) !< State vector
  integer (c_size_t), intent(inout) :: c_index           !< Unpack vector length

  TYPE (roms_state), pointer        :: self
  TYPE (roms_geom), pointer         :: geom

  integer                           :: vec_size, idx

  vec_size = c_vec_size
  idx = c_index
  CALL roms_state_registry%get (c_key_self, self)
  CALL roms_geom_registry%get (c_key_geom, geom)

  CALL self%deserialize (geom, vec_size, c_vec, idx)
  c_index = idx

END SUBROUTINE roms_state_deserialize_c

! ------------------------------------------------------------------------------
!> Appy logarithmic transformation to state.

SUBROUTINE roms_state_logtrans_c (c_key_self, c_trvars)                      &
                            BIND (c, name='roms_state_logtrans_f90')

  integer (c_int),     intent(in) :: c_key_self     !< State fields pointer
  TYPE (c_ptr), value, intent(in) :: c_trvars       !< Variables to transform

  TYPE (roms_state), pointer      :: self
  TYPE (oops_variables)           :: trvars

  trvars = oops_variables(c_trvars)

  CALL roms_state_registry%get (c_key_self, self)
  CALL self%logexpon (transfunc="log", trvars=trvars)

END SUBROUTINE roms_state_logtrans_c

! ------------------------------------------------------------------------------
!> Appy exponential transformation to state.

SUBROUTINE roms_state_expontrans_c (c_key_self, c_trvars)                    &
                              BIND (c, name='roms_state_expontrans_f90')

  integer (c_int),     intent(in) :: c_key_self     !< State fields pointer
  TYPE (c_ptr), value, intent(in) :: c_trvars       !< Variables to transform

  TYPE (roms_state),      pointer :: self
  TYPE (oops_variables)           :: trvars

  trvars = oops_variables(c_trvars)

  CALL roms_state_registry%get (c_key_self, self)
  CALL self%logexpon (transfunc="expon", trvars=trvars)

END SUBROUTINE roms_state_expontrans_c

! ------------------------------------------------------------------------------

END MODULE roms_state_mod_c
