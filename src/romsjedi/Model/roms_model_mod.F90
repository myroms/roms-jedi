! (C) Copyright 2017-2021 UCAR
! 
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0. 
! ------------------------------------------------------------------------------
!
!>
!! \brief   Model class to initialize, run, and finalize ROMS nonlinear kernel
!!
!! \details This class includes several routines used by JEDI to take control
!!          on how the nonlinear kernel is initialized, advanced, and terminated.
!!
!! \author  Hernan G. Arango (Rutgers University)
!! \date    September 2021

MODULE roms_model_mod

USE kinds,                      ONLY : kind_real

USE iso_c_binding
USE datetime_mod,               ONLY : datetime, datetime_create, datetime_set
USE duration_mod
USE fckit_configuration_module, ONLY : fckit_configuration
USE fckit_mpi_module,           ONLY : fckit_mpi_comm

USE roms_kernel_mod

USE roms_geom_mod,              ONLY : roms_geom
USE roms_fields_mod,            ONLY : roms_field
USE roms_fieldsutils_mod,       ONLY : roms_date2time
USE roms_state_mod,             ONLY : roms_state

implicit none

PRIVATE

!> Fortran derived type to hold ROMS nodel kernel definition.

TYPE, PUBLIC :: roms_model

  TYPE (fckit_mpi_comm) :: f_comm

  integer :: ng                            ! nested grid number
  integer :: tile                          ! domain parallel partition tile

  integer :: IniRec                        ! initial conditions NetCDF record
  integer :: NghostPoints                  ! number of tile ghost points
  integer :: LBi, UBi, LBj, UBj, LBk, UBk  ! array(i,j,k) allocation bounds
  integer :: N                             ! number of vertical levels

  integer :: IstrR, IendR, JstrR, JendR    ! tile RHO-cell full indices range
  integer :: Istr,  Iend,  Jstr,  Jend     ! computational RHO-indices
  integer :: IstrU, JstrV                  ! computational U- and V-indices

  real(kind=kind_real) :: dt               ! baroclinic timestep size (s)
  real(kind=kind_real) :: time             ! current ROMS time (s)
  real(kind=kind_real) :: RunInterval      ! timestepping interval (s)

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

! Set switch to read ROMS standard input parameter file and allocate and
! initialize (first touch policy) variables and structures. It needs to be
! done once for each simulation. Thus, "ROMS_initialize" overwrites the
! switch with a .FALSE. value when such tasks are compleated.

logical, save :: LsetROMS = .TRUE.

! ------------------------------------------------------------------------------
CONTAINS
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

  !> Get time step duration for YAML file and convert to seconds.  It can be
  !> a single ROMS timestep, dt(ng), as specified in ROMS standard input
  !> script or and integer factor of dt(ng).  

  CALL f_conf%get_or_die ("tstep", string)
  dtYAML = TRIM(string)
  deallocate (string)
  dtJEDI = duration_seconds(dtYAML)

  !> Set ROMS initial conditions NetCDF filename and record.

  IF (f_conf%has("initial condition")) THEN
    IF (.not.f_conf%get("fields_dir", directory)) THEN
      CALL abor1_ftn ("roms_model::create - Cannot find: "//                 &
                      '''initial condition.fields_dir''')
    END IF

    IF (.not.f_conf%get("initial condition.fields_filename", filename)) THEN
      CALL abor1_ftn ("roms_model::create - Cannot find: "//                 &
                      '''initial condition.fields_filename''')
    END IF
    self%roms_IniName = TRIM(directory)//TRIM(filename)

    IF (.not.f_conf%get("initial condition.fields_record", IniRec)) THEN
      CALL abor1_ftn ("roms_model::create - Cannot find: "//                 &
                      '''initial condition.fields_record''')
    END IF
    self%IniRec = IniRec
  END IF

  !> Set ROMS time integration interval.

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

  self%N   = geom%N                     ! number of vertical levels
  self%LBk = 1                          ! lower bound K-dimension
  self%UBk = geom%N                     ! upper bound K-dimension

  self%IstrR = geom%IstrR               ! full range I-starting (RHO-points)
  self%IendR = geom%IendR               ! full range I-ending   (RHO-points)
  self%JstrR = geom%JstrR               ! full range J-starting (RHO-points)
  self%JendR = geom%JendR               ! full range J-ending   (RHO-points)

  self%Istr = geom%Istr                 ! full range I-starting (PSI-, U-points)
  self%Iend = geom%Iend                 ! full range I-ending   (PSI-points)
  self%Jstr = geom%Jstr                 ! full range J-starting (PSI-, V-points)
  self%Jend = geom%Jend                 ! full range J-ending   (PSI-points)

  self%IstrU = geom%IstrU               ! computational I-starting (U-points)
  self%JstrV = geom%JstrV               ! computational J-starting (V-points)

END SUBROUTINE roms_model_create

! ------------------------------------------------------------------------------
!> Destroys ROMS NLM kernel object.

SUBROUTINE roms_model_delete (self)

  USE mod_arrays, ONLY : ROMS_deallocate_arrays

  CLASS (roms_model), intent(inout) :: self

  !> Deallocates ROMS state arrays and vectors.

  CALL ROMS_deallocate_arrays

  !> Turn on ROMS allocate/initialize switch for next JEDI tasks, if any.
  !> Unit tests perform several sequential and independent tasks.

  LsetROMS = .TRUE.

END SUBROUTINE roms_model_delete

! ------------------------------------------------------------------------------
!> Initializes ROMS NLM model kernel.  We cannot use 'ROMS_initialize' here
!! because it is specific to a particular algorithm.  We need a generic JEDI
!! initialization of ROMS with using the state object.

SUBROUTINE roms_model_initialize (self, state)

  USE mod_param,   ONLY : BOUNDS, Ngrids, iNLM
  USE mod_ncparam, ONLY : inp_lib, io_nf90, io_pio
  USE mod_scalars, ONLY : NoError, exit_flag, time

  CLASS (roms_model), intent(inout) :: self
  CLASS (roms_state), intent(in   ) :: state

  TYPE (roms_field), pointer        :: field
  TYPE (datetime)                   :: Fdatetime
  integer                           :: LocalPET, MyComm, Tindex
  integer                           :: i, ng
  real (kind=kind_real)             :: romsDateNumber, romstime(Ngrids)
  character (len=6), dimension(5)   :: extra_vars
  character (len=256)               :: text

  !> Get MPI communicator and PET rank. Get nested grid number.

  MyComm   = self%f_comm%communicator()
  LocalPET = self%f_comm%rank()
  ng       = self%ng

  !> ROMS-JEDI phase 1 initialization. Read in standard input parameters. Then,
  !> allocate/initialize parameters and variables. Set stepping parameters.

  IF (allocated(BOUNDS)) LsetROMS = .FALSE.

  CALL ROMS_initialize (LsetROMS,                                            &
                        mpiCOMM = MyComm,                                    &
                        kernel  = iNLM)
  IF (exit_flag .ne. NoError) THEN
    CALL abor1_ftn ("roms_model::initialize: Error in ROMS_initialize")
  END IF

  !> Get initial state date-time and over-write ROMS time.

  IF (allocated(state%fields(1)%DateTimeString)) THEN
    CALL datetime_create (state%fields(1)%DateTimeString, Fdatetime)
    CALL roms_date2time (LocalPET, Fdatetime, romsTime(ng), romsDateNumber)
    time(ng) = romsTime(ng)
  END IF

  !> Load JEDI initial state fields into ROMS NLM arrays.

  Tindex = nnew(ng)                                  !> timestep index

  DO i=1, SIZE(state%fields)
    field => state%fields(i)
    SELECT CASE (field%name)
      CASE ('ssh')                                   !> free-surface
        OCEAN(ng)%zeta(:,:,Tindex) = field%val(:,:,1)
      CASE ('uocn')                                  !> 3D U-momentum component
        OCEAN(ng)%u(:,:,:,Tindex) = field%val
      CASE ('vocn')                                  !> 3D V-momentum component
        OCEAN(ng)%v(:,:,:,Tindex) = field%val
      CASE ('tocn')                                  !> potential temperature
        OCEAN(ng)%t(:,:,:,Tindex,itemp) = field%val
      CASE ('socn')                                  !> salinity
        OCEAN(ng)%t(:,:,:,Tindex,isalt) = field%val
    END SELECT
  END DO

  !> Read in additional ROMS initial fields that are not part of the control
  !> state like barotropic momentum components (ubar, vbar) and vertical
  !> diffusion (AKt, AKs) and vicosity (AKv) coefficients from the turbulent
  !> closure parameterizions, if found in the ROMS initial NetCDF file.
  !> Notice that in sequential data assimilation cycles (time windows), the
  !> AKt, AKs, and AKV values, from the privious cycle, are needed in the
  !> prior to avoid spourious jumps in the trajectory due to ROMS three-time
  !> level predictor/corrector timestepping algorithm.

  extra_vars(1) = 'u2docn'        ! vertically-integrated U-velocity
  extra_vars(2) = 'v2docn'        ! vertically-integrated V-velocity
  extra_vars(3) = 'Ktocn '        ! temperature vertical diffusion coefficient
  extra_vars(4) = 'Ksocn '        ! salinity vertical diffusion coefficient
  extra_vars(5) = 'Kvocn '        ! vertical viscosity coefficient

  SELECT CASE (inp_lib)

    CASE (io_nf90)

      CALL state%read_extrafields_nf90 (field%InpRec, Tindex, extra_vars,    &
                                        TRIM(field%InpNCname),               &
                                        TRIM(field%DateTimeString),          &
                                        field%DateNumber)
#if defined PIO_LIB
    CASE (io_pio)
      CALL state%read_extrafields_pio (field%InpRec, Tindex, extra_vars,     &
                                       TRIM(field%InpNCname),                &
                                       TRIM(field%DateTimeString),           &
                                       field%DateNumber)
#endif

    CASE DEFAULT
      WRITE (text,'(a,i0)')                                                  &
                  'roms_model::initialize: Ilegal input type, io_type = ',   &
                  inp_lib
      CALL abor1_ftn (TRIM(text))

  END SELECT

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

  USE mod_grid
  USE mod_coupling
  USE mod_ocean

  USE dateclock_mod, ONLY : time_iso8601
  USE mod_scalars,   ONLY : NoError, exit_flag, time, time_code
  USE mod_stepping,  ONLY : nnew

  CLASS (roms_model), intent(inout) :: self    !< ROMS NLM object
  CLASS (roms_state), intent(inout) :: state   !< State fields object
  TYPE (roms_geom),   intent(inout) :: geom    !< geometry object
  TYPE (datetime),    intent(inout) :: vdate   !< Valid datetime after step

  TYPE (roms_field), pointer        :: field
  integer                           :: i, indx, j, k, ng

  !> Advance ROMS NLM kernel for the specified RunInterval in seconds.
  !> It needs to be a multiple of the baroclinic timestep.

  CALL ROMS_run (self%RunInterval, kernel=iNLM)
  IF (exit_flag .ne. NoError) THEN
    CALL abor1_ftn ("roms_model::step Error while calling ROMS_run")
  END IF

  !> Update state fields with current ROMS NLM values.

  ng = self%ng
  indx = nnew(ng)                                    !> timestep index

  DO i=1, SIZE(state%fields)
    field => state%fields(i)
    SELECT CASE (field%name)
      CASE ('ssh')                                   !> free-surface
        field%val(:,:,1) = COUPLING(ng)%Zt_avg1
      CASE ('uocn')                                  !> 3D U-momentum component
        field%val = OCEAN(ng)%u(:,:,:,indx)
      CASE ('vocn')                                  !> 3D V-momentum component
        field%val = OCEAN(ng)%v(:,:,:,indx)
      CASE ('tocn')                                  !> potential temperature
        field%val = OCEAN(ng)%t(:,:,:,indx, itemp)
      CASE ('socn')                                  !> salinity
        field%val = OCEAN(ng)%t(:,:,:,indx, isalt)
    END SELECT
  END DO

  !> Update geometry time-dependent variables: depths (m; negative).

  geom%z_r = GRID(ng)%z_r
  geom%z_w = GRID(ng)%z_w

  DO k=1,geom%N
    DO j=geom%Jstr-1,geom%Jend+1
      DO i=geom%IstrU-1,geom%Iend+1
        geom%z_u(i,j,k) = 0.5_kind_real*(geom%z_r(i-1,j,k)+geom%z_r(i,j,k))
      END DO
    END DO
    DO j=geom%JstrV-1,geom%Jend+1
      DO i=geom%Istr-1,geom%Iend+1
        geom%z_v(i,j,k) = 0.5_kind_real*(geom%z_r(i,j-1,k)+geom%z_r(i,j,k))
      END DO
    END DO
  END DO

  !> Set valid datetime after step.

  self%time = time(ng)
  self%roms_datetime = time_code(ng)
  CALL time_iso8601 (self%time, self%iso_datetime)
  CALL datetime_set (self%iso_datetime, vdate)

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

END MODULE roms_model_mod
