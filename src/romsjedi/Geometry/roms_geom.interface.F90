! (C) Copyright 2017-2025 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
!>
!! \brief    Fortran and C++ binding interface for ROMS-JEDI Geometry Class
!!
!! \details  Interoperability mechanism for the Geometry class that allows
!!           Fortran to invoke C++ functions and vice versa C++ to invoke
!!           Fortran procedures.
!!
!! \author   Hernan G. Arango (Rutgers University)
!! \date     April 2021

MODULE roms_geom_mod_c

USE iso_c_binding

USE atlas_module,               ONLY : atlas_field,                          &
                                       atlas_fieldset,                       &
                                       atlas_functionspace_NodeColumns
USE fckit_configuration_module, ONLY : fckit_configuration
USE fckit_mpi_module,           ONLY : fckit_mpi_comm
USE kinds,                      ONLY : kind_real
USE oops_variables_mod,         ONLY : oops_variables

!> ROMS module association.

USE mod_param,                  ONLY : iNLM, r2dvar
USE mp_exchange_mod,            ONLY : mp_exchange2d

!> ROMS-JEDI interface module association.

USE roms_fields_metadata_mod,   ONLY : roms_field_metadata
USE roms_fieldsutils_mod,       ONLY : LdebugGeometry
USE roms_geom_mod,              ONLY : roms_geom
USE roms_geom_reg,              ONLY : roms_geom_registry

implicit none

PRIVATE
! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
!> Setup geometry object

SUBROUTINE roms_geom_init_c (c_key_self, c_conf, c_comm)                       &
                       BIND (c, name='roms_geom_init_f90')

  integer (c_int),     intent(inout) :: c_key_self
  TYPE (c_ptr), value, intent(in   ) :: c_conf
  TYPE (c_ptr), value, intent(in   ) :: c_comm

  TYPE (roms_geom), pointer          :: self

  CALL roms_geom_registry%init ()
  CALL roms_geom_registry%add (c_key_self)
  CALL roms_geom_registry%get (c_key_self, self)

  CALL self%init (fckit_configuration(c_conf), fckit_mpi_comm(c_comm))

END SUBROUTINE roms_geom_init_c

! ------------------------------------------------------------------------------
!> Clone geometry object

SUBROUTINE roms_geom_clone_c (c_key_self, c_key_other)                         &
                        BIND (c, name='roms_geom_clone_f90')

  integer (c_int), intent(inout) :: c_key_self
  integer (c_int), intent(in   ) :: c_key_other

  TYPE (roms_geom), pointer      :: self, other

  CALL roms_geom_registry%add (c_key_self)
  CALL roms_geom_registry%get (c_key_self, self)
  CALL roms_geom_registry%get (c_key_other, other )

  CALL self%clone (other)

END SUBROUTINE roms_geom_clone_c

! ------------------------------------------------------------------------------
!> Geometry destructor

SUBROUTINE roms_geom_end_c (c_key_self)                                         &
                      BIND (c, name='roms_geom_end_f90')

  integer(c_int), intent(inout) :: c_key_self

  TYPE (roms_geom),     pointer :: self

  CALL roms_geom_registry%get (c_key_self, self)

  CALL self%end ()
  CALL roms_geom_registry%remove (c_key_self)

END SUBROUTINE roms_geom_end_c

! ------------------------------------------------------------------------------
!> Get begin and end of local tile geometry

SUBROUTINE roms_geom_start_end_c (c_key_self, Istr, Iend, Jstr, Jend,          &
                                  Kstr, Kend)                                  &
                            BIND (c, name='roms_geom_start_end_f90')

  integer (c_int), intent(in ) :: c_key_self
  integer (c_int), intent(out) :: Istr, Iend, Jstr, Jend, kstr, Kend

  TYPE (roms_geom), pointer    :: self

  CALL roms_geom_registry%get (c_key_self, self)

  Istr = self%bounds(r2dvar)%IstrD
  Iend = self%bounds(r2dvar)%IendD
  Jstr = self%bounds(r2dvar)%JstrD
  Jend = self%bounds(r2dvar)%JendD
  Kstr = 1
  Kend = self%N

END SUBROUTINE roms_geom_start_end_c

! ------------------------------------------------------------------------------
!> Get geometry information

SUBROUTINE roms_geom_info_c (c_key_self, nx, ny, nz, tile,                     &
                             LBi, UBi, LBj, UBj,                               &
                             Istr, Iend, Jstr, Jend)                           &
                      BIND (c, name='roms_geom_info_f90')

  integer (c_int), intent(in ) :: c_key_self
  integer (c_int), intent(out) :: nx, ny, nz, tile
  integer (c_int), intent(out) :: LBi, UBi, LBj, UBj, Istr, Iend, Jstr, Jend

  TYPE (roms_geom), pointer    :: self

  CALL roms_geom_registry%get (c_key_self, self)

  ! Load grid geometry information

  nx = self%Lm
  ny = self%Mm
  nz = self%N

  tile = self%tile

  LBi = self%LBi
  UBi = self%UBi
  LBj = self%LBj
  UBj = self%UBj

  Istr = self%bounds(r2dvar)%IstrD
  Iend = self%bounds(r2dvar)%IendD
  Jstr = self%bounds(r2dvar)%JstrD
  Jend = self%bounds(r2dvar)%JendD

END SUBROUTINE roms_geom_info_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_geom_get_num_levels_c (c_key_self, c_vars,                     &
                                       c_levels_size, c_levels)                &
                                 BIND (c, name='roms_geom_get_num_levels_f90')

  integer (c_int),     intent(in ) :: c_key_self
  TYPE (c_ptr), value, intent(in ) :: c_vars
  integer (c_size_t),  intent(in ) :: c_levels_size
  integer (c_size_t),  intent(out) :: c_levels(c_levels_size)

  TYPE (roms_field_metadata)       :: field_meta
  TYPE (roms_geom), pointer        :: self
  TYPE (oops_variables)            :: vars
  integer                          :: i
  character(len=:), allocatable    :: field_name

  CALL roms_geom_registry%get (c_key_self, self)
  vars = oops_variables(c_vars)

  DO i = 1,vars%nvars()

    field_name = vars%variable(i)
    field_meta = self%FieldsInfo%get(field_name)

    SELECT CASE(field_meta%levels)
      CASE ('1', 'surface')
        c_levels(i) = 1
      CASE ('full_ocn')
        IF (field_name .eq. field_meta%surface_name) THEN
          c_levels(i) = 1
        ELSE
          c_levels(i) = self%N
        END IF
      CASE DEFAULT
        CALL abor1_ftn ('c_roms_geo_get_num_levels: Unknown "levels" ' //      &
                        field_meta%levels)
    END SELECT

  END DO

END SUBROUTINE roms_geom_get_num_levels_c

! ------------------------------------------------------------------------------
!> Set ATLAS FunctionSpace pointers.

SUBROUTINE roms_geom_init_atlas_c (c_key_self, c_functionspace, c_fieldset)    &
                             BIND (c, name='roms_geom_init_atlas_f90')

  integer (c_int),     intent(in) :: c_key_self         !< Key to Geometry object
  TYPE (c_ptr), value, intent(in) :: c_functionspace    !< Key to FunctionSpace
  TYPE (c_ptr), value, intent(in) :: c_fieldset         !< Key to FieldSet

  TYPE (roms_geom), pointer       :: self

  CALL roms_geom_registry%get (c_key_self, self)

  self%functionspace = atlas_functionspace_NodeColumns(c_functionspace)

  ! Fill in the Geometry FieldSet.

  self%fieldset = atlas_fieldset(c_fieldset)
  CALL self%init_fieldset ()

END SUBROUTINE roms_geom_init_atlas_c

! ------------------------------------------------------------------------------
!> Determine the number of nodes and number of quadrilaterals cells that are
!  needed by ATLAS mesh.

SUBROUTINE roms_geom_get_mesh_size_c (c_key_self, c_nodes, c_quads)            &
                                BIND (c, name='roms_geom_get_mesh_size_f90')

  integer (c_int), intent(in ) :: c_key_self
  integer (c_int), intent(out) :: c_nodes
  integer (c_int), intent(out) :: c_quads

  TYPE (roms_geom), pointer    :: self

  logical, allocatable         :: valid_nodes(:,:), valid_cells(:,:)

  CALL roms_geom_registry%get (c_key_self, self)

  CALL self%mesh_valid_nodes_cells (valid_nodes, valid_cells)

  c_nodes = COUNT(valid_nodes)
  c_quads = COUNT(valid_cells)

END SUBROUTINE roms_geom_get_mesh_size_c

! ------------------------------------------------------------------------------
!> Generate the node and quadrilateral information that is needed by the C++
!! interface of Geometry::Geometry() to create a connected mesh in ATLAS.

SUBROUTINE roms_geom_gen_mesh_c (c_key_self, c_nodes, c_lon, c_lat, c_ghosts,  &
                                 c_global_index, c_remote_index, c_tile_index, &
                                 c_quad_nodes, c_quad_node_list)               &
                           BIND (c, name='roms_geom_gen_mesh_f90')

  integer (c_int), intent(in)    :: c_key_self
  integer (c_int), intent(in)    :: c_nodes, c_quad_nodes
  integer (c_int), intent(inout) :: c_ghosts(c_nodes)
  integer (c_int), intent(inout) :: c_global_index(c_nodes)
  integer (c_int), intent(inout) :: c_remote_index(c_nodes)
  integer (c_int), intent(inout) :: c_tile_index(c_nodes)
  integer (c_int), intent(inout) :: c_quad_node_list(c_quad_nodes)

  real (c_double), intent(inout) :: c_lon(c_nodes)
  real (c_double), intent(inout) :: c_lat(c_nodes)

  logical, parameter             :: Verbose = .TRUE.
  logical, allocatable           :: valid_nodes(:,:), valid_cells(:,:)

  integer                        :: Isize, Ioff, Joff
  integer                        :: IstrC, IendC, JstrC, JendC
  integer                        :: IstrD, IendD, JstrD, JendD
  integer                        :: IstrH, IendH, JstrH, JendH
  integer                        :: LBi, LBj, UBi, UBj
  integer                        :: cgrid, i, ic, ij, j, jc, nc, ng, nq, tile

  real (kind_real), allocatable  :: global_index(:,:)
  real (kind_real), allocatable  :: local_index(:,:)
  real (kind_real), allocatable  :: tile_index(:,:)

  character (len=254)            :: Message

  TYPE (roms_geom), pointer      :: self

  CALL roms_geom_registry%get (c_key_self, self)

  ! Grid parameters.

  ng = self%ng                           ! nested grid number
  tile = self%tile                       ! parallel partition tile

  cgrid = r2dvar                         ! staggered C-grid RHO-type (0:L,0:M)

  LBi = self%LBi                         ! I-dimension Lower bound
  UBi = self%UBi                         ! I-dimension Upper bound
  LBj = self%LBj                         ! J-dimension Lower bound
  UBj = self%UBj                         ! J-dimension Upper bound

  IstrC = self%bounds(cgrid)%IstrC       ! starting Computational I-index
  IendC = self%bounds(cgrid)%IendC       ! ending   Computational I-index
  JstrC = self%bounds(cgrid)%JstrC       ! starting Computational J-index
  JendC = self%bounds(cgrid)%JendC       ! ending   Computational J-index

  IstrD = self%bounds(cgrid)%IstrD       ! starting Data I-index
  IendD = self%bounds(cgrid)%IendD       ! ending   Data I-index
  JstrD = self%bounds(cgrid)%JstrD       ! starting Data J-index
  JendD = self%bounds(cgrid)%JendD       ! ending   Data J-index

  IstrH = self%bounds(cgrid)%IstrH       ! starting Halo I-index
  IendH = self%bounds(cgrid)%IendH       ! ending   Halo I-index
  JstrH = self%bounds(cgrid)%JstrH       ! starting Halo J-index
  JendH = self%bounds(cgrid)%JendH       ! ending   Halo J-index

  Isize = self%Lm + 2                    ! I-size for linear 2D index (Lm+2)
  Ioff  = 1                              ! because indices are 1-based
  Joff  = 0                              ! because indices are 1-based

  ! Allocate to ROMS state range bounds since we are using its parallel
  ! halo exchange, which is limited to floating-point arrays.

  allocate ( global_index(LBi:UBi, LBj:UBj) )
  allocate ( local_index (LBi:UBi, LBj:UBj) )
  allocate ( tile_index  (LBi:UBi, LBj:UBj) )

  ! Set ATLAS MeshBuilder arrays for RHO-points:
  !
  !   global_index - A 1-based global index linear counter corresponding to the
  !                  Fortran column-major order (continuous in memory) matrix.
  !                  Notice the Ioff and Joff offsets since RHO-points indices
  !                  start at zero in ROMS.
  !   local_index  - A 1-based local index on the parallel tile partion that
  !                  owns the point. It is returned as "remote_index" with
  !                  remote_index_base=1
  !   tile_index   - A 0-based rank of tile partition (task) woening the point.
  !
  !
  ! Notice that the mapping "atlas_ij2node(i,j)" can be used for RHO-, U-,
  ! and V-type variables since ROMS has a left-handed index enumeration
  ! convention. Since all the arrays are allocated (LBi:UBi, LBj:UBj, :),
  ! the non-physical for the U-variables are western/eastern boundaries
  ! and V-variables at the southern/northtern boundaries are filled with
  ! zeros in "toFieldSet" and "fromFieldSet" but never used.
  !
  !
  !   M   r..u..r..u..r..u..r..u..r..u..r..u..r..u..r..u..r..u..r..u..r
  !       :                                                           :
  !    M  v  p++v++p++v++p++v++p++v++p++v++p++v++p++v++p++v++p++v++p  v
  !       :  +     |     |     |     |     |     |     |     |     +  :
  !   Mm  r  u  r  u  r  u  r  u  r  u  r  u  r  u  r  u  r  u  r  u  r
  !       :  +     |     |     |     |     |     |     |     |     +  :
  !    Mm v  p--v--p--v--p--v--p--v--p--v--p--v--p--v--p--v--p--v--p  v
  !       :  +     |     |     |     |     |     |     |     |     +  :
  !       r  u  r  u  r  u  r  u  r  u  r  u  r  u  r  u  r  u  r  u  r
  !       :  +     |     |     |     |     |     |     |     |     +  :
  !       v  p--v--p--v--p--v--p--v--p--v--p--v--p--v--p--v--p--v--p  v
  !       :  +     |     |     |     |     |     |     |     |     +  :
  !       r  u  r  u  r  u  r  u  r  u  r  u  r  u  r  u  r  u  r  u  r
  !       :  +     |     |     |     |     |     |     |     |     +  :
  !       v  p--v--p--v--p--v--p--v--p--v--p--v--p--v--p--v--p--v--p  v
  !       :  +     |     |     |     |     |     |     |     |     +  :
  !   2   r  u  r  u  r  u  r  u  r  u  r  u  r  u  r  u  r  u  r  u  r
  !       :  +     |     |     |     |     |     |     |     |     +  :
  !    2  v  p--v--p--v--p--v--p--v--p--v--p--v--p--v--p--v--p--v--p  v
  !       :  +     |     |     |     |     |     |     |     |     +  :
  !   1   r  u  r  u  r  u  r  u  r  u  r  u  r  u  r  u  r  u  r  u  r
  !       :  +     |     |     |     |     |     |     |     |     +  :
  !    1  v  p++v++p++v++p++v++p++v++p++v++p++v++p++v++p++v++p++v++p  v
  !       :                                                           :
  !   0   r..u..r..u..r..u..r..u..r..u..r..u..r..u..r..u..r..u..r..u..r
  !          1     2                                         Lm    L
  !       0     1     2                                         Lm    L

  ic = 0

  DO j = JstrH, JendH
    jc = (j-Joff)*Isize
    DO i = IstrH, IendH
      IF (((JstrD.le.j).and.(j.le.JendC+1)).and.                               &
          ((IstrD.le.i).and.(i.le.IendC+1))) THEN          
        ic = ic + 1
        global_index(i,j) = REAL(i+Ioff+jc, kind_real)
        local_index (i,j) = REAL(ic, kind_real)
        tile_index  (i,j) = REAL(tile, kind_real)
      END IF
    END DO
  END DO

  ! Fill parallel halo points: operation on floating-point data.

  CALL mp_exchange2d (ng, tile, iNLM, 3,                                       &
                      LBi, UBi, LBj, UBj,                                      &
                      self%NghostPoints,                                       &
                      self%EWperiodic, self%NSperiodic,                        &
                      global_index,                                            &
                      local_index,                                             &
                      tile_index)

  ! Find which nodes and cells are skipped.

  CALL self%mesh_valid_nodes_cells (valid_nodes, valid_cells)

  ! In ATLAS, the ghost points are filled by different parallel tasks with
  ! halo exchanges.

  c_ghosts = 1                           ! unowned ghost points

  ! Fill in the node arrays on computational points to return to the C++
  ! interface. Save linear mapping from (i,j) to node count and vice versa.

  nc = 0

  DO j = JstrD, JendC+1
    DO i = IstrD, IendC+1

        nc = nc + 1                      ! 1-based node count: local per tile

        IF ((i.le.IendD).and.(j.le.JendD)) THEN
          c_ghosts(nc) = 0
          self%atlas_ij2node(i,j) = nc   ! (i,j) to node mapping
        END IF

        c_lon(nc) = self%lonr(i,j)
        c_lat(nc) = self%latr(i,j)

        c_global_index(nc) = INT(global_index(i,j))
        c_remote_index(nc) = INT(local_index(i,j))
        c_tile_index  (nc) = INT(tile_index(i,j))

    END DO
  END DO

  ! Fill in the quadrilateral cell node list (vertices).

  nq = 1
                 
  DO j = JstrD, JendC
    DO i = IstrD, IendC
      c_quad_node_list(nq  ) = INT(global_index(i  ,j  ))
      c_quad_node_list(nq+1) = INT(global_index(i  ,j+1))
      c_quad_node_list(nq+2) = INT(global_index(i+1,j+1))
      c_quad_node_list(nq+3) = INT(global_index(i+1,j  ))
      nq = nq + 4
    END DO
  END DO

  ! If requested, Report mesh parameters and arrays.

  IF (LdebugGeometry) THEN
    PRINT 10, 'ROMS_DEBUG roms_geom::gen_mesh_c: tile = ', tile,               &
                                     ', ng = ', ng,                            &
                                     ', 2D SHAPE = ',SHAPE(self%atlas_ij2node),&
                                     '  LBi   = ', LBi,                        &
                                     ', UBi   = ', UBi,                        &
                                     ', LBj   = ', LBj,                        &
                                     ', UBj   = ', UBj,                        &
                                     '  IstrD = ', IstrD,                      &
                                     ', IendD = ', IendD,                      &
                                     ', JstrD = ', JstrD,                      &
                                     ', JendD = ', JendD,                      &
                                     '  nodes = ', c_nodes,                    &
                                     '  counted = ', nc,                       &
                                     '  quads = ', c_quad_nodes,               &
                                     '  counted = ', nq-1
 10 FORMAT (a,i3,a,i0,a,2(i0,1x),2(/,t33,4(a,i4)),/,t33,2(a,i0),/,t33,2(a,i0))
    CALL self%f_comm%barrier()

    IF (Verbose) THEN                                  ! Fortran unit per task
      WRITE (100+tile,20) 'i', 'j', 'tile', 'ghost',                           &
                          'global', 'ij2node', 'local',                        &
                          'g(i,j)', 'g(i+1,j)', 'g(i,j+1)', 'g(i+1,j+1)'
 20   FORMAT (2(4x,a),2(2x,a),4x,a,3x,a,5x,a,4x,a,3(2x,a),/)

      DO j = JstrD, JendC
        DO i = IstrD, IendC
          ij = self%atlas_ij2node(i,j)
          WRITE (100+tile,30) i, j, INT(tile_index(i,j)), c_ghosts(ij),        &
                              INT(global_index(i,j)), ij,                      &
                              INT(local_index(i,j)),                           &
                              INT(global_index(i  ,j  )),                      &
                              INT(global_index(i+1,j  )),                      &
                              INT(global_index(i  ,j+1)),                      &
                              INT(global_index(i+1,j+1))
 30       FORMAT (2i5,1x,i5,2x,i5,8i10)
        END DO
      END DO
    END IF
  END IF

  IF (c_nodes .ne. nc) THEN
    WRITE (Message,40) tile, ', c_nodes = ', c_nodes, ' and nc = ',            &
                       nc, ' are not equal.'
 40 FORMAT (i4.4, a, 2(i0,a))
    CALL abor1_ftn ("roms_geom::gen_mesh_c: Error tile = " // TRIM(Message))
  END IF

  IF (c_quad_nodes .ne. nq-1) THEN
    WRITE (Message,40) tile, ', c cquad_nodes = ', c_quad_nodes, ' and nq = ', &
                       nq, ' are not equal.'
    CALL abor1_ftn ("roms_geom::gen_mesh: Error tile = " // TRIM(Message))
  END IF

END SUBROUTINE roms_geom_gen_mesh_c

! ------------------------------------------------------------------------------

END MODULE roms_geom_mod_c
