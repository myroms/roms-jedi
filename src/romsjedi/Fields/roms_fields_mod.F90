! (C) Copyright 2017-2021 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://Qwww.apache.org/licenses/LICENSE-2.0.
!
!>
!! \brief   Field/Fields class for ROMS state vector
!!
!! \details This class includes several routines used to create, destroy, get,
!!          check, operate, manipulate, read, and write each field in the state
!!          vector. It is one of the elementary classes for JEDI model agnostic
!!          data assimilation algorithms.
!!
!! \author  Hernan G. Arango (Rutgers University)
!! \date    June 2021

MODULE roms_fields_mod

USE datetime_mod
USE duration_mod
USE fckit_configuration_module, ONLY : fckit_configuration
USE fckit_log_module,           ONLY : log, fckit_log
USE fckit_mpi_module,           ONLY : fckit_mpi_comm,                         &
                                       fckit_mpi_min,                          &
                                       fckit_mpi_max,                          &
                                       fckit_mpi_sum
USE kinds,                      ONLY : kind_real
USE oops_variables_mod

USE roms_interpolate_mod
USE roms_fields_metadata_mod
USE roms_fieldsutils_mod
USE roms_geom_mod,              ONLY : roms_geom

USE mod_iounits,                ONLY : T_IO
USE mod_scalars,                ONLY : NoError, exit_flag

implicit none

PUBLIC  :: roms_field
PUBLIC  :: roms_fields

! ------------------------------------------------------------------------------
!> Structure holds all data and metadata related to a single field variable.
! ------------------------------------------------------------------------------

TYPE :: roms_field

  integer                            :: Istr, Iend           !< tile I-range
  integer                            :: Jstr, Jend           !< tile J-range
  integer                            :: N                    !< number of levels
  integer                            :: InpNCid, OutNCid     !< NetCDF file IDs
  integer                            :: InpRec, OutRec       !< NetCDF records

  real (kind=kind_real)              :: CheckSum             !< field checksum
  real (kind=kind_real)              :: DateNumber           !< Matlab datenum
  real (kind=kind_real)              :: MinValue             !< field min value
  real (kind=kind_real)              :: MaxValue             !< field max value

  real (kind=kind_real)              :: spval = 1.0E+37_kind_real
 
  real (kind=kind_real),     pointer :: angle(:,:) => null() !< field grid angle
  real (kind=kind_real),     pointer :: lon(:,:)   => null() !< field lon
  real (kind=kind_real),     pointer :: lat(:,:)   => null() !< field lat
  real (kind=kind_real),     pointer :: mask(:,:)  => null() !< field mask
  real (kind=kind_real), allocatable :: val(:,:,:)           !< field data

  character (len=:),     allocatable :: name                 !< internal name

  character (len=:),     allocatable :: DateTimeString       !< field ISO8601
  character (len=:),     allocatable :: InpNCname            !< input NetCDF
  character (len=:),     allocatable :: OutNCname            !< output NetCDF
  
  TYPE (roms_field_metadata)         :: metadata             !< metadata from
                                                             !< YAML config file
  CONTAINS
  
  PROCEDURE :: copy            => roms_field_copy
  PROCEDURE :: delete          => roms_field_delete

  PROCEDURE :: check_congruent => roms_field_check_congruent
  PROCEDURE :: update_halo     => roms_field_update_halo
  PROCEDURE :: stencil_interp  => roms_field_stencil_interp

  PROCEDURE :: io_has_var      => roms_field_io_has_var
  PROCEDURE :: stats           => roms_field_stats

END TYPE roms_field

! ------------------------------------------------------------------------------
!> Structure to holds a collection of roms_field types, and the public routines
!  to manipulate them. Represents all the fields of a given state or increment.
! ------------------------------------------------------------------------------

TYPE :: roms_fields

  TYPE (roms_geom),  pointer     :: geom => null()    !< Geometry
  TYPE (roms_field), allocatable :: fields(:)         !< Fields set

  TYPE (T_IO), allocatable       :: IO(:)             !< ROMS I/O file structure

  CONTAINS

  ! Field constructors and destructors.

  PROCEDURE :: create          => roms_fields_create
  PROCEDURE :: copy            => roms_fields_copy
  PROCEDURE :: delete          => roms_fields_delete

  ! Field getters and checkers.

  PROCEDURE :: get             => roms_fields_get
  PROCEDURE :: has             => roms_fields_has
  PROCEDURE :: check_congruent => roms_fields_check_congruent
  PROCEDURE :: check_subset    => roms_fields_check_subset

  ! Field math operations.

  PROCEDURE :: add             => roms_fields_add
  PROCEDURE :: axpy            => roms_fields_axpy
  PROCEDURE :: dot_prod        => roms_fields_dotprod
  PROCEDURE :: gpnorm          => roms_fields_gpnorm
  PROCEDURE :: mul             => roms_fields_mul
  PROCEDURE :: rms             => roms_fields_rms
  PROCEDURE :: sub             => roms_fields_sub
  PROCEDURE :: ones            => roms_fields_ones
  PROCEDURE :: zeros           => roms_fields_zeros

  ! Analytical initialization.

  PROCEDURE :: analytic        => roms_fields_analytic

  ! I/O processing.

  PROCEDURE :: IO_create       => roms_fields_IO_create
  PROCEDURE :: IO_metadata     => roms_fields_IO_metadata
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

PRIVATE

! Switch for printing fields information during debugging.

logical :: LdebugFields = .FALSE.

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
! ROMS routines for a single field:
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
!> Copy a field from RHS to SELF. SELF must be allocated first. The pointers
!  (mask, lat, lon) will be different, but should NOT be changed to point to
!  RHS pointers. Bad things will happen.

SUBROUTINE roms_field_copy (self, rhs)

  CLASS (roms_field), intent(inout) :: self      !< LHS Field object
  TYPE (roms_field),  intent(in   ) :: rhs       !< RHS Field object

  integer                           :: lstr
  integer                           :: LBi, UBi, LBj, UBj, N

  IF (LdebugFields .and. (my_comm%rank() .eq. 0)) THEN
    PRINT '(9a,5(a,i0))', ' roms_field::copy: Processing RHS - ',              &
                          ' name = ', rhs%name,                                & 
                          ', metadata%name ', rhs%metadata%name,               &
                          ', getval_name ', rhs%metadata%getval_name,          &
                          ', getval_name_surface = ',                          &
                          rhs%metadata%getval_name_surface,                    &
                          ', LBi = ', LBOUND(rhs%val,DIM=1),                   &
                          ', UBi = ', UBOUND(rhs%val,DIM=1),                   &
                          ', LBj = ', LBOUND(rhs%val,DIM=2),                   &
                          ', UBj = ', UBOUND(rhs%val,DIM=2),                   &
                          ', N = ',   UBOUND(rhs%val,DIM=3)
  END IF

  ! Sometimes, fields are transformed by the variable change operator that
  ! may change the size of the level dimension.  For example, we can extract
  ! and operate on a particular level like the surface value to pass SST, SSS,
  ! or other fields.  In such a case, deallocate/allocate "self" to the correct
  ! third dimension of "rhs"

  IF ((rhs%name .eq. rhs%metadata%getval_name_surface) .and.                   &
      (SIZE(self%val, DIM=3) .ne. SIZE(rhs%val, DIM=3))) THEN

    deallocate (self%val)

    LBi = LBOUND(rhs%val, DIM=1)
    UBi = UBOUND(rhs%val, DIM=1)
    LBj = LBOUND(rhs%val, DIM=2)
    UBj = UBOUND(rhs%val, DIM=2)
    N   = UBOUND(rhs%val, DIM=3)

    allocate ( self%val(LBi:UBi, LBj:UBj, N) )
    self%N = N

    self%name = rhs%name                      ! update field name and metadata
    self%metadata = rhs%metadata
    self%metadata%name = rhs%name 
  END IF

  ! Special case for processing RHS variable with GeoVaLs as short-name.

  IF ((rhs%name .ne. rhs%metadata%name) .and.                                  &
      (self%name .ne. rhs%name)) THEN
    self%name = rhs%name
  END IF

  ! The only variable that should be different is %val.

  CALL self%check_congruent (rhs)

  ! Copy field values.

  self%val = rhs%val

  ! Then, Copy few properties that are not set in 'roms_fields_init_vars'.
  ! They are needed elsewhere.

  self%InpNCid        = rhs%InpNCid
  self%OutNCid        = rhs%OutNCid
  self%InpRec         = rhs%InpRec
  self%OutRec         = rhs%OutRec
  self%DateNumber     = rhs%DateNumber

  IF (allocated(self%DateTimeString)) THEN
    deallocate ( self%DateTimeString )
  END IF
  IF (allocated(rhs%DateTimeString)) THEN
    lstr = MAX(21, LEN_TRIM(rhs%DateTimeString))
    allocate ( character(LEN=lstr) :: self%DateTimeString )
    self%DateTimeString = TRIM(rhs%DateTimeString)
  END IF

  IF (allocated(self%InpNCname)) THEN
    deallocate ( self%InpNCname )
  END IF
  IF (allocated(rhs%InpNCname)) THEN
    lstr = LEN_TRIM(rhs%InpNCname)
    allocate ( character(LEN=lstr) :: self%InpNCname )
    self%InpNCname = TRIM(rhs%InpNCname)
  END IF

  IF (allocated(self%OutNCname)) THEN
    deallocate ( self%OutNCname )
  END IF
  IF (allocated(rhs%OutNCname)) THEN
    lstr = LEN_TRIM(rhs%OutNCname)
    allocate ( character(LEN=lstr) :: self%OutNCname )
    self%OutNCname = TRIM(rhs%OutNCname)
  END IF

END SUBROUTINE roms_field_copy

! ------------------------------------------------------------------------------
!> Delete field object.

SUBROUTINE roms_field_delete (self)

  CLASS (roms_field), intent(inout) :: self      !< Field object

  IF (LdebugFields .and. (my_comm%rank() .eq. 0)) THEN
    PRINT '(2a,a5,5(a,i0))', 'Entered roms_field::copy:',                      &
                             ', variable = ', self%metadata%io_name,           &
                             '  LBi = ', LBOUND(self%val,DIM=1),               &
                             ', UBi = ', UBOUND(self%val,DIM=1),               &
                             ', LBj = ', LBOUND(self%val,DIM=2),               &
                             ', UBj = ', UBOUND(self%val,DIM=2),               &
                             ', N = ',   UBOUND(self%val,DIM=3)
  END IF

  deallocate (self%val)

END SUBROUTINE roms_field_delete

! ------------------------------------------------------------------------------
!> Make sure the two fields are the same in terms of name, size, and shape.

SUBROUTINE roms_field_check_congruent (self, rhs)

  CLASS (roms_field), intent(in) :: self         !< LHS Field object
  TYPE (roms_field),  intent(in) :: rhs          !< RHS Field object

  integer                       :: i
  character (len=1)             :: mydim

  IF (self%N .ne. rhs%N) THEN
    CALL abor1_ftn ("roms_field::check_congruent: '" // self%name //           &
                    "', third dimension self%N unequal to '" // rhs%name //    &
                    "' rhs%N") 
  END IF

  IF (self%name .ne. rhs%name) THEN
    CALL abor1_ftn ("roms_field:::check_congruent: '" // self%name //          &
                    "', variable name self%name unequal '" // rhs%name //      &
                    "' rhs%name, and possible metadata is different")
  END IF

  IF (SIZE(SHAPE(self%val)) .ne. SIZE(SHAPE(rhs%val))) THEN
    CALL abor1_ftn ("roms_field::check_congruent: " //                         &
                    "variable array rank of self%val unequal rhs%val")
  END IF

  DO i = 1, SIZE(SHAPE(self%val))
    IF (SIZE(self%val, DIM=i) .ne. SIZE(rhs%val, DIM=i)) THEN
      WRITE (mydim,'(i0)') i
      CALL abor1_ftn ("roms_field::check_congruent:  '" // self%name //        &
                      "', dimension " // mydim //                              &
                      " in variable self%val unequal rhs%val")
    END IF
  END DO

END SUBROUTINE roms_field_check_congruent

! ------------------------------------------------------------------------------
!> Update field halo points due to parallel tile partition.

SUBROUTINE roms_field_update_halo (self, geom)

  USE mp_exchange_mod, ONLY : mp_exchange2d, mp_exchange3d

  CLASS (roms_field),        intent(inout) :: self  !< Field object
  TYPE (roms_geom), pointer, intent(in   ) :: geom  !< Geometry

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

  IF (self%N .eq. 1) THEN
    CALL mp_exchange2d (ng, tile, 1, 1, LBi, UBi, LBj, UBj,                    &
                        NghostPoints, EWperiodic, NSperiodic,                  &
                        self%val(:,:,1))
  ELSE
     CALL mp_exchange3d (ng, tile, 1, 1, LBi, UBi, LBj, UBj, LBk, UBk,         &
                         NghostPoints, EWperiodic, NSperiodic,                 &
                         self%val)
  END IF
    
END SUBROUTINE roms_field_update_halo

! ------------------------------------------------------------------------------
!> Interpolate 2D or 3D field to different grid stencil location.

SUBROUTINE roms_field_stencil_interp (self, geom, interp, method)

  CLASS (roms_field),        intent(inout) :: self    !< Field object
  TYPE (roms_geom), pointer, intent(in   ) :: geom    !< Geometry
  TYPE (roms_interp_type),   intent(inout) :: interp  !< interpolation object
  integer,                   intent(in   ) :: method  !< interpolation method

  real(kind=kind_real),        allocatable :: val_src(:,:,:)

  ! Make a temporary copy of source field.

  allocate (val_src, MOLD=self%val)
  val_src = self%val

  ! Interpolate field level-by-level.

  CALL roms_horiz_interp (interp, val_src, self%val, method)
  IF (exit_flag .ne. NoError) THEN
    CALL abor1_ftn ('roms_field::stencil_interp: Error in roms_horiz_interp')
  END IF

  ! Update halo.

  CALL self%update_halo (geom)

  ! Deallocate temporary array.

  IF (allocated(val_src)) deallocate (val_src)

END SUBROUTINE roms_field_stencil_interp

! ------------------------------------------------------------------------------
!> Initializes ROMS field interpolation structure.

SUBROUTINE roms_field_interp_initialize (geom, field, interp, gtype)

  TYPE (roms_geom),        intent(in   ) :: geom      !< geometry object
  TYPE (roms_field),       intent(inout) :: field     !< field object
  TYPE (roms_interp_type), intent(inout) :: interp    !< interpolation object
  character (len=*),       intent(in   ) :: gtype     !< C-grid location

  integer                                :: LBi, UBi, LBj, UBj

  ! If applicable, deallocate interpolation structure.

  IF (allocated(interp%lon_src)) THEN
    CALL roms_interp_delete (interp)
  END IF

  ! Allocate and assign source grid component arrays.

  LBi = LBOUND(field%lon, DIM=1)
  UBi = UBOUND(field%lon, DIM=1)
  LBj = LBOUND(field%lon, DIM=2)
  UBj = UBOUND(field%lon, DIM=2)

  allocate ( interp%lon_src(LBi:UBi,LBj:UBj) )
  allocate ( interp%lat_src(LBi:UBi,LBj:UBj) )
  allocate ( interp%angle_src(LBi:UBi,LBj:UBj) )
  allocate ( interp%mask_src(LBi:UBi,LBj:UBj) )

  interp%ng = geom%ng
  interp%model = geom%model

  interp%lon_src   = field%lon
  interp%lat_src   = field%lat
  interp%angle_src = field%angle
  interp%mask_src  = field%mask

  interp%LBi_src   = LBi
  interp%UBi_src   = UBi
  interp%LBj_src   = LBi
  interp%UBj_src   = UBi

  interp%Istr_src  = field%Istr
  interp%Iend_src  = field%Iend
  interp%Jstr_src  = field%Jstr
  interp%Jend_src  = field%Jend

  ! Allocate and assign destination grid component arrays.

  LBi = geom%LBi
  UBi = geom%UBi
  LBj = geom%LBj
  UBj = geom%UBj

  allocate ( interp%lon_dst(LBi:UBi,LBj:UBj) )
  allocate ( interp%lat_dst(LBi:UBi,LBj:UBj) )
  allocate ( interp%mask_dst(LBi:UBi,LBj:UBj) )

  interp%LBi_dst = LBi
  interp%UBi_dst = UBi
  interp%LBj_dst = LBj
  interp%UBj_dst = UBj

  SELECT CASE (gtype)
    CASE ('r', 'R', 'w', 'W')            !< RHO-points
      interp%Istr_dst = geom%IstrR
      interp%Iend_dst = geom%IendR
      interp%Jstr_dst = geom%JstrR
      interp%Jend_dst = geom%JendR
      interp%lon_dst  = geom%lonr
      interp%lat_dst  = geom%latr
      interp%mask_dst = geom%rmask
    CASE ('u', 'U')                      !< U-points
      interp%Istr_dst = geom%Istr
      interp%Iend_dst = geom%IendR
      interp%Jstr_dst = geom%JstrR
      interp%Jend_dst = geom%JendR
      interp%lon_dst  = geom%lonu
      interp%lat_dst  = geom%latu
      interp%mask_dst = geom%umask
    CASE ('v', 'V')                      !< V-points
      interp%Istr_dst = geom%IstrR
      interp%Iend_dst = geom%IendR
      interp%Jstr_dst = geom%Jstr
      interp%Jend_dst = geom%JendR
      interp%lon_dst  = geom%lonv
      interp%lat_dst  = geom%latv
      interp%mask_dst = geom%vmask
    CASE DEFAULT
      CALL abor1_ftn ('roms_field::interp_initialize: unknown C-grid ' //      &
                      'location = ' // gtype)
  END SELECT

  ! Compute the horizontal fractional coordinates (x_dst, y_dst) of the source
  ! cells containing the destination values.

  CALL roms_interp_fractional (interp)

END SUBROUTINE roms_field_interp_initialize

! ------------------------------------------------------------------------------
!> It checks if field data is in file and return its NetCDF variable index. It
!! assumes that either 'netcdf_inq_var' or 'pio_netcdf_inq_var' has been called
!! previously. If found, it checks variable dimensions for consistency with
!! geometry.
 
FUNCTION roms_field_io_has_var (field, geom, vindex) RESULT (foundit)

  USE mod_netcdf,  ONLY : dim_size, n_var, var_dim, var_name

  CLASS (roms_field), intent(in ) :: field         !< Field object  
  TYPE (roms_geom),   intent(in ) :: geom          !< Geometry object
  integer,            intent(out) :: vindex        !< variable index

  logical                         :: foundit       !< returned value

  logical                         :: is3d
  integer                         :: Im, Jm, Km
  integer                         :: LBk, UBk
  integer                         :: i, nx, ny, nz
  character (len=256)             :: text

  ! Initialize

  foundit = .FALSE.
  is3d    = .FALSE.
  vindex  = -1

  ! Check if field name is in list of NetCDF variables.

  DO i = 1, n_var
    IF (field%metadata%io_name .eq. TRIM(var_name(i))) THEN
      foundit = .TRUE.
      vindex  = i
      EXIT
    END IF
  END DO

  ! If found variable, check its dimensions for consitency with geometry object.

  IF (foundit) THEN

    SELECT CASE (field%metadata%levels)
      CASE ('full_ocn')                             ! 3D field, full r-column
        LBk = 1
        UBk = geom%N
        is3d = .TRUE.
      CASE ('wfull_ocn')                            ! 3D field, full column
        LBk = 0
        UBk = geom%N
        is3d = .TRUE.
      CASE ('1', 'surface')                  
        LBk = 1                                     ! 3D field, single level
        UBk = 1
    END SELECT
    Km = UBk-LBk+1

    SELECT CASE (field%metadata%gtype)
      CASE ('r')                                    ! RHO-points variable
        Im = geom%Lm + 2
        Jm = geom%Mm + 2
      CASE ('u')                                    ! U-points variable
        Im = geom%Lm + 1
        Jm = geom%Mm + 2
      CASE ('v')                                    ! V-points variable
        Im = geom%Lm + 2
        Jm = geom%Mm + 1
      CASE ('w')                                    ! W-poits variable
        Im = geom%Lm + 2
        Jm = geom%Mm + 2
    END SELECT

    ! Check variable dimensions for consistency.

    nx = dim_size(var_dim(1,vindex))
    ny = dim_size(var_dim(2,vindex))

    IF (is3d) THEN

      nz = dim_size(var_dim(3,vindex))
      IF ((nx.ne.Im).or.(ny.ne.Jm).or.(nz.ne.Km)) THEN
        IF (geom%f_comm%rank() .eq. 0) THEN
          WRITE (text,'(a,3(1x,i0))')                                          &
                      'roms_field_io_has_var: inconsitent dimensions for '//   &
                      TRIM(field%metadata%io_name)//':', Im, Jm, Km
          CALL fckit_log%error (TRIM(text))
          WRITE (text,'(a,2(1x,i0))')                                          &
                      'roms_field::io_has_var: expected    dimensions for '//  &
                      TRIM(field%metadata%io_name)//':', nx, ny, nz
          CALL fckit_log%error (TRIM(text))
        END IF
      END IF

    ELSE

      IF ((nx.ne.Im).or.(ny.ne.Jm)) THEN
        IF (geom%f_comm%rank() .eq. 0) THEN
          WRITE (text,'(a,2(1x,i0))')                                          &
                      'roms_field::io_has_var: inconsitent dimensions for '//  &
                      TRIM(field%metadata%io_name)//':', Im, Jm
          CALL fckit_log%error (TRIM(text))
          WRITE (text,'(a,2(1x,i0))')                                          &
                      'roms_field::io_has_var: expected    dimensions for '//  &
                      TRIM(field%metadata%io_name)//':', nx, ny 
          CALL fckit_log%error (TRIM(text))
        END IF
      END IF

    END IF

  END IF

END FUNCTION roms_field_io_has_var

! ------------------------------------------------------------------------------
!> It computes global field statistics: Min and Max.

SUBROUTINE roms_field_stats (self, fstats)

  USE get_hash_mod, ONLY : get_hash 

  CLASS (roms_field),     intent(in ) :: self         !< Field object  
  real (kind=kind_real),  intent(out) :: fstats(3)    !< Field statistics

  logical,                allocatable :: mask(:,:)
  integer                             :: Istr, Iend, Jstr, Jend, LBk, UBk
  integer                             :: Npts, k
  integer (kind=SELECTED_INT_KIND(8)) :: checksum
  real (kind=kind_real),      pointer :: Cwrk(:)
  real (kind=kind_real),  allocatable :: buffer(:,:)
  real (kind=kind_real)               :: stats(3)

  ! Initialize.

  Istr = self%Istr
  Iend = self%Iend
  Jstr = self%Jstr
  Jend = self%Jend
  LBk  = LBOUND(self%val, DIM=3)
  UBk  = UBOUND(self%val, DIM=3)
  Npts = (Iend-Istr+1)*(Jend-Jstr+1)*(UBk-LBk+1)

  ! Get the mask and the total number of grid cells.

  allocate ( mask(Istr:Iend, Jstr:Jend) )

  IF (.not. ASSOCIATED(self%mask)) THEN
    mask = .true.
  ELSE
    mask = self%mask(Istr:Iend,Jstr:Jend) > 0.0
  END IF

  ! Compute field statistics.

  allocate ( buffer(2,LBk:UBk) )

  DO k = LBk, UBK
    buffer(1,k) = MINVAL(self%val(Istr:Iend, Jstr:Jend, k), MASK=mask)
    buffer(2,k) = MAXVAL(self%val(Istr:Iend, Jstr:Jend, k), MASK=mask)
  END DO

  stats(1) = MINVAL(buffer(1,:))
  stats(2) = MAXVAL(buffer(2,:))

  ! Global reductions

  CALL my_comm%allreduce (stats(1), fstats(1), fckit_mpi_min())
  CALL my_comm%allreduce (stats(2), fstats(2), fckit_mpi_max())

  ! Compute order invariant 'checksum'.

  IF (.not.associated(Cwrk)) allocate ( Cwrk(Npts) )
  Cwrk = PACK(self%val(Istr:Iend, Jstr:Jend, LBk:UBk), .TRUE.)
  CALL get_hash (Cwrk, Npts, checksum, .TRUE.)
  IF (associated(Cwrk)) deallocate (Cwrk)  

  fstats(3) = REAL(checksum, KIND=kind_real)

  ! Deallocate.

  IF (allocated(mask)) deallocate (mask)

END SUBROUTINE roms_field_stats

! ------------------------------------------------------------------------------
! ROMS routines for a set of fields:
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
!> Create a new set of fields, allocate space for them, and initialize to zero.

SUBROUTINE roms_fields_create (self, geom, vars)

  CLASS (roms_fields),        intent(inout) :: self   !< Fields object
  TYPE (roms_geom),  pointer, intent(inout) :: geom   !< Geometry
  TYPE (oops_variables),      intent(in   ) :: vars   !< Fields names to create

  integer                                   :: i
  character(len=:), allocatable             :: vars_str(:)

  ! Make sure current object has not already been allocated.

  IF (allocated(self%fields)) THEN
    CALL abor1_ftn ('roms_fields::create: SELF object already allocated')
  END IF

  ! Associate geometry.

  self%geom => geom

  IF (LdebugFields .and. (my_comm%rank() .eq. 0)) THEN
    PRINT '(a, 6(a,i0))', 'roms_fields::create: ',                             &
                          ' tile = ', geom%f_comm%rank(),                      &
                          ', LBi = ', geom%LBi, ', UBi = ', geom%UBi,          &
                          ', LBj = ', geom%LBj, ', UBj = ', geom%UBj,          &
                          ', N = ', geom%N
    CALL geom%f_comm%barrier()
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

  DO i = 1, SIZE(self%fields)
    SELECT CASE (self%fields(i)%name)
      CASE ('AKt', 'AKs', 'AKv')
        self%fields(i)%val = 1.0E-5_kind_real
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

  integer                            :: i
  character(len=:), allocatable      :: vars_str(:)
  TYPE (roms_field), pointer         :: rhs_fld

  ! Initialize the variables based on the names in RHS.

  IF (LdebugFields .and. (my_comm%rank() .eq. 0)) THEN
    PRINT '(a, 6(a,i0))', ' roms_fields::copy:',                               &
                          ' tile = ', rhs%geom%f_comm%rank(),                  &
                          ', LBi = ', rhs%geom%LBi,                            &
                          ', UBi = ', rhs%geom%UBi,                            &
                          ', LBj = ', rhs%geom%LBj,                            &
                          ', UBj = ', rhs%geom%UBj,                            &
                          ', N = ', rhs%geom%N
  END IF

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
!> Get a pointer to the roms_field with the given name.
!!  If no field exists with that name, the prorgam aborts
!!  (use roms_fields%has() if you need to check for optional fields)

SUBROUTINE roms_fields_get (self, name, field)

  CLASS (roms_fields), target, intent(in ) :: self   !< fields object
  character (len=*),           intent(in ) :: name   !< name of field to find
  TYPE (roms_field), pointer,  intent(out) :: field  !< resulting field pointer

  integer                                  :: i

  ! Find the field with the given internal name or UFO standard name.

  DO i = 1, SIZE(self%fields)
    IF ((TRIM(name) .eq. self%fields(i)%name) .or.                             &
        (TRIM(name) .eq. self%fields(i)%metadata%getval_name)) THEN
      field => self%fields(i)
      RETURN
    END IF
  END DO

  ! Error: field was not found.

  CALL abor1_ftn ("roms_fields::get: cannot find field '" // TRIM(name) // "'")

END SUBROUTINE roms_fields_get

! ------------------------------------------------------------------------------
!> Check if field with the given name exists.

FUNCTION roms_fields_has (self, name) RESULT (foundit)

  CLASS (roms_fields), intent(in) :: self        !< Fields object
  character (len=*),   intent(in) :: name        !< Fields name

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
!> Make sure two sets of fields have same shape for eachfield they have in
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

    ! Get field information from the metadata 'geom%fieldsinfo' object, which
    ! is read from the YAML configuration file elsewhere. Notice that the user
    ! may specify the variable names as the ROMS-JEDI internal value or the UFO
    ! value.  For example, 'ssh' or 'sea_surface_height_above_geoid'.

    self%fields(i)%name = TRIM(vars(i))
    self%fields(i)%metadata = self%geom%fieldsinfo%get(self%fields(i)%name)

    ! Initialize Min/Max values.

    self%fields(i)%MinValue = self%fields(i)%spval
    self%fields(i)%MaxValue = self%fields(i)%spval

    ! Set state field metadata and grid information.

    SELECT CASE (self%fields(i)%metadata%gtype)
      CASE ('r','w')
        self%fields(i)%Istr    =  self%geom%IstrR
        self%fields(i)%Iend    =  self%geom%IendR
        self%fields(i)%Jstr    =  self%geom%JstrR
        self%fields(i)%Jend    =  self%geom%JendR
        self%fields(i)%angle   => self%geom%angler
        self%fields(i)%lon     => self%geom%lonr
        self%fields(i)%lat     => self%geom%latr
        self%fields(i)%mask    => self%geom%rmask
      CASE ('u')
        self%fields(i)%Istr    =  self%geom%Istr
        self%fields(i)%Iend    =  self%geom%IendR
        self%fields(i)%Jstr    =  self%geom%JstrR
        self%fields(i)%Jend    =  self%geom%JendR
        self%fields(i)%angle   => self%geom%angleu
        self%fields(i)%lon     => self%geom%lonu
        self%fields(i)%lat     => self%geom%latu
        self%fields(i)%mask    => self%geom%umask
      CASE ('v')
        self%fields(i)%Istr    =  self%geom%IstrR
        self%fields(i)%Iend    =  self%geom%IendR
        self%fields(i)%Jstr    =  self%geom%Jstr
        self%fields(i)%Jend    =  self%geom%JendR
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

    IF (self%fields(i)%name == self%fields(i)%metadata%getval_name_surface) THEN
      LBk = 1
      UBk = 1                                          ! surface field
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

    IF (LdebugFields .and. (self%geom%f_comm%rank() .eq. 0)) THEN
      PRINT '(2a,a40,a,3(i0,1x))', 'roms_fields::init_vars: ',                 &
                                   'created and allocated ',                   &
                                   self%fields(i)%name,                        &
                                   ', SHAPE = ', SHAPE(self%fields(i)%val)
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
  integer                              :: i

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

  LocalPET = self%geom%f_comm%rank()   ! PET rank

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
        DO j = field%Jstr, field%Jend
          DO i = field%Istr, field%Iend
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
        CASE ('tocn',                                                          &
              'sea_water_potential_temperature',                               &
              'sst', 'SST',                                                    &
              'sea_surface_temperature')
          field%val = T0
        CASE ('socn',                                                          &
              'sea_water_practical_salinity',                                  &
              'sss', 'SSS',                                                    &
              'sea_surface_salinity')
          field%val = S0
        CASE ('uocn',                                                          &
              'eastward_sea_water_velocity',                                   &
              'sea_water_x_velocity',                                          &
              'usur',                                                          &
              'surface_eastward_sea_water_velocity',                           &
              'sea_water_surface_x_velocity')
          field%val = U0
        CASE ('vocn',                                                          &
              'northward_sea_water_velocity',                                  &
              'sea_water_y_velocity',                                          &
              'vsur',                                                          &
              'surface_northward_sea_water_velocity',                          &
              'sea_water_surface_y_velocity')
          field%val = V0
        CASE ('ssh', 'SSH',                                                    &
              'sea_surface_height_above_geoid',                                &
              'sea_surface_elevation_anomaly')
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

  USE mod_param,   ONLY : MT, Ngrids
  USE mod_ncparam, ONLY : NV, out_lib

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

SUBROUTINE roms_fields_IO_metadata (fld, metadata)

  CLASS (roms_fields),                     intent(inout) :: fld
  TYPE (roms_field_metadata), allocatable, intent(inout) :: metadata(:)

  integer                                                :: i

  ! Extract fields I/O metadata.

  IF (.not.allocated(metadata)) THEN

    allocate ( metadata(SIZE(fld%fields)) )

    DO i = 1, SIZE(fld%fields)
      metadata(i) = fld%geom%fieldsinfo%get(fld%fields(i)%name)
    END DO

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

  ! Make sure fields have the same name, size, and shape.

  CALL self%check_congruent (rhs)

  ! Add SELF and RHS fields.

  DO i = 1, SIZE(self%fields)
    self%fields(i)%val = self%fields(i)%val + rhs%fields(i)%val
  END DO

END SUBROUTINE roms_fields_add

! ------------------------------------------------------------------------------
!> Subtract two sets of fields.

SUBROUTINE roms_fields_sub (self, rhs)

  CLASS (roms_fields), intent(inout) :: self     !< LHS Fields object
  CLASS (roms_fields), intent(in   ) :: rhs      !< RHS Fields object

  integer                            :: i

  ! Make sure fields have the same name, size, and shape.

  CALL self%check_congruent (rhs)

  ! Subtract RHS from SELF.

  DO i = 1, SIZE(self%fields)
    self%fields(i)%val = self%fields(i)%val - rhs%fields(i)%val
  END DO

END SUBROUTINE roms_fields_sub

! ------------------------------------------------------------------------------
!> Multiply a set of fields by a constant.

SUBROUTINE roms_fields_mul (self, c)

  CLASS (roms_fields),   intent(inout) :: self   !< Fields object
  real (kind=kind_real), intent(in   ) :: c      !< multiplication constant

  integer                              :: i

  DO i = 1, SIZE(self%fields)
    self%fields(i)%val = c * self%fields(i)%val
  END DO

  IF (LdebugFields .and. (self%geom%f_comm%rank() .eq. 0)) THEN
    PRINT '(a,f0.4)', 'roms_fields::mul: multiplication factor, c = ', c
  END IF

END SUBROUTINE roms_fields_mul

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

    DO j = field%Jstr, field%Jend
      DO i = field%Istr, field%Iend

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

END SUBROUTINE roms_fields_rms

! ------------------------------------------------------------------------------
!> Add two fields, multiplying the rhs first by a constant.

SUBROUTINE roms_fields_axpy (self, c, rhs)

  CLASS (roms_fields), target, intent(inout) :: self  !< LHS Fields object
  real (kind=kind_real),       intent(in   ) :: c     !< multiplication constant
  CLASS (roms_fields),         intent(in   ) :: rhs   !< RHS Fields object

  integer                                    :: i
  TYPE (roms_field),                 pointer :: f_rhs, f_lhs

  ! Make sure fields are correct shape.

  CALL self%check_subset (rhs)

  DO i = 1, SIZE(self%fields)
    f_lhs => self%fields(i)
    IF (.not. rhs%has(f_lhs%name)) CYCLE
    CALL rhs%get (f_lhs%name, f_rhs)
    f_lhs%val = f_lhs%val + c * f_rhs%val
  END DO

END SUBROUTINE roms_fields_axpy

! ------------------------------------------------------------------------------
!> Calculate the global dot-product sum of two sets of fields. Ignore land
!! points.

SUBROUTINE roms_fields_dotprod (fld1, fld2, zprod)

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

    DO j = field1%Jstr, field1%Jend
      DO i = field1%Istr, field1%Iend

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

END SUBROUTINE roms_fields_dotprod

! ------------------------------------------------------------------------------
!> Calculate global statistics for each field (min, max, average).

SUBROUTINE roms_fields_gpnorm (fld, nf, pstat)

  CLASS (roms_fields),   intent(in   ) :: fld            !> Fields object
  integer,               intent(in   ) :: nf             !> number of fields
  real (kind=kind_real), intent(inout) :: pstat(3, nf)   !> [min, max, average]

  logical                              :: mask(fld%geom%Istr:fld%geom%Iend,    &
                                               fld%geom%Jstr:fld%geom%Jend)
  integer                              :: Istr, Iend, Jstr, Jend, n
  real (kind=kind_real)                :: my_water_cells, water_cells
  real (kind=kind_real)                :: buffer(3)
  TYPE (roms_field),           pointer :: field

  ! Indices for computational domain (interior points exclude boundary values).

  Istr = fld%geom%Istr
  Iend = fld%geom%Iend
  Jstr = fld%geom%Jstr
  Jend = fld%geom%Jend

  ! Calculate global min, max, mean for each field.
 
  DO n = 1, SIZE(fld%fields)

    CALL fld%get (fld%fields(n)%name, field)

    ! Get the mask and the total number of grid cells.

    IF (.not. ASSOCIATED(field%mask)) THEN
      mask = .true.
    ELSE
      mask = field%mask(Istr:Iend,Jstr:Jend) > 0.0
    END IF
    my_water_cells = COUNT(mask)

    CALL fld%geom%f_comm%allreduce (my_water_cells, water_cells,               &
                                    fckit_mpi_sum())

    ! Calculate global min/max/mean.

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

    ! Initialize horizontal interpolation structure.

    CALL roms_field_interp_initialize (self%geom, field, interp, gtype)

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
!> Initialize a fields set by reading from an input NetCDF file if "statefile"
!! or "initial condition" has "read_from_file" set to true in the YAML
!! configuraion file.

SUBROUTINE roms_fields_read (self, f_conf, vdate)

  USE mod_ncparam, ONLY : inp_lib, io_nf90, io_pio

  CLASS (roms_fields), target, intent(inout) :: self    !< Fields object
  TYPE (fckit_configuration),  intent(in   ) :: f_conf  !< configuration
  TYPE (datetime),             intent(inout) :: vdate   !< Date and Time

  integer                                   :: InpRec, LocalPET
  real (kind=kind_real)                     :: romsDateNumber, romsTime
  character (len=:), allocatable            :: fields_dir, fields_filename
  character (len=:), allocatable            :: my_string
  character (len=21)                        :: DateString
  character (len=256)                       :: ncname, text

  ! Initialize.

  LocalPET = self%geom%f_comm%rank()   ! PET rank

  ! Get fields data directory, filename, and time record to process from
  ! configuration YAML file.

  IF (.not.f_conf%get("fields_dir", fields_dir)) THEN
    CALL abor1_ftn ("roms_fields::read: Cannot find fields directory")
  END IF

  IF (.not.f_conf%get("fields_filename", fields_filename)) THEN
    CALL abor1_ftn ("roms_fields::read: Cannot find fields input filename")
  END IF
  ncname = TRIM(fields_dir)//TRIM(fields_filename)

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

  USE mod_param,    ONLY : Ngrids
  USE mod_ncparam,  ONLY : io_nf90, io_pio

  CLASS (roms_fields), target, intent(inout) :: self    !< Fields set
  TYPE (fckit_configuration),  intent(in   ) :: f_conf  !< Configuration
  TYPE (datetime),             intent(inout) :: vdate   !< DateTime

  integer, parameter                         :: max_length = 800

  TYPE (datetime)                            :: rdate
  TYPE (duration)                            :: frequency, policy, step
  integer                                    :: LocalPET, Nrecs, model, ng
  integer                                    :: frequency_sec, policy_sec
  integer                                    :: step_sec
  integer, save                              :: out_rec
  real (kind=kind_real)                      :: romsTime(Ngrids), romsDateNumber
  character (len=256)                        :: text
  character(len=max_length)                  :: filename
  character (len=:), allocatable             :: Fpolicy, iniDate, ioFrequency

  character (len=*), parameter               :: MyFile =                       &
     &  __FILE__//", roms_fields_write"

  ! Initialize.

  LocalPET = self%geom%f_comm%rank()   ! PET rank

  romsTime = 0.0_kind_real             ! ROMS time
  model    = self%geom%model           ! ROMS numerical kernel
  ng       = self%geom%ng              ! nested grid number

  ! Inquire configuration YAML file about file policy, output data frequency,
  ! initial date.

  IF (.not.f_conf%get("file_policy", Fpolicy)) THEN
    CALL abor1_ftn ("roms_fields::write: Cannot find 'file_policy'" //         &
                    " in YAML configuration")
  END IF

  IF (.not.f_conf%get("data_frequency", ioFrequency)) THEN
    CALL abor1_ftn ("roms_fields::write: Cannot find 'data_frequency'" //      &
                    " in YAML configuration")
  END IF

  IF (.not.f_conf%get("date", iniDate)) THEN
    CALL abor1_ftn ("roms_fields::write: Cannot find 'date'" //                &
                    " in YAML configuration")
  END IF

  CALL datetime_create (iniDate, rdate)         ! initial date
  CALL datetime_diff   (vdate, rdate, step)     ! time since initial date

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

  ! Create output NetCDF file according to specified policy: a new file is
  ! created every "policy_sec" intervals.

  IF (MOD(step_sec, policy_sec) .eq. 0 .and. (out_rec .eq. 0)) THEN

    ! Generate output NetCDF filename.

    filename = roms_gen_filename(f_conf, max_length, vdate)
    self%IO(ng)%name = TRIM(filename)

    ! Set IO fields metadata.

    CALL self%IO_metadata (metadata)

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
      CALL roms_fields_write_nf90 (self, self%IO, romsTime)

#if defined PIO_LIB
    CASE (io_pio)
      CALL roms_fields_write_pio (self, self%IO, romsTime)
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

SUBROUTINE roms_fields_write_debug (self, filename, vdate)

  USE mod_param,    ONLY : Ngrids
  USE mod_ncparam,  ONLY : io_nf90, io_pio

  CLASS (roms_fields), intent(inout) :: self            !< Fields set
  character (len=*),   intent(in   ) :: filename        !< Configuration
  TYPE (datetime),     intent(in   ) :: vdate           !< DateTime

  integer                            :: LocalPET, model, ng
  real (kind=kind_real)              :: romsTime(Ngrids), romsDateNumber
  character (len=256)                :: text

  character (len=*), parameter       :: MyFile =                               &
     &  __FILE__//", roms_fields_write_debug"

  ! Initialize.

  LocalPET = self%geom%f_comm%rank()   ! PET rank

  romsTime = 0.0_kind_real             ! ROMS time
  model    = self%geom%model           ! ROMS numerical kernel
  ng       = self%geom%ng              ! nested grid number

  ! Create output NetCDF file.

  self%IO(ng)%name = TRIM(filename)

  ! Set IO fields metadata.

  CALL self%IO_metadata (metadata)

  ! Create output NetCDF. Initialize I/O structure counters.

  self%IO(ng)%Fcount=1
  self%IO(ng)%load=1
  self%IO(ng)%Rindex=0

  CALL roms_create_ncfile (ng, model, LocalPET, self%IO, metadata)

  IF (LocalPET .eq. 0) THEN
    PRINT '(3a)', "roms_fields::write_debug: created NetCDF file: '",          &
                  TRIM(self%IO(ng)%name), "'"
  END IF

  ! Set ROMS time from JEDI date in seconds since reference time and date
  ! number.

  CALL roms_date2time (LocalPET, vdate, romsTime(ng), romsDateNumber)

  ! Write out all fields using either the standard NetCDF library or the
  ! Parallel I/O (PIO) library.

  SELECT CASE (self%IO(ng)%IOtype)

    CASE (io_nf90)
      CALL roms_fields_write_nf90 (self, self%IO, romsTime)

#if defined PIO_LIB
    CASE (io_pio)
      CALL roms_fields_write_pio (self, self%IO, romsTime)
#endif

    CASE DEFAULT
      WRITE (text,'(a,i0)') &
                  'roms_fields::write_debug: Ilegal output type, io_type = ',  &
                  self%IO(ng)%IOtype
      CALL abor1_ftn (TRIM(text))

  END SELECT

  ! If last time record, close output NetCDF file.

  CALL roms_close_ncfile (ng, model, self%IO)

END SUBROUTINE roms_fields_write_debug

! ------------------------------------------------------------------------------
!> Read fields from input file using standard NetCDF library.

SUBROUTINE roms_fields_read_nf90 (self, InpRec, ncname, DateString, DateNumber)

  USE mod_ncparam,    ONLY : io_nf90
  USE mod_iounits,    ONLY : stdout
  USE mod_netcdf,     ONLY : netcdf_open, netcdf_close, netcdf_inq_var, var_id
  USE mod_scalars,    ONLY : NoError, exit_flag
  USE netcdf,         ONLY : nf90_noerr
  USE nf_fread2d_mod, ONLY : nf_fread2d
  USE nf_fread3d_mod, ONLY : nf_fread3d

  CLASS (roms_fields), target, intent(inout) :: self       !< Fields set
  integer,                     intent(in   ) :: InpRec     !< Record to read
  character (len=*),           intent(in   ) :: ncname     !< NetCDF filename
  character (len=*),           intent(in   ) :: DateString !< ISO8601 DateTime
  real (kind=kind_real),       intent(in   ) :: DateNumber !< Fields datenum

  TYPE (roms_field), pointer                 :: field
  TYPE (roms_geom), pointer                  :: geom

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

  LocalPET = geom%f_comm%rank()        !> PET rank
  model    = geom%model                !> numerical kernel
  ng       = MAX(1, geom%ng)           !> nested grid number
  scale    = 1.0_kind_real             !> scale factor for read variables
  Vsize    = 0                         !> variable dimensions

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

        CASE ('ssh', 'u2docn', 'v2docn',                                       &
              'DU_avg1', 'DV_avg1', 'DU_avg2', 'DV_avg2')      ! 2D variables

          CALL nc_err (nf_fread2d(ng, model, ncname, ncid,                     &
                                  field%metadata%io_name,                      &
                                  varid, InpRec, Cgrid, Vsize,                 &
                                  LBi, UBi, LBj, UBj,                          &
                                  scale, field%MinValue, field%MaxValue,       &
                                  field%mask,                                  &
                                  field%val(:,:,1)),                           &
                       nf90_noerr, io_nf90, __LINE__, MyFile)

          IF (LocalPET .eq. 0) THEN
            WRITE (stdout,20) field%metadata%getval_name,                      &
                              field%MinValue, field%MaxValue
          END IF

        CASE ('uocn', 'vocn', 'tocn', 'socn',                                  &
              'Kvocn', 'Ktocn', 'Ksocn')                       ! 3D variables

          CALL nc_err (nf_fread3d(ng, model, ncname, ncid,                     &
                                  self%fields(i)%metadata%io_name,             &
                                  varid, InpRec, Cgrid, Vsize,                 &
                                  LBi, UBi, LBj, UBj, LBk, UBk,                &
                                  scale, field%MinValue, field%MaxValue,       &
                                  field%mask,                                  &
                                  field%val),                                  &
                       nf90_noerr, io_nf90, __LINE__, MyFile)

          IF (LocalPET .eq. 0) THEN
            WRITE (stdout,20) field%metadata%getval_name,                      &
                              field%MinValue, field%MaxValue
          END IF

      END SELECT

      IF (.FALSE. .and. (LocalPET .eq. 0)) THEN
        PRINT '(a)',           '------------------'
        PRINT '(2(a,i0))',     'ng     = ', ng, ', tile = ' , LocalPET
        PRINT '(2(a,i0),a,a)', 'ncid   = ', ncid, ', varid  = ', varid,        &
                               ', ncname = ', TRIM(ncname)
        PRINT '(6a)',          'field  = ', field%metadata%io_name,            &
                               ' :: ', field%metadata%name,                    &
                               ' :: ', field%metadata%getval_name
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

        CASE ('ssh', 'uocn', 'vocn', 'tocn', 'socn')

          WRITE (Message,'(6a)')                                               &
                'roms_fields::read_nf90: Unable to find tate variable: ',      &
                field%name, " - ", field%metadata%getval_name,                 &
                ', file: ', TRIM(ncname)
          CALL abor1_ftn (TRIM(Message))

        CASE ('Kvocn', 'Ktocn', 'Ksocn')

          field%val = 1.0E-5_kind_real         ! vertical mixing coefficients
    
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
  20 FORMAT (24x,'- ',a,/,27x,'(Min = ',1p,e15.8,' Max = ',1p,e15.8,')')

END SUBROUTINE roms_fields_read_nf90

! ------------------------------------------------------------------------------
!> Writes fields into output file using standard NetCDF library.

SUBROUTINE roms_fields_write_nf90 (self, S, romsTime)

  USE dateclock_mod,   ONLY : datestr
  USE mod_ncparam,     ONLY : idtime, Vname
  USE mod_iounits,     ONLY : T_IO
  USE mod_netcdf,      ONLY : netcdf_inq_var, netcdf_put_fvar, netcdf_sync,    &
                              var_id
  USE mod_scalars,     ONLY : Rclock, NoError, exit_flag
  USE netcdf,          ONLY : nf90_noerr
  USE nf_fwrite2d_mod, ONLY : nf_fwrite2d
  USE nf_fwrite3d_mod, ONLY : nf_fwrite3d

  CLASS (roms_fields), target, intent(inout) :: self          !< Fields set
  TYPE (T_IO),                 intent(inout) :: S(:)          !< ROMS I/O struc
  real (kind=kind_real)                      :: romsTime(:)   !< ROMS time (s)

  TYPE (roms_field), pointer                 :: field
  TYPE (roms_geom), pointer                  :: geom
  integer                                    :: Fcount, LocalPET, lstr, lend
  integer                                    :: Cgrid, varid, vindex
  integer                                    :: i, model, ng
  integer                                    :: LBi, UBi, LBj, UBj, LBk, UBk
  real (kind=kind_real)                      :: DateNumber, scale
  character (len=22)                         :: DateString
  character (len=1024)                       :: Message

  character (len=*), parameter               :: MyFile =                       &
     &  __FILE__//", roms_fields_write_nf90"

  ! Initialize

  geom => self%geom

  LocalPET = geom%f_comm%rank()        !< PET rank
  model    = geom%model                !< ROMS numerical kernel
  ng       = geom%ng                   !< nested grid number

  IF (LdebugFields .and. (LocalPET .eq. 0)) THEN
    lstr = SCAN(S(ng)%name, '/', BACK=.TRUE.) + 1
    lend = LEN_TRIM(S(ng)%name)    
    PRINT '(2a)', 'roms_fields::write_nf90 - writing state, File = ',          &
                  S(ng)%name(lstr:lend)
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

  ! Get output fields fractional "datenum".

  DateNumber = Rclock%DateNumber(1) + romsTime(ng)/86400.0_kind_real
  CALL datestr (DateNumber, .TRUE., DateString)

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

      LBi = LBOUND(field%val, DIM=1)
      UBi = UBOUND(field%val, DIM=1)
      LBj = LBOUND(field%val, DIM=2)
      UBj = UBOUND(field%val, DIM=2)
      LBk = LBOUND(field%val, DIM=3)
      UBk = UBOUND(field%val, DIM=3)

      field%OutNCname = TRIM(S(ng)%name)
      field%OutNCid   = S(ng)%ncid
      field%OutRec    = S(ng)%Rindex

      lstr = MAX(22, LEN_TRIM(DateString))
      IF (allocated(field%DateTimeString)) THEN
        deallocate ( field%DateTimeString )
      END IF
      allocate (character(LEN=lstr) :: field%DateTimeString )
      field%DateTimeString = TRIM(DateString)

      field%DateNumber = DateNumber

      varid = var_id(vindex)                        ! NetCDF variable ID

      SELECT CASE (field%name)

        CASE ('ssh', 'u2docn', 'v2docn',                                       &
              'DU_avg1', 'DV_avg1', 'DU_avg2', 'DV_avg2')      ! 2D variables

          CALL nc_err (nf_fwrite2d(ng, model, S(ng)%ncid, varid,               &
                                   S(ng)%Rindex, Cgrid,                        &
                                   LBi, UBi, LBj, UBj, scale,                  &
                                   field%mask,                                 &
                                   field%val(:,:,1),                           &
                                   MinValue = field%MinValue,                  &
                                   MaxValue = field%MaxValue),                 &
                       nf90_noerr, io_nf90, __LINE__, MyFile)

          IF (LdebugFields .and. (LocalPET .eq. 0)) THEN
            PRINT 10, field%name, field%MinValue, field%MaxValue
          END IF

        CASE ('uocn', 'vocn', 'tocn', 'socn',                                  &
              'Kvocn', 'Ktocn', 'Ksocn')                       ! 3D variables

          CALL nc_err (nf_fwrite3d(ng, model, S(ng)%ncid, varid,               &
                                   S(ng)%Rindex, Cgrid,                        &
                                   LBi, UBi, LBj, UBj, LBk, UBk, scale,        &
                                   field%mask,                                 &
                                   field%val,                                  &
                                   MinValue = field%MinValue,                  &
                                   MaxValue = field%MaxValue),                 &
                       nf90_noerr, io_nf90, __LINE__, MyFile)

          IF (LdebugFields .and. (LocalPET .eq. 0)) THEN
            PRINT 10, field%name, field%MinValue, field%MaxValue
          END IF

      END SELECT

    ELSE

      WRITE (Message,'(4a)')                                                   &
             'roms_fields::write_nf90: Cannot find and option to write = ',    &
             field%name, " - ", field%metadata%getval_name,                    &
            ', file: ', TRIM(S(ng)%name)
      CALL abor1_ftn (TRIM(Message))

    END IF

  END DO

  ! Synchronize NetCDF to disk.

  CALL netcdf_sync (ng, model, S(ng)%name, S(ng)%ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  10 FORMAT (2x,'- ',a,':',t13,'Min = ',1p,e15.8,',  Max = ',1p,e15.8)

END SUBROUTINE roms_fields_write_nf90

#if defined PIO_LIB

! ------------------------------------------------------------------------------
!> Read fields from input file using the Parallel I/O (PIO) library.

SUBROUTINE roms_fields_read_pio (self, InpRec, ncname, DateString, DateNumber)

  USE mod_pio_netcdf

  USE mod_ncparam,    ONLY : io_pio, r2dvar, r3dvar, u2dvar, u3dvar,           &
                                                     v2dvar, v3dvar, w3dvar
  USE mod_iounits,    ONLY : stdout
  USE mod_scalars,    ONLY : NoError, exit_flag
  USE nf_fread2d_mod, ONLY : nf_fread2d
  USE nf_fread3d_mod, ONLY : nf_fread3d

  CLASS (roms_fields), target, intent(inout) :: self       !< Fields set
  integer,                     intent(in   ) :: InpRec     !< Record to read
  character (len=*),           intent(in   ) :: ncname     !< NetCDF filename
  character (len=*),           intent(in   ) :: DateString !< ISO8601 DateTime
  real (kind=kind_real)        intent(in   ) :: DateNumber !< Fields datenum


  TYPE (roms_field), pointer                 :: field
  TYPE (roms_geom), pointer                  :: geom
  TYPE (IO_desc_t), pointer                  :: ioDesc
  TYPE (My_VarDesc)                          :: pioVar

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

  LocalPET = geom%f_comm%rank()        !< PET rank
  model    = geom%model                !< numerical kernel
  ng       = MAX(1, geom%ng)           !< nested grid number
  scale    = 1.0_kind_real             !> scale factor for read variables
  Vsize    = 0                         !> variable dimensions

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

        CASE ('ssh', 'u2docn', 'v2docn',                                       &
              'DU_avg1', 'DV_avg1', 'DU_avg2', 'DV_avg2')      ! 2D variables

          CALL nc_err (nf_fread2d(ng, model, ncname, pioFile,                  &
                                  field%metadata%io_name,                      &
                                  pioVar, InpRec, ioDesc, Vsize,               &
                                  LBi, UBi, LBj, UBj,                          &
                                  scale, field%MinValue, field%MaxValue,       &
                                  field%mask,                                  &
                                  field%val(:,:,1)),                           &
                       PIO_noerr, io_pio, __LINE__, MyFile)

          IF (LocalPET .eq. 0) THEN
            WRITE (stdout,20) field%metadata%getval_name,                      &
                              field%MinValue, field%MaxValue
          END IF

        CASE ('uocn', 'vocn', 'tocn', 'socn',                                  &
              'Kvocn', 'Ktocn', 'Ksocn')                       ! 3D variables

          CALL nc_err (nf_fread3d(ng, model, ncname, pioFile,                  &
                                  field%metadata%io_name,                      &
                                  pioVar, InpRec, ioDesc, Vsize,               &
                                  LBi, UBi, LBj, UBj, LBk, UBk,                &
                                  scale, field%MinValue, field%MaxValue,       &
                                  field%mask,                                  &
                                  field%val),                                  &
                       PIO_noerr, io_pio, __LINE__, MyFile)

          IF (LocalPET .eq. 0) THEN
            WRITE (stdout,20) field%metadata%getval_name,                      &
                              field%MinValue, field%MaxValue
          END IF

      END SELECT

      IF (.FALSE. .and. (LocalPET .eq. 0)) THEN
        PRINT '(a)',           '------------------'
        PRINT '(2(a,i0))',     'ng     = ', ng, ', tile = ' , LocalPET
        PRINT '(2(a,i0),a,a)', 'ncid   = ', ncid, ', varid  = ', varid,        &
                               ', ncname = ', TRIM(ncname)
        PRINT '(6a)',          'field  = ', field%metadata%io_name,            &
                               ' :: ', field%metadata%name,                    &
                               ' :: ', field%metadata%getval_name
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

        CASE ('ssh', 'uocn', 'vocn', 'tocn', 'socn')
          WRITE (Message,'(4a)')                                               &
                'roms_fields::write_pio: Cannot find and option to read = ',   &
                field%name, " - ", field%metadata%getval_name
          CALL abor1_ftn (TRIM(Message))

        CASE ('Kvocn', 'Ktocn', 'Ksocn')

          field%val = 1.0E-5_kind_real         ! vertical mixing coefficients

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
  20 FORMAT (24x,'- ',a,/,27x,'(Min = ',1p,e15.8,' Max = ',1p,e15.8,')')

END SUBROUTINE roms_fields_read_pio

! ------------------------------------------------------------------------------
!> Writes fields into output file using Paralell I/O (PIO) library.

SUBROUTINE roms_fields_write_pio (self, S, romsTime)

  USE mod_pio_netcdf
  USE mod_ncparam
 
 USE dateclock_mod,    ONLY : datestr
  USE mod_iounits,     ONLY : T_IO
  USE mod_scalars,     ONLY : NoError, exit_flag
  USE nf_fwrite2d_mod, ONLY : nf_fwrite2d
  USE nf_fwrite3d_mod, ONLY : nf_fwrite3d

  CLASS (roms_fields), target, intent(inout) :: self         !< Fields set
  TYPE (T_IO),                 intent(inout) :: S(:)         !< ROMS I/O struc
  real (kind=kind_real)                      :: romsTime(:)  !< ROMS time (s)

  TYPE (roms_field), pointer                 :: field
  TYPE (roms_geom), pointer                  :: geom
  TYPE (IO_desc_t), pointer                  :: ioDesc
  TYPE (My_VarDesc)                          :: pioVar

  integer                                    :: Fcount, LocalPET, lstr, lend
  integer                                    :: Cgrid, fld_kind, vindex
  integer                                    :: i, model, ng
  integer                                    :: LBi, UBi, LBj, UBj, LBk, UBk
  real (kind=kind_real)                      :: DateNumber, scale
  character (len=22)                         :: DateString
  character (len=1024)                       :: Message

  character (len=*), parameter               :: MyFile =                       &
     &  __FILE__//", roms_fields_write_pio"

  ! Initialize.

  geom => self%geom

  LocalPET = geom%f_comm%rank()        !< PET rank
  model    = geom%model                !< ROMS numerical kernel
  ng       = geom%ng                   !< nested grid number

  IF (LdebugFields .and. (LocalPET .eq. 0)) THEN
    lstr = SCAN(S(ng)%name, '/', BACK=.TRUE.) + 1
    lend = LEN_TRIM(S(ng)%name)    
    PRINT '(2a)', 'roms_fields::write_pio - writing state, File = ',           &
                  S(ng)%name(lstr:lend)
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

  CALL pio_netcdf_inq_var (ng, model, S(ng)%ncname,                            &
                           piofile = pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  ! Write out all fields. ROMS needs to be compiled with MASKING to use the
  ! writing NetCDF functions below.

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

      field%OutNCname = TRIM(S(ng)%name)
      field%OutNCid   = S(ng)%pioFile%fh
      field%OutRec    = S(ng)%Rindex

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

        CASE ('ssh', 'u2docn', 'v2docn',                                       &
              'DU_avg1', 'DV_avg1', 'DU_avg2', 'DV_avg2')      ! 2D variables

          CALL nc_err (nf_fwrite2d(ng, model, S(ng)%pioFile,                   &
                                   pioVar, S(ng)%Rindex, ioDesc,               &
                                   LBi, UBi, LBj, UBj, scale,                  &
                                   field%mask,                                 &
                                   field%val(:,:,1),                           &
                                   MinValue = Fmin,                            &
                                   MaxValue = Fmax),                           &
                       PIO_noerr, io_pio, __LINE__, MyFile)

          IF (LdebugFields .and. (LocalPET .eq. 0)) THEN
            PRINT 10, field%name, Fmin, Fmax
          END IF

        CASE ('uocn', 'vocn', 'tocn', 'socn',                                  &
              'Kvocn', 'Ktocn', 'Ksocn')                       ! 3D variables

          CALL nc_err (nf_fwrite3d(ng, model, S(ng)%pioFile,                   &
                                   pioVar, S(ng)%Rindex, ioDesc,               &
                                   LBi, UBi, LBj, UBj, LBk, UBk, scale,        &
                                   field%mask,                                 &
                                   field%val,                                  &
                                   MinValue = Fmin,                            &
                                   MaxValue = Fmax),                           &
                       PIO_noerr, io_pio, __LINE__, MyFile)

          IF (LdebugFields .and. (LocalPET .eq. 0)) THEN
            PRINT 10, field%name, Fmin, Fmax
          END IF

      END SELECT

    ELSE
  
      WRITE (Message,'(4a)')                                                   &
            'roms_fields::write_pio: Cannot find and option to write = ',      &
            field%name, " - ", field%metadata%getval_name
      CALL abor1_ftn (TRIM(Message))

    END IF
    
  END DO

  ! Synchronize NetCDF to disk.

  CALL pio_netcdf_sync (ng, model, S(ng)%name, S(ng)%pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  10 FORMAT (2x,'- ',a,':',t13,'Min = ',1p,e15.8,',  Max = ',1p,e15.8)

END SUBROUTINE roms_fields_write_pio

#endif

! ------------------------------------------------------------------------------

END MODULE roms_fields_mod
