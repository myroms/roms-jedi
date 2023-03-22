! (C) Copyright 2017-2023 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
!>
!! \brief   Field/Fields class utility for ROMS state vector
!!
!! \details This utility includes several routines used to compute statistics
!!          for a given field, analytical initialization of state vector at
!!          spedified coordinates, and support routines to create, read, and
!!          write files using the standard NetCDF and or the Parallel IO (PIO)
!!          libraries.
!!
!! \author  Hernan G. Arango (Rutgers University)
!! \date    June 2021

MODULE roms_fieldsutils_mod

USE fckit_configuration_module, ONLY : fckit_configuration
USE fckit_log_module,           ONLY : fckit_log
USE datetime_mod,               ONLY : datetime,                             &
                                       datetime_to_string,                   &
                                       datetime_to_yyyymmddhhmmss,           &
                                       datetime_create,                      &
                                       datetime_diff
USE duration_mod,               ONLY : duration,                             &
                                       duration_to_string
USE kinds,                      ONLY : kind_real

USE roms_fields_metadata_mod,   ONLY : roms_field_metadata

implicit none

PRIVATE

PUBLIC  :: ana_fields
PUBLIC  :: date2string
PUBLIC  :: DetectError
PUBLIC  :: field_info
PUBLIC  :: nc_err
PUBLIC  :: roms_close_ncfile
PUBLIC  :: roms_create_ncfile
PUBLIC  :: roms_date2time
PUBLIC  :: roms_gen_filename
PUBLIC  :: roms_tracer_index

PRIVATE :: roms_create_ncfile_nf90
PRIVATE :: roms_def_info_nf90
PRIVATE :: roms_wrt_info_nf90

#if defined PIO_LIB
PRIVATE :: roms_create_ncfile_pio
PRIVATE :: roms_def_info_pio
PRIVATE :: roms_wrt_info_pio
#endif

INTERFACE field_info
  MODULE PROCEDURE field_info3d, field_info2d
END INTERFACE field_info

logical,  parameter :: LdebugFieldUtils = .FALSE.

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
!> Analytical field initialization at coordinate (lon,lat,z). It is primarily
!> used to test horizontal and vertical interpolations.

FUNCTION ana_fields (name, mask, lon, lat, z, h, Tb, Sb, Ub, Vb)               &
             RESULT (value)

  USE erf_mod, ONLY : erf                      !< ROMS Error Function, ERF(x)

  real (kind=kind_real), intent(in) :: mask    !< land=0, ocean=1
  real (kind=kind_real), intent(in) :: lon     !< longitude (degree_east)  
  real (kind=kind_real), intent(in) :: lat     !< latitude (degree_north)
  real (kind=kind_real), intent(in) :: z       !< depth (m; negative)
  real (kind=kind_real), intent(in) :: h       !< bathymetry (m; positive)
  character (len=*),     intent(in) :: name    !< field name

  real (kind=kind_real), intent(in), optional :: Tb  !< background temperature
  real (kind=kind_real), intent(in), optional :: Sb  !< background salinity
  real (kind=kind_real), intent(in), optional :: Ub  !< background U-velocity
  real (kind=kind_real), intent(in), optional :: Vb  !< background V-velocity


  real (kind=kind_real)            :: value    !< returned anlytical value

  real (kind=kind_real), parameter :: pi = 3.14159265358979323846   
  real (kind=kind_real), parameter :: deg2rad = pi/180.0_kind_real

  real (kind=kind_real)            :: T0, S0, U0, V0, Tcoef, Scoef
  real (kind=kind_real)            :: dscale, f, g, omega
  real (kind=kind_real)            :: fac1, fac2, fac3

  ! Set bacground temperature (C), salinity, U-velocity (m/s), and V-velocity
  ! (m/s). If the optional arguments are present, overwrite default values with
  ! the ones specified in the YAML file ('analytic init.T0', 'analytic init.S0',
  ! 'analytic.init.U0', and 'analytic init.V0').

  T0 = 25.0_kind_real         ! potential temperature (C)
  S0 = 32.5_kind_real         ! practical salinity (nondimensional)
  U0 = 1.2_kind_real          ! zonal velocity (m/s)
  V0 = 0.7_kind_real          ! meridional velocity (m/s)

  IF (PRESENT(Tb)) T0 = Tb    ! If present, use values from YAML file
  IF (PRESENT(Sb)) S0 = Sb
  IF (PRESENT(Ub)) U0 = Ub
  IF (PRESENT(Vb)) V0 = Vb

  ! Initialize
 
  Tcoef  = 1.0E-4           ! thermal expansion coefficient (1/C)
  Scoef  = 7.6E-4           ! saline contraction coefficient
  omega  = 7.2921E-5        ! Earth rotation (rad/s)
  dscale = 80.0_kind_real   ! dynamic scale
  g      = 9.81_kind_real   ! acceleration due to gravity (m/s2)

  f      = 2.0_kind_real*omega*SIN(lat*deg2rad)   ! Coriolis parameter (1/s)

  ! Analytical initialization.

  SELECT CASE (TRIM(name))
    CASE ('tocn', 'ptocn',                                                     &
          'sea_water_temperature',                                             &
          'sea_water_potential_temperature',                                   &
          'sst', 'SST',                                                        &
          'sea_surface_temperature',                                           &
          'sea_surface_skin_temperature')
      fac1=COS(lon*deg2rad)*COS(lat*deg2rad)/dscale
      fac2=-0.5_kind_real*U0*dscale*f*SQRT(pi)/(Tcoef*g*h)
      fac3=(fac2*erf(fac1)+T0)*(1.0_kind_real+z/h)
      value=fac3*mask
    CASE ('socn',                                                              &
          'sea_water_practical_salinity',                                      &
          'sea_water_salinity',                                                &
          'sss', 'SSS',                                                        &
          'sea_surface_salinity')
      fac1=COS(lon*deg2rad)*COS(lat*deg2rad)/dscale
      fac2=-0.5*U0*dscale*f*SQRT(pi)/(Scoef*g*h)
      fac3=S0+(0.03_kind_real*fac1/fac2)*(2.0_kind_real-EXP(z/500.0_kind_real))
      value=fac3*mask
    CASE ('uocn',                                                              &
          'eastward_sea_water_velocity',                                       &
          'sea_water_x_velocity',                                              &
          'usur', 'Usur',                                                      &
          'surface_eastward_sea_water_velocity',                               &
          'sea_water_surface_x_velocity')
      fac1=SIN(lon*deg2rad)*COS(lat*deg2rad)/dscale
      fac2=z/h
      fac3=U0*(0.5_kind_real+fac2+(0.5*fac2*fac2))*EXP(-fac1*fac1)
      value=fac3*mask
    CASE ('vocn',                                                              &
          'northward_sea_water_velocity',                                      &
          'sea_water_y_velocity',                                              &
          'vsur', 'Vsur',                                                      &
          'surface_northward_sea_water_velocity',                              &
          'sea_water_surface_y_velocity')
      fac1=COS(lon*deg2rad)*SIN(lat*deg2rad)/dscale
      fac2=z/h
      fac3=-V0*(0.5_kind_real+fac2+(0.5*fac2*fac2))*EXP(-fac1*fac1)
      value=fac3*mask
    CASE ('ssh', 'SSH',                                                        &
          'sea_surface_height_above_geoid',                                    &
          'sea_surface_height_above_geopotential_datum')
      fac1=COS(lon*deg2rad)*SIN(lat*deg2rad)/dscale
      fac2=-U0*dscale*f*SQRT(pi)/(12.0_kind_real*g)
      fac3=1.0E+5*fac2*erf(fac1);
      value=fac3*mask
    CASE ('hocn',                                                              &
          'bathymetry',                                                        &
          'sea_floor_depth_below_sea_surface',                                 &
          'sea_floor_depth')
      value=h
    CASE ('zocn_r',                                                            &
          'model_level_depth_at_cell_center',                                  &
          'ocean_depth',                                                       &
          'level_depth')
      value=z
    CASE ('zocn_w',                                                            &
          'model_level_depth_at_cell_top_face')
      value=z
  END SELECT

END FUNCTION ana_fields

! ------------------------------------------------------------------------------
!> It converts date/time object to string.

SUBROUTINE date2string (vdate, DateString, ISO)

  TYPE (datetime),   intent(in ) :: vdate       !< Date/Time object
  character (len=*), intent(out) :: DateString  !< calling routine
  logical, optional, intent(in ) :: ISO         !< ISO8601 format

  integer                        :: is
 
  ! Convert date/time object to ISO8601 string.

  CALL datetime_to_string (vdate, DateString)

  ! If applicable, convert string to 'YYYY-MM-DD hh:mm:ss' format.

  IF (PRESENT(ISO)) THEN
    IF (.not.ISO) THEN
      is=INDEX(DateString, 'T')
      IF (is.gt.0) DateString(is:is) = CHAR(32)   ! replace 'T' with blank

      is=INDEX(DateString, 'Z')
      IF (is.gt.0) DateString(is:is) = CHAR(32)   ! replace 'Z' with blank
    END IF
  END IF

END SUBROUTINE date2string

! ------------------------------------------------------------------------------
!> If error is detected, create error message for aborting routine.

FUNCTION DetectError (ErrFlag, NoErr, line, routine, Message)                  &
              RESULT (GotErr)

  integer,           intent(in ) :: ErrFlag   !< returned error flag
  integer,           intent(in ) :: NoErr     !< value for no error
  integer,           intent(in ) :: line      !< calling routine line number
  character (len=*), intent(in ) :: routine   !< calling routine
  character (len=*), intent(out) :: Message   !< error message to abort routine

  logical                        :: GotErr

  ! If found error, set error message.

  IF (ErrFlag.ne.NoErr) THEN
    WRITE (Message,10) '*** Found error: ', ErrFlag,                           &
                       'Line: ', line,                                         &
                       'Source: ', routine
    GotErr  = .TRUE.
  ELSE
    Message = ' '
    GotErr  = .FALSE.
  END IF

  10  FORMAT (a,i0,2x,a,i0,2x,a,a)

END FUNCTION DetectError

! ------------------------------------------------------------------------------
!> Computes statistics for a tiled 2D field. Global reduction is done elsewhere.

SUBROUTINE field_info2d (fld, mask, info)

  real (kind=kind_real), intent(in ) :: fld(:,:)    !< 2D field values
  logical,               intent(in ) :: mask(:,:)   !< field mask
  real (kind=kind_real), intent(out) :: info(3)     !< [MIN, MAX, SUM]

  info(1) = MINVAL(fld, MASK=mask)
  info(2) = MAXVAL(fld, MASK=mask)
  info(3) = SUM   (fld, MASK=mask)

END SUBROUTINE field_info2d

! ------------------------------------------------------------------------------
!> Computes statistics for a tiled 3D field. Global reduction is done elsewhere.

SUBROUTINE field_info3d (fld, mask, info)

  real (kind=kind_real), intent(in ) :: fld(:,:,:)  !< 3D field values
  logical,               intent(in ) :: mask(:,:)   !< field mask
  real (kind=kind_real), intent(out) :: info(3)     !< [MIN, MAX, SUM]

  integer                            :: k
  real (kind=kind_real)              :: buffer(3,size(fld, dim=3))

  ! Calculate the min/max/sum separately for each masked level.

  DO k = 1, SIZE(buffer, dim=2)
    buffer(1,k) = MINVAL(fld(:,:,k), MASK=mask)
    buffer(2,k) = MAXVAL(fld(:,:,k), MASK=mask)
    buffer(3,k) = SUM   (fld(:,:,k), MASK=mask) / SIZE(fld, dim=3)
  END DO

  ! Then, combine the min/max/sum over all levels

  info(1) = MINVAL(buffer(1,:))
  info(2) = MAXVAL(buffer(2,:))
  info(3) = SUM   (buffer(3,:))

END SUBROUTINE field_info3d

! ------------------------------------------------------------------------------
!> Check returned error code from the NetCDF or PIO library.

SUBROUTINE nc_err (status, NoErr, iotype, line, routine)

  USE mod_ncparam, ONLY : io_nf90, io_pio
  USE mod_scalars, ONLY : NoError, exit_flag
  USE netcdf,      ONLY : nf90_strerror

  integer,           intent(in) :: status    !< returned error code
  integer,           intent(in) :: NoErr     !< Netcdf value for no error
  integer,           intent(in) :: iotype    !< IO library type 
  integer,           intent(in) :: line      !< calling routine line number
  character (len=*), intent(in) :: routine   !< calling routine

  character (len=1024)          :: text

  SELECT CASE (iotype)
    CASE (io_nf90)
      IF ((status.ne.NoErr).or.(exit_flag.ne.NoError)) THEN
        WRITE (text,10) '*** Found error: ', status,                           &
                        'Line: ', line,                                        &
                        'Source: ', TRIM(routine),                             &
                        TRIM(nf90_strerror(status))
        CALL abor1_ftn (TRIM(text))
      END IF
    CASE (io_pio)
      IF ((status.ne.NoErr).or.(exit_flag.ne.NoError)) THEN
        WRITE (text,20) '*** Found error: ', status,                           &
                        'Line: ', line,                                        &
                        'Source: ', TRIM(routine)
        CALL abor1_ftn (TRIM(text))
      END IF
  END SELECT

  10  FORMAT (a,i0,2x,a,i0,2x,a,a,2x,a)
  20  FORMAT (a,i0,3x,a,i0,3x,a,a)

END SUBROUTINE nc_err

! ------------------------------------------------------------------------------
!> Converts JEDI ISO8601 date-time to ROMS time in seconds since reference-time
!> and Matlab datenum (origin 0000-00-00 00:00:00) in days.

SUBROUTINE roms_date2time (LocalPET, vdate, romsTime, romsDateNumber)

  USE dateclock_mod, ONLY : datenum            !< from ROMS time management
  USE mod_scalars,   ONLY : Rclock, time_ref   !< ROMS reference time structure

  integer,               intent(in ) :: localPET         !< PET rank
  TYPE (datetime),       intent(in ) :: vdate            !< JEDI Date/Time
  real (kind=kind_real), intent(out) :: romsTime         !< ROMS time
  real (kind=kind_real), intent(out) :: romsDateNumber   !< Matlab datenum

  integer                            :: year, month, day, hour, minute, iseconds
  real (kind=kind_real)              :: myDateNumber(2), seconds
  character (len=120)                :: CurrentDateString

  ! Convert ISO8601 date-time to ROMS time and date number.

  CALL datetime_to_string (vdate, CurrentDateString)
  CALL datetime_to_yyyymmddhhmmss (vdate,                                      &
                                   year, month, day, hour, minute, iseconds)
  seconds = REAL(iseconds, kind_real)  
  CALL datenum (myDateNumber, year, month, day, hour, minute, seconds)

  ! Compute ROMS time as elapsed seconds from reference date.

  romsTime = myDateNumber(2)-Rclock%DateNumber(2)

  ! ROMS allows both Proleptic Julian Calendar (origin Nov 24, 4713 BC) and
  ! Gregorian (Proleptic or not) Calendar adjuted to Matlab origin of
  ! 0000-00-00 00:00:00, datenum(0,0,0)=0, for consistence.
   
  IF (INT(time_ref).eq.-2) THEN                           ! Julian Calendar
    romsDateNumber = myDateNumber(1)- 1721059.0_kind_real
  ELSE
    romsDateNumber = myDateNumber(1)                      ! Gregorian Calendar
  END IF

  IF (LdebugFieldUtils .and. (LocalPET .eq. 0)) THEN
    PRINT '(a,a)',             'Reference Date:      ', TRIM(Rclock%string)
    PRINT '(a,a)',             'Current Date:        ', TRIM(CurrentDateString)
    PRINT '(a,5(i0,1x),f7.4)', 'YYYY MM DD hh mm ss: ', year,month,day,hour,   &
                                                        minute,seconds
    PRINT '(a,a)',             'Calendar:            ', TRIM(Rclock%Calendar)
    PRINT '(a,f0.4)',          'Reference datenum:   ', Rclock%DateNumber(1)
    PRINT '(a,f0.4)',          'Matlab datenum:      ', romsDateNumber
    PRINT '(a,f0.4)',          'ROMS time (days):    ', romsTime/86400.0
    PRINT '(a,f0.4)',          'ROMS time (seconds): ', romsTime
  END IF

END SUBROUTINE roms_date2time

! ------------------------------------------------------------------------------
!> Generates filename based on the date and time.

FUNCTION roms_gen_filename (f_conf, max_length, vdate, file_type)              &
                    RESULT (filename)

  USE strings_mod, ONLY : uppercase

  TYPE (fckit_configuration),  intent(in) :: f_conf     !< configuration
  integer,                     intent(in) :: max_length !< string length
  TYPE (datetime),             intent(in) :: vdate      !< Date/Time
  character (len=*), optional, intent(in) :: file_type  !< file type or purpose

  TYPE (datetime)                         :: rdate
  TYPE (duration)                         :: step

  logical                                 :: IsEnsemble
  integer                                 :: year, month, day
  integer                                 :: hour, minute, seconds
  integer                                 :: ensemble_number, lstr
  character (len=3)                       :: Enumber
  character (len=19)                      :: filedate
  character (len=max_length)              :: filename 
  character (len=max_length)              :: MyPrefix, StepString, ValidityDate
  character (len=:), allocatable          :: Fdir, Fexp, Fprefix, Ftype, iniDate


  ! Inquire configuration YAML file about the output directory, file prefix,
  ! file type, and application date

  IF (.not.f_conf%get("data_dir", Fdir)) THEN
    CALL abor1_ftn ("roms_gen_filename: Cannot find 'data_dir'"//              &
                    " in YAML configuration")
  END IF

  IF (.not.f_conf%get("prefix", Fprefix)) THEN
    CALL abor1_ftn ("roms_gen_filename: Cannot find 'prefix'"//                &
                    " in YAML configuration")
  END IF

  IF (.not.f_conf%get("exp", Fexp)) THEN
    CALL abor1_ftn ("roms_gen_filename: Cannot find 'exp'"//                   &
                    " in YAML configuration")
  END IF

  IF (.not.f_conf%get("type", Ftype)) THEN
    CALL abor1_ftn ("roms_gen_filename: Cannot find 'type'"//                  &
                    " in YAML configuration")
  END IF

  IF (INDEX(uppercase(Ftype), 'MEM').gt.0) THEN
    IF (.not.f_conf%get("member", ensemble_number)) THEN
      CALL abor1_ftn ("roms_gen_filename: Cannot find 'member'"//              &
                      " in 'f_conf' object")
    END IF
    IsEnsemble = .TRUE.
    WRITE (Enumber, '(i3.3)') ensemble_number
  ELSE
    IsEnsemble = .FALSE.
  END IF

  IF (.not.f_conf%get("date", iniDate)) THEN
    CALL abor1_ftn ("roms_gen_filename: Cannot find 'date'"//                  &
                    " in YAML configuration")
  END IF

  ! Set filename prefix. Here, CHAR(47) = forward slash (/).

  lstr = LEN_TRIM(Fdir)
  IF (Fdir(lstr:lstr) .eq. CHAR(47) ) THEN
    MyPrefix = Fdir // Fprefix // '_' // Fexp // '_' // Ftype
  ELSE
    MyPrefix = Fdir // CHAR(47) // Fprefix // '_' // Fexp // '_' // Ftype
  END IF

  ! If ensemble file, attach ensemble number descriptor.

  IF (IsEnsemble) THEN
    MyPrefix = TRIM(MyPrefix) // Enumber
  END IF

  ! Get information from vdate structure.

  CALL datetime_to_string (vdate, ValidityDate)
  CALL datetime_create    (iniDate, rdate)         ! initial date
  CALL datetime_diff      (vdate, rdate, step)     ! time since initial date
  CALL duration_to_string (step, StepString)

  CALL datetime_to_yyyymmddhhmmss (vdate,                                      &
                                   year, month, day, hour, minute, seconds)

  ! Generate filename: <DirPath>/<Prefix>_<Type>_YYYY-MM-DD-hh.mm.ss.nc

  WRITE (filedate,10) year, month, day, hour, minute, seconds

  filename = TRIM(MyPrefix) // '_' // TRIM(filedate) // '.nc'

  IF (LdebugFieldUtils) THEN  
    PRINT '(a)',   '------------------'
    PRINT '(a,a)', 'Initial Date   = ', TRIM(iniDate)
    PRINT '(a,a)', 'Validity Date  = ', TRIM(ValidityDate)
    PRINT '(a,a)', 'Step String    = ', TRIM(StepString)
    PRINT '(a,a)', 'Directory Path = ', TRIM(Fdir)
    PRINT '(a,a)', 'File Prefix    = ', TRIM(Fprefix)
    PRINT '(a,a)', 'File Type      = ', TRIM(Ftype)
    PRINT '(a,a)', 'Experiment     = ', TRIM(Fexp)
    PRINT '(a,a)', 'Filename       = ', TRIM(filename)
  END IF

  ! Deallocate

  IF ( allocated(Fdir) )    deallocate (Fdir)
  IF ( allocated(Fexp) )    deallocate (Fexp)
  IF ( allocated(Fprefix) ) deallocate (Fprefix)
  IF ( allocated(Ftype) )   deallocate (Ftype)
  IF ( allocated(iniDate) ) deallocate (iniDate)

  10  FORMAT (i4,'-',i2.2,'-',i2.2,'-',i2.2,'.',i2.2,'.',i2.2)

END FUNCTION roms_gen_filename

! ------------------------------------------------------------------------------
!> It set ROMS tracer index from ROMS-JEDI internal metadata name.

FUNCTION roms_tracer_index (name) RESULT (tracer_index)

  USE mod_scalars, ONLY : itemp, isalt

  character (len=*), intent(in) :: name

  integer                       :: tracer_index    !< returned value
  character (len=1024)          :: Message

  ! Set ROMS tracer-type variable and diffusion array index.

  SELECT CASE (TRIM(name))
    CASE ('tocn', 'Ktocn')                 !< potential temperature
      tracer_index = itemp
    CASE ('socn', 'Ksocn')                 !< salinity
      tracer_index = isalt
    CASE DEFAULT
      WRITE (Message,'(2a)')                                                   &
            'roms_tracer_index: Cannot find an option for tracer variable: ',  &
            TRIM(name)
      CALL abor1_ftn (TRIM(Message))
  END SELECT

END FUNCTION roms_tracer_index

! ------------------------------------------------------------------------------
!> Closes state NetCDF file from IO structure.

SUBROUTINE roms_close_ncfile (ng, model, S)

  USE mod_iounits,    ONLY : T_IO
  USE mod_ncparam,    ONLY : io_nf90, io_pio
  USE mod_netcdf,     ONLY : netcdf_close
#if defined PIO_LIB
  USE mod_pio_netcdf, ONLY : pio_netcdf_close
#endif

  integer,      intent(in   ) :: ng                !< nested grid number
  integer,      intent(in   ) :: model             !< ROMS numerical kernel
  TYPE (T_IO),  intent(inout) :: S(:)              !< ROMS I/O structure

  logical,          parameter :: Lupdate = .FALSE.
  integer,          parameter :: ClosedState = -1

  SELECT CASE (S(ng)%IOtype)

    CASE (io_nf90)
      IF (S(ng)%ncid .ne. ClosedState) THEN
        CALL netcdf_close (ng, model, S(ng)%ncid, S(ng)%name, Lupdate)
      END IF

#if defined PIO_LIB
    CASE (io_pio)
      IF (associated(S(ng)%pioFile%iosystem) THEN
        IF (S(ng)%File%fh .ne. ClosedState) THEN
          CALL pio_netcdf_close (ng, model, S(ng)%pioFile, S(ng)%name, Lupdate)
        END IF
      END IF
#endif

  END SELECT

END SUBROUTINE roms_close_ncfile

! ------------------------------------------------------------------------------
!> Creates output state NetCDF file.

SUBROUTINE roms_create_ncfile (ng, model, LocalPET, S, metadata)

  USE mod_iounits, ONLY : T_IO
  USE mod_ncparam, ONLY : io_nf90, io_pio

  integer,                    intent(in   ) :: ng          !< nested grid number
  integer,                    intent(in   ) :: model       !< numerical kernel
  integer,                    intent(in   ) :: LocalPET    !< PET rank
  TYPE (T_IO),                intent(inout) :: S(:)        !< ROMS I/O structure
  TYPE (roms_field_metadata), intent(in   ) :: metadata(:) !< field Metadata

  character (len=256)         :: text

  SELECT CASE (S(ng)%IOtype)

    CASE (io_nf90)
      CALL roms_create_ncfile_nf90 (ng, model, LocalPET, S, metadata)

#if defined PIO_LIB
    CASE (io_pio)
      CALL roms_create_ncfile_pio (ng, model, LocalPET, S, metadata)
#endif

    CASE DEFAULT
      WRITE (text,'(a,i0)') &
                  'roms_create_ncfile: Ilegal output type, io_type = ',        &
                  S(ng)%IOtype
      CALL abor1_ftn (TRIM(text))

  END SELECT

END SUBROUTINE roms_create_ncfile

! ------------------------------------------------------------------------------
!> Creates output state file using the standard NetCDF library.

SUBROUTINE roms_create_ncfile_nf90 (ng, model, LocalPET, S, metadata)

  USE mod_param
  USE mod_parallel
  USE mod_ncparam
  USE mod_netcdf
  USE mod_scalars

  USE mod_iounits,  ONLY : T_IO
  USE def_dim_mod,  ONLY : def_dim
  USE def_info_mod, ONLY : def_info
  USE def_var_mod,  ONLY : def_var
  USE wrt_info_mod, ONLY : wrt_info

  integer,                    intent(in   ) :: ng          !< nested grid number
  integer,                    intent(in   ) :: model       !< numerical kernel
  integer,                    intent(in   ) :: LocalPET    !< PET rank
  TYPE (T_IO),                intent(inout) :: S(:)        !< ROMS I/O structure
  TYPE (roms_field_metadata), intent(in   ) :: metadata(:) !< field Metadata

  integer                      :: i, itrc
  integer                      :: DimIDs(nDimID)
  integer                      :: r2dgrd(3), u2dgrd(3), v2dgrd(3)
  integer                      :: r3dgrd(4), u3dgrd(4), v3dgrd(4)
  real (kind=kind_real)        :: Aval(6)
  character (len=120)          :: Vinfo(25)
  character (len=256)          :: ncname
  character (len=1024)         :: Message

  character (len=*), parameter :: MyFile =                                     &
     __FILE__//", roms_create_ncfile_nf90"

  ! Initialize

  DimIDs = 0
  Aval   = 0.0_kind_real
  Vinfo  = CHAR(32)                !> blank space

  ncname = S(ng)%name

  ! Create NetCDF file.

  CALL netcdf_create (ng, model, TRIM(ncname), S(ng)%ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  ! Define file dimensions.

  CALL nc_err (def_dim(ng, model, S(ng)%ncid, ncname, 'xi_rho',                &
                       IOBOUNDS(ng)%xi_rho, DimIDs( 1)),                       &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%ncid, ncname, 'xi_u',                  &
                       IOBOUNDS(ng)%xi_u, DimIDs( 2)),                         &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%ncid, ncname, 'xi_v',                  &
                       IOBOUNDS(ng)%xi_v, DimIDs( 3)),                         &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%ncid, ncname, 'xi_psi',                &
                       IOBOUNDS(ng)%xi_psi, DimIDs( 4)),                       &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%ncid, ncname, 'eta_rho',               &
                       IOBOUNDS(ng)%eta_rho, DimIDs( 5)),                      &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%ncid, ncname, 'eta_u',                 &
                       IOBOUNDS(ng)%eta_u, DimIDs( 6)),                        &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%ncid, ncname, 'eta_v',                 &
                       IOBOUNDS(ng)%eta_v, DimIDs( 7)),                        &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%ncid, ncname, 'N',                     &
                       N(ng), DimIDs( 9)),                                     &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%ncid, ncname, 's_rho',                 &
                       N(ng), DimIDs( 9)),                                     &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%ncid, ncname, 's_w',                   &
                       N(ng)+1, DimIDs(10)),                                   &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%ncid, ncname, 'tracer',                &
                       NT(ng), DimIDs(11)),                                    &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%ncid, ncname,                          &
                       TRIM(ADJUSTL(Vname(5,idtime))),                         &
                       nf90_unlimited, DimIDs(12)),                            &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  ! Set dimension vector for each C-grid location.

  r2dgrd = (/ DimIDs(1), DimIDs(5), DimIDs(12) /)
  u2dgrd = (/ DimIDs(2), DimIDs(6), DimIDs(12) /)
  v2dgrd = (/ DimIDs(3), DimIDs(7), DimIDs(12) /)

  r3dgrd = (/ DimIDs(1), DimIDs(5), DimIDs(9), DimIDs(12) /)
  u3dgrd = (/ DimIDs(2), DimIDs(6), DimIDs(9), DimIDs(12) /) 
  v3dgrd = (/ DimIDs(3), DimIDs(7), DimIDs(9), DimIDs(12) /)

  ! Define time-recordless information variables.

  CALL roms_def_info_nf90 (ng, model, LocalPET, S(ng)%ncid,                    &
                           DimIDs, ncname)

  ! Define model time.

  Vinfo( 1)=Vname(1,idtime)
  Vinfo( 2)=Vname(2,idtime)
  WRITE (Vinfo( 3),'(a,a)') 'seconds since ', TRIM(Rclock%string)
  Vinfo( 4)=TRIM(Rclock%calendar)
  CALL nc_err (def_var(ng, model, S(ng)%ncid, S(ng)%Vid(idtime),               &
                       NF_TOUT, 1, (/DimIDs(12)/), Aval, Vinfo,                &
                       ncname, SetParAccess = .TRUE.),                         &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  ! Define state variables.

  DO i = 1, SIZE(metadata)

    SELECT CASE (metadata(i)%name)

      CASE ('ssh')                             !< free-surface

        Vinfo( 1)=Vname(1,idFsur)
        Vinfo( 2)=Vname(2,idFsur)
        Vinfo(21)=metadata(i)%getval_name
        Vinfo( 3)=Vname(3,idFsur)
        Vinfo(16)=Vname(1,idtime)
        Vinfo(22)='coordinates'
        Aval(5)=REAL(Iinfo(1,idFsur,ng),r8)

        CALL nc_err (def_var(ng, model, S(ng)%ncid, S(ng)%Vid(idFsur),         &
                             NF_FOUT, 3, r2dgrd, Aval, Vinfo, ncname),         &
                     nf90_noerr, io_nf90, __LINE__, MyFile)

      CASE ('u2docn')                          !< 2D U-momentum component

        Vinfo( 1)=Vname(1,idUbar)
        Vinfo( 2)=Vname(2,idUbar)
        Vinfo(21)=metadata(i)%getval_name
        Vinfo( 3)=Vname(3,idUbar)
        Vinfo(16)=Vname(1,idtime)
        Vinfo(22)='coordinates'
        Aval(5)=REAL(Iinfo(1,idUbar,ng),r8)

        CALL nc_err (def_var(ng, model, S(ng)%ncid, S(ng)%Vid(idUbar),         &
                             NF_FOUT, 3, u2dgrd, Aval, Vinfo, ncname),         &
                     nf90_noerr, io_nf90, __LINE__, MyFile)

      CASE ('v2docn')                          !< 2D v-momentum component

        Vinfo( 1)=Vname(1,idVbar)
        Vinfo( 2)=Vname(2,idVbar)
        Vinfo(21)=metadata(i)%getval_name
        Vinfo( 3)=Vname(3,idVbar)
        Vinfo(14)=Vname(4,idVbar)
        Vinfo(16)=Vname(1,idtime)
        Vinfo(22)='coordinates'
        Aval(5)=REAL(Iinfo(1,idVbar,ng),r8)

        CALL nc_err (def_var(ng, model, S(ng)%ncid, S(ng)%Vid(idVbar),         &
                             NF_FOUT, 3, v2dgrd, Aval, Vinfo, ncname),         &
                     nf90_noerr, io_nf90, __LINE__, MyFile)

      CASE ('uocn')                            !< 3D U-momentum component

        Vinfo( 1)=Vname(1,idUvel)
        Vinfo( 2)=Vname(2,idUvel)
        Vinfo(21)=metadata(i)%getval_name
        Vinfo( 3)=Vname(3,idUvel)
        Vinfo(16)=Vname(1,idtime)
        Vinfo(22)='coordinates'
        Aval(5)=REAL(Iinfo(1,idUvel,ng),r8)

        CALL nc_err (def_var(ng, model, S(ng)%ncid, S(ng)%Vid(idUvel),         &
                             NF_FOUT, 4, u3dgrd, Aval, Vinfo, ncname),         &
                     nf90_noerr, io_nf90, __LINE__, MyFile)

      CASE ('vocn')                            !< 3D V-momentum component

        Vinfo( 1)=Vname(1,idVvel)
        Vinfo( 2)=Vname(2,idVvel)
        Vinfo(21)=metadata(i)%getval_name
        Vinfo( 3)=Vname(3,idVvel)
        Vinfo(16)=Vname(1,idtime)
        Vinfo(22)='coordinates'
        Aval(5)=REAL(Iinfo(1,idVvel,ng),r8)

        CALL nc_err (def_var(ng, model, S(ng)%ncid, S(ng)%Vid(idVvel),         &
                             NF_FOUT, 4, v3dgrd, Aval, Vinfo, ncname),         &
                     nf90_noerr, io_nf90, __LINE__, MyFile)

      CASE ('tocn', 'socn')                    !< tracer-type variables

        itrc = roms_tracer_index(metadata(i)%name)
        Vinfo( 1)=Vname(1,idTvar(itrc))
        Vinfo( 2)=Vname(2,idTvar(itrc))
        Vinfo(21)=metadata(i)%getval_name
        Vinfo( 3)=Vname(3,idTvar(itrc))
        Vinfo(16)=Vname(1,idtime)
        Vinfo(22)='coordinates'
        Aval(5)=REAL(r3dvar,r8)

        CALL nc_err (def_var(ng, model, S(ng)%ncid, S(ng)%Tid(itrc),           &
                             NF_FOUT, 4, r3dgrd, Aval, Vinfo, ncname),         &
                     nf90_noerr, io_nf90, __LINE__, MyFile)

      CASE DEFAULT
  
        WRITE (Message,'(4a)')                                                 &
              'roms_create_ncfile::nf90: Cannot find an option to define = ',  &
              metadata(i)%name, " - ", metadata(i)%getval_name
        CALL abor1_ftn (TRIM(Message))

    END SELECT

  END DO

  ! Leave definition mode.

  CALL netcdf_enddef (ng, model, ncname, S(ng)%ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  ! Write out time-recordless, information variables.

  CALL roms_wrt_info_nf90 (ng, model, S(ng)%ncid, ncname)

END SUBROUTINE roms_create_ncfile_nf90

! ------------------------------------------------------------------------------
!> Define NetCDF file global attributes and grid arrays using standard library.

SUBROUTINE roms_def_info_nf90 (ng, model, LocalPET, ncid, DimIDs, ncname)

  USE mod_param
  USE mod_ncparam
  USE mod_netcdf
  USE mod_scalars

  USE def_var_mod,  ONLY : def_var
  USE mod_strings,  ONLY : title

  integer,           intent(in) :: ng              !< nested grid number
  integer,           intent(in) :: model           !< ROMS numerical kernel
  integer,           intent(in) :: LocalPET        !< PET rank
  integer,           intent(in) :: ncid            !< NetCDF file ID
  integer,           intent(in) :: DimIDs(:)       !< NetCDF dimensions IDs
  character (len=*), intent(in) :: ncname          !< NetCDF filename

  integer                       :: status, varid
  integer                       :: r2dgrd(2), u2dgrd(2), v2dgrd(2)
  real (kind=kind_real)         :: Aval(6)
  character (len=120)           :: Vinfo(25)
  character (len=512)           :: text

  character (len=*),  parameter :: MyFile =                                    &
     __FILE__//", roms_def_info_nf90"

  ! Initialize

  Aval   = 0.0_kind_real
  Vinfo  = CHAR(32)                        !> blank space

  ! Set dimension vector for each C-grid location.

  r2dgrd = (/ DimIDs(1), DimIDs(5) /)      !> RHO-points
  u2dgrd = (/ DimIDs(2), DimIDs(6) /)      !> U-points
  v2dgrd = (/ DimIDs(3), DimIDs(7) /)      !> V-points

  ! Define global attributes. They are written by master process
  ! since it is calling NetCDF function 'nf90_put_att' directly in
  ! parallel environment.  Return errors are not checked.

  IF (LocalPET .eq. 0) THEN
    status=nf90_put_att(ncid, nf90_global, 'file',                             &
                        TRIM(ncname))

    status=nf90_put_att(ncid, nf90_global, 'Conventions',                      &
                            'CF-1.4, SGRID-0.3')

    status=nf90_put_att(ncid, nf90_global, 'type',                             &
                        'ROMS-JEDI state fields file')

    status=nf90_put_att(ncid, nf90_global, 'title',                            &
                        TRIM(title))

    status=nf90_put_att(ncid, nf90_global, 'var_info',                         &
                        TRIM(varname))

    status=nf90_put_att(ncid, nf90_global, 'grd_file',                         &
                        TRIM(GRD(ng)%name))

    status=nf90_put_att(ncid, nf90_global, 'script_file',                      &
                        TRIM(Iname))

    WRITE (text,'(i0,a,i0)') NtileI(ng), 'x', NtileJ(ng)
    status=nf90_put_att(ncid, nf90_global, 'tiling',                           &
                        TRIM(text))

    IF (LEN_TRIM(date_str).gt.0) THEN
      WRITE (text,'(a,1x,a,", ",a)') 'ROMS, Version', TRIM(version),           &
                                     TRIM(date_str)
    ELSE
      WRITE (text,'(a,1x,a)') 'ROMS, Version', TRIM(version)
    END IF
    status=nf90_put_att(ncid, nf90_global, 'history',                          &
                        TRIM(text))
  END IF

  ! Define grid variables.

  Vinfo( 1)='spherical'
  Vinfo( 2)='grid type logical switch'
  Vinfo( 9)='Cartesian'
  Vinfo(10)='spherical'
  CALL nc_err (def_var(ng, model, ncid, varid, nf90_int,                       &
                       1, (/0/), Aval, Vinfo, ncname,                          &
                       SetParAccess = .FALSE.),                                &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  ! S-coordinate parameters.

  Vinfo( 1)='Vtransform'
  Vinfo( 2)='vertical terrain-following transformation equation'
  CALL nc_err (def_var(ng, model, ncid, varid, nf90_int,                       &
                       1, (/0/), Aval, Vinfo, ncname,                          &
                       SetParAccess = .FALSE.),                                &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  Vinfo( 1)='Vstretching'
  Vinfo( 2)='vertical terrain-following stretching function'
  CALL nc_err (def_var(ng, model, ncid, varid, nf90_int,                       &
                       1, (/0/), Aval, Vinfo, ncname,                          &
                       SetParAccess = .FALSE.),                                &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  Vinfo( 1)='theta_s'
  Vinfo( 2)='S-coordinate surface control parameter'
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TOUT,                        &
                       1, (/0/), Aval, Vinfo, ncname,                          &
                       SetParAccess = .FALSE.),                                &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  Vinfo( 1)='theta_b'
  Vinfo( 2)='S-coordinate bottom control parameter'
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TOUT,                        &
                       1, (/0/), Aval, Vinfo, ncname,                          &
                       SetParAccess = .FALSE.),                                &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  Vinfo( 1)='Tcline'
  Vinfo( 2)='S-coordinate surface/bottom layer width'
  Vinfo( 3)='meter'
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TOUT,                        &
                       1, (/0/), Aval, Vinfo, ncname,                          &
                       SetParAccess = .FALSE.),                                &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  Vinfo( 1)='hc'
  Vinfo( 2)='S-coordinate parameter, critical depth'
  Vinfo( 3)='meter'
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TOUT,                        &
                       1, (/0/), Aval, Vinfo, ncname,                          &
                       SetParAccess = .FALSE.),                                &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  Vinfo( 1)='grid'
  CALL nc_err (def_var(ng, model, ncid, varid, nf90_int,                       &
                       1, (/0/), Aval, Vinfo, ncname,                          &
                       SetParAccess = .FALSE.),                                &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  ! S-coordinate non-dimensional independent variable at RHO-points.

  Vinfo( 1)='s_rho'
  Vinfo( 2)='S-coordinate at RHO-points'
  Vinfo( 5)='valid_min'
  Vinfo( 6)='valid_max'
  IF (Vtransform(ng).eq.1) THEN
    Vinfo(21)='ocean_s_coordinate_g1'
  ELSE IF (Vtransform(ng).eq.2) THEN
    Vinfo(21)='ocean_s_coordinate_g2'
  END IF
  Vinfo(23)='s: s_rho C: Cs_r eta: zeta depth: h depth_c: hc'
  vinfo(25)='up'
  Aval(2)=-1.0_r8
  Aval(3)=0.0_r8
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TOUT,                        &
                       1, (/DimIDs(9)/), Aval, Vinfo, ncname,                  &
                       SetParAccess = .FALSE.),                                &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  ! S-coordinate non-dimensional independent variable at W-points.

  Vinfo( 1)='s_w'
  Vinfo( 2)='S-coordinate at W-points'
  Vinfo( 5)='valid_min'
  Vinfo( 6)='valid_max'
  Vinfo(21)='ocean_s_coordinate'
  IF (Vtransform(ng).eq.1) THEN
    Vinfo(21)='ocean_s_coordinate_g1'
  ELSE IF (Vtransform(ng).eq.2) THEN
    Vinfo(21)='ocean_s_coordinate_g2'
  END IF
  Vinfo(23)='s: s_w C: Cs_w eta: zeta depth: h depth_c: hc'
  vinfo(25)='up'
  Aval(2)=-1.0_r8
  Aval(3)=0.0_r8
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TOUT,                        &
                       1, (/DimIDs(10)/), Aval, Vinfo, ncname,                 &
                       SetParAccess = .FALSE.),                                &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  ! S-coordinate non-dimensional stretching curves at RHO-points.

  Vinfo( 1)='Cs_r'
  Vinfo( 2)='S-coordinate stretching curves at RHO-points'
  Vinfo( 5)='valid_min'
  Vinfo( 6)='valid_max'
  Aval(2)=-1.0_r8
  Aval(3)=0.0_r8
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TOUT,                        &
                       1, (/DimIDs(9)/), Aval, Vinfo, ncname,                  &
                       SetParAccess = .FALSE.),                                &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  ! S-coordinate non-dimensional stretching curves at W-points.

  Vinfo( 1)='Cs_w'
  Vinfo( 2)='S-coordinate stretching curves at W-points'
  Vinfo( 5)='valid_min'
  Vinfo( 6)='valid_max'
  Aval(2)=-1.0_r8
  Aval(3)=0.0_r8
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TOUT,                        &
                       1, (/DimIDs(10)/), Aval, Vinfo, ncname,                 &
                       SetParAccess = .FALSE.),                                &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  ! Bathymetry.

  Vinfo( 1)='h'
  Vinfo( 2)='bathymetry at RHO-points'
  Vinfo( 3)='meter'
  Vinfo(22)='coordinates'
  Aval(5)=REAL(r2dvar,r8)
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TYPE,                        &
                       2, r2dgrd, Aval, Vinfo, ncname),                        &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  ! Grid coordinates of RHO-points.

  Vinfo( 1)='lon_rho'
  Vinfo( 2)='longitude of RHO-points'
  Vinfo( 3)='degree_east'
  Vinfo(21)='longitude'
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TYPE,                        &
                       2, r2dgrd, Aval, Vinfo, ncname),                        &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  Vinfo( 1)='lat_rho'
  Vinfo( 2)='latitude of RHO-points'
  Vinfo( 3)='degree_north'
  Vinfo(21)='latitude'
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TYPE,                        &
                       2, r2dgrd, Aval, Vinfo, ncname),                        &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  ! Grid coordinates of U-points.

  Vinfo( 1)='lon_u'
  Vinfo( 2)='longitude of U-points'
  Vinfo( 3)='degree_east'
  Vinfo(21)='longitude'
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TYPE,                        &
                       2, u2dgrd, Aval, Vinfo, ncname),                        &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  Vinfo( 1)='lat_u'
  Vinfo( 2)='latitude of U-points'
  Vinfo( 3)='degree_north'
  Vinfo(21)='latitude'
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TYPE,                        &
                       2, u2dgrd, Aval, Vinfo, ncname),                        &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  ! Grid coordinates of V-points.

  Vinfo( 1)='lon_v'
  Vinfo( 2)='longitude of V-points'
  Vinfo( 3)='degree_east'
  Vinfo(21)='longitude'
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TYPE,                        &
                       2, v2dgrd, Aval, Vinfo, ncname),                        &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  Vinfo( 1)='lat_v'
  Vinfo( 2)='latitude of V-points'
  Vinfo( 3)='degree_north'
  Vinfo(21)='latitude'
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TYPE,                        &
                       2, v2dgrd, Aval, Vinfo, ncname),                        &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  ! Angle between XI-axis and EAST at RHO-points.

  Vinfo( 1)='angle'
  Vinfo( 2)='angle between XI-axis and EAST'
  Vinfo( 3)='radians'
  Vinfo(22)='coordinates'
  Aval(5)=REAL(r2dvar,r8)
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TYPE,                        &
                       2, r2dgrd, Aval, Vinfo, ncname),                        &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  !  Masking fields at RHO-, U-, and V-points.

  Vinfo( 1)='mask_rho'
  Vinfo( 2)='mask on RHO-points'
  Vinfo( 9)='land'
  Vinfo(10)='water'
  Vinfo(22)='coordinates'
  Aval(5)=REAL(r2dvar,r8)
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TYPE,                        &
                       2, r2dgrd, Aval, Vinfo, ncname),                        &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  Vinfo( 1)='mask_u'
  Vinfo( 2)='mask on U-points'
  Vinfo( 9)='land'
  Vinfo(10)='water'
  Vinfo(22)='coordinates'
  Aval(5)=REAL(u2dvar,r8)
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TYPE,                        &
                       2, u2dgrd, Aval, Vinfo, ncname),                        &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  Vinfo( 1)='mask_v'
  Vinfo( 2)='mask on V-points'
  Vinfo( 9)='land'
  Vinfo(10)='water'
  Vinfo(22)='coordinates'
  Aval(5)=REAL(v2dvar,r8)
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TYPE,                        &
                       2, v2dgrd, Aval, Vinfo, ncname),                        &
               nf90_noerr, io_nf90, __LINE__, MyFile)

END SUBROUTINE roms_def_info_nf90

! ------------------------------------------------------------------------------
!> Define NetCDF file global attributes and grid arrays using standard library.

SUBROUTINE roms_wrt_info_nf90 (ng, model, ncid, ncname)

  USE mod_param
  USE mod_grid
  USE mod_scalars
  USE mod_ncparam
  USE mod_netcdf

  USE nf_fwrite2d_mod, ONLY : nf_fwrite2d
  USE strings_mod,     ONLY : find_string

  integer,           intent(in) :: ng              !< nested grid number
  integer,           intent(in) :: model           !< ROMS numerical kernel
  integer,           intent(in) :: ncid            !< NetCDF file ID
  character (len=*), intent(in) :: ncname          !< NetCDF filename

  integer                       :: LBi, UBi, LBj, UBj
  integer                       :: varid
  real (kind=kind_real)         :: scale
  character (len=1024)          :: Message

  character (len=*),  parameter :: MyFile =                                    &
     &  __FILE__//", roms_wrt_info_nf90"

  ! Initialize

  LBi=LBOUND(GRID(ng)%h,DIM=1)
  UBi=UBOUND(GRID(ng)%h,DIM=1)
  LBj=LBOUND(GRID(ng)%h,DIM=2)
  UBj=UBOUND(GRID(ng)%h,DIM=2)

  !  Inquire about the variables.

  CALL netcdf_inq_var (ng, model, ncname, ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  ! Write out grid variables.

  CALL netcdf_put_lvar (ng, model, ncname, 'spherical',                        &
                        spherical, (/0/), (/0/),                               &
                        ncid = ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  ! S-coordinate parameters.

  CALL netcdf_put_ivar (ng, model, ncname, 'Vtransform',                       &
                        Vtransform(ng), (/0/), (/0/),                          &
                        ncid = ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  CALL netcdf_put_ivar (ng, model, ncname, 'Vstretching',                      &
                        Vstretching(ng), (/0/), (/0/),                         &
                        ncid = ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  CALL netcdf_put_fvar (ng, model, ncname, 'theta_s',                          &
                        theta_s(ng), (/0/), (/0/),                             &
                        ncid = ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  CALL netcdf_put_fvar (ng, model, ncname, 'theta_b',                          &
                        theta_b(ng), (/0/), (/0/),                             &
                        ncid = ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  CALL netcdf_put_fvar (ng, model, ncname, 'Tcline',                           &
                        Tcline(ng), (/0/), (/0/),                              &
                        ncid = ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  CALL netcdf_put_fvar (ng, model, ncname, 'hc',                               &
                        hc(ng), (/0/), (/0/),                                  &
                        ncid = ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  CALL netcdf_put_ivar (ng, model, ncname, 'grid',                             &
                        (/1/), (/0/), (/0/),                                   &
                        ncid = ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  ! S-coordinate non-dimensional independent variables.

  CALL netcdf_put_fvar (ng, model, ncname, 's_rho',                            &
                        SCALARS(ng)%sc_r(:), (/1/), (/N(ng)/),                 &
                        ncid = ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  CALL netcdf_put_fvar (ng, model, ncname, 's_w',                              &
                        SCALARS(ng)%sc_w(0:), (/1/), (/N(ng)+1/),              &
                        ncid = ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  ! S-coordinate non-dimensional stretching curves.

  CALL netcdf_put_fvar (ng, model, ncname, 'Cs_r',                             &
                        SCALARS(ng)%Cs_r(:), (/1/), (/N(ng)/),                 &
                        ncid = ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  CALL netcdf_put_fvar (ng, model, ncname, 'Cs_w',                             &
                        SCALARS(ng)%Cs_w(0:), (/1/), (/N(ng)+1/),              &
                        ncid = ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  ! Bathymetry.

  IF (find_string(var_name, n_var, 'h', varid)) THEN
    scale=1.0_kind_real
    CALL nc_err (nf_fwrite2d(ng, model, ncid, varid, 0, r2dvar,                &
                             LBi, UBi, LBj, UBj, scale,                        &
                             GRID(ng) % rmask,                                 &
                             GRID(ng) % h,                                     &
                             SetFillVal = .FALSE.),                            &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  !  Grid coordinates of RHO-points.

  IF (find_string(var_name, n_var, 'lon_rho', varid)) THEN
    scale=1.0_kind_real
    CALL nc_err (nf_fwrite2d(ng, model, ncid, varid, 0, r2dvar,                &
                             LBi, UBi, LBj, UBj, scale,                        &
                             GRID(ng) % rmask,                                 &
                             GRID(ng) % lonr,                                  &
                             SetFillVal = .FALSE.),                            &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  IF (find_string(var_name, n_var, 'lat_rho', varid)) THEN
    scale=1.0_kind_real
    CALL nc_err (nf_fwrite2d(ng, model, ncid, varid, 0, r2dvar,                &
                             LBi, UBi, LBj, UBj, scale,                        &
                             GRID(ng) % rmask,                                 &
                             GRID(ng) % latr,                                  &
                             SetFillVal = .FALSE.),                            &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  ! Grid coordinates of U-points.

  IF (find_string(var_name, n_var, 'lon_u', varid)) THEN
    scale=1.0_kind_real
    CALL nc_err (nf_fwrite2d(ng, model, ncid, varid, 0, u2dvar,                &
                             LBi, UBi, LBj, UBj, scale,                        &
                             GRID(ng) % umask,                                 &
                             GRID(ng) % lonu,                                  &
                             SetFillVal = .FALSE.),                            &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  IF (find_string(var_name, n_var, 'lat_u', varid)) THEN
    scale=1.0_dp
    CALL nc_err (nf_fwrite2d(ng, model, ncid, varid, 0, u2dvar,                &
                             LBi, UBi, LBj, UBj, scale,                        &
                             GRID(ng) % umask,                                 &
                             GRID(ng) % latu,                                  &
                             SetFillVal = .FALSE.),                            &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  ! Grid coordinates of V-points.

  IF (find_string(var_name, n_var, 'lon_v', varid)) THEN
    scale=1.0_kind_real
    CALL nc_err (nf_fwrite2d(ng, model, ncid, varid, 0, v2dvar,                &
                             LBi, UBi, LBj, UBj, scale,                        &
                             GRID(ng) % vmask,                                 &
                             GRID(ng) % lonv,                                  &
                             SetFillVal = .FALSE.),                            &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  IF (find_string(var_name, n_var, 'lat_v', varid)) THEN
    scale=1.0_kind_real
    CALL nc_err (nf_fwrite2d(ng, model, ncid, varid, 0, v2dvar,                &
                             LBi, UBi, LBj, UBj, scale,                        &
                             GRID(ng) % vmask,                                 &
                             GRID(ng) % latv,                                  &
                             SetFillVal = .FALSE.),                            &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  ! Angle between XI-axis and EAST at RHO-points.

  IF (find_string(var_name, n_var, 'angle', varid)) THEN
    scale=1.0_kind_real
    CALL nc_err (nf_fwrite2d(ng, model, ncid, varid, 0, r2dvar,                &
                             LBi, UBi, LBj, UBj, scale,                        &
                             GRID(ng) % rmask,                                 &
                             GRID(ng) % angler,                                &
                             SetFillVal = .FALSE.),                            &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  ! Masking fields at RHO-, U-, and V-points.

  IF (find_string(var_name, n_var, 'mask_rho', varid)) THEN
    scale=1.0_kind_real
    CALL nc_err (nf_fwrite2d(ng, model, ncid, varid, 0, r2dvar,                &
                             LBi, UBi, LBj, UBj, scale,                        &
                             GRID(ng) % rmask,                                 &
                             GRID(ng) % rmask,                                 &
                             SetFillVal = .FALSE.),                            &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  IF (find_string(var_name, n_var, 'mask_u', varid)) THEN
    scale=1.0_kind_real
    CALL nc_err (nf_fwrite2d(ng, model, ncid, varid, 0, u2dvar,                &
                             LBi, UBi, LBj, UBj, scale,                        &
                             GRID(ng) % umask,                                 &
                             GRID(ng) % umask,                                 &
                             SetFillVal = .FALSE.),                            &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  IF (find_string(var_name, n_var, 'mask_v', varid)) THEN
    scale=1.0_kind_real
    CALL nc_err (nf_fwrite2d(ng, model, ncid, varid, 0, v2dvar,                &
                             LBi, UBi, LBj, UBj, scale,                        &
                             GRID(ng) % vmask,                                 &
                             GRID(ng) % vmask,                                 &
                             SetFillVal = .FALSE.),                            &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

END SUBROUTINE roms_wrt_info_nf90

# if defined PIO_LIB

! ------------------------------------------------------------------------------
!> Creates output state file using the Paralell-IO (PIO) library.

SUBROUTINE roms_create_ncfile_pio (ng, model, LocalPET, S, metadata)

  USE mod_param
  USE mod_ncparam
  USE mod_pio_netcdf
  USE mod_scalars

  USE mod_iounits,  ONLY : T_IO
  USE def_dim_mod,  ONLY : def_dim
  USE def_info_mod, ONLY : def_info
  USE def_var_mod,  ONLY : def_var
  USE wrt_info_mod, ONLY : wrt_info

  integer,                    intent(in   ) :: ng          !< nested grid number
  integer,                    intent(in   ) :: model       !< numerical kernel
  integer,                    intent(in   ) :: LocalPET    !< PET rank
  character (len=*),          intent(in   ) :: ncname      !< NetCDF filename
  TYPE (T_IO),                intent(inout) :: S(:)        !< ROMS I/O structure
  TYPE (roms_field_metadata), intent(in   ) :: metadata(:) !< field Metadata

  integer                          :: i, itrc
  integer                          :: DimIDs(nDimID)
  integer                          :: r2dgrd(3), u2dgrd(3), v2dgrd(3)
  integer                          :: r3dgrd(4), u3dgrd(4), v3dgrd(4)
  real (kind=kind_real)            :: Aval(6)
  character (len=120)              :: Vinfo(25)
  character (len=256)              :: ncname
  character (len=1024)             :: Message

  character (len=*),     parameter :: MyFile =                                 &
     __FILE__//", roms_create_ncfile_pio"

  ! Initialize.

  DimIDs = 0
  Aval   = 0.0_kind_real
  Vinfo  = CHAR(32)                !< blank space

  ncname = S(ng)%ncname

  ! Create NetCDF file.

  CALL pio_netcdf_create (ng, model, TRIM(ncname), S(ng)%pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  ! Define file dimensions.

  CALL nc_err (def_dim(ng, model, S(ng)%pioFile, ncname, 'xi_rho',             &
                       IOBOUNDS(ng)%xi_rho, DimIDs( 1)),                       &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%pioFile, ncname, 'xi_u',               &
                       IOBOUNDS(ng)%xi_u, DimIDs( 2)),                         &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%pioFile, ncname, 'xi_v',               &
                       IOBOUNDS(ng)%xi_v, DimIDs( 3)),                         &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%pioFile, ncname, 'xi_psi',             &
                       IOBOUNDS(ng)%xi_psi, DimIDs( 4)),                       &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%pioFile, ncname, 'eta_rho',            &
                       IOBOUNDS(ng)%eta_rho, DimIDs( 5)),                      &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%pioFile, ncname, 'eta_u',              &
                       IOBOUNDS(ng)%eta_u, DimIDs( 6)),                        &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%pioFile, ncname, 'eta_v',              &
                       IOBOUNDS(ng)%eta_v, DimIDs( 7)),                        &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%pioFile, ncname, 'N',                  &
                       N(ng), DimIDs( 9)),                                     &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%pioFile, ncname, 's_rho',              &
                       N(ng), DimIDs( 9)),                                     &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%pioFile, ncname, 's_w',                &
                       N(ng)+1, DimIDs(10)),                                   &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%pioFile, ncname, 'tracer',             &
                       NT(ng), DimIDs(11)),                                    &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%pioFile, ncname,                       &
                       TRIM(ADJUSTL(Vname(5,idtime))),                         &
                       nf90_unlimited, DimIDs(12)),                            &
               PIO_noerr, io_pio, __LINE__, MyFile)

  ! Set dimension vector for each C-grid location.

  r2dgrd = (/ DimIDs(1), DimIDs(5), DimIDs(12) /)
  u2dgrd = (/ DimIDs(2), DimIDs(6), DimIDs(12) /)
  v2dgrd = (/ DimIDs(3), DimIDs(7), DimIDs(12) /)

  r3dgrd = (/ DimIDs(1), DimIDs(5), DimIDs(9), DimIDs(12) /)
  u3dgrd = (/ DimIDs(2), DimIDs(6), DimIDs(9), DimIDs(12) /) 
  v3dgrd = (/ DimIDs(3), DimIDs(7), DimIDs(9), DimIDs(12) /)

  ! Define time-recordless information variables.

  CALL roms_def_info_pio (ng, model, localPET, S(ng)%pioFile,                  &
                          DimIDs, ncname)

  ! Define model time.

  Vinfo( 1)=Vname(1,idtime)
  Vinfo( 2)=Vname(2,idtime)
  WRITE (Vinfo( 3),'(a,a)') 'seconds since ', TRIM(Rclock%string)
  Vinfo( 4)=TRIM(Rclock%calendar)
  S(ng)%pioVar(idtime)%dkind=PIO_TOUT
  S(ng)%pioVar(idtime)%gtype=0
  CALL nc_err (def_var(ng, model, S(ng)%pioFile,                               &
                       S(ng)%pioVar(idtime)%vd,                                &
                       PIO_TOUT, 1, (/DimIDs(12)/), Aval, Vinfo,               &
                       ncname, SetParAccess = .TRUE.),                         &
               PIO_noerr, io_pio, __LINE__, MyFile)

  ! Define state variables.

  DO i = 1, SIZE(metadata)

    SELECT CASE (metadata(i)%name)

      CASE ('ssh')                             !< free-surface

        Vinfo( 1)=Vname(1,idFsur)
        Vinfo( 2)=Vname(2,idFsur)
        Vinfo(21)=metadata(i)%getval_name
        Vinfo( 3)=Vname(3,idFsur)
        Vinfo(16)=Vname(1,idtime)
        Vinfo(22)='coordinates'
        Aval(5)=REAL(Iinfo(1,idFsur,ng),r8)
        S(ng)%pioVar(idFsur)%dkind=PIO_FOUT
        S(ng)%pioVar(idFsur)%gtype=r2dvar

        CALL nc_err (def_var(ng, model, S(ng)%pioFile,                         &
                             S(ng)%pioVar(idFsur)%vd,                          &
                             PIO_FOUT, 3, r2dgrd, Aval, Vinfo, ncname),        &
                     PIO_noerr, io_pio, __LINE__, MyFile)

      CASE ('u2docn')                          !< 2D U-momentum component

        Vinfo( 1)=Vname(1,idUbar)
        Vinfo( 2)=Vname(2,idUbar)
        Vinfo(21)=metadata(i)%getval_name
        Vinfo( 3)=Vname(3,idUbar)
        Vinfo(16)=Vname(1,idtime)
        Vinfo(22)='coordinates'
        Aval(5)=REAL(Iinfo(1,idUbar,ng),r8)
        S(ng)%pioVar(idUbar)%dkind=PIO_FOUT
        S(ng)%pioVar(idUbar)%gtype=u2dvar

        CALL nc_err (def_var(ng, model, S(ng)%pioFile,                         &
                             S(ng)%pioVar(idUbar)%vd,                          &
                             PIO_FOUT, 3, u2dgrd, Aval, Vinfo, ncname),        &
                     PIO_noerr, io_pio, __LINE__, MyFile)

      CASE ('v2docn')                          !< 2D v-momentum component

        Vinfo( 1)=Vname(1,idVbar)
        Vinfo( 2)=Vname(2,idVbar)
        Vinfo(21)=metadata(i)%getval_name
        Vinfo( 3)=Vname(3,idVbar)
        Vinfo(16)=Vname(1,idtime)
        Vinfo(22)='coordinates'
        Aval(5)=REAL(Iinfo(1,idVbar,ng),r8)
        S(ng)%pioVar(idVbar)%dkind=PIO_FOUT
        S(ng)%pioVar(idVbar)%gtype=v2dvar

        CALL nc_err (def_var(ng, model, S(ng)%pioFile,                         &
                             S(ng)%pioVar(idVbar)%vd,                          &
                             PIO_FOUT, 3, v2dgrd, Aval, Vinfo, ncname),        &
                     PIO_noerr, io_pio, __LINE__, MyFile)

      CASE ('uocn')                            !< 3D U-momentum component

        Vinfo( 1)=Vname(1,idUvel)
        Vinfo( 2)=Vname(2,idUvel)
        Vinfo(21)=metadata(i)%getval_name
        Vinfo( 3)=Vname(3,idUvel)
        Vinfo(16)=Vname(1,idtime)
        Vinfo(22)='coordinates'
        Aval(5)=REAL(Iinfo(1,idUvel,ng),r8)
        S(ng)%pioVar(idUvel)%dkind=PIO_FOUT
        S(ng)%pioVar(idUvel)%gtype=u3dvar

        CALL nc_err (def_var(ng, model, S(ng)%pioFile,                         &
                             S(ng)%pioVar(idUvel)%vd,                          &
                             PIO_FOUT, 4, u3dgrd, Aval, Vinfo, ncname),        &
                     PIO_noerr, io_pio, __LINE__, MyFile)

      CASE ('vocn')                            !< 3D V-momentum component

        Vinfo( 1)=Vname(1,idVvel)
        Vinfo( 2)=Vname(2,idVvel)
        Vinfo(21)=metadata(i)%getval_name
        Vinfo( 3)=Vname(3,idVvel)
        Vinfo(16)=Vname(1,idtime)
        Vinfo(22)='coordinates'
        Aval(5)=REAL(Iinfo(1,idVvel,ng),r8)
        S(ng)%pioVar(idVvel)%dkind=PIO_FOUT
        S(ng)%pioVar(idVvel)%gtype=v3dvar

        CALL nc_err (def_var(ng, model, S(ng)%pioFile,                         &
                             S(ng)%pioVar(ifield)%vd,                          &
                             PIO_FOUT, 4, v3dgrd, Aval, Vinfo, ncname),        &
                     PIO_noerr, io_pio, __LINE__, MyFile)

      CASE ('tocn', 'socn')                    !< tracer-type variables

        itrc = roms_tracer_index(metadata(i)%name)
        Vinfo( 1)=Vname(1,idTvar(itrc))
        Vinfo( 2)=Vname(2,idTvar(itrc))
        Vinfo(21)=metadata(i)%getval_name
        Vinfo( 3)=Vname(3,idTvar(itrc))
        Vinfo(16)=Vname(1,idtime)
        Vinfo(22)='coordinates'
        Aval(5)=REAL(r3dvar,r8)
        S(ng)%pioTrc(itrc)%dkind=PIO_FOUT
        S(ng)%pioTrc(itrc)%gtype=r3dvar

        CALL nc_err (def_var(ng, model, S(ng)%pioFile,                         &
                             S(ng)%pioTrc(itrc)%vd,                            &
                             PIO_FOUT, 4, r3dgrd, Aval, Vinfo, ncname),        &
                     PIO_noerr, io_pio, __LINE__, MyFile)

      CASE DEFAULT
  
        WRITE (Message,'(4a)')                                                 &
              'roms_create_ncfile::pio: Cannot find an option to define = ',   &
              metadata(i)%name, " - ", metadata(i)%getval_name
        CALL abor1_ftn (TRIM(Message))

    END SELECT

  END DO

  ! Leave definition mode.

  CALL pio_netcdf_enddef (ng, model, ncname, S(ng)%pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  ! Write out time-recordless, information variables.

  CALL roms_wrt_info_pio (ng, model, S(ng)%pioFile, ncname)

END SUBROUTINE roms_create_ncfile_pio

! ------------------------------------------------------------------------------
!> Define NetCDF file global attributes and grid arrays using pio library.

SUBROUTINE roms_def_info_pio (ng, model, LocalPET, pioFile, DimIDs, ncname)

  USE mod_param
  USE mod_ncparam
  USE mod_pio_netcdf
  USE mod_scalars

  USE def_var_mod,  ONLY : def_var
  USE mod_strings,  ONLY : title

  integer,            intent(in) :: ng             !< nested grid number
  integer,            intent(in) :: model          !< ROMS numerical kernel
  integer,            intent(in) :: LocalPET       !< PET rank
  integer,            intent(in) :: DimIDs(:)      !< NetCDF file dimensions IDs
  TYPE (file_desc_t), intent(in) :: pioFile        !< NetCDF file descriptor
  character (len=*),  intent(in) :: ncname         !< NetCDF filename

  TYPE (Var_desc_t)              :: pioVar         !< NetCDF variable descriptor

  integer                        :: r2dgrd(2), u2dgrd(2), v2dgrd(2)
  real (kind=kind_real)          :: Aval(6)
  character (len=120)            :: Vinfo(25)
  character (len=512)            :: text

  character (len=*),   parameter :: MyFile =                                   &
     __FILE__//", roms_def_info_pio"

  ! Initialize

  Aval   = 0.0_kind_real
  Vinfo  = CHAR(32)                        !< blank space

  ! Set dimension vector for each C-grid location.

  r2dgrd = (/ DimIDs(1), DimIDs(5) /)      !< RHO-points
  u2dgrd = (/ DimIDs(2), DimIDs(6) /)      !< U-points
  v2dgrd = (/ DimIds(3), DimIDs(7) /)      !< V-points

  ! Define global attributes. They are defined in a parallel I/O
  ! environment and PIO will take care of writing into file. 

  CALL nc_err (PIO_put_att(pioFile, PIO_global, 'file',                        &
                           TRIM(ncname)),                                      &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (PIO_put_att(pioFile, PIO_global, 'Conventions',                 &
                           'CF-1.4, SGRID-0.3'),                               &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (PIO_put_att(pioFile, PIO_global, 'type',                        &
                           'ROMS-JEDI state fields file'),                     &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (PIO_put_att(pioFile, PIO_global, 'title',                       &
                           TRIM(title)),                                       &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (PIO_put_att(pioFile, PIO_global, 'var_info',                    &
                           TRIM(varname)),                                     &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (PIO_put_att(pioFile, PIO_global, 'grd_file',                    &
                           TRIM(GRD(ng)%name)),                                &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (PIO_put_att(pioFile, PIO_global, 'script_file',                 &
                           TRIM(Iname)),                                       &
               PIO_noerr, io_pio, __LINE__, MyFile)

  WRITE (text,'(i0,a,i0)') NtileI(ng), 'x', NtileJ(ng)
  CALL nc_err (PIO_put_att(pioFile, PIO_global, 'tiling',                      &
                           TRIM(text)),                                        &
               PIO_noerr, io_pio, __LINE__, MyFile)

  IF (LEN_TRIM(date_str).gt.0) THEN
    WRITE (text,'(a,1x,a,", ",a)') 'ROMS, Version', TRIM(version),             &
                                   TRIM(date_str)
  ELSE
    WRITE (test,'(a,1x,a)') 'ROMS, Version', TRIM(version)
  END IF
  CALL nc_err (PIO_put_att(pioFile, PIO_global, 'history',                     &
                           TRIM(text)),                                        &
               PIO_noerr, io_pio, __LINE__, MyFile)

  ! Define grid variables.

  Vinfo( 1)='spherical'
  Vinfo( 2)='grid type logical switch'
  Vinfo( 9)='Cartesian'
  Vinfo(10)='spherical'
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_int,                    &
                       1, (/0/), Aval, Vinfo, ncname,                          &
                       SetParAccess = .FALSE.),                                &
               PIO_noerr, io_pio, __LINE__, MyFile)

  ! S-coordinate parameters.

  Vinfo( 1)='Vtransform'
  Vinfo( 2)='vertical terrain-following transformation equation'
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_int,                    &
                       1, (/0/), Aval, Vinfo, ncname,                          &
                       SetParAccess = .FALSE.),                                &
               PIO_noerr, io_pio, __LINE__, MyFile)

  Vinfo( 1)='Vstretching'
  Vinfo( 2)='vertical terrain-following stretching function'
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_int,                    &
                       1, (/0/), Aval, Vinfo, ncname,                          &
                       SetParAccess = .FALSE.),                                &
               PIO_noerr, io_pio, __LINE__, MyFile)

  Vinfo( 1)='theta_s'
  Vinfo( 2)='S-coordinate surface control parameter'
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TOUT,                   &
                       1, (/0/), Aval, Vinfo, ncname,                          &
                       SetParAccess = .FALSE.),                                &
               PIO_noerr, io_pio, __LINE__, MyFile)

  Vinfo( 1)='theta_b'
  Vinfo( 2)='S-coordinate bottom control parameter'
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TOUT,                   &
                       1, (/0/), Aval, Vinfo, ncname,                          &
                       SetParAccess = .FALSE.),                                &
               PIO_noerr, io_pio, __LINE__, MyFile)

  Vinfo( 1)='Tcline'
  Vinfo( 2)='S-coordinate surface/bottom layer width'
  Vinfo( 3)='meter'
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TOUT,                   &
                       1, (/0/), Aval, Vinfo, ncname,                          &
                       SetParAccess = .FALSE.),                                &
               PIO_noerr, io_pio, __LINE__, MyFile)

  Vinfo( 1)='hc'
  Vinfo( 2)='S-coordinate parameter, critical depth'
  Vinfo( 3)='meter'
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TOUT,                   &
                       1, (/0/), Aval, Vinfo, ncname,                          &
                       SetParAccess = .FALSE.),                                &
               PIO_noerr, io_pio, __LINE__, MyFile)

  Vinfo( 1)='grid'
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_int,                    &
                       1, (/0/), Aval, Vinfo, ncname,                          &
                       SetParAccess = .FALSE.),                                &
               PIO_noerr, io_pio, __LINE__, MyFile)

  ! S-coordinate non-dimensional independent variable at RHO-points.

  Vinfo( 1)='s_rho'
  Vinfo( 2)='S-coordinate at RHO-points'
  Vinfo( 5)='valid_min'
  Vinfo( 6)='valid_max'
  IF (Vtransform(ng).eq.1) THEN
    Vinfo(21)='ocean_s_coordinate_g1'
  ELSE IF (Vtransform(ng).eq.2) THEN
    Vinfo(21)='ocean_s_coordinate_g2'
  END IF
  Vinfo(23)='s: s_rho C: Cs_r eta: zeta depth: h depth_c: hc'
  vinfo(25)='up'
  Aval(2)=-1.0_r8
  Aval(3)=0.0_r8
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TOUT,                   &
                       1, (/DimIDs(9)/), Aval, Vinfo, ncname,                  &
                       SetParAccess = .FALSE.),                                &
               PIO_noerr, io_pio, __LINE__, MyFile)

  ! S-coordinate non-dimensional independent variable at W-points.

  Vinfo( 1)='s_w'
  Vinfo( 2)='S-coordinate at W-points'
  Vinfo( 5)='valid_min'
  Vinfo( 6)='valid_max'
  Vinfo(21)='ocean_s_coordinate'
  IF (Vtransform(ng).eq.1) THEN
    Vinfo(21)='ocean_s_coordinate_g1'
  ELSE IF (Vtransform(ng).eq.2) THEN
    Vinfo(21)='ocean_s_coordinate_g2'
  END IF
  Vinfo(23)='s: s_w C: Cs_w eta: zeta depth: h depth_c: hc'
  vinfo(25)='up'
  Aval(2)=-1.0_r8
  Aval(3)=0.0_r8
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TOUT,                   &
                       1, (/DimIDs(10)/), Aval, Vinfo, ncname,                 &
                       SetParAccess = .FALSE.),                                &
               PIO_noerr, io_pio, __LINE__, MyFile)

  ! S-coordinate non-dimensional stretching curves at RHO-points.

  Vinfo( 1)='Cs_r'
  Vinfo( 2)='S-coordinate stretching curves at RHO-points'
  Vinfo( 5)='valid_min'
  Vinfo( 6)='valid_max'
  Aval(2)=-1.0_r8
  Aval(3)=0.0_r8
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TOUT,                   &
                       1, (/DimIDs(9)/), Aval, Vinfo, ncname,                  &
                       SetParAccess = .FALSE.),                                &
               PIO_noerr, io_pio, __LINE__, MyFile)

  ! S-coordinate non-dimensional stretching curves at W-points.

  Vinfo( 1)='Cs_w'
  Vinfo( 2)='S-coordinate stretching curves at W-points'
  Vinfo( 5)='valid_min'
  Vinfo( 6)='valid_max'
  Aval(2)=-1.0_r8
  Aval(3)=0.0_r8
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TOUT,                   &
                       1, (/DimIDs(10)/), Aval, Vinfo, ncname,                 &
                       SetParAccess = .FALSE.),                                &
               PIO_noerr, io_pio, __LINE__, MyFile)

  ! Bathymetry.

  Vinfo( 1)='h'
  Vinfo( 2)='bathymetry at RHO-points'
  Vinfo( 3)='meter'
  Vinfo(22)='coordinates'
  Aval(5)=REAL(r2dvar,r8)
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TYPE,                   &
                       2, r2dgrd, Aval, Vinfo, ncname),                        &
               PIO_noerr, io_pio, __LINE__, MyFile)

  ! Grid coordinates of RHO-points.

  Vinfo( 1)='lon_rho'
  Vinfo( 2)='longitude of RHO-points'
  Vinfo( 3)='degree_east'
  Vinfo(21)='longitude'
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TYPE,                   &
                       2, r2dgrd, Aval, Vinfo, ncname),                        &
               PIO_noerr, io_pio, __LINE__, MyFile)

  Vinfo( 1)='lat_rho'
  Vinfo( 2)='latitude of RHO-points'
  Vinfo( 3)='degree_north'
  Vinfo(21)='latitude'
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TYPE,                   &
                       2, r2dgrd, Aval, Vinfo, ncname),                        &
               PIO_noerr, io_pio, __LINE__, MyFile)

  ! Grid coordinates of U-points.

  Vinfo( 1)='lon_u'
  Vinfo( 2)='longitude of U-points'
  Vinfo( 3)='degree_east'
  Vinfo(21)='longitude'
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TYPE,                   &
                       2, u2dgrd, Aval, Vinfo, ncname),                        &
               PIO_noerr, io_pio, __LINE__, MyFile)

  Vinfo( 1)='lat_u'
  Vinfo( 2)='latitude of U-points'
  Vinfo( 3)='degree_north'
  Vinfo(21)='latitude'
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TYPE,                   &
                       2, u2dgrd, Aval, Vinfo, ncname),                        &
               PIO_noerr, io_pio, __LINE__, MyFile)

  ! Grid coordinates of V-points.

  Vinfo( 1)='lon_v'
  Vinfo( 2)='longitude of V-points'
  Vinfo( 3)='degree_east'
  Vinfo(21)='longitude'
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TYPE,                   &
                       2, v2dgrd, Aval, Vinfo, ncname),                        &
               PIO_noerr, io_pio, __LINE__, MyFile)

  Vinfo( 1)='lat_v'
  Vinfo( 2)='latitude of V-points'
  Vinfo( 3)='degree_north'
  Vinfo(21)='latitude'
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TYPE,                   &
                       2, v2dgrd, Aval, Vinfo, ncname),                        &
               PIO_noerr, io_pio, __LINE__, MyFile)

  ! Angle between XI-axis and EAST at RHO-points.

  Vinfo( 1)='angle'
  Vinfo( 2)='angle between XI-axis and EAST'
  Vinfo( 3)='radians'
  Vinfo(22)='coordinates'
  Aval(5)=REAL(r2dvar,r8)
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TYPE,                   &
                       2, r2dgrd, Aval, Vinfo, ncname),                        &
               PIO_noerr, io_pio, __LINE__, MyFile)

  !  Masking fields at RHO-, U-, and V-points.

  Vinfo( 1)='mask_rho'
  Vinfo( 2)='mask on RHO-points'
  Vinfo( 9)='land'
  Vinfo(10)='water'
  Vinfo(22)='coordinates'
  Aval(5)=REAL(r2dvar,r8)
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TYPE,                   &
                       2, r2dgrd, Aval, Vinfo, ncname),                        &
               PIO_noerr, io_pio, __LINE__, MyFile)

  Vinfo( 1)='mask_u'
  Vinfo( 2)='mask on U-points'
  Vinfo( 9)='land'
  Vinfo(10)='water'
  Vinfo(22)='coordinates'
  Aval(5)=REAL(u2dvar,r8)
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TYPE,                   &
                       2, u2dgrd, Aval, Vinfo, ncname).                        &
               PIO_noerr, io_pio, __LINE__, MyFile)

  Vinfo( 1)='mask_v'
  Vinfo( 2)='mask on V-points'
  Vinfo( 9)='land'
  Vinfo(10)='water'
  Vinfo(22)='coordinates'
  Aval(5)=REAL(v2dvar,r8)
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TYPE,                   &
                       2, v2dgrd, Aval, Vinfo, ncname),                        &
               PIO_noerr, io_pio, __LINE__, MyFile)

END SUBROUTINE roms_def_info_pio

! ------------------------------------------------------------------------------
!> Define NetCDF file global attributes and grid arrays using PIO library.

SUBROUTINE roms_wrt_info_pio (ng, model, pioFile, ncname)

  USE mod_param
  USE mod_grid
  USE mod_scalars
  USE mod_ncparam
  USE mod_pio_netcdf

  USE nf_fwrite2d_mod, ONLY : nf_fwrite2d
  USE strings_mod,     ONLY : find_string

  integer,            intent(in   ) :: ng          !< nested grid number
  integer,            intent(in   ) :: model       !< ROMS numerical kernel
  character (len=*),  intent(in   ) :: ncname      !< NetCDF filename
  TYPE (File_desc_t), intent(inout) :: pioFile     !< NetCDF file descriptor

  TYPE (IO_desc_t), pointer         :: ioDesc      !< I/O layout descriptor
  TYPE (My_VarDesc)                 :: pioVar      !< NetCDF variable descriptor

  integer                           :: LBi, UBi, LBj, UBj
  real (kind=kind_real)             :: scale
  character (len=1024)              :: Message

  character (len=*), parameter      :: MyFile =                                &
     &  __FILE__//", roms_wrt_info_pio"

  ! Initialize

  LBi=LBOUND(GRID(ng)%h,DIM=1)
  UBi=UBOUND(GRID(ng)%h,DIM=1)
  LBj=LBOUND(GRID(ng)%h,DIM=2)
  UBj=UBOUND(GRID(ng)%h,DIM=2)

  !  Inquire about the variables.

  CALL netcdf_inq_var (ng, model, ncname, pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  ! Write out grid variables.

  CALL pio_netcdf_put_lvar (ng, model, ncname, 'spherical',                    &
                            spherical, (/0/), (/0/),                           &
                            pioFile = pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  ! S-coordinate parameters.

  CALL pio_netcdf_put_ivar (ng, model, ncname, 'Vtransform',                   &
                            Vtransform(ng), (/0/), (/0/),                      &
                            pioFile = pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  CALL pio_netcdf_put_ivar (ng, model, ncname, 'Vstretching',                  &
                            Vstretching(ng), (/0/), (/0/),                     &
                            pioFile = pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  CALL pio_netcdf_put_fvar (ng, model, ncname, 'theta_s',                      &
                            theta_s(ng), (/0/), (/0/),                         &
                            pioFile = pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  CALL pio_netcdf_put_fvar (ng, model, ncname, 'theta_b',                      &
                            theta_b(ng), (/0/), (/0/),                         &
                            pioFile = pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  CALL pio_netcdf_put_fvar (ng, model, ncname, 'Tcline',                       &
                            Tcline(ng), (/0/), (/0/),                          &
                            pioFile = pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  CALL pio_netcdf_put_fvar (ng, model, ncname, 'hc',                           &
                            hc(ng), (/0/), (/0/),                              &
                            pioFile = pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  CALL pio_netcdf_put_ivar (ng, model, ncname, 'grid',                         &
                            (/1/), (/0/), (/0/),                               &
                            pioFile = pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  ! S-coordinate non-dimensional independent variables.

  CALL pio_netcdf_put_fvar (ng, model, ncname, 's_rho',                        &
                            SCALARS(ng)%sc_r(:), (/1/), (/N(ng)/),             &
                            pioFile = pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  CALL pio_netcdf_put_fvar (ng, model, ncname, 's_w',                          &
                            SCALARS(ng)%sc_w(0:), (/1/), (/N(ng)+1/),          &
                            pioFile = pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  ! S-coordinate non-dimensional stretching curves.

  CALL pio_netcdf_put_fvar (ng, model, ncname, 'Cs_r',                         &
                            SCALARS(ng)%Cs_r(:), (/1/), (/N(ng)/),             &
                            pioFile = pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  CALL pio_netcdf_put_fvar (ng, model, ncname, 'Cs_w',                         &
                            SCALARS(ng)%Cs_w(0:), (/1/), (/N(ng)+1/),          &
                            pioFile = pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))              &
    CALL abor1_ftn (TRIM(Message))

  ! Bathymetry.

  IF (pio_netcdf_find_var(ng, model, pioFile, 'h',                             &
                          pioVar%vd)) THEN
    scale=1.0_kind_real
    pioVar%gtype=r2dvar
    IF (PIO_TYPE.eq.PIO_double) THEN
      pioVar%dkind=PIO_double
      ioDesc => ioDesc_dp_r2dvar(ng)
    ELSE
      pioVar%dkind=PIO_real
      ioDesc => ioDesc_sp_r2dvar(ng)
    END IF
    CALL nc_err (nf_fwrite2d(ng, model, pioFile, pioVar,                       &
                             0, ioDesc,                                        &
                             LBi, UBi, LBj, UBj, scale,                        &
                             GRID(ng) % rmask,                                 &
                             GRID(ng) % h,                                     &
                             SetFillVal = .FALSE.),                            &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  !  Grid coordinates of RHO-points.

  IF (pio_netcdf_find_var(ng, model, pioFile, 'lon_rho',                       &
                          pioVar%vd)) THEN
    scale=1.0_kind_real
    pioVar%gtype=r2dvar
    IF (PIO_TYPE.eq.PIO_double) THEN
      pioVar%dkind=PIO_double
      ioDesc => ioDesc_dp_r2dvar(ng)
    ELSE
      pioVar%dkind=PIO_real
      ioDesc => ioDesc_sp_r2dvar(ng)
    END IF
    CALL nc_err (nf_fwrite2d(ng, model, pioFile, pioVar,                       &
                             0, ioDesc,                                        &
                             LBi, UBi, LBj, UBj, scale,                        &
                             GRID(ng) % rmask,                                 &
                             GRID(ng) % lonr,                                  &
                             SetFillVal = .FALSE.),                            &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  IF (pio_netcdf_find_var(ng, model, pioFile, 'lat_rho',                       &
                          pioVar%vd)) THEN
    scale=1.0_kind_real
    pioVar%gtype=r2dvar
    IF (PIO_TYPE.eq.PIO_double) THEN
      pioVar%dkind=PIO_double
      ioDesc => ioDesc_dp_r2dvar(ng)
    ELSE
      pioVar%dkind=PIO_real
      ioDesc => ioDesc_sp_r2dvar(ng)
    END IF
    CALL nc_err (nf_fwrite2d(ng, model, pioFile, pioVar,                       &
                             0, ioDesc,                                        &
                             LBi, UBi, LBj, UBj, scale,                        &
                             GRID(ng) % rmask,                                 &
                             GRID(ng) % latr,                                  &
                             SetFillVal = .FALSE.),                            &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  ! Grid coordinates of U-points.

  IF (pio_netcdf_find_var(ng, model, pioFile, 'lon_u',                         &
                          pioVar%vd)) THEN
    scale=1.0_kind_real
    pioVar%gtype=u2dvar
    IF (PIO_TYPE.eq.PIO_double) THEN
      pioVar%dkind=PIO_double
      ioDesc => ioDesc_dp_u2dvar(ng)
    ELSE
      pioVar%dkind=PIO_real
      ioDesc => ioDesc_sp_u2dvar(ng)
    END IF
    CALL nc_err (nf_fwrite2d(ng, model, pioFile, pioVar,                       &
                             0, ioDesc,                                        &
                             LBi, UBi, LBj, UBj, scale,                        &
                             GRID(ng) % umask,                                 &
                             GRID(ng) % lonu,                                  &
                             SetFillVal = .FALSE.),                            &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  IF (pio_netcdf_find_var(ng, model, pioFile, 'lat_u',                         &
                          pioVar%vd)) THEN
    scale=1.0_dp
    pioVar%gtype=u2dvar
    IF (PIO_TYPE.eq.PIO_double) THEN
      pioVar%dkind=PIO_double
      ioDesc => ioDesc_dp_u2dvar(ng)
    ELSE
      pioVar%dkind=PIO_real
      ioDesc => ioDesc_sp_u2dvar(ng)
    END IF
    CALL nc_err (nf_fwrite2d(ng, model, pioFile, pioVar,                       &
                             0, ioDesc,                                        &
                             LBi, UBi, LBj, UBj, scale,                        &
                             GRID(ng) % umask,                                 &
                             GRID(ng) % latu,                                  &
                             SetFillVal = .FALSE.),                            &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  ! Grid coordinates of V-points.

  IF (pio_netcdf_find_var(ng, model, pioFile, 'lon_v',                         &
                          pioVar%vd)) THEN
    scale=1.0_kind_real
    pioVar%gtype=v2dvar
    IF (PIO_TYPE.eq.PIO_double) THEN
      pioVar%dkind=PIO_double
      ioDesc => ioDesc_dp_v2dvar(ng)
    ELSE
      pioVar%dkind=PIO_real
      ioDesc => ioDesc_sp_v2dvar(ng)
    END IF
    CALL nc_err (nf_fwrite2d(ng, model, pioFile, pioVar,                       &
                             0, ioDesc,                                        &
                             LBi, UBi, LBj, UBj, scale,                        &
                             GRID(ng) % vmask,                                 &
                             GRID(ng) % lonv,                                  &
                             SetFillVal = .FALSE.),                            &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  IF (pio_netcdf_find_var(ng, model, pioFile, 'lat_v',                         &
                          pioVar%vd)) THEN
    scale=1.0_kind_real
    pioVar%gtype=v2dvar
    IF (PIO_TYPE.eq.PIO_double) THEN
      pioVar%dkind=PIO_double
      ioDesc => ioDesc_dp_v2dvar(ng)
    ELSE
      pioVar%dkind=PIO_real
      ioDesc => ioDesc_sp_v2dvar(ng)
    END IF
    CALL nc_err (nf_fwrite2d(ng, model, pioFile, pioVar,                       &
                             0, ioDesc,                                        &
                             LBi, UBi, LBj, UBj, scale,                        &
                             GRID(ng) % vmask,                                 &
                             GRID(ng) % latv,                                  &
                             SetFillVal = .FALSE.),                            &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  ! Angle between XI-axis and EAST at RHO-points.


  IF (pio_netcdf_find_var(ng, model, pioFile, 'angle',                         &
                          pioVar%vd)) THEN
    scale=1.0_kind_real
    pioVar%gtype=r2dvar
    IF (PIO_TYPE.eq.PIO_double) THEN
      pioVar%dkind=PIO_double
      ioDesc => ioDesc_dp_r2dvar(ng)
    ELSE
      pioVar%dkind=PIO_real
      ioDesc => ioDesc_sp_r2dvar(ng)
    END IF
    CALL nc_err (nf_fwrite2d(ng, model, pioFile, pioVar,                       &
                             0, ioDesc,                                        &
                             LBi, UBi, LBj, UBj, scale,                        &
                             GRID(ng) % rmask,                                 &
                             GRID(ng) % angler,                                &
                             SetFillVal = .FALSE.),                            &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  ! Masking fields at RHO-, U-, and V-points.

  IF (pio_netcdf_find_var(ng, model, pioFile, 'mask_rho',                      &
                          pioVar%vd)) THEN
    scale=1.0_kind_real
    pioVar%gtype=r2dvar
    IF (PIO_TYPE.eq.PIO_double) THEN
      pioVar%dkind=PIO_double
      ioDesc => ioDesc_dp_r2dvar(ng)
    ELSE
      pioVar%dkind=PIO_real
      ioDesc => ioDesc_sp_r2dvar(ng)
    END IF
    CALL nc_err (nf_fwrite2d(ng, model, pioFile, pioVar,                       &
                             0, ioDesc,                                        &
                             LBi, UBi, LBj, UBj, scale,                        &
                             GRID(ng) % rmask,                                 &
                             GRID(ng) % rmask,                                 &
                             SetFillVal = .FALSE.),                            &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  IF (pio_netcdf_find_var(ng, model, pioFile, 'mask_u',                        &
                          pioVar%vd)) THEN
    scale=1.0_kind_real
    pioVar%gtype=u2dvar
    IF (PIO_TYPE.eq.PIO_double) THEN
      pioVar%dkind=PIO_double
      ioDesc => ioDesc_dp_u2dvar(ng)
    ELSE
      pioVar%dkind=PIO_real
      ioDesc => ioDesc_sp_u2dvar(ng)
    END IF
    CALL nc_err (nf_fwrite2d(ng, model, pioFile, pioVar,                       &
                             0, ioDesc,                                        &
                             LBi, UBi, LBj, UBj, scale,                        &
                             GRID(ng) % umask,                                 &
                             GRID(ng) % umask,                                 &
                             SetFillVal = .FALSE.),                            &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  IF (pio_netcdf_find_var(ng, model, pioFile, 'mask_v',                        &
                          pioVar%vd)) THEN
    scale=1.0_kind_real
    pioVar%gtype=v2dvar
    IF (PIO_TYPE.eq.PIO_double) THEN
      pioVar%dkind=PIO_double
      ioDesc => ioDesc_dp_v2dvar(ng)
    ELSE
      pioVar%dkind=PIO_real
      ioDesc => ioDesc_sp_v2dvar(ng)
    END IF
    CALL nc_err (nf_fwrite2d(ng, model, pioFile, pioVar,                       &
                             0, ioDesc,                                        &
                             LBi, UBi, LBj, UBj, scale,                        &
                             GRID(ng) % vmask,                                 &
                             GRID(ng) % vmask,                                 &
                             SetFillVal = .FALSE.),                            &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

END SUBROUTINE roms_wrt_info_pio

#endif

END MODULE roms_fieldsutils_mod
