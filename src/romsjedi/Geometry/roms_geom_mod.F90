! (C) Copyright 2017-2025 UCAR
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

USE atlas_module,               ONLY : atlas_functionspace_NodeColumns,        &
                                       atlas_field,                            &
                                       atlas_fieldset,                         &
                                       atlas_geometry,                         &
                                       atlas_integer,                          &
                                       atlas_real

USE fckit_configuration_module, ONLY : fckit_configuration
USE fckit_mpi_module,           ONLY : fckit_mpi_comm
USE fckit_log_module

USE type_fieldset,              ONLY : fieldset_type

!> ROMS module association.

USE mod_param,                  ONLY : p2dvar, r2dvar, u2dvar, v2dvar

!> ROMS-JEDI interface module association.

USE roms_fields_metadata_mod,   ONLY : roms_fields_metadata
USE roms_fieldsutils_mod,       ONLY : LdebugGeometry, roms_get_env

implicit none

! ------------------------------------------------------------------------------
!> ROMS application horizontal domain decomposition.
! ------------------------------------------------------------------------------

TYPE, PUBLIC :: roms_tile

  ! Starting and ending Computational indices in the I- and J-directions.

  integer :: IstrC, IendC, JstrC, JendC 

  ! Starting and ending Data indices in the I- and J-directions used for I/O.
  ! It includes computational plus lateral physical boundary points.

  integer :: IstrD, IendD, JstrD, JendD 

  ! Starting and ending Halo indices in the I- and J-directions used for
  ! parallel exchanges. It includes computational, lateral physical boundary,
  ! and halo points. Depending of the kernel algorithm, ROMS can be configured
  ! with 2 or 3 halo points.

  integer :: IstrH, IendH, JstrH, JendH
 
END TYPE roms_tile

! ------------------------------------------------------------------------------
!> ROMS application Geometry object.
! ------------------------------------------------------------------------------

TYPE, PUBLIC :: roms_geom

  TYPE (roms_tile) :: bounds(4)              ! C-grid tile indices range

  logical :: levelsAreTopDown = .FALSE.      ! k=1 (bottom), k=N (top)

  logical :: EWperiodic                      ! East-West periodicity switch
  logical :: NSperiodic                      ! North-South periodicity switch

  integer :: model                           ! kernel ID (iNLM, iTLM, iADM)
  integer :: ng                              ! nested grid number
  integer :: Lm, Mm                          ! global number of I- and J-points
  integer :: tile                            ! domain parallel partition tile

  integer :: NghostPoints                    ! number of tile halo points
  integer :: LBi, UBi, LBj, UBj, LBk, UBk    ! array(i,j,k) allocation bounds
  integer :: N                               ! number of vertical levels

  integer :: iterator_dimension              ! iterator dimenson (2D or 3D)

  character (len=:), allocatable :: roms_stdinp    ! standard input filename
  character (len=:), allocatable :: project_dir    ! project directory

  ! Grid cell center (RHO-points) properties:

  real (kind_real), allocatable  :: angler(:,:)    ! XI-axis and EAST (radians)
  real (kind_real), allocatable  :: CosAngler(:,:) ! COS(angler)
  real (kind_real), allocatable  :: SinAngler(:,:) ! SIN(angler)

  real (kind_real), allocatable  :: pm(:,:)        ! inverse x-spacing (1/m)
  real (kind_real), allocatable  :: pn(:,:)        ! inverse y-spacing (1/m)
  real (kind_real), allocatable  :: cell_area(:,:) ! cell area (m2)

  real (kind_real), allocatable  :: f_r(:,:)       ! Coriolis parameter (1/s)
  real (kind_real), allocatable  :: h_r(:,:)       ! bathymetry (m; positive)

  real (kind_real), allocatable  :: lonr(:,:)      ! longitude (degrees east)
  real (kind_real), allocatable  :: latr(:,:)      ! latitude (degrees north)

  real (kind_real), allocatable  :: rmask(:,:)     ! mask,  0=land 1=ocean

  ! Grid left and right cell faces (U-points) properties:

  real (kind_real), allocatable  :: angleu(:,:)    ! XI-axis and EAST (radians)

  real (kind_real), allocatable  :: f_u(:,:)       ! Coriolis parameter (1/s)
  real (kind_real), allocatable  :: h_u(:,:)       ! bathymetry (m; positive)

  real (kind_real), allocatable  :: lonu(:,:)      ! longitude (degrees east)
  real (kind_real), allocatable  :: latu(:,:)      ! latitude (degrees north)

  real (kind_real), allocatable  :: umask(:,:)     ! mask,  0=land 1=ocean

  ! Grid lower and upper cell faces (V-points) properties:

  real (kind_real), allocatable  :: anglev(:,:)    ! XI-axis and EAST (radians)

  real (kind_real), allocatable  :: f_v(:,:)       ! Coriolis parameter (1/s)
  real (kind_real), allocatable  :: h_v(:,:)       ! bathymetry (m; positive)

  real (kind_real), allocatable  :: lonv(:,:)      ! longitude (degrees east)
  real (kind_real), allocatable  :: latv(:,:)      ! latitude (degrees north)

  real (kind_real), allocatable  :: vmask(:,:)     ! mask,  0=land 1=ocean

  ! Grid level thickness (m), cell center,

  real (kind_real), allocatable  :: Hz(:,:,:)

  ! Grid negative depths (m) are staggered RHO-, U- and V-points (cell center
  ! and W-points (top and bottom cell faces).

  real (kind_real), allocatable  :: z_r(:,:,:)     ! time varying RHO-depths
  real (kind_real), allocatable  :: z_u(:,:,:)     ! time varying U-depths
  real (kind_real), allocatable  :: z_v(:,:,:)     ! time varying V-depths
  real (kind_real), allocatable  :: z_w(:,:,:)     ! time varing W-depths

  real (kind_real), allocatable  :: z0_r(:,:,:)    ! unvarying RHO-depths
  real (kind_real), allocatable  :: z0_w(:,:,:)    ! unvarying W-depths

  ! ATLAS Mesh: A Field is represented in the grid domain (RHO-cell) that
  ! includes computational points plus tile halo.

  TYPE (atlas_functionspace_NodeColumns) :: functionspace
  TYPE (atlas_fieldset)                  :: fieldset

  integer, allocatable                   :: atlas_ij2node(:,:)

  ! Fortran and C/C++ interoperability toolkit: MPI coomunicator object.

  TYPE (fckit_mpi_comm)                 :: f_comm

  ! ROMS-JEDI state variables metadata.

  TYPE (roms_fields_metadata)           :: FieldsInfo

  CONTAINS

  PROCEDURE :: init                    => roms_geom_init
  PROCEDURE :: end                     => roms_geom_end
  PROCEDURE :: clone                   => roms_geom_clone

  PROCEDURE :: init_fieldset           => roms_geom_init_fieldset
  PROCEDURE :: mesh_valid_nodes_cells  => roms_geom_mesh_valid_nodes_cells

END TYPE roms_geom

PRIVATE

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
!> Setup geometry object by calling "ROMS_initializeP1".

SUBROUTINE roms_geom_init (self, f_conf, f_comm)

  USE mod_param
  USE mod_grid
  USE mod_iounits,     ONLY : Iname
  USE mod_scalars,     ONLY : EWperiodic, NSperiodic, NoError,                  &
                              exit_flag

  USE roms_kernel_mod, ONLY : ROMS_initializeP1
  USE set_depth_mod,   ONLY : set_depth0, set_depth

  CLASS (roms_geom),          intent(out) :: self         !< Geometry object
  TYPE (fckit_configuration), intent(in)  :: f_conf       !< Configuration
  TYPE (fckit_mpi_comm),      intent(in)  :: f_comm       !< MPI communicator

  logical, save                           :: first

  integer                                 :: cgrid, i, j, k, lstr, ng, tile
  integer                                 :: MyComm

  character (len=:), allocatable          :: flds_meta, project_dir
  character (len=:), allocatable          :: roms_stdinp

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
  CALL self%FieldsInfo%create (flds_meta)
  IF (allocated(flds_meta)) deallocate (flds_meta)

  ! Get nested grid number from configuration YAML file.

  CALL f_conf%get_or_die("ng", ng)
  self%ng = ng

  ! Get iterator dimension from configuration YAML file.

  IF (.not.f_conf%get("iterator dimension", self%iterator_dimension))          &
    self%iterator_dimension = 2

  ! Retrieve ROMS-JEDI debugging switch from system environmental variables.

  CALL roms_get_env ()

  ! ROMS-JEDI phase 1 initialization: read input script, allocate, initialize,
  ! and set grid.

  lstr = LEN_TRIM(project_dir)
  IF (project_dir(lstr:lstr) .eq. CHAR(47) ) THEN
    Iname = TRIM(project_dir) // TRIM(roms_stdinp)
  ELSE
    Iname = TRIM(project_dir) // CHAR(47) // TRIM(roms_stdinp)
  END IF
  IF (allocated(project_dir)) deallocate (project_dir)
  IF (allocated(roms_stdinp)) deallocate (roms_stdinp)

  IF (.not.allocated(BOUNDS)) THEN       ! it is only called once
    first = .TRUE.
    CALL ROMS_initializeP1 (first,                                             &
                            mpiCOMM = MyComm,                                  &
                            kernel  = iNLM)
    IF (exit_flag .ne. NoError) THEN
      CALL abor1_ftn ("geom_init: Error while calling ROMS_initializeP1")
    END IF
  END IF

  ! Initialize model depths and level thickness. At this point, the free
  ! surface is zero (zeta=0). Notice that these arrays are computed formally
  ! in routine 'ROMS_initializeP2'.

  CALL set_depth0 (ng, tile, iNLM)              ! time independent
  CALL set_depth  (ng, tile, iNLM)              ! time dependent

  ! Domain tile decomposition ranges and left-hand indexing:
  !
  !   (IstrC:IendC, JstrC:JendC)  => computational points
  !   (IstrD:IendD, JstrD:JeenD)  => computational plus boundary points
  !   (IstrH:IendH. JstrH:JendH)  => computational plus boundary and halo points
  !                                  (ROMS could have 2 or 3 halo points)
  !
  !   p(i,j+1,k)---v(i,j+1,k)---p(i+1,j+1,k)       -------w(i,j,k)-------
  !      |                          |              |                    |
  !   u(i,j,k)     r(i,j,k)     u(i+1,j,k)         |   p,r,u,v(i,j,k)   |
  !      |                          |              |                    |
  !   p(i,j,k)-----v(i,j,k)-----p(i+1,j,k)         ------w(i,j,k-1)------
  !
  !          horizontal stencil                       vertical stencil
  !            Arakawa C-grid          p,r,u,v:  bottom (k=1) to top (k=N)
  !                                          w:  bottom (k=0) to top (k=N)
  !                                              [levelsAreTopDown()=false]
 
  DO cgrid = 1, 4

    SELECT CASE (cgrid)

      CASE (p2dvar)  ! PSI-points: cell corners

        self%bounds(cgrid)%IstrC = BOUNDS(ng)%IstrU(tile)
        self%bounds(cgrid)%IendC = BOUNDS(ng)%Iend (tile)
        self%bounds(cgrid)%JstrC = BOUNDS(ng)%JstrV(tile)
        self%bounds(cgrid)%JendC = BOUNDS(ng)%Jend (tile)

        self%bounds(cgrid)%IstrD = BOUNDS(ng)%Istr (tile)
        self%bounds(cgrid)%IendD = BOUNDS(ng)%IendR(tile)
        self%bounds(cgrid)%JstrD = BOUNDS(ng)%Jstr (tile)
        self%bounds(cgrid)%JendD = BOUNDS(ng)%JendR(tile)

        self%bounds(cgrid)%IstrH = BOUNDS(ng)%Imin(p2dvar,1,tile)
        self%bounds(cgrid)%IendH = BOUNDS(ng)%Imax(p2dvar,1,tile)
        self%bounds(cgrid)%JstrH = BOUNDS(ng)%Jmin(p2dvar,1,tile)
        self%bounds(cgrid)%JendH = BOUNDS(ng)%Jmax(p2dvar,1,tile)

      CASE (r2dvar)  ! RHO-points: cell center

        self%bounds(cgrid)%IstrC = BOUNDS(ng)%Istr(tile)
        self%bounds(cgrid)%IendC = BOUNDS(ng)%Iend(tile)
        self%bounds(cgrid)%JstrC = BOUNDS(ng)%Jstr(tile)
        self%bounds(cgrid)%JendC = BOUNDS(ng)%Jend(tile)

        self%bounds(cgrid)%IstrD = BOUNDS(ng)%IstrR(tile)
        self%bounds(cgrid)%IendD = BOUNDS(ng)%IendR(tile)
        self%bounds(cgrid)%JstrD = BOUNDS(ng)%JstrR(tile)
        self%bounds(cgrid)%JendD = BOUNDS(ng)%JendR(tile)

        self%bounds(cgrid)%IstrH = BOUNDS(ng)%Imin(r2dvar,1,tile)
        self%bounds(cgrid)%IendH = BOUNDS(ng)%Imax(r2dvar,1,tile)
        self%bounds(cgrid)%JstrH = BOUNDS(ng)%Jmin(r2dvar,1,tile)
        self%bounds(cgrid)%JendH = BOUNDS(ng)%Jmax(r2dvar,1,tile)

      CASE (u2dvar)  ! U-points: left and right cell faces

        self%bounds(cgrid)%IstrC = BOUNDS(ng)%IstrU(tile)
        self%bounds(cgrid)%IendC = BOUNDS(ng)%Iend (tile)
        self%bounds(cgrid)%JstrC = BOUNDS(ng)%Jstr (tile)
        self%bounds(cgrid)%JendC = BOUNDS(ng)%Jend (tile)

        self%bounds(cgrid)%IstrD = BOUNDS(ng)%Istr (tile)
        self%bounds(cgrid)%IendD = BOUNDS(ng)%IendR(tile)
        self%bounds(cgrid)%JstrD = BOUNDS(ng)%JstrR(tile)
        self%bounds(cgrid)%JendD = BOUNDS(ng)%JendR(tile)

        self%bounds(cgrid)%IstrH = BOUNDS(ng)%Imin(u2dvar,1,tile)
        self%bounds(cgrid)%IendH = BOUNDS(ng)%Imax(u2dvar,1,tile)
        self%bounds(cgrid)%JstrH = BOUNDS(ng)%Jmin(u2dvar,1,tile)
        self%bounds(cgrid)%JendH = BOUNDS(ng)%Jmax(u2dvar,1,tile)

      CASE (v2dvar)  ! V-points: lower and upper cell faces

        self%bounds(cgrid)%IstrC = BOUNDS(ng)%Istr (tile)
        self%bounds(cgrid)%IendC = BOUNDS(ng)%Iend (tile)
        self%bounds(cgrid)%JstrC = BOUNDS(ng)%JstrV(tile)
        self%bounds(cgrid)%JendC = BOUNDS(ng)%Jend (tile)

        self%bounds(cgrid)%IstrD = BOUNDS(ng)%IstrR(tile)
        self%bounds(cgrid)%IendD = BOUNDS(ng)%IendR(tile)
        self%bounds(cgrid)%JstrD = BOUNDS(ng)%Jstr (tile)
        self%bounds(cgrid)%JendD = BOUNDS(ng)%JendR(tile)

        self%bounds(cgrid)%IstrH = BOUNDS(ng)%Imin(v2dvar,1,tile)
        self%bounds(cgrid)%IendH = BOUNDS(ng)%Imax(v2dvar,1,tile)
        self%bounds(cgrid)%JstrH = BOUNDS(ng)%Jmin(v2dvar,1,tile)
        self%bounds(cgrid)%JendH = BOUNDS(ng)%Jmax(v2dvar,1,tile)

    END SELECT

  END DO

  ! Other domain parameters.

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

  ! Allocate geometry arrays and initialize from ROMS GRID structure.

  CALL roms_geom_allocate (self)

  self%pm   = GRID(ng)%pm
  self%pn   = GRID(ng)%pn
  self%Hz   = GRID(ng)%Hz

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

  DO j = self%bounds(r2dvar)%JstrD, self%bounds(r2dvar)%JendD
    DO i = self%bounds(r2dvar)%IstrD, self%bounds(r2dvar)%IendD
      self%cell_area(i,j) = (1.0_kind_real/GRID(ng)%pm(i,j))*                  &
                            (1.0_kind_real/GRID(ng)%pn(i,j))
    END DO
  END DO

  ! Curvilinear rotation angle between XI-axis and EAST (radians).

  self%angler = GRID(ng)%angler

  DO j = self%bounds(u2dvar)%JstrC-1, self%bounds(u2dvar)%JendC+1
    DO i = self%bounds(u2dvar)%IstrC-1, self%bounds(u2dvar)%IendC+1
      self%angleu(i,j) = 0.5_kind_real*(self%angler(i-1,j)+self%angler(i,j))
    END DO
  END DO

  DO j = self%bounds(v2dvar)%JstrC-1, self%bounds(v2dvar)%JendC+1
    DO i = self%bounds(v2dvar)%IstrC-1, self%bounds(v2dvar)%IendC+1
      self%anglev(i,j) = 0.5_kind_real*(self%angler(i,j-1)+self%angler(i,j))
    END DO
  END DO

  ! Coriolis parameter (1/s).

  self%f_r = GRID(ng)%f

  DO j = self%bounds(u2dvar)%JstrC-1, self%bounds(u2dvar)%JendC+1
    DO i = self%bounds(u2dvar)%IstrC-1, self%bounds(u2dvar)%IendC+1
      self%f_u(i,j) = 0.5_kind_real*(self%f_r(i-1,j)+self%f_r(i,j))
    END DO
  END DO

  DO j = self%bounds(v2dvar)%JstrC-1, self%bounds(v2dvar)%JendC+1
    DO i = self%bounds(v2dvar)%IstrC-1, self%bounds(v2dvar)%IendC+1
      self%f_v(i,j) = 0.5_kind_real*(self%f_r(i,j-1)+self%f_r(i,j))
    END DO
  END DO

  ! Bathymetry (m; positive).

  self%h_r = GRID(ng)%h

  DO j = self%bounds(u2dvar)%JstrC-1, self%bounds(u2dvar)%JendC+1
    DO i = self%bounds(u2dvar)%IstrC-1, self%bounds(u2dvar)%IendC+1
      self%h_u(i,j) = 0.5_kind_real*(self%h_r(i-1,j)+self%H_r(i,j))
    END DO
  END DO

  DO j = self%bounds(v2dvar)%JstrC-1, self%bounds(v2dvar)%JendC+1
    DO i = self%bounds(v2dvar)%IstrC-1, self%bounds(v2dvar)%IendC+1
      self%h_v(i,j) = 0.5_kind_real*(self%h_r(i,j-1)+self%h_r(i,j))
    END DO
  END DO

  ! Depths (m; negative).

  self%z0_r = GRID(ng)%z0_r
  self%z0_w = GRID(ng)%z0_w

  self%z_r = GRID(ng)%z_r
  self%z_w = GRID(ng)%z_w

  DO k=1,self%N
    DO j = self%bounds(u2dvar)%JstrC-1, self%bounds(u2dvar)%JendC+1
      DO i = self%bounds(u2dvar)%IstrC-1, self%bounds(u2dvar)%IendC+1
        self%z_u(i,j,k) = 0.5_kind_real*(self%z_r(i-1,j,k)+self%z_r(i,j,k))
      END DO
    END DO

    DO j = self%bounds(v2dvar)%JstrC-1, self%bounds(v2dvar)%JendC+1
      DO i = self%bounds(v2dvar)%IstrC-1, self%bounds(v2dvar)%IendC+1
        self%z_v(i,j,k) = 0.5_kind_real*(self%z_r(i,j-1,k)+self%z_r(i,j,k))
      END DO
    END DO
  END DO

  ! Report.

  IF (LdebugGeometry) THEN
    PRINT 20, 'ROMS_DEBUG roms_geom::init: tile = ', self%tile,                &
              ', ng = ', self%ng,                                              &
              ', RHO-points SHAPE = ', SHAPE(self%z_r),                        &
              '  LBi   = ', self%LBi,                                          &
              ', UBi   = ', self%UBi,                                          &
              ', LBj   = ', self%LBj,                                          &
              ', UBj   = ', self%UBj,                                          &
              '  IstrD = ', self%bounds(2)%IstrD,                              &
              ', IendD = ', self%bounds(2)%IendD,                              &
              ', JstrD = ', self%bounds(2)%JstrD,                              &
              ', JendD = ', self%bounds(2)%JendD,                              &
              '  IstrH = ', self%bounds(2)%IstrH,                              &
              ', IendH = ', self%bounds(2)%IendH,                              &
              ', JstrH = ', self%bounds(2)%JstrH,                              &
              ', JendH = ', self%bounds(2)%JendH,                              &
              '  IstrC = ', self%bounds(2)%IstrC,                              &
              ', IendC = ', self%bounds(2)%IendC,                              &
              ', JstrC = ', self%bounds(2)%JstrC,                              &
              ', JendC = ', self%bounds(2)%JendC
 20 FORMAT (a,i3, a,i0, a,3(i0,1x),4(/,t29,4(a,i4)))
    CALL self%f_comm%barrier()
  END IF

END SUBROUTINE roms_geom_init

! ------------------------------------------------------------------------------
!> Geometry object destructor: deallocate all arrays.

SUBROUTINE roms_geom_end (self)

  CLASS (roms_geom), intent(out)  :: self                 !< Geometry object

  IF (allocated(self%f_r))        deallocate (self%f_r)
  IF (allocated(self%f_u))        deallocate (self%f_u)
  IF (allocated(self%f_v))        deallocate (self%f_v)

  IF (allocated(self%h_r))        deallocate (self%h_r)
  IF (allocated(self%h_u))        deallocate (self%h_u)
  IF (allocated(self%h_v))        deallocate (self%h_v)

  IF (allocated(self%pm))         deallocate (self%pm)
  IF (allocated(self%pn))         deallocate (self%pn)

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

  IF (allocated(self%Hz))         deallocate (self%Hz)

  IF (allocated(self%z_r))        deallocate (self%z_r)
  IF (allocated(self%z_u))        deallocate (self%z_u)
  IF (allocated(self%z_v))        deallocate (self%z_v)
  IF (allocated(self%z_w))        deallocate (self%z_w)

  IF (allocated(self%z0_r))       deallocate (self%z0_r)
  IF (allocated(self%z0_w))       deallocate (self%z0_w)

  CALL self%functionspace%final ()

END SUBROUTINE roms_geom_end

! ------------------------------------------------------------------------------
!> Clone geometry object, self = other.

SUBROUTINE roms_geom_clone (self, other)

  CLASS (roms_geom), intent(inout) :: self                !< LHS Geometry object
  CLASS (roms_geom), intent(in   ) :: other               !< RHS Geometry object

  integer                          :: cgrid

  ! Clone communicator.

  self%f_comm = other%f_comm

  ! Clone object parameters, domain bounds, and range indices.

  DO cgrid = 1, 4
    self%bounds(cgrid)%IstrC = other%bounds(cgrid)%IstrC
    self%bounds(cgrid)%IendC = other%bounds(cgrid)%IendC
    self%bounds(cgrid)%JstrC = other%bounds(cgrid)%JstrC
    self%bounds(cgrid)%JendC = other%bounds(cgrid)%JendC

    self%bounds(cgrid)%IstrD = other%bounds(cgrid)%IstrD
    self%bounds(cgrid)%IendD = other%bounds(cgrid)%IendD
    self%bounds(cgrid)%JstrD = other%bounds(cgrid)%JstrD
    self%bounds(cgrid)%JendD = other%bounds(cgrid)%JendD

    self%bounds(cgrid)%IstrH = other%bounds(cgrid)%IstrH
    self%bounds(cgrid)%IendH = other%bounds(cgrid)%IendH
    self%bounds(cgrid)%JstrH = other%bounds(cgrid)%JstrH
    self%bounds(cgrid)%JendH = other%bounds(cgrid)%JendH
  END DO

  self%ng   = other%ng
  self%tile = other%tile
  self%NghostPoints = other%NghostPoints

  self%model = other%model

  self%levelsAreTopDown = other%levelsAreTopDown

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

  self%project_dir = other%project_dir
  self%roms_stdinp = other%roms_stdinp
  self%FieldsInfo  = other%FieldsInfo

  ! Iterator dimension.

  self%iterator_dimension = other%iterator_dimension

  ! Clone geometry arrays.

  CALL roms_geom_allocate (self)

  self%f_r = other%f_r
  self%f_u = other%f_u
  self%f_v = other%f_v

  self%h_r = other%h_r
  self%h_u = other%h_u
  self%h_v = other%h_v

  self%pm  = other%pm
  self%pn  = other%pn
  self%Hz  = other%Hz

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

  self%z0_r = other%z0_r
  self%z0_w = other%z0_w

  ! Clone fields metadata.

  CALL other%FieldsInfo%clone (self%FieldsInfo)

  ! Clone ATLAS indices mapping.

  self%atlas_ij2node = other%atlas_ij2node

  ! Report.

  IF (LdebugGeometry) THEN
    PRINT 10, 'ROMS_DEBUG roms_geom::clone: tile = ', self%tile,               &
              ', ng = ', self%ng,                                              &
              ', RHO-points SHAPE = ', SHAPE(self%z_r),                        &
              '  LBi   = ', self%LBi,                                          &
              ', UBi   = ', self%UBi,                                          &
              ', LBj   = ', self%LBj,                                          &
              ', UBj   = ', self%UBj,                                          &
              ', LBk   = ', self%LBk,                                          &
              ', UBk   = ', self%UBk,                                          &
              '  IstrC = ', self%bounds(2)%IstrC,                              &
              ', IendC = ', self%bounds(2)%IendC,                              &
              ', JstrC = ', self%bounds(2)%JstrC,                              &
              ', JendC = ', self%bounds(2)%JendC
 10 FORMAT (a,i3, a,i0, a,3(i0,1x),/,t28,6(a,i4),/,t28,4(a,i4))
    CALL self%f_comm%barrier() 
  END IF

END SUBROUTINE roms_geom_clone

! ------------------------------------------------------------------------------
!> Allocate geometry object arrays.

SUBROUTINE roms_geom_allocate (self)

  CLASS (roms_geom), intent(inout) :: self                !< Geometry object

  integer :: LBi, UBi, LBj, UBj, LBk, UBk

  ! Allocate and initialize geometry arrays.

  LBi = self%LBi
  UBi = self%UBi
  LBj = self%LBj
  UBj = self%UBj
  LBk = self%LBk
  UBk = self%UBk

  allocate (self%f_r(LBi:UBi, LBj:UBj));          self%f_r = 0.0_kind_real
  allocate (self%f_u(LBi:UBi, LBj:UBj));          self%f_u = 0.0_kind_real
  allocate (self%f_v(LBi:UBi, LBj:UBj));          self%f_v = 0.0_kind_real

  allocate (self%h_r(LBi:UBi, LBj:UBj));          self%h_r = 0.0_kind_real
  allocate (self%h_u(LBi:UBi, LBj:UBj));          self%h_u = 0.0_kind_real
  allocate (self%h_v(LBi:UBi, LBj:UBj));          self%h_v = 0.0_kind_real

  allocate (self%pm(LBi:UBi, LBj:UBj));           self%pm  = 0.0_kind_real
  allocate (self%pn(LBi:UBi, LBj:UBj));           self%pn  = 0.0_kind_real

  allocate (self%lonr(LBi:UBi, LBj:UBj));         self%lonr = 0.0_kind_real
  allocate (self%latr(LBi:UBi, LBj:UBj));         self%latr = 0.0_kind_real
  allocate (self%lonu(LBi:UBi, LBj:UBj));         self%lonu = 0.0_kind_real
  allocate (self%latu(LBi:UBi, LBj:UBj));         self%latu = 0.0_kind_real
  allocate (self%lonv(LBi:UBi, LBj:UBj));         self%lonv = 0.0_kind_real
  allocate (self%latv(LBi:UBi, LBj:UBj));         self%latv = 0.0_kind_real

  allocate (self%angler(LBi:UBi, LBj:UBj));       self%angler = 0.0_kind_real
  allocate (self%angleu(LBi:UBi, LBj:UBj));       self%angleu = 0.0_kind_real
  allocate (self%anglev(LBi:UBi, LBj:UBj));       self%anglev = 0.0_kind_real

  allocate (self%cell_area(LBi:UBi, LBj:UBj));    self%cell_area = 0.0_kind_real

  allocate (self%CosAngler(LBi:UBi, LBj:UBj));    self%CosAngler = 0.0_kind_real
  allocate (self%SinAngler(LBi:UBi, LBj:UBj));    self%SinAngler = 0.0_kind_real

  allocate (self%rmask(LBi:UBi, LBj:UBj));        self%rmask = 0.0_kind_real
  allocate (self%umask(LBi:UBi, LBj:UBj));        self%umask = 0.0_kind_real
  allocate (self%vmask(LBi:UBi, LBj:UBj));        self%vmask = 0.0_kind_real

  allocate (self%Hz(LBi:UBi, LBj:UBj, LBk:UBk));  self%Hz = 0.0_kind_real

  allocate (self%z_r(LBi:UBi, LBj:UBj, LBk:UBk)); self%z_r = 0.0_kind_real
  allocate (self%z_u(LBi:UBi, LBj:UBj, LBk:UBk)); self%z_u = 0.0_kind_real
  allocate (self%z_v(LBi:UBi, LBj:UBj, LBk:UBk)); self%z_v = 0.0_kind_real
  allocate (self%z_w(LBi:UBi, LBj:UBj,   0:UBk)); self%z_w = 0.0_kind_real

  allocate (self%z0_r(LBi:UBi,LBj:UBj, LBk:UBk)); self%z0_r = 0.0_kind_real
  allocate (self%z0_w(LBi:UBi,LBj:UBj,   0:UBk)); self%z0_w = 0.0_kind_real

  allocate (self%atlas_ij2node(LBi:UBi,LBj:UBj)); self%atlas_ij2node = -1

END SUBROUTINE roms_geom_allocate

! ------------------------------------------------------------------------------
!> Fill ATLAS fieldset with cell area, vertical level units, and geographical
!! mask at density points.

SUBROUTINE roms_geom_init_fieldset (self)

  CLASS (roms_geom),     intent(inout) :: self            !< Geometry object

  TYPE (atlas_field)                   :: Area, Gmask, Owned, Rmask
  TYPE (atlas_field)                   :: VertCoord2d, VertCoord3d
  integer                              :: IstrC, IendC, JstrC, JendC
  integer                              :: IstrD, IendD, JstrD, JendD
  integer                              :: N, cgrid, i, j, k, nc
  integer, pointer                     :: Gmask_ptr(:,:), Owned_ptr(:,:)
  real (kind_real), pointer            :: Area_ptr(:,:), Rmask_ptr(:,:)
  real (kind_real), pointer            :: VertCoord2d_ptr(:,:)
  real (kind_real), pointer            :: VertCoord3d_ptr(:,:)

  ! Initialize. ATLAS assumes that all the variables are located at the
  ! grid center (A-grid).

  cgrid = r2dvar                         ! RHO-points, grid cell center

  IstrD = self%bounds(cgrid)%IstrD       ! starting Data I-index
  IendD = self%bounds(cgrid)%IendD       ! ending   Data I-index
  JstrD = self%bounds(cgrid)%JstrD       ! starting Data J-index
  JendD = self%bounds(cgrid)%JendD       ! ending   Data J-index

  N     = self%N

  ! Add grid cell area (m2) at RHO-points.

  Area = self%functionspace%create_field(name='area',                         &
                                         kind=atlas_real(kind_real),          &
                                         levels=1)
  CALL self%fieldset%add (Area)
  CALL area%data (Area_ptr)
  CALL area%set_dirty (.TRUE.)           ! mark halos as being out-of-date    

  ! Add 2D vertical coordinate for depth-independent state variable. 
  ! (Use top level enumeration N as a value for BUMP)

  VertCoord2d = self%functionspace%create_field(name='vert_coord_2d',          &
                                                kind=atlas_real(kind_real),    &
                                                levels=N)
  CALL self%fieldset%add (VertCoord2d)
  CALL VertCoord2d%data (VertCoord2d_ptr)

  ! Add 3D vertical coordinate: time-independent depths (m) at RHO-points 
  !                             (negative, levelsAreTopDown = .FALSE.)

  VertCoord3d = self%functionspace%create_field(name='vert_coord',             &
                                                kind=atlas_real(kind_real),    &
                                                levels=N)
  CALL self%fieldset%add (VertCoord3d)
  CALL VertCoord3d%data (VertCoord3d_ptr)

  ! Add geographical land/sea integer mask at RHO-points with values of
  ! land=0 and sea=1.

  Gmask = self%functionspace%create_field(name='gmask',                        &
                                          kind=atlas_integer(KIND(0)),         &
                                          levels=N)
  CALL self%fieldset%add (Gmask)
  CALL Gmask%data (Gmask_ptr)

  ! Add geographical land/sea floating-point mask at RHO-points with values of
  ! land=0 and sea=1.

  Rmask = self%functionspace%create_field(name='mask_rho',                     &
                                          kind=atlas_real(kind_real),          &
                                          levels=1)
  CALL self%fieldset%add (Rmask)
  CALL Rmask%data (Rmask_ptr)

  ! Add owned 2D mask: An integer array with one at owned points and zero at
  ! ghost grid points. Here, owned indicates possessed by a single process
  ! associated with the tile partition. It does not require a halo exchange. 

  Owned = self%functionspace%create_field(name='owned',                        &
                                          kind=atlas_integer(KIND(0)),         &
                                          levels=1)
  CALL self%fieldset%add (Owned)
  CALL Owned%data (Owned_ptr)
  Owned_ptr = 0                                ! intialize to unowned

  ! Fill the 2D data pointers at Data RHO-points (computational plus lateral
  ! boundary conditions points).

  DO j = JstrD, JendD
    DO i = IstrD, IendD
      nc = self%atlas_ij2node(i,j)
      Area_ptr(1,nc) = self%cell_area(i,j)
      Rmask_ptr(1,nc) = self%rmask(i,j)
      owned_ptr(1,nc) = 1                      ! point owned by parallel task
    END DO
  END DO

  ! Fill the 3D data pointer for geographical mask at Data RHO-points.

  DO k = 1, N
    DO j = JstrD, JendD
      DO i = IstrD, IendD
        nc = self%atlas_ij2node(i,j)
        Gmask_ptr(k,nc) = INT(self%rmask(i,j))
      END DO
    END DO
  END DO

  ! Fill pointers for 2D and 3D vertical coordinate at RHO-points.

  DO k = 1, N
    DO j = JstrD, JendD
      DO i = IstrD, IendD
        nc = self%atlas_ij2node(i,j)
        VertCoord2d_ptr(k,nc) = REAL(k, kind_real) ! level enumeration
        VertCoord3d_ptr(k,nc) = self%z0_r(i,j,k)   ! time invariant depths
      END DO
    END DO
  END DO

  ! ATLAS Parallel halo exchange.

  CALL Area%halo_exchange ()
  CALL Gmask%halo_exchange ()
  CALL Rmask%halo_exchange ()
  CALL VertCoord2d%halo_exchange ()
  CALL VertCoord3d%halo_exchange ()

  ! Done, cleanup.

  CALL Area%final ()
  CALL Gmask%final ()
  CALL Owned%final ()
  CALL Rmask%final ()
  CALL VertCoord2d%final ()  
  CALL VertCoord3d%final ()  

END SUBROUTINE roms_geom_init_fieldset

! ------------------------------------------------------------------------------
!> Determines the valid grid nodes and grid cells per parallel tile for
!  ATLAS mesh generation.

SUBROUTINE roms_geom_mesh_valid_nodes_cells (self, nodes, cells)

  CLASS (roms_geom),    intent(in ) :: self               !< Geometry object
  logical, allocatable, intent(out) :: nodes(:,:)         !< 2D grid vertices
  logical, allocatable, intent(out) :: cells(:,:)         !< grid cells

  integer                           :: IstrD, IendC, JstrD, JendC
  integer                           :: cgrid, ng, tile

  ! Grid parameters.

  ng    = self%ng                        ! nested grid number
  cgrid = r2dvar                         ! staggered C-grid RHO-type (0:L,0:M)
  tile  = self%tile                      ! parallel partition tile

  IstrD = self%bounds(cgrid)%IstrD       ! starting Data          I-index
  IendC = self%bounds(cgrid)%IendC       ! ending   Computational I-index

  JstrD = self%bounds(cgrid)%JstrD       ! starting Data          J-index
  JendC = self%bounds(cgrid)%JendC       ! ending   Computational J-index

  ! Allocate grid nodes and cells arrays at Data RHO-points (computational plus
  ! lateral boundary conditions points). Notice that indices IstrD and JstrD
  ! are used to ensure that western and southern lateral boundary conditions
  ! points are included in the nodes enumeration,

  allocate ( nodes(IstrD:IendC+1, JstrD:JendC+1) )   ! number of quads vertices
  allocate ( cells(IstrD:IendC,   JstrD:JendC  ) )   ! number of quads

  ! Initialize to valid points.

  cells = .TRUE.
  nodes = .TRUE.

  IF (LdebugGeometry) THEN
    PRINT 10, 'ROMS_DEBUG: roms_geom::valid_nodes_cells: tile = ', self%tile,  &
              ', ng = ', self%ng,                                              &
              ', 2D SHAPE = ',SHAPE(cells),                                    &
              '  nodes = ', COUNT(nodes),                                      &
              ', quads = ', COUNT(cells)
 10 FORMAT (a,i3, a,i0, a,2(i0,1x),/,t41,2(a,i0))
    CALL self%f_comm%barrier ()
  END IF

END SUBROUTINE roms_geom_mesh_valid_nodes_cells

! ------------------------------------------------------------------------------

END MODULE roms_geom_mod
