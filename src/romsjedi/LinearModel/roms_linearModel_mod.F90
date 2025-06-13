#undef ZERO_TRAJECTORY

! (C) Copyright 2017-2025 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

MODULE roms_linearModel_mod

USE kinds,                      ONLY : kind_real

USE iso_c_binding

USE datetime_mod,               ONLY : datetime,                               &
                                       datetime_create,                        &
                                       datetime_set
USE duration_mod
USE fckit_configuration_module, ONLY : fckit_configuration
USE fckit_mpi_module,           ONLY : fckit_mpi_comm
USE oops_variables_mod

!> ROMS modules association.

USE mod_boundary
USE mod_coupling
USE mod_forces
USE mod_grid
USE mod_mixing
USE mod_ocean

USE roms_kernel_mod

USE dateclock_mod,              ONLY : time_string
USE mod_param,                  ONLY : iADM, iNLM, iTLM, Ngrids
USE mod_parallel,               ONLY : Cend, Cstr, Csum, Ctotal, total_cpu
USE mod_scalars,                ONLY : INItime, NoError, dt, exit_flag,        &
                                       indx1, iic, jic, ntstart, ntend,        &
                                       ntimes, time, time4jedi
USE mod_stepping,               ONLY : kstp, krhs, knew, nrhs, nstp, nnew

!> ROMS-JEDI interface module association.

USE roms_field_mod,             ONLY : roms_field
USE roms_fieldsutils_mod,       ONLY : date2string,                            &
                                       LdebugLinearModel,                      &
                                       roms_date2time,                         &
                                       roms_tracer_index
USE roms_geom_mod,              ONLY : roms_geom,                              &
                                       roms_tile
USE roms_increment_mod,         ONLY : roms_increment
USE roms_state_mod,             ONLY : roms_state
USE roms_trajectory_mod,        ONLY : roms_trajectory
USE roms_utils_mod,             ONLY : vector_a_to_c,                          &
                                       vector_a_to_c_ad,                       &
                                       vector_c_to_a,                          &
                                       vector_c_to_a_ad

implicit none

!> Local routines.

PRIVATE :: jedi2roms_traj                  ! Pass nonlinear trajectory to ROMS
PRIVATE :: roms2jedi_incr                  ! Load TL/AD solution into increment

!-------------------------------------------------------------------------------
!> Fortran derived type object to hold LinearModel definition

TYPE, PUBLIC :: roms_linearModel

  TYPE (fckit_mpi_comm) :: f_comm

  TYPE (roms_tile)      :: bounds(4)       ! tile indice range

  integer :: ng                            ! nested grid number
  integer :: tile                          ! domain parallel partition tile

  integer :: NghostPoints                  ! number of tile ghost points
  integer :: LBi, UBi, LBj, UBj, LBk, UBk  ! array(i,j,k) allocation bounds
  integer :: N                             ! number of vertical levels

  integer :: Tindex                        ! Trajectory snapshot time index

  real(kind=kind_real) :: dt               ! baroclinic timestep size (s)
  real(kind=kind_real) :: INItime          ! Initial conditions time (s)
  real(kind=kind_real) :: RunInterval      ! timestepping interval (s)
  real(kind=kind_real) :: SimulationPeriod ! total simulation period (s)
  real(kind=kind_real) :: time             ! current ROMS LM time (s)

  character (len=20)   :: iso_datetime     ! current ROMS ISO8601 date/time
  character (len=22)   :: roms_datetime    ! current ROMS date/time

  CONTAINS

    PROCEDURE :: create        => roms_linearModel_create
    PROCEDURE :: delete        => roms_linearModel_delete
    PROCEDURE :: initialize_tl => roms_linearModel_initialize_tl
    PROCEDURE :: initialize_ad => roms_linearModel_initialize_ad
    PROCEDURE :: step_tl       => roms_linearModel_step_tl
    PROCEDURE :: step_ad       => roms_linearModel_step_ad
    PROCEDURE :: finalize_tl   => roms_linearModel_finalize_tl
    PROCEDURE :: finalize_ad   => roms_linearModel_finalize_ad

END TYPE roms_linearModel

!-------------------------------------------------------------------------------

PRIVATE

! Set switch to read ROMS standard input parameter file and allocate and
! initialize (first touch policy) variables and structures. It needs to be
! done once for each simulation.

logical :: LsetROMS
integer :: AD_inner, TL_inner

TYPE (fckit_mpi_comm) :: my_comm

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
!> Creates ROMS LinearModel object.

SUBROUTINE roms_linearModel_create (self, geom, f_conf)

  CLASS (roms_linearModel),   intent(inout) :: self    !< LinearModel object
  CLASS (roms_geom),          intent(in   ) :: geom    !< Geometry object
  TYPE (fckit_configuration), intent(in   ) :: f_conf  !< Configuration object

  TYPE (datetime)                           :: iniDate !> IC date/time
  TYPE (duration)                           :: dtYAML  !> ISO8601 duration
  real (kind=kind_real)                     :: dtJEDI  !> JEDI interval (seconds)

  integer                                   :: LocalPET, ng
  real (kind=kind_real)                     :: romsDateNumber, romsTime(Ngrids)
  character (len=:), allocatable            :: string

  !> Initialize.

  LocalPET = self%f_comm%rank()
  ng       = geom%ng
  AD_inner = -1                      ! OOPS runs an additional two sets
  TL_inner = -1                      ! TLM/ADM at the beggining with RPCG

  !> Get initial conditions date from YAML file.

  CALL f_conf%get_or_die ("date", string)
  CALL datetime_create (string, iniDate)
  deallocate (string)
  CALL roms_date2time (LocalPET, iniDate, romsTime(ng), romsDateNumber)
  self%INItime = romsTime(ng)

  !> Get time step duration from YAML file and convert to seconds.  It can be
  !> a single ROMS timestep, dt(ng), as specified in ROMS standard input
  !> script or and integer factor of dt(ng).  

  CALL f_conf%get_or_die ("tstep", string)
  dtYAML = TRIM(string)
  deallocate (string)
  dtJEDI = duration_seconds(dtYAML)

  !> Get simulation length period from YAML file and convert to seconds.  It is
  !> used to overwrite ROMS internal stepping integration 'NTIMES' parameter set
  !> in the standard input file.

  CALL f_conf%get_or_die ("simulation length", string)
  dtYAML = TRIM(string)
  deallocate (string)
  self%SimulationPeriod = duration_seconds(dtYAML)

  !> Set ROMS time integration interval.

  self%RunInterval = dtJEDI

  !> Set MPI Fortran object.

  self%f_comm = geom%f_comm

  !> Domain decomposition ranges and indices.

  self%ng   = ng
  self%tile = geom%tile

  self%NghostPoints = geom%NghostPoints ! number of ghost points

  self%LBi = geom%LBi                   ! lower bound I-dimension
  self%UBi = geom%UBi                   ! upper bound I-dimension
  self%LBj = geom%LBj                   ! lower bound J-dimension
  self%UBj = geom%UBj                   ! upper bound J-dimension

  self%bounds = geom%bounds             ! tile indices range

  self%N   = geom%N                     ! number of vertical levels
  self%LBk = 1                          ! lower bound K-dimension
  self%UBk = geom%N                     ! upper bound K-dimension

END SUBROUTINE roms_linearModel_create

! ------------------------------------------------------------------------------
!> Destroys ROMS kernels object.

SUBROUTINE roms_linearModel_delete (self)

  CLASS (roms_linearModel), intent(inout) :: self     !< LinearModel object

  !> Deallocates ROMS state arrays and vectors.

  CALL ROMS_deallocate_arrays

END SUBROUTINE roms_linearModel_delete

! ------------------------------------------------------------------------------
!> It initializes adjoint model (ADROMS) kernel.

SUBROUTINE roms_linearModel_initialize_ad (self, geom, Incr, Traj1, Traj2,     &
                                           fac1, fac2, vdate)

  CLASS (roms_linearModel), intent(inout) :: self    !< LinearModel object
  CLASS (roms_geom),        intent(in   ) :: geom    !< Geometry object
  CLASS (roms_increment),   intent(inout) :: Incr    !< Increment object
  CLASS (roms_trajectory),  intent(in   ) :: Traj1   !< Trajectory time-1
  CLASS (roms_trajectory),  intent(in   ) :: Traj2   !< Trajectory time-2
  real (kind=kind_real),    intent(in   ) :: fac1    !< time-1 interp weight
  real (kind=kind_real),    intent(in   ) :: fac2    !< time-2 interp weight
  TYPE (datetime),          intent(in   ) :: vdate   !< Increment valid DateTime

  integer                                 :: LocalPET, MyComm, my_ntimes, ng
  integer                                 :: Tindex2d, Tindex3d
  character (len=22)                      :: DateString
  character (len=80)                      :: ncname

  !> Get MPI communicator and PET rank. Get nested grid number.

  MyComm   = self%f_comm%communicator()
  LocalPET = self%f_comm%rank()
  ng       = self%ng
  AD_inner = AD_inner + 1

  !> Get JEDI increment valid DateTime string.

  CALL date2string (vdate, DateString, ISO=.FALSE.)

  !> Clean state arrays.

  CALL initialize_boundary (self%ng, self%tile, 0)
  CALL initialize_coupling (self%ng, self%tile, 0)
  CALL initialize_grid     (self%ng, self%tile, iADM)
  CALL initialize_ocean    (self%ng, self%tile, 0)

  !> Load nonlinear background trajectory into ROMS, which is used to linearize
  !> the adjoint model discrete equations. If appropriate, interpolate from
  !> time snapshots.

  CALL jedi2roms_traj (ng, Traj1, Traj2, fac1, fac2)

  !> ROMS-JEDI phase 1 initialization. If appropriate, read in standard input
  !> parameters. Then, allocate/initialize parameters and variables when switch
  !> LsetROMS is on. It sets time-stepping indices as kstp=1, knew=2, krhs=3,
  !> nstp=1, nnew=2, and nrhs=nnew.

  LsetROMS = .TRUE.
  IF (allocated(BOUNDS)) LsetROMS = .FALSE.

  CALL ROMS_initializeP1 (LsetROMS,                                            &
                          mpiCOMM = MyComm,                                    &
                          kernel  = iADM)
  IF (exit_flag .ne. NoError) THEN
    CALL abor1_ftn ("roms_linearModel::initialize_ad: "//                      &
                    "Error in ROMS_initializeP1")
  END IF

  !> Set ROMS initial conditions time (s).  It is need to set-up ROMS 
  !> timestepping counters correctly.

  INItime(ng) = self%INItime

  !> Reset ROMS total number of timesteps, if shorter simulation time period is
  !> is specified in the YAML file.

  my_ntimes = INT(self%SimulationPeriod/dt(ng))

  IF (my_ntimes .ne. ntimes(ng)) THEN
    IF (LocalPET .eq. 0)                                                       &
      PRINT '(2(a,i0))', ' roms_linearModel::initialize_ad: Reset input '//    &
                         'parameter, NTIMES = ', ntimes(ng), ' to ', my_ntimes
    ntimes(ng) = my_ntimes
  END IF

  ! The adjoint driver requires the reverse ROMS-to-JEDI variable changes
  ! and the control vector exchanges before time-stepping.

  Tindex2d = kstp(ng)                                    ! timestep 2D index
  Tindex3d = nstp(ng)                                    ! timestep 3D index

  CALL Incr%zero_boundary ()
  CALL roms2jedi_incr (ng, iADM, Tindex2d, Tindex3d, geom, Incr, DateString)

  !> Write out OOPS initial increment.

  IF (LdebugLinearModel) THEN
    WRITE (ncname,10) 'Data/increment/oops_iad_', AD_inner
 10 FORMAT (a,i2.2,'.nc')
    CALL Incr%write_debug (ncname, vdate,                                      &
                           AddZeroFields = .TRUE.)       ! create and write
  END IF

  !> ROMS-JEDI phase 2 initialization. Complete the initialization using
  !> the state fields loaded above. Compute depths, density, and horizontal
  !> mass fluxes.

  CALL ROMS_initializeP2 (iADM)
  IF (exit_flag .ne. NoError) THEN
    CALL abor1_ftn ("roms_linaermodel::initialize_ad: "//                      &
                    "Error in ROMS_initializeP2")
  END IF

  !> Execute the adjoint of the tangent linear last half-step that processes
  !> and writes the ADM output solution. The ADROMS kernel is not timestepped
  !> since AD_ADVANCE is false on the first pass. However, several routines
  !> are called after the AD_ADVANCE IF-block, including ad_rhs3d, ad_set_zeta,
  !> ad_omega, ad_set_vbc, ad_rho_eos, ad_set_massflux, ad_diag, ad_out_fields,
  !> ad_set_depths, ad_out_zeta, and ad_output. The nonlinear background
  !> trajectory is needed in these routines, and the following state adjoint
  !> variables are updated: ad_t(nrhs), ad_u(nrhs), ad_v(nrhs), and
  !> ad_zeta(1:2), among others. The 3D timestepping indices are updated as:
  !> nrhs=nnew, nnew=nstp, nstp=nrhs in that order.

  CALL ROMS_run (self%RunInterval, kernel=iADM)
  IF (exit_flag .ne. NoError) THEN
    IF ((LEN_TRIM(blowup_string).gt.0).and.(my_comm%rank().eq.0)) THEN
      PRINT '(a,/,2a)', 'roms_model:initialize_ad Abnormal remination: ',      &
                        'BLOWUP. REASON: ', TRIM(blowup_string)
    END IF
    CALL abor1_ftn ("roms_linearModel::initialize_ad: "//                      &
                    "Error while calling ROMS_run")
  END IF

  !> After half-step ADROMS, perform adjoint JEDI-to-ROMS reverse variable
  !> changes and the control vector updating.

  Tindex2d = kstp(ng)                                    ! timestep 2D index
  Tindex3d = nstp(ng)                                    ! timestep 3D index

  CALL jedi2roms_incr (ng, iADM, Tindex2d, Tindex3d, geom, Incr, DateString)

  !> If debugging, write out ADM initial state vector into ROMS-JEDI history,
  !> which can be used to compare to native ROMS solution.

  IF (LdebugLinearModel) THEN
    WRITE (ncname,10) 'Data/trajectory/roms_jedi_adj_', AD_inner
    CALL Incr%write_debug (ncname, vdate)                ! create and write
  END IF

END SUBROUTINE roms_linearModel_initialize_ad

! ------------------------------------------------------------------------------
!> It initializes tangent linear model (TLROMS) kernel.

SUBROUTINE roms_linearModel_initialize_tl (self, geom, Incr, Traj1, Traj2,     &
                                           fac1, fac2, vdate)

  CLASS (roms_linearModel), intent(inout) :: self    !< LinearModel object
  CLASS (roms_geom),        intent(in   ) :: geom    !< Geometry object
  CLASS (roms_increment),   intent(inout) :: incr    !< Increment object
  CLASS (roms_trajectory),  intent(in   ) :: Traj1   !< Trajectory time-1
  CLASS (roms_trajectory),  intent(in   ) :: Traj2   !< Trajectory time-2
  real (kind=kind_real),    intent(in   ) :: fac1    !< time-1 interp weight
  real (kind=kind_real),    intent(in   ) :: fac2    !< time-2 interp weight
  TYPE (datetime),          intent(in   ) :: vdate   !< Increment valid DateTime

  integer                                 :: LocalPET, MyComm, my_ntimes, ng
  integer                                 :: Tindex2d, Tindex3d
  character (len=22)                      :: DateString
  character (len=80)                      :: ncname

  !> Get MPI communicator and PET rank. Get nested grid number.

  MyComm   = self%f_comm%communicator()
  LocalPET = self%f_comm%rank()
  ng       = self%ng
  TL_inner = TL_inner + 1

  !> Get JEDI increment valid DateTime string.

  CALL date2string (vdate, DateString, ISO=.FALSE.)

  !> Clean state arrays.

  CALL initialize_boundary (self%ng, self%tile, 0)
  CALL initialize_coupling (self%ng, self%tile, 0)
  CALL initialize_grid     (self%ng, self%tile, iTLM)
  CALL initialize_ocean    (self%ng, self%tile, 0)

  ! Load nonlinear background trajectory into ROMS, which is used to linearize
  ! the tangent linear discrete equations. Interpolate from time snapshots.

  CALL jedi2roms_traj (ng, Traj1, Traj2, fac1, fac2)

  !> ROMS-JEDI phase 1 initialization. If appropriate, read in standard input
  !> parameters. Then, allocate/initialize parameters and variables when switch
  !> LsetROMS is on. It sets time-stepping indices as kstp=1, knew=1, krhs=1,
  !> nstp=1, nnew=1, and nrhs=1.

  !> LsetROMS is on. It sets stepping parameters.

  LsetROMS = .TRUE.
  IF (allocated(BOUNDS)) LsetROMS = .FALSE.

  CALL ROMS_initializeP1 (LsetROMS,                                            &
                          mpiCOMM = MyComm,                                    &
                          kernel  = iTLM)
  IF (exit_flag .ne. NoError) THEN
    CALL abor1_ftn ("roms_linearModel::initialize_tl: "//                      &
                    "Error in ROMS_initializeP1")
  END IF

  !> Set ROMS initial conditions time (s).  It is needed to set-up ROMS 
  !> timestepping counters correctly.

  INItime(ng) = self%INItime

  !> Reset ROMS total number of timesteps, if shorter simulation time period is
  !> is specified in the YAML file.

  my_ntimes = INT(self%SimulationPeriod/dt(ng))

  IF (my_ntimes .ne. ntimes(ng)) THEN
    IF (LocalPET .eq. 0)                                                       &
      PRINT '(2(a,i0))', ' roms_linearModel::initialize_tl: Reset input '//    &
                         'parameter, NTIMES = ', ntimes(ng), ' to ', my_ntimes
    ntimes(ng) = my_ntimes
  END IF

  !> Load JEDI initial state fields into ROMS TLM arrays. At initialization,
  !> all time indices are set to one. The TLM needs zero lateral boundaries.

  Tindex2d = kstp(ng)                                    ! timestep 2D index
  Tindex3d = nstp(ng)                                    ! timestep 3D index

  CALL Incr%zero_boundary ()
  CALL jedi2roms_incr (ng, iTLM, Tindex2d, Tindex3d, geom, Incr, DateString)

  !> Write out OOPS initial increment.

  IF (LdebugLinearModel) THEN
    WRITE (ncname,10) 'Data/increment/oops_itl_', TL_inner
 10 FORMAT (a,i2.2,'.nc')
    CALL Incr%write_debug (ncname, vdate,                                      &
                           AddZeroFields = .TRUE.)       ! create and write
  END IF

  !> ROMS-JEDI phase 2 initialization. Compleate the initialization using
  !> the state fields loaded above. Compute depths, density, and horizontal
  !> mass fluxes.

  CALL ROMS_initializeP2 (iTLM)
  IF (exit_flag .ne. NoError) THEN
    CALL abor1_ftn ("roms_linearModel::initialize_tl: "//                      &
                    "Error in ROMS_initializeP2")
  END IF

  !> ROMS-JEDI phase 3 initialization. Compute the initial depths and
  !> level thicknesses from the initial free-surface field. Additionally,
  !> initialize the nonlinear state variables for all time levels and
  !> applies lateral boundary conditions.

  CALL ROMS_initializeP3 (iTLM)
  IF (exit_flag .ne. NoError) THEN
    IF ((LEN_TRIM(blowup_string).gt.0) .and. (LocalPET.eq.0)) THEN
      PRINT '(a,/,2a)','roms_model::initialize Abnormal termination: BLOWUP.', &
                       'REASON: ', TRIM(blowup_string)
    END IF
    CALL abor1_ftn ("roms_model::initialize Error while calling ROMS_run")
  END IF

  !> TLROMS applied lateral boundary conditions to the initial increment
  !> vector. Pass the outdated increment vector back to JEDI.

  CALL roms2jedi_incr (ng, iTLM, Tindex2d, Tindex3d, geom, Incr, DateString)

  !> If debugging, write out TLM initial state vector into ROMS-JEDI history,
  !> which can be used to compare to native ROMS solution.

  IF (LdebugLinearModel) THEN
    WRITE (ncname,10) 'Data/trajectory/roms_jedi_tlm_', TL_inner
    CALL Incr%write_debug (ncname, vdate)                  ! create and write
  END IF

END SUBROUTINE roms_linearModel_initialize_tl

! ------------------------------------------------------------------------------
!> It timesteps backward adjoint model (ADROMS) kernel for the specified time
!! interval in seconds.

SUBROUTINE roms_linearModel_step_ad (self, geom, Incr, Traj1, Traj2,           &
                                     fac1, fac2, vdate)

  CLASS (roms_linearModel), intent(inout) :: self    !< LinearModel object
  CLASS (roms_geom),        intent(in   ) :: geom    !< Geometry object
  CLASS (roms_increment),   intent(inout) :: Incr    !< Increment object
  CLASS (roms_trajectory),  intent(in   ) :: Traj1   !< Trajectory time-1
  CLASS (roms_trajectory),  intent(in   ) :: Traj2   !< Trajectory time-2
  real (kind=kind_real),    intent(in   ) :: fac1    !< time-1 interp weight
  real (kind=kind_real),    intent(in   ) :: fac2    !< time-2 interp weight
  TYPE (datetime),          intent(inout) :: vdate   !< Increment valid DateTime

  integer                                 :: LocalPET, ng
  integer                                 :: Tindex2d, Tindex3d
  character (len=22)                      :: DateString
  character (len=80)                      :: ncname

  ! Initialize.

  LocalPET = self%f_comm%rank()
  ng       = self%ng

  CALL date2string (vdate, DateString, ISO=.FALSE.)

  ! Load nonlinear background trajectory into ROMS, which is used to linearize
  ! the adjoint model discrete equations.  Interpolate from time snapshots.

  CALL jedi2roms_traj (ng, Traj1, Traj2, fac1, fac2)

  ! The adjoint driver requires the reverse ROMS-to-JEDI variable changes
  ! and the control vector exchanges before time-stepping.

  Tindex2d = kstp(ng)                 ! RHS 2D-equations time index
  Tindex3d = nstp(ng)                 ! RHS 3D-equations time index

  CALL roms2jedi_incr (ng, iADM, Tindex2d, Tindex3d, geom, Incr, DateString)

  ! Timestep backward ADROMS by the specified RunInterval (often a single
  ! timestep) in seconds. Recall that ROMS kernels have a predictor/corrector
  ! time-stepping scheme with multiple time indices.
  !
  ! Unlike the TLM kernel, the adjoint of phase 3 initialization does not
  ! require special treatment in the ADM last timestep since it is done in
  ! the usual way in "ad_main3d" by calling "ad_post_initial".

  CALL ROMS_run (self%RunInterval, kernel=iADM)
  IF (exit_flag .ne. NoError) THEN
    IF ((LEN_TRIM(blowup_string).gt.0).and.(my_comm%rank().eq.0)) THEN
      PRINT '(a,/,2a)', 'roms_model::step_ad: Abnormal termination.',          &
                        'BLOWUP REASON: ', TRIM(blowup_string)
    END IF
    CALL abor1_ftn ("roms_linearModel::step_ad Error while calling ROMS_run")
  END IF

  self%time = time4jedi(ng)
  CALL time_string (self%time, self%roms_datetime)

  ! After time-stepping ADROMS, perform adjoint JEDI-to-ROMS reverse variable
  ! changes and the control vector updating.
  !
  ! Notice that ADROMS updates the time-level rolling indices at the bottom of
  ! the backward time-stepping kernel. Thus, we must use "nstp" instead of
  ! "nnew" time levels when updating the control increment vector.

  Tindex2d = kstp(ng)                 ! 2D-equations time index
  Tindex3d = nstp(ng)                 ! 3D-equations time index

  CALL jedi2roms_incr (ng, iADM, Tindex2d, Tindex3d, geom, Incr,               &
                       self%roms_datetime)

  !> If debugging, write out increment vector into ROMS-JEDI ADM history, which
  !> can be used to compare to native ROMS solution.

  IF (LdebugLinearModel) THEN
    WRITE (ncname,10) 'Data/trajectory/roms_jedi_adj_', AD_inner
 10 FORMAT (a,i2.2,'.nc')
    CALL Incr%write_debug (ncname, vdate,                                      &
                           Append = .TRUE.)              ! append records
  END IF

END SUBROUTINE roms_linearModel_step_ad

! ------------------------------------------------------------------------------
!> It timesteps forward tangent linear model (TLROMS) kernel for the specified
!! time interval in seconds.

SUBROUTINE roms_linearModel_step_tl (self, geom, Incr,  Traj1, Traj2,          &
                                     fac1, fac2, vdate)

  CLASS (roms_linearModel), intent(inout) :: self    !< LinearModel object
  CLASS (roms_geom),        intent(in   ) :: geom    !< Geometry object
  CLASS (roms_increment),   intent(inout) :: Incr    !< Increment object
  CLASS (roms_trajectory),  intent(in   ) :: Traj1   !< Trajectory time-1
  CLASS (roms_trajectory),  intent(in   ) :: Traj2   !< Trajectory time-2
  real (kind=kind_real),    intent(in   ) :: fac1    !< time-1 interp weight
  real (kind=kind_real),    intent(in   ) :: fac2    !< time-2 interp weight
  TYPE (datetime),          intent(inout) :: vdate   !< Increment valid DateTime

  integer                                 :: Tindex2d, Tindex3d, my_nstp, ng
  character (len=22)                      :: DateString
  character (len=80)                      :: ncname

  ! Initialize.

  ng = self%ng

  ! Get JEDI increment valid DateTime string.

  CALL date2string (vdate, DateString, ISO=.FALSE.)

  ! Load nonlinear background trajectory into ROMS, which is used to linearize
  ! the TLROMS discrete equations. The NL trajectory is unnecessary for the
  ! last full timestep since TL ROMS advances from "nstp" to "nnew". Neither
  ! is it necessary for the ending half step. Interpolate from time snapshots.

  CALL jedi2roms_traj (ng, Traj1, Traj2, fac1, fac2)

  ! The tangent linear driver requires JEDI-to-ROMS variable changes and the
  ! control vector updating before time-stepping.
  !
  ! Note that "tl_step2d" will start the TLROMS barotropic 2D time stepping
  ! with krhs=kstp=1 and knew=3 for iif=1 predictor step. However, the value
  ! of Tindex2d is not used in "jedi2roms_incr" because "tl_Zt_avg1" is the
  ! state variable active in TLROMS 3D kernel. The values of tl_zeta(:,:,1:2)
  ! are initialize to "tl_Zt_avg1" by calling "tl_set_zeta" before entering
  ! the TLROMS 2D kernel. Therefore, we only need to update "tl_Zt_avg1" when
  ! calling "jedi2roms_inc".
  !
  ! Similarly, the 3D time stepping uses nrhs=nstp with oscillating values
  ! between 1 and 2, and defines nstp=1+MOD(iic-ntstart,2). Since the 3D time
  ! indices are updated on entry into 'tl_main3d', we need to use here the
  ! value that will be assigned there.

  my_nstp  = 1 + MOD(iic(ng)-ntstart(ng),2)

  Tindex2d = kstp(ng)                 ! RHS 2D-equations time index
  Tindex3d = my_nstp                  ! RHS 3D-equations time index

  CALL jedi2roms_incr (ng, iTLM, Tindex2d, Tindex3d, geom, Incr, DateString)

  ! Advance TLROMS by the specified RunInterval (often a single timestep) in
  ! seconds. Recall that ROMS kernels have a predictor/corrector time-stepping
  ! scheme with multiple time indices. 

  CALL ROMS_run (self%RunInterval, kernel=iTLM)
  IF (exit_flag .ne. NoError) THEN
    IF ((LEN_TRIM(blowup_string).gt.0).and.(my_comm%rank().eq.0)) THEN
      PRINT '(a,/,2a)', 'roms_model::step Abnormal remination: BLOWUP.',       &
                        'REASON: ', TRIM(blowup_string)
    END IF
    CALL abor1_ftn ("roms_linearModel::step_tl Error while calling ROMS_run")
  END IF

  ! Update increment fields with current TLROMS solution. 
  !
  ! ROMS updates the time-level rolling indices at the beginning of the
  ! time-stepping TLM kernel, "tl_main3d".. Thus, "nnew" is the correct time
  ! level for the 3D solution to process here.

  Tindex2d = knew(ng)                 ! 2D coupling index in tl_step3d_uv
  Tindex3d = nnew(ng)                 ! current 3D solution at the of tl_main3d

  CALL roms2jedi_incr (ng, iTLM, Tindex2d, Tindex3d, geom, Incr, DateString)

  ! If debugging, write out increment vector into ROMS-JEDI TLM history, which
  ! can be used to compare to native ROMS solution.

  IF (LdebugLinearModel) THEN
    WRITE (ncname,10) 'Data/trajectory/roms_jedi_tlm_', TL_inner
 10 FORMAT (a,i2.2,'.nc')
    CALL Incr%write_debug (ncname, vdate,                                      &
                           Append = .TRUE.)              ! append records
  END IF

  ! If last timestep, run the last-half step to finich all ROMS native delayed
  ! output, which does not affect the ROMS-JEDI inteface.
  
  IF (iic(ng).eq.ntend(ng)+1) THEN 
    CALL ROMS_run (self%RunInterval, kernel=iTLM)
    IF (exit_flag .ne. NoError) THEN
      IF ((LEN_TRIM(blowup_string).gt.0).and.(my_comm%rank().eq.0)) THEN
        PRINT '(a,/,2a)', 'roms_model::step Abnormal remination: BLOWUP.',     &
                          'REASON: ', TRIM(blowup_string)
      END IF
      CALL abor1_ftn ("roms_linearModel::step_tl Error while calling "//       &
                      "ROMS_run last step")
    END IF
  END IF

END SUBROUTINE roms_linearModel_step_tl

! ------------------------------------------------------------------------------
!> It finalizes adjoint model (ADROMS) kernel integration.

SUBROUTINE roms_linearModel_finalize_ad (self, geom, Incr)

  CLASS (roms_linearModel), intent(inout) :: self    !< LinearModel object
  CLASS (roms_geom),        intent(in   ) :: geom    !< Geometry object
  CLASS (roms_increment),   intent(inout) :: Incr    !< Increment object

  ! Finalize ADROMS kernel integration.
  !
  ! Since the adjoint kernel is used primarily in iterative algorithms, the
  ! variables in several ROMS structures are initialized to zero, as it is
  ! done in ROMS native adjoint-based algorithms.

  CALL initialize_coupling (self%ng, self%tile, 0)
  CALL initialize_forces   (self%ng, self%tile, 0)
  CALL initialize_grid     (self%ng, self%tile, iADM)
  CALL initialize_mixing   (self%ng, self%tile, 0)
  CALL initialize_ocean    (self%ng, self%tile, 0)

  Cstr(:,iADM,:) = 0.0_kind_real                 ! Zeroth-out profiling arrays
  Cend(:,iADM,:) = 0.0_kind_real
  Csum(:,iADM,:) = 0.0_kind_real
  Ctotal         = 0.0_kind_real
  total_cpu      = 0.0_kind_real

END SUBROUTINE roms_linearModel_finalize_ad

! ------------------------------------------------------------------------------
!> It finalizes tangent linear model (TLROMS) kernel integration.

SUBROUTINE roms_linearModel_finalize_tl (self, geom, Incr)

  CLASS (roms_linearModel), intent(inout) :: self    !< LinearModel object
  CLASS (roms_geom),        intent(in   ) :: geom    !< Geometry object
  CLASS (roms_increment),   intent(inout) :: Incr    !< Increment object

  ! Finalize TLROMS kernel integration.
  !
  ! Since the tangent linear kernel is used primarily in iterative algorithms,
  ! the variables in several ROMS structures are initialized to zero, as it is
  ! done in ROMS native adjoint-based algorithms.

  CALL initialize_coupling (self%ng, self%tile, 0)
  CALL initialize_forces   (self%ng, self%tile, 0)
  CALL initialize_grid     (self%ng, self%tile, iTLM)
  CALL initialize_mixing   (self%ng, self%tile, 0)
  CALL initialize_ocean    (self%ng, self%tile, 0)

  Cstr(:,iTLM,:) = 0.0_kind_real                 ! Zeroth-out profiling arrays
  Cend(:,iTLM,:) = 0.0_kind_real
  Csum(:,iTLM,:) = 0.0_kind_real
  Ctotal         = 0.0_kind_real
  total_cpu      = 0.0_kind_real

END SUBROUTINE roms_linearModel_finalize_tl

! ------------------------------------------------------------------------------
!> It time interpolates JEDI nonlinear trajectory from snapshots and loads it
!> into ROMS field structure.

SUBROUTINE jedi2roms_traj (ng, Traj1, Traj2, fac1, fac2)

  integer,                        intent(in) :: ng        !< nested grid number
  TYPE (roms_trajectory), target, intent(in) :: Traj1     !< Trajectory time-1
  TYPE (roms_trajectory), target, intent(in) :: Traj2     !< Trajectory time-2
  real (kind=kind_real),          intent(in) :: fac1      !< time-1 weight
  real (kind=kind_real),          intent(in) :: fac2      !< time-2 weight

  TYPE (roms_field), pointer                 :: field1, field2
  integer                                    :: i, itrc, k

  ! The nonlinear trajectory fields are time interpolated from JEDI snapshots
  ! and repeated for each ROMS time level.

  IF (LdebugLinearModel.and.(my_comm%rank().eq.0))                             &
    PRINT 10, 'ROMS_DEBUG jedi2roms_traj: Interpolating trajectory for ROMS',  &
              SIZE(Traj1%fields), jic(ng), TRIM(Traj1%DateTimeStr), fac1,      &
              TRIM(Traj2%DateTimeStr), fac2

  DO i=1, SIZE(Traj1%fields)
    field1 => Traj1%fields(i)
    field2 => Traj2%fields(i)

    IF (LdebugLinearModel.and.(my_comm%rank().eq.0)) THEN
      PRINT 20, field1%metadata%short_name, field1%metadata%io_name,'(date1)', &
                field1%MinValue, field1%MaxValue, INT(field1%CheckSum,KIND=8)
      PRINT 20, field2%metadata%short_name, field2%metadata%io_name,'(date2)', &
                field2%MinValue, field2%MaxValue, INT(field2%CheckSum,KIND=8)
    END IF

    SELECT CASE (field1%name)

      CASE ('ssh',                                                             &
            'sea_surface_height_above_geoid')
        DO k = 1, 3
#ifdef ZERO_TRAJECTORY
          OCEAN(ng)%zeta(:,:,k) = 0.0_kind_real
#else
          OCEAN(ng)%zeta(:,:,k) = fac1*field1%val(:,:,1)+                      &
                                  fac2*field2%val(:,:,1)
#endif
        END DO

#ifdef ZERO_TRAJECTORY
        COUPLING(ng)%Zt_avg1 = 0.0_kind_real
#else
        COUPLING(ng)%Zt_avg1 = fac1*field1%val(:,:,1)+                         &
                               fac2*field2%val(:,:,1)
#endif

      CASE ('u2docn',                                                          &
            'barotropic_sea_water_x_velocity')
        DO k = 1, 3
#ifdef ZERO_TRAJECTORY
          OCEAN(ng)%ubar(:,:,k) = 0.0_kind_real
#else
          OCEAN(ng)%ubar(:,:,k) = fac1*field1%val(:,:,1)+                      &
                                  fac2*field2%val(:,:,1)
#endif
        END DO

      CASE ('v2docn',                                                          &
            'barotropic_sea_water_y_velocity')
        DO k = 1, 3
#ifdef ZERO_TRAJECTORY
          OCEAN(ng)%vbar(:,:,k) = 0.0_kind_real
#else
          OCEAN(ng)%vbar(:,:,k) = fac1*field1%val(:,:,1)+                      &
                                  fac2*field2%val(:,:,1)
#endif
        END DO

      CASE ('DU_avg1',                                                         &
            'sea_water_time_average_of_barotropic_x_velocity_flux')
#ifdef ZERO_TRAJECTORY
        COUPLING(ng)%DU_avg1 = 0.0_kind_real
#else
        COUPLING(ng)%DU_avg1 = fac1*field1%val(:,:,1)+                         &
                               fac2*field2%val(:,:,1)
#endif

      CASE ('DV_avg1',                                                         &
            'sea_water_time_average_of_barotropic_y_velocity_flux')
#ifdef ZERO_TRAJECTORY
        COUPLING(ng)%DV_avg1 = 0.0_kind_real
#else
        COUPLING(ng)%DV_avg1 = fac1*field1%val(:,:,1)+                         &
                               fac2*field2%val(:,:,1)
#endif

      CASE ('DU_avg2',                                                         &
            'sea_water_correct_barotropic_x_velocity_flux_for_coupling')
#ifdef ZERO_TRAJECTORY
        COUPLING(ng)%DU_avg2 = 0.0_kind_real
#else
        COUPLING(ng)%DU_avg2 = fac1*field1%val(:,:,1)+                         &
                               fac2*field2%val(:,:,1)
#endif

      CASE ('DV_avg2',                                                         &
            'sea_water_correct_barotropic_y_velocity_flux_for_coupling')
#ifdef ZERO_TRAJECTORY
        COUPLING(ng)%DV_avg2 = 0.0_kind_real
#else
        COUPLING(ng)%DV_avg2 = fac1*field1%val(:,:,1)+                         &
                               fac2*field2%val(:,:,1)
#endif

      CASE ('uaocn',                                                           &
            'eastward_sea_water_velocity')              !> A-grid
#ifdef ZERO_TRAJECTORY
        OCEAN(ng)%ua = 0.0_kind_real
#else
        OCEAN(ng)%ua = fac1*field1%val+                                        &
                       fac2*field2%val
#endif

      CASE ('uocn',                                                            &
            'sea_water_x_velocity')                     !> C-grid
        DO k = 1, 2
#ifdef ZERO_TRAJECTORY
          OCEAN(ng)%v(:,:,:,k) = 0.0_kind_real
#else
          OCEAN(ng)%v(:,:,:,k) = fac1*field1%val+                              &
                                 fac2*field2%val
#endif
          END DO

      CASE ('vaocn',                                                           &
            'northward_sea_water_velocity')             !> A-grid
#ifdef ZERO_TRAJECTORY
        OCEAN(ng)%va = 0.0_kind_real
#else
        OCEAN(ng)%va = fac1*field1%val+                                        &
                       fac2*field2%val
#endif

      CASE ('vocn',                                                            &
            'sea_water_y_velocity')                     !> C-grid
        DO k = 1, 2
#ifdef ZERO_TRAJECTORY
          OCEAN(ng)%v(:,:,:,k) = 0.0_kind_real
#else
          OCEAN(ng)%v(:,:,:,k) = fac1*field1%val+                              &
                                 fac2*field2%val
#endif
          END DO

      CASE ('tocn',                                                            &
            'sea_water_temperature',                                           &
            'sea_water_potential_temperature',                                 &
            'socn',                                                            &
            'sea_water_salinity')
        itrc = roms_tracer_index(field1%name)
        DO k = 1, 3
#ifdef ZERO_TRAJECTORY
          OCEAN(ng)%t(:,:,:,k,itrc) = 0.0_kind_real
#else
          OCEAN(ng)%t(:,:,:,k,itrc) = fac1*field1%val+                         &
                                      fac2*field2%val
#endif
          END DO

      CASE ('Ktocn',                                                           &
            'vertical_diffusion_coefficient_of_temperature_in_sea_water',      &
            'Ksocn',                                                           &
            'vertical_diffusion_coefficient_of_salinity_in_sea_water')
        itrc = roms_tracer_index(field1%name)
        MIXING(ng)%Akt(:,:,:,itrc) = fac1*field1%val+                          &
                                     fac2*field2%val

      CASE ('Kvocn',                                                           &
            'vertical_viscosity_coefficient_of_sea_water')
        MIXING(ng)%Akv = fac1*field1%val+                                      &
                         fac2*field2%val

      CASE ('zocn_r',                                                          &
            'model_level_depth_at_cell_center')

      CASE DEFAULT
        CALL abor1_ftn ("jedi2roms_traj: Cannot find option for field: "//     &
                        TRIM(field1%name))
    END SELECT
  END DO

  10 FORMAT (a,', Nfields = ',i2,', timestep = ',i5.5,', date1: ',a,           &
             ', fac1 = ',1p,e11.4,', date2: ',a,', fac2 = ',1p,e11.4)
  20 FORMAT (19x,'- ',a,': ',a,t113,a,/,22x,'(Min = ',1p,e15.8,                &
             ' Max = ',1p,e15.8,')',t93,'Checksum = ',i0)

END SUBROUTINE jedi2roms_traj

! ------------------------------------------------------------------------------
!> It loads JEDI increment fields into respective ROMS tangent linear or
!! adjoint fields.

SUBROUTINE jedi2roms_incr (ng, kernel, Tindex2d, Tindex3d, geom, Incr,         &
                           DateString)

  integer,                        intent(in   ) :: ng          !< nested grid
  integer,                        intent(in   ) :: kernel      !< ROMS kernel ID
  integer,                        intent(in   ) :: Tindex2d    !< 2D time index
  integer,                        intent(in   ) :: Tindex3d    !< 3D time index
  CLASS (roms_geom),              intent(in   ) :: geom        !< Geometry
  CLASS (roms_increment), target, intent(inout) :: Incr        !< Increment
  character (len=*),              intent(in   ) :: DateString  !< DateTime

  TYPE (roms_field),                    pointer :: field => null()
  TYPE (roms_field),                    pointer :: Ua    => null()
  TYPE (roms_field),                    pointer :: Va    => null()

  logical                                       :: have_Uc, have_Vc
  logical                                       :: need_Uc, need_Vc
  integer                                       :: i, itrc
  real (kind=kind_real)                         :: stats(4)
  real (kind=kind_real),            allocatable :: Uc(:,:,:), Vc(:,:,:)
  character (len=22)                            :: DateTimeStr

  ! Set ROMS date/time string.

  IF (LdebugLinearModel) CALL time_string  (time4jedi(ng), DateTimeStr)

  ! If increment has A-grid currents, compute to C-grid staggered currents.

  need_Uc = Incr%has('eastward_sea_water_velocity')
  need_Vc = Incr%has('northward_sea_water_velocity')

  have_Uc = .FALSE.
  have_Vc = .FALSE.

  IF (need_Uc .or. need_Vc) THEN
    CALL Incr%get ('eastward_sea_water_velocity',  Ua)
    CALL Incr%get ('northward_sea_water_velocity', Va)

    allocate ( Uc(geom%LBi:geom%UBi, geom%LBj:geom%UBj, geom%N) )
    allocate ( Vc(geom%LBi:geom%UBi, geom%LBj:geom%UBj, geom%N) )

    Uc = 0.0_kind_real
    Vc = 0.0_kind_real

    IF (kernel .eq. iADM) THEN
      Uc = OCEAN(ng)%ad_u(:,:,:,Tindex3d)
      Vc = OCEAN(ng)%ad_v(:,:,:,Tindex3d)
      CALL vector_a_to_c_ad (geom, Ua%val, Va%val, Uc, Vc)
      OCEAN(ng)%ad_u(:,:,:,Tindex3d) = 0.0_kind_real
      OCEAN(ng)%ad_v(:,:,:,Tindex3d) = 0.0_kind_real
    ELSE
      CALL vector_a_to_c (geom, Ua%val, Va%val, Uc, Vc)
      OCEAN(ng)%tl_u(:,:,:,Tindex3d) = Uc
      OCEAN(ng)%tl_v(:,:,:,Tindex3d) = Vc
    END IF
    have_Uc = .TRUE.
    have_Vc = .TRUE.
  END IF

  ! Load JEDI increment fields into respective ROMS arrays.

  ROMS_KERNEL : IF (kernel .eq. iTLM) THEN

    IF (LdebugLinearModel.and.(my_comm%rank().eq.0))                           &
      PRINT 10, 'ROMS_DEBUG jedi2roms_incr: TL ROMS - ', TL_inner,             &
                SIZE(Incr%fields), jic(ng), Tindex2d, Tindex3d,                &
                TRIM(DateString)

    DO i=1, SIZE(Incr%fields)

      field => Incr%fields(i)

      IF (LdebugLinearModel) THEN
        CALL field%stats (stats)
        IF (my_comm%rank().eq.0)                                               &
          PRINT 20, field%metadata%short_name, field%metadata%io_name,         &
                    stats(1), stats(2), INT(stats(4),KIND=8)
      END IF

      SELECT CASE (field%name)

        CASE ('ssh',                                                           &
              'sea_surface_height_above_geoid')
          COUPLING(ng)%tl_Zt_avg1(:,:) = field%val(:,:,1)

        CASE ('uaocn',                                                         &
              'eastward_sea_water_velocity')                 !> A-grid
          OCEAN(ng)%tl_ua = field%val

        CASE ('vaocn',                                                         &
              'northward_sea_water_velocity')                !> A-grid
          OCEAN(ng)%tl_va = field%val

        CASE ('uocn',                                                          &
              'sea_water_x_velocity')                        !> C-grid
          OCEAN(ng)%tl_u(:,:,:,Tindex3d) = field%val

        CASE ('vocn',                                                          &
              'sea_water_y_velocity')                        !> C-grid
          OCEAN(ng)%tl_v(:,:,:,Tindex3d) = field%val

        CASE ('tocn',                                                          &
              'sea_water_temperature',                                         &
              'sea_water_potential_temperature',                               &
              'socn',                                                          &
              'sea_water_salinity')
          itrc = roms_tracer_index(field%name)
          OCEAN(ng)%tl_t(:,:,:,Tindex3d,itrc) = field%val

        CASE DEFAULT
          CALL abor1_ftn ("jedi2roms_incr: Cannot find option for field: "//   &
                          TRIM(field%name))
      END SELECT

    END DO

  ELSE IF (kernel .eq. iADM) THEN               !> Adjoint of TL logic above


    IF (LdebugLinearModel.and.(my_comm%rank().eq.0))                           &
      PRINT 10, 'ROMS_DEBUG jedi2roms_incr: AD ROMS - ', AD_inner,             &
                SIZE(Incr%fields), jic(ng), Tindex2d, Tindex3d,                &
                TRIM(DateString)

    DO i=1, SIZE(Incr%fields)

      field => Incr%fields(i)

      IF (LdebugLinearModel) THEN
        CALL field%stats (stats)
        IF (my_comm%rank().eq.0)                                               &
          PRINT 20, field%metadata%short_name, field%metadata%io_name,         &
                    stats(1), stats(2), INT(stats(4),KIND=8)
      END IF

      SELECT CASE (field%name)

        CASE ('ssh',                                                           &
              'sea_surface_height_above_geoid')              !> a la ROMS
          field%val(:,:,1) = field%val(:,:,1) +                                &
                             OCEAN(ng)%ad_zeta(:,:,1)+                         &
                             OCEAN(ng)%ad_zeta(:,:,2)
          OCEAN(ng)%ad_zeta(:,:,1) = 0.0_kind_real
          OCEAN(ng)%ad_zeta(:,:,2) = 0.0_kind_real

        CASE ('uaocn',                                                         &
              'eastward_sea_water_velocity')                 !> A-grid
          IF (.not. have_Uc) THEN
            field%val = field%val + OCEAN(ng)%ad_ua
            OCEAN(ng)%ad_ua = 0.0_kind_real
          END IF

        CASE ('vaocn',                                                         &
              'northward_sea_water_velocity')                !> A-grid
          IF (.not. have_Vc) THEN
            field%val = field%val + OCEAN(ng)%ad_va
            OCEAN(ng)%ad_va = 0.0_kind_real
          END IF

        CASE ('uocn',                                                          &
              'sea_water_x_velocity')                        !> C-grid
          IF (.not. have_Uc) THEN
            field%val = field%val + OCEAN(ng)%ad_u(:,:,:,Tindex3d)
            OCEAN(ng)%ad_u(:,:,:,Tindex3d) = 0.0_kind_real
          END IF

        CASE ('vocn',                                                          &
              'sea_water_y_velocity')                        !> C-grid
          IF (.not. have_Vc) THEN
            field%val = field%val + OCEAN(ng)%ad_v(:,:,:,Tindex3d)
            OCEAN(ng)%ad_v(:,:,:,Tindex3d) = 0.0_kind_real
          END IF

        CASE ('tocn',                                                          &
              'sea_water_temperature',                                         &
              'sea_water_potential_temperature',                               &
              'socn',                                                          &
              'sea_water_salinity')
          itrc = roms_tracer_index(field%name)
          field%val = field%val +                                              &
                      OCEAN(ng)%ad_t(:,:,:,Tindex3d,itrc)
          OCEAN(ng)%ad_t(:,:,:,Tindex3d,itrc) = 0.0_kind_real

        CASE DEFAULT
          CALL abor1_ftn ("jedi2roms_incr: Cannot find option for field: "//   &
                           TRIM(field%name))
      END SELECT

    END DO

  END IF ROMS_KERNEL

! Deallocate local variables.

  IF (allocated(Uc)) deallocate (Uc)
  IF (allocated(Vc)) deallocate (Vc)
!
  10 FORMAT (a,'inner = ',i3.3,', Nfields = ',i2,', timestep = ',i5.5,         &
             ', timelevel = (',i0, ', ',i0,'), date: ',a)
  20 FORMAT (19x,'- ',a,': ',a,/,22x,'(Min = ',1p,e15.8,' Max = ',1p,e15.8,    &
             ')',t93,'Checksum = ',i0)

END SUBROUTINE jedi2roms_incr

! ------------------------------------------------------------------------------
!> It loads either ROMS tangent linear or adjoint state solution into increment
!! object.

SUBROUTINE roms2jedi_incr (ng, kernel, Tindex2d, Tindex3d, geom, Incr,         &
                           DateString)

  integer,                        intent(in   ) :: ng          !< nested grid
  integer,                        intent(in   ) :: kernel      !< ROMS kernel
  integer,                        intent(in   ) :: Tindex2d    !< 2D time index
  integer,                        intent(in   ) :: Tindex3d    !< 3D time index
  CLASS (roms_geom),              intent(in   ) :: geom        !< Geometry
  CLASS (roms_increment), target, intent(inout) :: Incr        !< Increment
  character (len=*),              intent(in   ) :: DateString  !< DateTime

  TYPE (roms_field),                    pointer :: field => null()
  TYPE (roms_field),                    pointer :: Ua    => null()
  TYPE (roms_field),                    pointer :: Va    => null()
  logical                                       :: have_Ua, have_Va
  logical                                       :: need_Ua, need_Va
  integer                                       :: i, itrc
  real (kind=kind_real)                         :: stats(4)
  real (kind=kind_real),            allocatable :: Uc(:,:,:), Vc(:,:,:)
  character (len=22)                            :: DateTimeStr

  ! Set ROMS date/time string.

  IF (LdebugLinearModel) CALL time_string  (time4jedi(ng), DateTimeStr)

  ! If increment has C-grid staggered currents, compute to A-grid currents.

  need_Ua = Incr%has('eastward_sea_water_velocity')
  need_Va = Incr%has('northward_sea_water_velocity')

  have_Ua = .FALSE.
  have_Va = .FALSE.

  IF (need_Ua .or. need_Va) THEN
    CALL Incr%get ('eastward_sea_water_velocity',  Ua)
    CALL Incr%get ('northward_sea_water_velocity', Va)

    allocate ( Uc(geom%LBi:geom%UBi, geom%LBj:geom%UBj, geom%N) )
    allocate ( Vc(geom%LBi:geom%UBi, geom%LBj:geom%UBj, geom%N) )

    Uc = 0.0_kind_real
    Vc = 0.0_kind_real

    IF (kernel .eq. iADM) THEN
      CALL vector_c_to_a_ad (geom, Uc, Vc, Ua%val, Va%val)
      OCEAN(ng)%ad_u(:,:,:,Tindex3d) = OCEAN(ng)%ad_u(:,:,:,Tindex3d) + Uc
      OCEAN(ng)%ad_v(:,:,:,Tindex3d) = OCEAN(ng)%ad_u(:,:,:,Tindex3d) + Vc
!     OCEAN(ng)%ad_u(:,:,:,Tindex3d) = Uc
!     OCEAN(ng)%ad_v(:,:,:,Tindex3d) = Vc
    ELSE
      Uc = OCEAN(ng)%tl_u(:,:,:,Tindex3d)
      Vc = OCEAN(ng)%tl_v(:,:,:,Tindex3d)
      CALL vector_c_to_a (geom, Uc, Vc, Ua%val, Va%val)
    END IF
    have_Ua = .TRUE.
    have_Va = .TRUE.
  END IF

  ! Load ROMS tangent linear or adjoint fields into JEDI increment object.

  ROMS_KERNEL : IF (kernel .eq. iTLM) THEN

    IF (LdebugLinearModel.and.(my_comm%rank().eq.0))                           &
      PRINT 10, 'ROMS_DEBUG roms2jedi_incr: TL ROMS - ', TL_inner,             &
                SIZE(Incr%fields), jic(ng), Tindex2d, Tindex3d,                &
                TRIM(DateString)

    DO i=1, SIZE(Incr%fields)

      field => Incr%fields(i)

      SELECT CASE (field%name)

        CASE ('ssh',                                                           &
              'sea_surface_height_above_geoid')              !> time-averaged
          field%val(:,:,1) = COUPLING(ng)%tl_Zt_avg1

        CASE ('uaocn',                                                         &
              'eastward_sea_water_velocity')                 !> A-grid
          IF (.not. have_Ua ) THEN
            field%val = OCEAN(ng)%tl_ua
          END IF

        CASE ('vaocn',                                                         &
              'northward_sea_water_velocity')                !> A-grid
          IF (.not. have_Va ) THEN
            field%val = OCEAN(ng)%tl_va
          END IF

        CASE ('uocn',                                                          &
              'sea_water_x_velocity')                        !> C-grid
          IF (.not. have_Ua) THEN
            field%val = OCEAN(ng)%tl_u(:,:,:,Tindex3d)
          END IF

        CASE ('vocn',                                                          &
              'sea_water_y_velocity')                        !> C-grid
          IF (.not. have_Va) THEN
            field%val = OCEAN(ng)%tl_v(:,:,:,Tindex3d)
          END IF

        CASE ('tocn',                                                          &
              'sea_water_temperature',                                         &
              'sea_water_potential_temperature',                               &
              'socn',                                                          &
              'sea_water_salinity')
          itrc = roms_tracer_index(field%name)
          field%val = OCEAN(ng)%tl_t(:,:,:,Tindex3d,itrc)

        CASE DEFAULT
          CALL abor1_ftn ("roms2jedi_incr: Cannot find option for field: " //  &
                          TRIM(field%name))

      END SELECT

      IF (LdebugLinearModel) THEN
        CALL field%stats (stats)
        IF (my_comm%rank().eq.0)                                               &
          PRINT 20, field%metadata%short_name, field%metadata%io_name,         &
                    stats(1), stats(2), INT(stats(4),KIND=8)
      END IF

    END DO

  ELSE IF (kernel .eq. iADM) THEN               !> Adjoint of TL logic above

    IF (LdebugLinearModel.and.(my_comm%rank().eq.0))                           &
      PRINT 10, 'ROMS_DEBUG roms2jedi_incr: AD ROMS - ', AD_inner,             &
                SIZE(Incr%fields), jic(ng), Tindex2d, Tindex3d,   &
                TRIM(DateString)

    DO i=1, SIZE(Incr%fields)

      field => Incr%fields(i)

      SELECT CASE (field%name)

        CASE ('ssh',                                                           &
              'sea_surface_height_above_geoid')
!         OCEAN(ng)%ad_zeta(:,:,1) = OCEAN(ng)%ad_zeta(:,:,1) +                &
!                                    field%val(:,:,1)
!         OCEAN(ng)%ad_zeta(:,:,2) = OCEAN(ng)%ad_zeta(:,:,2) +                &
!                                    field%val(:,:,1)

          COUPLING(ng)%ad_Zt_avg1 = COUPLING(ng)%ad_Zt_avg1 +                  &
                                    field%val(:,:,1)
          field%val(:,:,1) = 0.0_kind_real

        CASE ('uaocn',                                                         &
              'eastward_sea_water_velocity')                 !> A-grid
          OCEAN(ng)%ad_ua = OCEAN(ng)%ad_ua + Ua%val
          Ua%val = 0.0_kind_real

        CASE ('vaocn',                                                         &
              'northward_sea_water_velocity')                !> A-grid
          OCEAN(ng)%ad_va = OCEAN(ng)%ad_va + Va%val
          Va%val = 0.0_kind_real

        CASE ('uocn',                                                          &
              'sea_water_x_velocity')                        !> C-grid
          IF (.not. have_Ua) THEN
            OCEAN(ng)%ad_u(:,:,:,Tindex3d) = OCEAN(ng)%ad_u(:,:,:,Tindex3d) +  &
                                             field%val
            field%val = 0.0_kind_real
          END IF

        CASE ('vocn',                                                          &
              'sea_water_y_velocity')                        !> C-grid
          IF (.not. have_Va) THEN
            OCEAN(ng)%ad_v(:,:,:,Tindex3d) = OCEAN(ng)%ad_v(:,:,:,Tindex3d) +  &
                                             field%val
            field%val = 0.0_kind_real
          END IF

        CASE ('tocn',                                                          &
              'sea_water_temperature',                                         &
              'sea_water_potential_temperature',                               &
              'socn',                                                          &
              'sea_water_salinity')
          itrc = roms_tracer_index(field%name)
          OCEAN(ng)%ad_t(:,:,:,Tindex3d,itrc) = field%val +                    &
                                        OCEAN(ng)%ad_t(:,:,:,Tindex3d,itrc)
          field%val = 0.0_kind_real

        CASE DEFAULT
          CALL abor1_ftn ("roms2jedi_incr: Cannot find option for field: "//   &
                            TRIM(field%name))

      END SELECT

      IF (LdebugLinearModel) THEN
        CALL field%stats (stats)
        IF (my_comm%rank().eq.0)                                               &
          PRINT 20, field%metadata%short_name, field%metadata%io_name,         &
                    stats(1), stats(2), INT(stats(4),KIND=8)
      END IF

    END DO

  END IF ROMS_KERNEL

! Deallocate local variables.

  IF (allocated(Uc)) deallocate (Uc)
  IF (allocated(Vc)) deallocate (Vc)
!
  10 FORMAT (a,'inner = ',i3.3,', Nfields = ',i2,', timestep = ',i5.5,         &
             ', timelevel = (',i0, ', ',i0,'), date: ',a)
  20 FORMAT (19x,'- ',a,': ',a,/,22x,'(Min = ',1p,e15.8,' Max = ',1p,e15.8,    &
             ')',t93,'Checksum = ',i0)

END SUBROUTINE roms2jedi_incr

! ------------------------------------------------------------------------------

END MODULE roms_linearModel_mod
