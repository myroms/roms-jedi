#undef UV_CHANGE
! (C) Copyright 2017-2025 UCAR
! 
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0. 
! ------------------------------------------------------------------------------
!
!>
!! \brief   **Model** class to initialize, run, and finalize ROMS nonlinear
!!          kernel.
!!
!! \details This class includes several routines used by JEDI to take control
!!          on how the nonlinear kernel is initialized, advanced, and
!!          terminated.
!!
!! \author  Hernan G. Arango (Rutgers University)
!! \date    September 2021

MODULE roms_model_mod

USE kinds,                      ONLY : kind_real

USE iso_c_binding
USE datetime_mod,               ONLY : datetime,                               &
                                       datetime_create,                        &
                                       datetime_set
USE duration_mod
USE fckit_configuration_module, ONLY : fckit_configuration
USE fckit_mpi_module,           ONLY : fckit_mpi_comm

!> ROMS modules association.

USE dateclock_mod,              ONLY : time_string
USE mod_arrays,                 ONLY : ROMS_deallocate_arrays
USE mod_boundary,               ONLY : initialize_boundary
USE mod_coupling,               ONLY : COUPLING, initialize_coupling
USE mod_forces,                 ONLY : initialize_forces
USE mod_grid,                   ONLY : GRID
USE mod_mixing,                 ONLY : MIXING, initialize_mixing
USE mod_ocean,                  ONLY : OCEAN,  initialize_ocean
USE mod_param,                  ONLY : BOUNDS, Ngrids, iNLM
USE mod_scalars,                ONLY : INItime, NoError, blowup_string, dt,    &
                                       exit_flag, iic, jic, ntend, ntimes,     &
                                       sec2day, tdays, time, time4jedi
USE mod_stepping,               ONLY : knew, kstp, nnew, nstp
USE roms_kernel_mod

!> ROMS-JEDI interface module association.

USE roms_geom_mod,              ONLY : roms_geom,                              &
                                       roms_tile
USE roms_field_mod,             ONLY : roms_field
USE roms_fieldsutils_mod,       ONLY : date2string,                            & 
                                       LdebugModel,                            &
                                       LwroteIncrement,                        &
                                       roms_date2time,                         &
                                       roms_tracer_index
USE roms_state_mod,             ONLY : roms_state
#ifdef UV_CHANGE
USE roms_utils_mod,             ONLY : vector_a_to_c,                          &
                                       vector_c_to_a
#endif

implicit none

!> Local routines.

PRIVATE :: jedi2roms_state                 ! Load JEDI nonlinear state into ROMS
PRIVATE :: roms2jedi_state                 ! Load ROMS nonlinear state into JEDI

!-------------------------------------------------------------------------------
!> Fortran derived type to hold ROMS nodel kernel definition.

TYPE, PUBLIC :: roms_model

  TYPE (fckit_mpi_comm) :: f_comm          ! MPI communicator

  TYPE (roms_tile)      :: bounds(4)       ! tile indice range

  integer :: ng                            ! nested grid number
  integer :: tile                          ! domain parallel partition tile

  integer :: IniRec                        ! initial conditions NetCDF record
  integer :: NghostPoints                  ! number of tile ghost points
  integer :: LBi, UBi, LBj, UBj, LBk, UBk  ! array(i,j,k) allocation bounds
  integer :: N                             ! number of vertical levels

  real(kind=kind_real) :: dt               ! baroclinic timestep size (s)
  real(kind=kind_real) :: INItime          ! Initial conditions time (s)
  real(kind=kind_real) :: RunInterval      ! timestepping window interval (s)
  real(kind=kind_real) :: SimulationPeriod ! total simulation period (s)
  real(kind=kind_real) :: time             ! current ROMS time (s)

  character (len=20)   :: iso_datetime     ! current ROMS ISO8601 date/time
  character (len=22)   :: roms_datetime    ! current ROMS date/time
  character (len=256)  :: roms_IniName     ! initial conditions NetCDF filename

  CONTAINS

  PROCEDURE :: create     => roms_model_create
  PROCEDURE :: delete     => roms_model_delete
  PROCEDURE :: initialize => roms_model_initialize
  PROCEDURE :: step       => roms_model_step
  PROCEDURE :: finalize   => roms_model_finalize

END TYPE roms_model

!-------------------------------------------------------------------------------

PRIVATE

! Set switch to read ROMS standard input parameter file and allocate and
! initialize (first touch policy) variables and structures. It needs to be
! done once for each simulation.

logical :: LsetROMS

! MPI communicator.

TYPE (fckit_mpi_comm) :: my_comm

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
!> Creates ROMS NLM kernel object.

SUBROUTINE roms_model_create (self, geom, f_conf)

  CLASS (roms_model),         intent(inout) :: self
  TYPE (roms_geom),           intent(in   ) :: geom
  TYPE (fckit_configuration), intent(in   ) :: f_conf

  TYPE (duration)                           :: dtYAML !> ISO8601 duration format
  integer                                   :: IniRec !> NetCDF file IC record
  real (kind=kind_real)                     :: dtJEDI !> JEDI interval (seconds)
  character (len=:), allocatable            :: directory, filename, string

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

  !> Set ROMS initial conditions NetCDF filename and record.

  IF (f_conf%has("initial condition")) THEN
    IF (.not.f_conf%get("fields_dir", directory)) THEN
      CALL abor1_ftn ("roms_model::create - Cannot find: "//                   &
                      '''initial condition.fields_dir''')
    END IF

    IF (.not.f_conf%get("initial condition.fields_filename", filename)) THEN
      CALL abor1_ftn ("roms_model::create - Cannot find: "//                   &
                      '''initial condition.fields_filename''')
    END IF
    self%roms_IniName = TRIM(directory)//TRIM(filename)

    IF (.not.f_conf%get("initial condition.fields_record", IniRec)) THEN
      CALL abor1_ftn ("roms_model::create - Cannot find: "//                   &
                      '''initial condition.fields_record''')
    END IF
    self%IniRec = IniRec
  END IF

  !> Set ROMS time integration interval. Usually, a single or few timesteps.

  self%RunInterval = dtJEDI

  !> Set MPI Fortran object.

  self%f_comm = geom%f_comm

  !> Domain decomposition ranges and indices.

  self%ng   = geom%ng
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

END SUBROUTINE roms_model_create

! ------------------------------------------------------------------------------
!> Destroys ROMS NLM kernel object.

SUBROUTINE roms_model_delete (self)

  CLASS (roms_model), intent(inout) :: self

  ! Deallocate ROMS state arrays and vectors. It forces regular allocation and
  ! initialization in the next JEDI iteration, although not needed if the
  ! resolution of the Geometry object remains the same. Anyway, ut is always
  ! a good idea to release memory to avoid any leaks.

  CALL ROMS_deallocate_arrays
  LsetROMS = .TRUE.

END SUBROUTINE roms_model_delete

! ------------------------------------------------------------------------------
!> Initializes ROMS NLM model kernel.  We cannot use 'ROMS_initialize' here
!! because it is specific to a particular algorithm.  We need a generic JEDI
!! initialization of ROMS with using the state object.

SUBROUTINE roms_model_initialize (self, state, geom, vdate)

  CLASS (roms_model), intent(inout) :: self    !< ROMS NLM object
  CLASS (roms_state), intent(inout) :: state   !< State fields object
  TYPE (roms_geom),   intent(inout) :: geom    !< geometry object
  TYPE (datetime),    intent(in   ) :: vdate   !< State valid DateTime

  integer                           :: LocalPET, MyComm, Tindex2d, Tindex3d
  integer                           :: my_ntimes, ng
  real (kind=kind_real)             :: romsDateNumber, romsTime(Ngrids)
  character (len=22)                :: CurrentDateString
  character (len=80)                :: ncname

  !> Get MPI communicator and PET rank. Get nested grid number.

  MyComm   = self%f_comm%communicator()
  LocalPET = self%f_comm%rank()
  ng       = self%ng

  !> Get JEDI state valid DateTime string.

  CALL date2string (vdate, CurrentDateString, ISO=.FALSE.)

  !> ROMS-JEDI phase 1 initialization. If appropriate, read in standard input
  !> parameters. Then, allocate/initialize parameters and variables when switch
  !> LsetROMS is on. It sets TLM time-stepping parameters.

  LsetROMS = .TRUE.
  IF (allocated(BOUNDS)) LsetROMS = .FALSE.

  CALL ROMS_initializeP1 (LsetROMS,                                            &
                          mpiCOMM = MyComm,                                    &
                          kernel  = iNLM)
  IF (exit_flag .ne. NoError) THEN
    CALL abor1_ftn ("roms_model::initialize: Error in ROMS_initializeP1")
  END IF

  !> Reset ROMS total number of timesteps, if shorter simulation time period is
  !> is specified in the YAML file.

  my_ntimes = INT(self%SimulationPeriod/dt(ng))

  IF (my_ntimes .ne. ntimes(ng)) THEN
    IF (LocalPET .eq. 0)                                                       &
      PRINT '(2(a,i0))', ' roms_model::initialize: Reset input parameter,'//   &
                         ' NTIMES = ', ntimes(ng), ' to ', my_ntimes
    ntimes(ng) = my_ntimes
  END IF

  !> Get initial state date-time and over-write ROMS time.  Load initial
  !> time (s). It is needed to set-up ROMS counters correctly.

  CALL roms_date2time (LocalPET, vdate, romsTime(ng), romsDateNumber)

  INItime(ng)  = romsTime(ng)                      ! ROMS initial time (s)
  self%INItime = romsTime(ng)                      ! JEDI initial time (s)
  time(ng)     = romsTime(ng)                      ! Current ROMS time (s)
  tdays(ng)    = time(ng)*sec2day                  ! Current ROMS time (days)

  !> Load JEDI initial state fields into ROMS NLM arrays. At initialization,
  !> all time indices are set to one.

  Tindex2d = kstp(ng)                              ! timestep 2D index
  Tindex3d = nstp(ng)                              ! timestep 3D index

  CALL jedi2roms_state (ng, iNLM, Tindex2d, Tindex3d, state, geom,             &
                        CurrentDateString)

  !> ROMS-JEDI phase 2 initialization. Compleate the initialization using
  !> the state fields loaded above. Compute depths, density, and horizontal
  !> mass fluxes.

  CALL ROMS_initializeP2 (iNLM)
  IF (exit_flag .ne. NoError) THEN
    CALL abor1_ftn ("roms_model::initialize: Error in ROMS_initializeP2")
  END IF

  !> ROMS-JEDI phase 3 initialization. Compute the initial depths and
  !> level thicknesses from the initial free-surface field. Additionally,
  !> initialize the nonlinear state variables for all time levels and
  !> applies lateral boundary conditions.

  CALL ROMS_initializeP3 (iNLM)
  IF (exit_flag .ne. NoError) THEN
    IF ((LEN_TRIM(blowup_string).gt.0) .and. (LocalPET.eq.0)) THEN
      PRINT '(a,/,2a)','roms_model::initialize Abnormal termination: BLOWUP.', &
                       'REASON: ', TRIM(blowup_string)
    END IF
    CALL abor1_ftn ("roms_model::initialize Error while calling ROMS_run")
  END IF

  !> ROMS applied lateral boundary conditions to the initial state vector.
  !> Pass the outdated state vector back to JEDI.

  CALL roms2jedi_state (ng, iNLM, Tindex2d, Tindex3d, state, geom,             &
                        CurrentDateString)

  !> If debugging, write out initial state vector into ROMS-JEDI history,
  !> which can be used to compare to native ROMS solution.  Avoid writing
  !> during the analysis phase because of I/O interference.

  IF (.not. LwroteIncrement .and. LdebugModel) THEN
    ncname = 'Data/trajectory/roms_jedi_his.nc'
    CALL state%write_debug (ncname, vdate)               ! create and write
  END IF

END SUBROUTINE roms_model_initialize

! ------------------------------------------------------------------------------
!> Advances ROMS NLM kernel for specified time interval in seconds.

SUBROUTINE roms_model_step (self, state, geom, vdate)

  CLASS (roms_model), intent(inout) :: self    !< ROMS NLM object
  CLASS (roms_state), intent(inout) :: state   !< State fields object
  TYPE (roms_geom),   intent(inout) :: geom    !< geometry object
  TYPE (datetime),    intent(inout) :: vdate   !< Valid DateTime after step

  integer                           :: Tindex2d, Tindex3d, ng
  character (len=80)                :: ncname

  !> Initialize.

  ng = self%ng

  !> Advance ROMS NLM kernel for the specified RunInterval in seconds.
  !> It needs to be a multiple of the baroclinic timestep.  In OOPS, the
  !> RunInterval is usually a single ROMS timestep.

  CALL ROMS_run (self%RunInterval, kernel=iNLM)
  IF (exit_flag .ne. NoError) THEN
    IF ((LEN_TRIM(blowup_string).gt.0).and.(geom%f_comm%rank().eq.0)) THEN
      PRINT '(a,/,2a)', 'roms_model::step Abnormal remination: BLOWUP.',       &
                        'REASON: ', TRIM(blowup_string)
    END IF
    CALL abor1_ftn ("roms_model::step Error while calling ROMS_run")
  END IF

  !> Update state fields with current ROMS NLM values. In ROMS, the time-level
  !> rolling indices are updated at the beginning of the timestepping. Thus,
  !> "nnew" is the correct time level for the state solution.

  Tindex2d = 1                        ! 2D coupling index in step3d_uv
  Tindex3d = nnew(ng)                 ! current 3D solution at the of main3d

  CALL roms2jedi_state (ng, iNLM, Tindex2d, Tindex3d, state, geom,             &
                        TRIM(self%roms_datetime))

  !> If debugging, write out NLM state vector into ROMS-JEDI history, which
  !> can be used to compare to native ROMS solution. Avoid writing during the
  !> analysis phase because of I/O interference.

  IF (.not. LwroteIncrement .and. LdebugModel) THEN
    ncname = 'Data/trajectory/roms_jedi_his.nc'
    CALL state%write_debug (ncname, vdate,                                     &
                            Append = .TRUE.)             ! append records
  END IF

  !> If last timestep, run the last-half step to finich all ROMS native delayed
  !> output, which does not affect the ROMS-JEDI inteface.
  
  IF (iic(ng).eq.ntend(ng)+1) THEN 
    CALL ROMS_run (self%RunInterval, kernel=iNLM)
    IF (exit_flag .ne. NoError) THEN
      IF ((LEN_TRIM(blowup_string).gt.0).and.(geom%f_comm%rank().eq.0)) THEN
        PRINT '(a,/,2a)', 'roms_model::step Abnormal remination: BLOWUP.',     &
                          'REASON: ', TRIM(blowup_string)
      END IF
      CALL abor1_ftn ("roms_model::step Error while calling ROMS_run last step")
    END IF
  END IF

END SUBROUTINE roms_model_step

! ------------------------------------------------------------------------------
!> Finalizes ROMS NLM kernel integration.
!! Notice that all ROMS type-derived structures are deallocated and LsetROMS
!! activated to produce identical solutions with the same initial state vector
!! generated by JEDI.

SUBROUTINE roms_model_finalize (self, state)

  CLASS (roms_model), target :: self
  CLASS (roms_state)         :: state

  !> Stops ROMS clocks, reports memory requirements, and close input/output
  !> NetCDF files. If blowing-up, it saves latests NLM state into RESTART file.

  CALL ROMS_finalize

  !> We cannot deallocate ROMS variables using "ROMS_deallocate_arrays" because
  !> some variables in the GRID structure are needed in variational data
  !> assimilation, after finishing time-stepping. However, we need to initialize
  !> several variables to zero in DA and to pass "test_romsjedi_model" Unit
  !> Test. Otherwise, we get the wrong norms.

   CALL initialize_boundary (self%ng, self%tile, iNLM)
   CALL initialize_coupling (self%ng, self%tile, iNLM)
   CALL initialize_forces   (self%ng, self%tile, iNLM)
   CALL initialize_mixing   (self%ng, self%tile, iNLM)
   CALL initialize_ocean    (self%ng, self%tile, iNLM)

!  CALL ROMS_deallocate_arrays
!  LsetROMS = .TRUE.

END SUBROUTINE roms_model_finalize

! ------------------------------------------------------------------------------
!> It loads JEDI nonlinear state fields into ROMS fields structures.

SUBROUTINE jedi2roms_state (ng, kernel, Tindex2d, Tindex3d, state, geom,       &
                            DateString)

  integer,                   intent(in   ) :: ng         !< nested grid number
  integer,                   intent(in   ) :: kernel     !< ROMS kernel
  integer,                   intent(in   ) :: Tindex2d   !< ROMS 2D time index
  integer,                   intent(in   ) :: Tindex3d   !< ROMS 3d time index
  TYPE (roms_state), target, intent(in   ) :: state      !< State fields object
  TYPE (roms_geom),          intent(inout) :: geom       !< geometry object
  character (len=*),         intent(in   ) :: DateString !< State valid DateTime

  TYPE (roms_field),               pointer :: field => null()
#ifdef UV_CHANGE
  TYPE (roms_field),               pointer :: Ua    => null()
  TYPE (roms_field),               pointer :: Va    => null()
  real (kind=kind_real),       allocatable :: Uc(:,:,:), Vc(:,:,:)

  logical                                  :: have_Uc, have_Vc
  logical                                  :: need_Uc, need_Vc
#endif

  integer                                  :: i, itrc
  real (kind=kind_real)                    :: stats(4)
  character (len=22)                       :: DateTimeStr

  ! Set ROMS date/time string.

  IF (LdebugModel) CALL time_string  (time(ng), DateTimeStr)

#ifdef UV_CHANGE
  ! If state has A-grid currents, perform variable change from A- to C-grid
  ! velicities.

  need_Uc = state%has('eastward_sea_water_velocity')
  need_Vc = state%has('northward_sea_water_velocity')

  have_Uc = .FALSE.
  have_Vc = .FALSE.

  IF (need_Uc .or. need_Vc) THEN
    CALL state%get ('eastward_sea_water_velocity',  Ua)
    CALL state%get ('northward_sea_water_velocity', Va)

    allocate ( Uc(geom%LBi:geom%UBi, geom%LBj:geom%UBj, geom%N) )
    allocate ( Vc(geom%LBi:geom%UBi, geom%LBj:geom%UBj, geom%N) )

    Uc = 0.0_kind_real
    Vc = 0.0_kind_real

    CALL vector_a_to_c (geom, Ua%val, Va%val, Uc, Vc)
    OCEAN(ng)%u(:,:,:,Tindex3d) = Uc
    OCEAN(ng)%v(:,:,:,Tindex3d) = Vc
    have_Uc = .TRUE.
    have_Vc = .TRUE.
  END IF
#endif

  ! Load NLROMS state into JEDI state object.

  ROMS_KERNEL : IF (kernel .eq. iNLM) THEN

  ! Set ROMS DateTimeString

    IF (LdebugModel .and. (my_comm%rank() .eq. 0))                             &
      PRINT 10, 'ROMS_DEBUG jedi2roms_state: Loading JEDI statefield into '//  &
                'NL ROMS', SIZE(state%fields), jic(ng), Tindex2d,              &
                Tindex3d, TRIM(DateTimeStr)

    DO i=1, SIZE(state%fields)

      field => state%fields(i)

      IF (LdebugModel) THEN
        CALL field%stats (stats)
        IF (my_comm%rank() .eq. 0)                                             &
          PRINT 20, field%metadata%short_name, field%metadata%io_name,         &
                    stats(1), stats(2), INT(stats(4),KIND=8)
      END IF

      SELECT CASE (field%name)

        CASE ('ssh',                                                           &
              'sea_surface_height_above_geoid')
          OCEAN(ng)%zeta(:,:,Tindex2d) = field%val(:,:,1)

        CASE ('u2docn',                                                        &
              'barotropic_sea_water_x_velocity')
          OCEAN(ng)%ubar(:,:,Tindex2d) = field%val(:,:,1)

        CASE ('v2docn',                                                        &
              'barotropic_sea_water_y_velocity')
          OCEAN(ng)%vbar(:,:,Tindex2d) = field%val(:,:,1)

        CASE ('uaocn',                                                         &
              'eastward_sea_water_velocity')
          OCEAN(ng)%ua = field%val                     !> A-grid

        CASE ('vaocn',                                                         &
              'northward_sea_water_velocity')
          OCEAN(ng)%va = field%val                     !> A-grid

        CASE ('uocn',                                                          &
              'sea_water_x_velocity')
          OCEAN(ng)%u(:,:,:,Tindex3d) = field%val      !> C-grid

        CASE ('vocn',                                                          &
              'sea_water_y_velocity')
          OCEAN(ng)%v(:,:,:,Tindex3d) = field%val      !> C-grid

        CASE ('tocn',                                                          &
              'sea_water_temperature',                                         &
              'sea_water_potential_temperature',                               &
              'socn',                                                          &
              'sea_water_salinity')
          itrc = roms_tracer_index(field%name)
          OCEAN(ng)%t(:,:,:,Tindex3d,itrc) = field%val

        CASE ('Ktocn',                                                         &
              'vertical_diffusion_coefficient_of_temperature_in_sea_water',    &
              'Ksocn',                                                         &
              'vertical_diffusion_coefficient_of_salinity_in_sea_water')
          itrc = roms_tracer_index(field%name)
          MIXING(ng)%Akt(:,:,:,itrc) = field%val

        CASE ('Kvocn',                                                         &
              'vertical_viscosity_coefficient_of_sea_water')
          MIXING(ng)%Akv(:,:,:) = field%val

        CASE DEFAULT
           ! Only fields relevant to state vector are loaded.
      END SELECT
    END DO

  END IF ROMS_KERNEL

  10 FORMAT (2x,a,', Nfields = ',i2,', timestep = ',i5.5,', timelevel = (',i0, &
             ',',i0,'), date: ',a)
  20 FORMAT (19x,'- ',a,': ',a,/,22x,'(Min = ',1p,e15.8,' Max = ',1p,e15.8,    &
             ')',t93,'Checksum = ',i0)

END SUBROUTINE jedi2roms_state

! ------------------------------------------------------------------------------
!> It loads ROMS nonlinear state fields into JEDI state object.

SUBROUTINE roms2jedi_state (ng, kernel, Tindex2d, Tindex3d, state, geom,       &
                            DateString)

  integer,                   intent(in   ) :: ng         !< nested grid number
  integer,                   intent(in   ) :: kernel     !< ROMS kernel ID
  integer,                   intent(in   ) :: Tindex2d   !< ROMS 2D time index
  integer,                   intent(in   ) :: Tindex3d   !< ROMS 3D time index
  TYPE (roms_state), target, intent(inout) :: state      !< State fields object
  TYPE (roms_geom),          intent(inout) :: geom       !< geometry object
  character (len=*),         intent(in   ) :: DateString !< State valid DateTime

  TYPE (roms_field),               pointer :: field => null()
#ifdef UV_CHANGE
  TYPE (roms_field),               pointer :: Ua    => null()
  TYPE (roms_field),               pointer :: Va    => null()
  real (kind=kind_real),       allocatable :: Uc(:,:,:), Vc(:,:,:)

  logical                                  :: have_Ua, have_Va
  logical                                  :: need_Ua, need_Va
#endif

  integer                                  :: i, itrc, j, k
  real (kind=kind_real)                    :: stats(4)
  character (len=22)                       :: DateTimeStr

  ! Set ROMS DateTimeString

  IF (LdebugModel) CALL time_string  (time4jedi(ng), DateTimeStr)

#ifdef UV_CHANGE
  ! If state needs A-grid currents, perform variable change from C- to A-grid
  ! velicities.

  need_Ua = state%has('eastward_sea_water_velocity')
  need_Va = state%has('northward_sea_water_velocity')

  have_Ua = .FALSE.
  have_Va = .FALSE.

  IF (need_Ua .or. need_Va) THEN
    CALL state%get ('eastward_sea_water_velocity',  Ua)
    CALL state%get ('northward_sea_water_velocity', Va)

    allocate ( Uc(geom%LBi:geom%UBi, geom%LBj:geom%UBj, geom%N) )
    allocate ( Vc(geom%LBi:geom%UBi, geom%LBj:geom%UBj, geom%N) )

    Uc = 0.0_kind_real
    Vc = 0.0_kind_real

    Uc = OCEAN(ng)%u(:,:,:,Tindex3d)
    Vc = OCEAN(ng)%v(:,:,:,Tindex3d)
    CALL vector_c_to_a (geom, Uc, Vc, Ua%val, Va%val)
    have_Ua = .TRUE.
    have_Va = .TRUE.
  END IF
#endif

  ! Load NLROMS state into JEDI state object.

  ROMS_KERNEL : IF (kernel .eq. iNLM) THEN

    IF (LdebugModel .and. (my_comm%rank() .eq. 0))                             &
      PRINT 10, 'ROMS_DEBUG roms2jedi_state: Loading NL ROMS prediction '//    &
                'into JEDI', SIZE(state%fields), jic(ng)-1, Tindex2d,          &
                Tindex3d, TRIM(DateTimeStr)

    DO i=1, SIZE(state%fields)

      field => state%fields(i)

      SELECT CASE (field%name)

        CASE ('ssh',                                                           &
              'sea_surface_height_above_geoid')
          field%val(:,:,1) = COUPLING(ng)%Zt_avg1         !> time-averaged

        CASE ('u2docn',                                                        &
              'barotropic_sea_water_x_velocity')
          field%val(:,:,1) = OCEAN(ng)%ubar(:,:,Tindex2d) !> step3d_uv

        CASE ('v2docn',                                                        &
              'barotropic_sea_water_y_velocity')
          field%val(:,:,1) = OCEAN(ng)%vbar(:,:,Tindex2d) !> step3d_uv

        CASE ('DU_avg1',                                                       &
              'sea_water_time_average_of_barotropic_x_velocity_flux')
          field%val(:,:,1) = COUPLING(ng)%DU_avg1

        CASE ('DV_avg1',                                                       &
              'sea_water_time_average_of_barotropic_y_velocity_flux')
          field%val(:,:,1) = COUPLING(ng)%DV_avg1

        CASE ('DU_avg2',                                                       &
              'sea_water_correct_barotropic_x_velocity_flux_for_coupling')
          field%val(:,:,1) = COUPLING(ng)%DU_avg2

        CASE ('DV_avg2',                                                       &
              'sea_water_correct_barotropic_y_velocity_flux_for_coupling')
          field%val(:,:,1) = COUPLING(ng)%DV_avg2

        CASE ('uaocn',                                                         &
              'eastward_sea_water_velocity')
#ifdef UV_CHANGE
          IF (have_Ua) THEN
            OCEAN(ng)%ua = Ua%val                         !> A-grid
          END IF
#else
          field%val = OCEAN(ng)%ua                        !> A-grid
#endif

        CASE ('vaocn',                                                         &
              'northward_sea_water_velocity')
#ifdef UV_CHANGE
          IF (have_Va) THEN
            OCEAN(ng)%va = Va%val                         !> A-grid
          END IF
#else
          field%val = OCEAN(ng)%va                        !> A-grid
#endif
        CASE ('uocn',                                                          &
              'sea_water_x_velocity')

          field%val = OCEAN(ng)%u(:,:,:,Tindex3d)         !> C-grid

        CASE ('vocn',                                                          &
              'sea_water_y_velocity')
          field%val = OCEAN(ng)%v(:,:,:,Tindex3d)         !> C-grid

        CASE ('tocn',                                                          &
              'sea_water_temperature',                                         &
              'sea_water_potential_temperature',                               &
              'socn',                                                          &
              'sea_water_salinity')
          itrc = roms_tracer_index(field%name)
          field%val = OCEAN(ng)%t(:,:,:,Tindex3d,itrc)

        CASE ('z0ocn_r',                                                       &
              'unvarying_model_level_depth_at_cell_center')
          field%val = GRID(ng)%z0_r

        CASE ('z0ocn_w',                                                       &
              'unvarying_model_level_depth_at_cell_top_face')
          field%val = GRID(ng)%z0_w

        CASE ('zocn_r',                                                        &
              'model_level_depth_at_cell_center')
          field%val = GRID(ng)%z_r

        CASE ('Ktocn',                                                         &
              'vertical_diffusion_coefficient_of_temperature_in_sea_water',    &
              'Ksocn',                                                         &
              'vertical_diffusion_coefficient_of_salinity_in_sea_water')
          itrc = roms_tracer_index(field%name)
          field%val = MIXING(ng)%Akt(:,:,:,itrc)

        CASE ('Kvocn',                                                         &
              'vertical_viscosity_coefficient_of_sea_water')
          field%val = MIXING(ng)%Akv

        CASE DEFAULT
          CALL abor1_ftn (" roms2jedi_state: Cannot find option for field: "// &
                          TRIM(field%name))

      END SELECT

      IF (LdebugModel) THEN
        CALL field%stats (stats)
        IF (my_comm%rank() .eq. 0)                                             &
          PRINT 20, field%metadata%short_name, field%metadata%io_name,         &
                    stats(1), stats(2), INT(stats(4), KIND=8)
      END IF

    END DO

  END IF ROMS_KERNEL

  !> Update geometry time-dependent variables: depths (m; negative).

  geom%z_r = GRID(ng)%z_r
  geom%z_w = GRID(ng)%z_w

  DO k=1,geom%N
    DO j = geom%bounds(u2dvar)%JstrC-1, geom%bounds(u2dvar)%JendC+1
      DO i = geom%bounds(u2dvar)%IstrC-1, geom%bounds(u2dvar)%IendC+1
        geom%z_u(i,j,k) = 0.5_kind_real*(geom%z_r(i-1,j,k)+geom%z_r(i,j,k))
      END DO
    END DO

    DO j = geom%bounds(v2dvar)%JstrC-1, geom%bounds(v2dvar)%JendC+1
      DO i = geom%bounds(v2dvar)%IstrC-1, geom%bounds(v2dvar)%IendC+1
        geom%z_v(i,j,k) = 0.5_kind_real*(geom%z_r(i,j-1,k)+geom%z_r(i,j,k))
      END DO
    END DO
  END DO

#ifdef UV_CHANGE
! Deallocate local variables.

  IF (allocated(Uc)) deallocate (Uc)
  IF (allocated(Vc)) deallocate (Vc)
#endif
!
  10 FORMAT (2x,a,', Nfields = ',i2,', timestep = ',i5.5,', timelevel = (',i0, &
             ',',i0,'), date: ',a)
  20 FORMAT (19x,'- ',a,': ',a,/, 22x,'(Min = ',1p,e15.8,' Max = ',1p,e15.8,   &
             ')',t93,'Checksum = ',i0)

END SUBROUTINE roms2jedi_state

! ------------------------------------------------------------------------------

END MODULE roms_model_mod
