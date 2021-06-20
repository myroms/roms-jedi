! (C) Copyright 2017-2021 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
! Hernan G. Arango, Rutgers University, Jun 2021

!> ROMS fields object

MODULE roms_fields_mod

USE fckit_configuration_module, ONLY : fckit_configuration
USE fckit_log_module,           ONLY : log, fckit_log
USE fckit_mpi_module,           ONLY : fckit_mpi_comm, &
                                       fckit_mpi_min,  &
                                       fckit_mpi_max,  &
                                       fckit_mpi_sum
USE datetime_mod,               ONLY : datetime, datetime_set
USE duration_mod,               ONLY : duration
USE kinds,                      ONLY : kind_real
USE oops_variables_mod

USE interpolate_mod
USE roms_fieldsutils_mod
USE roms_geom_mod,              ONLY : roms_geom
USE mod_scalars,                ONLY : NoError, exit_flag

implicit none

PRIVATE

PUBLIC  :: roms_field
PUBLIC  :: roms_fields

!  Switch for printing fields information during debugging

logical :: LdebugFields = .TRUE.

! ------------------------------------------------------------------------------
!> Structure holds all data and metadata related to a single field variable
! ------------------------------------------------------------------------------

TYPE :: roms_field

  integer                            :: Istr, Iend           !< tile I-range
  integer                            :: Jstr, Jend           !< tile J-range
  integer                            :: N                    !< number of levels
  integer                            :: InpNCid, OutNCid     !< NetCDF file IDs
  integer                            :: InpRec, OutRec       !< NetCDF records

  real (kind=kind_real),     pointer :: angle(:,:) => null() !< field grid angle
  real (kind=kind_real),     pointer :: lon(:,:)   => null() !< field lon
  real (kind=kind_real),     pointer :: lat(:,:)   => null() !< field lat
  real (kind=kind_real),     pointer :: mask(:,:)  => null() !< field mask
  real (kind=kind_real), allocatable :: val(:,:,:)           !< field data

  character (len=1)                  :: gtype                !< C-grid location: 'r', 'u' or 'v'

  character (len=:),     allocatable :: name                 !< internal field name
  character (len=:),     allocatable :: cf_name              !< UFO fields standard name
  character (len=:),     allocatable :: io_name              !< I/O NetCDF file variable name
  character (len=:),     allocatable :: io_file              !< component file domain: 'ocn'

  character (len=:),     allocatable :: InpNCname, OutNCname !< input/output NetCDF filenames
  
  CONTAINS
  
  PROCEDURE :: copy            => roms_field_copy
  PROCEDURE :: delete          => roms_field_delete

  PROCEDURE :: check_congruent => roms_field_check_congruent
  PROCEDURE :: update_halo     => roms_field_update_halo
  PROCEDURE :: stencil_interp  => roms_field_stencil_interp

END TYPE roms_field

! ------------------------------------------------------------------------------
!> Structure to holds a collection of roms_field types, and the public routines
!> to manipulate them. Represents all the fields of a given state or increment
! ------------------------------------------------------------------------------

TYPE :: roms_fields

  TYPE (roms_geom),  pointer :: geom                  !< ROMS Geometry
  TYPE (roms_field), pointer :: fields(:) => null()

  CONTAINS

  ! Field constructors and destructors

  PROCEDURE :: create          => roms_fields_create
  PROCEDURE :: copy            => roms_fields_copy
  PROCEDURE :: delete          => roms_fields_delete

  ! field getters/checkers

  PROCEDURE :: get             => roms_fields_get
  PROCEDURE :: has             => roms_fields_has
  PROCEDURE :: check_congruent => roms_fields_check_congruent
  PROCEDURE :: check_subset    => roms_fields_check_subset

  ! Field math operations

  PROCEDURE :: add             => roms_fields_add
  PROCEDURE :: axpy            => roms_fields_axpy
  PROCEDURE :: dot_prod        => roms_fields_dotprod
  PROCEDURE :: gpnorm          => roms_fields_gpnorm
  PROCEDURE :: mul             => roms_fields_mul
  PROCEDURE :: sub             => roms_fields_sub
  PROCEDURE :: analytic        => roms_fields_analytic
  PROCEDURE :: ones            => roms_fields_ones
  PROCEDURE :: zeros           => roms_fields_zeros

  ! Field I/O processing

  PROCEDURE :: read            => roms_fields_read
  PROCEDURE :: write           => roms_fields_write

  ! Misc

  PROCEDURE :: update_halos    => roms_fields_update_halos
  PROCEDURE :: colocate        => roms_fields_colocate

  ! Field serialization

  PROCEDURE :: serial_size     => roms_fields_serial_size
  PROCEDURE :: serialize       => roms_fields_serialize
  PROCEDURE :: deserialize     => roms_fields_deserialize

END TYPE roms_fields

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
! ROMS routines for a single field:
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
!> Copy a field from RHS to SELF. SELF must be allocated first. The pointers
!> (mask, lat, lon) will be different, but should NOT be changed to point to
!> RHS pointers. Bad things will happen.

SUBROUTINE roms_field_copy (self, rhs)

  CLASS (roms_field), intent(inout) :: self
  TYPE (roms_field),  intent(   in) :: rhs

  CALL self%check_congruent (rhs)

  ! The only variable that should be different is %val

  IF (LdebugFields) THEN
    PRINT '(2a,a4,5(a,i0))', 'Entered roms_field::copy:',         &
                             ' name = ', rhs%name,                &
                             ', LBi = ', LBOUND(rhs%val,DIM=1),   &
                             ', UBi = ', UBOUND(rhs%val,DIM=1),   &
                             ', LBj = ', LBOUND(rhs%val,DIM=2),   &
                             ', UBj = ', UBOUND(rhs%val,DIM=2),   &
                             ', N = ',   UBOUND(rhs%val,DIM=3)
  END IF

  self%val = rhs%val

END SUBROUTINE roms_field_copy

! ------------------------------------------------------------------------------
!> Delete field object.

SUBROUTINE roms_field_delete (self)

  CLASS (roms_field), intent(inout) :: self

  IF (LdebugFields) THEN
    PRINT '(2a,a4,5(a,i0))', 'Entered roms_field::copy:',         &
                             ', name = ', self%name,              &
                             '  LBi = ', LBOUND(self%val,DIM=1),  &
                             ', UBi = ', UBOUND(self%val,DIM=1),  &
                             ', LBj = ', LBOUND(self%val,DIM=2),  &
                             ', UBj = ', UBOUND(self%val,DIM=2),  &
                             ', N = ',   UBOUND(self%val,DIM=3)
  END IF

  deallocate (self%val)

END SUBROUTINE roms_field_delete

! ------------------------------------------------------------------------------
!> Make sure the two fields are the same in terms of name, size, and shape.

SUBROUTINE roms_field_check_congruent (self, rhs)

  CLASS (roms_field), intent(in) :: self
  TYPE (roms_field),  intent(in) :: rhs

  integer                       :: i

  IF (self%N .ne. rhs%N) THEN
    CALL abor1_ftn ("roms_field:  self%N unequal rhs%N") 
  END IF

  IF (self%name .ne. rhs%name) THEN
    CALL abor1_ftn ("roms_field:  self%name unequal rhs%name")
  END IF

  IF (SIZE(SHAPE(self%val)) .ne. SIZE(SHAPE(rhs%val))) THEN
    call abor1_ftn ("roms_field: shape of self%val unequal rhs%val")
  END IF

  DO i = 1, SIZE(SHAPE(self%val))
    IF (SIZE(self%val, DIM=i) .ne. SIZE(rhs%val, DIM=i)) THEN
      CALL abor1_ftn ("roms_field: shape of self%val unequal rhs%val")
    END IF
  END DO

END SUBROUTINE roms_field_check_congruent

! ------------------------------------------------------------------------------
!> Update field halo points due to parallel tile partition.

SUBROUTINE roms_field_update_halo (self, geom)

  USE mp_exchange_mod, ONLY : mp_exchange2d, mp_exchange3d

  CLASS (roms_field),        intent(inout) :: self
  TYPE (roms_geom), pointer, intent(   in) :: geom

  logical                                  :: EWperiodic, NSperiodic
  integer                                  :: model, ng, tile, NghostPoints
  integer                                  :: LBi, UBi, LBj, UBj, LBk, UBk

  model = geom%model                    ! numerical kernel
  ng    = geom%ng                       ! nested grid number
  tile  = geom%tile                     ! tile partition

  NghostPoints = geom%NghostPoints      ! number of ghost points

  EWperiodic = geom%EWperiodic          ! East-West   periodicity switch
  NSperiodic = geom%NSperiodic          ! North-South periodicity switch

  LBi = geom%LBi
  UBi = geom%UBi
  LBj = geom%LBj
  UBj = geom%UBj
  LBk = geom%LBk
  UBk = geom%UBk

  SELECT CASE (self%name)
    CASE ('ssh')
      CALL mp_exchange2d (ng, tile, 1, 1, LBi, UBi, LBj, UBj, &
                          NghostPoints, EWperiodic, NSperiodic, &
                          self%val(:,:,1))
    CASE ('uocn', 'vocn', 'tocn', 'socn')
      CALL mp_exchange3d (ng, tile, 1, 1, LBi, UBi, LBj, UBj, LBk, UBk, &
                          NghostPoints, EWperiodic, NSperiodic, &
                          self%val)
    CASE DEFAULT
      CALL abor1_ftn ('roms_field::update_halo: wrong SIZE(SHAPE(field))')
  END SELECT
    
END SUBROUTINE roms_field_update_halo

! ------------------------------------------------------------------------------
!> Interpolate 2D or 3D field to different grid stencil location

SUBROUTINE roms_field_stencil_interp (self, geom, interp, method)

  CLASS (roms_field),        intent(inout) :: self
  TYPE (roms_geom), pointer, intent(   in) :: geom
  TYPE (roms_interp_type),   intent(inout) :: interp
  integer,                   intent(   in) :: method                           

  real(kind=kind_real),        allocatable :: val_src(:,:,:)

  ! Make a temporary copy of source field

  allocate (val_src, MOLD=self%val)
  val_src = self%val

  ! Interpolate field level-by-level

  CALL roms_horiz_interp (interp, val_src, self%val, method)
  IF (exit_flag .ne. NoError) THEN
    CALL abor1_ftn ("roms_field::stencil_interp: Error in roms_horiz_interp")
  END IF

  ! Update halo

  CALL self%update_halo (geom)

  ! Deallocate temporary array

  IF (allocated(val_src)) deallocate (val_src)

END SUBROUTINE roms_field_stencil_interp

! ------------------------------------------------------------------------------
!> Initializes ROMS field interpolation structure

SUBROUTINE roms_field_interp_initialize (geom, field, interp, gtype)

  TYPE (roms_geom),        intent(   in) :: geom    !< geometry object
  TYPE (roms_field),       intent(inout) :: field   !< field object
  TYPE (roms_interp_type), intent(inout) :: interp  !< interpolation object
  character (len=*),       intent(   in) :: gtype   !< C-grid location

  integer                                :: ng

  ! If applicable, deallocate interpolation structure

  IF (associated(interp%lon_src)) THEN
    CALL roms_interp_delete (interp)
  END IF

  ! Associate source (lon,lat) coordinates

  interp%angle_src = field%angle
  interp%lon_src   = field%lon
  interp%lat_src   = field%lat

  interp%LBi_src = LBOUND(interp%lon_src, DIM=1)
  interp%UBi_src = UBOUND(interp%lon_src, DIM=1)
  interp%LBj_src = LBOUND(interp%lat_src, DIM=2)
  interp%UBj_src = UBOUND(interp%lat_src, DIM=2)

  interp%Istr_src = field%Istr
  interp%Iend_src = field%Iend
  interp%Jstr_src = field%Jstr
  interp%Jend_src = field%Jend

  ng = geom%ng

  ! Associate destination (lon,lat) coordinates according to C-grid locations

  interp%LBi_dst = geom%LBi
  interp%UBi_dst = geom%UBi
  interp%LBj_dst = geom%LBj
  interp%UBj_dst = geom%UBj

  SELECT CASE (gtype)
    CASE ('r', 'R')                      !< RHO-points
      interp%Istr_dst = geom%IstrR
      interp%Iend_dst = geom%IendR
      interp%Jstr_dst = geom%JstrR
      interp%Jend_dst = geom%JendR
      interp%lon_dst  = geom%lonr
      interp%lat_dst  = geom%latr
    CASE ('u', 'U')                      !< U-points
      interp%Istr_dst = geom%Istr
      interp%Iend_dst = geom%IendR
      interp%Jstr_dst = geom%JstrR
      interp%Jend_dst = geom%JendR
      interp%lon_dst  = geom%lonu
      interp%lat_dst  = geom%latu
    CASE ('v', 'V')                      !< V-points
      interp%Istr_dst = geom%IstrR
      interp%Iend_dst = geom%IendR
      interp%Jstr_dst = geom%Jstr
      interp%Jend_dst = geom%JendR
      interp%lon_dst  = geom%lonv
      interp%lat_dst  = geom%latv
    CASE DEFAULT
      CALL abor1_ftn ('roms_field::hindices unknown C-grid location = '// gtype)
  END SELECT

  ! Compute the horizontal fractional coordinates (x_dst, y_dst) of the source
  ! cells containing the destination values.

  CALL roms_interp_fractional (interp)

END SUBROUTINE roms_field_interp_initialize

! ------------------------------------------------------------------------------
! ROMS routines for a set of fields:
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
!> Create a new set of fields, allocate space for them, and initialize to zero

SUBROUTINE roms_fields_create (self, geom, vars)

  CLASS (roms_fields),        intent(inout) :: self
  TYPE (roms_geom),  pointer, intent(inout) :: geom
  TYPE (oops_variables),      intent(inout) :: vars  !< field names to create

  integer                                   :: i
  character(len=:), allocatable             :: vars_str(:)

  ! Make sure current object has not already been allocated

  IF (ASSOCIATED(self%fields)) THEN
    CALL abor1_ftn ("roms_fields::create(): object already allocated")
  END IF

  ! Associate geometry

  self%geom => geom

  IF (LdebugFields) THEN
    PRINT '(a, 6(a,i0))', 'roms_fields::create: ', &
                          ' tile = ', geom%f_comm%rank(), &
                          ', LBi = ', geom%LBi, ', UBi = ', geom%UBi, &
                          ', LBj = ', geom%LBj, ', UBj = ', geom%UBj, &
                          ', N = ', geom%N
    CALL geom%f_comm%barrier()
  END IF

  ! Initialize the variable parameters

  ALLOCATE (character(len=1024) :: vars_str(vars%nvars()))

  DO i = 1, vars%nvars()
    vars_str(i) = TRIM(vars%variable(i))
  END DO

  CALL roms_fields_init_vars (self, vars_str)

  ! Set everything to zero

  CALL self%zeros ()

END SUBROUTINE roms_fields_create

! ------------------------------------------------------------------------------
!> Copy the contents of RHS to SELF. SELF will be initialized with the variable
!> names in RHS, if not already initialized

SUBROUTINE roms_fields_copy (self, rhs)

  CLASS (roms_fields), intent(inout) :: self
  CLASS (roms_fields),    intent(in) :: rhs

  integer                            :: i
  character(len=:),      allocatable :: vars_str(:)
  TYPE (roms_field),         pointer :: rhs_fld

  ! Initialize the variables based on the names in RHS

  IF (LdebugFields) THEN
    PRINT '(a, 6(a,i0))', 'Entered roms_fields::copy:',        &
                          ' tile = ', rhs%geom%f_comm%rank(),  &
                          ', LBi = ', rhs%geom%LBi,            &
                          ', UBi = ', rhs%geom%UBi,            &
                          ', LBj = ', rhs%geom%LBj,            &
                          ', UBj = ', rhs%geom%UBj,            &
                          ', N = ', rhs%geom%N
  END IF

  IF (.not. ASSOCIATED(self%fields)) THEN
    self%geom => rhs%geom

    ALLOCATE (character(len=1024) :: vars_str(SIZE(rhs%fields)))

    DO i = 1, SIZE(vars_str)
      vars_str(i) = rhs%fields(i)%name
    END DO

    CALL roms_fields_init_vars (self, vars_str)
  END IF

  ! Copy values from RHS to SELF, only if the variable exists in SELF

  DO i = 1, SIZE(self%fields)
    CALL rhs%get (self%fields(i)%name, rhs_fld)
    CALL self%fields(i)%copy (rhs_fld)
  END DO

END SUBROUTINE roms_fields_copy

! ------------------------------------------------------------------------------
!> Delete all the fields

SUBROUTINE roms_fields_delete (self)

  CLASS (roms_fields), intent(inout) :: self

  integer                            :: i

  ! Clear the fields and nullify pointers

  NULLIFY (self%geom)

  DO i = 1, SIZE(self%fields)
    CALL self%fields(i)%delete ()
  END DO

  DEALLOCATE (self%fields)

  NULLIFY (self%fields)

END SUBROUTINE roms_fields_delete

! ------------------------------------------------------------------------------
!> get a pointer to the roms_field with the given name.
!> If no field exists with that name, the prorgam aborts
!> (use roms_fields%has() if you need to check for optional fields)

SUBROUTINE roms_fields_get (self, name, field)

  CLASS (roms_fields),        intent( in) :: self
  character (len=*),          intent( in) :: name   !< name of field to find
  TYPE (roms_field), pointer, intent(out) :: field  !< resulting field pointer

  integer                                 :: i

  ! Find the field with the given name

  DO i = 1, SIZE(self%fields)
    IF (TRIM(name) == self%fields(i)%name) THEN
      field => self%fields(i)
      RETURN
    END IF
  END DO

  ! Error: field was not found

  CALL abor1_ftn ("roms_fields::get: cannot find field "//TRIM(name))

END SUBROUTINE roms_fields_get

! ------------------------------------------------------------------------------
!> Check if field with the given name exists

FUNCTION roms_fields_has (self, name) RESULT (foundit)

  CLASS (roms_fields), intent(in) :: self
  character (len=*),   intent(in) :: name

  logical                         :: foundit
  integer                         :: i

  foundit = .false.
  DO i = 1, SIZE(self%fields)
    IF (TRIM(name) == self%fields(i)%name) THEN
      foundit = .true.
      RETURN
    END IF
  END DO

END FUNCTION roms_fields_has

! ------------------------------------------------------------------------------
!> Make sure two sets of fields have the same name, size, and shape

!  TODO: make this more robust (allow for different number of fields?)

SUBROUTINE roms_fields_check_congruent (f1, f2)

  CLASS (roms_fields), intent(in) :: f1, f2

  integer                         :: i, j

  ! Number of fields should be the same

  IF (SIZE(f1%fields) .ne. SIZE(f2%fields)) THEN
    CALL abor1_ftn ("roms_fields: contains different number of fields")
  END IF

  ! Each field should match (name, size, shape)

  DO i = 1, SIZE(f1%fields)
    IF (f1%fields(i)%name .ne. f2%fields(i)%name) THEN
      CALL abor1_ftn ("roms_fields: field have different names")
    END IF

    DO j = 1, SIZE(SHAPE(f1%fields(i)%val))
      IF (SIZE(f1%fields(i)%val,DIM=j) .ne. SIZE(f2%fields(i)%val,DIM=j) ) THEN
        CALL abor1_ftn ("roms_fields: field '"// &
                        f1%fields(i)%name//"' has different dimensions")
      END IF
    END DO
  END DO

END SUBROUTINE roms_fields_check_congruent

! ------------------------------------------------------------------------------
!> Make sure two sets of fields have same shape for fields they have in common
!> f1 must be a subset of f2

!  TODO: make this more robust (allow for different number of fields?)

SUBROUTINE roms_fields_check_subset (f1, f2)

  CLASS (roms_fields), intent(in) :: f1, f2

  integer                         :: i, j
  TYPE (roms_field),      pointer :: fld

  ! Each field should match (name, size, shape)

  DO i = 1, SIZE(f1%fields)
    IF (.not. f2%has(f1%fields(i)%name)) THEN
      CALL abor1_ftn ("roms_fields: f1 is not a subset of f2")
    END IF

    CALL f2%get (f1%fields(i)%name, fld)

    DO j = 1, SIZE(SHAPE(fld%val))
      IF (SIZE(f1%fields(i)%val, dim=j) .ne. SIZE(fld%val, dim=j) ) THEN
        CALL abor1_ftn ("roms_fields: field '"//f1%fields(i)%name// &
                        "' has different dimensions")
      END IF
    END DO
  END DO

END SUBROUTINE roms_fields_check_subset

! ------------------------------------------------------------------------------
!> for a given list of field names, initialize the properties of those fields

!  NOTE: this information should be moved into a yaml file
!  TODO, allocate space for derived variables

SUBROUTINE roms_fields_init_vars (self, vars)

  CLASS (roms_fields),           intent(inout) :: self
  character(len=:), allocatable, intent(   in) :: vars(:)

  integer                                       :: LBi, UBi, LBj, UBj, N
  integer                                       :: i

  LBi = self%geom%LBi
  UBi = self%geom%UBi
  LBj = self%geom%LBj
  UBj = self%geom%UBj

  allocate ( self%fields(SIZE(vars)) )

  DO i = 1, SIZE(vars)

    self%fields(i)%name = TRIM(vars(i))

    ! determine number of levels, and if masked

    SELECT CASE (self%fields(i)%name)
      CASE ('tocn', 'socn')
        N = self%geom%N
        self%fields(i)%gtype =  "r"
        self%fields(i)%Istr  =  self%geom%IstrR
        self%fields(i)%Iend  =  self%geom%IendR
        self%fields(i)%Jstr  =  self%geom%JstrR
        self%fields(i)%Jend  =  self%geom%JendR
        self%fields(i)%angle => self%geom%angler
        self%fields(i)%lon   => self%geom%lonr
        self%fields(i)%lat   => self%geom%latr
        self%fields(i)%mask  => self%geom%rmask
      CASE ('uocn')
        N = self%geom%N
        self%fields(i)%gtype =  "u"
        self%fields(i)%Istr  =  self%geom%IstrU
        self%fields(i)%Iend  =  self%geom%IendR
        self%fields(i)%Jstr  =  self%geom%JstrR
        self%fields(i)%Jend  =  self%geom%JendR
        self%fields(i)%angle => self%geom%angleu
        self%fields(i)%lon   => self%geom%lonu
        self%fields(i)%lat   => self%geom%latu
        self%fields(i)%mask  => self%geom%umask
      CASE ('vocn')
        N = self%geom%N
        self%fields(i)%gtype =  "v"
        self%fields(i)%Istr  =  self%geom%IstrR
        self%fields(i)%Iend  =  self%geom%IendR
        self%fields(i)%Jstr  =  self%geom%JstrV
        self%fields(i)%Jend  =  self%geom%JendR
        self%fields(i)%angle => self%geom%anglev
        self%fields(i)%lon   => self%geom%lonv
        self%fields(i)%lat   => self%geom%latv
        self%fields(i)%mask  => self%geom%vmask
      CASE ('ssh')
        N = 1
        self%fields(i)%gtype =  "r"
        self%fields(i)%Istr  =  self%geom%IstrR
        self%fields(i)%Iend  =  self%geom%IendR
        self%fields(i)%Jstr  =  self%geom%JstrR
        self%fields(i)%Jend  =  self%geom%JendR
        self%fields(i)%angle => self%geom%angler
        self%fields(i)%lon   => self%geom%lonr
        self%fields(i)%lat   => self%geom%latr
        self%fields(i)%mask  => self%geom%rmask
      CASE DEFAULT
        CALL abor1_ftn ('roms_fields::create(): unknown field '// &
                        self%fields(i)%name)
    END SELECT

    ! Allocate space
    
    self%fields(i)%N = N
    
    allocate ( self%fields(i)%val(LBi:UBi, LBj:UBj, N) )

    ! Set other variables associated with each field

    SELECT CASE (self%fields(i)%name)
      CASE ('tocn')
        self%fields(i)%cf_name = "sea_water_potential_temperature"
        self%fields(i)%io_file = "ocn"
        self%fields(i)%io_name = "temp"
        self%fields(i)%gtype   = "r"
      CASE ('socn')
        self%fields(i)%cf_name = "sea_water_practical_salinity"
        self%fields(i)%io_file = "ocn"
        self%fields(i)%io_name = "salt"
        self%fields(i)%gtype   = "r"
      CASE ('ssh')
        self%fields(i)%cf_name = "sea_surface_height"
        self%fields(i)%io_file = "ocn"
        self%fields(i)%io_name = "zeta"
      CASE ('uocn')
        self%fields(i)%cf_name = "sea_water_zonal_current"
        self%fields(i)%io_file = "ocn"
        self%fields(i)%io_name = "u"
        self%fields(i)%gtype   = "u"
      CASE ('vocn')
        self%fields(i)%cf_name = "sea_water_meridional_current"
        self%fields(i)%io_file = "ocn"
        self%fields(i)%io_name = "v"
      CASE DEFAULT
        self%fields(i)%cf_name = ""
        self%fields(i)%io_name = ""
        self%fields(i)%gtype   = "r"
    END SELECT

    IF (LdebugFields) THEN
      IF (self%geom%f_comm%rank() .eq. 0) THEN
        PRINT '(a,a4,a,3(i0,1x))', 'roms_fields::init_vars: allocated ', &
                                   TRIM(self%fields(i)%io_name), &
                                   ', SHAPE = ', SHAPE(self%fields(i)%val)
      END IF
    END IF

  END DO

END SUBROUTINE roms_fields_init_vars

! ------------------------------------------------------------------------------
!> Update the halo points for all the fields in the list

SUBROUTINE roms_fields_update_halos (self)

  CLASS (roms_fields), intent(inout) :: self

  integer                            :: i

  DO i = 1, SIZE(self%fields)
    CALL self%fields(i)%update_halo (self%geom)
  END DO

END SUBROUTINE roms_fields_update_halos

! ------------------------------------------------------------------------------
!> Initialize all fields with analytical functions

SUBROUTINE roms_fields_analytic (self)

  CLASS (roms_fields), intent(inout) :: self

  integer                            :: i, j, k, n
  real(kind=kind_real),      pointer :: f(:,:), h(:,:), z(:,:,:) 
  TYPE (roms_field),         pointer :: fld

  DO n = 1, SIZE(self%fields)

    fld => self%fields(n)

    SELECT CASE (fld%name)
      CASE ('tocn', 'socn', 'ssh')
        f => self%geom%f_r
        h => self%geom%h_r
        z => self%geom%z_r
      CASE ('uocn')
        f => self%geom%f_u
        h => self%geom%h_u
        z => self%geom%z_u
      CASE ('vocn')
        f => self%geom%f_v
        h => self%geom%h_v
        z => self%geom%z_v
      CASE DEFAULT
        CALL abor1_ftn ('roms_fields::analytic(): unknown field: '//fld%name)
    END SELECT      

    DO k = 1, fld%N
      DO j = fld%Jstr, fld%Jend
        DO i = fld%Istr, fld%Iend
          CALL ana_fields (fld%name,       &
                           fld%mask(i,j),  &
                           fld%lon(i,j),   &
                           fld%lat(i,j),   &
                           z(i,j,k),       &
                           f(i,j),         &
                           h(i,j),         &
                           fld%val(i,j,k))
        END DO
      END DO
    END DO

  END DO

END SUBROUTINE roms_fields_analytic

! ------------------------------------------------------------------------------
!> Set all fields to unity

SUBROUTINE roms_fields_ones (self)

  CLASS (roms_fields), intent(inout) :: self

  integer                            :: i

  DO i = 1, SIZE(self%fields)
    self%fields(i)%val = 1.0_kind_real
  END DO

END SUBROUTINE roms_fields_ones

! ------------------------------------------------------------------------------
!> Set all fields to zero

SUBROUTINE roms_fields_zeros (self)

  CLASS (roms_fields), intent(inout) :: self

  integer                            :: i

  DO i = 1, SIZE(self%fields)
    self%fields(i)%val = 0.0_kind_real
  END DO

END SUBROUTINE roms_fields_zeros

! ------------------------------------------------------------------------------
!> Add two sets of fields together

SUBROUTINE roms_fields_add (self, rhs)

  CLASS (roms_fields), intent(inout) :: self
  CLASS (roms_fields), intent(   in) :: rhs

  integer                            :: i

  ! Make sure fields have the same name, size, and shape

  CALL self%check_congruent (rhs)

  ! Add SELF and RHS fields

  DO i = 1, SIZE(self%fields)
    self%fields(i)%val = self%fields(i)%val + rhs%fields(i)%val
  END DO

END SUBROUTINE roms_fields_add

! ------------------------------------------------------------------------------
!> Subtract two sets of fields

SUBROUTINE roms_fields_sub (self, rhs)

  CLASS (roms_fields), intent(inout) :: self
  CLASS (roms_fields), intent(   in) :: rhs

  integer                            :: i

  ! Make sure fields have the same name, size, and shape

  CALL self%check_congruent (rhs)

  ! Subtract RHS from SELF

  DO i = 1, SIZE(self%fields)
    self%fields(i)%val = self%fields(i)%val - rhs%fields(i)%val
  END DO

END SUBROUTINE roms_fields_sub

! ------------------------------------------------------------------------------
!> Multiply a set of fields by a constant

SUBROUTINE roms_fields_mul (self, c)

  CLASS (roms_fields), intent(inout) :: self
  real (kind=kind_real),  intent(in) :: c

  integer                            :: i

  DO i = 1, SIZE(self%fields)
    self%fields(i)%val = c * self%fields(i)%val
  END DO

  IF (LdebugFields .and. (self%geom%f_comm%rank() .eq. 0)) THEN
    PRINT '(a,f0.4)', 'roms_fields::mul: multiplication factor, c = ', c
  END IF

END SUBROUTINE roms_fields_mul

! ------------------------------------------------------------------------------
!> Add two fields (multiplying the rhs first by a constant)

SUBROUTINE roms_fields_axpy (self, c, rhs)

  CLASS (roms_fields),   intent(inout) :: self
  real (kind=kind_real), intent(   in) :: c
  CLASS (roms_fields),   intent(   in) :: rhs

  integer                              :: i
  TYPE (roms_field),           pointer :: f_rhs, f_lhs

  ! Make sure fields are correct shape

  CALL self%check_subset (rhs)

  DO i = 1, SIZE(self%fields)
    f_lhs => self%fields(i)
    IF (.not. rhs%has(f_lhs%name)) CYCLE
    CALL rhs%get (f_lhs%name, f_rhs)
    f_lhs%val = f_lhs%val + c * f_rhs%val
  END DO

END SUBROUTINE roms_fields_axpy

! ------------------------------------------------------------------------------
!> Calculate the global dot product of two sets of fields

SUBROUTINE roms_fields_dotprod (fld1, fld2, zprod)

  CLASS (roms_fields),    intent( in) :: fld1
  CLASS (roms_fields),    intent( in) :: fld2
  real (kind=kind_real),  intent(out) :: zprod

  integer                             :: i, j, k, n
  real (kind=kind_real)               :: my_zprod
  TYPE (roms_field),          pointer :: field1, field2

  ! Make sure fields have same name, size, and shape

  CALL fld1%check_congruent (fld2)

  ! Loop over (almost) all fields

  my_zprod = 0.0_kind_real

  DO n = 1, SIZE(fld1%fields)

    field1 => fld1%fields(n)
    field2 => fld2%fields(n)

    ! Add the given field to the dot product (only using computational points)

    DO j = fld1%geom%Jstr, fld1%geom%Jend
      DO i = fld1%geom%Istr, fld1%geom%Iend

        IF (associated(field1%mask)) THEN                    ! masking
          IF (field1%mask(i,j) < 1) CYCLE
        END IF

        DO k = 1, field1%N
          my_zprod = my_zprod + field1%val(i,j,k) * field2%val(i,j,k)
        END DO
      END DO
    END DO

  END DO

  ! Get global dot product

  CALL fld1%geom%f_comm%allreduce (my_zprod, zprod, fckit_mpi_sum())

END SUBROUTINE roms_fields_dotprod

! ------------------------------------------------------------------------------
!> Calculate global statistics for each field (min, max, average)

SUBROUTINE roms_fields_gpnorm (fld, nf, pstat)

  CLASS (roms_fields),   intent(   in) :: fld             !> Fields set
  integer,               intent(   in) :: nf
  real (kind=kind_real), intent(inout) :: pstat(3, nf)    !> [min, max, average]

  logical                              :: mask(fld%geom%Istr:fld%geom%Iend, &
                                               fld%geom%Jstr:fld%geom%Jend)
  integer                              :: Istr, Iend, Jstr, Jend, n
  real (kind=kind_real)                :: my_water_cells, water_cells
  real (kind=kind_real)                :: buffer(3)
  TYPE (roms_field),           pointer :: field

  ! Indices for computational domain (interior points excludid boundary values)

  Istr = fld%geom%Istr
  Iend = fld%geom%Iend
  Jstr = fld%geom%Jstr
  Jend = fld%geom%Jend

  ! Calculate global min, max, mean for each field
 
  DO n = 1, SIZE(fld%fields)

    CALL fld%get (fld%fields(n)%name, field)

    ! Get the mask and the total number of grid cells

    IF (.not. ASSOCIATED(field%mask)) THEN
      mask = .true.
    ELSE
      mask = field%mask(Istr:Iend,Jstr:Jend) > 0.0
    END IF
    my_water_cells = COUNT(mask)

    CALL fld%geom%f_comm%allreduce (my_water_cells, water_cells, &
                                    fckit_mpi_sum())

    ! Calculate global min/max/mean

    CALL field_info (field%val(Istr:Iend,Jstr:Jend,:), mask, buffer)

    CALL fld%geom%f_comm%allreduce (buffer(1), pstat(1,n), fckit_mpi_min())
    CALL fld%geom%f_comm%allreduce (buffer(2), pstat(2,n), fckit_mpi_max())
    CALL fld%geom%f_comm%allreduce (buffer(3), pstat(3,n), fckit_mpi_sum())
    pstat(3,n) = pstat(3,n) / water_cells

  END DO

END SUBROUTINE roms_fields_gpnorm

! ------------------------------------------------------------------------------
!> Interpolate from U- and V-points to RHO-points.

SUBROUTINE roms_fields_colocate (self, gtype)

  CLASS (roms_fields),    intent(inout) :: self
  character (len=1),      intent(   in) :: gtype   !< C-grid; 'r', 'u', or 'v'

  TYPE (roms_field),            pointer :: field
  TYPE (roms_interp_type)               :: interp
  real(kind=kind_real),     allocatable :: val(:,:,:)
  integer                               :: i

  ! Apply interpolation to all fields, when necessary

  DO i = 1, SIZE(self%fields)

    ! Avoid interpolation if the field is already colocateda at "gtype"

    IF (self%fields(i)%gtype == gtype) CYCLE

    field => self%fields(i)

    ! Initialize horizontal interpolation structure

    CALL roms_field_interp_initialize (self%geom, field, interp, gtype)

    ! Make a temporary copy of field

    IF (allocated(val)) deallocate (val)
    allocate ( val, MOLD=field%val )
    val = field%val

    ! Horizontally interpolate field level-by-level

    CALL self%fields(i)%stencil_interp (self%geom, interp, BilinearMethod)

    ! Update fields structure

    self%fields(i)%gtype = gtype
 
    SELECT CASE (gtype)
      CASE ('r')
        self%fields(i)%lon => self%geom%lonr
        self%fields(i)%lat => self%geom%latr
      CASE ('u')
        self%fields(i)%lon => self%geom%lonu
        self%fields(i)%lat => self%geom%latu
      CASE ('v')
        self%fields(i)%lon => self%geom%lonv
        self%fields(i)%lat => self%geom%latv
    END SELECT

    ! Dellocate ROMS interpolation structure

    CALL roms_interp_delete (interp)

  END DO

END SUBROUTINE roms_fields_colocate

! ------------------------------------------------------------------------------
!> Compute the number of elements of in the state vector including packed fields

SUBROUTINE roms_fields_serial_size (self, geom, vec_size)

  CLASS (roms_fields),   intent( in) :: self
  TYPE (roms_geom),      intent( in) :: geom
  integer,               intent(out) :: vec_size

  integer                            :: i

  ! Loop over fields

  vec_size = 0
  DO i = 1, SIZE(self%fields)
    vec_size = vec_size + SIZE(self%fields(i)%val)
  END DO

END SUBROUTINE roms_fields_serial_size

! ------------------------------------------------------------------------------
!> Pack all fields into state vector

SUBROUTINE roms_fields_serialize (self, geom, vec_size, vec)

  CLASS (roms_fields),    intent( in) :: self
  TYPE (roms_geom),       intent( in) :: geom
  integer,                intent( in) :: vec_size      ! state vector length
  real (kind=kind_real),  intent(out) :: vec(vec_size) ! state vector

  integer                             :: i, ic, np

  ! Loop over fields, levels and horizontal points

  ic = 1
  DO i = 1, SIZE(self%fields)
    np = SIZE(self%fields(i)%val)
    vec(ic:ic+np-1) = RESHAPE(self%fields(i)%val, (/np/))
    ic = ic + np
  END DO

END SUBROUTINE roms_fields_serialize

! ------------------------------------------------------------------------------
!> Unpack all fields from state vector

SUBROUTINE roms_fields_deserialize (self, geom, vec_size, vec, ic)

  CLASS (roms_fields),   intent(inout) :: self
  TYPE (roms_geom),      intent(   in) :: geom
  integer,               intent(   in) :: vec_size      !< state vector length
  real (kind=kind_real), intent(   in) :: vec(vec_size) !< state vector
  integer,               intent(inout) :: ic            !< unpack vector length

  integer                              :: i, np

  ! Loop over fields, levels and horizontal points

  DO i = 1, SIZE(self%fields)
    np = SIZE(self%fields(i)%val)
    self%fields(i)%val = RESHAPE(vec(ic+1:ic+1+np), SHAPE(self%fields(i)%val))
    ic = ic + np
  END DO

END SUBROUTINE roms_fields_deserialize

! ------------------------------------------------------------------------------
!> Analytical initialization of fields

SUBROUTINE roms_fields_analytic_init (fld, f_conf, vdate)

  CLASS (roms_fields),        intent(inout) :: fld     !< Fields set
  TYPE (fckit_configuration), intent(   in) :: f_conf  !< FCKIT configuration
  TYPE (datetime),            intent(inout) :: vdate   !< Date and Time

  character (len=20)                        :: sdate
  character (len=30)                        :: ana_config
  character (len=: ), allocatable           :: string

  ! Report configuration

  IF (f_conf%has("analytic_field")) THEN
    CALL f_conf%get_or_die ("analytic_field",string)
    ana_config = string
  ELSE
    ana_config = 'uniform_field'
  END IF
  CALL fckit_log%warning ('roms_fields_analytic: '//TRIM(ana_config))

  ! Set date and time

    CALL f_conf%get_or_die ("date", string)
    sdate = string
    CALL fckit_log%info ('roms_fields_analytic: validity date is '//sdate)
    CALL datetime_set (sdate, vdate)

  ! Define state fields

  SELECT CASE (TRIM(ana_config))
    CASE ('analytic_field')
      CALL fld%analytic ()
    CASE ('uniform_field')
      CALL fld%zeros ()
    CASE DEFAULT
      CALL abor1_ftn ('roms_fields_analytic: unknown analytical initialization')
  END SELECT

END SUBROUTINE roms_fields_analytic_init

! ------------------------------------------------------------------------------
!> Reads fields from NetCDF file

SUBROUTINE roms_fields_read (fld, f_conf, vdate)

  USE mod_ncparam,    ONLY : inp_lib, io_nf90, io_pio

  CLASS (roms_fields),        intent(inout) :: fld     !< Fields set
  TYPE (fckit_configuration), intent(   in) :: f_conf  !< FCKIT configuration
  TYPE (datetime),            intent(inout) :: vdate   !< Date and Time

  integer                                   :: InpRec, iread
  character (len=:), allocatable            :: fields_dir, fields_filename,  &
                                               string
  character (len=256)                       :: ncname, text

  ! Get flag to read fields from NetCDF file or get values from analytical
  ! expressions from input configuration YAML file.

  IF (f_conf%has("read_from_file")) THEN
    CALL f_conf%get_or_die ("read_from_file", iread)
  ELSE
    iread = 0
  END IF

  ! Set fields date and time

  CALL f_conf%get_or_die ("date", string)
  CALL datetime_set (string, vdate)    

  ! If reading from file, get fields directory, filename, and time record to
  ! process from input configuration YAML file

  IF (iread .eq. 1) THEN
    IF (.not.f_conf%get("fields_dir", fields_dir)) THEN
      CALL abor1_ftn ("roms_fields::read: Cannot find fields directory")
    END IF

    IF (.not.f_conf%get("fields_filename", fields_filename)) THEN
      CALL abor1_ftn ("roms_fields::read: Cannot find fields input filename")
    END IF
    ncname = TRIM(fields_dir)//TRIM(fields_filename)

    IF (.not.f_conf%get("fields_record", InpRec)) THEN
      CALL abor1_ftn ("roms_fields::read: Cannot find fields record to process")
    END IF
  END IF

  ! Process required fields

  IF (iread .eq. 0) THEN         !< analytical initialization

    CALL fckit_log%warning ('roms_fields_read: inventing analytical fields')
    CALL fld%analytic ()

  ELSE                           !< read input NetCDF file

    SELECT CASE (inp_lib)

      CASE (io_nf90)
        CALL roms_fields_read_nf90 (fld, InpRec, ncname)

#if defined PIO_LIB
      CASE (io_pio)
        CALL roms_fields_read_pio (fld, InpRec, ncname)
#endif

      CASE DEFAULT
        WRITE (text,'(a,i0)') &
                    'roms_fields::read: Ilegal input type, io_type = ',      &
                    inp_lib
      CALL abor1_ftn (TRIM(text))

    END SELECT

  END IF

END SUBROUTINE roms_fields_read

! ------------------------------------------------------------------------------
!> Writes fields into output file using the standard NetCDF or PIO libraries

SUBROUTINE roms_fields_write (fld, f_conf, vdate)

  USE mod_param,       ONLY : Ngrids, T_IO
  USE mod_ncparam,     ONLY : io_nf90, io_pio

  CLASS (roms_fields),        intent(inout) :: fld     !< Fields set
  TYPE (fckit_configuration), intent(   in) :: f_conf  !< Configuration
  TYPE (datetime),            intent(inout) :: vdate   !< DateTime

  integer,                        parameter :: max_length = 800
  integer,                        parameter :: Nfiles = 1

  integer                                   :: LocalPET
  integer                                   :: model, ng
  real (kind=kind_real)                     :: time(Ngrids)
  character (len=256)                       :: text
  character(len=max_length)                 :: filename

  TYPE (T_IO), allocatable                  :: S(:)
 
  character (len=*), parameter              :: MyFile =                      &
     &  __FILE__//", roms_fields_write"

  ! Initialize

  LocalPET = fld%geom%f_comm%rank()    ! PET rank

  time  = 0.0_kind_real                ! ROMS time
  model = fld%geom%model               ! ROMS numerical kernel
  ng    = fld%geom%ng                  ! nested grid number

  ! Generate filename

  filename = roms_gen_filename(f_conf, max_length, vdate)

  ! Allocate and initialize ROMS T_IO type structure.

  CALL roms_IOstruct (ng, Nfiles, filename, S)

  ! Create fields output NetCDF

  CALL roms_create_ncfile (ng, model, LocalPET, S)

  IF (LocalPET .eq. 0) THEN
    PRINT '(3a)', "roms_fields::write: created NetCDF file: '",              &
                  TRIM(S(ng)%name), "'"
  END IF

  ! Set ROMS time from JEDI date in seconds since reference time.

  CALL roms_date2time (LocalPET, vdate, time(ng))

  ! Write out all fields using either the standard NetCDF library or the
  ! Parallel I/O (PIO) library.

  SELECT CASE (S(ng)%IOtype)

    CASE (io_nf90)
      CALL roms_fields_write_nf90 (fld, S, time)

#if defined PIO_LIB
    CASE (io_pio)
      CALL roms_fields_write_pio (fld, S, time)
#endif

    CASE DEFAULT
      WRITE (text,'(a,i0)') &
                  'roms_fields::write: Ilegal output type, io_type = ',      &
                  S(ng)%IOtype
      CALL abor1_ftn (TRIM(text))

  END SELECT

  ! Close NetCDF file.

  CALL roms_close_ncfile (ng, model, S)

  ! Deallocate IO structure

  CALL roms_IOstruct_delete (S)

END SUBROUTINE roms_fields_write

! ------------------------------------------------------------------------------
!> Read fields from input file using standard NetCDF library

SUBROUTINE roms_fields_read_nf90 (fld, InpRec, ncname)

  USE mod_ncparam,    ONLY : r2dvar, r3dvar, u3dvar, v3dvar, io_nf90
  USE mod_netcdf,     ONLY : netcdf_open, netcdf_close, netcdf_inq_var,      &
                             var_Dsize
  USE mod_scalars,    ONLY : NoError, exit_flag
  USE netcdf,         ONLY : nf90_noerr
  USE nf_fread2d_mod, ONLY : nf_fread2d
  USE nf_fread3d_mod, ONLY : nf_fread3d

  CLASS (roms_fields),        intent(inout) :: fld     !< Fields set
  integer,                    intent(in   ) :: InpRec  !< time record to read
  character (len=*),          intent(in   ) :: ncname  !< NetCDF filename

  integer                                   :: LocalPET, lstr, lend
  integer                                   :: i, model, ng, nvdims
  integer                                   :: ncid, varid
  integer                                   :: LBi, UBi, LBj, UBj, LBk, UBk
  integer                                   :: Im, Jm, Km, nx, ny, nz
  integer, dimension(4)                     :: Vsize
  real (kind=kind_real)                     :: Fmin, Fmax, scale
  character (len=256)                       :: text
  character (len=1024)                      :: Message

  character (len=*), parameter :: MyFile =                                   &
     &  __FILE__//", roms_fields_read_nf90"

  ! Initialize

  LocalPET = fld%geom%f_comm%rank()    !> PET rank

  model = fld%geom%model               !> numerical kernel
  ng    = MAX(1,fld%geom%ng)           !> nested grid number
  Im    = fld%geom%Lm                  !> number of global interior I-points
  Jm    = fld%geom%Mm                  !> number of global interior J-points
  Km    = fld%geom%N                   !> number of vertical levels
  scale = 1.0_kind_real
  Vsize = 0

  IF (LdebugFields .and. (LocalPET .eq. 0)) THEN
    lstr = SCAN(ncname, '/', BACK=.TRUE.) + 1
    lend = LEN_TRIM(ncname)    
    PRINT '(2a)', 'roms_fields::read_nf90 - reading state, File = ',         &
                 ncname(lstr:lend)
  END IF

  ! Open fields NetCDF file for reading

  CALL netcdf_open (ng, model, ncname, 0, ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  ! Read in all fields. ROMS needs to be compiled with MASKING to use the
  ! NetCDF reading functions below.

  DO i = 1, SIZE(fld%fields)

    LBi = LBOUND(fld%fields(i)%val, DIM=1)
    UBi = UBOUND(fld%fields(i)%val, DIM=1)
    LBj = LBOUND(fld%fields(i)%val, DIM=2)
    UBj = UBOUND(fld%fields(i)%val, DIM=2)
    LBk = LBOUND(fld%fields(i)%val, DIM=3)
    UBk = UBOUND(fld%fields(i)%val, DIM=3)

    fld%fields(i)%InpNCname = TRIM(ncname)
    fld%fields(i)%InpRec    = InpRec
    fld%fields(i)%InpNCid   = ncid

    ! Inquire variable about dimensions

    CALL netcdf_inq_var (ng, model, ncname,                                  &
                         ncid = ncid,                                        &
                         myVarName = fld%fields(i)%io_name,                  &
                         VarID = varid,                                      &
                         nVarDim = nvdims)
    IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))          &
      CALL abor1_ftn (TRIM(Message))

    nx = var_Dsize(1)
    ny = var_Dsize(2)
    nz = var_Dsize(3)

    SELECT CASE (fld%fields(i)%name)

      CASE ('ssh')                               !> free-surface

        IF ((nx.ne.Im+2).or.(ny.ne.Jm+2)) THEN
          IF (fld%geom%f_comm%rank() .eq. 0) THEN
            WRITE (text,'(a,2(1x,i0))')                                      &
                        'roms_fields::read: inconsitent dimensions for '//   &
                        TRIM(fld%fields(i)%io_name)//':', Im+2, Jm+2
            CALL fckit_log%error (TRIM(text))
            WRITE (text,'(a,2(1x,i0))')                                      &
                        'roms_fields::read: expected    dimensions for '//   &
                        TRIM(fld%fields(i)%io_name)//':', nx, ny 
            CALL fckit_log%error (TRIM(text))
          END IF
        END IF

        CALL nc_err (nf_fread2d(ng, model, ncname, ncid,                     &
                                fld%fields(i)%io_name,                       &
                                varid, InpRec, r2dvar, Vsize,                &
                                LBi, UBi, LBj, UBj,                          &
                                scale, Fmin, Fmax,                           &
                                fld%fields(i)%mask,                          &
                                fld%fields(i)%val(:,:,1)),                   &
                     nf90_noerr, io_nf90, __LINE__, MyFile)

        IF (LdebugFields .and. (LocalPET .eq. 0)) THEN
          PRINT 10, fld%fields(i)%name, Fmin, Fmax
        END IF

      CASE ('uocn')                              !> 3D U-momentum component

        IF ((nx.ne.Im+1).or.(ny.ne.Jm+2).or.(nz.ne.Km)) THEN
          IF (fld%geom%f_comm%rank() .eq. 0) THEN
            WRITE (text,'(a,3(1x,i0))')                                      &
                        'roms_fields::read: inconsitent dimensions for '//   &
                        TRIM(fld%fields(i)%io_name)//':', Im+1, Jm+2, Km
            CALL fckit_log%error (TRIM(text))
            WRITE (text,'(a,2(1x,i0))')                                      &
                        'roms_fields::read: expected    dimensions for '//   &
                        TRIM(fld%fields(i)%io_name)//':', nx, ny, nz
            CALL fckit_log%error (TRIM(text))
          END IF
        END IF

        CALL nc_err (nf_fread3d(ng, model, ncname, ncid,                     &
                                fld%fields(i)%io_name,                       &
                                varid, InpRec, u3dvar, Vsize,                &
                                LBi, UBi, LBj, UBj, LBk, UBk,                &
                                scale, Fmin, Fmax,                           &
                                fld%fields(i)%mask,                          &
                                fld%fields(i)%val),                          &
                     nf90_noerr, io_nf90, __LINE__, MyFile)

        IF (LdebugFields .and. (LocalPET .eq. 0)) THEN
          PRINT 10, fld%fields(i)%name, Fmin, Fmax
        END IF

      CASE ('vocn')                              !> 3D V-momentum component

        IF ((nx.ne.Im+2).or.(ny.ne.Jm+1).or.(nz.ne.Km)) THEN
          IF (fld%geom%f_comm%rank() .eq. 0) THEN
            WRITE (text,'(a,3(1x,i0))')                                      &
                        'roms_fields::read: inconsitent dimensions for '//   &
                        TRIM(fld%fields(i)%io_name)//':', Im+2, Jm+1, Km
            CALL fckit_log%error (TRIM(text))
            WRITE (text,'(a,2(1x,i0))')                                      &
                        'roms_fields::read: expected    dimensions for '//   &
                        TRIM(fld%fields(i)%io_name)//':', nx, ny, nz
            CALL fckit_log%error (TRIM(text))
          END IF
        END IF

        CALL nc_err (nf_fread3d(ng, model, ncname, ncid,                     &
                                fld%fields(i)%io_name,                       &
                                varid, InpRec, v3dvar, Vsize,                &
                                LBi, UBi, LBj, UBj, LBk, UBk,                &
                                scale, Fmin, Fmax,                           &
                                fld%fields(i)%mask,                          &
                                fld%fields(i)%val),                          &
                     nf90_noerr, io_nf90, __LINE__, MyFile)

        IF (LdebugFields .and. (LocalPET .eq. 0)) THEN
          PRINT 10, fld%fields(i)%name, Fmin, Fmax
        END IF

      CASE ('tocn', 'socn')                    !> temperature or salinity

        IF ((nx.ne.Im+2).or.(ny.ne.Jm+2).or.(nz.ne.Km)) THEN
          IF (fld%geom%f_comm%rank() .eq. 0) THEN
            WRITE (text,'(a,3(1x,i0))')                                      &
                        'roms_fields::read: inconsitent dimensions for '//   &
                        TRIM(fld%fields(i)%io_name)//':', Im+2, Jm+2, Km
            CALL fckit_log%error (TRIM(text))
            WRITE (text,'(a,2(1x,i0))')                                      &
                        'roms_fields::read: expected    dimensions for '//   &
                        TRIM(fld%fields(i)%io_name)//':', nx, ny, nz
            CALL fckit_log%error (TRIM(text))
          END IF
        END IF

        CALL nc_err (nf_fread3d(ng, model, ncname, ncid,                     &
                                fld%fields(i)%io_name,                       &
                                varid, InpRec, r3dvar, Vsize,                &
                                LBi, UBi, LBj, UBj, LBk, UBk,                &
                                scale, Fmin, Fmax,                           &
                                fld%fields(i)%mask,                          &
                                fld%fields(i)%val),                          &
                     nf90_noerr, io_nf90, __LINE__, MyFile)

        IF (LdebugFields .and. (LocalPET .eq. 0)) THEN
          PRINT 10, fld%fields(i)%name, Fmin, Fmax
        END IF

      CASE DEFAULT
  
        WRITE (Message,'(4a)')                                               &
              'roms_fields::write_nf90: Cannot find and option to read = ',  &
              fld%fields(i)%name, " - ", fld%fields(i)%cf_name
        CALL abor1_ftn (TRIM(Message))

    END SELECT

    IF (.FALSE. .and. (LocalPET .eq. 0)) THEN
      PRINT '(a)',           '------------------'
      PRINT '(2(a,i0))',     'ng     = ', ng, ', tile = ' , LocalPET
      PRINT '(2(a,i0),a,a)', 'ncid   = ', ncid, ', varid  = ', varid,        &
                             ', ncname = ', TRIM(ncname)
      PRINT '(6a)',          'field  = ', TRIM(fld%fields(i)%io_name),       &
                             ' :: ', TRIM(fld%fields(i)%name),               &
                             ' :: ', TRIM(fld%fields(i)%cf_name)
      PRINT '(a,3(i0,1x))',  'shape  = ', SHAPE(fld%fields(i)%val)
      PRINT '(a,6(i0,1x))',  'bounds = ', LBi, UBi, LBj, UBj, LBk, UBk
    END IF

    CALL fld%fields(i)%update_halo (fld%geom)

  END DO

  ! Close NetCDF file

  CALL netcdf_close (ng, model, ncid, ncname, .FALSE.)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  10 FORMAT (2x,'- ',a,':',t13,'Min = ',1p,e15.8,',  Max = ',1p,e15.8)

END SUBROUTINE roms_fields_read_nf90

! ------------------------------------------------------------------------------
!> Writes fields into output file using standard NetCDF library

SUBROUTINE roms_fields_write_nf90 (fld, S, time)

  USE mod_ncparam
  USE mod_param,       ONLY : T_IO
  USE mod_netcdf,      ONLY : netcdf_put_fvar, netcdf_sync
  USE mod_scalars,     ONLY : NoError, exit_flag
  USE netcdf,          ONLY : nf90_noerr
  USE nf_fwrite2d_mod, ONLY : nf_fwrite2d
  USE nf_fwrite3d_mod, ONLY : nf_fwrite3d

  CLASS (roms_fields),   intent(inout) :: fld      !< Fields set
  TYPE (T_IO),           intent(inout) :: S(:)     !< ROMS I/O structure
  real (kind=kind_real)                :: time(:)  !< ROMS time (seconds)

  integer                              :: Fcount, LocalPET, lstr, lend
  integer                              :: i, model, ng
  integer                              :: LBi, UBi, LBj, UBj, LBk, UBk
  real (kind=kind_real)                :: Fmin, Fmax, scale
  character (len=1024)                 :: Message

  character (len=*), parameter         :: MyFile =                           &
     &  __FILE__//", roms_fields_write_nf90"

  ! Initialize

  LocalPET = fld%geom%f_comm%rank()    !> PET rank

  model = fld%geom%model               !> ROMS numerical kernel
  ng    = fld%geom%ng                  !> nested grid number

  LBi = fld%geom%LBi
  UBi = fld%geom%UBi
  LBj = fld%geom%LBj
  UBj = fld%geom%UBj
  LBk = fld%geom%LBk
  UBk = fld%geom%UBk

  IF (LdebugFields .and. (LocalPET .eq. 0)) THEN
    lstr = SCAN(S(ng)%name, '/', BACK=.TRUE.) + 1
    lend = LEN_TRIM(S(ng)%name)    
    PRINT '(2a)', 'roms_fields::write_nf90 - writing state, File = ',        &
                  S(ng)%name(lstr:lend)
  END IF

  ! Set writing parameters

  scale  = 1.0_kind_real                    !> field scale
  S(ng)%Rindex = S(ng)%Rindex + 1           !> NetCDF time record
  Fcount=S(ng)%load                         !> filename load counter
  S(ng)%Nrec(Fcount)=S(ng)%Nrec(Fcount)+1   !> record counter per multi-file

  ! Write out ROMS time variable.

  CALL netcdf_put_fvar (ng, model, S(ng)%name, TRIM(Vname(1,idtime)),        &
                        time(ng:), (/S(ng)%Rindex/), (/1/),                  &
                        ncid = S(ng)%ncid,                                   &
                        varid = S(ng)%Vid(idtime))
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  ! Write out all fields. ROMS needs to be compiled with MASKING to use the
  ! writing NetCDF functions below.

  DO i = 1, SIZE(fld%fields)

    fld%fields(i)%OutNCname = TRIM(S(ng)%name)
    fld%fields(i)%OutNCid   = S(ng)%ncid
    fld%fields(i)%OutRec    = S(ng)%Rindex

    SELECT CASE (fld%fields(i)%name)

      CASE ('ssh')                             !> free-surface

        CALL nc_err (nf_fwrite2d(ng, model, S(ng)%ncid, S(ng)%Vid(idFsur),   &
                                 S(ng)%Rindex, r2dvar,                       &
                                 LBi, UBi, LBj, UBj, scale,                  &
                                 fld%fields(i)%mask,                         &
                                 fld%fields(i)%val(:,:,1),                   &
                                 MinValue = Fmin,                            &
                                 MaxValue = Fmax),                           &
                     nf90_noerr, io_nf90, __LINE__, MyFile)

        IF (LdebugFields .and. (LocalPET .eq. 0)) THEN
          PRINT 10, fld%fields(i)%name, Fmin, Fmax
        END IF

      CASE ('uocn')                            !> 3D U-momentum component

        CALL nc_err (nf_fwrite3d(ng, model, S(ng)%ncid, S(ng)%Vid(idUvel),   &
                                 S(ng)%Rindex, u3dvar,                       &
                                 LBi, UBi, LBj, UBj, LBk, UBk, scale,        &
                                 fld%fields(i)%mask,                         &
                                 fld%fields(i)%val,                          &
                                 MinValue = Fmin,                            &
                                 MaxValue = Fmax),                           &
                     nf90_noerr, io_nf90, __LINE__, MyFile)

        IF (LdebugFields .and. (LocalPET .eq. 0)) THEN
          PRINT 10, fld%fields(i)%name, Fmin, Fmax
        END IF

      CASE ('vocn')                            !> 3D V-momentum component

        CALL nc_err (nf_fwrite3d(ng, model, S(ng)%ncid, S(ng)%Vid(idVvel),   &
                                 S(ng)%Rindex, v3dvar,                       &
                                 LBi, UBi, LBj, UBj, LBk, UBk, scale,        &
                                 fld%fields(i)%mask,                         &
                                 fld%fields(i)%val,                          &
                                 MinValue = Fmin,                            &
                                 MaxValue = Fmax),                           &
                     nf90_noerr, io_nf90, __LINE__, MyFile)

        IF (LdebugFields .and. (LocalPET .eq. 0)) THEN
          PRINT 10, fld%fields(i)%name, Fmin, Fmax
        END IF

      CASE ('tocn')                            !> potential temperature

        CALL nc_err (nf_fwrite3d(ng, model, S(ng)%ncid, S(ng)%Tid(itemp),    &
                                 S(ng)%Rindex, r3dvar,                       &
                                 LBi, UBi, LBj, UBj, LBk, UBk, scale,        &
                                 fld%fields(i)%mask,                         &
                                 fld%fields(i)%val,                          &
                                 MinValue = Fmin,                            &
                                 MaxValue = Fmax),                           &
                     nf90_noerr, io_nf90, __LINE__, MyFile)

        IF (LdebugFields .and. (LocalPET .eq. 0)) THEN
          PRINT 10, fld%fields(i)%name, Fmin, Fmax
        END IF

      CASE ('socn')                            !> salinity

        CALL nc_err (nf_fwrite3d(ng, model, S(ng)%ncid, S(ng)%Tid(isalt),    &
                                 S(ng)%Rindex, r3dvar,                       &
                                 LBi, UBi, LBj, UBj, LBk, UBk, scale,        &
                                 fld%fields(i)%mask,                         &
                                 fld%fields(i)%val,                          &
                                 MinValue = Fmin,                            &
                                 MaxValue = Fmax),                           &
                     nf90_noerr, io_nf90, __LINE__, MyFile)

        IF (LdebugFields .and. (LocalPET .eq. 0)) THEN
          PRINT 10, fld%fields(i)%name, Fmin, Fmax
        END IF

      CASE DEFAULT
  
        WRITE (Message,'(4a)')                                               &
              'roms_fields::write_pio: Cannot find and option to write = ',  &
              fld%fields(i)%name, " - ", fld%fields(i)%cf_name
        CALL abor1_ftn (TRIM(Message))

    END SELECT
    
  END DO

  ! Synchronize NetCDF to disk.

  CALL netcdf_sync (ng, model, S(ng)%name, S(ng)%ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  10 FORMAT (2x,'- ',a,':',t13,'Min = ',1p,e15.8,',  Max = ',1p,e15.8)

END SUBROUTINE roms_fields_write_nf90

#if defined PIO_LIB

! ------------------------------------------------------------------------------
!> Read fields from input file using the Parallel I/O (PIO) library

SUBROUTINE roms_fields_read_pio (fld, InpRec, ncname)

  USE mod_ncparam,    ONLY : r2dvar, r3dvar, u3dvar, v3dvar, io_pio
  USE mod_netcdf,     ONLY : var_Dsize
  USE mod_pio_netcdf, ONLY : pio_netcdf_open, pio_netcdf_close,              &
                             pio_netcdf_inq_var
  USE mod_scalars,    ONLY : NoError, exit_flag
  USE nf_fread2d_mod, ONLY : nf_fread2d
  USE nf_fread3d_mod, ONLY : nf_fread3d

  CLASS (roms_fields),        intent(inout) :: fld     !< Fields set
  integer,                    intent(in   ) :: InpRec  !< time record to read
  character (len=*),          intent(in   ) :: ncname  !< NetCDF filename

  TYPE (IO_desc_t), pointer                 :: ioDesc
  TYPE (My_VarDesc)                         :: pioVar

  integer                                   :: LocalPET, lstr, lend
  integer                                   :: fld_kind, i, model, ng, nvdims
  integer                                   :: LBi, UBi, LBj, UBj, LBk, UBk
  integer                                   :: Im, Jm, Km, nx, ny, nz
  integer, dimension(4)                     :: Vsize
  real (kind=kind_real)                     :: Fmin, Fmax, scale
  character (len=256)                       :: text
  character (len=1024)                      :: Message

  character (len=*), parameter              :: MyFile =                      &
     &  __FILE__//", roms_fields_read_pio"

  ! Initialize

  LocalPET = fld%geom%f_comm%rank()    !> PET rank

 0 model = fld%geom%model              !> numerical kernel
  ng    = MAX(1,fld%geom%ng)           !> nested grid number
  Im    = fld%geom%Lm                  !> number of global interior I-points
  Jm    = fld%geom%Mm                  !> number of global interior J-points
  Km    = fld%geom%N                   !> number of vertical levels
  scale = 1.0_kind_real
  Vsize = 0

  IF (LdebugFields .and. (LocalPET .eq. 0)) THEN
    lstr = SCAN(ncname, '/', BACK=.TRUE.) + 1
    lend = LEN_TRIM(ncname)    
    PRINT '(2a)', 'roms_fields::read_nf90 - reading state, File = ',         &
                 ncname(lstr:lend)
  END IF

  ! Open fields NetCDF file for reading

  CALL pio_netcdf_open (ng, model, ncname, 0, pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  ! Read in all fields. ROMS needs to be compiled with MASKING to use the
  ! NetCDF reading functions below.

  DO i = 1, SIZE(fld%fields)

    LBi = LBOUND(fld%fields(i)%val, DIM=1)
    UBi = UBOUND(fld%fields(i)%val, DIM=1)
    LBj = LBOUND(fld%fields(i)%val, DIM=2)
    UBj = UBOUND(fld%fields(i)%val, DIM=2)
    LBk = LBOUND(fld%fields(i)%val, DIM=3)
    UBk = UBOUND(fld%fields(i)%val, DIM=3)

    fld%fields(i)%InpNCname = TRIM(ncname)
    fld%fields(i)%InpRec    = InpRec
    fld%fields(i)%InpNCid   = pioFile%fh

    fld_kind = KIND(fld%fields(i)%val)

    ! Inquire variable about dimensions

    CALL pio_netcdf_inq_var (ng, model, ncname,                              &
                             piofile = pioFile,                              &
                             myVarName = fld%fields(i)%io_name,              &
                             pioVar = pioVar,                                &
                             nVarDim = nvdims)
    IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))          &
      CALL abor1_ftn (TRIM(Message))

    nx = var_Dsize(1)
    ny = var_Dsize(2)
    nz = var_Dsize(3)

    SELECT CASE (fld%fields(i)%name)

      CASE ('ssh')                               !> free-surface

        IF ((nx.ne.Im+2).or.(ny.ne.Jm+2)) THEN
          IF (fld%geom%f_comm%rank() .eq. 0) THEN
            WRITE (text,'(a,2(1x,i0))')                                      &
                        'roms_fields::read: inconsitent dimensions for '//   &
                        TRIM(fld%fields(i)%io_name)//':', Im+2, Jm+2
            CALL fckit_log%error (TRIM(text))
            WRITE (text,'(a,2(1x,i0))')                                      &
                        'roms_fields::read: expected    dimensions for '//   &
                        TRIM(fld%fields(i)%io_name)//':', nx, ny 
            CALL fckit_log%error (TRIM(text))
          END IF
        END IF

        pioVar%gtype=r2dvar
        IF (fld_kind.eq.8) THEN
          pioVar%dkind=PIO_double
          ioDesc => ioDesc_dp_r2dvar(ng)
        ELSE
          pioVar%dkind=PIO_real
          ioDesc => ioDesc_sp_r2dvar(ng)
        END IF
        CALL nc_err (nf_fread2d(ng, model, ncname, pioFile,                  &
                                fld%fields(i)%io_name,                       &
                                pioVar, InpRec, ioDesc, Vsize,               &
                                LBi, UBi, LBj, UBj,                          &
                                scale, Fmin, Fmax,                           &
                                fld%fields(i)%mask,                          &
                                fld%fields(i)%val(:,:,1)),                   &
                     PIO_noerr, io_pio, __LINE__, MyFile)

        IF (LdebugFields .and. (LocalPET .eq. 0)) THEN
          PRINT 10, fld%fields(i)%name, Fmin, Fmax
        END IF

      CASE ('uocn')                              !> 3D U-momentum component

        IF ((nx.ne.Im+1).or.(ny.ne.Jm+2).or.(nz.ne.Km)) THEN
          IF (fld%geom%f_comm%rank() .eq. 0) THEN
            WRITE (text,'(a,3(1x,i0))')                                      &
                        'roms_fields::read: inconsitent dimensions for '//   &
                        TRIM(fld%fields(i)%io_name)//':', Im+1, Jm+2, Km
            CALL fckit_log%error (TRIM(text))
            WRITE (text,'(a,2(1x,i0))')                                      &
                        'roms_fields::read: expected    dimensions for '//   &
                        TRIM(fld%fields(i)%io_name)//':', nx, ny, nz
            CALL fckit_log%error (TRIM(text))
          END IF
        END IF

        pioVar%gtype=u3dvar
        IF (fld_kind.eq.8) THEN
          pioVar%dkind=PIO_double
          ioDesc => ioDesc_dp_u3dvar(ng)
        ELSE
          pioVar%dkind=PIO_real
          ioDesc => ioDesc_sp_u3dvar(ng)
        END IF
        CALL nc_err (nf_fread3d(ng, model, ncname, pioFile,                  &
                                fld%fields(i)%io_name,                       &
                                pioVar, InpRec, ioDesc, Vsize,               &
                                LBi, UBi, LBj, UBj, LBk, UBk,                &
                                scale, Fmin, Fmax,                           &
                                fld%fields(i)%mask,                          &
                                fld%fields(i)%val),                          &
                     PIO_noerr, io_pio, __LINE__, MyFile)

        IF (LdebugFields .and. (LocalPET .eq. 0)) THEN
          PRINT 10, fld%fields(i)%name, Fmin, Fmax
        END IF

      CASE ('vocn')                              !> 3D V-momentum component

        IF ((nx.ne.Im+2).or.(ny.ne.Jm+1).or.(nz.ne.Km)) THEN
          IF (fld%geom%f_comm%rank() .eq. 0) THEN
            WRITE (text,'(a,3(1x,i0))')                                      &
                        'roms_fields::read: inconsitent dimensions for '//   &
                        TRIM(fld%fields(i)%io_name)//':', Im+2, Jm+1, Km
            CALL fckit_log%error (TRIM(text))
            WRITE (text,'(a,2(1x,i0))')                                      &
                        'roms_fields::read: expected    dimensions for '//   &
                        TRIM(fld%fields(i)%io_name)//':', nx, ny, nz
            CALL fckit_log%error (TRIM(text))
          END IF
        END IF

        pioVar%gtype=v3dvar
        IF (fld_kind.eq.8) THEN
          pioVar%dkind=PIO_double
          ioDesc => ioDesc_dp_v3dvar(ng)
        ELSE
          pioVar%dkind=PIO_real
          ioDesc => ioDesc_sp_v3dvar(ng)
        END IF
        CALL nc_err (nf_fread3d(ng, model, ncname, pioVar,                   &
                                fld%fields(i)%io_name,                       &
                                pioVar, InpRec, ioDesc, Vsize,               &
                                LBi, UBi, LBj, UBj, LBk, UBk,                &
                                scale, Fmin, Fmax,                           &
                                fld%fields(i)%mask,                          &
                                fld%fields(i)%val),                          &
                     PIO_noerr, io_pio, __LINE__, MyFile)

        IF (LdebugFields .and. (LocalPET .eq. 0)) THEN
          PRINT 10, fld%fields(i)%name, Fmin, Fmax
        END IF

      CASE ('tocn', 'socn')                    !> temperature or salinity

        IF ((nx.ne.Im+2).or.(ny.ne.Jm+2).or.(nz.ne.Km)) THEN
          IF (fld%geom%f_comm%rank() .eq. 0) THEN
            WRITE (text,'(a,3(1x,i0))')                                      &
                        'roms_fields::read: inconsitent dimensions for '//   &
                        TRIM(fld%fields(i)%io_name)//':', Im+2, Jm+2, Km
            CALL fckit_log%error (TRIM(text))
            WRITE (text,'(a,2(1x,i0))')                                      &
                        'roms_fields::read: expected    dimensions for '//   &
                        TRIM(fld%fields(i)%io_name)//':', nx, ny, nz
            CALL fckit_log%error (TRIM(text))
          END IF
        END IF

        pioVar%gtype=r3dvar
        IF (fld_kind.eq.8) THEN
          pioVar%dkind=PIO_double
          ioDesc => ioDesc_dp_r3dvar(ng)
        ELSE
          pioVar%dkind=PIO_real
          ioDesc => ioDesc_sp_r3dvar(ng)
        END IF
        CALL nc_err (nf_fread3d(ng, model, ncname, pioFile,                  &
                                fld%fields(i)%io_name,                       &
                                pioVar, InpRec, ioDesc, Vsize,               &
                                LBi, UBi, LBj, UBj, LBk, UBk,                &
                                scale, Fmin, Fmax,                           &
                                fld%fields(i)%mask,                          &
                                fld%fields(i)%val),                          &
                     PIO_noerr, io_pio, __LINE__, MyFile)

        IF (LdebugFields .and. (LocalPET .eq. 0)) THEN
          PRINT 10, fld%fields(i)%name, Fmin, Fmax
        END IF

      CASE DEFAULT
  
        WRITE (Message,'(4a)')                                               &
              'roms_fields::write_nf90: Cannot find and option to read = ',  &
              fld%fields(i)%name, " - ", fld%fields(i)%cf_name
        CALL abor1_ftn (TRIM(Message))

    END SELECT

    IF (.FALSE. .and. (LocalPET .eq. 0)) THEN
      PRINT '(a)',           '------------------'
      PRINT '(2(a,i0))',     'ng     = ', ng, ', tile = ' , LocalPET
      PRINT '(2(a,i0),a,a)', 'ncid   = ', ncid, ', varid  = ', varid,        &
                             ', ncname = ', TRIM(ncname)
      PRINT '(6a)',          'field  = ', TRIM(fld%fields(i)%io_name),       &
                             ' :: ', TRIM(fld%fields(i)%name),               &
                             ' :: ', TRIM(fld%fields(i)%cf_name)
      PRINT '(a,3(i0,1x))',  'shape  = ', SHAPE(fld%fields(i)%val)
      PRINT '(a,6(i0,1x))',  'bounds = ', LBi, UBi, LBj, UBj, LBk, UBk
    END IF

    CALL fld%fields(i)%update_halo (fld%geom)

  END DO

  ! Close NetCDF file

  CALL pio_netcdf_close (ng, model, pioFile, ncname, .FALSE.)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  10 FORMAT (2x,'- ',a,':',t13,'Min = ',1p,e15.8,',  Max = ',1p,e15.8)

END SUBROUTINE roms_fields_read_pio

! ------------------------------------------------------------------------------
!> Writes fields into output file using Paralell I/O (PIO) library

SUBROUTINE roms_fields_write_pio (fld, S, time)

  USE mod_ncparam
  USE mod_param,       ONLY : T_IO
  USE mod_pio_netcdf,  ONLY : pio_netcdf_put_fvar, pio_netcdf_sync
  USE mod_scalars,     ONLY : NoError, exit_flag
  USE netcdf,          ONLY : nf90_noerr
  USE nf_fwrite2d_mod, ONLY : nf_fwrite2d
  USE nf_fwrite3d_mod, ONLY : nf_fwrite3d

  CLASS (roms_fields),   intent(inout) :: fld      !< Fields set
  TYPE (T_IO),           intent(inout) :: S(:)     !< ROMS I/O structure
  real (kind=kind_real)                :: time(:)  !< ROMS time (seconds)

  integer                              :: Fcount, LocalPET, lstr, lend
  integer                              :: i, model, ng
  integer                              :: LBi, UBi, LBj, UBj, LBk, UBk
  real (kind=kind_real)                :: Fmin, Fmax, scale
  character (len=1024)                 :: Message

  TYPE (IO_desc_t), pointer            :: ioDesc

  character (len=*), parameter         :: MyFile =                           &
     &  __FILE__//", roms_fields_write_pio"

  ! Initialize

  LocalPET = fld%geom%f_comm%rank()    !> PET rank

  model = fld%geom%model               !> ROMS numerical kernel
  ng    = fld%geom%ng                  !> nested grid number

  LBi = fld%geom%LBi
  UBi = fld%geom%UBi
  LBj = fld%geom%LBj
  UBj = fld%geom%UBj
  LBk = fld%geom%LBk
  UBk = fld%geom%UBk

  IF (LdebugFields .and. (LocalPET .eq. 0)) THEN
    lstr = SCAN(S(ng)%name, '/', BACK=.TRUE.) + 1
    lend = LEN_TRIM(S(ng)%name)    
    PRINT '(2a)', 'roms_fields::write_nf90 - writing state, File = ',        &
                  S(ng)%name(lstr:lend)
  END IF

  ! Set writing parameters

  scale  = 1.0_kind_real                    !> field scale
  S(ng)%Rindex = S(ng)%Rindex + 1           !> NetCDF time record
  Fcount=S(ng)%load                         !> filename load counter
  S(ng)%Nrec(Fcount)=S(ng)%Nrec(Fcount)+1   !> record counter per multi-file

  ! Write out ROMS time variable.

  CALL pio_netcdf_put_fvar (ng, model, S(ng)%name, TRIM(Vname(1,idtime)),    &
                            time(ng:), (/S(ng)%Rindex/), (/1/),              &
                            pioFile = S(ng)pioFile,                          &
                            pioVar = S(ng)%pioVar(idtime)%vd)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  ! Write out all fields. ROMS needs to be compiled with MASKING to use the
  ! writing NetCDF functions below.

  DO i = 1, SIZE(fld%fields)

    fld%fields(i)%OutNCname = TRIM(S(ng)%name)
    fld%fields(i)%OutNCid   = S(ng)%pioFile%fh
    fld%fields(i)%OutRec    = S(ng)%Rindex

    SELECT CASE (fld%fields(i)%name)

      CASE ('ssh')                             !> free-surface

        IF (S(ng)%pioVar(idFsur)%dkind.eq.PIO_double) THEN
          ioDesc => ioDesc_dp_r2dvar(ng)
        ELSE
          ioDesc => ioDesc_sp_r2dvar(ng)
        END IF
        CALL nc_err (nf_fwrite2d(ng, model, S(ng)%pioFile,                   &
                                 S(ng)%pioVar(idFsur),                       &
                                 S(ng)%Rindex, ioDesc,                       &
                                 LBi, UBi, LBj, UBj, scale,                  &
                                 fld%fields(i)%mask,                         &
                                 fld%fields(i)%val(:,:,1),                   &
                                 MinValue = Fmin,                            &
                                 MaxValue = Fmax),                           &
                     PIO_noerr, io_pio, __LINE__, MyFile)

        IF (LdebugFields .and. (LocalPET .eq. 0)) THEN
          PRINT 10, fld%fields(i)%name, Fmin, Fmax
        END IF

      CASE ('uocn')                            !> 3D U-momentum component

       IF (S(ng)%pioVar(idUvel)%dkind.eq.PIO_double) THEN
          ioDesc => ioDesc_dp_u3dvar(ng)
        ELSE
          ioDesc => ioDesc_sp_u3dvar(ng)
        END IF
        CALL nc_err (nf_fwrite3d(ng, model, S(ng)%pioFile,                   &
                                 S(ng)%pioVar(idUvel),                       &
                                 S(ng)%Rindex, ioDesc,                       &
                                 LBi, UBi, LBj, UBj, LBk, UBk, scale,        &
                                 fld%fields(i)%mask,                         &
                                 fld%fields(i)%val,                          &
                                 MinValue = Fmin,                            &
                                 MaxValue = Fmax),                           &
                     PIO_noerr, io_pio, __LINE__, MyFile)

        IF (LdebugFields .and. (LocalPET .eq. 0)) THEN
          PRINT 10, fld%fields(i)%name, Fmin, Fmax
        END IF

      CASE ('vocn')                            !> 3D V-momentum component

        IF (S(ng)%pioVar(idVvel)%dkind.eq.PIO_double) THEN
          ioDesc => ioDesc_dp_v3dvar(ng)
        ELSE
          ioDesc => ioDesc_sp_v3dvar(ng)
        END IF
        CALL nc_err (nf_fwrite3d(ng, model, S(ng)%ncid,                      &
                                 S(ng)%pioVar(idVvel),                       &
                                 S(ng)%Rindex, ioDesc,                       &
                                 LBi, UBi, LBj, UBj, LBk, UBk, scale,        &
                                 fld%fields(i)%mask,                         &
                                 fld%fields(i)%val,                          &
                                 MinValue = Fmin,                            &
                                 MaxValue = Fmax),                           &
                     PIO_noerr, io_pio, __LINE__, MyFile)

        IF (LdebugFields .and. (LocalPET .eq. 0)) THEN
          PRINT 10, fld%fields(i)%name, Fmin, Fmax
        END IF

      CASE ('tocn')                            !> potential temperature

        IF (S(ng)%pioTrc(itemp)%dkind.eq.PIO_double) THEN
          ioDesc => ioDesc_dp_r3dvar(ng)
        ELSE
          ioDesc => ioDesc_sp_r3dvar(ng)
        END IF
        CALL nc_err (nf_fwrite3d(ng, model, S(ng)%ncid,                      &
                                 S(ng)%pioTrc(itemp),                        &
                                 S(ng)%Rindex, ioDesc,                       &
                                 LBi, UBi, LBj, UBj, LBk, UBk, scale,        &
                                 fld%fields(i)%mask,                         &
                                 fld%fields(i)%val,                          &
                                 MinValue = Fmin,                            &
                                 MaxValue = Fmax),                           &
                     PIO_noerr, io_pio, __LINE__, MyFile)

        IF (LdebugFields .and. (LocalPET .eq. 0)) THEN
          PRINT 10, fld%fields(i)%name, Fmin, Fmax
        END IF

      CASE ('socn')                            !> salinity

        IF (S(ng)%pioTrc(isalt)%dkind.eq.PIO_double) THEN
          ioDesc => ioDesc_dp_r3dvar(ng)
        ELSE
          ioDesc => ioDesc_sp_r3dvar(ng)
        END IF
        CALL nc_err (nf_fwrite3d(ng, model, S(ng)%ncid,                      &
                                 S(ng)%pioTrc(isalt),                        &
                                 S(ng)%Rindex, ioDesc,                       &
                                 LBi, UBi, LBj, UBj, LBk, UBk, scale,        &
                                 fld%fields(i)%mask,                         &
                                 fld%fields(i)%val,                          &
                                 MinValue = Fmin,                            &
                                 MaxValue = Fmax),                           &
                     PIO_noerr, io_pio, __LINE__, MyFile)

        IF (LdebugFields .and. (LocalPET .eq. 0)) THEN
          PRINT 10, fld%fields(i)%name, Fmin, Fmax
        END IF

      CASE DEFAULT
  
        WRITE (Message,'(4a)')                                               &
              'roms_fields::write_pio: Cannot find and option to write = ',  &
              fld%fields(i)%name, " - ", fld%fields(i)%cf_name
        CALL abor1_ftn (TRIM(Message))

    END SELECT
    
  END DO

  ! Synchronize NetCDF to disk.

  CALL pio_netcdf_sync (ng, model, S(ng)%name, S(ng)%pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  10 FORMAT (2x,'- ',a,':',t13,'Min = ',1p,e15.8,',  Max = ',1p,e15.8)

END SUBROUTINE roms_fields_write_pio

#endif

! ------------------------------------------------------------------------------

END MODULE roms_fields_mod
