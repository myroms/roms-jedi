! (C) Copyright 2017-2021 UCAR
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
USE datetime_mod,               ONLY : datetime,                             &
                                       datetime_to_string,                   &
                                       datetime_create,                      &
                                       datetime_diff
USE duration_mod,               ONLY : duration,                             &
                                       duration_to_string
USE kinds,                      ONLY : kind_real

implicit none

PRIVATE

PUBLIC  :: ana_fields
PUBLIC  :: DetectError
PUBLIC  :: field_info
PUBLIC  :: nc_err
PUBLIC  :: roms_close_ncfile
PUBLIC  :: roms_create_ncfile
PUBLIC  :: roms_date2time
PUBLIC  :: roms_gen_filename
PUBLIC  :: roms_IOstruct
PUBLIC  :: roms_IOstruct_delete

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

logical,  parameter :: LdebugFieldUtils = .TRUE.

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
!> Analytical field initialization at coordinate (lon,lat,z). It is primarily
!> used to test horizontal and vertical interpolations.

SUBROUTINE ana_fields (name, mask, lon, lat, z, h, value)

  USE erf_mod, ONLY : erf                      !< ROMS Error Function, ERF(x)

  real(kind=kind_real), intent( in) :: mask    !< land=0, ocean=1
  real(kind=kind_real), intent( in) :: lon     !< longitude (degree_east)  
  real(kind=kind_real), intent( in) :: lat     !< latitude (degree_north)
  real(kind=kind_real), intent( in) :: z       !< depth (m; negative)
  real(kind=kind_real), intent( in) :: h       !< bathymetry (m; positive)
  real(kind=kind_real), intent(out) :: value   !< returned anlytical value

  character(len=*),      intent(in) :: name    !< field name
  
  real(kind=kind_real), parameter :: T0 = 25.0_kind_real      ! temperature (C)   
  real(kind=kind_real), parameter :: S0 = 32.5_kind_real      ! salinity    
  real(kind=kind_real), parameter :: U0 = 1.2_kind_real       ! U-velocity scale (m/s)
  real(kind=kind_real), parameter :: v0 = 0.7_kind_real       ! V-velocity scale (m/s)
  real(kind=kind_real), parameter :: Tcoef = 1.0E-4           ! thermal expansion (1/C)
  real(kind=kind_real), parameter :: Scoef = 7.6E-4           ! saline contraction
  real(kind=kind_real), parameter :: g = 9.81_kind_real       ! gravity (m/s2)
  real(kind=kind_real), parameter :: dscale = 80.0_kind_real  ! dynamic scale
  real(kind=kind_real), parameter :: omega = 7.2921E-5        ! Earth rotation (rad/s)

  real(kind=kind_real), parameter :: pi = 3.14159265358979323846   
  real(kind=kind_real), parameter :: deg2rad = pi/180.0_kind_real

  real(kind=kind_real)            :: f, fac1, fac2, fac3

  ! Initialize
  
  f=2.0_kind_real*omega*sin(lat*deg2rad)            ! Coriolis parameter (1/s)

  ! Analytical initialization.

  SELECT CASE (TRIM(name))
    CASE ('tocn', 'sea_water_potential_temperature',                         &
          'sst',  'sea_surface_temperature')
      fac1=COS(lon*deg2rad)*COS(lat*deg2rad)/dscale
      fac2=-0.5_kind_real*U0*dscale*f*SQRT(pi)/(Tcoef*g*h)
      fac3=(fac2*erf(fac1)+T0)*(1.0_kind_real+z/h)
      value=fac3*mask
    CASE ('socn', 'sea_water_practical_salinity',                            &
          'sss',  'sea_surface_salinity')
      fac1=COS(lon*deg2rad)*COS(lat*deg2rad)/dscale
      fac2=-0.5*U0*dscale*f*SQRT(pi)/(Scoef*g*h)
      fac3=S0+(0.03_kind_real*fac1/fac2)*(2.0_kind_real-EXP(z/500.0_kind_real))
      value=fac3*mask
    CASE ('uocn', 'sea_water_zonal_velocity',                                &
          'usur', 'surface_sea_water_zonal_velocity')
      fac1=SIN(lon*deg2rad)*COS(lat*deg2rad)/dscale
      fac2=z/h
      fac3=U0*(0.5_kind_real+fac2+(0.5*fac2*fac2))*EXP(-fac1*fac1)
      value=fac3*mask
    CASE ('vocn', 'sea_water_meridional_velocity',                           &
          'vsur', 'surface_sea_water_meridional_velocity')
      fac1=COS(lon*deg2rad)*SIN(lat*deg2rad)/dscale
      fac2=z/h
      fac3=-V0*(0.5_kind_real+fac2+(0.5*fac2*fac2))*EXP(-fac1*fac1)
      value=fac3*mask
    CASE ('ssh', 'sea_surface_height')
      fac1=COS(lon*deg2rad)*SIN(lat*deg2rad)/dscale
      fac2=-U0*dscale*f*SQRT(pi)/(12.0_kind_real*g)
      fac3=1.0E+5*fac2*erf(fac1);
      value=fac3*mask
    CASE ('hocn', 'sea_floor_depth_below_sea_surface')
      value=h
    CASE ('zocn', 'level_depth')
      value=z
  END SELECT  

END SUBROUTINE ana_fields

! ------------------------------------------------------------------------------
!> If error is detected, create error message for aborting routine.

FUNCTION DetectError (ErrFlag, NoErr, line, routine, Message)                &
              RESULT (GotErr)

  integer,           intent(in ) :: ErrFlag   !< returned error flag
  integer,           intent(in ) :: NoErr     !< value for no error
  integer,           intent(in ) :: line      !< calling routine line number
  character (len=*), intent(in ) :: routine   !< calling routine
  character (len=*), intent(out) :: Message   !< error message to abort routine

  logical                        :: GotErr

  ! If found error, set error message.

  IF (ErrFlag.ne.NoErr) THEN
    WRITE (Message,10) '*** Found error: ', ErrFlag,                         &
                       'Line: ', line,                                       &
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
        WRITE (text,10) '*** Found error: ', status,                         &
                        'Line: ', line,                                      &
                        'Source: ', TRIM(routine),                           &
                        TRIM(nf90_strerror(status))
        CALL abor1_ftn (TRIM(text))
      END IF
    CASE (io_pio)
      IF ((status.ne.NoErr).or.(exit_flag.ne.NoError)) THEN
        WRITE (text,20) '*** Found error: ', status,                         &
                        'Line: ', line,                                      &
                        'Source: ', TRIM(routine)
        CALL abor1_ftn (TRIM(text))
      END IF
  END SELECT

  10  FORMAT (a,i0,2x,a,i0,2x,a,a,2x,a)
  20  FORMAT (a,i0,3x,a,i0,3x,a,a)

END SUBROUTINE nc_err

! ------------------------------------------------------------------------------
!> Converts JEDI date to ROMS time in second since reference-time.

SUBROUTINE roms_date2time (LocalPET, vdate, time)

  USE dateclock_mod, ONLY : datenum            !< from ROMS time management
  USE mod_scalars,   ONLY : Rclock             !< ROMS reference time structure

  integer,               intent(in ) :: localPET   !< PET rank
  TYPE (datetime),       intent(in ) :: vdate      !< JEDI Date/Time
  real (kind=kind_real), intent(out) :: time       !< ROMS time (seconds)


  integer                            :: i, lstr
  integer                            :: year, month, day, hour, minutes
  real (kind=kind_real)              :: DateNumber(2),  seconds
  character (len=1), parameter       :: blank = CHAR(32)
  character (len=120)                :: CurrentDateString

  ! Convert ROMS reference-time string to datetime type (rdate). Replace non
  ! numeric elements with blanks.
  !
  !     CHAR(45)=hyphen    CHAR(58)=colon

  CALL datetime_to_string (vdate, CurrentDateString)

  lstr = LEN_TRIM(CurrentDateString)
  DO i = 1, lstr
    IF ((CurrentDateString(i:i) .eq. CHAR(45)) .or.                          &
        (CurrentDateString(i:i) .eq. CHAR(58)) .or.                          &
        (CurrentDateString(i:i) .eq. 'T')      .or.                          &
        (CurrentDateString(i:i) .eq. 'Z')) THEN
      CurrentDateString(i:i) = blank
    END IF
  END DO

  ! Decode string to integers. Then, compute datenum.

  READ (CurrentDateString,*) year, month, day, hour, minutes, seconds

  CALL datenum (DateNumber, year, month, day, hour, minutes, seconds)

  ! Compute ROMS time as elapsed seconds from reference date.

  time = DateNumber(2)-Rclock%DateNumber(2)

  IF (LdebugFieldUtils .and. (LocalPET .eq. 0)) THEN
    PRINT '(a,a)',             'Reference Date:      ', TRIM(Rclock%string)
    PRINT '(a,a)',             'Current Date:        ', TRIM(CurrentDateString)
    PRINT '(a,5(i0,1x),f7.4)', 'YYYY MM DD hh mm ss: ', year,month,day,hour, &
                                                        minutes,seconds
    PRINT '(a,f0.4)',          'Reference datenum:   ', Rclock%DateNumber(1)
    PRINT '(a,f0.4)',          'Current datenum:     ', DateNumber(1)
    PRINT '(a,f0.4)',          'ROMS time (days):    ', time/86400.0_kind_real
    PRINT '(a,f0.4)',          'ROMS time (seconds): ', time
  END IF

  10 FORMAT (5i0,f0.8)

END SUBROUTINE roms_date2time

! ------------------------------------------------------------------------------
!> Generates filename based on the date and time.

FUNCTION roms_gen_filename (f_conf, max_length, vdate, file_type)            &
                    RESULT (filename)

  TYPE (fckit_configuration),  intent(in) :: f_conf     !< configuration
  integer,                     intent(in) :: max_length !< string length
  TYPE (datetime),             intent(in) :: vdate      !< Date/Time
  character (len=*), optional, intent(in) :: file_type  !< file type or purpose

  integer                                 :: i, lstr
  character (len=max_length)              :: filename
  character (len=max_length)              :: MyPrefix, StepString, ValidityDate
  character (len=:),          allocatable :: Fdir, Fexp, Fprefix, Ftype, MyDate
  TYPE (datetime)                         :: rdate
  TYPE (duration)                         :: step

  ! Inquire configuration YAML file about the output directory, file prefix,
  ! file type, and application date

  IF (.not.f_conf%get("datadir", Fdir)) THEN
    CALL abor1_ftn ("roms_set_filename: Cannot find 'datadir'"//             &
                    " in YAML configuration")
  END IF

  IF (.not.f_conf%get("prefix", Fprefix)) THEN
    CALL abor1_ftn ("roms_set_filename: Cannot find 'prefix'"//              &
                    " in YAML configuration")
  END IF

  IF (.not.f_conf%get("exp", Fexp)) THEN
    CALL abor1_ftn ("roms_set_filename: Cannot find 'exp'"//                 &
                    " in YAML configuration")
  END IF

  IF (.not.f_conf%get("type", Ftype)) THEN
    CALL abor1_ftn ("roms_set_filename: Cannot find 'type'"//                &
                    " in YAML configuration")
  END IF

  IF (.not.f_conf%get("date", MyDate)) THEN
    CALL abor1_ftn ("roms_set_filename: Cannot find 'date'"//                &
                    " in YAML configuration")
  END IF

  ! Set filename prefix. Here, CHAR(47) = forward slash (/).

  lstr = LEN_TRIM(Fdir)
  IF (Fdir(lstr:lstr) .eq. CHAR(47) ) THEN
    MyPrefix = Fdir // Fprefix // '_' // Ftype
  ELSE
    MyPrefix = Fdir // CHAR(47) // Fprefix // '_' // Ftype
  END IF

  ! Get information from vdate structure.

  CALL datetime_to_string (vdate, ValidityDate)
  CALL datetime_create    (MyDate, rdate)
  CALL datetime_diff      (vdate, rdate, step)
  CALL duration_to_string (step, StepString)

  ! Generate filename: <DirPath>/<Prefix>_<Type>_YYYY-MM-DDThh.mm.ssZ.nc
  ! So, edit ValidityDate ISO 8601 format and replace ':' with '.' to
  ! facilitate UNIX manipulations like copy/paste, auto complete, etc.
  
  lstr = LEN_TRIM(ValidityDate)
  DO i = 1, lstr
    IF (ValidityDate(i:i) .eq. ':') THEN
      ValidityDate(i:i) = '.'
    END IF
  END DO

  filename = TRIM(MyPrefix) // '_' // TRIM(ValidityDate) // '.nc'

  IF (LdebugFieldUtils) THEN  
    PRINT '(a)',   '------------------'
    PRINT '(a,a)', 'Initial Date   = ', TRIM(MyDate)
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
  IF ( allocated(Fprefix) ) deallocate (Fprefix)
  IF ( allocated(Ftype) )   deallocate (Ftype)

END FUNCTION roms_gen_filename

! ------------------------------------------------------------------------------
!> Allocates and initalize ROMS T_IO type structure.

SUBROUTINE roms_IOstruct (ng, Nfiles, ncname, S)

  USE mod_param,   ONLY : MT, Ngrids, T_IO
  USE mod_ncparam, ONLY : NV, out_lib

  integer,                  intent(in   ) :: ng         !< nested grid number
  integer,                  intent(in   ) :: Nfiles     !< number of multi-files
  character (len=*),        intent(in   ) :: ncname     !< NetCDF file name
  TYPE (T_IO), allocatable, intent(inout) :: S(:)       !< IO structure

  integer                                 :: i, j, lstr

  ! Allocate structure according to the number of nested grids.

  IF (.not.allocated(S)) THEN
    allocate ( S(Ngrids) )
  END IF

  ! Allocate fields in the structure.

  DO i = 1, Ngrids
    IF (.not.associated(S(i)%Nrec))      allocate ( S(ng)%Nrec(Nfiles) )
    IF (.not.associated(S(i)%time_min))  allocate ( S(ng)%time_min(Nfiles) )
    IF (.not.associated(S(i)%time_max))  allocate ( S(ng)%time_max(Nfiles) )
    IF (.not.associated(S(i)%Vid))       allocate ( S(ng)%Vid(NV) )
    IF (.not.associated(S(i)%Tid))       allocate ( S(ng)%Tid(MT) )
#if defined PIO_LIB
    IF (.not.associated(S(i)%pioVar))    allocate ( S(ng)%pioVar(NV) )
    IF (.not.associated(S(i)%pioTrc))    allocate ( S(ng)%pioTrc(MT) )
#endif
    IF (.not.associated(S(i)%files))     allocate ( S(ng)%files(Nfiles) )
  END DO

  ! Initialize various fields.

  S(ng)%IOtype=out_lib                         ! file IO type
  S(ng)%Nfiles=Nfiles                          ! number of multi-files
  S(ng)%Fcount=1                               ! multi-file counter
  S(ng)%load=1                                 ! filename load counter
  S(ng)%Rindex=0                               ! time index
  S(ng)%ncid=-1                                ! closed NetCDF state
  S(ng)%Vid=-1                                 ! NetCDF variables IDs
  S(ng)%Tid=-1                                 ! NetCDF tracers IDs
#if defined PIO_LIB
  S(ng)%pioFile%fh=-1                          ! closed file handler
  DO i=1,NV
    S(ng)%pioVar(i)%vd%varID=-1                ! variables IDs
    S(ng)%pioVar(i)%dkind=-1                   ! variables data kind
    S(ng)%pioVar(i)%gtype=0                    ! variables C-grid type
  END DO
  DO i=1,MT
    S(ng)%pioTrc(i)%vd%varID=-1                ! tracers IDs
    S(ng)%pioTrc(i)%dkind=-1                   ! tracers data kind
    S(ng)%pioTrc(j)%gtype=0                    ! tracers C-grid type
  END DO
#endif

  i=0
  DO j=1,Nfiles
    i=i+1
    S(ng)%files(j)=TRIM(ncname)                ! load multi-files
    S(ng)%Nrec(j)=0                            ! record counter
    S(ng)%time_min(j)=0.0_kind_real            ! starting time
    S(ng)%time_max(j)=0.0_kind_real            ! ending time
  END DO
  S(ng)%label='ROMS-JEDI State Fields'         ! structure label
  S(ng)%name=TRIM(S(ng)%files(1))              ! current filename
  lstr=LEN_TRIM(S(ng)%name)
  S(ng)%head=S(ng)%name(1:lstr-3)              ! head filename (without  ".nc")
  S(ng)%base=S(ng)%name(1:lstr-3)              ! base filename (without  ".nc")

END SUBROUTINE roms_IOstruct

! ------------------------------------------------------------------------------
!> Deallocates and initalize ROMS T_IO type structure.

SUBROUTINE roms_IOstruct_delete (S)

  USE mod_param,   ONLY : Ngrids, T_IO

  TYPE (T_IO), allocatable, intent(inout) :: S(:)       !< IO structure

  integer                                 :: ng

  ! Deallocate fields in the structure.

  DO ng = 1, Ngrids
    IF (associated(S(ng)%Nrec))     deallocate (S(ng)%Nrec)
    IF (associated(S(ng)%time_min)) deallocate (S(ng)%time_min)
    IF (associated(S(ng)%time_max)) deallocate (S(ng)%time_max)
    IF (associated(S(ng)%Vid))      deallocate (S(ng)%Vid)
    IF (associated(S(ng)%Tid))      deallocate (S(ng)%Tid)
#if defined PIO_LIB
    IF (associated(S(ng)%pioVar))   deallocate (S(ng)%pioVar)
    IF (associated(S(ng)%pioTrc))   deallocate (S(ng)%pioTrc)
#endif
    IF (associated(S(ng)%files))    deallocate (S(ng)%files)
  END DO

  ! Deallocate structure.

  IF (allocated(S))                 deallocate (S)

END SUBROUTINE roms_IOstruct_delete

! ------------------------------------------------------------------------------
!> Closes state NetCDF file from IO structure.

SUBROUTINE roms_close_ncfile (ng, model, S)

  USE mod_param,      ONLY : T_IO
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

SUBROUTINE roms_create_ncfile (ng, model, LocalPET, S)

  USE mod_param,   ONLY : T_IO
  USE mod_ncparam, ONLY : io_nf90, io_pio

  integer,      intent(in   ) :: ng           !< nested grid number
  integer,      intent(in   ) :: model        !< ROMS numerical kernel
  integer,      intent(in   ) :: LocalPET     !< PET rank
  TYPE (T_IO),  intent(inout) :: S(:)         !< ROMS I/O structure

  character (len=256)         :: text

  SELECT CASE (S(ng)%IOtype)

    CASE (io_nf90)
      CALL roms_create_ncfile_nf90 (ng, model, LocalPET, S)

#if defined PIO_LIB
    CASE (io_pio)
      CALL roms_create_ncfile_pio (ng, model, LocalPET, S)
#endif

    CASE DEFAULT
      WRITE (text,'(a,i0)') &
                  'roms_create_ncfile: Ilegal output type, io_type = ',      &
                  S(ng)%IOtype
      CALL abor1_ftn (TRIM(text))

  END SELECT

END SUBROUTINE roms_create_ncfile

! ------------------------------------------------------------------------------
!> Creates output state file using the standard NetCDF library.

SUBROUTINE roms_create_ncfile_nf90 (ng, model, LocalPET, S)

  USE mod_param
  USE mod_parallel
  USE mod_ncparam
  USE mod_netcdf
  USE mod_scalars

  USE def_dim_mod,  ONLY : def_dim
  USE def_info_mod, ONLY : def_info
  USE def_var_mod,  ONLY : def_var
  USE wrt_info_mod, ONLY : wrt_info

  integer,       intent(in   ) :: ng           !< nested grid number
  integer,       intent(in   ) :: model        !< ROMS numerical kernel
  integer,       intent(in   ) :: LocalPET     !< PET rank
  TYPE (T_IO),   intent(inout) :: S(:)         !< ROMS I/O structure

  integer                      :: itrc
  integer                      :: DimIDs(nDimID)
  integer                      :: r2dgrd(3), u2dgrd(3), v2dgrd(3)
  integer                      :: r3dgrd(4), u3dgrd(4), v3dgrd(4)
  real (kind=kind_real)        :: Aval(6)
  character (len=120)          :: Vinfo(25)
  character (len=256)          :: ncname
  character (len=1024)         :: Message

  character (len=*), parameter :: MyFile =                                   &
     __FILE__//", roms_create_ncfile_nf90"

  ! Initialize

  DimIDs = 0
  Aval   = 0.0_kind_real
  Vinfo  = CHAR(32)                !> blank space

  ncname = S(ng)%name

  ! Create NetCDF file.

  CALL netcdf_create (ng, model, TRIM(ncname), S(ng)%ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  ! Define file dimensions.

  CALL nc_err (def_dim(ng, model, S(ng)%ncid, ncname, 'xi_rho',              &
                       IOBOUNDS(ng)%xi_rho, DimIDs( 1)),                     &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%ncid, ncname, 'xi_u',                &
                       IOBOUNDS(ng)%xi_u, DimIDs( 2)),                       &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%ncid, ncname, 'xi_v',                &
                       IOBOUNDS(ng)%xi_v, DimIDs( 3)),                       &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%ncid, ncname, 'xi_psi',              &
                       IOBOUNDS(ng)%xi_psi, DimIDs( 4)),                     &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%ncid, ncname, 'eta_rho',             &
                       IOBOUNDS(ng)%eta_rho, DimIDs( 5)),                    &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%ncid, ncname, 'eta_u',               &
                       IOBOUNDS(ng)%eta_u, DimIDs( 6)),                      &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%ncid, ncname, 'eta_v',               &
                       IOBOUNDS(ng)%eta_v, DimIDs( 7)),                      &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%ncid, ncname, 'N',                   &
                       N(ng), DimIDs( 9)),                                   &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%ncid, ncname, 's_rho',               &
                       N(ng), DimIDs( 9)),                                   &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%ncid, ncname, 's_w',                 &
                       N(ng)+1, DimIDs(10)),                                 &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%ncid, ncname, 'tracer',              &
                       NT(ng), DimIDs(11)),                                  &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%ncid, ncname,                        &
                       TRIM(ADJUSTL(Vname(5,idtime))),                       &
                       nf90_unlimited, DimIDs(12)),                          &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  ! Set dimension vector for each C-grid location.

  r2dgrd = (/ DimIDs(1), DimIDs(5), DimIDs(12) /)
  u2dgrd = (/ DimIDs(2), DimIDs(6), DimIDs(12) /)
  v2dgrd = (/ DimIDs(3), DimIDs(7), DimIDs(12) /)

  r3dgrd = (/ DimIDs(1), DimIDs(5), DimIDs(9), DimIDs(12) /)
  u3dgrd = (/ DimIDs(2), DimIDs(6), DimIDs(9), DimIDs(12) /) 
  v3dgrd = (/ DimIDs(3), DimIDs(7), DimIDs(9), DimIDs(12) /)

  ! Define time-recordless information variables.

  CALL roms_def_info_nf90 (ng, model, LocalPET, S(ng)%ncid,                   &
                           DimIDs, ncname)

  ! Define model time.

  Vinfo( 1)=Vname(1,idtime)
  Vinfo( 2)=Vname(2,idtime)
  WRITE (Vinfo( 3),'(a,a)') 'seconds since ', TRIM(Rclock%string)
  Vinfo( 4)=TRIM(Rclock%calendar)
  CALL nc_err (def_var(ng, model, S(ng)%ncid, S(ng)%Vid(idtime),             &
                       NF_TOUT, 1, (/DimIDs(12)/), Aval, Vinfo,              &
                       ncname, SetParAccess = .TRUE.),                       &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  ! Define free-surface.

  Vinfo( 1)=Vname(1,idFsur)
  Vinfo( 2)=Vname(2,idFsur)
  Vinfo( 3)=Vname(3,idFsur)
  Vinfo(16)=Vname(1,idtime)
  Vinfo(22)='coordinates'
  Aval(5)=REAL(Iinfo(1,idFsur,ng),r8)

  CALL nc_err (def_var(ng, model, S(ng)%ncid, S(ng)%Vid(idFsur),             &
                       NF_FOUT, 3, r2dgrd, Aval, Vinfo, ncname),             &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  ! Define 2D U-momentum component.

  Vinfo( 1)=Vname(1,idUbar)
  Vinfo( 2)=Vname(2,idUbar)
  Vinfo( 3)=Vname(3,idUbar)
  Vinfo(16)=Vname(1,idtime)
  Vinfo(22)='coordinates'
  Aval(5)=REAL(Iinfo(1,idUbar,ng),r8)

  CALL nc_err (def_var(ng, model, S(ng)%ncid, S(ng)%Vid(idUbar),             &
                       NF_FOUT, 3, u2dgrd, Aval, Vinfo, ncname),             &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  ! Define 2D V-momentum component.

  Vinfo( 1)=Vname(1,idVbar)
  Vinfo( 2)=Vname(2,idVbar)
  Vinfo( 3)=Vname(3,idVbar)
  Vinfo(14)=Vname(4,idVbar)
  Vinfo(16)=Vname(1,idtime)
  Vinfo(22)='coordinates'
  Aval(5)=REAL(Iinfo(1,idVbar,ng),r8)

  CALL nc_err (def_var(ng, model, S(ng)%ncid, S(ng)%Vid(idVbar),              &
                       NF_FOUT, 3, v2dgrd, Aval, Vinfo, ncname),              &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  ! Define 3D U-momentum component.

  Vinfo( 1)=Vname(1,idUvel)
  Vinfo( 2)=Vname(2,idUvel)
  Vinfo( 3)=Vname(3,idUvel)
  Vinfo(16)=Vname(1,idtime)
  Vinfo(22)='coordinates'
  Aval(5)=REAL(Iinfo(1,idUvel,ng),r8)
  CALL nc_err (def_var(ng, model, S(ng)%ncid, S(ng)%Vid(idUvel),              &
                       NF_FOUT, 4, u3dgrd, Aval, Vinfo, ncname),              &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  ! Define 3D V-momentum component.

  Vinfo( 1)=Vname(1,idVvel)
  Vinfo( 2)=Vname(2,idVvel)
  Vinfo( 3)=Vname(3,idVvel)
  Vinfo(16)=Vname(1,idtime)
  Vinfo(22)='coordinates'
  Aval(5)=REAL(Iinfo(1,idVvel,ng),r8)
  CALL nc_err (def_var(ng, model, S(ng)%ncid, S(ng)%Vid(idVvel),              &
                       NF_FOUT, 4, v3dgrd, Aval, Vinfo, ncname),              &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  ! Define tracer type variables.

  DO itrc=1,NT(ng)
    Vinfo( 1)=Vname(1,idTvar(itrc))
    Vinfo( 2)=Vname(2,idTvar(itrc))
    Vinfo( 3)=Vname(3,idTvar(itrc))
    Vinfo(16)=Vname(1,idtime)
    Vinfo(22)='coordinates'
    Aval(5)=REAL(r3dvar,r8)

    CALL nc_err (def_var(ng, model, S(ng)%ncid, S(ng)%Tid(itrc),             &
                         NF_FOUT, 4, r3dgrd, Aval, Vinfo, ncname),           &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END DO

  ! Leave definition mode.

  CALL netcdf_enddef (ng, model, ncname, S(ng)%ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
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

  character (len=*),  parameter :: MyFile =                                  &
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
    status=nf90_put_att(ncid, nf90_global, 'file',                           &
                        TRIM(ncname))

    status=nf90_put_att(ncid, nf90_global, 'Conventions',                    &
                            'CF-1.4, SGRID-0.3')

    status=nf90_put_att(ncid, nf90_global, 'type',                           &
                        'ROMS-JEDI state fields file')

    status=nf90_put_att(ncid, nf90_global, 'title',                          &
                        TRIM(title))

    status=nf90_put_att(ncid, nf90_global, 'var_info',                       &
                        TRIM(varname))

    status=nf90_put_att(ncid, nf90_global, 'grd_file',                       &
                        TRIM(GRD(ng)%name))

    status=nf90_put_att(ncid, nf90_global, 'script_file',                    &
                        TRIM(Iname))

    WRITE (text,'(i0,a,i0)') NtileI(ng), 'x', NtileJ(ng)
    status=nf90_put_att(ncid, nf90_global, 'tiling',                         &
                        TRIM(text))

    IF (LEN_TRIM(date_str).gt.0) THEN
      WRITE (text,'(a,1x,a,", ",a)') 'ROMS, Version', TRIM(version),         &
                                     TRIM(date_str)
    ELSE
      WRITE (text,'(a,1x,a)') 'ROMS, Version', TRIM(version)
    END IF
    status=nf90_put_att(ncid, nf90_global, 'history',                        &
                        TRIM(text))
  END IF

  ! Define grid variables.

  Vinfo( 1)='spherical'
  Vinfo( 2)='grid type logical switch'
  Vinfo( 9)='Cartesian'
  Vinfo(10)='spherical'
  CALL nc_err (def_var(ng, model, ncid, varid, nf90_int,                     &
                       1, (/0/), Aval, Vinfo, ncname,                        &
                       SetParAccess = .FALSE.),                              &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  ! S-coordinate parameters.

  Vinfo( 1)='Vtransform'
  Vinfo( 2)='vertical terrain-following transformation equation'
  CALL nc_err (def_var(ng, model, ncid, varid, nf90_int,                     &
                       1, (/0/), Aval, Vinfo, ncname,                        &
                       SetParAccess = .FALSE.),                              &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  Vinfo( 1)='Vstretching'
  Vinfo( 2)='vertical terrain-following stretching function'
  CALL nc_err (def_var(ng, model, ncid, varid, nf90_int,                     &
                       1, (/0/), Aval, Vinfo, ncname,                        &
                       SetParAccess = .FALSE.),                              &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  Vinfo( 1)='theta_s'
  Vinfo( 2)='S-coordinate surface control parameter'
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TOUT,                      &
                       1, (/0/), Aval, Vinfo, ncname,                        &
                       SetParAccess = .FALSE.),                              &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  Vinfo( 1)='theta_b'
  Vinfo( 2)='S-coordinate bottom control parameter'
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TOUT,                      &
                       1, (/0/), Aval, Vinfo, ncname,                        &
                       SetParAccess = .FALSE.),                              &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  Vinfo( 1)='Tcline'
  Vinfo( 2)='S-coordinate surface/bottom layer width'
  Vinfo( 3)='meter'
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TOUT,                      &
                       1, (/0/), Aval, Vinfo, ncname,                        &
                       SetParAccess = .FALSE.),                              &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  Vinfo( 1)='hc'
  Vinfo( 2)='S-coordinate parameter, critical depth'
  Vinfo( 3)='meter'
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TOUT,                      &
                       1, (/0/), Aval, Vinfo, ncname,                        &
                       SetParAccess = .FALSE.),                              &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  Vinfo( 1)='grid'
  CALL nc_err (def_var(ng, model, ncid, varid, nf90_int,                     &
                       1, (/0/), Aval, Vinfo, ncname,                        &
                       SetParAccess = .FALSE.),                              &
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
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TOUT,                      &
                       1, (/DimIDs(9)/), Aval, Vinfo, ncname,                &
                       SetParAccess = .FALSE.),                              &
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
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TOUT,                      &
                       1, (/DimIDs(10)/), Aval, Vinfo, ncname,               &
                       SetParAccess = .FALSE.),                              &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  ! S-coordinate non-dimensional stretching curves at RHO-points.

  Vinfo( 1)='Cs_r'
  Vinfo( 2)='S-coordinate stretching curves at RHO-points'
  Vinfo( 5)='valid_min'
  Vinfo( 6)='valid_max'
  Aval(2)=-1.0_r8
  Aval(3)=0.0_r8
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TOUT,                      &
                       1, (/DimIDs(9)/), Aval, Vinfo, ncname,                &
                       SetParAccess = .FALSE.),                              &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  ! S-coordinate non-dimensional stretching curves at W-points.

  Vinfo( 1)='Cs_w'
  Vinfo( 2)='S-coordinate stretching curves at W-points'
  Vinfo( 5)='valid_min'
  Vinfo( 6)='valid_max'
  Aval(2)=-1.0_r8
  Aval(3)=0.0_r8
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TOUT,                      &
                       1, (/DimIDs(10)/), Aval, Vinfo, ncname,               &
                       SetParAccess = .FALSE.),                              &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  ! Bathymetry.

  Vinfo( 1)='h'
  Vinfo( 2)='bathymetry at RHO-points'
  Vinfo( 3)='meter'
  Vinfo(22)='coordinates'
  Aval(5)=REAL(r2dvar,r8)
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TYPE,                      &
                       2, r2dgrd, Aval, Vinfo, ncname),                      &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  ! Grid coordinates of RHO-points.

  Vinfo( 1)='lon_rho'
  Vinfo( 2)='longitude of RHO-points'
  Vinfo( 3)='degree_east'
  Vinfo(21)='longitude'
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TYPE,                      &
                       2, r2dgrd, Aval, Vinfo, ncname),                      &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  Vinfo( 1)='lat_rho'
  Vinfo( 2)='latitude of RHO-points'
  Vinfo( 3)='degree_north'
  Vinfo(21)='latitude'
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TYPE,                      &
                       2, r2dgrd, Aval, Vinfo, ncname),                      &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  ! Grid coordinates of U-points.

  Vinfo( 1)='lon_u'
  Vinfo( 2)='longitude of U-points'
  Vinfo( 3)='degree_east'
  Vinfo(21)='longitude'
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TYPE,                      &
                       2, u2dgrd, Aval, Vinfo, ncname),                      &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  Vinfo( 1)='lat_u'
  Vinfo( 2)='latitude of U-points'
  Vinfo( 3)='degree_north'
  Vinfo(21)='latitude'
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TYPE,                      &
                       2, u2dgrd, Aval, Vinfo, ncname),                      &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  ! Grid coordinates of V-points.

  Vinfo( 1)='lon_v'
  Vinfo( 2)='longitude of V-points'
  Vinfo( 3)='degree_east'
  Vinfo(21)='longitude'
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TYPE,                      &
                       2, v2dgrd, Aval, Vinfo, ncname),                      &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  Vinfo( 1)='lat_v'
  Vinfo( 2)='latitude of V-points'
  Vinfo( 3)='degree_north'
  Vinfo(21)='latitude'
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TYPE,                      &
                       2, v2dgrd, Aval, Vinfo, ncname),                      &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  ! Angle between XI-axis and EAST at RHO-points.

  Vinfo( 1)='angle'
  Vinfo( 2)='angle between XI-axis and EAST'
  Vinfo( 3)='radians'
  Vinfo(22)='coordinates'
  Aval(5)=REAL(r2dvar,r8)
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TYPE,                      &
                       2, r2dgrd, Aval, Vinfo, ncname),                      &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  !  Masking fields at RHO-, U-, and V-points.

  Vinfo( 1)='mask_rho'
  Vinfo( 2)='mask on RHO-points'
  Vinfo( 9)='land'
  Vinfo(10)='water'
  Vinfo(22)='coordinates'
  Aval(5)=REAL(r2dvar,r8)
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TYPE,                      &
                       2, r2dgrd, Aval, Vinfo, ncname),                      &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  Vinfo( 1)='mask_u'
  Vinfo( 2)='mask on U-points'
  Vinfo( 9)='land'
  Vinfo(10)='water'
  Vinfo(22)='coordinates'
  Aval(5)=REAL(u2dvar,r8)
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TYPE,                      &
                       2, u2dgrd, Aval, Vinfo, ncname),                      &
               nf90_noerr, io_nf90, __LINE__, MyFile)

  Vinfo( 1)='mask_v'
  Vinfo( 2)='mask on V-points'
  Vinfo( 9)='land'
  Vinfo(10)='water'
  Vinfo(22)='coordinates'
  Aval(5)=REAL(v2dvar,r8)
  CALL nc_err (def_var(ng, model, ncid, varid, NF_TYPE,                      &
                       2, v2dgrd, Aval, Vinfo, ncname),                      &
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

  character (len=*),  parameter :: MyFile =                                  &
     &  __FILE__//", roms_wrt_info_nf90"

  ! Initialize

  LBi=LBOUND(GRID(ng)%h,DIM=1)
  UBi=UBOUND(GRID(ng)%h,DIM=1)
  LBj=LBOUND(GRID(ng)%h,DIM=2)
  UBj=UBOUND(GRID(ng)%h,DIM=2)

  !  Inquire about the variables.

  CALL netcdf_inq_var (ng, model, ncname, ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  ! Write out grid variables.

  CALL netcdf_put_lvar (ng, model, ncname, 'spherical',                      &
                        spherical, (/0/), (/0/),                             &
                        ncid = ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  ! S-coordinate parameters.

  CALL netcdf_put_ivar (ng, model, ncname, 'Vtransform',                     &
                        Vtransform(ng), (/0/), (/0/),                        &
                        ncid = ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  CALL netcdf_put_ivar (ng, model, ncname, 'Vstretching',                    &
                        Vstretching(ng), (/0/), (/0/),                       &
                        ncid = ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  CALL netcdf_put_fvar (ng, model, ncname, 'theta_s',                        &
                        theta_s(ng), (/0/), (/0/),                           &
                        ncid = ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  CALL netcdf_put_fvar (ng, model, ncname, 'theta_b',                        &
                        theta_b(ng), (/0/), (/0/),                           &
                        ncid = ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  CALL netcdf_put_fvar (ng, model, ncname, 'Tcline',                         &
                        Tcline(ng), (/0/), (/0/),                            &
                        ncid = ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  CALL netcdf_put_fvar (ng, model, ncname, 'hc',                             &
                        hc(ng), (/0/), (/0/),                                &
                        ncid = ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  CALL netcdf_put_ivar (ng, model, ncname, 'grid',                           &
                        (/1/), (/0/), (/0/),                                 &
                        ncid = ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  ! S-coordinate non-dimensional independent variables.

  CALL netcdf_put_fvar (ng, model, ncname, 's_rho',                          &
                        SCALARS(ng)%sc_r(:), (/1/), (/N(ng)/),               &
                        ncid = ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  CALL netcdf_put_fvar (ng, model, ncname, 's_w',                            &
                        SCALARS(ng)%sc_w(0:), (/1/), (/N(ng)+1/),            &
                        ncid = ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  ! S-coordinate non-dimensional stretching curves.

  CALL netcdf_put_fvar (ng, model, ncname, 'Cs_r',                           &
                        SCALARS(ng)%Cs_r(:), (/1/), (/N(ng)/),               &
                        ncid = ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  CALL netcdf_put_fvar (ng, model, ncname, 'Cs_w',                           &
                        SCALARS(ng)%Cs_w(0:), (/1/), (/N(ng)+1/),            &
                        ncid = ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  ! Bathymetry.

  IF (find_string(var_name, n_var, 'h', varid)) THEN
    scale=1.0_kind_real
    CALL nc_err (nf_fwrite2d(ng, model, ncid, varid, 0, r2dvar,              &
                             LBi, UBi, LBj, UBj, scale,                      &
                             GRID(ng) % rmask,                               &
                             GRID(ng) % h,                                   &
                             SetFillVal = .FALSE.),                          &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  !  Grid coordinates of RHO-points.

  IF (find_string(var_name, n_var, 'lon_rho', varid)) THEN
    scale=1.0_kind_real
    CALL nc_err (nf_fwrite2d(ng, model, ncid, varid, 0, r2dvar,              &
                             LBi, UBi, LBj, UBj, scale,                      &
                             GRID(ng) % rmask,                               &
                             GRID(ng) % lonr,                                &
                             SetFillVal = .FALSE.),                          &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  IF (find_string(var_name, n_var, 'lat_rho', varid)) THEN
    scale=1.0_kind_real
    CALL nc_err (nf_fwrite2d(ng, model, ncid, varid, 0, r2dvar,              &
                             LBi, UBi, LBj, UBj, scale,                      &
                             GRID(ng) % rmask,                               &
                             GRID(ng) % latr,                                &
                             SetFillVal = .FALSE.),                          &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  ! Grid coordinates of U-points.

  IF (find_string(var_name, n_var, 'lon_u', varid)) THEN
    scale=1.0_kind_real
    CALL nc_err (nf_fwrite2d(ng, model, ncid, varid, 0, u2dvar,              &
                             LBi, UBi, LBj, UBj, scale,                      &
                             GRID(ng) % umask,                               &
                             GRID(ng) % lonu,                                &
                             SetFillVal = .FALSE.),                          &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  IF (find_string(var_name, n_var, 'lat_u', varid)) THEN
    scale=1.0_dp
    CALL nc_err (nf_fwrite2d(ng, model, ncid, varid, 0, u2dvar,              &
                             LBi, UBi, LBj, UBj, scale,                      &
                             GRID(ng) % umask,                               &
                             GRID(ng) % latu,                                &
                             SetFillVal = .FALSE.),                          &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  ! Grid coordinates of V-points.

  IF (find_string(var_name, n_var, 'lon_v', varid)) THEN
    scale=1.0_kind_real
    CALL nc_err (nf_fwrite2d(ng, model, ncid, varid, 0, v2dvar,              &
                             LBi, UBi, LBj, UBj, scale,                      &
                             GRID(ng) % vmask,                               &
                             GRID(ng) % lonv,                                &
                             SetFillVal = .FALSE.),                          &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  IF (find_string(var_name, n_var, 'lat_v', varid)) THEN
    scale=1.0_kind_real
    CALL nc_err (nf_fwrite2d(ng, model, ncid, varid, 0, v2dvar,              &
                             LBi, UBi, LBj, UBj, scale,                      &
                             GRID(ng) % vmask,                               &
                             GRID(ng) % latv,                                &
                             SetFillVal = .FALSE.),                          &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  ! Angle between XI-axis and EAST at RHO-points.

  IF (find_string(var_name, n_var, 'angle', varid)) THEN
    scale=1.0_kind_real
    CALL nc_err (nf_fwrite2d(ng, model, ncid, varid, 0, r2dvar,              &
                             LBi, UBi, LBj, UBj, scale,                      &
                             GRID(ng) % rmask,                               &
                             GRID(ng) % angler,                              &
                             SetFillVal = .FALSE.),                          &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  ! Masking fields at RHO-, U-, and V-points.

  IF (find_string(var_name, n_var, 'mask_rho', varid)) THEN
    scale=1.0_kind_real
    CALL nc_err (nf_fwrite2d(ng, model, ncid, varid, 0, r2dvar,              &
                             LBi, UBi, LBj, UBj, scale,                      &
                             GRID(ng) % rmask,                               &
                             GRID(ng) % rmask,                               &
                             SetFillVal = .FALSE.),                          &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  IF (find_string(var_name, n_var, 'mask_u', varid)) THEN
    scale=1.0_kind_real
    CALL nc_err (nf_fwrite2d(ng, model, ncid, varid, 0, u2dvar,              &
                             LBi, UBi, LBj, UBj, scale,                      &
                             GRID(ng) % umask,                               &
                             GRID(ng) % umask,                               &
                             SetFillVal = .FALSE.),                          &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  IF (find_string(var_name, n_var, 'mask_v', varid)) THEN
    scale=1.0_kind_real
    CALL nc_err (nf_fwrite2d(ng, model, ncid, varid, 0, v2dvar,              &
                             LBi, UBi, LBj, UBj, scale,                      &
                             GRID(ng) % vmask,                               &
                             GRID(ng) % vmask,                               &
                             SetFillVal = .FALSE.),                          &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

END SUBROUTINE roms_wrt_info_nf90

# if defined PIO_LIB

! ------------------------------------------------------------------------------
!> Creates output state file using the Paralell-IO (PIO) library.

SUBROUTINE roms_create_ncfile_pio (ng, model, LocalPET, S)

  USE mod_param
  USE mod_ncparam
  USE mod_pio_netcdf
  USE mod_scalars

  USE def_dim_mod,  ONLY : def_dim
  USE def_info_mod, ONLY : def_info
  USE def_var_mod,  ONLY : def_var
  USE wrt_info_mod, ONLY : wrt_info

  integer,              intent(in) :: ng           !< nested grid number
  integer,              intent(in) :: model        !< ROMS numerical kernel
  integer,              intent(in) :: LocalPET     !< PET rank
  character (len=*),    intent(in) :: ncname       !< NetCDF filename
  TYPE (T_IO),       intent(inout) :: S(:)         !< ROMS I/O structure

  integer                          :: itrc
  integer                          :: DimIDs(nDimID)
  integer                          :: r2dgrd(3), u2dgrd(3), v2dgrd(3)
  integer                          :: r3dgrd(4), u3dgrd(4), v3dgrd(4)
  real (kind=kind_real)            :: Aval(6)
  character (len=120)              :: Vinfo(25)
  character (len=256)              :: ncname
  character (len=1024)             :: Message

  character (len=*),     parameter :: MyFile =                               &
     __FILE__//", roms_create_ncfile_pio"

  ! Initialize.

  DimIDs = 0
  Aval   = 0.0_kind_real
  Vinfo  = CHAR(32)                !< blank space

  ncname = S(ng)%ncname

  ! Create NetCDF file.

  CALL pio_netcdf_create (ng, model, TRIM(ncname), S(ng)%pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  ! Define file dimensions.

  CALL nc_err (def_dim(ng, model, S(ng)%pioFile, ncname, 'xi_rho',           &
                       IOBOUNDS(ng)%xi_rho, DimIDs( 1)),                     &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%pioFile, ncname, 'xi_u',             &
                       IOBOUNDS(ng)%xi_u, DimIDs( 2)),                       &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%pioFile, ncname, 'xi_v',             &
                       IOBOUNDS(ng)%xi_v, DimIDs( 3)),                       &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%pioFile, ncname, 'xi_psi',           &
                       IOBOUNDS(ng)%xi_psi, DimIDs( 4)),                     &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%pioFile, ncname, 'eta_rho',          &
                       IOBOUNDS(ng)%eta_rho, DimIDs( 5)),                    &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%pioFile, ncname, 'eta_u',            &
                       IOBOUNDS(ng)%eta_u, DimIDs( 6)),                      &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%pioFile, ncname, 'eta_v',            &
                       IOBOUNDS(ng)%eta_v, DimIDs( 7)),                      &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%pioFile, ncname, 'N',                &
                       N(ng), DimIDs( 9)),                                   &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%pioFile, ncname, 's_rho',            &
                       N(ng), DimIDs( 9)),                                   &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%pioFile, ncname, 's_w',              &
                       N(ng)+1, DimIDs(10)),                                 &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%pioFile, ncname, 'tracer',           &
                       NT(ng), DimIDs(11)),                                  &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (def_dim(ng, model, S(ng)%pioFile, ncname,                     &
                       TRIM(ADJUSTL(Vname(5,idtime))),                       &
                       nf90_unlimited, DimIDs(12)),                          &
               PIO_noerr, io_pio, __LINE__, MyFile)

  ! Set dimension vector for each C-grid location.

  r2dgrd = (/ DimIDs(1), DimIDs(5), DimIDs(12) /)
  u2dgrd = (/ DimIDs(2), DimIDs(6), DimIDs(12) /)
  v2dgrd = (/ DimIDs(3), DimIDs(7), DimIDs(12) /)

  r3dgrd = (/ DimIDs(1), DimIDs(5), DimIDs(9), DimIDs(12) /)
  u3dgrd = (/ DimIDs(2), DimIDs(6), DimIDs(9), DimIDs(12) /) 
  v3dgrd = (/ DimIDs(3), DimIDs(7), DimIDs(9), DimIDs(12) /)

  ! Define time-recordless information variables.

  CALL roms_def_info_pio (ng, model, localPET, S(ng)%pioFile,                &
                          DimIDs, ncname)

  ! Define model time.

  Vinfo( 1)=Vname(1,idtime)
  Vinfo( 2)=Vname(2,idtime)
  WRITE (Vinfo( 3),'(a,a)') 'seconds since ', TRIM(Rclock%string)
  Vinfo( 4)=TRIM(Rclock%calendar)
  S(ng)%pioVar(idtime)%dkind=PIO_TOUT
  S(ng)%pioVar(idtime)%gtype=0
  CALL nc_err (def_var(ng, model, S(ng)%pioFile,                             &
                       S(ng)%pioVar(idtime)%vd,                              &
                       PIO_TOUT, 1, (/DimIDs(12)/), Aval, Vinfo,             &
                       ncname, SetParAccess = .TRUE.),                       &
               PIO_noerr, io_pio, __LINE__, MyFile)

  ! Define free-surface.

  Vinfo( 1)=Vname(1,idFsur)
  Vinfo( 2)=Vname(2,idFsur)
  Vinfo( 3)=Vname(3,idFsur)
  Vinfo(16)=Vname(1,idtime)
  Vinfo(22)='coordinates'
  Aval(5)=REAL(Iinfo(1,idFsur,ng),r8)
  S(ng)%pioVar(idFsur)%dkind=PIO_FOUT
  S(ng)%pioVar(idFsur)%gtype=r2dvar
  CALL nc_err (def_var(ng, model, S(ng)%pioFile,                             &
                       S(ng)%pioVar(idFsur)%vd,                              & 
                       PIO_FOUT, 3, r2dgrd, Aval, Vinfo, ncname),            &
               PIO_noerr, io_pio, __LINE__, MyFile)

  ! Define 2D U-momentum component.

  Vinfo( 1)=Vname(1,idUbar)
  Vinfo( 2)=Vname(2,idUbar)
  Vinfo( 3)=Vname(3,idUbar)
  Vinfo(16)=Vname(1,idtime)
  Vinfo(22)='coordinates'
  Aval(5)=REAL(Iinfo(1,idUbar,ng),r8)
  S(ng)%pioVar(idUbar)%dkind=PIO_FOUT
  S(ng)%pioVar(idUbar)%gtype=u2dvar
  CALL nc_err (def_var(ng, model, S(ng)%pioFile,                             &
                       S(ng)%pioVar(idUbar)%vd,                              &
                       PIO_FOUT, 3, u2dgrd, Aval, Vinfo, ncname),            &
               PIO_noerr, io_pio, __LINE__, MyFile)

  ! Define 2D V-momentum component.

  Vinfo( 1)=Vname(1,idVbar)
  Vinfo( 2)=Vname(2,idVbar)
  Vinfo( 3)=Vname(3,idVbar)
  Vinfo(16)=Vname(1,idtime)
  Vinfo(22)='coordinates'
  Aval(5)=REAL(Iinfo(1,idVbar,ng),r8)
  S(ng)%pioVar(idVbar)%dkind=PIO_FOUT
  S(ng)%pioVar(idVbar)%gtype=v2dvar
  CALL nc_err (def_var(ng, model, S(ng)%pioFile,                             &
                       S(ng)%pioVar(idVbar)%vd,                              &
                       PIO_FOUT, 3, v2dgrd, Aval, Vinfo, ncname),            &
               PIO_noerr, io_pio, __LINE__, MyFile)

  ! Define 3D U-momentum component.

  Vinfo( 1)=Vname(1,idUvel)
  Vinfo( 2)=Vname(2,idUvel)
  Vinfo( 3)=Vname(3,idUvel)
  Vinfo(16)=Vname(1,idtime)
  Vinfo(22)='coordinates'
  Aval(5)=REAL(Iinfo(1,idUvel,ng),r8)
  S(ng)%pioVar(idUvel)%dkind=PIO_FOUT
  S(ng)%pioVar(idUvel)%gtype=u3dvar
  CALL nc_err (def_var(ng, model, S(ng)%pioFile,                             &
                       S(ng)%pioVar(idUvel)%vd,                              &
                       PIO_FOUT, 4, u3dgrd, Aval, Vinfo, ncname),            &
               PIO_noerr, io_pio, __LINE__, MyFile)

  ! Define 3D V-momentum component.

  Vinfo( 1)=Vname(1,idVvel)
  Vinfo( 2)=Vname(2,idVvel)
  Vinfo( 3)=Vname(3,idVvel)
  Vinfo(16)=Vname(1,idtime)
  Vinfo(22)='coordinates'
  Aval(5)=REAL(Iinfo(1,idVvel,ng),r8)
  S(ng)%pioVar(idVvel)%dkind=PIO_FOUT
  S(ng)%pioVar(idVvel)%gtype=v3dvar
  CALL nc_err (def_var(ng, model, S(ng)%pioFile,                              &
                       S(ng)%pioVar(ifield)%vd,                               &
                       PIO_FOUT, 4, v3dgrd, Aval, Vinfo, ncname),             &
               PIO_noerr, io_pio, __LINE__, MyFile)

  ! Define tracer type variables.

  DO itrc=1,NT(ng)
    Vinfo( 1)=Vname(1,idTvar(itrc))
    Vinfo( 2)=Vname(2,idTvar(itrc))
    Vinfo( 3)=Vname(3,idTvar(itrc))
    Vinfo(16)=Vname(1,idtime)
    Vinfo(22)='coordinates'
    Aval(5)=REAL(r3dvar,r8)
    S(ng)%pioTrc(itrc)%dkind=PIO_FOUT
    S(ng)%pioTrc(itrc)%gtype=r3dvar
    CALL nc_err (def_var(ng, model, S(ng)%pioFile,                           &
                         S(ng)%pioTrc(itrc)%vd,                              &
                         PIO_FOUT, 4, r3dgrd, Aval, Vinfo, ncname),          &
                 PIO_noerr, io_pio, __LINE__, MyFile)
  END DO

  ! Leave definition mode.

  CALL pio_netcdf_enddef (ng, model, ncname, S(ng)%pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
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

  character (len=*),   parameter :: MyFile =                                 &
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

  CALL nc_err (PIO_put_att(pioFile, PIO_global, 'file',                      &
                           TRIM(ncname)),                                    &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (PIO_put_att(pioFile, PIO_global, 'Conventions',               &
                           'CF-1.4, SGRID-0.3'),                             &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (PIO_put_att(pioFile, PIO_global, 'type',                      &
                           'ROMS-JEDI state fields file'),                   &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (PIO_put_att(pioFile, PIO_global, 'title',                     &
                           TRIM(title)),                                     &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (PIO_put_att(pioFile, PIO_global, 'var_info',                  &
                           TRIM(varname)),                                   &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (PIO_put_att(pioFile, PIO_global, 'grd_file',                  &
                           TRIM(GRD(ng)%name)),                              &
               PIO_noerr, io_pio, __LINE__, MyFile)

  CALL nc_err (PIO_put_att(pioFile, PIO_global, 'script_file',               &
                           TRIM(Iname)),                                     &
               PIO_noerr, io_pio, __LINE__, MyFile)

  WRITE (text,'(i0,a,i0)') NtileI(ng), 'x', NtileJ(ng)
  CALL nc_err (PIO_put_att(pioFile, PIO_global, 'tiling',                    &
                           TRIM(text)),                                      &
               PIO_noerr, io_pio, __LINE__, MyFile)

  IF (LEN_TRIM(date_str).gt.0) THEN
    WRITE (text,'(a,1x,a,", ",a)') 'ROMS, Version', TRIM(version),           &
                                   TRIM(date_str)
  ELSE
    WRITE (test,'(a,1x,a)') 'ROMS, Version', TRIM(version)
  END IF
  CALL nc_err (PIO_put_att(pioFile, PIO_global, 'history',                   &
                           TRIM(text)),                                      &
               PIO_noerr, io_pio, __LINE__, MyFile)

  ! Define grid variables.

  Vinfo( 1)='spherical'
  Vinfo( 2)='grid type logical switch'
  Vinfo( 9)='Cartesian'
  Vinfo(10)='spherical'
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_int,                  &
                       1, (/0/), Aval, Vinfo, ncname,                        &
                       SetParAccess = .FALSE.),                              &
               PIO_noerr, io_pio, __LINE__, MyFile)

  ! S-coordinate parameters.

  Vinfo( 1)='Vtransform'
  Vinfo( 2)='vertical terrain-following transformation equation'
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_int,                  &
                       1, (/0/), Aval, Vinfo, ncname,                        &
                       SetParAccess = .FALSE.),                              &
               PIO_noerr, io_pio, __LINE__, MyFile)

  Vinfo( 1)='Vstretching'
  Vinfo( 2)='vertical terrain-following stretching function'
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_int,                  &
                       1, (/0/), Aval, Vinfo, ncname,                        &
                       SetParAccess = .FALSE.),                              &
               PIO_noerr, io_pio, __LINE__, MyFile)

  Vinfo( 1)='theta_s'
  Vinfo( 2)='S-coordinate surface control parameter'
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TOUT,                 &
                       1, (/0/), Aval, Vinfo, ncname,                        &
                       SetParAccess = .FALSE.),                              &
               PIO_noerr, io_pio, __LINE__, MyFile)

  Vinfo( 1)='theta_b'
  Vinfo( 2)='S-coordinate bottom control parameter'
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TOUT,                 &
                       1, (/0/), Aval, Vinfo, ncname,                        &
                       SetParAccess = .FALSE.),                              &
               PIO_noerr, io_pio, __LINE__, MyFile)

  Vinfo( 1)='Tcline'
  Vinfo( 2)='S-coordinate surface/bottom layer width'
  Vinfo( 3)='meter'
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TOUT,                 &
                       1, (/0/), Aval, Vinfo, ncname,                        &
                       SetParAccess = .FALSE.),                              &
               PIO_noerr, io_pio, __LINE__, MyFile)

  Vinfo( 1)='hc'
  Vinfo( 2)='S-coordinate parameter, critical depth'
  Vinfo( 3)='meter'
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TOUT,                 &
                       1, (/0/), Aval, Vinfo, ncname,                        &
                       SetParAccess = .FALSE.),                              &
               PIO_noerr, io_pio, __LINE__, MyFile)

  Vinfo( 1)='grid'
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_int,                  &
                       1, (/0/), Aval, Vinfo, ncname,                        &
                       SetParAccess = .FALSE.),                              &
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
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TOUT,                 &
                       1, (/DimIDs(9)/), Aval, Vinfo, ncname,                &
                       SetParAccess = .FALSE.),                              &
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
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TOUT,                 &
                       1, (/DimIDs(10)/), Aval, Vinfo, ncname,               &
                       SetParAccess = .FALSE.),                              &
               PIO_noerr, io_pio, __LINE__, MyFile)

  ! S-coordinate non-dimensional stretching curves at RHO-points.

  Vinfo( 1)='Cs_r'
  Vinfo( 2)='S-coordinate stretching curves at RHO-points'
  Vinfo( 5)='valid_min'
  Vinfo( 6)='valid_max'
  Aval(2)=-1.0_r8
  Aval(3)=0.0_r8
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TOUT,                 &
                       1, (/DimIDs(9)/), Aval, Vinfo, ncname,                &
                       SetParAccess = .FALSE.),                              &
               PIO_noerr, io_pio, __LINE__, MyFile)

  ! S-coordinate non-dimensional stretching curves at W-points.

  Vinfo( 1)='Cs_w'
  Vinfo( 2)='S-coordinate stretching curves at W-points'
  Vinfo( 5)='valid_min'
  Vinfo( 6)='valid_max'
  Aval(2)=-1.0_r8
  Aval(3)=0.0_r8
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TOUT,                 &
                       1, (/DimIDs(10)/), Aval, Vinfo, ncname,               &
                       SetParAccess = .FALSE.),                              &
               PIO_noerr, io_pio, __LINE__, MyFile)

  ! Bathymetry.

  Vinfo( 1)='h'
  Vinfo( 2)='bathymetry at RHO-points'
  Vinfo( 3)='meter'
  Vinfo(22)='coordinates'
  Aval(5)=REAL(r2dvar,r8)
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TYPE,                 &
                       2, r2dgrd, Aval, Vinfo, ncname),                      &
               PIO_noerr, io_pio, __LINE__, MyFile)

  ! Grid coordinates of RHO-points.

  Vinfo( 1)='lon_rho'
  Vinfo( 2)='longitude of RHO-points'
  Vinfo( 3)='degree_east'
  Vinfo(21)='longitude'
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TYPE,                 &
                       2, r2dgrd, Aval, Vinfo, ncname),                      &
               PIO_noerr, io_pio, __LINE__, MyFile)

  Vinfo( 1)='lat_rho'
  Vinfo( 2)='latitude of RHO-points'
  Vinfo( 3)='degree_north'
  Vinfo(21)='latitude'
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TYPE,                 &
                       2, r2dgrd, Aval, Vinfo, ncname),                      &
               PIO_noerr, io_pio, __LINE__, MyFile)

  ! Grid coordinates of U-points.

  Vinfo( 1)='lon_u'
  Vinfo( 2)='longitude of U-points'
  Vinfo( 3)='degree_east'
  Vinfo(21)='longitude'
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TYPE,                 &
                       2, u2dgrd, Aval, Vinfo, ncname),                      &
               PIO_noerr, io_pio, __LINE__, MyFile)

  Vinfo( 1)='lat_u'
  Vinfo( 2)='latitude of U-points'
  Vinfo( 3)='degree_north'
  Vinfo(21)='latitude'
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TYPE,                 &
                       2, u2dgrd, Aval, Vinfo, ncname),                      &
               PIO_noerr, io_pio, __LINE__, MyFile)

  ! Grid coordinates of V-points.

  Vinfo( 1)='lon_v'
  Vinfo( 2)='longitude of V-points'
  Vinfo( 3)='degree_east'
  Vinfo(21)='longitude'
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TYPE,                 &
                       2, v2dgrd, Aval, Vinfo, ncname),                      &
               PIO_noerr, io_pio, __LINE__, MyFile)

  Vinfo( 1)='lat_v'
  Vinfo( 2)='latitude of V-points'
  Vinfo( 3)='degree_north'
  Vinfo(21)='latitude'
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TYPE,                 &
                       2, v2dgrd, Aval, Vinfo, ncname),                      &
               PIO_noerr, io_pio, __LINE__, MyFile)

  ! Angle between XI-axis and EAST at RHO-points.

  Vinfo( 1)='angle'
  Vinfo( 2)='angle between XI-axis and EAST'
  Vinfo( 3)='radians'
  Vinfo(22)='coordinates'
  Aval(5)=REAL(r2dvar,r8)
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TYPE,                 &
                       2, r2dgrd, Aval, Vinfo, ncname),                      &
               PIO_noerr, io_pio, __LINE__, MyFile)

  !  Masking fields at RHO-, U-, and V-points.

  Vinfo( 1)='mask_rho'
  Vinfo( 2)='mask on RHO-points'
  Vinfo( 9)='land'
  Vinfo(10)='water'
  Vinfo(22)='coordinates'
  Aval(5)=REAL(r2dvar,r8)
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TYPE,                 &
                       2, r2dgrd, Aval, Vinfo, ncname),                      &
               PIO_noerr, io_pio, __LINE__, MyFile)

  Vinfo( 1)='mask_u'
  Vinfo( 2)='mask on U-points'
  Vinfo( 9)='land'
  Vinfo(10)='water'
  Vinfo(22)='coordinates'
  Aval(5)=REAL(u2dvar,r8)
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TYPE,                 &
                       2, u2dgrd, Aval, Vinfo, ncname).                      &
               PIO_noerr, io_pio, __LINE__, MyFile)

  Vinfo( 1)='mask_v'
  Vinfo( 2)='mask on V-points'
  Vinfo( 9)='land'
  Vinfo(10)='water'
  Vinfo(22)='coordinates'
  Aval(5)=REAL(v2dvar,r8)
  CALL nc_err (def_var(ng, model, pioFile, pioVar, PIO_TYPE,                 &
                       2, v2dgrd, Aval, Vinfo, ncname),                      &
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

  character (len=*), parameter      :: MyFile =                              &
     &  __FILE__//", roms_wrt_info_pio"

  ! Initialize

  LBi=LBOUND(GRID(ng)%h,DIM=1)
  UBi=UBOUND(GRID(ng)%h,DIM=1)
  LBj=LBOUND(GRID(ng)%h,DIM=2)
  UBj=UBOUND(GRID(ng)%h,DIM=2)

  !  Inquire about the variables.

  CALL netcdf_inq_var (ng, model, ncname, pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  ! Write out grid variables.

  CALL pio_netcdf_put_lvar (ng, model, ncname, 'spherical',                  &
                            spherical, (/0/), (/0/),                         &
                            pioFile = pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  ! S-coordinate parameters.

  CALL pio_netcdf_put_ivar (ng, model, ncname, 'Vtransform',                 &
                            Vtransform(ng), (/0/), (/0/),                    &
                            pioFile = pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  CALL pio_netcdf_put_ivar (ng, model, ncname, 'Vstretching',                &
                            Vstretching(ng), (/0/), (/0/),                   &
                            pioFile = pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  CALL pio_netcdf_put_fvar (ng, model, ncname, 'theta_s',                    &
                            theta_s(ng), (/0/), (/0/),                       &
                            pioFile = pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  CALL pio_netcdf_put_fvar (ng, model, ncname, 'theta_b',                    &
                            theta_b(ng), (/0/), (/0/),                       &
                            pioFile = pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  CALL pio_netcdf_put_fvar (ng, model, ncname, 'Tcline',                     &
                            Tcline(ng), (/0/), (/0/),                        &
                            pioFile = pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  CALL pio_netcdf_put_fvar (ng, model, ncname, 'hc',                         &
                            hc(ng), (/0/), (/0/),                            &
                            pioFile = pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  CALL pio_netcdf_put_ivar (ng, model, ncname, 'grid',                       &
                            (/1/), (/0/), (/0/),                             &
                            pioFile = pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  ! S-coordinate non-dimensional independent variables.

  CALL pio_netcdf_put_fvar (ng, model, ncname, 's_rho',                      &
                            SCALARS(ng)%sc_r(:), (/1/), (/N(ng)/),           &
                            pioFile = pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  CALL pio_netcdf_put_fvar (ng, model, ncname, 's_w',                        &
                            SCALARS(ng)%sc_w(0:), (/1/), (/N(ng)+1/),        &
                            pioFile = pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  ! S-coordinate non-dimensional stretching curves.

  CALL pio_netcdf_put_fvar (ng, model, ncname, 'Cs_r',                       &
                            SCALARS(ng)%Cs_r(:), (/1/), (/N(ng)/),           &
                            pioFile = pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  CALL pio_netcdf_put_fvar (ng, model, ncname, 'Cs_w',                       &
                            SCALARS(ng)%Cs_w(0:), (/1/), (/N(ng)+1/),        &
                            pioFile = pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  ! Bathymetry.

  IF (pio_netcdf_find_var(ng, model, pioFile, 'h',                           &
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
    CALL nc_err (nf_fwrite2d(ng, model, pioFile, pioVar,                     &
                             0, ioDesc,                                      &
                             LBi, UBi, LBj, UBj, scale,                      &
                             GRID(ng) % rmask,                               &
                             GRID(ng) % h,                                   &
                             SetFillVal = .FALSE.),                          &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  !  Grid coordinates of RHO-points.

  IF (pio_netcdf_find_var(ng, model, pioFile, 'lon_rho',                     &
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
    CALL nc_err (nf_fwrite2d(ng, model, pioFile, pioVar,                     &
                             0, ioDesc,                                      &
                             LBi, UBi, LBj, UBj, scale,                      &
                             GRID(ng) % rmask,                               &
                             GRID(ng) % lonr,                                &
                             SetFillVal = .FALSE.),                          &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  IF (pio_netcdf_find_var(ng, model, pioFile, 'lat_rho',                     &
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
    CALL nc_err (nf_fwrite2d(ng, model, pioFile, pioVar,                     &
                             0, ioDesc,                                      &
                             LBi, UBi, LBj, UBj, scale,                      &
                             GRID(ng) % rmask,                               &
                             GRID(ng) % latr,                                &
                             SetFillVal = .FALSE.),                          &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  ! Grid coordinates of U-points.

  IF (pio_netcdf_find_var(ng, model, pioFile, 'lon_u',                       &
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
    CALL nc_err (nf_fwrite2d(ng, model, pioFile, pioVar,                     &
                             0, ioDesc,                                      &
                             LBi, UBi, LBj, UBj, scale,                      &
                             GRID(ng) % umask,                               &
                             GRID(ng) % lonu,                                &
                             SetFillVal = .FALSE.),                          &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  IF (pio_netcdf_find_var(ng, model, pioFile, 'lat_u',                       &
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
    CALL nc_err (nf_fwrite2d(ng, model, pioFile, pioVar,                     &
                             0, ioDesc,                                      &
                             LBi, UBi, LBj, UBj, scale,                      &
                             GRID(ng) % umask,                               &
                             GRID(ng) % latu,                                &
                             SetFillVal = .FALSE.),                          &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  ! Grid coordinates of V-points.

  IF (pio_netcdf_find_var(ng, model, pioFile, 'lon_v',                       &
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
    CALL nc_err (nf_fwrite2d(ng, model, pioFile, pioVar,                     &
                             0, ioDesc,                                      &
                             LBi, UBi, LBj, UBj, scale,                      &
                             GRID(ng) % vmask,                               &
                             GRID(ng) % lonv,                                &
                             SetFillVal = .FALSE.),                          &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  IF (pio_netcdf_find_var(ng, model, pioFile, 'lat_v',                       &
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
    CALL nc_err (nf_fwrite2d(ng, model, pioFile, pioVar,                     &
                             0, ioDesc,                                      &
                             LBi, UBi, LBj, UBj, scale,                      &
                             GRID(ng) % vmask,                               &
                             GRID(ng) % latv,                                &
                             SetFillVal = .FALSE.),                          &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  ! Angle between XI-axis and EAST at RHO-points.


  IF (pio_netcdf_find_var(ng, model, pioFile, 'angle',                       &
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
    CALL nc_err (nf_fwrite2d(ng, model, pioFile, pioVar,                     &
                             0, ioDesc,                                      &
                             LBi, UBi, LBj, UBj, scale,                      &
                             GRID(ng) % rmask,                               &
                             GRID(ng) % angler,                              &
                             SetFillVal = .FALSE.),                          &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  ! Masking fields at RHO-, U-, and V-points.

  IF (pio_netcdf_find_var(ng, model, pioFile, 'mask_rho',                    &
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
    CALL nc_err (nf_fwrite2d(ng, model, pioFile, pioVar,                     &
                             0, ioDesc,                                      &
                             LBi, UBi, LBj, UBj, scale,                      &
                             GRID(ng) % rmask,                               &
                             GRID(ng) % rmask,                               &
                             SetFillVal = .FALSE.),                          &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  IF (pio_netcdf_find_var(ng, model, pioFile, 'mask_u',                      &
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
    CALL nc_err (nf_fwrite2d(ng, model, pioFile, pioVar,                     &
                             0, ioDesc,                                      &
                             LBi, UBi, LBj, UBj, scale,                      &
                             GRID(ng) % umask,                               &
                             GRID(ng) % umask,                               &
                             SetFillVal = .FALSE.),                          &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

  IF (pio_netcdf_find_var(ng, model, pioFile, 'mask_v',                      &
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
    CALL nc_err (nf_fwrite2d(ng, model, pioFile, pioVar,                     &
                             0, ioDesc,                                      &
                             LBi, UBi, LBj, UBj, scale,                      &
                             GRID(ng) % vmask,                               &
                             GRID(ng) % vmask,                               &
                             SetFillVal = .FALSE.),                          &
                 nf90_noerr, io_nf90, __LINE__, MyFile)
  END IF

END SUBROUTINE roms_wrt_info_pio

#endif

END MODULE roms_fieldsutils_mod
