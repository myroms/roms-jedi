! (C) Copyright 2017-2023 UCAR
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

USE roms_kernel_mod
USE mod_param,                  ONLY : BOUNDS, Ngrids, iNLM
USE mod_scalars,                ONLY : NoError, exit_flag

!> ROMS-JEDI interface module association.

USE roms_geom_mod,              ONLY : roms_geom,                              &
                                       roms_tile
USE roms_field_mod,             ONLY : roms_field
USE roms_fieldsutils_mod,       ONLY : date2string,                            & 
                                       roms_date2time,                         &
                                       roms_tracer_index
USE roms_state_mod,             ONLY : roms_state

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

! Set debugging switch.

logical :: LdebugModel = .FALSE.

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

  USE mod_arrays, ONLY : ROMS_deallocate_arrays

  CLASS (roms_model), intent(inout) :: self

  ! Deallocate ROMS state arrays and vectors. It forces regular allocation and
  ! initialization in the next JEDI iteration, although not needed if the
  ! resolution of the Geometry object remains the same. Anyway, ut is always
  ! a good idea to release memory to avoid any leaks.

  CALL ROMS_deallocate_arrays

END SUBROUTINE roms_model_delete

! ------------------------------------------------------------------------------
!> Initializes ROMS NLM model kernel.  We cannot use 'ROMS_initialize' here
!! because it is specific to a particular algorithm.  We need a generic JEDI
!! initialization of ROMS with using the state object.

SUBROUTINE roms_model_initialize (self, state, vdate)

  USE mod_ncparam,  ONLY : Ngrids
  USE mod_scalars,  ONLY : INItime, dt, ntimes, time
  USE mod_stepping, ONLY : nnew

  CLASS (roms_model), intent(inout) :: self    !< ROMS NLM object
  CLASS (roms_state), intent(inout) :: state   !< State fields object
  TYPE (datetime),    intent(in   ) :: vdate   !< State valid DateTime

  integer                           :: LocalPET, MyComm, Tindex, ng
  integer                           :: my_ntimes
  real (kind=kind_real)             :: romsDateNumber, romsTime(Ngrids)
  character (len=22)                :: CurrentDateString

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

  CALL ROMS_initialize (LsetROMS,                                              &
                        mpiCOMM = MyComm,                                      &
                        kernel  = iNLM)
  IF (exit_flag .ne. NoError) THEN
    CALL abor1_ftn ("roms_model::initialize: Error in ROMS_initialize")
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

  !> Load JEDI initial state fields into ROMS NLM arrays.

  Tindex = nnew(ng)                                  !> timestep index

  CALL jedi2roms_state (ng, iNLM, Tindex, state, CurrentDateString)

  !> ROMS-JEDI phase 2 initialization. Compleate the initialization using
  !> the state fields loaded above. Compute depths, density, and horizontal
  !> mass fluxes.

  CALL ROMS_initializeP2 (iNLM)
  IF (exit_flag .ne. NoError) THEN
    CALL abor1_ftn ("roms_model::initialize: Error in ROMS_initializeP2")
  END IF

END SUBROUTINE roms_model_initialize

! ------------------------------------------------------------------------------
!> Advances ROMS NLM kernel for specified time interval in seconds.

SUBROUTINE roms_model_step (self, state, geom, vdate)

  USE dateclock_mod, ONLY : time_iso8601
  USE mod_scalars,   ONLY : time4jedi
  USE mod_stepping,  ONLY : nnew

  CLASS (roms_model), intent(inout) :: self    !< ROMS NLM object
  CLASS (roms_state), intent(inout) :: state   !< State fields object
  TYPE (roms_geom),   intent(inout) :: geom    !< geometry object
  TYPE (datetime),    intent(inout) :: vdate   !< Valid DateTime after step

  integer                           :: Tindex, ng

  !> Initialize.

  ng = self%ng

  !> Advance ROMS NLM kernel for the specified RunInterval in seconds.
  !> It needs to be a multiple of the baroclinic timestep.  In OOPS, the
  !> RunInterval is usually a single ROMS timestep.

  CALL ROMS_run (self%RunInterval, kernel=iNLM)
  IF (exit_flag .ne. NoError) THEN
    CALL abor1_ftn ("roms_model::step Error while calling ROMS_run")
  END IF

  !> Reset valid date/time current NLM step interval.
  !>
  !> ROMS has a predictor/corrector three-time levels timestep. Also, the I/O
  !> is delayed for the half timestep. Therefore, we need to reset the JEDI
  !> state valid DateTime back one timestep to account for the delayed I/O and
  !> initial conditions modification.
  !>
  !> Notice that in the first timestep, NL ROMS updates the initial state
  !> lateral boundary conditions and recomputes vertically integrated momentum
  !> in timelevel "nstp". And, then, it advances the solution to timelevel
  !> "nnew". Thus, delaying the NL ROMS DateTime allows to overwrite JEDI
  !> initial conditions and the timestepping is increased by the half timestep
  !> needed by NL ROMS to compleate the solution. ROMS has the 'time4jedi'
  !> to avoid any confusion to its regular clock that it is advanced at the
  !> end of the timestep.

  self%time = time4jedi(ng)
  CALL time_iso8601 (self%time, self%iso_datetime)
  CALL datetime_set (self%iso_datetime, vdate)
  CALL date2string (vdate, self%roms_datetime, ISO=.FALSE.)

  !> Update state fields with current ROMS NLM values. In ROMS, the time-level
  !> rolling indices are updated at the beginning of the timestepping. Thus,
  !> "nnew" is the correct time level for the state exchage here.

  Tindex = nnew(ng)

  CALL roms2jedi_state (ng, iNLM, Tindex, state, geom, TRIM(self%roms_datetime))

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

  !> Deallocates ROMS state arrays and vectors.

  CALL ROMS_deallocate_arrays

  !> Turn on ROMS allocate/initialize switch for next JEDI tasks, if any.

  LsetROMS = .TRUE.

END SUBROUTINE roms_model_finalize

! ------------------------------------------------------------------------------
!> It loads JEDI nonlinear state fields into ROMS fields structures.

SUBROUTINE jedi2roms_state (ng, kernel, Tindex, state, DateString)

  USE mod_ocean,    ONLY : OCEAN
  USE mod_scalars,  ONLY : jic, time

  integer,                   intent(in) :: ng          !< nested grid number
  integer,                   intent(in) :: kernel      !< ROMS kernel identifier
  integer,                   intent(in) :: Tindex      !< ROMS time level index
  TYPE (roms_state), target, intent(in) :: state       !< State fields object
  character (len=*),         intent(in) :: DateString  !< State valid DateTime

  TYPE (roms_field), pointer            :: field
  integer                               :: i, itrc
  real (kind=kind_real)                 :: fstats(3)
  character (len=22)                    :: DateTimeStr

  ! Set ROMS date/time string.

  IF (LdebugModel) CALL time_string  (time(ng), DateTimeStr)

  ! Load NLROMS state into JEDI state object.

  ROMS_KERNEL : IF (kernel .eq. iNLM) THEN

  ! Set ROMS DateTimeString

    IF (LdebugModel .and. (my_comm%rank() .eq. 0))                             &
      PRINT 10, 'ROMS_DEBUG jedi2roms_state: Loading JEDI statefield into '//  &
                'NL ROMS', SIZE(state%fields), MAX(0,jic(ng)-1), Tindex,       &
                TRIM(DateString)

    DO i=1, SIZE(state%fields)

      field => state%fields(i)

      IF (LdebugModel) THEN
        CALL field%stats (fstats)
        IF (my_comm%rank() .eq. 0)                                             &
          PRINT 20, field%metadata%getval_name, field%metadata%io_name,        &
                    fstats(1), fstats(2), INT(fstats(3),KIND=8)
      END IF

      SELECT CASE (field%name)
         CASE ('ssh')                                   !> free-surface
           OCEAN(ng)%zeta(:,:,Tindex) = field%val(:,:,1)
         CASE ('uocn')                                  !> 3D U-momentum
           OCEAN(ng)%u(:,:,:,Tindex) = field%val
         CASE ('vocn')                                  !> 3D V-momentum
           OCEAN(ng)%v(:,:,:,Tindex) = field%val
         CASE ('tocn', 'socn')                          !> tracers
           itrc = roms_tracer_index(field%name)
           OCEAN(ng)%t(:,:,:,Tindex,itrc) = field%val
         CASE DEFAULT
           ! Only fields relevant to state vector are loaded.
      END SELECT
    END DO

  END IF ROMS_KERNEL

  10 FORMAT (2x,a,', Nfields = ',i2,', timestep = ',i5.5,',timelevel = ',i0,   &
             ', date: ',a)
  20 FORMAT (19x,'- ',a,': ',a,/,22x,'(Min = ',1p,e15.8,' Max = ',1p,e15.8,    &
             ')',t93,'Checksum = ',i0)

END SUBROUTINE jedi2roms_state

! ------------------------------------------------------------------------------
!> It loads ROMS nonlinear state fields into JEDI state object.

SUBROUTINE roms2jedi_state (ng, kernel, Tindex, state, geom, DateString)

  USE dateclock_mod, ONLY : time_string
  USE mod_coupling,  ONLY : COUPLING
  USE mod_grid,      ONLY : GRID
  USE mod_mixing,    ONLY : MIXING
  USE mod_ocean,     ONLY : OCEAN
  USE mod_scalars,   ONLY : jic, time4jedi

  integer,                   intent(in   ) :: ng         !< nested grid number
  integer,                   intent(in   ) :: kernel     !< ROMS kernel ID
  integer,                   intent(in   ) :: Tindex     !< ROMS time index
  TYPE (roms_state), target, intent(inout) :: state      !< State fields object
  TYPE (roms_geom),          intent(inout) :: geom       !< geometry object
  character (len=*),         intent(in   ) :: DateString !< State valid DateTime

  TYPE (roms_field), pointer               :: field
  integer                                  :: Is, Ie, Js, Je
  integer                                  :: i, itrc, j, k
  real (kind=kind_real)                    :: fstats(3)
  character (len=22)                       :: DateTimeStr

  ! Set ROMS DateTimeString

  IF (LdebugModel) CALL time_string  (time4jedi(ng), DateTimeStr)

  ! Load NLROMS state into JEDI state object.

  ROMS_KERNEL : IF (kernel .eq. iNLM) THEN

    IF (LdebugModel .and. (my_comm%rank() .eq. 0))                             &
      PRINT 10, 'ROMS_DEBUG roms2jedi_state: Loading NL ROMS prediction '//    &
                'into JEDI', SIZE(state%fields), jic(ng)-1, Tindex,            &
                TRIM(DateString)

    DO i=1, SIZE(state%fields)

      field => state%fields(i)

      Is = field%bounds%IstrD
      Ie = field%bounds%IendD
      Js = field%bounds%JstrD
      Je = field%bounds%JendD

      SELECT CASE (field%name)

        CASE ('ssh')                                    !> free-surface
          field%val(Is:Ie,Js:Je,1) = OCEAN(ng)%zeta(Is:Ie,Js:Je,Tindex)
        CASE ('u2docn')                                 !> 2D U-momentum
          field%val(Is:Ie,Js:Je,1) = OCEAN(ng)%ubar(Is:Ie,Js:Je,Tindex)
        CASE ('v2docn')                                 !> 2D V-momentum
          field%val(Is:Ie,Js:Je,1) = OCEAN(ng)%vbar(Is:Ie,Js:Je,Tindex)
        CASE ('DU_avg1')                                !> averaged 2D U-flux
          field%val(Is:Ie,Js:Je,1) = COUPLING(ng)%DU_avg1(Is:Ie,Js:Je)
        CASE ('DV_avg1')                                !> averaged 2D V-flux
          field%val(Is:Ie,Js:Je,1) = COUPLING(ng)%DV_avg1(Is:Ie,Js:Je)
        CASE ('DU_avg2')                                !> U-flux 3D coupling
          field%val(Is:Ie,Js:Je,1) = COUPLING(ng)%DU_avg2(Is:Ie,Js:Je)
        CASE ('DV_avg2')                                !> V-flux 3D coupling
          field%val(Is:Ie,Js:Je,1) = COUPLING(ng)%DV_avg2(Is:Ie,Js:Je)
        CASE ('uocn')                                   !> 3D U-momentum
          field%val(Is:Ie,Js:Je,:) = OCEAN(ng)%u(Is:Ie,Js:Je,:,Tindex)
        CASE ('vocn')                                   !> 3D V-momentum
          field%val(Is:Ie,Js:Je,:) = OCEAN(ng)%v(Is:Ie,Js:Je,:,Tindex)
        CASE ('tocn', 'socn')                           !> tracers
          itrc = roms_tracer_index(field%name)
          field%val(Is:Ie,Js:Je,:) = OCEAN(ng)%t(Is:Ie,Js:Je,:,Tindex,itrc)
        CASE ('z0ocn_r')                                !> unvarying rho-depths
          field%val(Is:Ie,Js:Je,:) = GRID(ng)%z0_r(Is:Ie,Js:Je,:)
        CASE ('z0ocn_w')                                !> unvarying w-depths
          field%val(Is:Ie,Js:Je,:) = GRID(ng)%z0_w(Is:Ie,Js:Je,:)
        CASE ('zocn_r')                                 !> varying rho-depths
          field%val(Is:Ie,Js:Je,:) = GRID(ng)%z_r(Is:Ie,Js:Je,:)
        CASE ('zocn_w')                                 !> varying w-depths
          field%val(Is:Ie,Js:Je,:) = GRID(ng)%z_r(Is:Ie,Js:Je,:)
        CASE ('Ktocn', 'Ksocn')                         !> vertical diffusion
          itrc = roms_tracer_index(field%name)
          field%val(Is:Ie,Js:Je,:) = MIXING(ng)%Akt(Is:Ie,Js:Je,:,itrc)
        CASE ('Kvocn')                                  !> vertical viscosity
          field%val(Is:Ie,Js:Je,:) = MIXING(ng)%Akt(Is:Ie,Js:Je,:,itrc)
        CASE DEFAULT
          CALL abor1_ftn (" roms2jedi_state: Cannot find option for field: "// &
                          TRIM(field%name))

      END SELECT

      IF (LdebugModel) THEN
        CALL field%stats (fstats)
        IF (my_comm%rank() .eq. 0)                                             &
          PRINT 20, field%metadata%getval_name, field%metadata%io_name,        &
                    fstats(1), fstats(2), INT(fstats(3),KIND=8)
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

  10 FORMAT (2x,a,', Nfields = ',i2,', timestep = ',i5.5,',timelevel = ',i0,   &
             ', date: ',a)
  20 FORMAT (19x,'- ',a,': ',a,/,22x,'(Min = ',1p,e15.8,' Max = ',1p,e15.8,    &
             ')',t93,'Checksum = ',i0)

END SUBROUTINE roms2jedi_state

! ------------------------------------------------------------------------------

END MODULE roms_model_mod
