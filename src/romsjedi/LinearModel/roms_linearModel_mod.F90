#undef ZERO_TRAJECTORY


! (C) Copyright 2017-2023 UCAR
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

USE roms_kernel_mod
USE mod_param,                  ONLY : iADM, iNLM, iTLM
USE mod_scalars,                ONLY : NoError, exit_flag

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

TYPE (fckit_mpi_comm) :: my_comm

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
!> Creates ROMS LinearModel object.

SUBROUTINE roms_linearModel_create (self, geom, f_conf)

  USE mod_ncparam,  ONLY : Ngrids

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

SUBROUTINE roms_linearModel_initialize_ad (self, incr, vdate)

  USE mod_scalars,  ONLY : INItime, dt, ntimes
  USE mod_stepping, ONLY : kstp, nstp

  CLASS (roms_linearModel), intent(inout) :: self    !< LinearModel object
  CLASS (roms_increment),   intent(inout) :: incr    !< Increment object
  TYPE (datetime),          intent(in   ) :: vdate   !< Increment valid DateTime

  integer                                 :: LocalPET, MyComm, my_ntimes, ng
  integer                                 :: Tindex2d, Tindex3d
  character (len=22)                      :: CurrentDateString

  !> Get MPI communicator and PET rank. Get nested grid number.

  MyComm   = self%f_comm%communicator()
  LocalPET = self%f_comm%rank()
  ng       = self%ng

  !> Get JEDI increment valid DateTime string.

  CALL date2string (vdate, CurrentDateString, ISO=.FALSE.)

  !> ROMS-JEDI phase 1 initialization. If appropriate, read in standard input
  !> parameters. Then, allocate/initialize parameters and variables when switch
  !> LsetROMS is on. It sets TLM time-stepping parameters.

  LsetROMS = .TRUE.
  IF (allocated(BOUNDS)) LsetROMS = .FALSE.

  CALL ROMS_initialize (LsetROMS,                                            &
                        mpiCOMM = MyComm,                                    &
                        kernel  = iADM)
  IF (exit_flag .ne. NoError) THEN
    CALL abor1_ftn ("roms_linearModel::initialize_ad: "//                    &
                    "Error in ROMS_initialize")
  END IF

  !> Reset ROMS total number of timesteps, if shorter simulation time period is
  !> is specified in the YAML file.

  my_ntimes = INT(self%SimulationPeriod/dt(ng))

  IF (my_ntimes .ne. ntimes(ng)) THEN
    IF (LocalPET .eq. 0)                                                     &
      PRINT '(2(a,i0))', ' roms_linearModel::initialize_ad: Reset input '//  &
                         'parameter, NTIMES = ', ntimes(ng), ' to ', my_ntimes
    ntimes(ng) = my_ntimes
  END IF

  !> Set ROMS NLM initial conditions time (s).  It is need to set-up ROMS 
  !> timestepping counters correctly.

  INItime(ng) = self%INItime

  !> Load JEDI initial state fields into ROMS NLM arrays.

  Tindex2d = kstp(ng)                              ! timestep 2D index
  Tindex3d = nstp(ng)                              ! timestep 3D index

  CALL jedi2roms_incr (ng, iADM, Tindex2d, Tindex3d, incr, CurrentDateString)

  !> ROMS-JEDI phase 2 initialization. Compleate the initialization using
  !> the state fields loaded above. Compute depths, density, and horizontal
  !> mass fluxes.

  CALL ROMS_initializeP2 (iADM)
  IF (exit_flag .ne. NoError) THEN
    CALL abor1_ftn ("roms_linaermodel::initialize_ad: "//                    &
                    "Error in ROMS_initializeP2")
  END IF

  !> Write out OOPS initial increment.

  IF (LdebugLinearModel) THEN
    CALL incr%write_debug ('Data/increment/oops_iad.nc', vdate)
  END IF

END SUBROUTINE roms_linearModel_initialize_ad

! ------------------------------------------------------------------------------
!> It initializes tangent linear model (TLROMS) kernel.

SUBROUTINE roms_linearModel_initialize_tl (self, incr, vdate)

  USE mod_scalars,  ONLY : INItime, dt, ntimes
  USE mod_stepping, ONLY : kstp, nstp

  CLASS (roms_linearModel), intent(inout) :: self    !< LinearModel object
  CLASS (roms_increment),   intent(inout) :: incr    !< Increment object
  TYPE (datetime),          intent(in   ) :: vdate   !< Increment valid DateTime

  integer                                 :: LocalPET, MyComm, my_ntimes, ng
  integer                                 :: Tindex2d, Tindex3d
  character (len=22)                      :: CurrentDateString

  !> Get MPI communicator and PET rank. Get nested grid number.

  MyComm   = self%f_comm%communicator()
  LocalPET = self%f_comm%rank()
  ng       = self%ng

  !> Get JEDI increment valid DateTime string.

  CALL date2string (vdate, CurrentDateString, ISO=.FALSE.)

  !> ROMS-JEDI phase 1 initialization. Read in standard input parameters. Then,
  !> allocate/initialize parameters and variables (LsetROMS=.TRUE.). Also, set
  !> stepping parameters.

  LsetROMS = .TRUE.
  IF (allocated(BOUNDS)) LsetROMS = .FALSE.

  CALL ROMS_initialize (LsetROMS,                                            &
                        mpiCOMM = MyComm,                                    &
                        kernel  = iTLM)
  IF (exit_flag .ne. NoError) THEN
    CALL abor1_ftn ("roms_linearModel::initialize_tl: "//                    &
                    "Error in ROMS_initialize")
  END IF

  !> Set ROMS NLM initial conditions time (s).  It is needed to set-up ROMS 
  !> timestepping counters correctly.

  INItime(ng) = self%INItime

  !> Reset ROMS total number of timesteps, if shorter simulation time period is
  !> is specified in the YAML file.

  my_ntimes = INT(self%SimulationPeriod/dt(ng))

  IF (my_ntimes .ne. ntimes(ng)) THEN
    IF (LocalPET .eq. 0)                                                     &
      PRINT '(2(a,i0))', ' roms_linearModel::initialize_tl: Reset input '//  &
                         'parameter, NTIMES = ', ntimes(ng), ' to ', my_ntimes
    ntimes(ng) = my_ntimes
  END IF

  !> Load JEDI initial state fields into ROMS TLM arrays. At initialization,
  !> all time indices are set to one.

  Tindex2d = kstp(ng)                              ! timestep 2D index
  Tindex3d = nstp(ng)                              ! timestep 3D index

  CALL jedi2roms_incr (ng, iTLM, Tindex2d, Tindex3d, incr, CurrentDateString)

  !> ROMS-JEDI phase 2 initialization. Compleate the initialization using
  !> the state fields loaded above. Compute depths, density, and horizontal
  !> mass fluxes.

  CALL ROMS_initializeP2 (iTLM)
  IF (exit_flag .ne. NoError) THEN
    CALL abor1_ftn ("roms_linearModel::initialize_tl: "//                      &
                    "Error in ROMS_initializeP2")
  END IF

  !> Perform TLROMS the first half timestep, the NLM kernel updates the
  !> initial state lateral boundary conditions and recomputes vertically
  !> integrated momentum for timelevel "nstp".

  CALL ROMS_run (self%RunInterval, kernel=iTLM)
  IF (exit_flag .ne. NoError) THEN
    IF ((LEN_TRIM(blowup_string).gt.0) .and. (LocalPET.eq.0)) THEN
      PRINT '(a,/,2a)','roms_model::initialize Abnormal termination: BLOWUP.', &
                       'REASON: ', TRIM(blowup_string)
    END IF
    CALL abor1_ftn ("roms_model::initialize Error while calling ROMS_run")
  END IF

  !> TLROMS applied lateral boundary conditions to the initial increment
  !> vector. Pass the outdated increment vector back to JEDI.

  CALL roms2jedi_incr (ng, iTLM, Tindex2d, Tindex3d, incr, CurrentDateString)

  !> Write out OOPS initial increment.

  IF (LdebugLinearModel) THEN
    CALL incr%write_debug ('Data/increment/oops_itl.nc', vdate)
  END IF

END SUBROUTINE roms_linearModel_initialize_tl

! ------------------------------------------------------------------------------
!> It timesteps backward adjoint model (ADROMS) kernel for the specified time
!! interval in seconds.

SUBROUTINE roms_linearModel_step_ad (self, Incr, Traj, vdate)

  USE dateclock_mod, ONLY : time_string
  USE mod_scalars,   ONLY : jic, ntend, time4jedi
  USE mod_stepping,  ONLY : kstp, knew, nstp, nnew

  CLASS (roms_linearModel), intent(inout) :: self    !< LinearModel object
  CLASS (roms_increment),   intent(inout) :: Incr    !< Increment object
  CLASS (roms_trajectory),  intent(in   ) :: Traj    !< Trajectory object
  TYPE (datetime),          intent(inout) :: vdate   !< Increment valid DateTime

  integer                                 :: Tindex2d, Tindex3d, ng
  character (len=20)                      :: DateString

  ! Initialize.

  ng = self%ng

  CALL date2string (vdate, DateString, ISO=.FALSE.)

  ! Load nonlinear background trajectory into ROMS, which is used to linearize
  ! the adjoint model discrete equations.

  CALL jedi2roms_traj (ng, Traj)

  ! Pass incoming increment to ADROMS. Usually, the increment is the previous
  ! time-stepped solution, which can be processed and modified by OOPS or not.
  ! It is expected to use this modified state to advance the solution for the
  ! next timestep. But, of course, it will spoil ROMS predictor/corrector,
  ! multiple time level stepping. So, we need to figure out how to use such a
  ! previous state as a forcing term without affecting the time stepping.

! CALL jedi2roms_incr (ng, iADM, Tindex2d, Tindex3d, Incr, DateString)

  ! Timestep backward ADROMS by the specified RunInterval (often a single
  ! timestep) in seconds. Recall that ROMS kernels have a predictor/corrector
  ! time-stepping scheme with multiple time indices 
  !
  ! On the first step, AD_ADVANCE is false, and ADROMS is not time stepped.
  ! Then, it computes the adjoint of the delayed output step. The strategy here
  ! is to advance an additional timestep.

  CALL ROMS_run (self%RunInterval, kernel=iADM)
  IF (exit_flag .ne. NoError) THEN
    CALL abor1_ftn ("roms_linearModel::step_ad Error while calling ROMS_run")
  END IF

  ! Load ROMS adjoint state solution into the increment object. The adjoint
  ! solution is split in a couple of time indices because of the exact discrete
  ! linear model transformation and the multi-level, predictor/corrector,
  ! time-stepping scheme.  The option AD_OUTPUT_STATE is activated in ROMS to
  ! combine both time levels in "*_sol" arrays passed back to OOPS. 

  self%time = time4jedi(ng)
  CALL time_string (self%time, self%roms_datetime)

  IF (jic(ng).ne.ntend(ng)) THEN
!   Tindex3d = -1                          ! use full solution adjoint state
!   Tindex3d = -1
    Tindex2d = knew(ng)
    Tindex3d = nnew(ng)
  ELSE
    Tindex2d = kstp(ng)
    Tindex3d = nstp(ng)                    ! use time level index for last step
  END IF

  CALL roms2jedi_incr (ng, iADM, Tindex2d, Tindex3d, Incr, self%roms_datetime)

END SUBROUTINE roms_linearModel_step_ad

! ------------------------------------------------------------------------------
!> It timesteps forward tangent linear model (TLROMS) kernel for the specified
!! time interval in seconds.

SUBROUTINE roms_linearModel_step_tl (self, Incr, Traj, vdate)

  USE dateclock_mod, ONLY : time_string
  USE mod_scalars,   ONLY : jic, ntend, time
  USE mod_stepping,  ONLY : nnew, nrhs

  CLASS (roms_linearModel), intent(inout) :: self    !< LinearModel object
  CLASS (roms_increment),   intent(inout) :: Incr    !< Increment object
  CLASS (roms_trajectory),  intent(in   ) :: Traj    !< Trajectory object
  TYPE (datetime),          intent(inout) :: vdate   !< Increment valid DateTime

  integer                                 :: Tindex2d, Tindex3d, ng
  character (len=22)                      :: CurrentDateString

  ! Initialize.

  ng = self%ng

  ! Get JEDI increment valid DateTime string.

  CALL date2string (vdate, CurrentDateString, ISO=.FALSE.)

  ! Load nonlinear background trajectory into ROMS, which is used to linearize
  ! the TLROMS discrete equations. The NL trajectory is unnecessary for the
  ! last full timestep since TL ROMS advances from "nstp" to "nnew". Neither
  ! is it necessary for the ending half step.

  CALL jedi2roms_traj (ng, Traj)

  ! Pass incoming increment to TLROMS. Usually, the increment is the previous
  ! time-stepped solution, which can be processed and modified by OOPS or not.
  ! It is expected to use this modified state to advance the solution for the
  ! next timestep. But, of course, it will spoil ROMS predictor/corrector,
  ! multiple time level stepping. So, we need to figure out how to use such a
  ! previous state as a forcing term without affecting the time stepping.

! CALL jedi2roms_incr (ng, iTLM, Tindex2d, Tindex3d, Incr, CurrentDateString)

  ! Advance TLROMS by the specified RunInterval (often a single timestep) in
  ! seconds. Recall that ROMS kernels have a predictor/corrector time-stepping
  ! scheme with multiple time indices. 
  !
  ! The initial increment is updated on the first timestep to apply the lateral
  ! boundary conditions and compute the vertically integrated (barotropic)
  ! momentum. However, we haven't figured out how to pass the updated initial
  ! increment back to OOPS in the current design.

  CALL ROMS_run (self%RunInterval, kernel=iTLM)
  IF (exit_flag .ne. NoError) THEN
    CALL abor1_ftn ("roms_linearModel::step_ad Error while calling ROMS_run")
  END IF

  ! Load ROMS tangent linear state solution into the increment object. The
  ! advanced TL solution is computed level "nnew".

  self%time = time(ng)
  CALL time_string (time(ng), self%roms_datetime)

  IF (jic(ng).lt.ntend(ng)) THEN
    Tindex2d = knew(ng)
    Tindex3d = nnew(ng)                ! current solution at end of tl_main3d
  ELSE
    Tindex3d = kstp(ng)
    Tindex3d = nrhs(ng)                ! last 2 steps use previous index because
  END IF                               ! delayed output

  CALL roms2jedi_incr (ng, iTLM, Tindex2d, Tindex3d, Incr, self%roms_datetime)

END SUBROUTINE roms_linearModel_step_tl

! ------------------------------------------------------------------------------
!> It finalizes adjoint model (ADROMS) kernel integration.

SUBROUTINE roms_linearModel_finalize_ad (self, Incr)

  USE mod_parallel, ONLY : Cend, Cstr, Csum, Ctotal, total_cpu

  USE mod_coupling, ONLY : initialize_coupling
  USE mod_forces,   ONLY : initialize_forces
  USE mod_grid,     ONLY : initialize_grid
  USE mod_mixing,   ONLY : initialize_mixing
  USE mod_ocean,    ONLY : initialize_ocean

  CLASS (roms_linearModel), intent(inout) :: self     !< LinearModel object
  CLASS (roms_increment),   intent(inout) :: Incr     !< Increment object

  ! Zeroth-out profiling arrays.

  Cstr(:,iADM,:) = 0.0_kind_real
  Cend(:,iADM,:) = 0.0_kind_real
  Csum(:,iADM,:) = 0.0_kind_real
  Ctotal         = 0.0_kind_real
  total_cpu      = 0.0_kind_real

  ! Since the adjoint kernel is used primarily in iterative algorithms, the
  ! variables in several ROMS structures are initialized to zero, as it is
  ! done in ROMS native adjoint-based algorithms.

  CALL initialize_coupling (self%ng, self%tile, iADM)
  CALL initialize_forces   (self%ng, self%tile, iADM)
  CALL initialize_grid     (self%ng, self%tile, iADM)
  CALL initialize_mixing   (self%ng, self%tile, iADM)
  CALL initialize_ocean    (self%ng, self%tile, iNLM)
  CALL initialize_ocean    (self%ng, self%tile, iADM)

END SUBROUTINE roms_linearModel_finalize_ad

! ------------------------------------------------------------------------------
!> It finalizes tangent linear model (TLROMS) kernel integration.

SUBROUTINE roms_linearModel_finalize_tl (self, Incr)

  USE mod_parallel, ONLY : Cend, Cstr, Csum, Ctotal, total_cpu

  USE mod_coupling, ONLY : initialize_coupling
  USE mod_forces,   ONLY : initialize_forces
  USE mod_grid,     ONLY : initialize_grid
  USE mod_ocean,    ONLY : initialize_ocean

  CLASS (roms_linearModel), intent(inout) :: self     !< LinearModel object
  CLASS (roms_increment),   intent(inout) :: Incr     !< Increment object

  ! Zeroth-out profiling arrays.

  Cstr(:,iTLM,:) = 0.0_kind_real
  Cend(:,iTLM,:) = 0.0_kind_real
  Csum(:,iTLM,:) = 0.0_kind_real
  Ctotal         = 0.0_kind_real
  total_cpu      = 0.0_kind_real

  ! Since the tangent linear kernel is used primarily in iterative algorithms,
  ! the variables in several ROMS structures are initialized to zero, as it is
  ! done in ROMS native adjoint-based algorithms.

  CALL initialize_coupling (self%ng, self%tile, 0)
  CALL initialize_forces   (self%ng, self%tile, iTLM)
  CALL initialize_grid     (self%ng, self%tile, iTLM)
  CALL initialize_ocean    (self%ng, self%tile, iNLM)
  CALL initialize_ocean    (self%ng, self%tile, iTLM)

END SUBROUTINE roms_linearModel_finalize_tl

! ------------------------------------------------------------------------------
!> It loads JEDI nonlinear state trajectory fields into ROMS field structure.

SUBROUTINE jedi2roms_traj (ng, Traj)

  USE mod_parallel, ONLY : Cend, Cstr, Csum

  USE mod_coupling, ONLY : COUPLING
  USE mod_mixing,   ONLY : MIXING
  USE mod_ocean,    ONLY : OCEAN
  USE mod_scalars,  ONLY : jic

  integer,                        intent(in) :: ng        !< nested grid number
  TYPE (roms_trajectory), target, intent(in) :: Traj      !< Trajectory fields

  TYPE (roms_field), pointer                 :: field
  integer                                    :: Tindex, i, itrc, k

  ! Load ROMS NLM trajectory managed by the JEDI driver.

  IF (Traj%doSnapshots) THEN

    ! The nonlinear trajectory fields are saved at time snapshots greater than
    ! ROMS timestep.  The ROMS TLM and ADM kernels will time-interpolate the
    ! data from available snapshots.

    Tindex = Traj%snapshotIndex

    DO i=1, SIZE(Traj%fields)
      field => Traj%fields(i)
      SELECT CASE (field%name)
        CASE ('ssh')                                    !> free-surface
          OCEAN(ng)%zeta(:,:,Tindex) = field%val(:,:,1)
        CASE ('uocn')                                   !> 3D U-momentum
          OCEAN(ng)%u(:,:,:,Tindex) = field%val
        CASE ('vocn')                                   !> 3D V-momentum
          OCEAN(ng)%v(:,:,:,Tindex) = field%val
        CASE ('tocn', 'socn')                           !> tracers
          itrc = roms_tracer_index(field%name)
          OCEAN(ng)%t(:,:,:,Tindex,itrc) = field%val
        CASE DEFAULT
          CALL abor1_ftn ("jedi2roms_traj: Cannot find option for field: "//   &
                          TRIM(field%name))
      END SELECT
    END DO

    IF (LdebugLinearModel .and. (my_comm%rank() .eq. 0)) THEN
      PRINT '(2a,i2,a,i0,2a)', 'ROMS_DEBUG jedi2roms_traj: ',                  &
                               'Loading trajectory into NL ROMS, nfields = ',  &
                               SIZE(Traj%fields),                              &
                               ', snapshot index = ', Tindex,                  &
                               ', date: ', Traj%DateTimeStr
    END IF

  ELSE

    ! The nonlinear trajectory fields are saved at every ROMS timestep and
    ! repeated for each ROMS time level.

    IF (LdebugLinearModel .and. (my_comm%rank() .eq. 0))                       &
      PRINT 10, 'ROMS_DEBUG jedi2roms_traj: Loading trajectory into NL ROMS',  &
                SIZE(Traj%fields), jic(ng), TRIM(Traj%DateTimeStr)

    DO i=1, SIZE(Traj%fields)
      field => Traj%fields(i)

      IF (LdebugLinearModel .and. (my_comm%rank() .eq. 0))                     &
        PRINT 20, field%metadata%getval_name, field%metadata%io_name,          &
                  field%MinValue, field%MaxValue, INT(field%CheckSum,KIND=8)

      SELECT CASE (field%name)
        CASE ('ssh')                                    !> free-surface
          DO k = 1, 3
#ifdef ZERO_TRAJECTORY
            OCEAN(ng)%zeta(:,:,k) = 0.0_kind_real
#else
            OCEAN(ng)%zeta(:,:,k) = field%val(:,:,1)
#endif
          END DO
        CASE ('u2docn')                                 !> 2D U-momentum
          DO k = 1, 3
#ifdef ZERO_TRAJECTORY
            OCEAN(ng)%ubar(:,:,k) = 0.0_kind_real
#else
            OCEAN(ng)%ubar(:,:,k) = field%val(:,:,1)
#endif
          END DO
        CASE ('v2docn')                                 !> 2D V-momentum
          DO k = 1, 3
#ifdef ZERO_TRAJECTORY
            OCEAN(ng)%vbar(:,:,k) = 0.0_kind_real
#else
            OCEAN(ng)%vbar(:,:,k) = field%val(:,:,1)
#endif
          END DO
        CASE ('DU_avg1')                                !> averaged 2D U-Flux
#ifdef ZERO_TRAJECTORY
          COUPLING(ng)%DU_avg1(:,:) = 0.0_kind_real
#else
          COUPLING(ng)%DU_avg1(:,:) = field%val(:,:,1)
#endif
        CASE ('DV_avg1')                                !> averaged 2D V-Flux
#ifdef ZERO_TRAJECTORY
          COUPLING(ng)%DV_avg1(:,:) = 0.0_kind_real
#else
          COUPLING(ng)%DV_avg1(:,:) = field%val(:,:,1)
#endif
        CASE ('DU_avg2')                                !> U-Flux 3D coupling
#ifdef ZERO_TRAJECTORY
          COUPLING(ng)%DU_avg2(:,:) = 0.0_kind_real
#else
          COUPLING(ng)%DU_avg2(:,:) = field%val(:,:,1)
#endif
        CASE ('DV_avg2')                                !> V-Flux 3D coupling
#ifdef ZERO_TRAJECTORY
          COUPLING(ng)%DV_avg2(:,:) = 0.0_kind_real
#else
          COUPLING(ng)%DV_avg2(:,:) = field%val(:,:,1)
#endif
        CASE ('uocn')                                   !> 3D U-momentum
          DO k = 1, 2
#ifdef ZERO_TRAJECTORY
            OCEAN(ng)%u(:,:,:,k) = 0.0_kind_real
#else
            OCEAN(ng)%u(:,:,:,k) = field%val
#endif
          END DO
        CASE ('vocn')                                   !> 3D V-momentum
          DO k = 1, 2
#ifdef ZERO_TRAJECTORY
            OCEAN(ng)%v(:,:,:,k) = 0.0_kind_real
#else
            OCEAN(ng)%v(:,:,:,k) = field%val
#endif
          END DO
        CASE ('tocn', 'socn')                           !> tracers
          itrc = roms_tracer_index(field%name)
          DO k = 1, 3
#ifdef ZERO_TRAJECTORY
            OCEAN(ng)%t(:,:,:,k,itrc) = 0.0_kind_real
#else
            OCEAN(ng)%t(:,:,:,k,itrc) = field%val
#endif
          END DO
        CASE ('Ktocn', 'Ksocn')                         !> vertical diffusion
          itrc = roms_tracer_index(field%name)
#ifdef ZERO_TRAJECTORY
          MIXING(ng)%Akt(:,:,:,itrc) = 0.0_kind_real
#else
          MIXING(ng)%Akt(:,:,:,itrc) = field%val
#endif
        CASE ('Kvocn')                                  !> vertical viscosity
#ifdef ZERO_TRAJECTORY
          MIXING(ng)%Akv = 0.0_kind_real
#else
          MIXING(ng)%Akv = field%val
#endif
        CASE DEFAULT
          CALL abor1_ftn ("jedi2roms_traj: Cannot find option for field: "//   &
                          TRIM(field%name))
      END SELECT
    END DO

  END IF

  10 FORMAT (1x,a,', Nfields = ',i2,', timestep = ',i5.5,', date: ',a)
  20 FORMAT (19x,'- ',a,': ',a,/,22x,'(Min = ',1p,e15.8,' Max = ',1p,e15.8,    &
             ')',t93,'Checksum = ',i0)

END SUBROUTINE jedi2roms_traj

! ------------------------------------------------------------------------------
!> It loads JEDI increment fields into respective ROMS tangent linear or
!! adjoint fields.

SUBROUTINE jedi2roms_incr (ng, kernel, Tindex2d, Tindex3d, Incr, DateString)

  USE dateclock_mod, ONLY : time_string
  USE mod_ocean,     ONLY : OCEAN
  USE mod_scalars,   ONLY : jic, time4jedi

  integer,                        intent(in   ) :: ng          !< nested grid
  integer,                        intent(in   ) :: kernel      !< ROMS kernel ID
  integer,                        intent(in   ) :: Tindex2d    !< 2D time index
  integer,                        intent(in   ) :: Tindex3d    !< 3D time index
  CLASS (roms_increment), target, intent(inout) :: Incr        !< Increment
  character (len=*),              intent(in   ) :: DateString  !< DateTime

  TYPE (roms_field), pointer                    :: field
  integer                                       :: i, itrc
  real (kind=kind_real)                         :: fstats(3)
  character (len=22)                            :: DateTimeStr

  ! Set ROMS date/time string.

  IF (LdebugLinearModel) CALL time_string  (time4jedi(ng), DateTimeStr)

  ! Load JEDI increment fields into respective ROMS arrays.

  ROMS_KERNEL : IF (kernel .eq. iTLM) THEN

    IF (LdebugLinearModel .and. (my_comm%rank() .eq. 0))                       &
      PRINT 10, 'ROMS_DEBUG jedi2roms_incr: Loading increments into TL ROMS',  &
                SIZE(Incr%fields), jic(ng), Tindex2d, Tindex3d,                &
                TRIM(DateString)

    DO i=1, SIZE(Incr%fields)

      field => Incr%fields(i)

      IF (LdebugLinearModel) THEN
        CALL field%stats (fstats)
        IF (my_comm%rank() .eq. 0)                                             &
          PRINT 20, field%metadata%getval_name, field%metadata%io_name,        &
                    fstats(1), fstats(2), INT(fstats(3),KIND=8)
      END IF

      SELECT CASE (field%name)
         CASE ('ssh')                                   !> free-surface
           OCEAN(ng)%tl_zeta(:,:,Tindex2d) = field%val(:,:,1)
         CASE ('uocn')                                  !> 3D U-momentum
           OCEAN(ng)%tl_u(:,:,:,Tindex3d) = field%val
         CASE ('vocn')                                  !> 3D V-momentum
           OCEAN(ng)%tl_v(:,:,:,Tindex3d) = field%val
         CASE ('tocn', 'socn')                          !> tracers
           itrc = roms_tracer_index(field%name)
           OCEAN(ng)%tl_t(:,:,:,Tindex3d,itrc) = field%val
         CASE DEFAULT
           CALL abor1_ftn ("jedi2roms_incr: Cannot find option for field: "// &
                           TRIM(field%name))
      END SELECT

    END DO

  ELSE IF (kernel .eq. iADM) THEN  

    IF (LdebugLinearModel .and. (my_comm%rank() .eq. 0))                       &
      PRINT 10, 'ROMS_DEBUG jedi2roms_incr: Loading increments into AD ROMS',  &
                SIZE(Incr%fields), jic(ng), Tindex2d, Tindex3d,                &
                TRIM(DateString)

    DO i=1, SIZE(Incr%fields)

      field => Incr%fields(i)

      IF (LdebugLinearModel) THEN
        CALL field%stats (fstats)
        IF (my_comm%rank() .eq. 0)                                             &
          PRINT 20, field%metadata%getval_name, field%metadata%io_name,        &
                    fstats(1), fstats(2), INT(fstats(3),KIND=8)
      END IF

      SELECT CASE (field%name)
         CASE ('ssh')                                   !> free-surface
           OCEAN(ng)%ad_zeta(:,:,Tindex2d) = field%val(:,:,1)
         CASE ('uocn')                                  !> 3D U-momentum
           OCEAN(ng)%ad_u(:,:,:,Tindex3d) = field%val
         CASE ('vocn')                                  !> 3D V-momentum
           OCEAN(ng)%ad_v(:,:,:,Tindex3d) = field%val
         CASE ('tocn', 'socn')                          !> tracers
           itrc = roms_tracer_index(field%name)
           OCEAN(ng)%ad_t(:,:,:,Tindex3d,itrc) = field%val
         CASE DEFAULT
           CALL abor1_ftn ("jedi2roms_incr: Cannot find option for field: "//  &
                           TRIM(field%name))
      END SELECT

    END DO

  END IF ROMS_KERNEL

  10 FORMAT (1x,a,', Nfields = ',i2,', timestep = ',i5.5,', timelevel = (',i0, &
             ', ',i0,'), date: ',a)
  20 FORMAT (19x,'- ',a,': ',a,/,22x,'(Min = ',1p,e15.8,' Max = ',1p,e15.8,    &
             ')',t93,'Checksum = ',i0)

END SUBROUTINE jedi2roms_incr

! ------------------------------------------------------------------------------
!> It loads either ROMS tangent linear or adjoint state solution into increment
!! object.

SUBROUTINE roms2jedi_incr (ng, kernel, Tindex2d, Tindex3d, Incr, DateString)

  USE dateclock_mod, ONLY : time_string
  USE mod_ocean,     ONLY : OCEAN
  USE mod_scalars,   ONLY : jic, time4jedi
  USE mod_stepping,  ONLY : kstp

  integer,                        intent(in   ) :: ng          !< nested grid
  integer,                        intent(in   ) :: kernel      !< ROMS kernel
  integer,                        intent(in   ) :: Tindex2d    !< 2D time level
  integer,                        intent(in   ) :: Tindex3d    !< 3D time level
  CLASS (roms_increment), target, intent(inout) :: Incr        !< Increment
  character (len=*),              intent(in   ) :: DateString  !< DateTime

  TYPE (roms_field), pointer                    :: field
  integer                                       :: Is, Ie, Js, Je
  integer                                       :: i, itrc
  real (kind=kind_real)                         :: fstats(3)
  character (len=22)                            :: DateTimeStr

  ! Set ROMS date/time string.

  IF (LdebugLinearModel) CALL time_string  (time4jedi(ng), DateTimeStr)

  ! Load ROMS tangent linear or adjoint fields into JEDI increment object.

  ROMS_KERNEL : IF (kernel .eq. iTLM) THEN

    IF (LdebugLinearModel .and. (my_comm%rank() .eq. 0))                       &
      PRINT 10, 'ROMS_DEBUG roms2jedi_incr: Loading TL ROMS increments '//     &
                'into JEDI', SIZE(Incr%fields), jic(ng)-1, Tindex2d,           &
                Tindex3d, TRIM(DateString)

    DO i=1, SIZE(Incr%fields)

      field => Incr%fields(i)

      SELECT CASE (field%name)

        CASE ('ssh')                                           !> free-surface
          field%val(:,:,1) = OCEAN(ng)%tl_zeta(:,:,Tindex2d)

        CASE ('uocn')                                          !> 3D U-momentum
          field%val = OCEAN(ng)%tl_u(:,:,:,Tindex3d)

        CASE ('vocn')                                          !> 3D V-momentum
          field%val = OCEAN(ng)%tl_v(:,:,:,Tindex3d)

        CASE ('tocn', 'socn')                                  !> tracers
          itrc = roms_tracer_index(field%name)
          field%val = OCEAN(ng)%tl_t(:,:,:,Tindex3d,itrc)

        CASE DEFAULT
          CALL abor1_ftn ("roms2jedi_incr: Cannot find option for field: " //  &
                          TRIM(field%name))

      END SELECT

      IF (LdebugLinearModel) THEN
        CALL field%stats (fstats)
        IF (my_comm%rank() .eq. 0)                                             &
          PRINT 20, field%metadata%getval_name, field%metadata%io_name,        &
                    fstats(1), fstats(2), INT(fstats(3),KIND=8)
      END IF

    END DO

  ELSE IF (kernel .eq. iADM) THEN  

    IF (LdebugLinearModel .and. (my_comm%rank() .eq. 0))                       &
      PRINT 10, 'ROMS_DEBUG roms2jedi_incr: Loading AD ROMS increments '//     &
                'into JEDI', SIZE(Incr%fields), jic(ng), Tindex2d,             &
                Tindex3d, TRIM(DateString)

    DO i=1, SIZE(Incr%fields)

      field => Incr%fields(i)

      Is = field%bounds%IstrD
      Ie = field%bounds%IendD
      Js = field%bounds%JstrD
      Je = field%bounds%JendD

      ! Use ROMS full adjoint output solution. Due to the predictor/corrector
      ! and multiple time level schemes, pieces of the adjoint solution are
      ! in two-time levels and are added in the "_sol" arrays for output and
      ! exchange purposes.

      IF (Tindex3d.le.0) THEN

        SELECT CASE (field%name)

          CASE ('ssh')                                         !> free-surface
            field%val(:,:,1) = OCEAN(ng)%ad_zeta_sol

          CASE ('uocn')                                        !> 3D U-momentum
            field%val = OCEAN(ng)%ad_u_sol

          CASE ('vocn')                                        !> 3D V-momentum
            field%val = OCEAN(ng)%ad_v_sol

          CASE ('tocn', 'socn')                                !> tracers
            itrc = roms_tracer_index(field%name)
            field%val = OCEAN(ng)%ad_t_sol(:,:,:,itrc)

          CASE DEFAULT
            CALL abor1_ftn ("roms2jedi_incr: Cannot find option for field: "// &
                            TRIM(field%name))

        END SELECT

      ! Otherwise, use specified time level "Tindex" for the last timestep

      ELSE

        SELECT CASE (field%name)

          CASE ('ssh')                                         !> free-surface
            field%val(:,:,1) = OCEAN(ng)%ad_zeta(:,:,Tindex2d)

          CASE ('uocn')                                        !> 3D U-momentum
            field%val = OCEAN(ng)%ad_u(:,:,:,Tindex3d)

          CASE ('vocn')                                        !> 3D V-momentum
            field%val = OCEAN(ng)%ad_v(:,:,:,Tindex3d)

          CASE ('tocn', 'socn')                                !> tracers
            itrc = roms_tracer_index(field%name)
            field%val = OCEAN(ng)%ad_t(:,:,:,Tindex3d,itrc)

          CASE DEFAULT
            CALL abor1_ftn ("roms2jedi_incr: Cannot find option for field: "// &
                            TRIM(field%name))

        END SELECT

      END IF

      IF (LdebugLinearModel) THEN
        CALL field%stats (fstats)
        IF (my_comm%rank() .eq. 0)                                             &
          PRINT 20, field%metadata%getval_name, field%metadata%io_name,        &
                    fstats(1), fstats(2), INT(fstats(3),KIND=8)
      END IF

    END DO

  END IF ROMS_KERNEL

  10 FORMAT (1x,a,', Nfields = ',i2,', timestep = ',i5.5,', timelevel = (',i0, &
             ', ',i0,'), date: ',a)
  20 FORMAT (19x,'- ',a,': ',a,/,22x,'(Min = ',1p,e15.8,' Max = ',1p,e15.8,    &
             ')',t93,'Checksum = ',i0)

END SUBROUTINE roms2jedi_incr

! ------------------------------------------------------------------------------

END MODULE roms_linearModel_mod
