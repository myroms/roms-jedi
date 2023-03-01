! (C) Copyright 2017-2023 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://Qwww.apache.org/licenses/LICENSE-2.0.
!
!>
!! \brief   **Field Class** for ROMS state vector
!!
!! \details This class includes several routines used to clone, copy, destroy,
!!          and other operators to manipulate a single field in the state
!!          vector. It is one of the elementary classes for JEDI model agnostic
!!          data assimilation algorithms.
!!
!! \author  Hernan G. Arango (Rutgers University)
!! \date    June 2021

MODULE roms_field_mod

USE fckit_log_module,           ONLY : fckit_log
USE fckit_mpi_module,           ONLY : fckit_mpi_comm,                         &
                                       fckit_mpi_min,                          &
                                       fckit_mpi_max
USE kinds,                      ONLY : kind_real

USE roms_interpolate_mod,       ONLY : roms_interp_type,                       &
                                       roms_interp_delete,                     &
                                       roms_interp_fractional,                 &
                                       roms_horiz_interp
USE mod_scalars,                ONLY : NoError, exit_flag

USE roms_fields_metadata_mod,   ONLY : roms_field_metadata
USE roms_geom_mod,              ONLY : roms_geom,                              &
                                       roms_tile

implicit none

! ------------------------------------------------------------------------------
!> Structure holds all data and metadata related to a single field variable.
! ------------------------------------------------------------------------------

TYPE, PUBLIC :: roms_field

  logical                            :: IsAdjointField       !< Halo switch
  logical                            :: UpdatedHalo          !< Updated switch

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
  
  character (len=20)                 :: interp_type = "nearest"

  TYPE (roms_tile)                   :: bounds               !< tile indices

  TYPE (roms_field_metadata)         :: metadata             !< metadata from
                                                             !< YAML config file
  CONTAINS
  
  PROCEDURE :: clone             => roms_field_clone
  PROCEDURE :: copy              => roms_field_copy
  PROCEDURE :: delete            => roms_field_delete

  PROCEDURE :: check_congruent   => roms_field_check_congruent
  PROCEDURE :: update_halo       => roms_field_update_halo
  PROCEDURE :: interp_initialize => roms_field_interp_initialize

  PROCEDURE :: stencil_interp    => roms_field_stencil_interp

  PROCEDURE :: io_has_var        => roms_field_io_has_var
  PROCEDURE :: stats             => roms_field_stats

END TYPE roms_field

! ------------------------------------------------------------------------------

PRIVATE

! Switch for printing fields information during debugging.

logical :: LdebugField = .FALSE.

! Local MPI communicator.

TYPE (fckit_mpi_comm) :: my_comm

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
!> Clone field object, self = other.

SUBROUTINE roms_field_clone (self, other)

  CLASS (roms_field), intent(inout) :: self      !< LHS Field object
  TYPE (roms_field),  intent(in   ) :: other     !< RHS Field object

  integer                           :: lstr
  integer                           :: IstrD, IendD, JstrD, JendD
  integer                           :: LBi, UBi, LBj, UBj, LBk, UBk

  ! Clone field object parameters.

  self%IsAdjointField = other%IsAdjointField
  self%UpdatedHalo    = .FALSE.

  self%bounds         = other%bounds
  self%N              = other%N

  self%CheckSum       = other%CheckSum
  self%DateNumber     = other%DateNumber
  self%MinValue       = other%MinValue
  self%MaxValue       = other%MaxValue
  self%spval          = other%spval

  self%metadata       = other%metadata

  ! Clone field string properties.

  IF (allocated(self%name)) THEN
    deallocate ( self%name )
  END IF
  IF (allocated(other%name)) THEN
    lstr = MAX(21, LEN_TRIM(other%name))
    allocate ( character(LEN=lstr) :: self%name )
    self%name = TRIM(other%name)
  END IF

  IF (allocated(self%DateTimeString)) THEN
    deallocate ( self%DateTimeString )
  END IF
  IF (allocated(other%DateTimeString)) THEN
    lstr = MAX(21, LEN_TRIM(other%DateTimeString))
    allocate ( character(LEN=lstr) :: self%DateTimeString )
    self%DateTimeString = TRIM(other%DateTimeString)
  END IF

  IF (allocated(self%InpNCname)) THEN
    deallocate ( self%InpNCname )
  END IF
  IF (allocated(other%InpNCname)) THEN
    lstr = LEN_TRIM(other%InpNCname)
    allocate ( character(LEN=lstr) :: self%InpNCname )
    self%InpNCname = TRIM(other%InpNCname)
  END IF

  IF (allocated(self%OutNCname)) THEN
    deallocate ( self%OutNCname )
  END IF
  IF (allocated(other%OutNCname)) THEN
    lstr = LEN_TRIM(other%OutNCname)
    allocate ( character(LEN=lstr) :: self%OutNCname )
    self%OutNCname = TRIM(other%OutNCname)
  END IF

  ! Clone field object properties.

  self%angle = other%angle
  self%lon   = other%lon
  self%lat   = other%lat
  self%mask  = other%mask

  ! Clone field values.

  IstrD = other%bounds%IstrD
  IendD = other%bounds%IendD
  JstrD = other%bounds%JstrD
  JendD = other%bounds%JendD

  IF (.not.allocated(self%val)) THEN
    LBi = LBOUND(other%val, DIM=1)
    UBi = UBOUND(other%val, DIM=1)
    LBj = LBOUND(other%val, DIM=2)
    UBj = UBOUND(other%val, DIM=2)
    LBk = LBOUND(other%val, DIM=3)
    UBk = UBOUND(other%val, DIM=3)

    allocate ( self%val(LBi:UBi, LBj:UBj, LBk:UBk) )
  END IF

  self%val = 0.0_kind_real

  self%val(IstrD:IendD, JstrD:JendD, :) = other%val(IstrD:IendD, JstrD:JendD, :)

END SUBROUTINE roms_field_clone

! ------------------------------------------------------------------------------
!> Copy a field from RHS to SELF. SELF must be allocated first. The pointers
!  (mask, lat, lon) will be different, but should NOT be changed to point to
!  RHS pointers. Bad things will happen.

SUBROUTINE roms_field_copy (self, rhs)

  CLASS (roms_field), intent(inout) :: self      !< LHS Field object
  TYPE (roms_field),  intent(in   ) :: rhs       !< RHS Field object

  integer                           :: lstr
  integer                           :: LBi, UBi, LBj, UBj, N

  IF (LdebugField .and. (my_comm%rank() .eq. 0)) THEN
    PRINT '(9a,5(a,i0))', 'ROMS_DEBUG roms_field::copy: Processing RHS - ',    &
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

  self%IsAdjointField = rhs%IsAdjointField
  self%UpdatedHalo    = rhs%UpdatedHalo

  self%DateNumber     = rhs%DateNumber

  self%InpNCid        = rhs%InpNCid
  self%OutNCid        = rhs%OutNCid
  self%InpRec         = rhs%InpRec
  self%OutRec         = rhs%OutRec

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
!> It destroys/deallocates field object.

SUBROUTINE roms_field_delete (self)

  CLASS (roms_field), intent(inout) :: self      !< Field object

  IF (LdebugField .and. (my_comm%rank() .eq. 0)) THEN
    PRINT '(2a,a5,5(a,i0))', 'ROMS_DEBUG roms_field::delete:',                 &
                             ', variable = ', self%metadata%io_name,           &
                             '  LBi = ', LBOUND(self%val,DIM=1),               &
                             ', UBi = ', UBOUND(self%val,DIM=1),               &
                             ', LBj = ', LBOUND(self%val,DIM=2),               &
                             ', UBj = ', UBOUND(self%val,DIM=2),               &
                             ', N = ',   UBOUND(self%val,DIM=3)
  END IF

  self%IsAdjointField = .FALSE.
  self%UpdatedHalo    = .FALSE.

  nullify (self%angle)
  nullify (self%lon)
  nullify (self%lat)
  nullify (self%mask)

  IF (allocated(self%val))                                                     &
    deallocate (self%val)
  IF (allocated(self%name))                                                    &
    deallocate (self%name) 
  IF (allocated(self%DateTimeString))                                          &
    deallocate (self%DateTimeString)
  IF (allocated(self%InpNCname))                                               &
    deallocate (self%InpNCname)
  IF (allocated(self%OutNCname))                                               &
    deallocate (self%OutNCname)

  IF (allocated(self%metadata%levels))                                         &
    deallocate (self%metadata%levels)
  IF (allocated(self%metadata%name))                                           &
    deallocate (self%metadata%name)
  IF (allocated(self%metadata%getval_name))                                    &
    deallocate (self%metadata%getval_name)
  IF (allocated(self%metadata%getval_name_surface))                            &
    deallocate (self%metadata%getval_name_surface)
  IF (allocated(self%metadata%io_file))                                        &
    deallocate (self%metadata%io_file)
  IF (allocated(self%metadata%io_name))                                        &
    deallocate (self%metadata%io_name)
  IF (allocated(self%metadata%property))                                       &
    deallocate (self%metadata%property)

END SUBROUTINE roms_field_delete

! ------------------------------------------------------------------------------
!> Make sure the two fields are the same in terms of name, size, and shape.

SUBROUTINE roms_field_check_congruent (self, rhs)

  CLASS (roms_field), intent(in) :: self         !< LHS Field object
  TYPE (roms_field),  intent(in) :: rhs          !< RHS Field object

  integer                        :: i
  character (len=1)              :: mydim
  character (len=4)              :: self_N, rhs_N

  IF (self%N .ne. rhs%N) THEN
    WRITE (self_N,'(i0)') self%N
    WRITE (rhs_N ,'(i0)') rhs%N
    CALL abor1_ftn ("roms_field::check_congruent: '" // self%name //           &
                    "', third dimension self%N = " // TRIM(self_N) //          &
                    " is unequal to '" // rhs%name // "' rhs%N = " //          &
                    TRIM(rhs_N))
  END IF

  IF (self%metadata%name .ne. rhs%metadata%name) THEN
    CALL abor1_ftn ("roms_field:::check_congruent: '"                          &
                    // self%metadata%name //                                   &
                    "', variable name self%metadata%name unequal '"            &
                    // rhs%metadata%name //                                    &
                    "' rhs%metadata%name, and possible metadata is different")
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

  USE mp_exchange_mod, ONLY : ad_mp_exchange2d, ad_mp_exchange3d,              &
                              mp_exchange2d, mp_exchange3d
  USE mod_param,       ONLY : iADM, iNLM

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

  IF (self%IsAdjointField .and. (.not.self%UpdatedHalo)) THEN

    ! Tile halo exchange for adjoint field. It needs to be done only once!
    ! Otherwise, it accumulates values at ghost points from previous exchange.

    IF (self%N .eq. 1) THEN
      CALL ad_mp_exchange2d (ng, tile, iADM, 1, LBi, UBi, LBj, UBj,            &
                             NghostPoints, EWperiodic, NSperiodic,             &
                             self%val(:,:,1))
    ELSE
       CALL ad_mp_exchange3d (ng, tile, iADM, 1, LBi, UBi, LBj, UBj, LBk, UBk, &
                              NghostPoints, EWperiodic, NSperiodic,            &
                              self%val)
    END IF
    self%UpdatedHalo = .TRUE.

  ELSE

    ! Tile halo exchange for nonlinear or tangent linear field.

    IF (self%N .eq. 1) THEN
      CALL mp_exchange2d (ng, tile, iNLM, 1, LBi, UBi, LBj, UBj,               &
                          NghostPoints, EWperiodic, NSperiodic,                &
                          self%val(:,:,1))
    ELSE
       CALL mp_exchange3d (ng, tile, iNLM, 1, LBi, UBi, LBj, UBj, LBk, UBk,    &
                           NghostPoints, EWperiodic, NSperiodic,               &
                           self%val)
    END IF
    self%UpdatedHalo = .TRUE.

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

SUBROUTINE roms_field_interp_initialize (self, interp, geom, gtype)

  USE mod_ncparam, ONLY : r2dvar, u2dvar, v2dvar

  CLASS (roms_field),      intent(inout) :: self      !< source Field object
  TYPE (roms_interp_type), intent(inout) :: interp    !< Interpolation object
  TYPE (roms_geom),        intent(in   ) :: geom      !< Geometry object
  character (len=*),       intent(in   ) :: gtype     !< C-grid location

  integer                                :: LBi, UBi, LBj, UBj

  ! If applicable, deallocate interpolation structure.

  IF (allocated(interp%lon_src)) THEN
    CALL roms_interp_delete (interp)
  END IF

  ! Allocate and assign source grid component arrays.

  LBi = LBOUND(self%lon, DIM=1)
  UBi = UBOUND(self%lon, DIM=1)
  LBj = LBOUND(self%lon, DIM=2)
  UBj = UBOUND(self%lon, DIM=2)

  allocate ( interp%lon_src(LBi:UBi,LBj:UBj) )
  allocate ( interp%lat_src(LBi:UBi,LBj:UBj) )
  allocate ( interp%angle_src(LBi:UBi,LBj:UBj) )
  allocate ( interp%mask_src(LBi:UBi,LBj:UBj) )

  interp%ng = geom%ng
  interp%model = geom%model

  interp%lon_src   = self%lon
  interp%lat_src   = self%lat
  interp%angle_src = self%angle
  interp%mask_src  = self%mask

  interp%LBi_src   = LBi
  interp%UBi_src   = UBi
  interp%LBj_src   = LBi
  interp%UBj_src   = UBi

  interp%Istr_src  = self%bounds%IstrD
  interp%Iend_src  = self%bounds%IendD
  interp%Jstr_src  = self%bounds%JstrD
  interp%Jend_src  = self%bounds%JendD

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
    CASE ('r', 'R', 'w', 'W')                           !< RHO-points
      interp%Istr_dst = geom%bounds(r2dvar)%IstrD
      interp%Iend_dst = geom%bounds(r2dvar)%IendD
      interp%Jstr_dst = geom%bounds(r2dvar)%JstrD
      interp%Jend_dst = geom%bounds(r2dvar)%JendD
      interp%lon_dst  = geom%lonr
      interp%lat_dst  = geom%latr
      interp%mask_dst = geom%rmask
    CASE ('u', 'U')                                     !< U-points
      interp%Istr_dst = geom%bounds(u2dvar)%IstrD
      interp%Iend_dst = geom%bounds(u2dvar)%IendD
      interp%Jstr_dst = geom%bounds(u2dvar)%JstrD
      interp%Jend_dst = geom%bounds(u2dvar)%JendD
      interp%lon_dst  = geom%lonu
      interp%lat_dst  = geom%latu
      interp%mask_dst = geom%umask
    CASE ('v', 'V')                                     !< V-points
      interp%Istr_dst = geom%bounds(v2dvar)%IstrD
      interp%Iend_dst = geom%bounds(v2dvar)%IendD
      interp%Jstr_dst = geom%bounds(v2dvar)%JstrD
      interp%Jend_dst = geom%bounds(v2dvar)%JendD
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
  integer                             :: IstrD, IendD, JstrD, JendD, LBk, UBk
  integer                             :: Npts, k
  integer (kind=SELECTED_INT_KIND(8)) :: checksum
  real (kind=kind_real),      pointer :: Cwrk(:)
  real (kind=kind_real),  allocatable :: buffer(:,:)
  real (kind=kind_real)               :: stats(3)

  ! Initialize.

  IstrD = self%bounds%IstrD
  IendD = self%bounds%IendD
  JstrD = self%bounds%JstrD
  JendD = self%bounds%JendD
  LBk   = LBOUND(self%val, DIM=3)
  UBk   = UBOUND(self%val, DIM=3)
  Npts  = (IendD-IstrD+1)*(JendD-JstrD+1)*(UBk-LBk+1)

  ! Get the mask and the total number of grid cells.

  allocate ( mask(IstrD:IendD, JstrD:JendD) )

  IF (.not. ASSOCIATED(self%mask)) THEN
    mask = .true.
  ELSE
    mask = self%mask(IstrD:IendD, JstrD:JendD) > 0.0_kind_real
  END IF

  ! Compute field statistics.

  allocate ( buffer(2,LBk:UBk) )

  DO k = LBk, UBK
    buffer(1,k) = MINVAL(self%val(IstrD:IendD, JstrD:JendD, k), MASK=mask)
    buffer(2,k) = MAXVAL(self%val(IstrD:IendD, JstrD:JendD, k), MASK=mask)
  END DO

  stats(1) = MINVAL(buffer(1,:))
  stats(2) = MAXVAL(buffer(2,:))

  ! Global reductions

  CALL my_comm%allreduce (stats(1), fstats(1), fckit_mpi_min())
  CALL my_comm%allreduce (stats(2), fstats(2), fckit_mpi_max())

  ! Compute order invariant 'checksum'.

  IF (.not.associated(Cwrk)) allocate ( Cwrk(Npts) )
  Cwrk = PACK(self%val(IstrD:IendD, JstrD:JendD, LBk:UBk), .TRUE.)
  CALL get_hash (Cwrk, Npts, checksum, .TRUE.)
  IF (associated(Cwrk)) deallocate (Cwrk)  

  fstats(3) = REAL(checksum, KIND=kind_real)

  ! Deallocate.

  IF (allocated(mask)) deallocate (mask)

END SUBROUTINE roms_field_stats

! ------------------------------------------------------------------------------

END MODULE roms_field_mod
