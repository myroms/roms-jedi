! (C) Copyright 2020-2021 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
!>
!! \brief   LinearGeoValues class for interpolating state vector at GeoVaLs
!!          locations
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

MODULE roms_lineargetvalues_mod

USE iso_c_binding
USE kinds,                          ONLY : kind_real

USE datetime_mod,                   ONLY : datetime, datetime_to_string
USE fckit_log_module,               ONLY : fckit_log
USE ufo_geovals_mod,                ONLY : ufo_geovals
USE ufo_locations_mod
USE unstructured_interpolation_mod, ONLY : unstrc_interp

USE roms_geom_mod,                  ONLY : roms_geom
use roms_getvalues_mod,             ONLY : roms_getvalues
USE roms_fields_mod,                ONLY : roms_fields, roms_field
USE roms_state_mod ,                ONLY : roms_state

implicit none

PRIVATE

TYPE, PUBLIC, EXTENDS(roms_getvalues) :: roms_lineargetvalues
  
  CONTAINS

  PROCEDURE :: fill_geovals_ad => roms_lineargetvalues_fillgeovals_ad

END TYPE roms_lineargetvalues

logical :: LdebugLinearGetValues = .FALSE.

!------------------------------------------------------------------------------
CONTAINS
!------------------------------------------------------------------------------

SUBROUTINE roms_lineargetvalues_fillgeovals_ad (self, geom, incr,             &
                                                t1, t2, locs, geovals)

  CLASS (roms_lineargetvalues), intent(inout) :: self    !< GetValues object
  TYPE (roms_geom),             intent(in   ) :: geom    !< geometry object
  CLASS (roms_fields),          intent(inout) :: incr    !< increment object
  TYPE (datetime),              intent(in   ) :: t1      !< start of time window
  TYPE (datetime),              intent(in   ) :: t2      !< end of time window
  TYPE (ufo_locations),         intent(in   ) :: locs    !< obs locations
  TYPE (ufo_geovals),           intent(in   ) :: geovals !< GeoVaLs object

  logical (c_bool),               allocatable :: time_mask(:)
  logical                                     :: masked
  integer                                     :: N, i, ival, ivar, k, nval
  integer                                     :: ni, nj, ns
  integer                                     :: interp_index = -1
  integer                                     :: Istr, Iend, Jstr, Jend
  real (kind=kind_real),          allocatable :: gom_window(:,:)
  real (kind=kind_real),          allocatable :: gom_window_ival(:)
  real (kind=kind_real),          allocatable :: incr3d(:,:,:), incr3d_un(:)
  TYPE (roms_field),                  pointer :: ad_field

  ! Starting and ending indices for the compute domain tile (no halo).

  Istr = geom%Istr
  Iend = geom%Iend
  Jstr = geom%Jstr
  Jend = geom%Jend
  N    = geom%N                         ! number of vertical levels in ROMS

  ! Get mask for locations in this time window.

  allocate ( time_mask(locs%nlocs()) )
  CALL locs%get_timemask (t1, t2, time_mask)
  allocate ( gom_window_ival(locs%nlocs()) )

  DO ivar = 1, geovals%nvar

    ! Set number of vertical levels or categories (nval). Notice that the GeoVaLs
    ! are in terms of the UFO standard name and not ROMS internal name.

    CALL incr%get (geovals%variables(ivar), ad_field)
    nval = ad_field%N

    ! Allocate temporary GeoVaLs and 3D field for the current time window.

    allocate ( gom_window(nval,locs%nlocs()) )
    allocate ( incr3d(Istr:Iend,Jstr:Jend,1:nval) )
    incr3d = 0.0_kind_real
    gom_window = 0.0_kind_real

    ! Determine if this variable should use the masked grid.

    masked = ad_field%metadata%masked

    ! Apply backward (adjoint) interpolation: Observations ---> Model

    IF (masked) THEN
      ns = COUNT(incr%geom%rmask(Istr:Iend,Jstr:Jend) > 0.0_kind_real)
    ELSE
      ni = Iend - Istr + 1
      nj = Jend - Jstr + 1
      ns = ni * nj
    END IF
    IF (.not.allocated(incr3d_un)) allocate ( incr3d_un(ns) )

    interp_index = self%get_interp(geom, ad_field%metadata%gtype, masked, locs)

    DO ival = 1, nval                          ! level by level         

      ! Fill GeoVaLs values according to time window. Flip the GeoVaLs vertical
      ! levels back such that level=1 correspond to ROMS level=N. Recall that
      ! ROMS has a vertical enumeration such that level=1 is adjacent to the
      ! bathymetry.

      IF (nval .gt. 1) THEN
        k = (N - ival) + 1                     ! 3D state field
      ELSE
        k = ival                               ! 2D state field
      END IF

      DO i = 1, locs%nlocs()
        IF (time_mask(i)) THEN
          gom_window(k, i) = geovals%geovals(ivar)%vals(ival, i)
        END IF
      END DO
      gom_window_ival = gom_window(k,1:locs%nlocs())

      ! Adjoint horizontal interpolation. Notice that we use the flipped
      ! vertical levels for ROMS adjoint state fields.

      IF (masked) THEN
        incr3d_un = PACK(incr3d(Istr:Iend,Jstr:Jend,k),                        &
                         MASK=ad_field%mask(Istr:Iend,Jstr:Jend) > 0.0)
        CALL self%horiz_interp(interp_index)%apply_ad (incr3d_un,              &
                                                       gom_window_ival)
        incr3d(Istr:Iend,Jstr:Jend,k) = UNPACK(incr3d_un,                      &
                    MASK=ad_field%mask(Istr:Iend,Jstr:Jend) > 0.0,             &
                    FIELD=incr3d(Istr:Iend,Jstr:Jend,k))
      ELSE
        incr3d_un = RESHAPE(incr3d(Istr:Iend,Jstr:Jend,k), (/ns/))
        CALL self%horiz_interp(interp_index)%apply_ad (incr3d_un(1:ns),        &
                                                       gom_window_ival)
        incr3d(Istr:Iend,Jstr:Jend,k) = RESHAPE(incr3d_un(1:ns),(/ni,nj/))
      END IF

    END DO

    ad_field%val(Istr:Iend,Jstr:Jend,1:nval) =                                 &
                                  ad_field%val(Istr:Iend,Jstr:Jend,1:nval) +   &
                                  incr3d(Istr:Iend,Jstr:Jend,1:nval)

    ! Deallocate temporary arrays.

    deallocate (incr3d)
    deallocate (gom_window)

  END DO

  deallocate (gom_window_ival)

END SUBROUTINE roms_lineargetvalues_fillgeovals_ad

!------------------------------------------------------------------------------

END MODULE roms_lineargetvalues_mod
