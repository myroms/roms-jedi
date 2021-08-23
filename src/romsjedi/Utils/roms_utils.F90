! (C) Copyright 2017-2020 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

MODULE roms_utils

USE atlas_module,           ONLY : atlas_geometry, atlas_indexkdtree
USE netcdf
USE kinds,                  ONLY : kind_real
use gsw_mod_toolbox,        ONLY : gsw_rho, gsw_sa_from_sp, gsw_ct_from_pt, gsw_mlp
use fckit_exception_module, ONLY : fckit_exception

implicit none

PRIVATE

PUBLIC  :: write2pe, roms_str2int, roms_adjust, &
           roms_rho, roms_diff, roms_mld, nc_check, roms_remap_idw

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------

ELEMENTAL FUNCTION roms_rho (sp, pt, p, lon, lat)

  real(kind=kind_real), intent(in)  :: pt, sp, p, lon, lat
  real(kind=kind_real) :: sa, ct, lon_rot, roms_rho

  ! Rotate longitude if necessary

  lon_rot = lon
  IF (lon < -180.0) lon_rot=lon+360.0
  IF (lon >  180.0) lon_rot=lon-360.0

  ! Convert practical salinity to absolute salinity

  sa = gsw_sa_from_sp (sp, p, lon_rot, lat)

  ! Convert potential temperature to concervative temperature

  ct = gsw_ct_from_pt (sa, pt)

  ! Insitu density

  roms_rho = gsw_rho(sa,ct,p)

  RETURN

END FUNCTION roms_rho

! ------------------------------------------------------------------------------

FUNCTION roms_mld (sp, pt, p, lon, lat)

  real(kind=kind_real), intent(in)  :: pt(:), sp(:), p(:), lon, lat

  real(kind=kind_real) :: lon_rot, roms_mld
  real(kind=kind_real), allocatable :: sa(:), ct(:)

  ! Rotate longitude if necessary

  lon_rot = lon
  IF (lon <-180.0) lon_rot=lon+360.0
  IF (lon > 180.0) lon_rot=lon-360.0

  ! Allocate memory

  allocate (sa(size(sp,1)), ct(size(sp,1)))

  ! Convert practical salinity to absolute salinity

  sa = gsw_sa_from_sp (sp, p, lon_rot, lat)

  ! Convert potential temperature to concervative temperature

  ct = gsw_ct_from_pt (sa, pt)

  ! Mixed layer depth

  roms_mld = gsw_mlp(sa,ct,p)
  IF (roms_mld>9999.9_kind_real) roms_mld = p(1)
  roms_mld = MAX(roms_mld, p(1))

  deallocate (sa, ct)

  RETURN

END FUNCTION roms_mld

! ------------------------------------------------------------------------------

SUBROUTINE roms_diff (dvdz,v,h)

  real(kind=kind_real), intent(in)  :: v(:), h(:)
  real(kind=kind_real), intent(out) :: dvdz(:)

  integer :: k, ik

  k = SIZE(v,1)

  DO ik = 2, k-1
     dvdz(ik) = (v(ik+1)-v(ik-1))/(h(ik)+0.5*h(ik+1)+h(ik-1))
  END DO
  dvdz(1) = dvdz(2)
  dvdz(k) = dvdz(k-1)

END SUBROUTINE roms_diff

! ------------------------------------------------------------------------------

SUBROUTINE write2pe (vec, varname, filename, append)

  real(kind=kind_real), intent(in) :: vec(:)
  character(len=*),     intent(in) :: varname
  character(len=256),   intent(in) :: filename
  logical,              intent(in) :: append

  integer(kind=4) :: iNcid
  integer(kind=4) :: iDim_ID
  integer(kind=4) :: iVar_ID
  integer         :: ndims=1, ns

  ns=SIZE(vec)
  IF (append) THEN  ! If file exists, append to it
    CALL nc_check (nf90_open(filename, NF90_WRITE, iNcid))
    CALL nc_check (nf90_inquire(iNcid, nDimensions = ndims))
    CALL nc_check (nf90_inq_dimid(iNcid, "ns", iDim_ID))
    CALL nc_check (nf90_redef(iNcid))
  ELSE
    CALL nc_check (nf90_create(filename, NF90_CLOBBER, iNcid))
    CALL nc_check (nf90_def_dim(iNcid, "ns", ns, iDim_ID))
  END IF

  ! Define of variables.

  CALL nc_check (nf90_def_var(iNcid, TRIM(varname), NF90_DOUBLE, (/iDim_ID/), iVar_ID))

  ! End define mode.

  CALL nc_check (nf90_enddef(iNcid))

  ! Writing

  CALL nc_check (nf90_put_var(iNcid, iVar_ID , vec))

  ! Close file.

  CALL nc_check (nf90_close(iNcid))

END SUBROUTINE write2pe

! ------------------------------------------------------------------------------

SUBROUTINE nc_check (status)

  integer(4), intent ( in) :: status

  IF (status /= nf90_noerr) THEN
     PRINT *, TRIM(nf90_strerror(status))
     STOP "Stopped"
  END IF

END SUBROUTINE nc_check

! ------------------------------------------------------------------------------
!> Apply bounds

ELEMENTAL FUNCTION roms_adjust (std, minstd, maxstd)

  real(kind=kind_real), intent(in)  :: std, minstd, maxstd
  real(kind=kind_real)              :: roms_adjust

  roms_adjust = MIN(MAX(std, minstd), maxstd)

END FUNCTION roms_adjust

! ------------------------------------------------------------------------------
subroutine roms_str2int(str, int)

  character(len=*),intent(in) :: str
  integer,intent(out)         :: int

  read(str,*)  int

END SUBROUTINE roms_str2int

! ------------------------------------------------------------------------------
! inverse distance weighted remaping (modified Shepard's method)

SUBROUTINE roms_remap_idw (lon_src, lat_src, data_src, lon_dst, lat_dst, data_dst)

  real(kind_real), intent(in) :: lon_src(:)
  real(kind_real), intent(in) :: lat_src(:)
  real(kind_real), intent(in) :: data_src(:)
  real(kind_real), intent(in) :: lon_dst(:,:)
  real(kind_real), intent(in) :: lat_dst(:,:)
  real(kind_real), intent(inout) :: data_dst(:,:)

  integer, parameter :: nn_max = 10
  real(kind_real), parameter :: idw_pow = 2.0

  integer :: idx(nn_max)
  integer :: n_src, i, j, n, nn
  real(kind_real) :: dmax, r, w(nn_max),  dist(nn_max)
  type(atlas_geometry) :: ageometry
  type(atlas_indexkdtree) :: kd

  ! Create kd tree

  n_src = size(lon_src)
  ageometry = atlas_geometry("UnitSphere")
  kd = atlas_indexkdtree(ageometry)
  CALL kd%reserve (n_src)
  CALL kd%build (n_src, lon_src, lat_src)

  ! Remap

  DO i = 1, SIZE(data_dst, dim=1)
    DO j = 1, SIZE(data_dst, dim=2)

      ! Get nn_max nearest neighbors

      CALL kd%closestPoints (lon_dst(i,j), lat_dst(i,j), nn_max, idx)

      ! Get distances. Add a small offset so there is never any 0 values

      DO n=1,nn_max
        dist(n) = ageometry%distance(lon_dst(i,j), lat_dst(i,j), &
                                     lon_src(idx(n)), lat_src(idx(n)))
      END DO
      dist = dist + 1e-6

      ! Truncate the list if the last points are the same distance.
      ! This is needed to ensure reproducibility across machines.
      ! The last point is always removed (becuase we don't know if it would
      ! have been identical to the one after it)

      nn=nn_max-1
      DO n=nn_max-1, 1, -1
        IF (dist(n) /= dist(nn_max)) EXIT
        nn = n-1
      END DO
      IF (nn <= 0 ) CALL fckit_exception%abort( &
        "No valid points found in IDW remapping, uh oh.")

      ! Calculate weights based on inverse distance

      dmax = MAXVAL(dist(1:nn))
      w = 0.0
      DO n=1,nn
        w(n) = ((dmax-dist(n)) / (dmax*dist(n))) ** idw_pow
      END DO
      w = w / SUM(w)

      ! Calculate final value

      r = 0.0
      DO n=1,nn
        r = r + data_src(idx(n))*w(n)
      END DO
      data_dst(i,j) = r

    END DO
  END DO

  ! Done, cleanup

  CALL kd%final ()

END SUBROUTINE roms_remap_idw

! ------------------------------------------------------------------------------

END MODULE roms_utils
