! (C) Copyright 2020-2021 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
! Hernan G. Arango, Rutgers University, Apr 2021

MODULE roms_state_mod

USE kinds,                      ONLY : kind_real

USE datetime_mod
USE fckit_configuration_module, ONLY : fckit_configuration
USE fckit_log_module,           ONLY : fckit_log
USE oops_variables_mod

USE roms_geom_mod
USE roms_fields_mod
USE roms_fields_metadata_mod
USE roms_fieldsutils_mod
USE roms_increment_mod
!USE roms_convert_state_mod

implicit none

PRIVATE

TYPE, PUBLIC, EXTENDS(roms_fields) :: roms_state

  CONTAINS

  ! Constructors / Destructors
 
  PROCEDURE :: create                => roms_state_create

  ! Increment operations

  PROCEDURE :: diff_incr             => roms_state_diff_incr
  PROCEDURE :: add_incr              => roms_state_add_incr

  ! Operations

  PROCEDURE :: rotate                => roms_state_rotate
  PROCEDURE :: convert               => roms_state_convert
  PROCEDURE :: logexpon              => roms_state_logexpon

  ! Read extra fields

  PROCEDURE :: read_extrafields_nf90 => roms_state_read_extrafields_nf90

#if defined PIO_LIB
  PROCEDURE :: read_extrafields_pio  => roms_state_read_extrafields_pio
#endif

END TYPE roms_state

!-------------------------------------------------------------------------------
CONTAINS
!-------------------------------------------------------------------------------

!-------------------------------------------------------------------------------
!> Create State object

SUBROUTINE roms_state_create (self, geom, vars)

  CLASS (roms_state),         intent(inout) :: self    !< State
  TYPE (roms_geom),  pointer, intent(inout) :: geom    !< Geometry
  TYPE (oops_variables),      intent(inout) :: vars    !< State variables

  ! Initialization fields by base class

  CALL self%roms_fields%create (geom, vars)

END SUBROUTINE roms_state_create

! ------------------------------------------------------------------------------
!> Initialize state with analytical expressions.

SUBROUTINE roms_state_analytic_init (self, geom, f_conf, vdate)

  CLASS (roms_state),         intent(inout) :: self    !< State
  TYPE (roms_geom),           intent(in   ) :: geom    !< Geometry
  TYPE (fckit_configuration), intent(in   ) :: f_conf  !< Configuration
  TYPE (datetime),            intent(inout) :: vdate   !< DateTime

  character (len=20)                        :: sdate
  character (len=30)                        :: ana_config
  character (len=: ), allocatable           :: string

  ! Get type of analytical field from configuration YAML.

  IF (f_conf%has("analytic init")) THEN
    CALL f_conf%get_or_die ("analytic init.method",string)
    ana_config = string
  ELSE
    ana_config = 'uniform_ocnfields'
  END IF
  CALL fckit_log%warning ('roms_state_analytic_init: '//TRIM(ana_config))

  ! Set date and time

  CALL f_conf%get_or_die ("date", string)
  sdate = string
  CALL fckit_log%info ('roms_state_analytic_init: validity date is '//sdate)
  CALL datetime_set (sdate, vdate)

  ! Define state fields

  SELECT CASE (TRIM(ana_config))
    CASE ('ana_ocnfields')
      CALL self%analytic ()
    CASE ('uniform_ocnfields')
      CALL self%zeros ()
    CASE DEFAULT
      CALL abor1_ftn ('roms_state_analytic_init: unknown analytical ' //     &
                      'initialization: ' // TRIM(ana_config))
  END SELECT

END SUBROUTINE roms_state_analytic_init

! ------------------------------------------------------------------------------
!> Rotate horizontal vector components to geographical or curvilinear 
!! coordinates

SUBROUTINE roms_state_rotate (self, coordinate, uvars, vvars)

  CLASS (roms_state),    intent(inout) :: self
  character (len=*),     intent(   in) :: coordinate  !> "north" or "grid"
  TYPE (oops_variables), intent(   in) :: uvars
  TYPE (oops_variables), intent(   in) :: vvars

  integer                              :: i, k
  TYPE (roms_field),           pointer :: uocn, vocn
  real(kind=kind_real),    allocatable :: un(:,:,:), vn(:,:,:)
  character (len=64)                   :: u_names, v_names

  DO i=1, uvars%nvars()

    ! Get (u, v) vector components and make a copy

    u_names = TRIM(uvars%variable(i))
    v_names = TRIM(vvars%variable(i))

    IF (self%has(u_names).and.self%has(v_names)) THEN
      CALL fckit_log%info ("rotating "//TRIM(u_names)//" "//TRIM(v_names))
      CALL self%get (u_names, uocn)
      CALL self%get (v_names, vocn)
    ELSE                             ! skip if no pair found
      CALL fckit_log%info ("not rotating "//TRIM(u_names)//" "//TRIM(v_names))
      CYCLE
    END IF

    allocate (un(SIZE(uocn%val,1), SIZE(uocn%val,2), SIZE(uocn%val,3)))
    allocate (vn(SIZE(uocn%val,1), SIZE(uocn%val,2), SIZE(uocn%val,3)))
    un = uocn%val
    vn = vocn%val

    ! Rotate (uocn, vocn) vector components to geographical NORTH and EAST
    ! coordinates or numerical curvilinear (XI,ETA) coordinates.
    ! The ROMS rotation angle is an azimuth that is counterclockwise from
    ! true EAST, and defined at RHO-points.
    ! TODO: Do we to average to U- and V-points?

    SELECT CASE (TRIM(coordinate))
      CASE ("north")         ! rotate from (XI,ETA) to geographical coordinates
        DO k=1,uocn%N
          uocn%val(:,:,k) = (un(:,:,k) * self%geom%CosAngler(:,:)- &
                             vn(:,:,k) * self%geom%SinAngler(:,:)) * &
                            uocn%mask(:,:)

          vocn%val(:,:,k) = (vn(:,:,k) * self%geom%CosAngler(:,:)+ &
                             un(:,:,k) * self%geom%SinAngler(:,:)) * &
                            vocn%mask(:,:)
        END DO
      CASE ("grid")          ! rotate from geographical to (XI,ETA) coordinates
        DO k=1,uocn%N
          uocn%val(:,:,k) = (un(:,:,k) * self%geom%CosAngler(:,:)+ &
                             vn(:,:,k) * self%geom%SinAngler(:,:)) * &
                            uocn%mask(:,:)

          vocn%val(:,:,k) = (vn(:,:,k) * self%geom%CosAngler(:,:)- &
                             un(:,:,k) * self%geom%SinAngler(:,:)) * &
                            vocn%mask(:,:)
        END DO
    END SELECT

    deallocate (un, vn)

    ! Update halos

    CALL uocn%update_halo (self%geom)
    CALL vocn%update_halo (self%geom)

  END DO

END SUBROUTINE roms_state_rotate

! ------------------------------------------------------------------------------
!> Add a set of increments to the set of fields

SUBROUTINE roms_state_add_incr (self, rhs)

  CLASS (roms_state),     intent(inout) :: self
  CLASS (roms_increment), intent(   in) :: rhs

  TYPE (roms_field),            pointer :: fld, fld_r
  TYPE (roms_fields)                    :: incr
  integer                               :: i

  ! Make sure "rhs" is a subset of "self"

  CALL rhs%check_subset (self)

  ! Make a copy of the increment

  CALL incr%copy (rhs)

  ! For each field that exists in "incr", add to "self"

  DO i = 1, SIZE(incr%fields)
    fld_r => incr%fields(i)
    CALL self%get (fld_r%name, fld)
    fld%val = fld%val + fld_r%val
  END DO

END SUBROUTINE roms_state_add_incr

! ------------------------------------------------------------------------------
!> Subtract two sets of fields, saving the results separately

SUBROUTINE roms_state_diff_incr (x1, x2, inc)

  CLASS (roms_state),     intent(   in) :: x1
  CLASS (roms_state),     intent(   in) :: x2
  CLASS (roms_increment), intent(inout) :: inc

  TYPE (roms_field),            pointer :: f1, f2
  integer                               :: i

  ! Make sure fields correct shapes

  CALL inc%check_subset (x2)
  CALL x2%check_subset (x1)

  ! Subtract

  DO i = 1, SIZE(inc%fields)
    CALL x1%get (inc%fields(i)%name, f1)
    CALL x2%get (inc%fields(i)%name, f2)
    inc%fields(i)%val = f1%val - f2%val
  END DO

END SUBROUTINE roms_state_diff_incr

! ------------------------------------------------------------------------------
!> Convert State Application:  Interpolate between geometries

SUBROUTINE roms_state_convert (self, rhs)

  CLASS (roms_state), intent(inout) :: self  !> target
  CLASS (roms_state), intent(   in) :: rhs   !> source

  integer                           :: n
! TYPE (roms_convertstate_type)     :: convert_state
  TYPE (roms_field),        pointer :: field1, field2

! CALL rhs%get ("hocn", hocn1)
! CALL self%get ("hocn", hocn2)
! CALL convert_state%setup (rhs%geom, self%geom, hocn1, hocn2)

  DO n = 1, SIZE(rhs%fields)
    field1 => rhs%fields(n)
    CALL self%get (TRIM(field1%name), field2)
    IF (field1%metadata%io_file=="ocn") THEN
!     call convert_state%change_resol (field1, field2, rhs%geom, self%geom)
    END IF
  END DO

! CALL convert_state%clean ()

END SUBROUTINE roms_state_convert

! ------------------------------------------------------------------------------
!> Apply logarithmic or exponential transformations

SUBROUTINE roms_state_logexpon (self, transfunc, trvars)

  CLASS (roms_state),    intent(inout) :: self
  character (len=*),     intent(   in) :: transfunc   !> "log" or "expon"
  TYPE (oops_variables), intent(   in) :: trvars

  TYPE (roms_field),           pointer :: trocn
  integer                              :: i
  real(kind=kind_real)                 :: min_val = 1e-6_kind_real
  real(kind=kind_real),   allocatable :: trn(:,:,:)
  character(len=64)                   :: tr_names

  DO i=1, trvars%nvars()

    ! Get a list variables to be transformed and make a copy

    tr_names = TRIM(trvars%variable(i))

    IF (self%has(tr_names)) THEN
      CALL fckit_log%info ("transforming "//TRIM(tr_names))
      CALL self%get (tr_names, trocn)
    ELSE                                 ! skip if no variable found
      CALL fckit_log%info ("not transforming "//TRIM(tr_names))
      CYCLE
    END IF

    allocate (trn(SIZE(trocn%val,1), SIZE(trocn%val,2), SIZE(trocn%val,3)))
    trn = trocn%val

    SELECT CASE(TRIM(transfunc))
      CASE ("log")                       ! apply logarithmic transformation
        trocn%val = LOG(trn + min_val)
      CASE ("expon")                     ! Apply exponential transformation
        trocn%val = EXP(trn) - min_val
    END SELECT

    ! Update halos

    CALL trocn%update_halo (self%geom)

    ! Deallocate "trn" for next variable

    deallocate (trn)

  END DO

END SUBROUTINE roms_state_logexpon

!-------------------------------------------------------------------------------
!> Reads in extra fields that are not part of the state vector and load then
!  to respective ROMS array.  They are needed for ROMS initialization. It uses
!  the standard NetCDF library.

SUBROUTINE roms_state_read_extrafields_nf90 (self, InpRec, Tindex,           &
                                             extra_vars, ncname,             &
                                             DateString, DateNumber)

  USE mod_grid,       ONLY : GRID
  USE mod_mixing,     ONLY : MIXING
  USE mod_ocean,      ONLY : OCEAN

  USE mod_ncparam,    ONLY : u2dvar, v2dvar, w3dvar, io_nf90
  USE mod_iounits,    ONLY : stdout
  USE mod_netcdf,     ONLY : netcdf_open, netcdf_close, netcdf_find_var
  USE mod_scalars,    ONLY : NoError, exit_flag, itemp, isalt
  USE netcdf,         ONLY : nf90_noerr
  USE nf_fread2d_mod, ONLY : nf_fread2d
  USE nf_fread3d_mod, ONLY : nf_fread3d

  CLASS (roms_state),    intent(in) :: self          !< State object
  integer,               intent(in) :: InpRec        !< time record to read
  integer,               intent(in) :: Tindex        !< ROMS array time index 
  real (kind=kind_real), intent(in) :: DateNumber    !< fields datenum
  character (len=*),     intent(in) :: extra_vars(:) !< variables to read
  character (len=*),     intent(in) :: ncname        !< input NetCDF file
  character (len=*),     intent(in) :: DateString    !< ISO8601 DateTime

  TYPE (roms_field_metadata)        :: metadata 
  integer                           :: LocalPET, lstr, lend
  integer                           :: LBi, UBi, LBj, UBj, N
  integer                           :: i, model, ng, nvars
  integer                           :: ncid, varid
  integer, dimension(4)             :: Vsize
  real (kind=kind_real)             :: Fmin, Fmax, scale
  character (len=:), allocatable    :: fieldname
  character (len=1024)              :: Message

  character (len=*), parameter      :: MyFile =                              &
     &  __FILE__//", roms_state_read_extrafields_nf90"

  ! Initialize.

  LocalPET = self%geom%f_comm%rank()   !> PET rank

  model = self%geom%model              !> numerical kernel
  ng    = MAX(1,self%geom%ng)          !> nested grid number
  LBi   = self%geom%LBi                !> I-dimension lower bound
  UBi   = self%geom%UBi                !> I-dimension upper bound
  LBj   = self%geom%LBj                !> J-dimension lower bound
  UBj   = self%geom%UBj                !> J-dimension upper bound
  N     = self%geom%N                  !> number of vertical levels
  scale = 1.0_kind_real
  Vsize = 0

  IF (LocalPET .eq. 0) THEN
    lstr = SCAN(ncname, '/', BACK=.TRUE.) + 1
    lend = LEN_TRIM(ncname)    
    WRITE (stdout,10) 'State Extra Fields,', TRIM(DateString), ng,           &
                      DateNumber, ncname(lstr:lend), InpRec
  END IF

  ! Open fields NetCDF file for reading.

  CALL netcdf_open (ng, model, ncname, 0, ncid)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  ! Read in requested extra fields. ROMS needs to be compiled with MASKING
  ! to use the NetCDF reading functions below.

  nvars=UBOUND(extra_vars, DIM=1)

  DO i = 1, nvars

    ! Get variable metadata.

    fieldname = extra_vars(i)
    metadata  = self%geom%fieldsinfo%get(fieldname)

    ! Inquire variable if requested variable exits.

    IF (.not.netcdf_find_var(ng, model, ncid, metadata%io_name, varid)) THEN

      IF (LocalPET .eq. 0) THEN
        PRINT '(3a)', 'ROMS_STATE::read_extrafields_nf90 - Variable: ',      &
                      metadata%io_name, ' not found in file: ', ncname                      
      END IF

      CYCLE

    ELSE

      SELECT CASE (TRIM(extra_vars(i)))

        CASE ('u2docn')                    !> 2D U-momentum component

          CALL nc_err (nf_fread2d(ng, model, ncname, ncid,                   &
                                  metadata%io_name,                          &
                                  varid, InpRec, u2dvar, Vsize,              &
                                  LBi, UBi, LBj, UBj,                        &
                                  scale, Fmin, Fmax,                         &
                                  GRID(ng)%umask,                            &
                                  OCEAN(ng)%ubar(:,:,Tindex)),               &
                       nf90_noerr, io_nf90, __LINE__, MyFile)

          IF (LocalPET .eq. 0) THEN
            WRITE (stdout,20) metadata%getval_name, Fmin, Fmax
          END IF

        CASE ('v2docn')                    !> 2D V-momentum component

          CALL nc_err (nf_fread2d(ng, model, ncname, ncid,                   &
                                  metadata%io_name,                          &
                                  varid, InpRec, v2dvar, Vsize,              &
                                  LBi, UBi, LBj, UBj,                        &
                                  scale, Fmin, Fmax,                         &
                                  GRID(ng)%vmask,                            &
                                  OCEAN(ng)%vbar(:,:,Tindex)),               &
                     nf90_noerr, io_nf90, __LINE__, MyFile)

          IF (LocalPET .eq. 0) THEN
            WRITE (stdout,20) metadata%getval_name, Fmin, Fmax
          END IF

        CASE ('Ktocn')                     !> temperature vertical diffusion

          CALL nc_err (nf_fread3d(ng, model, ncname, ncid,                   &
                                  metadata%io_name,                          &
                                  varid, InpRec, w3dvar, Vsize,              &
                                  LBi, UBi, LBj, UBj, 0, N,                  &
                                  scale, Fmin, Fmax,                         &
                                  GRID(ng)%rmask,                            &
                                  MIXING(ng)%AKt(:,:,:,itemp)),              &
                       nf90_noerr, io_nf90, __LINE__, MyFile)

          IF (LocalPET .eq. 0) THEN
            WRITE (stdout,20) metadata%getval_name, Fmin, Fmax
          END IF

        CASE ('Ksocn')                     !> salinity vertical diffusion

          CALL nc_err (nf_fread3d(ng, model, ncname, ncid,                   &
                                  metadata%io_name,                          &
                                  varid, InpRec, w3dvar, Vsize,              &
                                  LBi, UBi, LBj, UBj, 0, N,                  &
                                  scale, Fmin, Fmax,                         &
                                  GRID(ng)%rmask,                            &
                                  MIXING(ng)%AKt(:,:,:,isalt)),              &
                       nf90_noerr, io_nf90, __LINE__, MyFile)

          IF (LocalPET .eq. 0) THEN
            WRITE (stdout,20) metadata%getval_name, Fmin, Fmax
          END IF

        CASE ('Kvocn')                     !> vertical viscosity

          CALL nc_err (nf_fread3d(ng, model, ncname, ncid,                   &
                                  metadata%io_name,                          &
                                  varid, InpRec, w3dvar, Vsize,              &
                                  LBi, UBi, LBj, UBj, 0, N,                  &
                                  scale, Fmin, Fmax,                         &
                                  GRID(ng)%rmask,                            &
                                  MIXING(ng)%AKv),                           &
                       nf90_noerr, io_nf90, __LINE__, MyFile)

          IF (LocalPET .eq. 0) THEN
            WRITE (stdout,20) metadata%getval_name, Fmin, Fmax
          END IF

        CASE DEFAULT
  
          WRITE (Message,'(5a)')                                             &
                'roms_state::read_extrafields_nf90: Cannot find and option ',&
                'to read = ', TRIM(extra_vars(i)), " - ", metadata%getval_name
          CALL abor1_ftn (TRIM(Message))

      END SELECT

    END IF

  END DO

  ! Close NetCDF file.

  CALL netcdf_close (ng, model, ncid, ncname, .FALSE.)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  10 FORMAT (/,1x,'ROMS_STATE::read_extrafields_nf90 - ',a,t75,a,/,26x,      &
             '(Grid=',i2.2,', datenum=',f0.4,', File: ',a,', Rec= ',i0,')')
  20 FORMAT (24x,'- ',a,/,27x,'(Min = ',1p,e15.8,' Max = ',1p,e15.8,')')

END SUBROUTINE roms_state_read_extrafields_nf90

#if defined PIO_LIB

!-------------------------------------------------------------------------------
!> Reads in extra fields that are not part of the state vector and load then
!  to respective ROMS array.  They are needed for ROMS initialization. It uses
!  the Parallel I/O (PIO) library.

SUBROUTINE roms_state_read_extrafields_pio (self, InpRec, Tindex,            &
                                            extra_vars, ncname,              &
                                            DateString, DateNumber)

  USE mod_grid,       ONLY : GRID
  USE mod_mixing,     ONLY : MIXING
  USE mod_ocean,      ONLY : OCEAN
  USE mod_pio_netcdf

  USE mod_ncparam,    ONLY : u2dvar, v2dvar, w3dvar, io_pio
  USE mod_iounits,    ONLY : stdout
  USE mod_scalars,    ONLY : NoError, exit_flag, itemp, isalt
  USE nf_fread2d_mod, ONLY : nf_fread2d
  USE nf_fread3d_mod, ONLY : nf_fread3d

  CLASS (roms_state),    intent(in) :: self          !< State object
  integer,               intent(in) :: InpRec        !< time record to read
  integer,               intent(in) :: Tindex        !< ROMS array time index 
  real (kind=kind_real), intent(in) :: DateNumber    !< fields datenum
  character (len=*),     intent(in) :: extra_vars(:) !< variables to read
  character (len=*),     intent(in) :: ncname        !< input NetCDF file
  character (len=*),     intent(in) :: DateString    !< ISO8601 DateTime

  TYPE (IO_desc_t), pointer         :: ioDesc
  TYPE (My_VarDesc)                 :: pioVar

  TYPE (roms_field_metadata)        :: metadata 
  integer                           :: LocalPET, lstr, lend
  integer                           :: LBi, UBi, LBj, UBj, N
  integer                           :: i, model, ng, nvars
  integer, dimension(4)             :: Vsize
  real (kind=kind_real)             :: Fmin, Fmax, scale
  character (len=:), allocatable    :: fieldname
  character (len=1024)              :: Message

  character (len=*), parameter      :: MyFile =                              &
     &  __FILE__//", roms_state_read_extrafields_pio"

  ! Initialize.

  LocalPET = self%geom%f_comm%rank()   !> PET rank

  model = self%geom%model              !> numerical kernel
  ng    = MAX(1,self%geom%ng)          !> nested grid number
  LBi   = self%geom%LBi                !> I-dimension lower bound
  UBi   = self%geom%UBi                !> I-dimension upper bound
  LBj   = self%geom%LBj                !> J-dimension lower bound
  UBj   = self%geom%UBj                !> J-dimension upper bound
  N     = self%geom%N                  !> number of vertical levels
  scale = 1.0_kind_real
  Vsize = 0

  IF (LocalPET .eq. 0) THEN
    lstr = SCAN(ncname, '/', BACK=.TRUE.) + 1
    lend = LEN_TRIM(ncname)    
    WRITE (stdout,10) 'State Extra Fields,', TRIM(DateString), ng,           &
                      DateNumber, ncname(lstr:lend), InpRec
  END IF

  ! Open fields NetCDF file for reading.

  CALL pio_netcdf_open (ng, model, ncname, 0, pioFile)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  ! Read in requested extra fields. ROMS needs to be compiled with MASKING
  ! to use the NetCDF reading functions below.

  nvars=UBOUND(extra_vars, DIM=1)

  DO i = 1, nvars

    ! Get variable metadata.

    fieldname = extra_vars(i)
    metadata  = self%geom%fieldsinfo%get(fieldname)

    ! Inquire variable if requested variable exits.

    IF (.not.pio_netcdf_find_var(ng, model, pioFile, metadata%io_name,       &
                                 pioVar)) THEN

      IF (LocalPET .eq. 0) THEN
        PRINT '(3a)', 'ROMS_STATE::read_extrafields_pio - Variable: ',       &  
                      metadata%io_name, ' not found in file: ', ncname                      
      END IF

      CYCLE

    ELSE

      SELECT CASE (TRIM(extra_vars(i)))

        CASE ('u2docn')                    !> 2D U-momentum component

          pioVar%gtype=u2dvar
          IF (KIND(OCEAN(ng)%ubar).eq.8) THEN
            pioVar%dkind=PIO_double
            ioDesc => ioDesc_dp_u2dvar(ng)
          ELSE
            pioVar%dkind=PIO_real
            ioDesc => ioDesc_sp_u2dvar(ng)
          END IF
          CALL nc_err (nf_fread2d(ng, model, ncname, pioFile                 &
                                  metadata%io_name,                          &
                                  pioVar, InpRec, ioDesc, Vsize,             &
                                  LBi, UBi, LBj, UBj,                        &
                                  scale, Fmin, Fmax,                         &
                                  GRID(ng)%umask,                            &
                                  OCEAN(ng)%ubar(:,:,Tindex)),               &
                       PIO_noerr, io_pio, __LINE__, MyFile)

          IF (LocalPET .eq. 0) THEN
            WRITE (stdout,20) metadata%getval_name, Fmin, Fmax
          END IF

        CASE ('v2docn')                    !> 2D V-momentum component

          pioVar%gtype=v2dvar
          IF (KIND(OCEAN(ng)%vbar).eq.8) THEN
            pioVar%dkind=PIO_double
            ioDesc => ioDesc_dp_v2dvar(ng)
          ELSE
            pioVar%dkind=PIO_real
            ioDesc => ioDesc_sp_v2dvar(ng)
          END IF
          CALL nc_err (nf_fread2d(ng, model, ncname, pioFile,                &
                                  metadata%io_name,                          &
                                  pioVar, InpRec, ioDesc, Vsize,             &
                                  LBi, UBi, LBj, UBj,                        &
                                  scale, Fmin, Fmax,                         &
                                  GRID(ng)%vmask,                            &
                                  OCEAN(ng)%vbar(:,:,Tindex)),               &
                     PIO_noerr, io_pio, __LINE__, MyFile)

          IF (LocalPET .eq. 0) THEN
            WRITE (stdout,20) metadata%getval_name, Fmin, Fmax
          END IF

        CASE ('Ktocn')                     !> temperature vertical diffusion

          pioVar%gtype=w3dvar
          IF (KIND(MIXING(ng)%AKt).eq.8) THEN
            pioVar%dkind=PIO_double
            ioDesc => ioDesc_dp_w3dvar(ng)
          ELSE
            pioVar%dkind=PIO_real
            ioDesc => ioDesc_sp_w3dvar(ng)
          END IF
          CALL nc_err (nf_fread3d(ng, model, ncname, pioFile,                &
                                  metadata%io_name,                          &
                                  pioVar, InpRec, ioDesc, Vsize,             &
                                  LBi, UBi, LBj, UBj, 0, N,                  &
                                  scale, Fmin, Fmax,                         &
                                  GRID(ng)%rmask,                            &
                                  MIXING(ng)%AKt(:,:,:,itemp)),              &
                       PIO_noerr, io_pio, __LINE__, MyFile)

          IF (LocalPET .eq. 0) THEN
            WRITE (stdout,20) metadata%getval_name, Fmin, Fmax
          END IF

        CASE ('Ksocn')                     !> salinity vertical diffusion

          pioVar%gtype=w3dvar
          IF (KIND(MIXING(ng)%AKt).eq.8) THEN
            pioVar%dkind=PIO_double
            ioDesc => ioDesc_dp_w3dvar(ng)
          ELSE
            pioVar%dkind=PIO_real
            ioDesc => ioDesc_sp_w3dvar(ng)
          END IF
          CALL nc_err (nf_fread3d(ng, model, ncname, pioFile,                &
                                  metadata%io_name,                          &
                                  pioVar, InpRec, ioDesc, Vsize,             &
                                  LBi, UBi, LBj, UBj, 0, N,                  &
                                  scale, Fmin, Fmax,                         &
                                  GRID(ng)%rmask,                            &
                                  MIXING(ng)%AKt(:,:,:,isalt)),              &
                       PIO_noerr, io_pio, __LINE__, MyFile)

          IF (LocalPET .eq. 0) THEN
            WRITE (stdout,20) metadata%getval_name, Fmin, Fmax
          END IF

        CASE ('Kvocn')                     !> vertical viscosity

          pioVar%gtype=w3dvar
          IF (KIND(MIXING(ng)%AKv).eq.8) THEN
            pioVar%dkind=PIO_double
            ioDesc => ioDesc_dp_w3dvar(ng)
          ELSE
            pioVar%dkind=PIO_real
            ioDesc => ioDesc_sp_w3dvar(ng)
          END IF
          CALL nc_err (nf_fread3d(ng, model, ncname, pioFile,                &
                                  metadata%io_name,                          &
                                  pioVar, InpRec, ioDesc, Vsize,             &
                                  LBi, UBi, LBj, UBj, 0, N,                  &
                                  scale, Fmin, Fmax,                         &
                                  GRID(ng)%rmask,                            &
                                  MIXING(ng)%AKv),                           &
                       PIO_noerr, io_pio, __LINE__, MyFile)

          IF (LocalPET .eq. 0) THEN
            WRITE (stdout,20) metadata%getval_name, Fmin, Fmax
          END IF

        CASE DEFAULT
  
          WRITE (Message,'(5a)')                                             &
                'roms_state::read_extrafields_pio: Cannot find and option ', &
                'to read = ', TRIM(extra_vars(i)), " - ", metadata%getval_name
          CALL abor1_ftn (TRIM(Message))

      END SELECT

    END IF

  END DO

  ! Close NetCDF file.

  CALL pio_netcdf_close (ng, model, pioFile, ncname, .FALSE.)
  IF (DetectError(exit_flag, NoError, __LINE__, MyFile, Message))            &
    CALL abor1_ftn (TRIM(Message))

  10 FORMAT (/,1x,'ROMS_STATE::read_extrafields_pio - ',a,t75,a,/,26x,       &
             '(Grid=',i2.2,', datenum=',f0.4,', File: ',a,', Rec= ',i0,')')
  20 FORMAT (24x,'- ',a,/,27x,'(Min = ',1p,e15.8,' Max = ',1p,e15.8,')')

END SUBROUTINE roms_state_read_extrafields_pio

#endif

! ------------------------------------------------------------------------------

END MODULE roms_state_mod
