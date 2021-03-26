! (C) Copyright 2017-2020 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

!> Handle fields for the model

MODULE roms_fields_mod

USE fckit_configuration_module, ONLY : fckit_configuration
USE fckit_log_module,           ONLY : log, fckit_log
USE fckit_mpi_module,           ONLY : fckit_mpi_comm, &
                                       fckit_mpi_min, &
                                       fckit_mpi_max, &
                                       fckit_mpi_sum
USE datetime_mod,               ONLY : datetime, datetime_set
USE duration_mod,               ONLY : duration
USE kinds,                      ONLY : kind_real
USE oops_variables_mod
USE mpp_domains_mod,            ONLY : mpp_update_domains
USE roms_geom_mod,              ONLY : roms_geom
USE roms_fieldsutils_mod,       ONLY : roms_genfilename, &
                                       fldinfo
USE roms_utils,                 ONLY : roms_mld

USE horiz_interp_mod,           ONLY : horiz_interp_type
USE horiz_interp_spherical_mod, ONLY : horiz_interp_spherical, &
                                       horiz_interp_spherical_new, &
                                       horiz_interp_spherical_del
USE tools_const,                ONLY : deg2rad

implicit none

PRIVATE

PUBLIC  :: roms_field
PUBLIC  :: roms_fields

! ------------------------------------------------------------------------------
! ROMS FIELD Subroutines:
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
!> Structure holds all data and metadata related to a single field variable

TYPE :: roms_field

  integer                            :: N                    !< the number of levels
  integer                            :: InpNCid, OutNCid     !< input/output NetCDF file IDs
  integer                            :: InpRec, OutRec       !< input/output NetCDF records

  real (kind=kind_real), allocatable :: val(:,:,:)           !< field data
  real (kind=kind_real),     pointer :: mask(:,:) => null()  !< field mask
  real (kind=kind_real),     pointer :: lon(:,:)  => null()  !< field lon
  real (kind=kind_real),     pointer :: lat(:,:)  => null()  !< field lat

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
! ------------------------------------------------------------------------------

!> Structure to holds a collection of roms_field types, and the public suroutines
!> to manipulate them. Represents all the fields of a given state or increment

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
!> Copy a field from RHS to SELF. SELF must be allocated first. The pointers
!> (mask, lat, lon) will be different, but should NOT be changed to point to
!> RHS pointers. Bad things will happen.

SUBROUTINE roms_field_copy (self, rhs)

  CLASS (roms_field), intent(inout) :: self
  TYPE (roms_field),  intent(in)    :: rhs

  CALL self%check_congruent (rhs)

  ! The only variable that should be different is %val

  self%val = rhs%val

END SUBROUTINE roms_field_copy

! ------------------------------------------------------------------------------
!> Delete field object.

SUBROUTINE roms_field_delete (self)

  CLASS (roms_field), intent(inout) :: self

  deallocate (self%val)

END SUBROUTINE roms_field_delete

! ------------------------------------------------------------------------------
! Make sure the two fields are the same in terms of name, size, and shape.

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

  CLASS (roms_field),     intent(inout) :: self
  TYPE (roms_geom), pointer, intent(in) :: geom

  logical                               :: EWperiodic, NSperiodic
  integer                               :: ng, tile, NghostPoints
  integer                               :: LBi, UBi, LBj, UBj, LBk, UBk

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
                        & NghostPoints, EWperiodic, NWperiodic, self%val)
    CASE ('uocn', 'vocn', 'tocn', 'socn')
      CALL mp_exchange3d (ng, tile, 1, 1, LBi, UBi, LBj, UBj, LBk, UBk, &
                        & NghostPoints, EWperiodic, NSperiodic, self%val)
    CASE DEFAULT
      CALL abor1_ftn ('roms_field::update_halo: wrong SIZE(SHAPE(field))')
  END SELECT
    
END SUBROUTINE roms_field_update_halo

! ------------------------------------------------------------------------------
! Interpolate field

SUBROUTINE roms_field_stencil_interp (self, geom, interp2d)

  CLASS (roms_field),     intent(inout) :: self
  TYPE (roms_geom), pointer, intent(in) :: geom
  TYPE (horiz_interp_type),  intent(in) :: interp2d

  integer                              :: Isc, Iec, Jsc, Jec
  integer                              :: Isd, Ied, Jsd, Jed
  integer                              :: k
  real(kind=kind_real),    allocatable :: val(:,:,:)

  allocate (val, mold=self%val)

  Isc = geom%isc
  Iec = geom%iec
  Jsc = geom%jsc
  Jec = geom%jec

  Isd = geom%isd
  Ied = geom%ied
  Jsd = geom%jsd
  Jed = geom%jed

  val = self%val

  DO k = 1, self%nz
    CALL horiz_interp_spherical (interp2d, val(Is:Ie,Js:Je,k), self%val(Isc:Iec,Jsc:Jec,k))
  END DO

  CALL self%update_halo (geom)

END SUBROUTINE roms_field_stencil_interp

! ------------------------------------------------------------------------------
! ROMS FIELDS Subroutines:
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
!> Create a new set of fields, allocate space for them, and initialize to zero

SUBROUTINE roms_fields_create (self, geom, vars)

  CLASS (roms_fields),        intent(inout) :: self
  TYPE (roms_geom),  pointer, intent(inout) :: geom
  TYPE (oops_variables),      intent(inout) :: vars  !< field names list to create

  integer                                   :: i
  character(len=:), allocatable             :: vars_str(:)

  ! Make sure current object has not already been allocated

  IF (ASSOCIATED(self%fields)) THEN
    call abor1_ftn ("roms_fields::create(): object already allocated")
  END IF

  ! Associate geometry

  self%geom => geom

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

  CLASS (roms_fields),         intent(in) :: self
  character (len=*),           intent(in) :: name   !< name of field to find
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
!>
!> TODO: make this more robust (allow for different number of fields?)

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
      IF (SIZE(f1%fields(i)%val, dim=j) .ne. SIZE(f2%fields(i)%val, dim=j) ) THEN
        CALL abor1_ftn ("roms_fields: field '"//f1%fields(i)%name//"' has different dimensions")
      END IF
    END DO
  END DO

END SUBROUTINE roms_fields_check_congruent

! ------------------------------------------------------------------------------
!> Make sure two sets of fields have same shape for fields they have in common
!> f1 must be a subset of f2
!>
!> TODO: make this more robust (allow for different number of fields?)

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
        CALL abor1_ftn ("roms_fields: field '"//f1%fields(i)%name//"' has different dimensions")
      END IF
    END DO
  END DO

END SUBROUTINE roms_fields_check_subset

! ------------------------------------------------------------------------------
!> for a given list of field names, initialize the properties of those fields
! NOTE: this information should be moved into a yaml file
! TODO, allocate space for derived variables

SUBROUTINE roms_fields_init_vars (self, vars)

  CLASS (roms_fields),        intent(inout) :: self
  character(len=:), allocatable, intent(in) :: vars(:)

  integer                                   :: LBi, UBi, LBj, UBj, N
  integer                                   :: i

  LBi = self%geom%LBi
  UBi = self%geom%UBi
  LBj = self%geom%LBj
  UBj = self%geom%UBj

  allocate ( self%fields(SIZE(vars)) )

  DO i = 1, SIZE(vars)
    self%fields(i)%name = trim(vars(i))

    ! Default stencil grid location is at cell center (RHO-points)

    self%fields(i)%lon => self%geom%lonr
    self%fields(i)%lat => self%geom%latr

    ! determine number of levels, and if masked

    SELECT CASE (self%fields(i)%name)
      CASE ('tocn', 'socn')
        N = self%geom%N
        self%fields(i)%mask => self%geom%rmask
      CASE ('uocn')
        N = self%geom%N
        self%fields(i)%mask => self%geom%umask
        self%fields(i)%lon  => self%geom%lonu
        self%fields(i)%lat  => self%geom%latu
      CASE ('vocn')
        N = self%geom%N
        self%fields(i)%mask => self%geom%vmask
        self%fields(i)%lon  => self%geom%lonv
        self%fields(i)%lat  => self%geom%latv
      CASE ('ssh')
        N = 1
        self%fields(i)%mask => self%geom%rmask
      CASE DEFAULT
        CALL abor1_ftn ('roms_fields::create(): unknown field '// self%fields(i)%name)
    END SELECT

    ! Allocate space
    
    self%fields(i)%N = N
    
    allocate ( self%fields(i)%val(LBi:UBi, LBj:UBi, N) )

    ! Set other variables associated with each field

    self%fields(i)%cf_name = ""
    self%fields(i)%io_name = ""
    self%fields(i)%gtype   = "r"

    SELECT CASE (self%fields(i)%name)
      CASE ('tocn')
        self%fields(i)%cf_name = "sea_water_potential_temperature"
        self%fields(i)%io_file = "ocn"
        self%fields(i)%io_name = "temp"
      CASE ('socn')
        self%fields(i)%cf_name = "sea_water_practical_salinity"
        self%fields(i)%io_file = "ocn"
        self%fields(i)%io_name = "salt"
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
        self%fields(i)%gtype   = "v"
    END SELECT

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
  CLASS (roms_fields),    intent(in) :: rhs

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
  CLASS (roms_fields),    intent(in) :: rhs

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

END SUBROUTINE roms_fields_mul

! ------------------------------------------------------------------------------
!> Add two fields (multiplying the rhs first by a constant)

SUBROUTINE roms_fields_axpy (self, c, rhs)

  CLASS (roms_fields), intent(inout) :: self
  real (kind=kind_real),  intent(in) :: c
  CLASS (roms_fields),    intent(in) :: rhs

  integer                            :: i
  TYPE (roms_field),         pointer :: f_rhs, f_lhs

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

  CLASS (roms_fields),     intent(in) :: fld1
  CLASS (roms_fields),     intent(in) :: fld2
  real (kind=kind_real),  intent(out) :: zprod

  integer                             :: i, j, k, n
  real (kind=kind_real)               :: my_zprod
  TYPE (roms_field),          pointer :: field1, field2

  ! Make sure fields have same name, size, and shape

  CALL F1%check_congruent (F2)

  ! Loop over (almost) all fields

  my_zprod = 0.0_kind_real

  DO n = 1, SIZE(F1%fields)

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

  CLASS (roms_fields),      intent(in) :: fld              !> Fields set
  integer,                  intent(in) :: nf
  real (kind=kind_real), intent(inout) :: pstat(3, nf)     !> [min, max, average]

  logical                              :: mask(fld%geom%Istr:fld%geom%Iend, &
                                             & fld%geom%Jstr:fld%geom%Jend)
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

    CALL fld%geom%f_comm%allreduce (my_water_cells, water_cells, fckit_mpi_sum())

    ! Calculate global min/max/mean

    CALL fldinfo (field%val(Istr:Iend,Jstr:Jend,:), mask, buffer)

    CALL fld%geom%f_comm%allreduce (buffer(1), pstat(1,m), fckit_mpi_min())
    CALL fld%geom%f_comm%allreduce (buffer(2), pstat(2,m), fckit_mpi_max())
    CALL fld%geom%f_comm%allreduce (buffer(3), pstat(3,m), fckit_mpi_sum())
    pstat(3,n) = pstat(3,n) / water_cells

  END DO

END SUBROUTINE roms_fields_gpnorm


! ------------------------------------------------------------------------------
! Interpolate from U- and V-points to RHO-points.

SUBROUTINE roms_fields_colocate (self, gtype)

  CLASS (roms_fields),    intent(inout) :: self
  character (len=1),         intent(in) :: gtype  !< C-grid location (r, u, or v)

  integer                               :: i, k
  real (kind=kind_real),    allocatable :: val(:,:,:)
  real (kind=kind_real),        pointer :: lon_out(:,:) => null()
  real (kind=kind_real),        pointer :: lat_out(:,:) => null()
  TYPE (roms_geom),             pointer :: g => null()
  TYPE (horiz_interp_type)              :: interp2d

  ! Associate lon_out and lat_out according to cgridlocout

  SELECT CASE (gtype)
    CASE ('r')                           !< RHO-points
      lon_out => self%geom%lon
      lat_out => self%geom%lat
    CASE ('u')                           !< U-points
      lon_out => self%geom%lonu
      lat_out => self%geom%latu
    CASE ('v')                           !< V-points
      lon_out => self%geom%lonv
      lat_out => self%geom%latv
    CASE DEFAULT
      CALL abor1_ftn ('roms_fields::colocate: unknown C-grid location '// gtype)
  END SELECT

  ! Apply interpolation to all fields, when necessary

  DO i = 1, SIZE(self%fields)

    ! Check if already colocated

    IF (self%fields(i)%gtype == gtype) CYCLE

    ! Initialize fms spherical idw interpolation

     g => self%geom
     CALL horiz_interp_spherical_new(interp2d, &
       & REAL(deg2rad*self%fields(i)%lon(g%isd:g%ied,g%jsd:g%jed), 8), &
       & REAL(deg2rad*self%fields(i)%lat(g%isd:g%ied,g%jsd:g%jed), 8), &
       & REAL(deg2rad*lon_out(g%isc:g%iec,g%jsc:g%jec), 8), &
       & REAL(deg2rad*lat_out(g%isc:g%iec,g%jsc:g%jec), 8))

    ! Make a temporary copy of field

    IF (ALLOCATED(val)) deallocate (val)
    allocate (val, MOLD=self%fields(i)%val)
    val = self%fields(i)%val

    ! Interpolate all levels

    DO k = 1, self%fields(i)%nz
      CALL self%fields(i)%stencil_interp (self%geom, interp2d)
    END DO

    ! Update c-grid location

    self%fields(i)%gtype = gtype
 
    SELECT CASE (gtype)
      CASE ('r')
        self%fields(i)%lon => self%geom%lon
        self%fields(i)%lat => self%geom%lat
      CASE ('u')
        self%fields(i)%lon => self%geom%lonu
        self%fields(i)%lat => self%geom%latu
      CASE ('v')
        self%fields(i)%lon => self%geom%lonv
        self%fields(i)%lat => self%geom%latv
    END SELECT

  END DO

  CALL horiz_interp_spherical_del (interp2d)

END SUBROUTINE roms_fields_colocate

! ------------------------------------------------------------------------------
! Compute the number of elements of in the state vector including packed fields

SUBROUTINE roms_fields_serial_size (self, geom, vec_size)

  CLASS (roms_fields),    intent(in) :: self
  TYPE (roms_geom),       intent(in) :: geom
  integer,               intent(out) :: vec_size

  integer                            :: i

  ! Loop over fields

  vec_size = 0
  DO i = 1, SIZE(self%fields)
    vec_size = vec_size + SIZE(self%fields(i)%val)
  END DO

END SUBROUTINE roms_fields_serial_size

! ------------------------------------------------------------------------------
! Pack all fields into state vector

SUBROUTINE roms_fields_serialize (self, geom, vec_size, vec)

  CLASS (roms_fields),     intent(in) :: self
  TYPE (roms_geom),        intent(in) :: geom
  integer,                 intent(in) :: vec_size      ! state vector length
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
! Unpack all fields from state vector

SUBROUTINE roms_fields_deserialize (self, geom, vec_size, vec, ic)

  CLASS (roms_fields),  intent(inout) :: self
  TYPE (roms_geom),        intent(in) :: geom
  integer,                 intent(in) :: vec_size      !< state vector length
  real (kind=kind_real),   intent(in) :: vec(vec_size) !< state vector
  integer,              intent(inout) :: ic            !< vector element counter        

  integer                             :: i, np

  ! Loop over fields, levels and horizontal points

  DO i = 1, SIZE(self%fields)
    np = SIZE(self%fields(i)%val)
    self%fields(i)%val = RESHAPE(vec(ic+1:ic+1+np), SHAPE(self%fields(i)%val))
    ic = ic + np
  END DO

END SUBROUTINE roms_fields_deserialize

! ------------------------------------------------------------------------------

SUBROUTINE roms_fields_read (fld, f_conf, vdate)

  USE mod_ncparam,    ONLY : r2dvar, r3dvar, u3dvar, v3dvar
  USE mod_netcdf,     ONLY : netcdf_inq_varid
  USE mod_scalars,    ONLY : NoError, exit_flag
  USE netcdf,         ONLY : nf90_noerr
  USE nf_fread2d_mod, ONLY : nf_fread2d
  USE nf_fread3d_mod, ONLY : nf_fread3d

  CLASS (roms_fields),        intent(inout) :: fld     !< Fields set
  TYPE (fckit_configuration), intent(in)    :: f_conf  !< Configuration
  TYPE (datetime),            intent(inout) :: vdate   !< DateTime

  integer                                   :: i, model, ng, varid
  integer                                   :: InpNCid, InpRec
  integer                                   :: LBi, UBi, LBj, UBj, LBk, UBk
  real (kind=kind_real)                     :: Fmin, Fmax, scale
  character (len=256)                       :: InpNCname

  ! Initialize

  model = fld%geom%model        ! numerical kernel
  ng    = fld%geom%ng           ! nested grid number

  LBi = fld%geom%LBi
  UBi = fld%geom%UBi
  LBj = fld%geom%LBj
  UBj = fld%geom%UBj
  LBk = fld%geom%LBk
  UBk = fld%geom%UBk

  scale = 1.0_kind_real

  ! Read in all fields

  DO i = 1, SIZE(fld%fields)

    InpNCname = fld%fields(i)%InpNCname
    InpNCid   = fld%fields(i)%InpNCid
    InpRec    = fld%fields(i)%InpRec

    CALL netcdf_inq_varid (ng, model, InpNCname, fld%fields(i)%io_name, &
                         & InpNCid, varid)
    IF (exit_flag.ne.NoError) THEN
      CALL abor1_ftn ("roms_fields::read: error while inquiring '"//fld%fields(i)%io_name"' variable ID")
    END IF

    SELECT CASE (fld%fields(i)%name)
      CASE ('ssh')
        status=nf_read2d(ng, model, InpNCname, InpNCid, fld%fields(i)%io_name, &
                       & varid, InpRec, r2dvar, Vsize, &
                       & LBi, UBi, LBj, UBj, &
                       & scale, Fmin, Fmax, &
                       & fld%fields(i)%mask, fld%fields(i)%val(:,:,1))
      CASE ('uocn')
        status=nf_read3d(ng, model, InpNCname, InpNCid, fld%fields(i)%io_name, &
                       & varid, InpRec, u3dvar, Vsize, &
                       & LBi, UBi, LBj, UBj, LBk, UBk, &
                       % scale, Fmin, Fmax, &
                       & fld%fields(i)%mask, fld%fields(i)%val)
      CASE ('vocn')
        status=nf_read3d(ng, model, InpNCname, InpNCid, fld%fields(i)%io_name, &
                       & varid, InpRec, v3dvar, Vsize, &
                       & LBi, UBi, LBj, UBj, LBk, UBk, &
                       % scale, Fmin, Fmax, &
                       & fld%fields(i)%mask, fld%fields(i)%val)
      CASE ('tocn', 'socn')
        status=nf_read3d(ng, model, InpNCname, InpNCid, fld%fields(i)%io_name, &
                       & varid, InpRec, r3dvar, Vsize, &
                       & LBi, UBi, LBj, UBj, LBk, UBk, &
                       % scale, Fmin, Fmax, &
                       & fld%fields(i)%mask, fld%fields(i)%val)
    END SELECT
    IF (status.ne.nf90_noerr) THEN
      CALL abor1_ftn ("roms_fields::read: error while readin '"//fld%fields(i)%io_name"'")
    END IF

    CALL self%update_halo (fld%geom)

  END DO

END SUBROUTINE roms_fields_read

! ------------------------------------------------------------------------------
!> Write out ROMS fields into output NetCDF file

SUBROUTINE roms_fields_write (fld, f_conf, vdate)

  USE mod_ncparam,     ONLY : r2dvar, r3dvar, u3dvar, v3dvar
  USE mod_netcdf,      ONLY : netcdf_inq_varid
  USE mod_scalars,     ONLY : NoError, exit_flag
  USE netcdf,          ONLY : nf90_noerr
  USE nf_fwrite2d_mod, ONLY : nf_fwrite2d
  USE nf_fwrite3d_mod, ONLY : nf_fwrite3d


  CLASS (roms_fields),        intent(inout) :: fld     !< Fields set
  TYPE (fckit_configuration), intent(in)    :: f_conf  !< Configuration
  TYPE (datetime),            intent(inout) :: vdate   !< DateTime

  integer                         :: i, model, ng, varid
  integer                         :: OutNCid, OutRec
  integer                         :: LBi, UBi, LBj, UBj, LBk, UBk
  real (kind=kind_real)           :: scale

  ! Initialize

  model = fld%geom%model        ! numerical kernel
  ng    = fld%geom%ng           ! nested grid number

  LBi = fld%geom%LBi
  UBi = fld%geom%UBi
  LBj = fld%geom%LBj
  UBj = fld%geom%UBj
  LBk = fld%geom%LBk
  UBk = fld%geom%UBk

  scale = 1.0_kind_real

  ! Write out all fields

  DO i = 1, SIZE(fld%fields)

    OutNCname = fld%fields(i)%InpNCname
    OutNCid   = fld%fields(i)%OutNCid
    OutRec    = fld%fields(i)%OutRec + 1

    CALL netcdf_inq_varid (ng, model, OutNCname, fld%fields(i)%io_name, &
                         & OutNCid, varid)
    IF (exit_flag.ne.NoError) THEN
      CALL abor1_ftn ("roms_fields::write: error while inquiring '"//fld%fields(i)%io_name"' variable ID")
    END IF

    SELECT CASE (fld%fields(i)%name)
      CASE ('ssh')
        status=nf_fwrite2d(ng, model, OutNCid, varid, OutRec, r2dvar, &
                         & LBi, UBi, LBj, UBj, scale, &
                         & fld%fields(i)%mask, fld%fields(i)%val(:,:,1))
      CASE ('uocn')
        status=nf_fwrite3d(ng, model, OutNCid, varid, OutRec, u3dvar, &
                         & LBi, UBi, LBj, UBj, LBk, UBk, &
                         & fld%fields(i)%mask, fld%fields(i)%val)
      CASE ('vocn')
        status=nf_fwrite3d(ng, model, OutNCid, varid, OutRec, v3dvar, &
                         & LBi, UBi, LBj, UBj, LBk, UBk, &
                         & fld%fields(i)%mask, fld%fields(i)%val)
      CASE ('tocn', 'socn')
        status=nf_fwrite3d(ng, model, OutNCid, varid, OutRec, r3dvar, &
                         & LBi, UBi, LBj, UBj, LBk, UBk,
                         & fld%fields(i)%mask, fld%fields(i)%val)
    END SELECT
    IF (status.ne.nf90_noerr) THEN
      CALL abor1_ftn ("roms_fields::write: error while writing '"//fld%fields(i)%io_name"'")
    END IF
    
    fld%fields(i)%OutRec = OutRec

  END DO

END SUBROUTINE roms_fields_write

! ------------------------------------------------------------------------------

END MODULE roms_fields_mod
