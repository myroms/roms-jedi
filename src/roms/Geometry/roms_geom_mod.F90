! (C) Copyright 2017-2020 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
! Hernan G. Arango, Rutgers University, Apr 2021

MODULE roms_geom_mod

USE kinds,                      ONLY : kind_real
USE fckit_configuration_module, ONLY : fckit_configuration
USE fckit_mpi_module,           ONLY : fckit_mpi_comm
USE fckit_log_module

implicit none

PRIVATE
PUBLIC  :: roms_geom

!> Geometry data structure

TYPE :: roms_geom

  TYPE (fckit_mpi_comm) :: f_comm

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
  integer :: Istr,  Iend,  Jstr,  Jend        ! computational I- and J-indices range at RHO-points
  integer :: IstrU, JstrV                     ! computational starting U- and V-indices

  real(kind=kind_real), allocatable, dimension(:,:) :: lonr, latr ! RHO-longitude, RHO-latitude
  real(kind=kind_real), allocatable, dimension(:,:) :: lonu, latu ! U-longitude, U-latitude
  real(kind=kind_real), allocatable, dimension(:,:) :: lonv, latv ! V-longitude, V-latitude

  real(kind=kind_real), allocatable, dimension(:,:) :: angler     ! RHO-angle between XI-axis and EAST (radians)
  real(kind=kind_real), allocatable, dimension(:,:) :: angleu     ! U-angle between XI-axis and EAST (radians)
  real(kind=kind_real), allocatable, dimension(:,:) :: anglev     ! V-angle between XI-axis and EAST (radians)

  real(kind=kind_real), allocatable, dimension(:,:) :: CosAngler  ! cosine of curvilinear angle, cos(angler)
  real(kind=kind_real), allocatable, dimension(:,:) :: SinAngler  ! sine of curvilinear angle, sin(angler)

  real(kind=kind_real), allocatable, dimension(:,:,:) :: z_r  ! depths at RHO-points (m, negative)
  real(kind=kind_real), allocatable, dimension(:,:,:) :: z_u  ! depths at U-points (m, negative)
  real(kind=kind_real), allocatable, dimension(:,:,:) :: z_v  ! depths at V-points (m, negative)
  real(kind=kind_real), allocatable, dimension(:,:,:) :: z_w  ! depths at W-points (m, negative)

  real(kind=kind_real), allocatable, dimension(:,:) :: rmask  ! RHO-points mask, 0=land 1=ocean
  real(kind=kind_real), allocatable, dimension(:,:) :: umask  ! U-points mask,   0=land 1=ocean
  real(kind=kind_real), allocatable, dimension(:,:) :: vmask  ! V-points mask,   0=land 1=ocean

  character (len=:), allocatable :: project_dir               ! ROMS project directory
  character (len=:), allocatable :: roms_stdinp               ! ROMS standard input filename

  CONTAINS

  PROCEDURE :: init  => roms_geom_init
  PROCEDURE :: end   => roms_geom_end
  PROCEDURE :: clone => roms_geom_clone

END TYPE roms_geom

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
!> Setup geometry object

SUBROUTINE roms_geom_init (self, f_conf, f_comm)

  USE mod_param
  USE mod_grid
  USE mod_iounits,     ONLY : Iname
  USE mod_scalars,     ONLY : EWperiodic, NSperiodic, NoError, exit_flag

  USE roms_kernel_mod, ONLY : ROMS_initialize

  CLASS (roms_geom),          intent(out) :: self
  TYPE (fckit_configuration), intent(in)  :: f_conf
  TYPE (fckit_mpi_comm),      intent(in)  :: f_comm

  logical, save :: first
  logical :: Ldebug = .TRUE.
  integer :: i, j, k, ng, tile
  integer :: MyComm, MyRank, MyError

  character (len=:), allocatable :: project_dir, roms_stdinp

  ! MPI communicator

  MyComm = f_comm%communicator()
  tile = f_comm%rank()

  self%f_comm = f_comm
  self%tile = tile

  ! Get ROMS project directory and standard input filename from YAML file

  IF (.not.f_conf%get("project_dir", project_dir)) THEN
    CALL abor1_ftn ("geom_init: Cannot find ROMS project directory")
  END IF
  self%project_dir = project_dir

  IF (.not.f_conf%get("roms_stdinp", roms_stdinp)) THEN
    CALL abor1_ftn ("geom_init: Cannot find ROMS standard input file")
  END IF
  self%roms_stdinp = roms_stdinp

  ! Get nested grid number from YAML file

  CALL f_conf%get_or_die("ng", ng)
  self%ng = ng

  ! ROMS initialization: read input script, allocate, initialize, and set grid.

  Iname = TRIM(project_dir)//TRIM(roms_stdinp)

  IF (.not.allocated(BOUNDS)) THEN       ! it is only called once
    first = .TRUE.
    CALL ROMS_initialize (first, MyComm)
    IF (exit_flag .ne. NoError) THEN
      CALL abor1_ftn ("geom_init: Error while calling ROMS_initialize")
    END IF
  END IF

  ! Domain decomposition ranges and indices

  self%model = iNLM                      ! numerical kernel

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

  ! Allocate geometry arrays and initialize from ROMS GRID structure

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

  ! Curvilinear rotation angle between XI-axis and EAST (radians)

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

  ! Depths (m)

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

  ! Report

  IF (Ldebug) THEN
    PRINT '(a,12(a,i0),a,3(i0,1x))', 'roms_geom::init: ', &
                                      ' tile = ', self%tile, ', ng = ', self%ng, &
                                      ', LBi = ', self%LBi, ', UBi = ', self%UBi, &
                                      ', LBj = ', self%LBj, ', UBj = ', self%UBj, &
                                      ', LBk = ', self%LBk, ', UBk = ', self%UBk, &
                                      ', Istr = ', self%Istr, ', Iend = ', self%Iend, &
                                      ', Jstr = ', self%Jstr, ', Jend = ', self%Jend, &
                                      ', SHAPE = ', SHAPE(self%z_r)
    CALL self%f_comm%barrier()
  END IF

END SUBROUTINE roms_geom_init

! ------------------------------------------------------------------------------
!> Geometry destructor

SUBROUTINE roms_geom_end (self)

  CLASS (roms_geom), intent(out)  :: self

  IF (allocated(self%lonr))       deallocate (self%lonr)
  IF (allocated(self%latr))       deallocate (self%latr)
  IF (allocated(self%lonu))       deallocate (self%lonu)
  IF (allocated(self%latu))       deallocate (self%latu)
  IF (allocated(self%lonv))       deallocate (self%lonv)
  IF (allocated(self%latv))       deallocate (self%latv)

  IF (allocated(self%angler))     deallocate (self%angler)
  IF (allocated(self%angleu))     deallocate (self%angleu)
  IF (allocated(self%anglev))     deallocate (self%anglev)

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
!> Clone, self = other

SUBROUTINE roms_geom_clone (self, other)

  CLASS (roms_geom), intent(inout) :: self
  CLASS (roms_geom), intent(in   ) :: other

  ! Clone communicator

  self%f_comm = other%f_comm

  ! clone tiled domain bounds and range indices

  self%ng   = other%ng
  self%tile = other%tile
  self%NghostPoints = other%NghostPoints

  self%project_dir = other%project_dir
  self%roms_stdinp = other%roms_stdinp

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

  ! Clone geometry arrays

  CALL roms_geom_allocate (self)

  self%lonr = other%lonr
  self%latr = other%latr
  self%lonu = other%lonu
  self%latu = other%latu
  self%lonv = other%lonv
  self%latv = other%latv

  self%angler = other%angler
  self%angleu = other%angleu
  self%anglev = other%anglev

  self%CosAngler = other%CosAngler
  self%SinAngler = other%SinAngler

  self%rmask = other%rmask
  self%umask = other%umask
  self%vmask = other%vmask

  self%z_r = other%z_r
  self%z_u = other%z_u
  self%z_v = other%z_v
  self%z_w = other%z_w

  PRINT '(a,12(a,i0),a,3(i0,1x))', 'roms_geom::clone: ', &
                                    ' tile = ', self%tile, ', ng = ', self%ng, &
                                    ', LBi = ', self%LBi, ', UBi = ', self%UBi, &
                                    ', LBj = ', self%LBj, ', UBj = ', self%UBj, &
                                    ', LBk = ', self%LBk, ', UBk = ', self%UBk, &
                                    ', Istr = ', self%Istr, ', Iend = ', self%Iend, &
                                    ', Jstr = ', self%Jstr, ', Jend = ', self%Jend, &
                                    ', SHAPE = ', SHAPE(self%z_r)
  CALL self%f_comm%barrier() 

END SUBROUTINE roms_geom_clone

! ------------------------------------------------------------------------------
!> Allocate geometry arrays

SUBROUTINE roms_geom_allocate (self)

  CLASS (roms_geom), intent(inout) :: self

  integer :: LBi, UBi, LBj, UBj, LBk, UBk

  ! Allocate and initialize geometry arrays

  LBi = self%LBi
  UBi = self%UBi
  LBj = self%LBj
  UBj = self%UBj
  LBk = self%LBk
  UBk = self%UBk

  allocate (self%lonr(LBi:UBi, LBj:UBj));           self%lonr = 0.0_kind_real
  allocate (self%latr(LBi:UBi, LBj:UBj));           self%latr = 0.0_kind_real
  allocate (self%lonu(LBi:UBi, LBj:UBj));           self%lonu = 0.0_kind_real
  allocate (self%latu(LBi:UBi, LBj:UBj));           self%latu = 0.0_kind_real
  allocate (self%lonv(LBi:UBi, LBj:UBj));           self%lonv = 0.0_kind_real
  allocate (self%latv(LBi:UBi, LBj:UBj));           self%latv = 0.0_kind_real

  allocate (self%angler(LBi:UBi, LBj:UBj));         self%angler = 0.0_kind_real
  allocate (self%angleu(LBi:UBi, LBj:UBj));         self%angleu = 0.0_kind_real
  allocate (self%anglev(LBi:UBi, LBj:UBj));         self%anglev = 0.0_kind_real

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

END MODULE roms_geom_mod
