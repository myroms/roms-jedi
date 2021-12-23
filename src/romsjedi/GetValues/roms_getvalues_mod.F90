! (C) Copyright 2020-2021 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
!>
!! \brief   GeoValues class for interpolating state vector at GeoVaLs locations
!!
!! \details This class includes several routines used to interpolate ROMS state
!!          at the observations locations. It include methods to generate
!!          analytic GeoVaLs, nonlinear state GeoVaLs, tangent linear state
!!          GeoVaLs and its associated Adjoint state GeoVaLs. It uses OOPS
!!          unstructured interpolation (from ATLAS) with Barycentric weights.
!!          It uses ROMS native interpolation for configuring the analytical
!!          GeoVaLs.
!!
!! \author  Hernan G. Arango (Rutgers University)
!! \date    July 2021

!------------------------------------------------------------------------------

MODULE roms_getvalues_mod

USE iso_c_binding
USE kinds,                          ONLY : kind_real

USE datetime_mod,                   ONLY : datetime, datetime_to_string
USE fckit_log_module,               ONLY : fckit_log
USE ufo_geovals_mod,                ONLY : ufo_geovals
USE ufo_locations_mod
USE unstructured_interpolation_mod, ONLY : unstrc_interp

USE roms_geom_mod,                  ONLY : roms_geom
USE roms_fields_mod,                ONLY : roms_fields, roms_field
USE roms_state_mod ,                ONLY : roms_state

implicit none

PRIVATE

TYPE, PUBLIC :: roms_getvalues
  
  logical, allocatable              :: horiz_interp_init(:)

  TYPE (unstrc_interp), allocatable :: horiz_interp(:)

  CONTAINS

  ! Constructors and Destructors.

  PROCEDURE :: create          => roms_getvalues_create
  PROCEDURE :: delete          => roms_getvalues_delete

  ! Apply Interpolation.

  PROCEDURE :: get_interp      => roms_getvalues_getinterp
  PROCEDURE :: fill_geovals    => roms_getvalues_fillgeovals

  ! Generic interfaces.

  GENERIC   :: fill_geovals_tl => fill_geovals
  GENERIC   :: set_trajectory  => fill_geovals

END TYPE roms_getvalues

logical :: LdebugGetValues = .FALSE.

!------------------------------------------------------------------------------
CONTAINS
!------------------------------------------------------------------------------
!> Creates GetValues object to interpolates model at observation locations.

SUBROUTINE roms_getvalues_create (self, geom, locs)

  CLASS(roms_getvalues), intent(inout) :: self    !< GetValues object
  TYPE (roms_geom),      intent(in   ) :: geom    !< Geometry object
  TYPE (ufo_locations),  intent(in   ) :: locs    !< observation locations

  ! Allocate interpolators for RHO-, U-, and V-points. All fields in ROMS
  ! are assumed to be masked.  If they are not masked, the mask arrays are
  ! set to unity everywhere. Therefore, we do not need special case for
  ! unmasked interpolator.

  allocate ( self%horiz_interp(3) )         !< gtype = 'r', 'u', 'v' 
  allocate ( self%horiz_interp_init(3) )
  self%horiz_interp_init = .FALSE.

END SUBROUTINE roms_getvalues_create

!------------------------------------------------------------------------------
!> Initializes GetValues horizontal interpolator according to C-grid type
!! variable. It uses OOPS unstructured interpolation with Barycentric weights
!! formula.

FUNCTION roms_getvalues_getinterp (self, geom, gtype, masked, locs)           &
                           RESULT (interp_index)

  CLASS (roms_getvalues),    intent(inout) :: self      !< GetValue object
  TYPE (roms_geom),  target, intent(in   ) :: geom      !< geometry object
  character (len=1),         intent(in   ) :: gtype     !< C-grid location
  logical,                   intent(in   ) :: masked    !< land/sea masking
  TYPE (ufo_locations),      intent(in   ) :: locs      !< observation locations

  integer                                  :: interp_index  !< C-grid type index

  integer                                  :: Istr, Iend, Jstr, Jend
  integer                                  :: np_in, np_out
  integer,                       parameter :: nn = 3    !< number of neighboors
  character (len=*),             parameter :: wtype = 'barycent'

  real (kind=kind_real),           pointer :: mask(:,:) => null()
  real (kind=kind_real),           pointer :: lon(:,:)  => null()
  real (kind=kind_real),           pointer :: lat(:,:)  => null()
  real (kind=kind_real),       allocatable :: lats_in(:), lons_in(:)
  real (8),                    allocatable :: locs_lons(:), locs_lats(:)

  ! Get the application lon-lat interpolator depending on C-grid type.

  SELECT CASE (gtype)
    CASE ('r')
      interp_index = 1
      lon  => geom%lonr
      lat  => geom%latr
      mask => geom%rmask
    CASE ('u')
      interp_index = 2
      lon  => geom%lonu
      lat  => geom%latu
      mask => geom%umask
    CASE ('v')
      interp_index = 3
      lon  => geom%lonv
      lat  => geom%latv
      mask => geom%vmask
    CASE DEFAULT
      CALL abor1_ftn('roms_getvalues_getinterp: illegal C-grid type: '       &
                     // gtype)
  END SELECT

  ! If appropriate, compute horizontal interpolation weigths.

  COMPUTE_WEIGHTS : IF (.not. self%horiz_interp_init(interp_index)) THEN

    ! Starting and ending indices for compute domain tile (no halo).

    Istr = geom%Istr
    Iend = geom%Iend
    Jstr = geom%Jstr
    Jend = geom%Jend

    ! Get observations (lon,lat) locations.

    np_out = locs%nlocs()
    allocate ( locs_lons(np_out) )
    allocate ( locs_lats(np_out) )
    CALL locs%get_lons (locs_lons)
    CALL locs%get_lats (locs_lats)

    ! Create interpolation weights.

    IF (.not.masked) THEN            ! unmasked fields

      np_in = (Iend - Istr + 1) * (Jend - Jstr + 1)
      allocate ( lons_in(np_in) )
      allocate ( lats_in(np_in) )

      lons_in = RESHAPE(lon(Istr:Iend,Jstr:Jend), (/np_in/))
      lats_in = RESHAPE(lat(Istr:Iend,Jstr:Jend), (/np_in/))

    ELSE                             ! masked fields

      np_in = COUNT(mask(Istr:Iend,Jstr:Jend) > 0.0_kind_real)
      allocate ( lons_in(np_in) )
      allocate ( lats_in(np_in) )

      lons_in  = PACK(lon(Istr:Iend,Jstr:Jend),                              &
                      MASK=mask(Istr:Iend,Jstr:Jend) > 0.0_kind_real)
      lats_in  = PACK(lat(Istr:Iend,Jstr:Jend),                              &
                      MASK=mask(Istr:Iend,Jstr:Jend) > 0.0_kind_real)
    END IF

    CALL self%horiz_interp(interp_index)%create (geom%f_comm, nn, wtype,     &
                                                 np_in, lats_in, lons_in,    &
                                                 np_out, locs_lats, locs_lons)
    self%horiz_interp_init(interp_index) = .TRUE.

  END IF COMPUTE_WEIGHTS

END FUNCTION roms_getvalues_getinterp

!------------------------------------------------------------------------------
!> Deletes GetValues object.

SUBROUTINE roms_getvalues_delete (self)

  CLASS (roms_getvalues), intent(inout) :: self

  deallocate (self%horiz_interp)
  deallocate (self%horiz_interp_init)

END SUBROUTINE roms_getvalues_delete

!------------------------------------------------------------------------------
!> Interpolates nonlinear model at observation locations and load its values
!! into the GeoVaLs object.

SUBROUTINE roms_getvalues_fillgeovals (self, geom, fld, t1, t2, locs, geovals)

  CLASS (roms_getvalues), intent(inout) :: self      !< GetValues object
  TYPE (roms_geom),       intent(in   ) :: geom      !< geometry object
  CLASS (roms_fields),    intent(in   ) :: fld       !< fields object
  TYPE (datetime),        intent(in   ) :: t1        !< start of time window
  TYPE (datetime),        intent(in   ) :: t2        !< end of time window
  TYPE (ufo_locations),   intent(in   ) :: locs      !< observation locations
  TYPE (ufo_geovals),     intent(inout) :: geovals   !< GeoVaLs object

  logical (c_bool),         allocatable :: time_mask(:)
  logical                               :: masked
  integer                               :: N, i, ival, ivar, k, nval
  integer                               :: Istr, Iend, Jstr, Jend, ns
  integer                               :: interp_index = -1
  real (kind=kind_real),    allocatable :: gom_window(:)
  real (kind=kind_real),    allocatable :: fld3d(:,:,:), fld3d_un(:)
  TYPE (roms_field),            pointer :: fldptr
  character (len=40)                    :: DateString(2)

  ! Starting and ending indices for the compute domain tile (no halo).

  Istr = geom%Istr
  Iend = geom%Iend
  Jstr = geom%Jstr
  Jend = geom%Jend
  N    = geom%N                         ! number of vertical levels in ROMS

  ! Get mask for locations in this time window.

  allocate ( time_mask(locs%nlocs()) )
  CALL locs%get_timemask (t1, t2, time_mask)
  
  IF (LdebugGetValues .and. (geom%f_comm%rank() .eq. 0)) THEN
    CALL datetime_to_string (t1, DateString(1))
    CALL datetime_to_string (t2, DateString(2))
    PRINT '(5a,10(1x,l1))', 'GeoVals: ', TRIM(DateString(1)), ' - ',         &
                                         TRIM(DateString(2)),                &
                            ', TimeMask: ', time_mask
  END IF

  ! Allocate temporary GeoVals and 3d field for the current time window.

  DO ivar = 1, geovals%nvar

    ! Set number of vertical levels or categories (nval). Notice that the
    ! GeoVaLs are in terms of the standard name and not ROMS internal name.

    CALL fld%get (geovals%variables(ivar), fldptr)

    nval   = fldptr%N
    masked = fldptr%metadata%masked

    IF (LdebugGetValues .and. (geom%f_comm%rank() .eq. 0)) THEN
      PRINT '(9a,l1,a,i0)',       'GeoVal = ', fldptr%metadata%io_name,      &
                                  ' :: ', fldptr%metadata%name,              &
                                  ' :: ', fldptr%metadata%getval_name,       &
                                  ' :: ', TRIM(geovals%variables(ivar)),     &
                                  ', masked = ', masked,                     &
                                  ', Nobs = ', locs%nlocs()
      PRINT '(3a,i0,a,3(i0,1x))', '  C-grid = ', fldptr%metadata%gtype,      &
                                  ', N = ',nval,                             &
                                  ', shape  = ', SHAPE(fldptr%val)
    END IF

    ! Return if no observations.

    IF (geovals%geovals(ivar)%nlocs .eq. 0) RETURN

    allocate ( gom_window(locs%nlocs()) )
    allocate ( fld3d(Istr:Iend,Jstr:Jend,1:nval) )

    fld3d = fldptr%val(Istr:Iend,Jstr:Jend,1:nval)

    ! If appropriate, compute horizontal interpolation weights for current
    ! C-grid type variable. It may have been computed previously in the
    ! DO-loop for "ivar".

    interp_index = self%get_interp(geom, fldptr%metadata%gtype, masked, locs)

    ! Apply forward interpolation level-by-level: Model ---> Observations.

    DO ival = 1, nval
      IF (masked) THEN
        ns = COUNT(fldptr%mask(Istr:Iend,Jstr:Jend) > 0.0_kind_real)
        IF (.not.allocated(fld3d_un)) allocate ( fld3d_un(ns) )
        fld3d_un = PACK(fld3d(Istr:Iend,Jstr:Jend,ival),                     &
                        MASK=fldptr%mask(Istr:Iend,Jstr:Jend) > 0.0_kind_real)
      ELSE
        ns = (Iend - Istr + 1) * (Jend - Jstr  + 1)
        IF (.not.allocated(fld3d_un)) allocate( fld3d_un(ns) )
        fld3d_un = RESHAPE(fld3d(Istr:Iend,Jstr:Jend,ival), (/ns/))
      END IF
      CALL self%horiz_interp (interp_index)%apply(fld3d_un(1:ns), gom_window)

      ! Fill GeoVaLs values according to time window. Flip the vertical levels
      ! such that level=1 in the GeoVaLs are next to the surface.  Recall that
      ! ROMS has a vertical enumeration such that level=1 is adjacent to the
      ! bathymetry.

      IF (nval .gt. 1) THEN
        k = (N - ival) + 1                     ! 3D state field
      ELSE
        k = ival                               ! 2D state field
      END IF

      DO i = 1, locs%nlocs()
        IF (time_mask(i)) THEN
          geovals%geovals(ivar)%vals(k, i) = gom_window(i)
      !   PRINT '(a,a4,2(a,i0),a,f0.4)', 'GeoVal :: ',                       &
      !                                  fldptr%metadata%name,               &
      !                                  ': Loc = ', i, ' k = ', k,          &
      !                                  ' value = ', gom_window(i)
        END IF
      END DO
    END DO

    ! Deallocate temporary arrays.

    deallocate (fld3d_un)
    deallocate (fld3d)
    deallocate (gom_window)

  END DO

  ! If we reach this point, GeoVaLs has been initialized.

  geovals%linit = .TRUE.

END SUBROUTINE roms_getvalues_fillgeovals

!------------------------------------------------------------------------------

END MODULE roms_getvalues_mod
