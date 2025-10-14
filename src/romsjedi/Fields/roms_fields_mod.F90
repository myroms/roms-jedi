! (C) Copyright 2017-2025 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://Qwww.apache.org/licenses/LICENSE-2.0.
!
!>
!! \brief   **Fields Class** for ROMS state vector
!!
!! \details This class includes several routines used to create, destroy, get,
!!          check, operate, manipulate, read, and write each field in the state
!!          vector. It is one of the elementary classes for JEDI model agnostic
!!          data assimilation algorithms.
!!
!! \author  Hernan G. Arango (Rutgers University)
!! \date    June 2021

MODULE roms_fields_mod

USE atlas_module,               ONLY : atlas_field,                            &
                                       atlas_fieldset,                         &
                                       atlas_metadata,                         &
                                       atlas_real
USE datetime_mod
USE duration_mod
USE fckit_configuration_module, ONLY : fckit_configuration
USE fckit_log_module,           ONLY : fckit_log
USE fckit_mpi_module,           ONLY : fckit_mpi_comm,                         &
                                       fckit_mpi_min,                          &
                                       fckit_mpi_max,                          &
                                       fckit_mpi_sum

USE kinds,                      ONLY : kind_real

USE oops_variables_mod,         ONLY : oops_variables

USE roms_interpolate_mod,       ONLY : roms_interp_type,                       &
                                       roms_interp_delete,                     &
                                       BilinearMethod

! ROMS modules association.

USE dateclock_mod,              ONLY : datestr
USE mod_grid,                   ONLY : GRID
USE mod_iounits,                ONLY : SourceFile, T_IO, stdout
USE mod_ncparam
USE mod_netcdf,                 ONLY : netcdf_open, netcdf_close,              &
                                       netcdf_inq_var, netcdf_inq_varid,       &
                                       netcdf_put_fvar, netcdf_sync,           &
                                       n_var, rec_size, var_id, var_name
USE mod_param,                  ONLY : MT, Ngrids, iADM, iNLM
USE mod_scalars,                ONLY : NoError, Rclock, exit_flag
USE mp_exchange_mod,            ONLY : ad_mp_exchange2d, ad_mp_exchange3d,     &
                                       mp_exchange2d, mp_exchange3d
USE nf_fread2d_mod,             ONLY : nf_fread2d
USE nf_fread3d_mod,             ONLY : nf_fread3d
USE nf_fwrite2d_mod,            ONLY : nf_fwrite2d
USE nf_fwrite3d_mod,            ONLY : nf_fwrite3d

! ROMS-JEDI interface module association.

USE roms_field_mod,             ONLY : roms_field
USE roms_fields_metadata_mod,   ONLY : roms_field_metadata
USE roms_fieldsutils_mod
USE roms_geom_mod,              ONLY : roms_geom
USE roms_utils_mod,             ONLY : set_string,                             &
                                       vector_a_to_c

implicit none

! ------------------------------------------------------------------------------
!> Structure to holds a collection of roms_field types, and the public routines
!  to manipulate them. Represents all the fields of a given state or increment.
! ------------------------------------------------------------------------------

TYPE, PUBLIC :: roms_fields

  TYPE (roms_geom),  pointer     :: geom => null()    !< Geometry
  TYPE (roms_field), allocatable :: fields(:)         !< Fields set

  TYPE (T_IO), allocatable       :: IO(:)             !< ROMS I/O file structure

  CONTAINS

  ! Field constructors and destructors.

  PROCEDURE :: create          => roms_fields_create
  PROCEDURE :: copy            => roms_fields_copy
  PROCEDURE :: delete          => roms_fields_delete

  ! ATLAS.

  PROCEDURE :: to_fieldset     => roms_fields_to_fieldset
  PROCEDURE :: from_fieldset   => roms_fields_from_fieldset

  ! Field getters and checkers.

  PROCEDURE :: get             => roms_fields_get
  PROCEDURE :: has             => roms_fields_has
  PROCEDURE :: check_congruent => roms_fields_check_congruent
  PROCEDURE :: check_subset    => roms_fields_check_subset

  ! Field math operations.

  PROCEDURE :: add             => roms_fields_add
  PROCEDURE :: axpy            => roms_fields_axpy
  PROCEDURE :: dot_prod        => roms_fields_dot_prod
  PROCEDURE :: enorm           => roms_fields_enorm
  PROCEDURE :: gstats          => roms_fields_gstats
  PROCEDURE :: mul             => roms_fields_mul
  PROCEDURE :: norm            => roms_fields_norm
  PROCEDURE :: rms             => roms_fields_rms
  PROCEDURE :: sub             => roms_fields_sub
  PROCEDURE :: ones            => roms_fields_ones
  PROCEDURE :: zeros           => roms_fields_zeros

  ! Analytical initialization.

  PROCEDURE :: analytic        => roms_fields_analytic

  ! I/O processing.

  PROCEDURE :: IO_create       => roms_fields_IO_create
  PROCEDURE :: IO_metadata     => roms_fields_IO_metadata
  PROCEDURE :: inquire         => roms_fields_inquire
  PROCEDURE :: read            => roms_fields_read
  PROCEDURE :: write           => roms_fields_write
  PROCEDURE :: write_debug     => roms_fields_write_debug

  ! Misc.

  PROCEDURE :: colocate        => roms_fields_colocate
  PROCEDURE :: update_fields   => roms_fields_update_fields
  PROCEDURE :: update_halos    => roms_fields_update_halos

  ! Field serialization.

  PROCEDURE :: serial_size     => roms_fields_serial_size
  PROCEDURE :: serialize       => roms_fields_serialize
  PROCEDURE :: deserialize     => roms_fields_deserialize

END TYPE roms_fields

! ------------------------------------------------------------------------------

integer, parameter, PUBLIC :: fields_clen = 512

PRIVATE

! Number of I/O multi-files.

integer, parameter :: Nfiles = 1

! Define input and output ROMS I/O structures

TYPE (roms_field_metadata), allocatable :: metadata(:) ! I/O metadata structure

! Local MPI communicator.

TYPE (fckit_mpi_comm) :: my_comm

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
!> Create a new set of fields, allocate space for them, and initialize to zero.

SUBROUTINE roms_fields_create (self, geom, vars)

  CLASS (roms_fields),        intent(inout) :: self   !< Fields object
  TYPE (roms_geom),  pointer, intent(inout) :: geom   !< Geometry
  TYPE (oops_variables),      intent(in   ) :: vars   !< Fields names to create

  integer                                   :: i, ng
  character(len=:), allocatable             :: vars_str(:)

  ! Make sure current object has not already been allocated.

  IF (allocated(self%fields)) THEN
    CALL abor1_ftn ('roms_fields::create: SELF object already allocated')
  END IF

  ! Associate geometry.

  self%geom => geom

  IF (LdebugFields .and. (my_comm%rank() .eq. 0)) THEN
    PRINT '(a, 6(a,i0))', 'ROMS_DEBUG roms_fields::create: ',                  &
                          ' tile = ', my_comm%rank(),                          &
                          ', LBi = ', geom%LBi, ', UBi = ', geom%UBi,          &
                          ', LBj = ', geom%LBj, ', UBj = ', geom%UBj,          &
                          ', N = ', geom%N
  END IF

  ! Initialize the variable parameters.

  ALLOCATE (character(len=1024) :: vars_str(vars%nvars()))

  DO i = 1, vars%nvars()
    vars_str(i) = TRIM(vars%variable(i))
  END DO

  CALL roms_fields_init_vars (self, vars_str)

  ! Set everything to zero.

  CALL self%zeros ()

  ! If vertical mixing, initialize to background value.

  ng = geom%ng

  DO i = 1, SIZE(self%fields)
    SELECT CASE (self%fields(i)%name)
      CASE ('AKt', 'Ktocn',                                                    &
            'vertical_diffusion_coefficient_of_temperature_in_sea_water',      &
            'AKs', 'Ksocn',                                                    &
            'vertical_diffusion_coefficient_of_salinity_in_sea_water',         &
            'AKv', 'Kvocn',                                                    &
            'vertical_viscosity_coefficient_of_sea_water')
        self%fields(i)%val = 1.0E-5_kind_real
      CASE ('Hz', 'Hzocn',                                                     &
            'model_level_thickness_at_cell_center')
        self%fields(i)%val = GRID(ng)%Hz
      CASE ('z0ocn_r',                                                         &
            'unvarying_model_level_depth_at_cell_center')
        self%fields(i)%val = GRID(ng)%z0_r
      CASE ('z0ocn_w',                                                         &
            'unvarying_model_level_depth_at_cell_top_face')
        self%fields(i)%val = GRID(ng)%z0_w
      CASE ('z_rho', 'zocn_r',                                                 &
            'model_level_depth_at_cell_center')
        self%fields(i)%val = GRID(ng)%z_r
      CASE ('z_w', 'zocn_w',                                                   &
            'model_level_depth_at_cell_top_face')
        self%fields(i)%val = GRID(ng)%z_w
    END SELECT
  END DO

  ! Allocate and initialize ROMS I/O structure.

  CALL self%IO_create ()

END SUBROUTINE roms_fields_create

! ------------------------------------------------------------------------------
!> Copy the contents of RHS to SELF. SELF will be initialized with the variable
!  names in RHS, if not already initialized.

SUBROUTINE roms_fields_copy (self, rhs)

  CLASS (roms_fields), intent(inout) :: self     !< LHS Fields object
  CLASS (roms_fields), intent(in   ) :: rhs      !< RHS Fields object

  integer                            :: i, nflds
  real (kind=kind_real)              :: stats(4)
  character(len=:), allocatable      :: vars_str(:)
  TYPE (roms_field), pointer         :: rhs_fld

  ! Report fields to process.

  IF (LdebugFields .and. (my_comm%rank() .eq. 0)) THEN
    nflds = SIZE(self%fields)
    PRINT '(a)', 'ROMS_DEBUG roms_fields::copy: Copying from RHS to SELF:'
    PRINT 10,    '  RHS Vars: ', (rhs%fields(i)%metadata%short_name, i=1,nflds)
    PRINT '(6(a,i0))', '  tile = ', rhs%geom%f_comm%rank(),                    &
                          ', LBi = ', rhs%geom%LBi,                            &
                          ', UBi = ', rhs%geom%UBi,                            &
                          ', LBj = ', rhs%geom%LBj,                            &
                          ', UBj = ', rhs%geom%UBj,                            &
                          ', 3D N = ', rhs%geom%N
 10 FORMAT (a, *(1x,a,','))
  END IF

  ! Initialize the variables based on the names in RHS.

  IF (.not. allocated(self%fields)) THEN
    self%geom => rhs%geom

    ALLOCATE (character(len=1024) :: vars_str(SIZE(rhs%fields)))

    DO i = 1, SIZE(vars_str)
      vars_str(i) = rhs%fields(i)%name
    END DO

    CALL roms_fields_init_vars (self, vars_str)
  END IF

  ! Copy values from RHS to SELF, only if the variable exists in SELF.

  DO i = 1, SIZE(self%fields)

    CALL rhs%get (self%fields(i)%name, rhs_fld)
    CALL self%fields(i)%copy (rhs_fld)

    IF (LdebugFields) THEN
      CALL rhs_fld%stats (stats)
      IF (my_comm%rank() .eq. 0) THEN
        PRINT 20, rhs_fld%metadata%short_name, stats(1), stats(2),             &
                  INT(stats(4))
 20     FORMAT (2x,'- ',a,':',t15,'Min = ',1p,e22.15,',  Max = ',1p,e22.15,    &
                ',  CheckSum = ', i0)
      END IF
    END IF

  END DO

END SUBROUTINE roms_fields_copy

! ------------------------------------------------------------------------------
!> Delete all the fields.

SUBROUTINE roms_fields_delete (self)

  CLASS (roms_fields), intent(inout) :: self     !< Fields object

  integer                            :: i

  ! Clear the fields and nullify pointers.

  nullify (self%geom)

  DO i = 1, SIZE(self%fields)
    CALL self%fields(i)%delete ()
  END DO

  deallocate (self%fields)

  ! Deallocate I/O structure. The Fortran 2003 standard allows deallocating
  ! just the parent object to deallocate all array variables within its scope
  ! automatically.

  IF (allocated(self%IO)) deallocate (self%IO)

END SUBROUTINE roms_fields_delete

! ------------------------------------------------------------------------------
!> It loads Fields data into ATLAS FieldSet object. It includes computational
!  points, boundary points, and halo. The fields that are returned have halos
!  (minus the invalid and duplicate halo points), and field values at these
!  halo points are set to zero.

SUBROUTINE roms_fields_to_fieldset (self, geom, vars, afieldset)

  CLASS (roms_fields), target, intent(in   ) :: self         !< Fields object
  TYPE (roms_geom), target,    intent(in   ) :: geom         !< Geometry object
  TYPE (oops_variables),       intent(in   ) :: vars         !< OOPS variables
  TYPE (atlas_fieldset),       intent(inout) :: afieldset    !< ATLAS fieldset

  TYPE (atlas_field)                         :: afield
  TYPE (atlas_metadata)                      :: meta
  TYPE (roms_field), pointer                 :: field

  integer                                    :: IstrD, IendD, JstrD, JendD
  integer                                    :: LBi, UBi, LBj, UBj, N
  integer                                    :: cgrid, i, ivar, j, k, nc
  real (kind=kind_real)                      :: stats(4)
  real (kind=kind_real), pointer             :: fldptr(:,:)

  ! Get tile bounds. Currently, ATLAS allows a single function space which is
  ! problematic with staggered C-grids. That is, ATLAS assumes that all the
  ! variables are at the same location (cell center, A-grid).

  LBi = geom%LBi
  UBi = geom%UBi
  LBj = geom%LBj
  UBj = geom%UBj

  cgrid = r2dvar                               ! RHO-points (cell-center)

  IstrD = geom%bounds(cgrid)%IstrD
  IendD = geom%bounds(cgrid)%IendD
  JstrD = geom%bounds(cgrid)%JstrD
  JendD = geom%bounds(cgrid)%JendD

  ! Load field data into the ATLAS FieldSet object.

  DO ivar = 1, vars%nvars()

    CALL self%get (vars%variable(ivar), field)
    N = field%N

    RHO_VARS : IF (field%metadata%gtype .ne. 'w') THEN     ! Exclude W-points

      IF (LdebugFields) THEN
        CALL field%stats (stats)
        IF (my_comm%rank() .eq. 0) THEN
          IF (ivar.eq.1) PRINT '(a)', 'ROMS_DEBUG roms_fields_to_fieldset:'
          PRINT 10, field%metadata%short_name, stats(1), stats(2),             &
                    INT(stats(4))
 10       FORMAT (2x,'- ',a,':',t15,'Min = ',1p,e22.15,                        &
                  ',  Max = ',1p,e22.15,',  CheckSum = ', i0)
        END IF
      END IF

      ! Get or create ATLAS field.
    
      IF (afieldset%has_field(vars%variable(ivar))) THEN
        afield = afieldset%field(vars%variable(ivar))       ! get field
      ELSE
        afield = geom%functionspace%create_field(name=vars%variable(ivar),     &
                                                 kind=atlas_real(kind_real),   &
                                                 levels=N)
        CALL afieldset%add (afield)                         ! create field
      END IF

      ! Get field pointer to ATLAS and copy data. The pointer is inialized to
      ! and owned values are overwritten.

      CALL afield%data (fldptr)

      fldptr = 0.0_kind_real
      DO k = 1, N
        DO j = JstrD, JendD
          DO i = IstrD, IendD
            nc = self%geom%atlas_ij2node(i,j)
            fldptr(k,nc) = field%val(i,j,k)
          END DO
        END DO
      END DO

      meta = afield%metadata()
      CALL meta%set ('interp_type', TRIM(field%interp_type))

      CALL afield%set_dirty (.TRUE.)         ! mark halos as being out-of-date
      CALL afield%final ()                   ! release pointer
      CALL meta%final ()                     ! release pointer      

    END IF RHO_VARS

  END DO

END SUBROUTINE roms_fields_to_fieldset

! ------------------------------------------------------------------------------
!> It fills Fields object with data from the ATLAS object.

SUBROUTINE roms_fields_from_fieldset (self, geom, vars, afieldset)

  CLASS (roms_fields), target, intent(inout) :: self         !< Fields object
  TYPE (roms_geom),            intent(in   ) :: geom         !< Geometry object
  TYPE (oops_variables),       intent(in   ) :: vars         !< OOPS variables
  TYPE (atlas_fieldset),       intent(in   ) :: afieldset    !< ATLAS fieldset

  TYPE (roms_field), pointer                 :: field
  TYPE (atlas_field)                         :: afield

  integer                                    :: IstrD, IendD, JstrD, JendD
  integer                                    :: cgrid, i, ivar, j, k, nc
  real (kind=kind_real)                      :: stats(4)
  real (kind=kind_real), pointer             :: fldptr(:,:)

  ! Initialize increment fields to zero.

  CALL self%zeros ()

  ! Retrieve field increments from the ATLAS object.

  cgrid = r2dvar                                 ! RHO-points (cell-center)

  IstrD = geom%bounds(cgrid)%IstrD
  IendD = geom%bounds(cgrid)%IendD
  JstrD = geom%bounds(cgrid)%JstrD
  JendD = geom%bounds(cgrid)%JendD

  DO ivar = 1, vars%nvars()

    CALL self%get (vars%variable(ivar), field)

    RHO_VARS : IF (field%metadata%gtype .ne. 'w') THEN     ! Exclude W-points

      ! Get field from ATLAS.

      afield = afieldset%field(vars%variable(ivar))          ! get field

      ! Copy field data.

      CALL afield%data (fldptr)

      DO k = 1, field%N
        DO j = JstrD, JendD
          DO i = IstrD, IendD
            nc = self%geom%atlas_ij2node(i,j)
            field%val(i,j,k) = fldptr(k,nc)
          END DO
        END DO
      END DO

      IF (LdebugFields) THEN
        CALL field%stats (stats)
        IF (my_comm%rank() .eq. 0) THEN
          IF (ivar.eq.1) PRINT '(a)', 'ROMS_DEBUG roms_fields_from_fieldset:'
          PRINT 10, field%metadata%short_name, stats(1), stats(2),             &
                    INT(stats(4))
 10       FORMAT (2x,'- ',a,':',t15,'Min = ',1p,e22.15,                        &
                  ',  Max = ',1p,e22.15,',  CheckSum = ', i0)
        END IF
      END IF

      CALL afield%final ()                                   ! release pointer

    END IF RHO_VARS

  END DO

END SUBROUTINE roms_fields_from_fieldset

! -----------------------------------------------------------------------------
!> Get a pointer to the roms_field with the given name.
!!  If no field exists with that name, the program aborts
!!  (use roms_fields%has() if you need to check for optional fields)

SUBROUTINE roms_fields_get (self, name, field)

  CLASS (roms_fields), target, intent(in ) :: self   !< fields object
  character (len=*),           intent(in ) :: name   !< name of field to find
  TYPE (roms_field), pointer,  intent(out) :: field  !< resulting field pointer

  integer                                  :: i

  ! Find the field with the given internal name or UFO standard name.

  DO i = 1, SIZE(self%fields)
    IF ((TRIM(name) .eq. self%fields(i)%name) .or.                             &
        (TRIM(name) .eq. self%fields(i)%metadata%short_name)) THEN
      field => self%fields(i)
      RETURN
    END IF
  END DO

  ! Error: field was not found.

  CALL abor1_ftn ("roms_fields::get: cannot find field '" // TRIM(name) // "'")

END SUBROUTINE roms_fields_get

! ------------------------------------------------------------------------------
!> Check if field with the given name exists.

FUNCTION roms_fields_has (self, name, findex) RESULT (foundit)

  CLASS (roms_fields), intent(in)  :: self        !< Fields object
  character (len=*),   intent(in)  :: name        !< Fields name
  integer, optional,   intent(out) :: findex      !< field index in set

  logical                         :: foundit      !< returned value
  integer                         :: i

  IF (LdebugFieldsVerbose .and. (my_comm%rank() .eq. 0)) THEN
    PRINT '(2a)', 'ROMS_DEBUG roms_fields::has:  Finding Var = ', TRIM(name)
    DO i = 1, SIZE(self%fields)
      PRINT 10, i, TRIM(self%fields(i)%name),                                  &
                   TRIM(self%fields(i)%metadata%short_name),                   &
                   TRIM(self%fields(i)%metadata%io_name)
 10   FORMAT (2x,'Field ',i2.2,':',2x,'name = ',a,',  short_name = ',a,        &
              ',  io_name = ',a)
    END DO
  END IF

  foundit = .FALSE.
  DO i = 1, SIZE(self%fields)
    IF ((TRIM(name) .eq. TRIM(self%fields(i)%name)) .or.                       &
        (TRIM(name) .eq. TRIM(self%fields(i)%metadata%short_name)) .or.        &
        (TRIM(name) .eq. TRIM(self%fields(i)%metadata%io_name))) THEN
      foundit = .TRUE.
      IF (PRESENT(findex)) findex = i
      RETURN
    END IF
  END DO

END FUNCTION roms_fields_has

! ------------------------------------------------------------------------------
!> Make sure two sets of fields have the same name, size, and shape.

!  TODO: make this more robust (allow for different number of fields?)

SUBROUTINE roms_fields_check_congruent (f1, f2)

  CLASS (roms_fields), intent(in) :: f1          !< Fields set 1 object
  CLASS (roms_fields), intent(in) :: f2          !< Fields set 2 object

  integer                         :: i, j

  ! Number of fields should be the same.

  IF (SIZE(f1%fields) .ne. SIZE(f2%fields)) THEN
    CALL abor1_ftn ("roms_fields::check_congruent: '" //                       &
                    "f1' and 'f2' objects contains different number of fields")
  END IF

  ! Each field should match (name, size, shape).

  DO i = 1, SIZE(f1%fields)
    IF (f1%fields(i)%name .ne. f2%fields(i)%name) THEN
      CALL abor1_ftn ("roms_fields:check_congruent: '" //                      &
                      "f1' and 'f2' objects have different fields names")
    END IF

    DO j = 1, SIZE(SHAPE(f1%fields(i)%val))
      IF (SIZE(f1%fields(i)%val,DIM=j) .ne.                                    &
          SIZE(f2%fields(i)%val,DIM=j) ) THEN
        CALL abor1_ftn ("roms_fields::check_congruent: objects f1' and 'f2'"// &
                        " have different dimensions for '" //                  &
                        f1%fields(i)%name // "'")
      END IF
    END DO
  END DO

END SUBROUTINE roms_fields_check_congruent

! ------------------------------------------------------------------------------
!> Make sure two sets of fields have same shape for each field they have in
!! common, f1 must be a subset of f2.

!  TODO: make this more robust (allow for different number of fields?)

SUBROUTINE roms_fields_check_subset (f1, f2)

  CLASS (roms_fields), intent(in) :: f1          !< Fields set 1 object
  CLASS (roms_fields), intent(in) :: f2          !< Fields set 2 object

  integer                         :: i, j
  TYPE (roms_field), pointer      :: fld

  ! Each field should match (name, size, shape).

  DO i = 1, SIZE(f1%fields)
    IF (.not. f2%has(f1%fields(i)%name)) THEN
      CALL abor1_ftn ("roms_fields_check_subset: '" //                         &
                      "f1' is not a subset of 'f2'")
    END IF

    CALL f2%get (f1%fields(i)%name, fld)

    DO j = 1, SIZE(SHAPE(fld%val))
      IF (SIZE(f1%fields(i)%val, dim=j) .ne. SIZE(fld%val, dim=j) ) THEN
        CALL abor1_ftn ("roms_fields::check_subset: objects f1' and 'f2'" //   &
                        " have different dimensions for '" //                  &
                        f1%fields(i)%name // "'")
      END IF
    END DO
  END DO

END SUBROUTINE roms_fields_check_subset

! ------------------------------------------------------------------------------
!> For a given list of field names, it allocates and initilizes Fields object
!! properties.

SUBROUTINE roms_fields_init_vars (self, vars)

  CLASS (roms_fields),            intent(inout) :: self     !< Fields object
  character (len=:), allocatable, intent(in   ) :: vars(:)  !< variable names

  integer                                       :: LBi, UBi, LBj, UBj, LBk, UBk
  integer                                       :: i

  LBi = self%geom%LBi
  UBi = self%geom%UBi
  LBj = self%geom%LBj
  UBj = self%geom%UBj

  allocate ( self%fields(SIZE(vars)) )

  DO i = 1, SIZE(vars)

    ! Get field information from the metadata 'geom%FieldsInfo' object, which
    ! is read from the YAML configuration file elsewhere. Notice that the user
    ! may specify the variable names as the ROMS-JEDI standard name (default)
    ! or internal short name.
    ! For example, 'sea_surface_height_above_geoid' or 'ssh'.

    self%fields(i)%name = TRIM(vars(i))
    self%fields(i)%metadata = self%geom%FieldsInfo%get(self%fields(i)%name)

    ! Initialize switches used for parallel tile halo exchange. If adjoint
    ! field, we need to turn on switch elsewhere for proper management of
    ! the halo exchange.

    self%fields(i)%IsAdjointField = .FALSE.
    self%fields(i)%UpdatedHalo    = .FALSE.

    ! Initialize Min/Max values.

    self%fields(i)%MinValue = self%fields(i)%spval
    self%fields(i)%MaxValue = self%fields(i)%spval

    ! Set state field metadata and grid information.

    SELECT CASE (self%fields(i)%metadata%gtype)
      CASE ('r','w')
        self%fields(i)%bounds  =  self%geom%bounds(r2dvar)
        self%fields(i)%angle   => self%geom%angler
        self%fields(i)%lon     => self%geom%lonr
        self%fields(i)%lat     => self%geom%latr
        self%fields(i)%mask    => self%geom%rmask
      CASE ('u')
        self%fields(i)%bounds  =  self%geom%bounds(u2dvar)
        self%fields(i)%angle   => self%geom%angleu
        self%fields(i)%lon     => self%geom%lonu
        self%fields(i)%lat     => self%geom%latu
        self%fields(i)%mask    => self%geom%umask
      CASE ('v')
        self%fields(i)%bounds  =  self%geom%bounds(v2dvar)
        self%fields(i)%angle   => self%geom%anglev
        self%fields(i)%lon     => self%geom%lonv
        self%fields(i)%lat     => self%geom%latv
        self%fields(i)%mask    => self%geom%vmask
      CASE DEFAULT
        CALL abor1_ftn ("roms_fields::init_vars: Illegal C-grid type = " //    &
                        self%fields(i)%metadata%gtype //                       &
                        " given for '" // self%fields(i)%name // "'")
    END SELECT

    ! Set number of vertical levels.

    IF (self%fields(i)%name == self%fields(i)%metadata%surface_name) THEN
      LBk = 1
      UBk = 1                                          ! surface field

      SELECT CASE (self%fields(i)%name)
        CASE ('sea_surface_temperature')
          self%fields(i)%metadata%short_name = 'SST'
        CASE ('sea_surface_salinity')
          self%fields(i)%metadata%short_name = 'SSS'
        CASE ('surface_eastward_sea_water_velocity',                           &
              'surface_sea_water_x_velocity')
          self%fields(i)%metadata%short_name = 'Usur'
        CASE ('surface_northward_sea_water_velocity',                          &
              'surface_sea_water_y_velocity')
          self%fields(i)%metadata%short_name = 'Vsur'
      END SELECT

    ELSE
      SELECT CASE (self%fields(i)%metadata%levels)
        CASE ('full_ocn')                              ! 3D field, full r-column
          LBk = 1
          UBk = self%geom%N
        CASE ('wfull_ocn')                             ! 3D field, full column
          LBk = 0
          UBk = self%geom%N
        CASE ('1', 'surface')                               
          LBk = 1                                      ! 3D field, single level
          UBk = 1
        CASE DEFAULT
          CALL abor1_ftn ("roms_fields::init_vars: Illegal levels '" //        &
                          self%fields(i)%metadata%levels //                    &
                          "' given for '" // self%fields(i)%name // "'")
      END SELECT
    END IF

    ! Allocate space.
    
    self%fields(i)%N = UBk-LBk+1
    
    allocate ( self%fields(i)%val(LBi:UBi, LBj:UBj, LBk:UBk) )

    ! Report.

    IF (LdebugFields .and. (my_comm%rank() .eq. 0)) THEN
      PRINT 10, 'ROMS_DEBUG roms_fields::init_vars: created and allocated - ', &
                TRIM(self%fields(i)%metadata%short_name),                      &
                ', SHAPE = ', SHAPE(self%fields(i)%val),                       &
                TRIM(self%fields(i)%metadata%io_name)
 10   FORMAT (2a,t70,a,3(i0,1x),2x,'(',a,')')
    END IF

  END DO

END SUBROUTINE roms_fields_init_vars

! ------------------------------------------------------------------------------
!> It updates the Fields object by adding/removing variables in the requested
!! OOPS list.  It removes fields not in the list and allocates unallocated
!! fields in the list.

SUBROUTINE roms_fields_update_fields (self, vars)

  CLASS (roms_fields),   intent(inout) :: self     !< Fields object
  TYPE (oops_variables), intent(in   ) :: vars     !< variable names

  TYPE (roms_fields)                   :: tmp
  TYPE (roms_field), pointer           :: field

  integer                              :: i, nflds, nvars

  ! Report fields to process.

  IF (LdebugFields .and. (my_comm%rank() .eq. 0)) THEN 
    nflds = SIZE(self%fields)
    nvars = vars%nvars()
    PRINT '(a)', 'ROMS_DEBUG roms_fields::update_fields: Creating TMP Fields:'
    PRINT 10,    '  SELF Vars: ', (self%fields(i)%name, i=1,nflds)
    PRINT 10,    '  OOPS Vars: ', (TRIM(vars%variable(i)), i=1,nvars)
 10 FORMAT (a, *(1x,a,','))
  END IF

  ! Create new fields.

  CALL tmp%create (self%geom, vars)

  ! If field exists, copy from SELF to TMP object.

  DO i = 1, SIZE(tmp%fields)
    IF (self%has(tmp%fields(i)%name)) THEN
      CALL self%get (tmp%fields(i)%name, field)
      CALL tmp%fields(i)%copy (field)
    END IF
  END DO

  ! Transfer allocation from TMP to SELF object. It uses Fortran 2003
  ! intrinsic procedure. Here, "self%fields" are allocated with the same
  ! dynamic type, type parameters, array bounds, and it is given the
  ! same values as "tmp%fields" have before MOVE_ALLOC was invoked. Then,
  ! "tmp%fields" becomes unallocated or undefined.

  IF ( allocated (self%fields) )  deallocate (self%fields)
  CALL MOVE_ALLOC (tmp%fields, self%fields)

END SUBROUTINE roms_fields_update_fields

! ------------------------------------------------------------------------------
!> Update the halo points for all the fields in the list.

SUBROUTINE roms_fields_update_halos (self)

  CLASS (roms_fields), intent(inout) :: self     !< Fields object

  integer                            :: i

  DO i = 1, SIZE(self%fields)
    CALL self%fields(i)%update_halo (self%geom)
  END DO

END SUBROUTINE roms_fields_update_halos

! ------------------------------------------------------------------------------
!> Initialize the fields set with analytical functions if the "state generate"
!! has a false value in "read_from_file" in the YAML configuration file. The
!! keyword "analytic init.method" can either have a value of "ana_ocnfields"
!! or "uniform_ocnfields".

SUBROUTINE roms_fields_analytic (self, f_conf, vdate)

  CLASS (roms_fields), target, intent(inout) :: self    !< Fields object
  TYPE (fckit_configuration),  intent(in   ) :: f_conf  !< configuration
  TYPE (datetime),             intent(inout) :: vdate   !< Date and Time

  TYPE (roms_field), pointer                 :: field
  integer                                    :: LocalPET
  integer                                    :: i, j, k, n
  real (kind=kind_real)                      :: romsDateNumber, romsTime
  real (kind=kind_real), pointer             :: h(:,:), z(:,:,:) 
  real (kind=kind_real)                      :: T0, S0, U0, V0
  character (len=21)                         :: DateString
  character (len=30)                         :: method
  character (len=:), allocatable             :: my_string

  ! Initialize.

  LocalPET = my_comm%rank()   ! PET rank

  ! Get analytical parameters from input configuration YAML file.

  IF (.not.f_conf%has("analytic init")) THEN
    CALL abor1_ftn ("roms_fields::analytic: Cannot find 'analytic init' " //   &
                    "component and its elements")
  END IF

  ! Analytical method: "ana_ocnfields" or "uniform_ocnfields".

  CALL f_conf%get_or_die ("analytic init.method", my_string)
  method = my_string
  deallocate (my_string)

  ! Background temperature (C), salinity, zonal velocity (m/s), and meridional
  ! velocity (m/s).

  CALL f_conf%get_or_die ("analytic init.T0", T0)
  CALL f_conf%get_or_die ("analytic init.S0", S0)
  CALL f_conf%get_or_die ("analytic init.U0", U0)
  CALL f_conf%get_or_die ("analytic init.V0", V0)

  CALL fckit_log%warning ("roms_fields::analytic: inventing analytical " //    &
                          "fields, method: '" // TRIM(method) // "'.")

  ! Set fields date and time.

  CALL f_conf%get_or_die ("date", my_string)
  DateString = my_string
  deallocate (my_string)

  CALL datetime_set (DateString, vdate)    
  CALL roms_date2time (LocalPET, vdate, romsTime, romsDateNumber) 

  ! Analitical formula.

  IF (method .eq. 'ana_ocnfields') THEN

    DO n = 1, SIZE(self%fields)

      field => self%fields(n)

      SELECT CASE (field%metadata%gtype)
        CASE ('r')
          h => self%geom%h_r
          z => self%geom%z_r
        CASE ('u')
          h => self%geom%h_u
          z => self%geom%z_u
        CASE ('v')
          h => self%geom%h_v
          z => self%geom%z_v
        CASE DEFAULT
          CALL abor1_ftn ("roms_fields::analytic: unknown C-grid type: '" //   &
                           field%metadata%gtype // "', field: '" //            &
                           field%name // "'")
      END SELECT      

      DO k = 1, field%N
        DO j = field%bounds%JstrD, field%bounds%JendD
          DO i = field%bounds%IstrD, field%bounds%IendD
            field%val(i,j,k) = ana_fields(field%name,                          &
                                          field%mask(i,j),                     &
                                          field%lon(i,j),                      &
                                          field%lat(i,j),                      &
                                          z(i,j,k),                            &
                                          h(i,j),                              &
                                          T0, S0, U0, V0)
          END DO
        END DO
      END DO

    END DO

  ! Uniform fields.

  ELSE IF (method .eq. 'uniform_ocnfields') THEN

    DO n = 1, SIZE(self%fields)

      field => self%fields(n)

      SELECT CASE (field%name)
        CASE ('tocn', 'ptocn',                                                 &
              'sea_water_temperature',                                         &
              'sea_water_potential_temperature',                               &
              'sst', 'SST',                                                    &
              'sea_surface_temperature',                                       &
              'sea_surface_skin_temperature')
          field%val = T0
        CASE ('socn',                                                          &
              'sea_water_practical_salinity',                                  &
              'sea_water_salinity',                                            &
              'sss', 'SSS',                                                    &
              'sea_surface_salinity')
          field%val = S0
        CASE ('uaocn',                                                         &
              'eastward_sea_water_velocity',                                   &
              'surface_eastward_sea_water_velocity',                           &
              'uocn',                                                          &
              'sea_water_x_velocity',                                          &
              'sea_water_surface_x_velocity')
          field%val = U0
        CASE ('vaocn',                                                         &
              'northward_sea_water_velocity',                                  &
              'surface_northward_sea_water_velocity',                          &
              'vocn',                                                          &
              'sea_water_y_velocity',                                          &
              'sea_water_surface_y_velocity')
          field%val = V0
        CASE ('ssh', 'SSH',                                                    &
              'sea_surface_height_above_geoid',                                &
              'sea_surface_height_above_geopotential_datum')
          field%val = 0.0_kind_real
      END SELECT

    END DO

  ! Otherwise, zero fields.

  ELSE

    CALL self%zeros ()

  END IF

END SUBROUTINE roms_fields_analytic

! ------------------------------------------------------------------------------
!> It allocates and initializes ROMS I/O structure to read/write fields NetCDF
!! file(s).

SUBROUTINE roms_fields_IO_create (self)

  CLASS (roms_fields), intent(inout) :: self        !< Fields object

  integer                            :: i, k

  ! Allocate I/O structure.

  IF (.not.allocated(self%IO)) THEN

    allocate ( self%IO(Ngrids) )

    ! Allocate array variables in the structure.

    DO i = 1, Ngrids
      allocate ( self%IO(i)%Nrec(Nfiles) )
      allocate ( self%IO(i)%time_min(Nfiles) )
      allocate ( self%IO(i)%time_max(Nfiles) )
      allocate ( self%IO(i)%Vid(NV) )
      allocate ( self%IO(1)%Tid(MT) )
#if defined PIO_LIB
      allocate ( self%IO(i)%pioVar(NV) )
      allocate ( self%IO(i)%pioTrc(MT) )
#endif
      allocate ( self%IO(i)%files(Nfiles) )
    END DO

    ! Initialize.

    DO i = 1, Ngrids
      self%IO(i)%IOtype=out_lib                  ! file IO type
      self%IO(i)%Nfiles=Nfiles                   ! number of multi-files
      self%IO(i)%Fcount=1                        ! multi-file counter
      self%IO(i)%load=1                          ! filename load counter
      self%IO(i)%Rindex=0                        ! time index
      self%IO(i)%ncid=-1                         ! closed NetCDF state

      DO k=1,NV
        self%IO(i)%Vid(k)=-1                     ! NetCDF variables IDs
#if defined PIO_LIB
        self%IO(i)%pioVar(k)%vd%varID=-1         ! PIO variables IDs
        self%IO(i)%pioVar(k)%dkind=-1            ! PIO variables data kind
        self%IO(i)%pioVar(i)%gtype=0             ! PIO variables C-grid type
#endif
      END DO

      DO k=1,MT
        self%IO(i)%Tid(k)=-1                     ! NetCDF tracers IDs
#if defined PIO_LIB
        self%IO(i)%pioTrc(k)%vd%varID=-1         ! PIO tracers IDs
        self%IO(i)%pioTrc(k)%dkind=-1            ! PIO tracers data kind
        self%IO(i)%pioTrc(k)%gtype=0             ! PIO tracers C-grid type
#endif
      END DO

      DO k=1,Nfiles
        self%IO(i)%Nrec(k)=0                     ! record counter
        self%IO(i)%time_min(k)=0.0_kind_real     ! starting time
        self%IO(i)%time_max(k)=0.0_kind_real     ! ending time
      END DO

#if defined PIO_LIB
      self%IO(i)%pioFile%fh=-1                   ! closed file PIO handler
#endif
      self%IO(i)%label='ROMS-JEDI State Fields'  ! structure label
    END DO

  END IF

END SUBROUTINE roms_fields_IO_create

! ------------------------------------------------------------------------------
!> Set ROMS I/O metadata structure. It is used to create output NetCDF files.

SUBROUTINE roms_fields_IO_metadata (self, metadata, addVarChange)
  CLASS (roms_fields),                     intent(inout) :: self
  TYPE (roms_field_metadata), allocatable, intent(inout) :: metadata(:)
  logical,                                 intent(in   ) :: addVarChange

  logical                                                :: add_uocn, add_vocn
  integer                                                :: i, ic, ierr, nvars
  character (len=:),                         allocatable :: name

  ! Deallocate metadata to allow different set of variables.

  IF (allocated(metadata)) THEN
    deallocate (metadata)
  END IF    

  ! Check if additional fields from variable changes are requested.

  nvars = SIZE(self%fields)

  IF (addVarChange) THEN
    add_uocn = .not. self%has('sea_water_x_velocity') .and.                    &
                     self%has('eastward_sea_water_velocity')
    IF (add_uocn) nvars = nvars + 1

    add_vocn = .not. self%has('sea_water_y_velocity') .and.                    &
                     self%has('northward_sea_water_velocity')
    IF (add_vocn) nvars = nvars + 1
  END IF

  ! Extract fields I/O metadata.

   allocate ( metadata(nvars) )

   ic = 0
   DO i = 1, SIZE(self%fields)
     ic = ic + 1
     metadata(i) = self%geom%FieldsInfo%get(self%fields(i)%name)
   END DO

   IF (addVarChange) THEN
     IF (add_uocn) THEN
       ic = ic + 1
       ierr = set_string('sea_water_x_velocity', name)
       metadata(ic) = self%geom%FieldsInfo%get(name)
     END IF

     IF (add_vocn) THEN
       ic = ic + 1
       ierr = set_string('sea_water_y_velocity', name)
       metadata(ic) = self%geom%FieldsInfo%get(name)
     END IF
   END IF

END SUBROUTINE roms_fields_IO_metadata

! ------------------------------------------------------------------------------
!> Set all fields to unity.

SUBROUTINE roms_fields_ones (self)

  CLASS (roms_fields), intent(inout) :: self     !< Fields object

  integer                            :: i

  DO i = 1, SIZE(self%fields)
    self%fields(i)%val = 1.0_kind_real
  END DO

END SUBROUTINE roms_fields_ones

! ------------------------------------------------------------------------------
!> Set all fields to zero.

SUBROUTINE roms_fields_zeros (self)

  CLASS (roms_fields), intent(inout) :: self     !< Fields object

  integer                            :: i

  DO i = 1, SIZE(self%fields)
    self%fields(i)%val = 0.0_kind_real
  END DO

END SUBROUTINE roms_fields_zeros

! ------------------------------------------------------------------------------
!> Add two sets of fields together.

SUBROUTINE roms_fields_add (self, rhs)

  CLASS (roms_fields), intent(inout) :: self     !< LHS Fields object
  CLASS (roms_fields), intent(in   ) :: rhs      !< RHS Fields object

  integer                            :: i
  real (kind=kind_real)              :: stats(4)

  ! Make sure fields have the same name, size, and shape.

  CALL self%check_congruent (rhs)

  ! Report variables to process.

  IF (LdebugFields) THEN
    IF (my_comm%rank() .eq. 0)                                                 &
      PRINT '(a)', 'ROMS_DEBUG roms_fields::add'
    DO i = 1, SIZE(self%fields)
      CALL self%fields(i)%stats (stats)
      IF (my_comm%rank() .eq. 0) THEN
        IF (i .eq. 1) PRINT '(2x,a)', 'Input SELF variables:'
        PRINT 10, self%fields(i)%metadata%short_name, stats(1), stats(2),      &
                  INT(stats(4))
      END IF
    END DO
    DO i = 1, SIZE(rhs%fields)
      CALL rhs%fields(i)%stats (stats)
      IF (my_comm%rank() .eq. 0) THEN
        IF (i .eq. 1) PRINT '(2x,a)', 'Input RHS  variables:'
        PRINT 10, rhs%fields(i)%metadata%short_name, stats(1), stats(2),       &
                  INT(stats(4))
      END IF
    END DO
  END IF

  ! Add RHS fields to SELF.

  DO i = 1, SIZE(self%fields)
    self%fields(i)%val = self%fields(i)%val + rhs%fields(i)%val

    IF (LdebugFields) THEN
      CALL self%fields(i)%stats (stats)
      IF (my_comm%rank() .eq. 0) THEN
        IF (i .eq. 1) PRINT '(2x,a)', 'Output SELF = SELF + RHS'
        PRINT 10, self%fields(i)%metadata%short_name, stats(1), stats(2),      &
                  INT(stats(4))
      END IF
    END IF
  END DO

  10  FORMAT (2x,'- ',a,':',t15,'Min = ',1p,e22.15,',  Max = ',1p,e22.15,      &
              ',  CheckSum = ', i0)

END SUBROUTINE roms_fields_add

! ------------------------------------------------------------------------------
!> Subtract two sets of fields.

SUBROUTINE roms_fields_sub (self, rhs)

  CLASS (roms_fields), intent(inout) :: self     !< LHS Fields object
  CLASS (roms_fields), intent(in   ) :: rhs      !< RHS Fields object

  integer                            :: i
  real (kind=kind_real)              :: stats(4)

  ! Make sure fields have the same name, size, and shape.

  CALL self%check_congruent (rhs)

  ! Subtract RHS from SELF.

  IF (LdebugFields .and. (my_comm%rank() .eq. 0)) THEN
    PRINT '(a)', 'ROMS_DEBUG roms_fields::sub:'
  END IF

  DO i = 1, SIZE(self%fields)
    self%fields(i)%val = self%fields(i)%val - rhs%fields(i)%val

    IF (LdebugFields) THEN
      CALL self%fields(i)%stats (stats)
      IF (my_comm%rank() .eq. 0) THEN
        PRINT 10, self%fields(i)%metadata%short_name, stats(1), stats(2),      &
                  INT(stats(4))
 10     FORMAT (2x,'- ',a,':',t15,'Min = ',1p,e22.15,',  Max = ',1p,e22.15,    &
                ',  CheckSum = ', i0)
      END IF
    END IF
  END DO

END SUBROUTINE roms_fields_sub

! ------------------------------------------------------------------------------
!> Multiply a set of fields by a constant.

SUBROUTINE roms_fields_mul (self, c)

  CLASS (roms_fields),   intent(inout) :: self   !< Fields object
  real (kind=kind_real), intent(in   ) :: c      !< multiplication constant

  integer                              :: i
  real (kind=kind_real)                :: stats(4)

  IF (LdebugFields .and. (my_comm%rank() .eq. 0)) THEN
    PRINT '(a,f0.15)', 'ROMS_DEBUG roms_fields::mul, c = ', c
  END IF

  DO i = 1, SIZE(self%fields)
    self%fields(i)%val = c * self%fields(i)%val

    IF (LdebugFields) THEN
      CALL self%fields(i)%stats (stats)
      IF (my_comm%rank() .eq. 0) THEN
        PRINT 10, self%fields(i)%metadata%short_name, stats(1), stats(2),      &
                  INT(stats(4))
 10     FORMAT (2x,'- ',a,':',t15,'Min = ',1p,e22.15,',  Max = ',1p,e22.15,    &
                ',  CheckSum = ', i0)
      END IF
    END IF
  END DO

END SUBROUTINE roms_fields_mul

! ------------------------------------------------------------------------------
!> Compute the global energy norm per unit ares (MJ/m2) for the state vector.

SUBROUTINE roms_fields_enorm (self, Enorm)

  CLASS (roms_fields), target, intent(in ) :: self   !< Fields object
  real (kind=kind_real),       intent(out) :: Enorm  !< squared Fields sum

  integer                                  :: i, j, k, n

  real (kind=kind_real), parameter         :: Scoef = 7.6E-4_kind_real   ! 1/PSS
  real (kind=kind_real), parameter         :: Tcoef = 1.0E-4_kind_real   ! 1/C
  real (kind=kind_real), parameter         :: bvfsqr = 1.6E-3_kind_real  ! 1/s2
  real (kind=kind_real), parameter         :: g = 9.81_kind_real         ! m/s2
  real (kind=kind_real), parameter         :: rho0 = 1025.0_kind_real    ! kg/m3

  real (kind=kind_real)                    :: Hr, Hu, Hv
  real (kind=kind_real)                    :: area_inv, cff, odx, ody, scale
  real (kind=kind_real)                    :: my_norm
  TYPE (roms_field), pointer               :: field

  ! Compute fields RMS.

  my_norm = 0.0_kind_real

  DO n = 1, SIZE(self%fields)

    field => self%fields(n)

    ! Get scale for the energy norm: energy per unit area, J/m2.

    SELECT CASE (field%name)

      CASE ('ssh', 'SSH',                                                      &
            'sea_surface_height_above_geoid',                                  &
            'sea_surface_height_above_geopotential_datum')               ! m

        scale = 0.5_kind_real*g*rho0
        DO j = field%bounds%JstrD, field%bounds%JendD
          DO i = field%bounds%IstrD, field%bounds%IendD
            IF (associated(field%mask)) THEN                    ! masking
              IF (field%mask(i,j) < 1.0_kind_real) CYCLE
            END IF
            DO k = 1, field%N
              my_norm = my_norm + scale*field%val(i,j,k)*field%val(i,j,k)
            END DO
          END DO
        END DO

      CASE ('u2docn',                                                          &
            'barotropic_sea_water_x_velocity')                           ! m/s

        cff = 0.5_kind_real*rho0
        DO j = field%bounds%JstrD, field%bounds%JendD
          DO i = field%bounds%IstrD, field%bounds%IendD
            IF (associated(field%mask)) THEN                    ! masking
              IF (field%mask(i,j) < 1.0_kind_real) CYCLE
            END IF
            scale = cff*self%geom%h_u(i,j)   
            DO k = 1, field%N
              my_norm = my_norm + scale*field%val(i,j,k)*field%val(i,j,k)
            END DO
          END DO
        END DO

      CASE ('v2docn',                                                          &
            'barotropic_sea_water_y_velocity')                           ! m/s

        cff = 0.5_kind_real*rho0
        DO j = field%bounds%JstrD, field%bounds%JendD
          DO i = field%bounds%IstrD, field%bounds%IendD
            IF (associated(field%mask)) THEN                    ! masking
              IF (field%mask(i,j) < 1.0_kind_real) CYCLE
            END IF
            scale = cff*self%geom%h_v(i,j)   
            DO k = 1, field%N
              my_norm = my_norm + scale*field%val(i,j,k)*field%val(i,j,k)
            END DO
          END DO
        END DO

      CASE ('DU_avg1',                                                         &
            'sea_water_time_average_of_barotropic_x_velocity_flux',            &
            'DU_avg2',                                                         &
            'sea_water_correct_barotropic_x_velocity_flux_for_coupling') ! m3/s

        cff = 0.5_kind_real*rho0
        DO j = field%bounds%JstrD, field%bounds%JendD
          DO i = field%bounds%IstrD, field%bounds%IendD
            IF (associated(field%mask)) THEN                    ! masking
              IF (field%mask(i,j) < 1.0_kind_real) CYCLE
            END IF
            ody = 0.5_kind_real*(self%geom%pn(i-1,j)+self%geom%pn(i,j))  ! 1/m
            scale = cff*ody*ody
            DO k = 1, field%N
              my_norm = my_norm + scale*field%val(i,j,k)*field%val(i,j,k)
            END DO
          END DO
        END DO

      CASE ('DV_avg1',                                                         &
            'sea_water_time_average_of_barotropic_y_velocity_flux',            &
            'DV_avg2',                                                         &
            'sea_water_correct_barotropic_y_velocity_flux_for_coupling') ! m3/s

        cff = 0.5_kind_real*rho0
        DO j = field%bounds%JstrD, field%bounds%JendD
          DO i = field%bounds%IstrD, field%bounds%IendD
            IF (associated(field%mask)) THEN                    ! masking
              IF (field%mask(i,j) < 1.0_kind_real) CYCLE
            END IF
            odx = 0.5_kind_real*(self%geom%pm(i,j-1)+self%geom%pm(i,j))  ! 1/m
            scale = cff*odx*odx
            DO k = 1, field%N
              my_norm = my_norm + scale*field%val(i,j,k)*field%val(i,j,k)
            END DO
          END DO
        END DO

      CASE ('uocn',                                                            &
            'sea_water_x_velocity',                                            &
            'sea_water_surface_x_velocity')                              ! m/s

        cff = 0.25_kind_real*rho0
        DO j = field%bounds%JstrD, field%bounds%JendD
          DO i = field%bounds%IstrD, field%bounds%IendD
            IF (associated(field%mask)) THEN                    ! masking
              IF (field%mask(i,j) < 1.0_kind_real) CYCLE
            END IF
            DO k = 1, field%N
              Hu = (self%geom%z_w(i-1,j,k  )+self%geom%z_w(i,j,k  ))-          &
                   (self%geom%z_w(i-1,j,k-1)+self%geom%z_w(i,j,k-1))     ! m
              scale = cff*Hu
              my_norm = my_norm + scale*field%val(i,j,k)*field%val(i,j,k)
            END DO
          END DO
        END DO

      CASE ('vocn',                                                            &
            'sea_water_y_velocity',                                            &
            'sea_water_surface_y_velocity')                              ! m/s

        cff = 0.25_kind_real*rho0
        DO j = field%bounds%JstrD, field%bounds%JendD
          DO i = field%bounds%IstrD, field%bounds%IendD
            IF (associated(field%mask)) THEN                    ! masking
              IF (field%mask(i,j) < 1.0_kind_real) CYCLE
            END IF
            DO k = 1, field%N
              Hv = (self%geom%z_w(i,j-1,k  )+self%geom%z_w(i,j,k  ))-          &
                   (self%geom%z_w(i,j-1,k-1)+self%geom%z_w(i,j,k-1))     ! m
              scale = cff*Hv
              my_norm = my_norm + scale*field%val(i,j,k)*field%val(i,j,k)
            END DO
          END DO
        END DO

      CASE ('uaocn',                                                           &
            'eastward_sea_water_velocity',                                     &
            'surface_eastward_sea_water_velocity',                             &
            'vaocn',                                                           &
            'northward_sea_water_velocity',                                    &
            'surface_northward_sea_water_velocity')                      ! m/s

        DO j = field%bounds%JstrD, field%bounds%JendD
          DO i = field%bounds%IstrD, field%bounds%IendD
            IF (associated(field%mask)) THEN                    ! masking
              IF (field%mask(i,j) < 1.0_kind_real) CYCLE
            END IF
            DO k = 1, field%N
              Hr = self%geom%z_w(i,j,k)-self%geom%z_w(i,j,k-1)
              scale = rho0*Hr
              my_norm = my_norm + scale*field%val(i,j,k)*field%val(i,j,k)
            END DO
          END DO
        END DO

      CASE ('tocn',                                                            &
            'sea_water_potential_temperature',                                 &
            'sst', 'SST',                                                      &
            'sea_surface_temperature')                                   ! C

        cff = 0.5_kind_real*rho0*Tcoef*Tcoef*g*g/bvfsqr
        DO j = field%bounds%JstrD, field%bounds%JendD
          DO i = field%bounds%IstrD, field%bounds%IendD
            IF (associated(field%mask)) THEN                    ! masking
              IF (field%mask(i,j) < 1.0_kind_real) CYCLE
            END IF
            DO k = 1, field%N
              Hr = self%geom%z_w(i,j,k)-self%geom%z_w(i,j,k-1)
              scale = cff*Hr                                             ! m
              my_norm = my_norm + scale*field%val(i,j,k)*field%val(i,j,k)
            END DO
          END DO
        END DO

      CASE ('socn',                                                            &
            'sea_water_practical_salinity',                                    &
            'sss', 'SSS',                                                      &
            'sea_surface_salinity')                                      ! PSS

        cff = 0.5_kind_real*rho0*Scoef*Scoef*g*g/bvfsqr
        DO j = field%bounds%JstrD, field%bounds%JendD
          DO i = field%bounds%IstrD, field%bounds%IendD
            IF (associated(field%mask)) THEN                    ! masking
              IF (field%mask(i,j) < 1.0_kind_real) CYCLE
            END IF
            DO k = 1, field%N
              Hr = self%geom%z_w(i,j,k)-self%geom%z_w(i,j,k-1)           ! m
              scale = cff*Hr
              my_norm = my_norm + scale*field%val(i,j,k)*field%val(i,j,k)
            END DO
          END DO
        END DO

      CASE ('Ksocn',                                                           &
            'vertical_diffusion_coefficient_of_salinity_in_sea_water',         &
            'Ktocn',                                                           &
            'vertical_diffusion_coefficient_of_temperature_in_sea_water',      &
            'Kvocn',                                                           &
            'vertical_viscosity_coefficient_of_sea_water')               ! m2/s

        cff = 0.5_kind_real*rho0                                         ! kg/m3
        DO j = field%bounds%JstrD, field%bounds%JendD
          DO i = field%bounds%IstrD, field%bounds%IendD
            IF (associated(field%mask)) THEN                    ! masking
              IF (field%mask(i,j) < 1.0_kind_real) CYCLE
            END IF
            area_inv = self%geom%pm(i,j)*self%geom%pn(i,j)               ! 1/m2
            DO k = 1, field%N
              Hr = self%geom%z_w(i,j,k)-self%geom%z_w(i,j,k-1)           ! m
              scale = cff*Hr*area_inv
              my_norm = my_norm + scale*field%val(i,j,k)*field%val(i,j,k)
            END DO
          END DO
        END DO

    END SELECT

  END DO

  ! Get global sum.

  CALL self%geom%f_comm%allreduce (my_norm, Enorm, fckit_mpi_sum())

  ! Scale to use MJ/m2 (1 MJ = 10^6 J).

  Enorm = 1.0E-6_kind_real * Enorm

  IF (LdebugFields .and. (my_comm%rank() .eq. 0)) THEN
    PRINT '(a,f0.15)', 'ROMS_DEBUG roms_fields::enorm, Enorm = ', Enorm
  END IF

END SUBROUTINE roms_fields_enorm

! ------------------------------------------------------------------------------
!> Compute the global norm for the nondimensional state vector.

SUBROUTINE roms_fields_norm (self, norm)

  CLASS (roms_fields), target, intent(in ) :: self   !< Fields object
  real (kind=kind_real),       intent(out) :: norm   !< squared Fields sum

  integer                                  :: i, j, k, n

  real (kind=kind_real)                    :: my_norm
  TYPE (roms_field), pointer               :: field

  ! Compute fields RMS.

  my_norm = 0.0_kind_real

  DO n = 1, SIZE(self%fields)

    field => self%fields(n)

    DO j = field%bounds%JstrD, field%bounds%JendD
      DO i = field%bounds%IstrD, field%bounds%IendD

        IF (associated(field%mask)) THEN                    ! masking
          IF (field%mask(i,j) < 1.0_kind_real) CYCLE
        END IF

        DO k = 1, field%N
          my_norm = my_norm + field%val(i,j,k)*field%val(i,j,k)
        END DO

      END DO
    END DO

  END DO

  ! Get global sum.

  CALL self%geom%f_comm%allreduce (my_norm, norm, fckit_mpi_sum())

  IF (LdebugFields .and. (my_comm%rank() .eq. 0)) THEN
    PRINT '(a,f0.15)', 'ROMS_DEBUG roms_fields::norm, norm = ', norm
  END IF

END SUBROUTINE roms_fields_norm

! ------------------------------------------------------------------------------
!> Compute the RMS of all state fields.

SUBROUTINE roms_fields_rms (self, prms)

  CLASS (roms_fields), target, intent(in ) :: self   !< Fields object
  real (kind=kind_real),       intent(out) :: prms   !< Fields root-mean square

  integer                                  :: i, j, k, n
  real (kind=kind_real)                    :: norm, psum
  real (kind=kind_real)                    :: my_norm, my_psum
  TYPE (roms_field), pointer               :: field

  ! Compute fields RMS.

  my_norm = 0.0_kind_real
  my_psum = 0.0_kind_real

  DO n = 1, SIZE(self%fields)

    field => self%fields(n)

    ! Add the given field to the dot product (only using computational points).

    DO j = field%bounds%JstrD, field%bounds%JendD
      DO i = field%bounds%IstrD, field%bounds%IendD

        IF (associated(field%mask)) THEN                    ! masking
          IF (field%mask(i,j) < 1.0_kind_real) CYCLE
        END IF

        DO k = 1, field%N
          my_psum = my_psum + field%val(i,j,k) * field%val(i,j,k)
          my_norm = my_norm + 1.0_kind_real
        END DO
      END DO
    END DO

  END DO

  ! Get global number of elements processed and sum.

  CALL self%geom%f_comm%allreduce (my_norm, norm, fckit_mpi_sum())
  CALL self%geom%f_comm%allreduce (my_psum, psum, fckit_mpi_sum())

  ! Normalize by number of points and take the squared-root.

  prms = SQRT(psum/norm)

  IF (LdebugFields .and. (my_comm%rank() .eq. 0)) THEN
    PRINT '(a,f0.15)', 'ROMS_DEBUG roms_fields::rms, prms = ', prms
  END IF

END SUBROUTINE roms_fields_rms

! ------------------------------------------------------------------------------
!> Add two fields, multiplying the rhs first by a constant.

SUBROUTINE roms_fields_axpy (self, c, rhs)

  CLASS (roms_fields), target, intent(inout) :: self  !< LHS Fields object
  real (kind=kind_real),       intent(in   ) :: c     !< multiplication constant
  CLASS (roms_fields),         intent(in   ) :: rhs   !< RHS Fields object

  integer                                    :: i
  real (kind=kind_real)                      :: stats(4)
  TYPE (roms_field),                 pointer :: f_rhs, f_lhs

  ! Make sure fields are correct shape.

  CALL self%check_subset (rhs)

  IF (LdebugFields .and. (my_comm%rank() .eq. 0)) THEN
    PRINT '(a, f0.15)', 'ROMS_DEBUG roms_fields::axpy: c = ', c
  END IF

  DO i = 1, SIZE(self%fields)
    f_lhs => self%fields(i)
    IF (.not. rhs%has(f_lhs%name)) CYCLE
    CALL rhs%get (f_lhs%name, f_rhs)
    f_lhs%val = f_lhs%val + c * f_rhs%val

    IF (LdebugFields) THEN
      CALL f_lhs%stats (stats)
      IF (my_comm%rank() .eq. 0) THEN
        PRINT 10, f_lhs%metadata%short_name, stats(1), stats(2), INT(stats(4))
 10     FORMAT (2x,'- ',a,':',t15,'Min = ',1p,e22.15,',  Max = ',1p,e22.15,    &
                ',  CheckSum = ', i0)
      END IF
    END IF
  END DO

END SUBROUTINE roms_fields_axpy

! ------------------------------------------------------------------------------
!> Calculate the global dot-product sum of two sets of fields. Ignore land
!! points.

SUBROUTINE roms_fields_dot_prod (fld1, fld2, zprod)

  CLASS (roms_fields), target, intent(in ) :: fld1    !< Fields set 1 object
  CLASS (roms_fields), target, intent(in ) :: fld2    !< Fields set 2 object
  real (kind=kind_real),       intent(out) :: zprod   !< Fields dot-product

  integer                                  :: i, j, k, n
  real (kind=kind_real)                    :: my_zprod
  TYPE (roms_field), pointer               :: field1, field2

  ! Make sure fields have same name, size, and shape.

  CALL fld1%check_congruent (fld2)
  ! Loop over all fields.

  my_zprod = 0.0_kind_real

  DO n = 1, SIZE(fld1%fields)

    field1 => fld1%fields(n)
    field2 => fld2%fields(n)

    ! Add the given field to the dot product (only using computational points).

    DO j = field1%bounds%JstrD, field1%bounds%JendD
      DO i = field1%bounds%IstrD, field1%bounds%IendD

        IF (associated(field1%mask)) THEN
          IF (field1%mask(i,j) < 1.0_kind_real) CYCLE        ! skip land points
        END IF

        DO k = 1, field1%N
          my_zprod = my_zprod + field1%val(i,j,k) * field2%val(i,j,k)
        END DO
      END DO
    END DO

  END DO

  ! Get global dot product.

  CALL fld1%geom%f_comm%allreduce (my_zprod, zprod, fckit_mpi_sum())

  IF (LdebugFields .and. (my_comm%rank() .eq. 0)) THEN
    PRINT '(a,f0.15)', 'ROMS_DEBUG roms_fields::dot_prod zprod = ', zprod
  END IF

END SUBROUTINE roms_fields_dot_prod

! ------------------------------------------------------------------------------
!> Calculate global statistics for each field (min, max, average, CheckSum).

SUBROUTINE roms_fields_gstats (self, nf, Gstats)

  CLASS (roms_fields),   intent(in   ) :: self           !> Fields object
  integer,               intent(in   ) :: nf             !> number of fields
  real (kind=kind_real), intent(inout) :: Gstats(4, nf)  !> Global statistics

  integer                              :: n
  real (kind=kind_real)                :: stats(4)
  TYPE (roms_field),           pointer :: field

  ! Calculate global min, max, mean, and CheckSum for each field.

  DO n = 1, SIZE(self%fields)
    CALL self%get (self%fields(n)%name, field)
    CALL field%stats (stats)
    Gstats(1:4,n) = stats(1:4)
  END DO

END SUBROUTINE roms_fields_gstats

! ------------------------------------------------------------------------------
!> Interpolate from U- and V-points to RHO-points.

SUBROUTINE roms_fields_colocate (self, gtype)

  CLASS (roms_fields), target, intent(inout) :: self    !< Fields object
  character (len=1),           intent(in   ) :: gtype   !< 'r', 'u', or 'v'

  TYPE (roms_field), pointer                 :: field
  TYPE (roms_interp_type)                    :: interp
  real(kind=kind_real), allocatable          :: val(:,:,:)
  integer                                    :: i

  ! Apply interpolation to all fields, when necessary.

  DO i = 1, SIZE(self%fields)

    ! Avoid interpolation if the field is already colocated at 'gtype'.

    IF (self%fields(i)%metadata%gtype == gtype) CYCLE

    field => self%fields(i)

    ! Initialize horizontal interpolation structure, "interp".

    CALL self%fields(i)%interp_initialize (interp, self%geom, gtype)

    ! Make a temporary copy of field.

    IF (allocated(val)) deallocate (val)
    allocate ( val, MOLD=field%val )
    val = field%val

    ! Horizontally interpolate field level-by-level.

    CALL self%fields(i)%stencil_interp (self%geom, interp, BilinearMethod)

    ! Update fields structure.

    self%fields(i)%metadata%gtype = gtype
 
    SELECT CASE (gtype)
      CASE ('r', 'w')
        self%fields(i)%lon => self%geom%lonr
        self%fields(i)%lat => self%geom%latr
      CASE ('u')
        self%fields(i)%lon => self%geom%lonu
        self%fields(i)%lat => self%geom%latu
      CASE ('v')
        self%fields(i)%lon => self%geom%lonv
        self%fields(i)%lat => self%geom%latv
    END SELECT

    ! Dellocate ROMS interpolation structure.

    CALL roms_interp_delete (interp)

  END DO

END SUBROUTINE roms_fields_colocate

! ------------------------------------------------------------------------------
!> Compute the number of elements of in the packed state vector.

SUBROUTINE roms_fields_serial_size (self, geom, vec_size)

  CLASS (roms_fields),   intent(in ) :: self       !< Fields object
  TYPE (roms_geom),      intent(in ) :: geom       !< Geometry
  integer,               intent(out) :: vec_size   !< state vector length

  integer                            :: i

  ! Loop over fields.

  vec_size = 0
  DO i = 1, SIZE(self%fields)
    vec_size = vec_size + SIZE(self%fields(i)%val)
  END DO

END SUBROUTINE roms_fields_serial_size

! ------------------------------------------------------------------------------
!> Pack all fields into state vector.

SUBROUTINE roms_fields_serialize (self, geom, vec_size, vec)

  CLASS (roms_fields),    intent(in ) :: self          !< Fields object
  TYPE (roms_geom),       intent(in ) :: geom          !< Geometry
  integer,                intent(in ) :: vec_size      !< state vector length
  real (kind=kind_real),  intent(out) :: vec(vec_size) !< state vector

  integer                             :: i, ic, np

  ! Loop over fields, levels and horizontal points.

  ic = 1
  DO i = 1, SIZE(self%fields)
    np = SIZE(self%fields(i)%val)
    vec(ic:ic+np-1) = RESHAPE(self%fields(i)%val, (/np/))
    ic = ic + np
  END DO

END SUBROUTINE roms_fields_serialize

! ------------------------------------------------------------------------------
!> Unpack all fields from state vector.

SUBROUTINE roms_fields_deserialize (self, geom, vec_size, vec, ic)

  CLASS (roms_fields),   intent(inout) :: self          !< Fields object
  TYPE (roms_geom),      intent(in   ) :: geom          !< Geometry
  integer,               intent(in   ) :: vec_size      !< state vector length
  real (kind=kind_real), intent(in   ) :: vec(vec_size) !< state vector
  integer,               intent(inout) :: ic            !< unpack vector length

  integer                              :: i, np

  ! Loop over fields, levels and horizontal points.

  DO i = 1, SIZE(self%fields)
    np = SIZE(self%fields(i)%val)
    self%fields(i)%val = RESHAPE(vec(ic+1:ic+1+np), SHAPE(self%fields(i)%val))
    ic = ic + np
  END DO

END SUBROUTINE roms_fields_deserialize

! ------------------------------------------------------------------------------
!> It inquires about information on NetCDF variables, including dimensions,
!! IDs, names, attributes, and data types. All details are stored in ROMS
!! native NetCDF modules.

SUBROUTINE roms_fields_inquire (self, ncname)

  CLASS (roms_fields), target, intent(inout) :: self    !< Fields object
  character (len=*),           intent(in   ) :: ncname  !< NetCDF filename

#if defined PIO_LIB
  TYPE (My_VarDesc)                          :: my_pioVar
#endif
  integer                                    :: i, idfld, model, my_varid, ng
  character (len=256)                        :: text 
  character (len=1024)                       :: Message

  character (len=*), parameter :: MyFile =                                     &
     &  __FILE__//", roms_fields_inquire"

  ! Initialize.

  model    = self%geom%model           !> numerical kernel
  ng       = MAX(1, self%geom%ng)      !> nested grid number

  ! Open NetCDF file and inquire about the variables ID.

  SELECT CASE (self%IO(ng)%IOtype)

    CASE (io_nf90)
      CALL netcdf_open (ng, model, ncname, 1, self%IO(ng)%ncid)
      IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))          &
        CALL abor1_ftn (TRIM(Message))

      CALL netcdf_inq_varid (ng, model, ncname, TRIM(Vname(1,idtime)),         &
                             self%IO(ng)%ncid, my_varid)
      IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))          &
        CALL abor1_ftn (TRIM(Message))
      self%IO(ng)%Vid(idtime) = my_varid

      DO i=1, SIZE(self%fields)
        CALL netcdf_inq_varid (ng, model, ncname,                              &
                               self%fields(i)%metadata%io_name,                &
                               self%IO(ng)%ncid, my_varid)
        IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))        &
          CALL abor1_ftn (TRIM(Message))
        idfld = roms_metadata_index(self%fields(i)%name)
        self%IO(ng)%Vid(idfld) = my_varid
      END DO

#if defined PIO_LIB
    CASE (io_pio)
      CALL pio_netcdf_open (ng, model, ncname, 1, self%IO(ng)%pioFile)
      IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))          &
        CALL abor1_ftn (TRIM(Message))

      CALL pio_netcdf_inq_varid (ng, model, ncname, TRIM(Vname(1,idtime)),     &
                                 self%IO(ng)%pioFile, my_pioVar)
      IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))          &
        CALL abor1_ftn (TRIM(Message))
      self%IO(ng)%pioVar(idtime)%varID = my_pioVar%varID

      DO i=1, SIZE(self%fields)
        CALL pio_netcdf_inq_varid (ng, model, ncname,                          &
                                   self%fields(i)%metadata%io_name,            &
                                   self%IO(ng)%pioFile, my_pioVar)
        IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))        &
          CALL abor1_ftn (TRIM(Message))
        idfld = roms_metadata_index(self%fields(i)%name)
        self%IO(ng)%pioVar(idfld)%varID = my_pioVar%varID
      END DO
#endif

    CASE DEFAULT
      WRITE (text,'(a,i0)')                                                    &
            'roms_fields::inquire: Ilegal input type, io_type = ',             &
            self%IO(ng)%IOtype
      CALL abor1_ftn (TRIM(text))

  END SELECT

END SUBROUTINE roms_fields_inquire

! ------------------------------------------------------------------------------
!> It post-process a field set to create and compute an EXTRA field set
!! from required variable changes to the conrol vector. Then, it writes
!! such variables ot output NetCDF file.
!!
!! For example, it generates C-grid currents from the contol increment
!! A-grid currents.

SUBROUTINE roms_fields_post_process (self, S)

  USE netcdf, ONLY : nf90_noerr
#if defined PIO_LIB
  USE mod_pio_netcdf
#endif

  CLASS (roms_fields),  target, intent(in   ) :: self   !< Fields object
  TYPE (T_IO),                  intent(inout) :: S(:)   !< ROMS I/O struc

  TYPE (roms_fields)                          :: extra
  TYPE (roms_geom),                   pointer :: geom
#if defined PIO_LIB
  TYPE (IO_desc_t),                   pointer :: ioDesc
  TYPE (My_VarDesc)                           :: pioVar
#endif

  TYPE (roms_field),                  pointer :: Ua => null()
  TYPE (roms_field),                  pointer :: Va => null()
  TYPE (roms_field),                  pointer :: Uc => null()
  TYPE (roms_field),                  pointer :: Vc => null()

  logical                                     :: need_uocn, need_vocn
  integer                                     :: LocalPET
  integer                                     :: Cgrid, idfld, varid, vindex
  integer                                     :: i, model, ng, nvars
  integer                                     :: LBi, UBi, LBj, UBj, LBk, UBk
  real (kind=kind_real)                       :: scale
  real (kind=kind_real)                       :: stats(4)
  character (len=:),              allocatable :: vars(:)
  character (len=1024)                        :: Message

  character (len=*),                parameter :: MyFile =                      &
     &  __FILE__//", roms_fields_post_process"

  ! Initialize

  geom => self%geom

  LocalPET   = my_comm%rank()          !< PET rank
  SourceFile = MyFile                  !< current executed ROMS routine
  model      = geom%model              !< ROMS numerical kernel
  ng         = geom%ng                 !< nested grid number
  Message    = " "

  ! Check extra fields needed from variable changes.

  nvars = 0

  need_uocn = .not. self%has('sea_water_x_velocity') .and.                     &
                    self%has('eastward_sea_water_velocity')
  IF (need_uocn) nvars = nvars + 1

  need_vocn = .not. self%has('sea_water_y_velocity') .and.                     &
                    self%has('northward_sea_water_velocity')
  IF (need_vocn) nvars = nvars + 1

  ! Set variables to process.

  allocate ( character(len=1024) :: vars(nvars) )

  IF (need_uocn) vars(1) = 'sea_water_x_velocity'
  IF (need_vocn) vars(2) = 'sea_water_y_velocity'

  ! Create variable changes local field set, EXTRA.

  extra%geom => self%geom
  CALL roms_fields_init_vars (extra, vars)
  CALL roms_fields_zeros (extra)
  CALL roms_fields_IO_create (extra)

  ! Compute needed variable changes.

  IF (need_uocn .and. need_vocn) THEN
    CALL self%get ('eastward_sea_water_velocity',  Ua)
    CALL self%get ('northward_sea_water_velocity', Va)

    CALL extra%get ('sea_water_x_velocity', Uc)
    CALL extra%get ('sea_water_y_velocity', Vc)

    CALL vector_a_to_c (geom, Ua%val, Va%val, Uc%val, Vc%val)
  END IF

  ! Write out all fields. ROMS needs to be compiled with MASKING to use the
  ! writing NetCDF functions below.

  DO i = 1, SIZE(extra%fields)

    IF (extra%fields(i)%io_has_var(extra%geom, vindex)) THEN

      Cgrid = extra%fields(i)%metadata%Cgrid
      idfld = roms_metadata_index(extra%fields(i)%name)
      scale = 1.0_kind_real                              ! field scale

      LBi = LBOUND(extra%fields(i)%val, DIM=1)
      UBi = UBOUND(extra%fields(i)%val, DIM=1)
      LBj = LBOUND(extra%fields(i)%val, DIM=2)
      UBj = UBOUND(extra%fields(i)%val, DIM=2)
      LBk = LBOUND(extra%fields(i)%val, DIM=3)
      UBk = UBOUND(extra%fields(i)%val, DIM=3)

      CALL extra%fields(i)%stats (stats)

      IF (extra%IO(ng)%IOtype .eq. io_nf90) THEN

        varid = var_id(vindex)                           ! NetCDF variable ID

        SELECT CASE (TRIM(extra%fields(i)%name))

          CASE ('uocn',                                                        &
                'sea_water_x_velocity',                                        &
                'vocn',                                                        &
                'sea_water_y_velocity')

            CALL nc_err (nf_fwrite3d(ng, model, S(ng)%ncid, idfld, varid,      &
                                     S(ng)%Rindex, Cgrid,                      &
                                     LBi, UBi, LBj, UBj, LBk, UBk, scale,      &
                                     extra%fields(i)%mask,                     &
                                     extra%fields(i)%val,                      &
                                     MinValue = extra%fields(i)%MinValue,      &
                                     MaxValue = extra%fields(i)%MaxValue),     &
                         nf90_noerr, io_nf90, __LINE__, MyFile)

            IF (LocalPET .eq. 0) THEN
              PRINT 10, extra%fields(i)%metadata%io_name,                      &
                        extra%fields(i)%MinValue, extra%fields(i)%MaxValue,    &
                      S(ng)%Rindex, INT(stats(4), KIND=8)
            END IF

        END SELECT

#if defined PIO_LIB
      ELSE IF (extra%IO(ng)%IOtype .eq. io_pio) THEN

        ! Set variable and IO descriptors.
  
        fld_kind     = PIO_FOUT
        pioVar%vd    = var_desc(vindex)
        pioVar%gtype = Cgrid

        SELECT CASE (Cgrid)
          CASE (r3dvar)
            IF (fld_kind.eq.PIO_double) THEN
              pioVar%dkind=PIO_double
              ioDesc => ioDesc_dp_r3dvar(ng)
            ELSE
              pioVar%dkind=PIO_real
              ioDesc => ioDesc_sp_r3dvar(ng)
            END IF
          CASE (u3dvar)
            IF (fld_kind.eq.PIO_double) THEN
              pioVar%dkind=PIO_double
              ioDesc => ioDesc_dp_u3dvar(ng)
            ELSE
              pioVar%dkind=PIO_real
              ioDesc => ioDesc_sp_u3dvar(ng)
            END IF
          CASE (w3dvar)
            IF (fld_kind.eq.PIO_double) THEN
              pioVar%dkind=PIO_double
              ioDesc => ioDesc_dp_w3dvar(ng)
            ELSE
              pioVar%dkind=PIO_real
              ioDesc => ioDesc_sp_w3dvar(ng)
            END IF
        END SELECT

        ! Write out variable.

        SELECT CASE (TRIM(extra%fields(i)%name))

          CASE ('uocn',                                                        &
                'sea_water_x_velocity',                                        &
                'vocn',                                                        &
                'sea_water_y_velocity')

            CALL nc_err (nf_fwrite3d(ng, model, S(ng)%pioFile, idfld,          &
                                     pioVar, S(ng)%Rindex, ioDesc,             &
                                     LBi, UBi, LBj, UBj, LBk, UBk, scale,      &
                                     extra%fields(i)%mask,                     &
                                     extra%fields(i)%val,                      &
                                     MinValue = extra%fields(i)%MinValue,      &
                                     MaxValue = extra%fields(i)%MaxValue),     &
                         PIO_noerr, io_pio, __LINE__, MyFile)

            IF (LocalPET .eq. 0) THEN
              PRINT 10, extra%fields(i)%metadata%io_name,                      &
                        extra%fields(i)%MinValue, extra%fields(i)%MaxValue,    &
                      S(ng)%Rindex, INT(stats(4), KIND=8)
            END IF
#endif
      END IF

    END IF
  
  END DO

  10 FORMAT (2x,'- ',a,':',t30,'Min = ',1p,e15.8,',  Max = ',1p,e15.8,         &
             ',  Rec = ',i3,',  CheckSum = ',i0)

END SUBROUTINE roms_fields_post_process

! ------------------------------------------------------------------------------
!> Initialize a fields set by reading from an input NetCDF file if "statefile"
!! or "initial condition" has "read_from_file" set to true in the YAML
!! configuraion file.

SUBROUTINE roms_fields_read (self, f_conf, vdate)

  CLASS (roms_fields), target, intent(inout) :: self    !< Fields object
  TYPE (fckit_configuration),  intent(in   ) :: f_conf  !< configuration
  TYPE (datetime),             intent(inout) :: vdate   !< Date and Time

  integer                                   :: InpRec, LocalPET, lstr
  real (kind=kind_real)                     :: romsDateNumber, romsTime
  character (len=:), allocatable            :: fields_dir, fields_filename
  character (len=:), allocatable            :: my_string
  character (len=21)                        :: DateString
  character (len=256)                       :: ncname, text

  ! Initialize.

  LocalPET = my_comm%rank()   ! PET rank

  ! Get fields data directory, filename, and time record to process from
  ! configuration YAML file.

  IF (.not.f_conf%get("fields_dir", fields_dir)) THEN
    CALL abor1_ftn ("roms_fields::read: Cannot find fields directory")
  END IF

  IF (.not.f_conf%get("fields_filename", fields_filename)) THEN
    CALL abor1_ftn ("roms_fields::read: Cannot find fields input filename")
  END IF

  lstr = LEN(fields_dir)
  IF (fields_dir(lstr:lstr) .eq. '/') THEN
    ncname = TRIM(fields_dir)//TRIM(fields_filename)
  ELSE
    ncname = TRIM(fields_dir)//'/'//TRIM(fields_filename)
  END IF

  IF (.not.f_conf%get("fields_record", InpRec)) THEN
    CALL abor1_ftn ("roms_fields::read: Cannot find record to process")
  END IF

  ! Set fields date and time.

  CALL f_conf%get_or_die ("date", my_string)
  DateString = my_string
  deallocate (my_string)

  CALL datetime_set (DateString, vdate)    
  CALL roms_date2time (LocalPET, vdate, romsTime, romsDateNumber) 

  ! Read fields set from input NetCDF file.

  SELECT CASE (inp_lib)

    CASE (io_nf90)
      CALL roms_fields_read_nf90 (self, InpRec, TRIM(ncname),                  &
                                  DateString, romsDateNumber)

#if defined PIO_LIB
    CASE (io_pio)
      CALL roms_fields_read_pio (self, InpRec, TRIM(ncname),                   &
                                 DateString, romsDateNumber)
#endif

    CASE DEFAULT
      WRITE (text,'(a,i0)')                                                    &
            'roms_fields::read: Ilegal input type, io_type = ', inp_lib
      CALL abor1_ftn (TRIM(text))

  END SELECT

END SUBROUTINE roms_fields_read

! ------------------------------------------------------------------------------
!> Writes fields into output file using the standard NetCDF or PIO libraries.

SUBROUTINE roms_fields_write (self, f_conf, vdate)

  CLASS (roms_fields), target, intent(inout) :: self         !< Fields set
  TYPE (fckit_configuration),  intent(in   ) :: f_conf       !< Configuration
  TYPE (datetime),             intent(inout) :: vdate        !< DateTime

  integer, parameter                         :: max_length = 800

  TYPE (datetime)                            :: rdate
  TYPE (duration)                            :: frequency, policy, step

  logical                                    :: addVarChange
  logical                                    :: createFile, singleRecord
  integer                                    :: LocalPET, Nrecs, model, ng
  integer                                    :: frequency_sec, policy_sec
  integer                                    :: step_sec
  integer, save                              :: out_rec
  real (kind=kind_real)                      :: romsTime(Ngrids), romsDateNumber
  character (len=256)                        :: text
  character (len=max_length)                 :: ValidityDate, filename
  character (len=:), allocatable             :: Fpolicy, iniDate, ioFrequency

  character (len=*), parameter               :: MyFile =                       &
     &  __FILE__//", roms_fields_write"

  ! Initialize.

  LocalPET   = my_comm%rank()          !> PET rank
  SourceFile = MyFile                  !> current executed ROMS routine
  romsTime   = 0.0_kind_real           !> ROMS time
  model      = self%geom%model         !> ROMS numerical kernel
  ng         = self%geom%ng            !> nested grid number

  ! Get information from vdate structure.

  CALL datetime_to_string (vdate, ValidityDate)

  ! Inquire configuration YAML file about additional fields from variable
  ! changes, file policy, output data frequency, initial date.

  IF (f_conf%has("add_varchange")) THEN
    IF (.not.f_conf%get("add_varchange", addVarChange)) THEN
      CALL abor1_ftn ("roms_fields::write: Cannot get 'add_varchange'" //      &
                      " from YAML configuration")
    END IF
  ELSE
    addVarChange = .FALSE.
  END IF

  IF (f_conf%has("single_record")) THEN
    IF (.not.f_conf%get("single_record", singleRecord)) THEN
      CALL abor1_ftn ("roms_fields::write: Cannot find 'file_policy'" //       &
                      " in YAML configuration")
    END IF
  ELSE
    singleRecord = .FALSE.
  END IF

  IF (.not.singleRecord) THEN
    IF (.not.f_conf%get("file_policy", Fpolicy)) THEN
      CALL abor1_ftn ("roms_fields::write: Cannot find 'file_policy'" //       &
                      " in YAML configuration")
    END IF
    IF (.not.f_conf%get("data_frequency", ioFrequency)) THEN
      CALL abor1_ftn ("roms_fields::write: Cannot find 'data_frequency'" //    &
                      " in YAML configuration")
    END IF
  END IF

  IF (.not.f_conf%get("date", iniDate)) THEN
    CALL abor1_ftn ("roms_fields::write: Cannot find 'date'" //                &
                    " in YAML configuration")
  END IF

  CALL datetime_create (iniDate, rdate)         ! initial date
  CALL datetime_diff   (vdate, rdate, step)     ! time since initial date

  ! Determine if output NetCDF needs to be created or not.

  IF (singleRecord) THEN
    createFile = .TRUE.
    Nrecs = 1
  ELSE
    policy    = Fpolicy
    frequency = ioFrequency

    step_sec      = duration_seconds(step)
    policy_sec    = duration_seconds(policy)
    frequency_sec = duration_seconds(frequency)

    ! Number of time records in the output file.

    Nrecs = policy_sec/frequency_sec
    IF (policy_sec .eq. frequency_sec) Nrecs = 1

    ! Initialize record counter. This routine is called twice by "State.cc" with
    ! the same "vdate" as the initialization date "iniDate", weird.  The time
    ! record counter is reset to zero in the second call to create files properly
    ! every "policy_sec" intervals.

    IF (step_sec .eq. 0) out_rec = 0

    createFile = (MOD(step_sec, policy_sec).eq.0) .and. (out_rec .eq. 0)
  END IF

  ! Create output NetCDF file according to specified policy: a new file is
  ! created every "policy_sec" intervals.

  IF (createFile) THEN

    ! Generate output NetCDF filename.

    filename = roms_gen_filename(f_conf, max_length, vdate)
    self%IO(ng)%name = TRIM(filename)

    ! Set IO fields metadata.

    CALL self%IO_metadata (metadata, addVarChange)

    ! Create output NetCDF. Initialize I/O structure counters.

    self%IO(ng)%Fcount=1
    self%IO(ng)%load=1
    self%IO(ng)%Rindex=0

    CALL roms_create_ncfile (ng, model, LocalPET, self%IO, metadata)

    IF (LocalPET .eq. 0) THEN
      PRINT '(3a)', "roms_fields::write: created NetCDF file: '",              &
                    TRIM(self%IO(ng)%name), "'"
    END IF

  END IF

  ! Set ROMS time from JEDI date in seconds since reference time and date
  ! number.

  CALL roms_date2time (LocalPET, vdate, romsTime(ng), romsDateNumber)

  ! Write out all fields using either the standard NetCDF library or the
  ! Parallel I/O (PIO) library.

  SELECT CASE (self%IO(ng)%IOtype)

    CASE (io_nf90)
      CALL roms_fields_write_nf90 (self, self%IO, romsTime, addVarChange)

#if defined PIO_LIB
    CASE (io_pio)
      CALL roms_fields_write_pio (self, self%IO, romsTime, addVarChange)
#endif

    CASE DEFAULT
      WRITE (text,'(a,i0)') &
                  'roms_fields::write: Ilegal output type, io_type = ',        &
                  self%IO(ng)%IOtype
      CALL abor1_ftn (TRIM(text))

  END SELECT

  out_rec = out_rec + 1

  ! If last time record, close output NetCDF file.

  IF (out_rec .eq. Nrecs) THEN
    CALL roms_close_ncfile (ng, model, self%IO)
    out_rec = 0    
  END IF

  ! Deallocate.

  IF ( allocated(Fpolicy) )     deallocate (Fpolicy)  
  IF ( allocated(iniDate) )     deallocate (iniDate)  
  IF ( allocated(ioFrequency) ) deallocate (ioFrequency)

END SUBROUTINE roms_fields_write

! ------------------------------------------------------------------------------
!> Writes fields into output file using the standard NetCDF or PIO libraries. It
!  used for debugging, like writing out OOPS generated increment fields.

SUBROUTINE roms_fields_write_debug (self, filename, vdate,                     &
                                    AddZeroFields, Append)

  CLASS (roms_fields), intent(inout) :: self            !< Fields set
  character (len=*),   intent(in   ) :: filename        !< Configuration
  TYPE (datetime),     intent(in   ) :: vdate           !< DateTime
  logical,   optional, intent(in   ) :: AddZeroFields   !< Add
  logical,   optional, intent(in   ) :: Append          !< Append records

  logical                            :: Lcreate, LaddZeroFields
  integer                            :: LocalPET, model, ng
  real (kind=kind_real)              :: romsTime(Ngrids), romsDateNumber
  character (len=256)                :: text

  character (len=*), parameter       :: MyFile =                               &
     &  __FILE__//", roms_fields_write_debug"

  ! Initialize.

  LocalPET   = my_comm%rank()          !> PET rank
  SourceFile = MyFile                  !> current executed ROMS routine
  romsTime   = 0.0_kind_real           !> ROMS time
  model      = self%geom%model         !> ROMS numerical kernel
  ng         = self%geom%ng            !> nested grid number

  ! If appropriate, allocate ROMS IO structure.

  IF (.not.allocated(self%IO)) THEN
    CALL self%IO_create ()
  END IF 
  self%IO(ng)%name = TRIM(filename)

  ! Set switch to write other defined variables not present in the field set
  ! with zero values. Usually, we include other variables needed by ROMS
  ! kernels like: ubar, vbar, DU_avg1, DU_avg2, DV_avg1, DV_avg2, AKt, AKs,
  ! and AKV.

  IF (PRESENT(AddZeroFields)) THEN
    LaddZeroFields=AddZeroFields
  ELSE
    LaddZeroFields=.FALSE.
  END IF

  ! Set switch to create NetCDF file or append to existing NetCDF file.

  IF (PRESENT(Append)) THEN
    Lcreate=.FALSE.
    CALL self%inquire (filename)
  ELSE
    Lcreate=.TRUE.
  END IF

  ! If applicable, create a new output NetCDF file. Otherwise, append to

  IF (Lcreate) THEN

    ! Set IO fields metadata.

    CALL self%IO_metadata (metadata, .FALSE.)

    ! Create output NetCDF. Initialize I/O structure counters.

    self%IO(ng)%Fcount=1
    self%IO(ng)%load=1
    self%IO(ng)%Rindex=0

    CALL roms_create_ncfile (ng, model, LocalPET, self%IO, metadata)

    IF (LocalPET .eq. 0) THEN
      PRINT '(3a)', "roms_fields::write_debug: created NetCDF file: '",        &
                    TRIM(self%IO(ng)%name), "'"
    END IF

  END IF

  ! Set ROMS time from JEDI date in seconds since reference time and date
  ! number.

  CALL roms_date2time (LocalPET, vdate, romsTime(ng), romsDateNumber)

  ! Write out all fields using either the standard NetCDF library or the
  ! Parallel I/O (PIO) library.

  SELECT CASE (self%IO(ng)%IOtype)

    CASE (io_nf90)
      CALL roms_fields_write_nf90 (self, self%IO, romsTime)
      IF (LaddZeroFields) THEN
        CALL roms_fields_write_zero_nf90 (self, self%IO)
      END IF

#if defined PIO_LIB
    CASE (io_pio)
      CALL roms_fields_write_pio (self, self%IO, romsTime)
      IF (LaddZeroFields) THEN
        CALL roms_fields_write_zero_pio (self, self%IO)
      END IF
#endif

    CASE DEFAULT
      WRITE (text,'(a,i0)') &
                  'roms_fields::write_debug: Ilegal output type, io_type = ',  &
                  self%IO(ng)%IOtype
      CALL abor1_ftn (TRIM(text))

  END SELECT

  ! If last time record, close output NetCDF file.

  CALL roms_close_ncfile (ng, model, self%IO)

  RETURN

END SUBROUTINE roms_fields_write_debug

! ------------------------------------------------------------------------------
!> Read fields from input file using standard NetCDF library.

SUBROUTINE roms_fields_read_nf90 (self, InpRec, ncname, DateString, DateNumber)

  USE netcdf, ONLY : nf90_noerr

  CLASS (roms_fields), target, intent(inout) :: self        !< Fields set
  integer,                     intent(in   ) :: InpRec      !< Record to read
  character (len=*),           intent(in   ) :: ncname      !< NetCDF filename
  character (len=*),           intent(in   ) :: DateString  !< ISO8601 DateTime
  real (kind=kind_real),       intent(in   ) :: DateNumber  !< Fields datenum

  TYPE (roms_field), pointer                 :: field
  TYPE (roms_geom), pointer                  :: geom

  integer (kind=SELECTED_INT_KIND(8))        :: Fhash

  integer                                    :: LocalPET, lstr, lend
  integer                                    :: i, model, ng
  integer                                    :: Cgrid, ncid, varid, vindex
  integer                                    :: LBi, UBi, LBj, UBj, LBk, UBk
  integer, dimension(4)                      :: Vsize
  real (kind=kind_real)                      :: scale
  character (len=1024)                       :: Message

  character (len=*), parameter :: MyFile =                                     &
     &  __FILE__//", roms_fields_read_nf90"

  ! Initialize.

  geom => self%geom

  LocalPET   = my_comm%rank()          !> PET rank
  SourceFile = MyFile                  !> current executed ROMS routine
  model      = geom%model              !> numerical kernel
  ng         = MAX(1, geom%ng)         !> nested grid number
  scale      = 1.0_kind_real           !> scale factor for read variables
  Vsize      = 0                       !> variable dimensions

  IF (LocalPET .eq. 0) THEN
    lstr = SCAN(ncname, '/', BACK=.TRUE.) + 1
    lend = LEN_TRIM(ncname)    
    WRITE (stdout,10) 'State Fields,', TRIM(DateString), ng, DateNumber,       &
                      ncname(lstr:lend), InpRec
  END IF

  ! Open fields NetCDF file for reading.

  CALL netcdf_open (ng, model, ncname, 0, ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  ! Inquire about all variables.

  CALL netcdf_inq_var (ng, model, ncname,                                      &
                       ncid = ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  ! Read in all fields. ROMS needs to be compiled with MASKING to use the
  ! NetCDF reading functions below.

  DO i = 1, SIZE(self%fields)

    field => self%fields(i)

    IF (field%io_has_var(geom, vindex)) THEN

      Cgrid = field%metadata%Cgrid

      LBi = LBOUND(field%val, DIM=1)
      UBi = UBOUND(field%val, DIM=1)
      LBj = LBOUND(field%val, DIM=2)
      UBj = UBOUND(field%val, DIM=2)
      LBk = LBOUND(field%val, DIM=3)
      UBk = UBOUND(field%val, DIM=3)

      lstr = LEN_TRIM(ncname)
      IF (allocated(field%InpNCname)) THEN
        deallocate ( field%InpNCname )
      END IF
      allocate (character(LEN=lstr) :: field%InpNCname )
      field%InpNCname = TRIM(ncname)

      lstr = MAX(21, LEN_TRIM(DateString))
      IF (allocated(field%DateTimeString)) THEN
        deallocate ( field%DateTimeString )
      END IF
      allocate (character(LEN=lstr) :: field%DateTimeString )
      field%DateTimeString = TRIM(DateString)

      field%InpRec     = InpRec
      field%InpNCid    = ncid
      field%DateNumber = DateNumber

      varid = var_id(vindex)                             ! NetCDF variable ID

      SELECT CASE (field%name)
                                                         ! 2D variables
        CASE ('ssh',                                                           &
              'sea_surface_height_above_geoid',                                &
              'u2docn',                                                        &
              'barotropic_sea_water_x_velocity',                               &
              'v2docn',                                                        &
              'barotropic_sea_water_y_velocity',                               &
              'DU_avg1',                                                       &
              'sea_water_time_average_of_barotropic_x_velocity_flux',          &
              'DV_avg1',                                                       &
              'sea_water_time_average_of_barotropic_y_velocity_flux',          &
              'DU_avg2',                                                       &
              'sea_water_correct_barotropic_x_velocity_flux_for_coupling',     &
              'DV_avg2',                                                       &
              'sea_water_correct_barotropic_y_velocity_flux_for_coupling')

          CALL nc_err (nf_fread2d(ng, model, ncname, ncid,                     &
                                  field%metadata%io_name,                      &
                                  varid, InpRec, Cgrid, Vsize,                 &
                                  LBi, UBi, LBj, UBj,                          &
                                  scale, field%MinValue, field%MaxValue,       &
                                  field%mask,                                  &
                                  field%val(:,:,1),                            &
                                  checksum = Fhash),                           &
                       nf90_noerr, io_nf90, __LINE__, MyFile)

          IF (LocalPET .eq. 0) THEN
            WRITE (stdout,20) field%metadata%io_name,                          &
                              field%MinValue, field%MaxValue, Fhash
          END IF

                                                         ! 3D variables
        CASE ('uocn',                                                          &
              'sea_water_x_velocity',                                          &
              'vocn',                                                          &
              'sea_water_y_velocity',                                          &
              'uaocn',                                                         &
              'eastward_sea_water_velocity',                                   &
              'vaocn',                                                         &
              'northward_sea_water_velocity',                                  &
              'tocn',                                                          &
              'sea_water_temperature',                                         &
              'sea_water_potential_temperature',                               &
              'socn',                                                          &
              'sea_water_salinity',                                            &
              'Kvocn',                                                         &
              'vertical_viscosity_coefficient_of_sea_water',                   &
              'Ktocn',                                                         &
              'vertical_diffusion_coefficient_of_temperature_in_sea_water',    &
              'Ksocn',                                                         &
              'vertical_diffusion_coefficient_of_salinity_in_sea_water')

          CALL nc_err (nf_fread3d(ng, model, ncname, ncid,                     &
                                  self%fields(i)%metadata%io_name,             &
                                  varid, InpRec, Cgrid, Vsize,                 &
                                  LBi, UBi, LBj, UBj, LBk, UBk,                &
                                  scale, field%MinValue, field%MaxValue,       &
                                  field%mask,                                  &
                                  field%val,                                   &
                                  checksum = Fhash),                           &
                       nf90_noerr, io_nf90, __LINE__, MyFile)

          IF (LocalPET .eq. 0) THEN
            WRITE (stdout,20) field%metadata%io_name,                          &
                              field%MinValue, field%MaxValue, Fhash
          END IF

      END SELECT

      IF (.FALSE. .and. (LocalPET .eq. 0)) THEN
        PRINT '(a)',           '------------------'
        PRINT '(2(a,i0))',     'ng     = ', ng, ', tile = ' , LocalPET
        PRINT '(2(a,i0),a,a)', 'ncid   = ', ncid, ', varid  = ', varid,        &
                               ', ncname = ', TRIM(ncname)
        PRINT '(6a)',          'field  = ', field%metadata%io_name,            &
                               ' :: ', field%metadata%short_name,              &
                               ' :: ', field%metadata%name
        PRINT '(a,3(i0,1x))',  'shape  = ', SHAPE(field%val)
        PRINT '(a,6(i0,1x))',  'bounds = ', LBi, UBi, LBj, UBj, LBk, UBk
      END IF

      ! Parallel exchange of halo points.

      CALL self%fields(i)%update_halo (geom)

    ELSE

      ! An error is issued if required state vector variables are not found.
      ! Secondary trajectory variables used to linearize the TLM and ADM
      ! kernels will be processed elsewhere.

      SELECT CASE (field%name)

        CASE ('ssh',                                                           &
              'sea_surface_height_above_geoid',                                &
              'uocn',                                                          &
              'sea_water_x_velocity',                                          &
              'vocn',                                                          &  
              'sea_water_y_velocity',                                          &
              'uaocn',                                                         &
              'eastward_sea_water_velocity',                                   &
              'vaocn',                                                         &
              'northward_sea_water_velocity',                                  &
              'tocn',                                                          &
              'sea_water_temperature',                                         &
              'sea_water_potential_temperature',                               &
              'socn',                                                          &
              'sea_water_salinity')

          WRITE (Message,'(6a)')                                               &
                'roms_fields::read_nf90: Unable to find state variable: ',     &
                field%name, " - ", field%metadata%io_name,                     &
                ', file: ', TRIM(ncname)
          CALL abor1_ftn (TRIM(Message))

        CASE ('Kvocn',                                                         &
              'vertical_viscosity_coefficient_of_sea_water',                   &
              'Ktocn',                                                         &
              'vertical_diffusion_coefficient_of_temperature_in_sea_water',    &
              'Ksocn',                                                         &
              'vertical_diffusion_coefficient_of_salinity_in_sea_water')

          field%val = 1.0E-5_kind_real
   
        CASE ('Hzocn',                                                         &
              'model_level_thickness_at_cell_center')

          field%val = self%geom%Hz

        CASE ('z0ocn_r',                                                       &
              'unvarying_model_level_depth_at_cell_center')

          field%val = self%geom%z0_r

        CASE ('zocn_r',                                                        &
              'model_level_depth_at_cell_center')

          field%val = self%geom%z_r

        CASE ('z0ocn_w',                                                       &
              'unvarying_model_level_depth_at_cell_top_face')

          field%val = self%geom%z0_w

        CASE ('zocn_w',                                                        &
              'model_level_depth_at_cell_top_face')

          field%val = self%geom%z_w

        CASE DEFAULT

          field%val = 0.0_kind_real

      END SELECT

    END IF

  END DO

  ! Close NetCDF file.

  CALL netcdf_close (ng, model, ncid, ncname, .FALSE.)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  10 FORMAT (/,1x,'ROMS_FIELDS::read_nf90 - ',a,t75,a,/,26x,                   &
             '(Grid=',i2.2,', datenum=',f0.4,', File: ',a,', Rec= ',i0,')')
  20 FORMAT (24x,'- ',a,/,27x,'(Min = ',1p,e15.8,' Max = ',1p,e15.8,           &
             ' CheckSum = ',i0,')')

END SUBROUTINE roms_fields_read_nf90

! ------------------------------------------------------------------------------
!> Writes fields into output file using standard NetCDF library.

SUBROUTINE roms_fields_write_nf90 (self, S, romsTime, addVarChange)

  USE netcdf, ONLY : nf90_noerr

  CLASS (roms_fields), target, intent(inout) :: self         !< Fields set
  TYPE (T_IO),                 intent(inout) :: S(:)         !< ROMS I/O struc
  real (kind=kind_real)                      :: romsTime(:)  !< ROMS time (s)
  logical,           optional, intent(in   ) :: addVarChange !< write VarChanges

  TYPE (roms_field),                 pointer :: field
  TYPE (roms_geom),                  pointer :: geom

  integer                                    :: Fcount, LocalPET, lstr, lend
  integer                                    :: Cgrid, idfld, varid, vindex
  integer                                    :: i, model, ng
  integer                                    :: LBi, UBi, LBj, UBj, LBk, UBk
  real (kind=kind_real)                      :: DateNumber, scale
  real (kind=kind_real)                      :: stats(4)
  character (len=22)                         :: DateString
  character (len=1024)                       :: Message

  character (len=*), parameter               :: MyFile =                       &
     &  __FILE__//", roms_fields_write_nf90"

  ! Initialize

  geom => self%geom

  LocalPET   = my_comm%rank()          !< PET rank
  SourceFile = MyFile                  !< current executed ROMS routine
  model      = geom%model              !< ROMS numerical kernel
  ng         = geom%ng                 !< nested grid number
  Message    = " "

  ! Get output fields fractional "datenum".

  DateNumber = Rclock%DateNumber(1) + romsTime(ng)/86400.0_kind_real
  CALL datestr (DateNumber, .TRUE., DateString)

  IF (LocalPET .eq. 0) THEN
    lstr = SCAN(S(ng)%name, '/', BACK=.TRUE.) + 1
    lend = LEN_TRIM(S(ng)%name)    
    PRINT '(4a)', 'ROMS_DEBUG roms_fields::write_nf90 - writing state'//      &
                  ', File = ', S(ng)%name(lstr:lend),                         &
                  ', date = ', TRIM(DateString)                  
  END IF

  ! Set writing parameters.

  scale = 1.0_kind_real                     !< field scale
  S(ng)%Rindex = S(ng)%Rindex + 1           !< NetCDF time record
  Fcount=S(ng)%load                         !< filename load counter
  S(ng)%Nrec(Fcount)=S(ng)%Nrec(Fcount)+1   !< record counter per multi-file

  ! Write out ROMS time variable.

  CALL netcdf_put_fvar (ng, model, S(ng)%name, TRIM(Vname(1,idtime)),          &
                        romsTime(ng:), (/S(ng)%Rindex/), (/1/),                &
                        ncid = S(ng)%ncid,                                     &
                        varid = S(ng)%Vid(idtime))
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  ! Inquire about all variables.

  CALL netcdf_inq_var (ng, model, S(ng)%name,                                  &
                       ncid = S(ng)%ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  ! Write out all fields. ROMS needs to be compiled with MASKING to use the
  ! writing NetCDF functions below.

  DO i = 1, SIZE(self%fields)

    field => self%fields(i)

    IF (field%io_has_var(geom, vindex)) THEN

      Cgrid = field%metadata%Cgrid
      idfld = roms_metadata_index(field%name)

      LBi = LBOUND(field%val, DIM=1)
      UBi = UBOUND(field%val, DIM=1)
      LBj = LBOUND(field%val, DIM=2)
      UBj = UBOUND(field%val, DIM=2)
      LBk = LBOUND(field%val, DIM=3)
      UBk = UBOUND(field%val, DIM=3)

      field%OutNCname = TRIM(S(ng)%name)
      field%OutNCid   = S(ng)%ncid
      field%OutRec    = S(ng)%Rindex

      CALL field%stats (stats)

      lstr = MAX(22, LEN_TRIM(DateString))
      IF (allocated(field%DateTimeString)) THEN
        deallocate ( field%DateTimeString )
      END IF
      allocate (character(LEN=lstr) :: field%DateTimeString )
      field%DateTimeString = TRIM(DateString)

      field%DateNumber = DateNumber

      varid = var_id(vindex)                             ! NetCDF variable ID

      SELECT CASE (TRIM(field%name))
                                                         ! 2D variables
        CASE ('ssh',                                                           &
              'sea_surface_height_above_geoid',                                &
              'u2docn',                                                        &
              'barotropic_sea_water_x_velocity',                               &
              'v2docn',                                                        &
              'barotropic_sea_water_y_velocity',                               &
              'DU_avg1',                                                       &
              'sea_water_time_average_of_barotropic_x_velocity_flux',          &
              'DV_avg1',                                                       &
              'sea_water_time_average_of_barotropic_y_velocity_flux',          &
              'DU_avg2',                                                       &
              'sea_water_correct_barotropic_x_velocity_flux_for_coupling',     &
              'DV_avg2',                                                       &
              'sea_water_correct_barotropic_y_velocity_flux_for_coupling')

          CALL nc_err (nf_fwrite2d(ng, model, S(ng)%ncid, idfld, varid,        &
                                   S(ng)%Rindex, Cgrid,                        &
                                   LBi, UBi, LBj, UBj, scale,                  &
                                   field%mask,                                 &
                                   field%val(:,:,1),                           &
                                   MinValue = field%MinValue,                  &
                                   MaxValue = field%MaxValue),                 &
                       nf90_noerr, io_nf90, __LINE__, MyFile)

          IF (LocalPET .eq. 0) THEN
            PRINT 10, field%metadata%io_name, field%MinValue, field%MaxValue,  &
                      S(ng)%Rindex, INT(stats(4), KIND=8)
          END IF

                                                         ! 3D variables
        CASE ('uocn',                                                          &
              'sea_water_x_velocity',                                          &
              'vocn',                                                          &
              'sea_water_y_velocity',                                          &
              'uaocn',                                                         &
              'eastward_sea_water_velocity',                                   &
              'vaocn',                                                         &
              'northward_sea_water_velocity',                                  &
              'tocn',                                                          &
              'sea_water_temperature',                                         &
              'sea_water_potential_temperature',                               &
              'socn',                                                          &
              'sea_water_salinity',                                            &
              'Hzocn',                                                         &
              'model_level_thickness_at_cell_center',                          &
              'Kvocn',                                                         &
              'vertical_viscosity_coefficient_of_sea_water',                   &
              'Ktocn',                                                         &
              'vertical_diffusion_coefficient_of_temperature_in_sea_water',    &
              'Ksocn',                                                         &
              'vertical_diffusion_coefficient_of_salinity_in_sea_water')

          CALL nc_err (nf_fwrite3d(ng, model, S(ng)%ncid, idfld, varid,        &
                                   S(ng)%Rindex, Cgrid,                        &
                                   LBi, UBi, LBj, UBj, LBk, UBk, scale,        &
                                   field%mask,                                 &
                                   field%val,                                  &
                                   MinValue = field%MinValue,                  &
                                   MaxValue = field%MaxValue),                 &
                       nf90_noerr, io_nf90, __LINE__, MyFile)

          IF (LocalPET .eq. 0) THEN
            PRINT 10, field%metadata%io_name, field%MinValue, field%MaxValue,  &
                      S(ng)%Rindex, INT(stats(4), KIND=8)
          END IF

      END SELECT

    ELSE

      SELECT CASE (field%name)

        CASE ('zocn_r',                                                        &
              'model_level_depth_at_cell_center',                              &
              'z0ocn_r',                                                       &
              'unvarying_model_level_depth_at_cell_center',                    &
              'zocn_w',                                                        &
              'model_level_depth_at_cell_top_face',                            &
              'z0ocn_w',                                                       &
              'unvarying_model_level_depth_at_cell_top_face')

        ! Ignore time-dependent metric variables.

        CASE DEFAULT

          WRITE (Message,'(6a)')                                               &
                'roms_fields::write_nf90: Cannot find an option to write = ',  &
                TRIM(field%name), ' - ', TRIM(field%metadata%io_name),         &
                ', file: ', TRIM(S(ng)%name)
          CALL abor1_ftn (TRIM(Message))

      END SELECT

    END IF

  END DO

  ! If requested, write extra field from variable changes.

  IF (PRESENT(addVarChange)) THEN
    IF (addVarChange) THEN
      CALL roms_fields_post_process (self, S)
    END IF
  END IF

  ! Synchronize NetCDF to disk.

  CALL netcdf_sync (ng, model, S(ng)%name, S(ng)%ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  10 FORMAT (2x,'- ',a,':',t30,'Min = ',1p,e15.8,',  Max = ',1p,e15.8,         &
             ',  Rec = ',i3,',  CheckSum = ',i0)

END SUBROUTINE roms_fields_write_nf90

! ------------------------------------------------------------------------------
!> Writes zero fields into output file using standard NetCDF library.

SUBROUTINE roms_fields_write_zero_nf90 (self, S)

  USE mod_netcdf,  ONLY : n_var, var_id, var_ndim, var_name
  USE netcdf,      ONLY : nf90_noerr

  CLASS (roms_fields), target, intent(inout) :: self          !< Fields set
  TYPE (T_IO),                 intent(inout) :: S(:)          !< ROMS I/O struc

  TYPE (roms_geom), pointer                  :: geom
  integer                                    :: LocalPET, i, model, ng
  integer                                    :: LBi, UBi, LBj, UBj, LBk, UBk
  integer                                    :: idfld, varid
  real (kind=kind_real)                      :: Fmin, Fmax, scale
  real (kind=kind_real), allocatable         :: F2dat(:,:), F3dat(:,:,:)
  character (len=1024)                       :: Message

  character (len=*), parameter               :: MyFile =                       &
     &  __FILE__//", roms_fields_write_zero_nf90"

  ! Initialize

  geom => self%geom

  LocalPET   = my_comm%rank()          !< PET rank
  SourceFile = MyFile                  !< current executed ROMS routine
  model      = geom%model              !< ROMS numerical kernel
  ng         = geom%ng                 !< nested grid number

  LBi = geom%LBi
  UBi = geom%UBi
  LBj = geom%LBj
  UBj = geom%UBj
  UBk = geom%N

  ! Set writing parameters.

  scale = 1.0_kind_real                !< field scale

  ! Inquire about all variables.

  CALL netcdf_inq_var (ng, model, S(ng)%name,                                  &
                       ncid = S(ng)%ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  ! Write out zero fields.

  DO i = 1, n_var
    IF (var_ndim(i).ge.3) THEN
      IF (.not.self%has(TRIM(var_name(i)))) THEN

        SELECT CASE (TRIM(var_name(i)))        

          CASE ('ubar', 'u2docn',                                              &
                'barotropic_sea_water_x_velocity',                             &
                'DU_avg1',                                                     &
                'sea_water_time_average_of_barotropic_x_velocity_flux',        &
                'DU_avg2',                                                     &
                'sea_water_correct_barotropic_x_velocity_flux_for_coupling')

            IF (.not.allocated(F2dat)) THEN
              allocate ( F2dat(LBi:UBi, LBj:UBj) )
              F2dat = 0.0_kind_real
            END IF

            idfld = roms_metadata_index(TRIM(var_name(i)))
            varid = var_id(i)

            CALL nc_err (nf_fwrite2d(ng, model, S(ng)%ncid, idfld, varid,      &
                                     S(ng)%Rindex, u2dvar,                     &
                                     LBi, UBi, LBj, UBj, scale,                &
                                     geom%umask,                               &
                                     F2dat,                                    &
                                     MinValue = Fmin,                          &
                                     MaxValue = Fmax),                         &
                         nf90_noerr, io_nf90, __LINE__, MyFile)

            IF (LocalPET .eq. 0) THEN
              PRINT 10, TRIM(var_name(i)), Fmin, Fmax, S(ng)%Rindex, 0
            END IF
            deallocate ( F2dat )

          CASE ('vbar', 'v2docn',                                              &
                'barotropic_sea_water_y_velocity',                             &
                'DV_avg1',                                                     &
                'sea_water_time_average_of_barotropic_y_velocity_flux',        &
                'DV_avg2',                                                     &
                'sea_water_correct_barotropic_y_velocity_flux_for_coupling')

            IF (.not.allocated(F2dat)) THEN
              allocate ( F2dat(LBi:UBi, LBj:UBj) )
              F2dat = 0.0_kind_real
            END IF

            idfld = roms_metadata_index(TRIM(var_name(i)))
            varid = var_id(i)

            CALL nc_err (nf_fwrite2d(ng, model, S(ng)%ncid, idfld, varid,      &
                                     S(ng)%Rindex, v2dvar,                     &
                                     LBi, UBi, LBj, UBj, scale,                &
                                     geom%umask,                               &
                                     F2dat,                                    &
                                     MinValue = Fmin,                          &
                                     MaxValue = Fmax),                         &
                         nf90_noerr, io_nf90, __LINE__, MyFile)

            IF (LocalPET .eq. 0) THEN
              PRINT 10, TRIM(var_name(i)), Fmin, Fmax, S(ng)%Rindex, 0
            END IF
            deallocate ( F2dat )

          CASE ('AKv', 'Kvocn',                                                &
                'vertical_viscosity_coefficient_of_sea_water',                 &
                'AKt', 'Ktocn',                                                &
                'vertical_diffusion_coefficient_of_temperature_in_sea_water',  &
                'AKs', 'Ksocn',                                                &
                'vertical_diffusion_coefficient_of_salinity_in_sea_water')

            LBk=0
            IF (.not.allocated(F3dat)) THEN
              allocate ( F3dat(LBi:UBi, LBj:UBj, LBk:UBk) )
              F3dat = 0.0_kind_real
            END IF

            idfld = roms_metadata_index(TRIM(var_name(i)))
            varid = var_id(i)

            CALL nc_err (nf_fwrite3d(ng, model, S(ng)%ncid, idfld, varid,      &
                                     S(ng)%Rindex, w3dvar,                     &
                                     LBi, UBi, LBj, UBj, LBk, UBk, scale,      &
                                     geom%rmask,                               &
                                     F3dat,                                    &
                                     MinValue = Fmin,                          &
                                     MaxValue = Fmax),                         &
                         nf90_noerr, io_nf90, __LINE__, MyFile)

            IF (LocalPET .eq. 0) THEN
              PRINT 10, TRIM(var_name(i)), Fmin, Fmax, S(ng)%Rindex, 0
            END IF
            deallocate ( F3dat )

        END SELECT
      END IF
    END IF
  END DO

  ! Synchronize NetCDF to disk.

  CALL netcdf_sync (ng, model, S(ng)%name, S(ng)%ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  10 FORMAT (2x,'- ',a,':',t30,'Min = ',1p,e15.8,',  Max = ',1p,e15.8,         &
             ',  Rec = ',i3,',  CheckSum = ',i0)

END SUBROUTINE roms_fields_write_zero_nf90

#if defined PIO_LIB

! ------------------------------------------------------------------------------
!> Read fields from input file using the Parallel I/O (PIO) library.

SUBROUTINE roms_fields_read_pio (self, InpRec, ncname, DateString, DateNumber)

  USE mod_pio_netcdf

  CLASS (roms_fields), target, intent(inout) :: self       !< Fields set
  integer,                     intent(in   ) :: InpRec     !< Record to read
  character (len=*),           intent(in   ) :: ncname     !< NetCDF filename
  character (len=*),           intent(in   ) :: DateString !< ISO8601 DateTime
  real (kind=kind_real)        intent(in   ) :: DateNumber !< Fields datenum


  TYPE (roms_field), pointer                 :: field
  TYPE (roms_geom), pointer                  :: geom
  TYPE (IO_desc_t), pointer                  :: ioDesc
  TYPE (My_VarDesc)                          :: pioVar

  integer (kind=SELECTED_INT_KIND(8))        :: Fhash

  integer                                    :: LocalPET, i, lstr, lend, ng
  integer                                    :: Cgrid, fld_kind, model, vindex
  integer                                    :: LBi, UBi, LBj, UBj, LBk, UBk
  integer, dimension(4)                      :: Vsize
  real (kind=kind_real)                      :: scale
  character (len=1024)                       :: Message

  character (len=*), parameter               :: MyFile =                       &
     &  __FILE__//", roms_fields_read_pio"

  ! Initialize.

  geom => self%geom

  LocalPET   = my_comm%rank()          !< PET rank
  SourceFile = MyFile                  !< current executed ROMS routine
  model      = geom%model              !< numerical kernel
  ng         = MAX(1, geom%ng)         !< nested grid number
  scale      = 1.0_kind_real           !< scale factor for read variables
  Vsize      = 0                       !< variable dimensions

  IF (LocalPET .eq. 0) THEN
    lstr = SCAN(ncname, '/', BACK=.TRUE.) + 1
    lend = LEN_TRIM(ncname)    
    WRITE (stdout,10) 'State Fields,', TRIM(DateString), ng, DateNumber,       &
                      ncname(lstr:lend), InpRec
  END IF

  ! Open fields NetCDF file for reading.

  CALL pio_netcdf_open (ng, model, ncname, 0, pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  ! Inquire about all variables.

  CALL pio_netcdf_inq_var (ng, model, ncname,                                  &
                           piofile = pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  ! Read in all fields. ROMS needs to be compiled with MASKING to use the
  ! NetCDF reading functions below.

  DO i = 1, SIZE(self%fields)

    field => self%fields(i)

    IF (field%io_has_var(geom, vindex)) THEN

      Cgrid = field%metadata%Cgrid

      LBi = LBOUND(field%val, DIM=1)
      UBi = UBOUND(field%val, DIM=1)
      LBj = LBOUND(field%val, DIM=2)
      UBj = UBOUND(field%val, DIM=2)
      LBk = LBOUND(field%val, DIM=3)
      UBk = UBOUND(field%val, DIM=3)

      lstr = LEN_TRIM(ncname)
      IF (allocated(field%InpNCname)) THEN
        deallocate ( field%InpNCname )
      END IF
      allocate (character(LEN=lstr) :: field%InpNCname )
      field%InpNCname = TRIM(ncname)

      lstr = LEN_TRIM(DateString)
      IF (allocated(field%DateTimeString)) THEN
        deallocate ( field%DateTimeString )
      END IF
      allocate (character(LEN=lstr) :: field%DateTimeString )
      field%DateTimeString = TRIM(DateString)

      field%InpRec     = InpRec
      field%InpNCid    = pioFile%fh
      field%DateNumber = DateNumber

      ! Set variable and IO descriptors.

      fld_kind = KIND(field%val)

      pioVar%vd    = var_desc(vindex)
      pioVar%gtype = Cgrid

      SELECT CASE (Cgrid)
        CASE (r2dvar)
          IF (fld_kind.eq.8) THEN
            pioVar%dkind=PIO_double
            ioDesc => ioDesc_dp_r2dvar(ng)
          ELSE
            pioVar%dkind=PIO_real
            ioDesc => ioDesc_sp_r2dvar(ng)
          END IF
        CASE (u2dvar)
          IF (fld_kind.eq.8) THEN
            pioVar%dkind=PIO_double
            ioDesc => ioDesc_dp_u2dvar(ng)
          ELSE
            pioVar%dkind=PIO_real
            ioDesc => ioDesc_sp_u2dvar(ng)
          END IF
        CASE (v2dvar)
          IF (fld_kind.eq.8) THEN
            pioVar%dkind=PIO_double
            ioDesc => ioDesc_dp_v2dvar(ng)
          ELSE
            pioVar%dkind=PIO_real
            ioDesc => ioDesc_sp_v2dvar(ng)
          END IF
        CASE (r3dvar)
          IF (fld_kind.eq.8) THEN
            pioVar%dkind=PIO_double
            ioDesc => ioDesc_dp_r3dvar(ng)
          ELSE
            pioVar%dkind=PIO_real
            ioDesc => ioDesc_sp_r3dvar(ng)
          END IF
        CASE (u3dvar)
          IF (fld_kind.eq.8) THEN
            pioVar%dkind=PIO_double
            ioDesc => ioDesc_dp_u3dvar(ng)
          ELSE
            pioVar%dkind=PIO_real
            ioDesc => ioDesc_sp_u3dvar(ng)
          END IF
        CASE (w3dvar)
          IF (fld_kind.eq.8) THEN
            pioVar%dkind=PIO_double
            ioDesc => ioDesc_dp_w3dvar(ng)
          ELSE
            pioVar%dkind=PIO_real
            ioDesc => ioDesc_sp_w3dvar(ng)
          END IF
      END SELECT

      ! Read in variable.
      
      SELECT CASE (field%name)
                                                         ! 2D variables
        CASE ('ssh',                                                           &
              'sea_surface_height_above_geoid',                                &
              'u2docn',                                                        &
              'barotropic_sea_water_x_velocity',                               &
              'v2docn',                                                        &
              'barotropic_sea_water_y_velocity',                               &
              'DU_avg1',                                                       &
              'sea_water_time_average_of_barotropic_x_velocity_flux',          &
              'DV_avg1',                                                       &
              'sea_water_time_average_of_barotropic_y_velocity_flux',          &
              'DU_avg2',                                                       &
              'sea_water_correct_barotropic_x_velocity_flux_for_coupling',     &
              'DV_avg2'                                                        &
              'sea_water_correct_barotropic_y_velocity_flux_for_coupling')

          CALL nc_err (nf_fread2d(ng, model, ncname, pioFile,                  &
                                  field%metadata%io_name,                      &
                                  pioVar, InpRec, ioDesc, Vsize,               &
                                  LBi, UBi, LBj, UBj,                          &
                                  scale, field%MinValue, field%MaxValue,       &
                                  field%mask,                                  &
                                  field%val(:,:,1),                            &
                                  checksum = Fhash),                           &
                       PIO_noerr, io_pio, __LINE__, MyFile)

          IF (LocalPET .eq. 0) THEN
            WRITE (stdout,20) field%metadata%io_name,                          &
                              field%MinValue, field%MaxValue, Fhash
          END IF

                                                         ! 3D variables
        CASE ('uocn',                                                          &
              'sea_water_x_velocity',                                          &
              'vocn',                                                          &
              'sea_water_y_velocity',                                          &
              'uaocn',                                                         &
              'eastward_sea_water_velocity',                                   &
              'vaocn',                                                         &
              'northward_sea_water_velocity',                                  &
              'tocn',                                                          &
              'sea_water_temperature',                                         &
              'sea_water_potential_temperature',                               &
              'socn',                                                          &
              'sea_water_salinity',                                            &
              'Kvocn',                                                         &
              'vertical_viscosity_coefficient_of_sea_water',                   &
              'Ktocn',                                                         &
              'vertical_diffusion_coefficient_of_temperature_in_sea_water',    &
              'Ksocn',                                                         &
              'vertical_diffusion_coefficient_of_salinity_in_sea_water')

          CALL nc_err (nf_fread3d(ng, model, ncname, pioFile,                  &
                                  field%metadata%io_name,                      &
                                  pioVar, InpRec, ioDesc, Vsize,               &
                                  LBi, UBi, LBj, UBj, LBk, UBk,                &
                                  scale, field%MinValue, field%MaxValue,       &
                                  field%mask,                                  &
                                  field%val,                                   &
                                  checksum = Fhash),                           &
                       PIO_noerr, io_pio, __LINE__, MyFile)

          IF (LocalPET .eq. 0) THEN
            WRITE (stdout,20) field%metadata%io_name,                          &
                              field%MinValue, field%MaxValue, Fhash
          END IF

      END SELECT

      IF (.FALSE. .and. (LocalPET .eq. 0)) THEN
        PRINT '(a)',           '------------------'
        PRINT '(2(a,i0))',     'ng     = ', ng, ', tile = ' , LocalPET
        PRINT '(2(a,i0),a,a)', 'ncid   = ', ncid, ', varid  = ', varid,        &
                               ', ncname = ', TRIM(ncname)
        PRINT '(6a)',          'field  = ', field%metadata%io_name,            &
                               ' :: ', field%metadata%short_name,              &
                               ' :: ', field%metadata%name
        PRINT '(a,3(i0,1x))',  'shape  = ', SHAPE(field%val)
        PRINT '(a,6(i0,1x))',  'bounds = ', LBi, UBi, LBj, UBj, LBk, UBk
      END IF

      ! Parallel exchange of halo points.

      CALL self%fields(i)%update_halo (geom)

    ELSE

      ! An error is issued if required state vector variables are not found.
      ! Secondary trajectory variables used to linearize the TLM and ADM
      ! kernels will be processed elsewhere.

      SELECT CASE (field%name)

        CASE ('ssh',                                                           &
              'sea_surface_height_above_geoid',                                &
              'uocn',                                                          &
              'sea_water_x_velocity',                                          &
              'vocn',                                                          &  
              'sea_water_y_velocity',                                          &
              'uaocn',                                                         &
              'eastward_sea_water_velocity',                                   &
              'vaocn',                                                         &
              'northward_sea_water_velocity',                                  &
              'tocn',                                                          &
              'sea_water_temperature',                                         &
              'sea_water_potential_temperature',                               &
              'socn',                                                          &
              'sea_water_salinity')

          WRITE (Message,'(6a)')                                               &
                'roms_fields::write_pio: Cannot find an option to read = ',    &
                TRIM(field%name), ' - ', TRIM(field%metadata%io_name),         &
                ', file: ', TRIM(ncname)
          CALL abor1_ftn (TRIM(Message))

        CASE ('Kvocn',                                                         &
              'vertical_viscosity_coefficient_of_sea_water',                   &
              'Ktocn',                                                         &
              'vertical_diffusion_coefficient_of_temperature_in_sea_water',    &
              'Ksocn'                                                          &
              'vertical_diffusion_coefficient_of_salinity_in_sea_water')

          field%val = 1.0E-5_kind_real

        CASE ('Hzocn',                                                         &
              'model_level_thickness_at_cell_center')

          field%val = self%geom%Hz

        CASE ('z0ocn_r',                                                       &
              'unvarying_model_level_depth_at_cell_center')

          field%val = self%geom%z0_r

        CASE ('zocn_r',                                                        &
              'model_level_depth_at_cell_center')

          field%val = self%geom%z_r

        CASE ('z0ocn_w',                                                       &
              'unvarying_model_level_depth_at_cell_top_face')

          field%val = self%geom%z0_w

        CASE ('zocn_w',                                                        &
              'model_level_depth_at_cell_top_face')

          field%val = self%geom%z_w

        CASE DEFAULT

          field%val = 0.0_kind_real

      END SELECT

    END IF

  END DO

  ! Close NetCDF file.

  CALL pio_netcdf_close (ng, model, pioFile, ncname, .FALSE.)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  10 FORMAT (/,1x,'ROMS_FIELDS::read_pio  - ',a,t75,a,/,26x,                   &
             '(Grid=',i2.2,', datenum=',f0.4,', File: ',a,', Rec= ',i0,')')
  20 FORMAT (24x,'- ',a,/,27x,'(Min = ',1p,e15.8,' Max = ',1p,e15.8,           &
             'CheckSum = ',i0,')')

END SUBROUTINE roms_fields_read_pio

! ------------------------------------------------------------------------------
!> Writes fields into output file using Paralell I/O (PIO) library.

SUBROUTINE roms_fields_write_pio (self, S, romsTime)

  USE mod_pio_netcdf
 
  CLASS (roms_fields), target, intent(inout) :: self         !< Fields set
  TYPE (T_IO),                 intent(inout) :: S(:)         !< ROMS I/O struc
  real (kind=kind_real)                      :: romsTime(:)  !< ROMS time (s)

  TYPE (roms_field), pointer                 :: field
  TYPE (roms_geom), pointer                  :: geom
  TYPE (IO_desc_t), pointer                  :: ioDesc
  TYPE (My_VarDesc)                          :: pioVar

  integer                                    :: Fcount, LocalPET, lstr, lend
  integer                                    :: Cgrid, fld_kind, idfld, vindex
  integer                                    :: i, model, ng
  integer                                    :: LBi, UBi, LBj, UBj, LBk, UBk
  real (kind=kind_real)                      :: DateNumber, scale
  real (kind=kind_real)                      :: stats(4)
  character (len=22)                         :: DateString
  character (len=1024)                       :: Message

  character (len=*), parameter               :: MyFile =                       &
     &  __FILE__//", roms_fields_write_pio"

  ! Initialize.

  geom => self%geom

  LocalPET   = my_comm%rank()          !< PET rank
  SourceFile = MyFile                  !< current executed ROMS routine
  model      = geom%model              !< ROMS numerical kernel
  ng         = geom%ng                 !< nested grid number

  IF (LdebugFields .and. (LocalPET .eq. 0)) THEN
    lstr = SCAN(S(ng)%name, '/', BACK=.TRUE.) + 1
    lend = LEN_TRIM(S(ng)%name)    
    PRINT '(2a)', 'ROMS_DEBUG roms_fields::write_pio - writing state,'//       &
                  ' File = ', S(ng)%name(lstr:lend)
  END IF

  ! Set writing parameters.

  scale = 1.0_kind_real                     !< field scale
  S(ng)%Rindex = S(ng)%Rindex + 1           !< NetCDF time record
  Fcount=S(ng)%load                         !< filename load counter
  S(ng)%Nrec(Fcount)=S(ng)%Nrec(Fcount)+1   !< record counter per multi-file

  ! Write out ROMS time variable.

  CALL pio_netcdf_put_fvar (ng, model, S(ng)%name, TRIM(Vname(1,idtime)),      &
                            romsTime(ng:), (/S(ng)%Rindex/), (/1/),            &
                            pioFile = S(ng)pioFile,                            &
                            pioVar = S(ng)%pioVar(idtime)%vd)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  ! Get output fields fractional "datenum".

  DateNumber = Rclock%DateNumber(1) + romsTime(ng)/86400.0_kind_real
  CALL datestr (DateNumber, .TRUE., DateString)

 ! Inquire about all variables.

  CALL pio_netcdf_inq_var (ng, model, S(ng)%name,                              &
                           piofile = S(ng)pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  ! Write out all fields. ROMS needs to be compiled with MASKING to use the
  ! writing NetCDF functions below.

  DO i = 1, SIZE(self%fields)

    field => self%fields(i)

    IF (field%io_has_var(geom, vindex)) THEN

      Cgrid = field%metadata%Cgrid
      idfld = roms_metadata_index(field%name)


      LBi = LBOUND(field%val, DIM=1)
      UBi = UBOUND(field%val, DIM=1)
      LBj = LBOUND(field%val, DIM=2)
      UBj = UBOUND(field%val, DIM=2)
      LBk = LBOUND(field%val, DIM=3)
      UBk = UBOUND(field%val, DIM=3)

      field%OutNCname = TRIM(S(ng)%name)
      field%OutNCid   = S(ng)%pioFile%fh
      field%OutRec    = S(ng)%Rindex

      CALL field%stats (stats)

      lstr = MAX(22, LEN_TRIM(DateString))
      IF (allocated(field%DateTimeString)) THEN
        deallocate ( field%DateTimeString )
      END IF
      allocate (character(LEN=lstr) :: field%DateTimeString )
      field%DateTimeString = TRIM(DateString)

      field%DateNumber = DateNumber

      ! Set variable and IO descriptors.

      fld_kind = PIO_FOUT

      pioVar%vd    = var_desc(vindex)
      pioVar%gtype = Cgrid

      SELECT CASE (Cgrid)
        CASE (r2dvar)
          IF (fld_kind.eq.PIO_double) THEN
            pioVar%dkind=PIO_double
            ioDesc => ioDesc_dp_r2dvar(ng)
          ELSE
            pioVar%dkind=PIO_real
            ioDesc => ioDesc_sp_r2dvar(ng)
          END IF
        CASE (u2dvar)
          IF (fld_kind.eq.PIO_double) THEN
            pioVar%dkind=PIO_double
            ioDesc => ioDesc_dp_u2dvar(ng)
          ELSE
            pioVar%dkind=PIO_real
            ioDesc => ioDesc_sp_u2dvar(ng)
          END IF
        CASE (v2dvar)
          IF (fld_kind.eq.PIO_double) THEN
            pioVar%dkind=PIO_double
            ioDesc => ioDesc_dp_v2dvar(ng)
          ELSE
            pioVar%dkind=PIO_real
            ioDesc => ioDesc_sp_v2dvar(ng)
          END IF
        CASE (r3dvar)
          IF (fld_kind.eq.PIO_double) THEN
            pioVar%dkind=PIO_double
            ioDesc => ioDesc_dp_r3dvar(ng)
          ELSE
            pioVar%dkind=PIO_real
            ioDesc => ioDesc_sp_r3dvar(ng)
          END IF
        CASE (u3dvar)
          IF (fld_kind.eq.PIO_double) THEN
            pioVar%dkind=PIO_double
            ioDesc => ioDesc_dp_u3dvar(ng)
          ELSE
            pioVar%dkind=PIO_real
            ioDesc => ioDesc_sp_u3dvar(ng)
          END IF
        CASE (w3dvar)
          IF (fld_kind.eq.PIO_double) THEN
            pioVar%dkind=PIO_double
            ioDesc => ioDesc_dp_w3dvar(ng)
          ELSE
            pioVar%dkind=PIO_real
            ioDesc => ioDesc_sp_w3dvar(ng)
          END IF
      END SELECT

      ! Write out variable.

      SELECT CASE (field%name)
                                                         ! 2D variables
        CASE ('ssh',                                                           &
              'sea_surface_height_above_geoid',                                &
              'u2docn',                                                        &
              'barotropic_sea_water_x_velocity',                               &
              'v2docn',                                                        &
              'barotropic_sea_water_y_velocity',                               &
              'DU_avg1',                                                       &
              'sea_water_time_average_of_barotropic_x_velocity_flux',          &
              'DV_avg1',                                                       &
              'sea_water_time_average_of_barotropic_y_velocity_flux',          &
              'DU_avg2',                                                       &
              'sea_water_correct_barotropic_x_velocity_flux_for_coupling',     &
              'DV_avg2'                                                        &
              'sea_water_correct_barotropic_y_velocity_flux_for_coupling')

          CALL nc_err (nf_fwrite2d(ng, model, S(ng)%pioFile, idfld,            &
                                   pioVar, S(ng)%Rindex, ioDesc,               &
                                   LBi, UBi, LBj, UBj, scale,                  &
                                   field%mask,                                 &
                                   field%val(:,:,1),                           &
                                   MinValue = field%MinValue,                  &
                                   MaxValue = field%MaxValue),                 &
                       PIO_noerr, io_pio, __LINE__, MyFile)

          IF (LocalPET .eq. 0) THEN
            PRINT 10, field%metadata%io_name, field%MinValue, field%MaxValue,  &
                      S(ng)%Rindex, INT(stats(4), KIND=8)
          END IF

                                                         ! 3D variables
        CASE ('uocn',                                                          &
              'sea_water_x_velocity',                                          &
              'vocn',                                                          &
              'sea_water_y_velocity',                                          &
              'uaocn',                                                         &
              'eastward_sea_water_velocity',                                   &
              'vaocn',                                                         &
              'northward_sea_water_velocity',                                  &
              'tocn',                                                          &
              'sea_water_temperature',                                         &
              'sea_water_potential_temperature',                               &
              'socn',                                                          &
              'sea_water_salinity',                                            &
              'Hzocn',                                                         &
              'model_level_thickness_at_cell_center',                          &
              'Kvocn',                                                         &
              'vertical_viscosity_coefficient_of_sea_water',                   &
              'Ktocn',                                                         &
              'vertical_diffusion_coefficient_of_temperature_in_sea_water',    &
              'Ksocn',                                                         &
              'vertical_diffusion_coefficient_of_salinity_in_sea_water')

          CALL nc_err (nf_fwrite3d(ng, model, S(ng)%pioFile, idfld,            &
                                   pioVar, S(ng)%Rindex, ioDesc,               &
                                   LBi, UBi, LBj, UBj, LBk, UBk, scale,        &
                                   field%mask,                                 &
                                   field%val,                                  &
                                   MinValue = field%MinValue,                  &
                                   MaxValue = field%MaxValue),                 &
                       PIO_noerr, io_pio, __LINE__, MyFile)

          IF (LocalPET .eq. 0) THEN
            PRINT 10, field%metadata%io_name, field%MinValue, field%MaxValue,  &
                      S(ng)%Rindex, INT(stats(4), KIND=8)
          END IF

      END SELECT

    ELSE

      SELECT CASE (field%name)

        CASE ('zocn_r',                                                        &
              'model_level_depth_at_cell_center',                              &
              'z0ocn_r',                                                       &
              'unvarying_model_level_depth_at_cell_center',                    &
              'zocn_w',                                                        &
              'model_level_depth_at_cell_top_face',                            &
              'z0ocn_w',                                                       &
              'unvarying_model_level_depth_at_cell_top_face')

        ! Ignore time-dependent metric variables.

        CASE DEFAULT

          WRITE (Message,'(6a)')                                               &
                'roms_fields::write_pio: Cannot find an option to write = ',   &
                TRIM(field%name), ' - ', TRIM(field%metadata%io_name),         &
                ', file: ', TRIM(S(ng)%name)
          CALL abor1_ftn (TRIM(Message))

      END SELECT

    END IF
    
  END DO

  ! Synchronize NetCDF to disk.

  CALL pio_netcdf_sync (ng, model, S(ng)%name, S(ng)%pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  10 FORMAT (2x,'- ',a,':',t30,'Min = ',1p,e15.8,',  Max = ',1p,e15.8,         &
             ',  Rec = ',i3,',  CheckSum = ',i0)

END SUBROUTINE roms_fields_write_pio


! ------------------------------------------------------------------------------
!> Writes zero fields into output file using Paralell I/O (PIO) library.

SUBROUTINE roms_fields_write_zero_pio (self, S)

  USE mod_pio_netcdf

  CLASS (roms_fields), target, intent(inout) :: self          !< Fields set
  TYPE (T_IO),                 intent(inout) :: S(:)          !< ROMS I/O struc

  TYPE (roms_geom), pointer                  :: geom
  TYPE (IO_desc_t), pointer                  :: ioDesc
  TYPE (My_VarDesc)                          :: pioVar

  integer                                    :: LocalPET, i, model, ng
  integer                                    :: LBi, UBi, LBj, UBj, LBk, UBk
  integer                                    :: idfld
  real (kind=kind_real)                      :: Fmin, Fmax, scale
  real (kind=kind_real), allocatable         :: F2dat(:,:), F3dat(:,:,:)
  character (len=1024)                       :: Message

  character (len=*), parameter               :: MyFile =                       &
     &  __FILE__//", roms_fields_write_zero_pio"

  ! Initialize

  geom => self%geom

  LocalPET   = my_comm%rank()          !< PET rank
  SourceFile = MyFile                  !< current executed ROMS routine
  model      = geom%model              !< ROMS numerical kernel
  ng         = geom%ng                 !< nested grid number

  LBi = geom%LBi
  UBi = geom%UBi
  LBj = geom%LBj
  UBj = geom%UBj
  UBk = geom%N

  ! Set writing parameters.

  scale = 1.0_kind_real                !< field scale

  ! Inquire about all variables.

  CALL pio_netcdf_inq_var (ng, model, S(ng)%name,                              &
                           pioFile = S(ng)%pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  ! Write out zero fields.

  DO i = 1, n_var
    IF (var_ndim(i).ge.3) THEN
      IF (.not.self%has(TRIM(var_name(i)))) THEN

        fld_kind = PIO_FOUT

        SELECT CASE (TRIM(var_name(i)))        

          CASE ('ubar', 'u2docn',                                              &
                'barotropic_sea_water_x_velocity',                             &
                'DU_avg1',                                                     &
                'sea_water_time_average_of_barotropic_x_velocity_flux',        &
                'DU_avg2',                                                     &
                'sea_water_correct_barotropic_x_velocity_flux_for_coupling')

            IF (.not.allocated(F2dat)) THEN
              allocate ( F2dat(LBi:UBi, LBj:UBj) )
              F2dat = 0.0_kind_real
            END IF

            idfld = roms_metadata_index(TRIM(var_name(i)))
            pioVar%vd = var_desc(var_id(i))
            pioVar%gtype = u2dvar

            IF (fld_kind.eq.PIO_double) THEN
              pioVar%dkind=PIO_double
              ioDesc => ioDesc_dp_u2dvar(ng)
            ELSE
              pioVar%dkind=PIO_real
              ioDesc => ioDesc_sp_u2dvar(ng)
            END IF

            CALL nc_err (nf_fwrite2d(ng, model, S(ng)%pioFile, idfld,          &
                                     pioVar, S(ng)%Rindex, ioDesc,             &
                                     LBi, UBi, LBj, UBj, scale,                &
                                     geom%umask,                               &
                                     F2dat,                                    &
                                     MinValue = Fmin,                          &
                                     MaxValue = Fmax),                         &
                         PIO_noerr, io_pio, __LINE__, MyFile)

            IF (LocalPET .eq. 0) THEN
              PRINT 10, TRIM(var_name(i)), Fmin, Fmax, S(ng)%Rindex, 0
            END IF
            deallocate ( F2dat )

          CASE ('vbar', 'v2docn',                                              &
                'barotropic_sea_water_y_velocity',                             &
                'DV_avg1',                                                     &
                'sea_water_time_average_of_barotropic_y_velocity_flux',        &
                'DV_avg2',                                                     &
                'sea_water_correct_barotropic_y_velocity_flux_for_coupling')

            IF (.not.allocated(F2dat)) THEN
              allocate ( F2dat(LBi:UBi, LBj:UBj) )
              F2dat = 0.0_kind_real
            END IF

            idfld = roms_metadata_index(TRIM(var_name(i)))
            pioVar%vd = var_desc(var_id(i))
            pioVar%gtype = v2dvar

            IF (fld_kind.eq.PIO_double) THEN
              pioVar%dkind=PIO_double
              ioDesc => ioDesc_dp_v2dvar(ng)
            ELSE
              pioVar%dkind=PIO_real
              ioDesc => ioDesc_sp_v2dvar(ng)
            END IF

            CALL nc_err (nf_fwrite2d(ng, model, S(ng)%pioFile, idfld,          &
                                     pioVar, S(ng)%Rindex, ioDesc,             &
                                     LBi, UBi, LBj, UBj, scale,                &
                                     geom%vmask,                               &
                                     F2dat,                                    &
                                     MinValue = Fmin,                          &
                                     MaxValue = Fmax),                         &
                         PIO_noerr, io_pio, __LINE__, MyFile)

            IF (LocalPET .eq. 0) THEN
              PRINT 10, TRIM(var_name(i)), Fmin, Fmax, S(ng)%Rindex, 0
            END IF
            deallocate ( F2dat )

          CASE ('AKv', 'Kvocn',                                                &
                'vertical_viscosity_coefficient_of_sea_water',                 &
                'AKt', 'Ktocn',                                                &
                'vertical_diffusion_coefficient_of_temperature_in_sea_water',  &
                'AKs', 'Ksocn',                                                &
                'vertical_diffusion_coefficient_of_salinity_in_sea_water')

            LBk=0
            IF (.not.allocated(F3dat)) THEN
              allocate ( F3dat(LBi:UBi, LBj:UBj, LBk:UBk) )
              F3dat = 0.0_kind_real
            END IF

            idfld = roms_metadata_index(TRIM(var_name(i)))
            pioVar%vd = var_desc(var_id(i))
            pioVar%gtype = w3dvar

            IF (fld_kind.eq.PIO_double) THEN
              pioVar%dkind=PIO_double
              ioDesc => ioDesc_dp_w3dvar(ng)
            ELSE
              pioVar%dkind=PIO_real
              ioDesc => ioDesc_sp_w3dvar(ng)
            END IF

            CALL nc_err (nf_fwrite3d(ng, model, S(ng)%pioFile, idfld,          &
                                     pioVar, S(ng)%Rindex, ioDesc,             &
                                     LBi, UBi, LBj, UBj, LBk, UBk, scale,      &
                                     geom%rmask,                               &
                                     F3dat,                                    &
                                     MinValue = Fmin,                          &
                                     MaxValue = Fmax),                         &
                         PIO_noerr, io_pio, __LINE__, MyFile)

            IF (LocalPET .eq. 0) THEN
              PRINT 10, TRIM(var_name(i)), Fmin, Fmax, S(ng)%Rindex, 0
            END IF
            deallocate ( F3dat )

        END SELECT
      END IF
    END IF
  END DO

  ! Synchronize NetCDF to disk.

  CALL pio_netcdf_sync (ng, model, S(ng)%name, S(ng)%pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  10 FORMAT (2x,'- ',a,':',t30,'Min = ',1p,e15.8,',  Max = ',1p,e15.8,         &
             ',  Rec = ',i3,',  CheckSum = ',i0)

END SUBROUTINE roms_fields_write_zero_pio

#endif

! ------------------------------------------------------------------------------

END MODULE roms_fields_mod
