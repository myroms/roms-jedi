!
! (C) Copyright 2017-2021 UCAR
! 
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0. 
!
!>
!! \brief   Initialize **GeoVaLs** with an analytical state
!!
!! \details Takes an existing GeoVaLs object and fill values of the ROMS state
!!          fields with analytical expression. It is inteded for testing the
!!          intepolation of the state at the observation locations.  The
!!          analytical formulas need the bathymetry and the level depths
!!          at the observation locations. Their values are already available
!!          in the GeoVaLs object. They were interpolated in **GetValues**
!!          routine **roms_getvalues_fillgeovals**.
!!
!! \author  Hernan G. Arango (Rutgers University)
!! \date    July 2021

MODULE roms_analyticinit_mod

USE kinds,                ONLY : kind_real

USE roms_fieldsutils_mod, ONLY : ana_fields

USE ufo_geovals_mod,      ONLY : ufo_geovals
USE ufo_locations_mod,    ONLY : ufo_locations

implicit none

PRIVATE
PUBLIC  :: roms_analytic_init

logical :: LdebugAnalyticInit = .FALSE.

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------
!> Initialize GeoVals with analytical expressions. The state variables are
!! over-written with analytical values except the bathymetry and the level
!! depths.

SUBROUTINE roms_analytic_init (self, locs, ana_method)

  TYPE (ufo_geovals),   intent(inout) :: self        !< GeoVaLs object
  TYPE (ufo_locations), intent(in   ) :: locs        !< observation locations
  character (len=*),    intent(in   ) :: ana_method  !< analytical case

  integer                             :: iloc, ivar, ival, nloc, nvar
  real (kind=kind_real)               :: mask, value
  real (kind=kind_real), allocatable  :: locs_lons(:), locs_lats(:)

  ! Check if GeoVaLs are defined.

  IF (.not. self%linit) THEN
    CALL abor1_ftn ("roms_analytic_init: GeoVaLs not defined.")
  END IF

  nloc = locs%nlocs()
  nvar = self%nvar

  ! Get GeoVaLs (lon,lat) locations.

  allocate ( locs_lons(nloc) )
  allocate ( locs_lats(nloc) )
  CALL locs%get_lons (locs_lons)
  CALL locs%get_lats (locs_lats)

  IF (LdebugAnalyticInit) THEN
    PRINT '(a,10(1x,f0.4))', 'AnalyticInit Lon  = ', locs_lons
    PRINT '(a,10(1x,f0.4))', 'AnalyticInit Lat  = ', locs_lats
    PRINT '(a,10(1x,f0.4))', 'AnalyticInit h    = ', self%geovals(nvar-1)%vals
    PRINT '(a,10(1x,f0.4))', 'AnalyticInit z    = ', self%geovals(nvar)%vals
  END IF

  ! Fill GeoVals with analytical expresions. Use the bathmetry and level depths
  ! already interpolated at the GeoVaLs locations in the GetValues routine
  ! "roms_getvalues_fillgeovals".  Notice that in the YAML file the keyword
  ! "state variables" has:
  !
  ! bathymetry   = self%geovals(nvar-1)%vals(1,:) ! penultimate variable in list
  ! level depths = self%geovals(nvar)%vals(:,:)   ! last in variable list

  mask = 1.0_kind_real    ! Assume that all GeoVaLs are at water locations

  DO ivar = 1, nvar
    DO iloc = 1, self%geovals(ivar)%nlocs
      DO ival = 1, self%geovals(ivar)%nval    
        CALL ana_fields (TRIM(self%variables(ivar)),                         &
                         mask,                                               &
                         locs_lons(iloc),                                    &
                         locs_lats(iloc),                                    &
                         self%geovals(nvar)%vals(ival,iloc),                 &
                         self%geovals(nvar-1)%vals(1,iloc),                  &
                         value)                               
        self%geovals(ivar)%vals(ival, iloc) = value
      END DO
    END DO
  END DO

  ! Deallocate local variables.

  IF (allocated(locs_lons))   deallocate (locs_lons)
  IF (allocated(locs_lats))   deallocate (locs_lats)

END SUBROUTINE roms_analytic_init

! ------------------------------------------------------------------------------

END MODULE roms_analyticinit_mod
