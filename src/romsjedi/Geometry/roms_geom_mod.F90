! (C) Copyright 2017-2021 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
!>
!! \brief    Geometry class for a ROMS-JEDI model/state space
!!
!! \details  This class includes several routines used to create, destroy, and
!!           clone a geometry object. It contains all the spatial coordinates
!!           (lon,lat,z) for the C-grid type fields located at the cell center
!!           (RHO-points), west and east cell edges (U-points), and southern
!!           and northern cell edges (V-points). It also includes parallel tile
!!           array-allocation and computational decomposition, land/sea masking
!!           arrays (0:land, 1:ocean), and curvilinear coordinates arrays.
!!
!! \author   Hernan G. Arango (Rutgers University)
!! \date     April 2021

MODULE roms_geom_mod

USE kinds,                      ONLY : kind_real

USE atlas_module,               ONLY : atlas_functionspace_pointcloud,       &
                                       atlas_field,                          &
                                       atlas_fieldset,                       &
                                       atlas_geometry,                       &
                                       atlas_indexkdtree,                    &
                                       atlas_integer,                        &
                                       atlas_real

USE fckit_configuration_module, ONLY : fckit_configuration
USE fckit_mpi_module,           ONLY : fckit_mpi_comm
USE fckit_log_module

USE roms_fields_metadata_mod

implicit none

PRIVATE
PUBLIC  :: roms_geom

!> Geometry data structure

TYPE :: roms_geom

  TYPE (atlas_functionspace_pointcloud) :: afunctionspace
  TYPE (fckit_mpi_comm)                 :: f_comm
  TYPE (roms_fields_metadata)           :: fieldsinfo

  logical :: EWperiodic                       ! East-West periodicity switch
  logical :: NSperiodic                       ! North-South periodicity switch

  integer :: model                            ! numerical kernel (iNLM, iTLM, iADM)
  integer :: ng                               ! nested grid number
  integer :: Lm, Mm                           ! grid global number of I- and J-points
  integer :: tile                             ! domain parallel partition tile

  integer :: NghostPoints                     ! number of tile partition ghost points
  integer :: LBi, UBi, LBj, UBj, LBk, UBk     ! array(i,j,k) allocation bounds
  integer :: N                                ! number of vertical levels at RHO-, U-, V-points

  integer :: IstrR, IendR, JstrR, JendR       ! tiled RHO-cell full indices range
  integer :: Istr,  Iend,  Jstr,  Jend        ! computational I- and J-indices range, RHO-points
  integer :: IstrU, JstrV                     ! computational starting U- and V-indices

  real (kind_real), allocatable  :: f_r(:,:)       ! Coriolis parameter (1/s), RHO-points
  real (kind_real), allocatable  :: f_u(:,:)       ! Coriolis parameter (1/s), U-points
  real (kind_real), allocatable  :: f_v(:,:)       ! Coriolis parameter (1/s), V-points

  real (kind_real), allocatable  :: h_r(:,:)       ! bathymetry (m; positive), RHO-points
  real (kind_real), allocatable  :: h_u(:,:)       ! bathymetry (m; positive), U-points
  real (kind_real), allocatable  :: h_v(:,:)       ! bathymetry (m; positive), V-points

  real (kind_real), allocatable  :: lonr(:,:)      ! longitude, RHO-points
  real (kind_real), allocatable  :: lonu(:,:)      ! longitude, U-points
  real (kind_real), allocatable  :: lonv(:,:)      ! longitude, V-points

  real (kind_real), allocatable  :: latr(:,:)      ! latitude, RHO-points
  real (kind_real), allocatable  :: latu(:,:)      ! latitude, U-points
  real (kind_real), allocatable  :: latv(:,:)      ! latitude, V-points

  real (kind_real), allocatable  :: cell_area(:,:) ! RHO-points cell area (m2)

  real (kind_real), allocatable  :: angler(:,:)    ! XI-axis and EAST RHO-angle (radians)
  real (kind_real), allocatable  :: angleu(:,:)    ! XI-axis and EAST U-angle (radians)
  real (kind_real), allocatable  :: anglev(:,:)    ! XI-axis and EAST V-angle (radians)

  real (kind_real), allocatable  :: CosAngler(:,:) ! cosine of curvilinear angle, cos(angler)
  real (kind_real), allocatable  :: SinAngler(:,:) ! sine of curvilinear angle, sin(angler)

  real (kind_real), allocatable  :: z_r(:,:,:)     ! depths at RHO-points (m, negative)
  real (kind_real), allocatable  :: z_u(:,:,:)     ! depths at U-points (m, negative)
  real (kind_real), allocatable  :: z_v(:,:,:)     ! depths at V-points (m, negative)
  real (kind_real), allocatable  :: z_w(:,:,:)     ! depths at W-points (m, negative)

  real (kind_real), allocatable  :: rmask(:,:)     ! RHO-points mask, 0=land 1=ocean
  real (kind_real), allocatable  :: umask(:,:)     ! U-points mask,   0=land 1=ocean
  real (kind_real), allocatable  :: vmask(:,:)     ! V-points mask,   0=land 1=ocean

  character (len=:), allocatable :: roms_stdinp    ! ROMS standard input filename
  character (len=:), allocatable :: project_dir    ! ROMS project directory

  CONTAINS

  PROCEDURE :: init                 => roms_geom_init
  PROCEDURE :: end                  => roms_geom_end
  PROCEDURE :: clone                => roms_geom_clone

  PROCEDURE :: set_atlas_lonlat     => roms_geom_set_atlas_lonlat
  PROCEDURE :: fill_atlas_fieldset  => roms_geom_fill_atlas_fieldset
  PROCEDURE :: atlas2struct         => roms_geom_atlas2struct
  PROCEDURE :: struct2atlas         => roms_geom_struct2atlas

END TYPE roms_geom

!> Switch for printing fields information during debugging

logical :: LdebugGeometry = .TRUE.

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
!> Setup geometry object by calling "ROMS_initialize".

SUBROUTINE roms_geom_init (self, f_conf, f_comm)

  USE mod_param
  USE mod_grid
  USE mod_iounits,     ONLY : Iname
  USE mod_scalars,     ONLY : EWperiodic, NSperiodic, NoError, exit_flag

  USE roms_kernel_mod, ONLY : ROMS_initialize

  CLASS (roms_geom),          intent(out) :: self
  TYPE (fckit_configuration), intent(in)  :: f_conf
  TYPE (fckit_mpi_comm),      intent(in)  :: f_comm

  logical, save                           :: first
  integer                                 :: i, j, k, lstr, ng, tile
  integer                                 :: MyComm
  character (len=:), allocatable          :: flds_meta, project_dir, roms_stdinp

  ! Get MPI communicator.

  MyComm = f_comm%communicator()
  tile = f_comm%rank()

  self%f_comm = f_comm
  self%tile = tile

  ! Get ROMS project directory and standard input filename from YAML file.

  IF (.not.f_conf%get("project_dir", project_dir)) THEN
    CALL abor1_ftn ("geom_init: Cannot find ROMS project directory")
  END IF
 
  lstr = LEN_TRIM(project_dir)
  IF (.not.allocated(self%project_dir)) THEN
    allocate (character(LEN=lstr) :: self%project_dir)
  END IF
  self%project_dir = TRIM(project_dir)

  IF (.not.f_conf%get("roms_stdinp", roms_stdinp)) THEN
    CALL abor1_ftn ("geom_init: Cannot find ROMS standard input file")
  END IF

  lstr = LEN_TRIM(roms_stdinp)
  IF (.not.allocated(self%roms_stdinp)) THEN
    allocate (character(LEN=lstr) :: self%roms_stdinp)
  END IF
  self%roms_stdinp = TRIM(roms_stdinp)

  ! Get YAML metadata filename and create ROMS fields metadata object.

  CALL f_conf%get_or_die ("fields metadata", flds_meta)
  CALL self%fieldsinfo%create (flds_meta)

  ! Get nested grid number from configuration YAML file.

  CALL f_conf%get_or_die("ng", ng)
  self%ng = ng

  ! ROMS initialization: read input script, allocate, initialize, and set grid.

  Iname = TRIM(project_dir)//TRIM(roms_stdinp)

  IF (.not.allocated(BOUNDS)) THEN       ! it is only called once
    first = .TRUE.
    CALL ROMS_initialize (first,                                             &
                          mpiCOMM = MyComm,                                  &
                          kernel  = iNLM)
    IF (exit_flag .ne. NoError) THEN
      CALL abor1_ftn ("geom_init: Error while calling ROMS_initialize")
    END IF
  END IF

  ! Domain decomposition ranges and indices.

  self%model = iNLM                      ! ROMS numerical kernel

  self%EWperiodic = EWperiodic(ng)       ! East-West periodicity switch
  self%NSperiodic = NSperiodic(ng)       ! North-South periodicity switch

  self%NghostPoints = NghostPoints       ! number of ghost points

  self%Lm = Lm(ng)                       ! global interior I-points
  self%Mm = Mm(ng)                       ! global interior J-points

  self%LBi = BOUNDS(ng)%LBi(tile)        ! lower bound I-dimension
  self%UBi = BOUNDS(ng)%UBi(tile)        ! upper bound I-dimension
  self%LBj = BOUNDS(ng)%LBj(tile)        ! lower bound J-dimension
  self%UBj = BOUNDS(ng)%UBj(tile)        ! upper bound J-dimension

  self%N   = N(ng)                       ! number of vertical levels
  self%LBk = 1                           ! lower bound K-dimension
  self%UBk = N(ng)                       ! upper bound K-dimension

  self%IstrR = BOUNDS(ng)%IstrR(tile)    ! full range I-starting (RHO-points)
  self%IendR = BOUNDS(ng)%IendR(tile)    ! full range I-ending   (RHO-points)
  self%JstrR = BOUNDS(ng)%JstrR(tile)    ! full range J-starting (RHO-points)
  self%JendR = BOUNDS(ng)%JendR(tile)    ! full range J-ending   (RHO-points)

  self%Istr = BOUNDS(ng)%Istr(tile)      ! full range I-starting (PSI-, U-points)
  self%Iend = BOUNDS(ng)%Iend(tile)      ! full range I-ending   (PSI-points)
  self%Jstr = BOUNDS(ng)%Jstr(tile)      ! full range J-starting (PSI-, V-points)
  self%Jend = BOUNDS(ng)%Jend(tile)      ! full range J-ending   (PSI-points)

  self%IstrU = BOUNDS(ng)%IstrU(tile)    ! computational I-starting (U-points)
  self%JstrV = BOUNDS(ng)%JstrV(tile)    ! computational J-starting (V-points)

  ! Allocate geometry arrays and initialize from ROMS GRID structure.

  CALL roms_geom_allocate (self)

  self%lonr = GRID(ng)%lonr
  self%latr = GRID(ng)%latr
  self%lonu = GRID(ng)%lonu
  self%latu = GRID(ng)%latu
  self%lonv = GRID(ng)%lonv
  self%latv = GRID(ng)%latv

  self%CosAngler = GRID(ng)%CosAngler
  self%SinAngler = GRID(ng)%SinAngler

  self%rmask = GRID(ng)%rmask
  self%umask = GRID(ng)%umask
  self%vmask = GRID(ng)%vmask

  ! Area at RHO-points. Compute over tile extend to avoid dividing by zero.

  DO j=self%JstrR,self%JendR
    DO i=self%IstrR,self%IendR
      self%cell_area(i,j) = (1.0_kind_real/GRID(ng)%pm(i,j))*                &
                            (1.0_kind_real/GRID(ng)%pn(i,j))
    END DO
  END DO

  ! Curvilinear rotation angle between XI-axis and EAST (radians).

  self%angler = GRID(ng)%angler

  DO j=self%Jstr-1,self%Jend+1
    DO i=self%IstrU-1,self%Iend+1
      self%angleu(i,j) = 0.5_kind_real*(self%angler(i-1,j)+self%angler(i,j))
    END DO
  END DO
  DO j=self%JstrV-1,self%Jend+1
    DO i=self%Istr-1,self%Iend+1
      self%anglev(i,j) = 0.5_kind_real*(self%angler(i,j-1)+self%angler(i,j))
    END DO
  END DO

  ! Coriolis parameter (1/s).

  self%f_r = GRID(ng)%f

  DO j=self%Jstr-1,self%Jend+1
    DO i=self%IstrU-1,self%Iend+1
      self%f_u(i,j) = 0.5_kind_real*(self%f_r(i-1,j)+self%f_r(i,j))
    END DO
  END DO
  DO j=self%JstrV-1,self%Jend+1
    DO i=self%Istr-1,self%Iend+1
      self%f_v(i,j) = 0.5_kind_real*(self%f_r(i,j-1)+self%f_r(i,j))
    END DO
  END DO

  ! Bathymetry (m; positive).

  self%h_r = GRID(ng)%h

  DO j=self%Jstr-1,self%Jend+1
    DO i=self%IstrU-1,self%Iend+1
      self%h_u(i,j) = 0.5_kind_real*(self%h_r(i-1,j)+self%H_r(i,j))
    END DO
  END DO
  DO j=self%JstrV-1,self%Jend+1
    DO i=self%Istr-1,self%Iend+1
      self%h_v(i,j) = 0.5_kind_real*(self%h_r(i,j-1)+self%h_r(i,j))
    END DO
  END DO

  ! Depths (m; negative).

  self%z_r = GRID(ng)%z_r
  self%z_w = GRID(ng)%z_w

  DO k=1,self%N
    DO j=self%Jstr-1,self%Jend+1
      DO i=self%IstrU-1,self%Iend+1
        self%z_u(i,j,k) = 0.5_kind_real*(self%z_r(i-1,j,k)+self%z_r(i,j,k))
      END DO
    END DO
    DO j=self%JstrV-1,self%Jend+1
      DO i=self%Istr-1,self%Iend+1
        self%z_v(i,j,k) = 0.5_kind_real*(self%z_r(i,j-1,k)+self%z_r(i,j,k))
      END DO
    END DO
  END DO

  ! Report.

  IF (LdebugGeometry) THEN
    PRINT '(a,12(a,i0),a,3(i0,1x))', 'roms_geom::init: ',                    &
                                      ' tile = ', self%tile,                 &             
                                      ', ng = ', self%ng,                    &
                                      ', LBi = ', self%LBi,                  &
                                      ', UBi = ', self%UBi,                  &
                                      ', LBj = ', self%LBj,                  &
                                      ', UBj = ', self%UBj,                  &
                                      ', LBk = ', self%LBk,                  &
                                      ', UBk = ', self%UBk,                  &
                                      ', Istr = ', self%Istr,                &
                                      ', Iend = ', self%Iend,                &
                                      ', Jstr = ', self%Jstr,                &
                                      ', Jend = ', self%Jend,                &
                                      ', SHAPE = ', SHAPE(self%z_r)
    CALL self%f_comm%barrier()
  END IF

END SUBROUTINE roms_geom_init

! ------------------------------------------------------------------------------
!> Geometry object destructor: deallocate all arrays.

SUBROUTINE roms_geom_end (self)

  CLASS (roms_geom), intent(out)  :: self

  IF (allocated(self%f_r))        deallocate (self%f_r)
  IF (allocated(self%f_u))        deallocate (self%f_u)
  IF (allocated(self%f_v))        deallocate (self%f_v)

  IF (allocated(self%h_r))        deallocate (self%h_r)
  IF (allocated(self%h_u))        deallocate (self%h_u)
  IF (allocated(self%h_v))        deallocate (self%h_v)

  IF (allocated(self%lonr))       deallocate (self%lonr)
  IF (allocated(self%latr))       deallocate (self%latr)
  IF (allocated(self%lonu))       deallocate (self%lonu)
  IF (allocated(self%latu))       deallocate (self%latu)
  IF (allocated(self%lonv))       deallocate (self%lonv)
  IF (allocated(self%latv))       deallocate (self%latv)

  IF (allocated(self%angler))     deallocate (self%angler)
  IF (allocated(self%angleu))     deallocate (self%angleu)
  IF (allocated(self%anglev))     deallocate (self%anglev)

  IF (allocated(self%cell_area))  deallocate (self%cell_area)

  IF (allocated(self%CosAngler))  deallocate (self%CosAngler)
  IF (allocated(self%SinAngler))  deallocate (self%SinAngler)

  IF (allocated(self%rmask))      deallocate (self%rmask)
  IF (allocated(self%umask))      deallocate (self%umask)
  IF (allocated(self%vmask))      deallocate (self%vmask)

  IF (allocated(self%z_r))        deallocate (self%z_r)
  IF (allocated(self%z_u))        deallocate (self%z_u)
  IF (allocated(self%z_v))        deallocate (self%z_v)
  IF (allocated(self%z_w))        deallocate (self%z_w)

END SUBROUTINE roms_geom_end

! ------------------------------------------------------------------------------
!> Clone geometry object, self = other.

SUBROUTINE roms_geom_clone (self, other)

  CLASS (roms_geom), intent(inout) :: self
  CLASS (roms_geom), intent(in   ) :: other

  ! Clone communicator.

  self%f_comm = other%f_comm

  ! Clone object parameters, domain bounds, and range indices.

  self%ng   = other%ng
  self%tile = other%tile
  self%NghostPoints = other%NghostPoints

  self%project_dir = other%project_dir
  self%roms_stdinp = other%roms_stdinp
  self%fieldsinfo  = other%fieldsinfo

  self%model = other%model

  self%EWperiodic = other%EWperiodic
  self%NSperiodic = other%NSperiodic

  self%Lm = other%Lm
  self%Mm = other%Mm

  self%LBi = other%LBi
  self%UBi = other%UBi
  self%LBj = other%LBj
  self%UBj = other%UBj

  self%N   = other%N
  self%LBk = other%LBk
  self%UBk = other%UBk

  self%IstrR = other%IstrR
  self%IendR = other%IendR
  self%JstrR = other%JstrR
  self%JendR = other%JendR

  self%Istr  = other%Istr
  self%Iend  = other%Iend
  self%Jstr  = other%Jstr
  self%Jend  = other%Jend

  self%IstrU = other%IstrU
  self%JstrV = other%JstrV

  ! Clone geometry arrays.

  CALL roms_geom_allocate (self)

  self%f_r = other%f_r
  self%f_u = other%f_u
  self%f_v = other%f_v

  self%h_r = other%h_r
  self%h_u = other%h_u
  self%h_v = other%h_v

  self%lonr = other%lonr
  self%latr = other%latr
  self%lonu = other%lonu
  self%latu = other%latu
  self%lonv = other%lonv
  self%latv = other%latv

  self%angler = other%angler
  self%angleu = other%angleu
  self%anglev = other%anglev

  self%cell_area = other%cell_area

  self%CosAngler = other%CosAngler
  self%SinAngler = other%SinAngler

  self%rmask = other%rmask
  self%umask = other%umask
  self%vmask = other%vmask

  self%z_r = other%z_r
  self%z_u = other%z_u
  self%z_v = other%z_v
  self%z_w = other%z_w

  ! Clone fields metadata.

  CALL other%fieldsinfo%clone (self%fieldsinfo)

  ! Report.

  IF (LdebugGeometry) THEN
    PRINT '(a,12(a,i0),a,3(i0,1x))', 'roms_geom::clone: ',                   &
                                    ' tile = ', self%tile,                   &
                                    ', ng = ', self%ng,                      &
                                    ', LBi = ', self%LBi,                    &
                                    ', UBi = ', self%UBi,                    &
                                    ', LBj = ', self%LBj,                    &
                                    ', UBj = ', self%UBj,                    &
                                    ', LBk = ', self%LBk,                    &
                                    ', UBk = ', self%UBk,                    &
                                    ', Istr = ', self%Istr,                  &
                                    ', Iend = ', self%Iend,                  &
                                    ', Jstr = ', self%Jstr,                  &
                                    ', Jend = ', self%Jend,                  &
                                    ', SHAPE = ', SHAPE(self%z_r)
    CALL self%f_comm%barrier() 
  END IF

END SUBROUTINE roms_geom_clone

! ------------------------------------------------------------------------------
!> Allocate geometry object arrays.

SUBROUTINE roms_geom_allocate (self)

  CLASS (roms_geom), intent(inout) :: self

  integer :: LBi, UBi, LBj, UBj, LBk, UBk

  ! Allocate and initialize geometry arrays.

  LBi = self%LBi
  UBi = self%UBi
  LBj = self%LBj
  UBj = self%UBj
  LBk = self%LBk
  UBk = self%UBk

  allocate (self%f_r(LBi:UBi, LBj:UBj));            self%f_r = 0.0_kind_real
  allocate (self%f_u(LBi:UBi, LBj:UBj));            self%f_u = 0.0_kind_real
  allocate (self%f_v(LBi:UBi, LBj:UBj));            self%f_v = 0.0_kind_real

  allocate (self%h_r(LBi:UBi, LBj:UBj));            self%h_r = 0.0_kind_real
  allocate (self%h_u(LBi:UBi, LBj:UBj));            self%h_u = 0.0_kind_real
  allocate (self%h_v(LBi:UBi, LBj:UBj));            self%h_v = 0.0_kind_real

  allocate (self%lonr(LBi:UBi, LBj:UBj));           self%lonr = 0.0_kind_real
  allocate (self%latr(LBi:UBi, LBj:UBj));           self%latr = 0.0_kind_real
  allocate (self%lonu(LBi:UBi, LBj:UBj));           self%lonu = 0.0_kind_real
  allocate (self%latu(LBi:UBi, LBj:UBj));           self%latu = 0.0_kind_real
  allocate (self%lonv(LBi:UBi, LBj:UBj));           self%lonv = 0.0_kind_real
  allocate (self%latv(LBi:UBi, LBj:UBj));           self%latv = 0.0_kind_real

  allocate (self%angler(LBi:UBi, LBj:UBj));         self%angler = 0.0_kind_real
  allocate (self%angleu(LBi:UBi, LBj:UBj));         self%angleu = 0.0_kind_real
  allocate (self%anglev(LBi:UBi, LBj:UBj));         self%anglev = 0.0_kind_real

  allocate (self%cell_area(LBi:UBi, LBj:UBj));      self%cell_area = 0.0_kind_real

  allocate (self%CosAngler(LBi:UBi, LBj:UBj));      self%CosAngler = 0.0_kind_real
  allocate (self%SinAngler(LBi:UBi, LBj:UBj));      self%SinAngler = 0.0_kind_real

  allocate (self%rmask(LBi:UBi, LBj:UBj));          self%rmask = 0.0_kind_real
  allocate (self%umask(LBi:UBi, LBj:UBj));          self%umask = 0.0_kind_real
  allocate (self%vmask(LBi:UBi, LBj:UBj));          self%vmask = 0.0_kind_real

  allocate (self%z_r(LBi:UBi, LBj:UBj, LBk:UBk));   self%z_r = 0.0_kind_real
  allocate (self%z_u(LBi:UBi, LBj:UBj, LBk:UBk));   self%z_u = 0.0_kind_real
  allocate (self%z_v(LBi:UBi, LBj:UBj, LBk:UBk));   self%z_v = 0.0_kind_real
  allocate (self%z_w(LBi:UBi, LBj:UBj,   0:UBk));   self%z_w = 0.0_kind_real

END SUBROUTINE roms_geom_allocate

! ------------------------------------------------------------------------------
!> Set ATLAS **lonlat** fieldset at density points.

SUBROUTINE roms_geom_set_atlas_lonlat (self, afieldset)

  CLASS (roms_geom),     intent(inout) :: self        !< Geometry object
  TYPE (atlas_fieldset), intent(inout) :: afieldset   !< ATLAS fieldset

  TYPE (atlas_field)                   :: afield
  integer                              :: Istr, Iend, Jstr, Jend
  real (kind_real), pointer            :: r_ptr(:,:)

  ! Create lon/lat fields at RHO (density) points. Currently, ATLAS allows a
  ! single function space which is problematic with staggered C-grids. That
  ! is, ATLAS assumes that all the variables are at the same location.

  Istr = self%IstrR
  Iend = self%IendR
  Jstr = self%JstrR
  Jend = self%JendR

  afield = atlas_field(name="lonlat",                                        &
                       kind=atlas_real(kind_real),                           &
                       shape=(/2,(Iend-Istr+1)*(Jend-Jstr+1)/))

  CALL afield%data (r_ptr)

  r_ptr(1,:) = PACK(self%lonr(Istr:Iend,Jstr:Jend), .TRUE.)
  r_ptr(2,:) = PACK(self%latr(Istr:Iend,Jstr:Jend), .TRUE.)

  CALL afieldset%add (afield)

END SUBROUTINE roms_geom_set_atlas_lonlat

! ------------------------------------------------------------------------------
!> Fill ATLAS fieldset with cell area, vertical level units, and geographical
!! mask at density points.

SUBROUTINE roms_geom_fill_atlas_fieldset (self, afieldset)

  CLASS (roms_geom),     intent(inout) :: self         !< Geometry object
  TYPE (atlas_fieldset), intent(inout) :: afieldset    !< ATLAS fieldset

  TYPE (atlas_field)                   :: afield
  integer                              :: Istr, Iend, Jstr, Jend, N
  integer                              :: k
  integer, pointer                     :: i_ptr(:,:)
  real (kind_real), pointer            :: r_ptr_1(:), r_ptr_2(:,:)

  ! Initialize. Currently, ATLAS allows a single function space which is
  ! problematic with staggered C-grids. That is, ATLAS assumes that all
  ! the variables are at the same location.

  Istr = self%IstrR
  Iend = self%IendR
  Jstr = self%JstrR
  Jend = self%JendR
  N    = self%N

  ! Add grid cell area at RHO-points.

  afield = self%afunctionspace%create_field(name='area',                     &
                                            kind=atlas_real(kind_real),      &
                                            levels=0)
  CALL afield%data (r_ptr_1)
  r_ptr_1 = PACK(self%cell_area(Istr:Iend,Jstr:Jend), .TRUE.)
  CALL afieldset%add (afield)
  CALL afield%final ()

  ! Add vertical level unit.

  afield = self%afunctionspace%create_field(name='vunit',                    &
                                            kind=atlas_real(kind_real),      &
                                            levels=N)

  CALL afield%data (r_ptr_2)
  DO k = 1, self%N
    r_ptr_2(k,:) = REAL(k, kind_real)
  END DO
  CALL afieldset%add (afield)
  CALL afield%final ()

  ! Add geographical land/sea mask at RHO-points.

  afield = self%afunctionspace%create_field(name='gmask',                    &
                                            kind=atlas_integer(KIND(0)),     &
                                            levels=N)
  CALL afield%data (i_ptr)
  DO k = 1,self%N
    i_ptr(k,:) = INT(PACK(self%rmask(Istr:Iend,Jstr:Jend), .TRUE.))
  END DO
  CALL afieldset%add (afield)
  CALL afield%final ()

END SUBROUTINE roms_geom_fill_atlas_fieldset

! ------------------------------------------------------------------------------
!> Copy a structured field from an ATLAS fieldset

SUBROUTINE roms_geom_atlas2struct (self, dx_struct, dx_atlas)

  CLASS (roms_geom),     intent(in   ) :: self            !< Geometry object
  real (kind=kind_real), intent(inout) :: dx_struct(:,:)  !< structured field
  TYPE (atlas_fieldset), intent(inout) :: dx_atlas        !< ATLAS fieldset

  TYPE (atlas_field)                   :: afield
  logical, allocatable                 :: fmask(:,:)
  integer                              :: Istr, Iend, Jstr, Jend
  real (kind_real), pointer            :: r_ptr(:)

  ! Initialize. Currently, ATLAS allows a single function space which is
  ! problematic with staggered C-grids. That is, ATLAS assumes that all
  ! the variables are at the same location.

  Istr = self%IstrR
  Iend = self%IendR
  Jstr = self%JstrR
  Jend = self%JendR

  allocate ( fmask(Istr:Iend, Jstr:Jend) )
  fmask = .TRUE.

  ! Unpack field from ATLAS.

  afield = dx_atlas%field('var')
  CALL afield%data (r_ptr)
  dx_struct(Istr:Iend, Jstr:Jend) = UNPACK(r_ptr, fmask,                     &
                                           dx_struct(Istr:Iend, Jstr:Jend))
  CALL afield%final ()

  deallocate ( fmask )

END SUBROUTINE roms_geom_atlas2struct

! ------------------------------------------------------------------------------
!> Copy a structured field into an ATLAS fieldset.

SUBROUTINE roms_geom_struct2atlas (self, dx_struct, dx_atlas)

  CLASS (roms_geom),     intent(in ) :: self              !< Geometry object
  real (kind=kind_real), intent(in ) :: dx_struct(:,:)    !< structured field
  TYPE (atlas_fieldset), intent(out) :: dx_atlas          !< ATLAS fieldset

  TYPE (atlas_field)                 :: afield
  integer                            :: Istr, Iend, Jstr, Jend
  real (kind_real), pointer          :: r_ptr(:)

  ! Initialize. Currently, ATLAS allows a single function space which is
  ! problematic with staggered C-grids. That is, ATLAS assumes that all
  ! the variables are at the same location.

  Istr = self%IstrR
  Iend = self%IendR
  Jstr = self%JstrR
  Jend = self%JendR

  ! Add structured field to ATLAS.

  dx_atlas = atlas_fieldset()
  afield = self%afunctionspace%create_field('var',                           &
                                            kind=atlas_real(kind_real),      &
                                            levels=0)

  CALL dx_atlas%add (afield)
  CALL afield%data (r_ptr)
  r_ptr = PACK(dx_struct(Istr:Iend,Jstr:Jend), .TRUE.)
  CALL afield%final ()

END SUBROUTINE roms_geom_struct2atlas

! ------------------------------------------------------------------------------

END MODULE roms_geom_mod
