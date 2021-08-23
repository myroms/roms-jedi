! (C) Copyright 2020-2020 UCAR.
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
! ------------------------------------------------------------------------------

MODULE roms_convert_state_mod

  USE roms_geom_mod
  USE roms_fields_mod
  USE roms_utils, only: roms_remap_idw
  USE kinds, only: kind_real
  USE fms_io_mod, only: read_data, write_data, fms_io_init, fms_io_exit
  USE MOM_remapping, only : remapping_CS, initialize_remapping, remapping_core_h
  USE MOM_domains, only : pass_var, root_PE, sum_across_pes
  USE mpp_mod, only     : mpp_broadcast, mpp_sync, mpp_sync_self
  USE MOM_error_handler, only : MOM_mesg, MOM_error, FATAL, WARNING, is_root_pe
  USE mpp_domains_mod, only  : mpp_global_field, mpp_update_domains
  USE horiz_interp_mod, only : horiz_interp_new, horiz_interp, horiz_interp_type
  USE MOM_horizontal_regridding, only : meshgrid, fill_miss_2d
  USE MOM_grid, only : ocean_grid_type
  USE fckit_exception_module, only: fckit_exception

  implicit none

  PRIVATE

  TYPE, public :: roms_convertstate_type

    real(kind=kind_real), allocatable, dimension(:,:,:) :: hocn_src, hocn_des

    CONTAINS
      PROCEDURE :: setup           => roms_convertstate_setup
      PROCEDURE :: change_resol    => roms_convertstate_change_resol
      PROCEDURE :: change_resol2d  => roms_convertstate_change_resol2d
      PROCEDURE :: clean           => roms_convertstate_delete

  END TYPE roms_convertstate_type

! ------------------------------------------------------------------------------
CONTAINS

SUBROUTINE roms_convertstate_setup (self, src, des, hocn, hocn2)

  CLASS (roms_convertstate_type), intent(inout) :: self
  TYPE (roms_geom),               intent(inout) :: src, des
  TYPE (roms_field),              intent(inout) :: hocn, hocn2

  integer                                       :: tmp(1)

  CALL fms_io_init ()

  CALL read_data (TRIM(src%geom_grid_file), 'nzo_zstar', tmp(1), domain=src%Domain%mpp_domain)
  src%nzo_zstar = tmp(1)

  CALL read_data (TRIM(des%geom_grid_file), 'nzo_zstar', tmp(1), domain=des%Domain%mpp_domain)
  des%nzo_zstar = tmp(1)

  IF (des%nzo_zstar /= src%nzo_zstar) CALL fckit_exception%abort(&
     "target nzo_zstar /= source nzo_zstar! Reset maximum depth in target grid MOM_input file and re-run soca gridgen")


  IF (allocated(src%h_zstar)) deallocate (src%h_zstar)
  allocate (src%h_zstar(src%isd:src%ied,src%jsd:src%jed,1:src%nzo_zstar))
  CALL read_data (TRIM(src%geom_grid_file), 'h_zstar', src%h_zstar, domain=src%Domain%mpp_domain)

  IF (allocated(des%h_zstar)) deallocate (des%h_zstar)
  allocate (des%h_zstar(des%isd:des%ied,des%jsd:des%jed,1:des%nzo_zstar))
  CALL read_data (TRIM(des%geom_grid_file), 'h_zstar', des%h_zstar, domain=des%Domain%mpp_domain)

  call fms_io_exit()

  allocate (self%hocn_src(src%isd:src%ied,src%jsd:src%jed,1:src%nzo))
  allocate (self%hocn_des(des%isd:des%ied,des%jsd:des%jed,1:des%nzo))

  ! Set hocn for target grid

  hocn2%val = des%h
  self%hocn_src = hocn%val
  self%hocn_des = hocn2%val

END SUBROUTINE roms_convertstate_setup

! ------------------------------------------------------------------------------
!> Cleanup

SUBROUTINE roms_convertstate_delete (self)

  CLASS (roms_convertstate_type), intent(inout) :: self

  deallocate (self%hocn_src)
  deallocate (self%hocn_des)

END SUBROUTINE roms_convertstate_delete

! ------------------------------------------------------------------------------

SUBROUTINE roms_convertstate_change_resol2d (self, field_src, field_des, geom_src, geom_des)

  CLASS (roms_convertstate_type), intent(inout) :: self
  TYPE (roms_field), pointer,     intent(inout) :: field_src, field_des
  TYPE (roms_geom),               intent(inout) :: geom_src, geom_des

  integer :: i, j, k, tmp_nz, nz_
  integer :: isc1, iec1, jsc1, jec1, isd1, ied1, jsd1, jed1, isg, ieg, jsg, jeg
  integer :: isc2, iec2, jsc2, jec2, isd2, ied2, jsd2, jed2

  type(remapping_CS)  :: remapCS2
  type(horiz_interp_type) :: Interp

  real(kind=kind_real) :: missing = 0.d0
  real(kind=kind_real) :: z_tot
  real(kind=kind_real), dimension(geom_src%isg:geom_src%ieg) :: lon_in
  real(kind=kind_real), dimension(geom_src%jsg:geom_src%jeg) :: lat_in
  real(kind=kind_real), dimension(geom_des%isd:geom_des%ied,geom_des%jsd:geom_des%jed) :: lon_out, lat_out
  real(kind=kind_real), dimension(geom_des%isd:geom_des%ied,geom_des%jsd:geom_des%jed) :: mask_
  real(kind=kind_real), allocatable :: tmp(:,:,:), tmp2(:,:,:), gdata(:,:,:)

  ! Indices for compute, data, and global domain for source

  isc1 = geom_src%isc ; iec1 = geom_src%iec ; jsc1 = geom_src%jsc ; jec1 = geom_src%jec
  isd1 = geom_src%isd ; ied1 = geom_src%ied ; jsd1 = geom_src%jsd ; jed1 = geom_src%jed
  isg = geom_src%isg ; ieg = geom_src%ieg ; jsg = geom_src%jsg ; jeg = geom_src%jeg

  ! Indices for compute and data domain for des

  isc2 = geom_des%isc ; iec2 = geom_des%iec ; jsc2 = geom_des%jsc ; jec2 = geom_des%jec
  isd2 = geom_des%isd ; ied2 = geom_des%ied ; jsd2 = geom_des%jsd ; jed2 = geom_des%jed

  lon_in = geom_src%lonh ; lat_in = geom_src%lath
  IF (field_src%name == "uocn" .and. field_des%name == "uocn") lon_in = geom_src%lonq
  IF (field_src%name == "vocn" .and. field_des%name == "vocn") lat_in = geom_src%latq

  ! Initialize work arrays

  nz_ = field_src%nz
  allocate (tmp(isd1:ied1,jsd1:jed1,1:nz_))
  allocate (gdata(isg:ieg,jsg:jeg,1:nz_))
  allocate (tmp2(isd2:ied2,jsd2:jed2,1:nz_))
  tmp = 0.d0 ; gdata = 0.d0 ; tmp2 = 0.d0;
  tmp(:,:,1:nz_) = field_src%val(:,:,1:nz_)

  ! Reconstruct global input field

  CALL mpp_update_domains (tmp, geom_src%Domain%mpp_domain)
  mask_ = field_des%mask
  CALL mpp_global_field (geom_src%Domain%mpp_domain, tmp(:,:,1:nz_), gdata(:,:,1:nz_) )

  ! Interpolate to destination geometry

  CALL roms_hinterp (geom_des,field_des%val,gdata,mask_(:,:),nz_,missing,lon_in,lat_in,field_des%lon,field_des%lat)

  ! Update halos

  CALL mpp_update_domains (field_des%val, geom_des%Domain%mpp_domain)

END SUBROUTINE roms_convertstate_change_resol2d

! ------------------------------------------------------------------------------

SUBROUTINE roms_convertstate_change_resol (self, field_src, field_des, geom_src, geom_des)

  CLASS (roms_convertstate_type), intent(inout) :: self
  TYPE (roms_field), pointer,     intent(inout) :: field_src, field_des
  TYPE (roms_geom),               intent(inout) :: geom_src, geom_des

  integer :: i, j, k, tmp_nz, nz_
  integer :: isc1, iec1, jsc1, jec1, isd1, ied1, jsd1, jed1, isg, ieg, jsg, jeg
  integer :: isc2, iec2, jsc2, jec2, isd2, ied2, jsd2, jed2
  type(remapping_CS)  :: remapCS2
  type(horiz_interp_type) :: Interp
  real(kind=kind_real) :: missing = 0.d0
  real(kind=kind_real) :: PI_180, z_tot
  real(kind=kind_real), dimension(geom_src%isg:geom_src%ieg) :: lon_in
  real(kind=kind_real), dimension(geom_src%jsg:geom_src%jeg) :: lat_in
  real(kind=kind_real), dimension(geom_des%isd:geom_des%ied,geom_des%jsd:geom_des%jed) :: lon_out, lat_out
  real(kind=kind_real), dimension(geom_des%isd:geom_des%ied,geom_des%jsd:geom_des%jed) :: mask_
  real(kind=kind_real), allocatable :: tmp(:,:,:), tmp2(:,:,:), gdata(:,:,:)
  real(kind=kind_real), allocatable :: h1(:), h2(:)
  real(kind=kind_real), dimension(geom_src%isd:geom_src%ied,geom_src%jsd:geom_src%jed,1:geom_src%nzo_zstar) :: h_new1
  real(kind=kind_real), dimension(geom_des%isd:geom_des%ied,geom_des%jsd:geom_des%jed,1:geom_des%nzo_zstar) :: h_new2

  PI_180=ATAN(1.0d0)/45.0d0

  ! Indices for compute, data, and global domain for source

  isc1 = geom_src%isc ; iec1 = geom_src%iec ; jsc1 = geom_src%jsc ; jec1 = geom_src%jec
  isd1 = geom_src%isd ; ied1 = geom_src%ied ; jsd1 = geom_src%jsd ; jed1 = geom_src%jed
  isg  = geom_src%isg ; ieg  = geom_src%ieg ; jsg  = geom_src%jsg ; jeg  = geom_src%jeg

  ! Indices for compute and data domain for des

  isc2 = geom_des%isc ; iec2 = geom_des%iec ; jsc2 = geom_des%jsc ; jec2 = geom_des%jec
  isd2 = geom_des%isd ; ied2 = geom_des%ied ; jsd2 = geom_des%jsd ; jed2 = geom_des%jed

  ! Initialize vertical remapping

  CALL initialize_remapping (remapCS2,'PPM_IH4')

  ! Set grid thickness based on zstar level for src & target grid

  IF (field_des%io_file=="ocn".or.field_des%io_file=='ice') THEN
    mask_ = field_des%mask
    h_new1(isc1:iec1,jsc1:jec1,1:geom_src%nzo_zstar) = geom_src%h_zstar(isc1:iec1,jsc1:jec1,1:geom_src%nzo_zstar)
    h_new2(isc2:iec2,jsc2:jec2,1:geom_des%nzo_zstar) = geom_des%h_zstar(isc2:iec2,jsc2:jec2,1:geom_des%nzo_zstar)
    call mpp_update_domains (mask_, geom_des%Domain%mpp_domain)
    call mpp_update_domains (h_new1, geom_src%Domain%mpp_domain)
    call mpp_update_domains (h_new2, geom_des%Domain%mpp_domain)
  ELSE
    mask_ = 1.d0
  END IF

  ! Target hocn has been set in setup

  IF (field_des%name == "hocn" ) THEN
    RETURN
  END if
  lon_in = geom_src%lonh ; lat_in = geom_src%lath
  IF (field_src%name == "uocn" .and. field_des%name == "uocn") lon_in = geom_src%lonq
  IF (field_src%name == "vocn" .and. field_des%name == "vocn") lat_in = geom_src%latq

!  call meshgrid(geom_des%lonh(isd2:ied2),geom_des%lath(jsd2:jed2),lon_out,lat_out)
!  if (field_des%name == "uocn") call meshgrid(geom_des%lonq(isd2:ied2),geom_des%lath(jsd2:jed2),lon_out,lat_out)
!  if (field_des%name == "vocn") call meshgrid(geom_des%lonh(isd2:ied2),geom_des%latq(jsd2:jed2),lon_out,lat_out)

  ! Converts src grid to zstar coordinate

  nz_ = geom_src%nzo_zstar
  IF (field_src%nz == 1 .or. field_src%io_file=="ice") nz_ = field_src%nz
  allocate (tmp(isd1:ied1,jsd1:jed1,1:nz_))
  allocate (gdata(isg:ieg,jsg:jeg,1:nz_))
  allocate (tmp2(isd2:ied2,jsd2:jed2,1:nz_))
  allocate(h1(field_src%nz),h2(nz_))
  tmp = 0.d0 ; gdata = 0.d0 ; tmp2 = 0.d0;

  IF ( field_src%nz > 1 .and. field_src%io_file/="ice") THEN
    DO j = jsc1, jec1
      DO i = isc1, iec1
        tmp_nz = field_src%nz
        IF (field_src%name =="uocn") THEN
          IF (field_src%mask(i,j)>0.) THEN
            h1(1:tmp_nz) = 0.5 * ( self%hocn_src(i,j,1:tmp_nz) + self%hocn_src(i+1,j,1:tmp_nz) )
            h2(1:nz_) = 0.5 * ( h_new1(i,j,1:nz_) + h_new1(i+1,j,1:nz_) )
            CALL remapping_core_h (remapCS2, tmp_nz, h1(1:tmp_nz), field_src%val(i,j,1:tmp_nz), &
                                   nz_, h2(1:nz_), tmp(i,j,1:nz_))
          END IF
        ELSE IF (field_src%name =="vocn") THEN
          IF (field_src%mask(i,j)>0.) THEN
            h1(1:tmp_nz) = 0.5 * ( self%hocn_src(i,j,1:tmp_nz) + self%hocn_src(i,j+1,1:tmp_nz) )
            h2(1:nz_) = 0.5 * ( h_new1(i,j,1:nz_) + h_new1(i,j+1,1:nz_) )
            CALL remapping_core_h (remapCS2, tmp_nz, h1(1:tmp_nz), field_src%val(i,j,1:tmp_nz), &
                                   nz_, h2(1:nz_), tmp(i,j,1:nz_))
          END IF
        ELSE
          IF (field_src%mask(i,j) > 0.d0) THEN
            CALL remapping_core_h (remapCS2, tmp_nz, self%hocn_src(i,j,1:tmp_nz), field_src%val(i,j,1:tmp_nz), &
                                   nz_, h_new1(i,j,1:nz_), tmp(i,j,1:nz_))
          END IF
        END IF
      END DO !i
    END DO !j
  ELSE
    IF (field_src%io_file=="ocn") tmp(:,:,1) = field_src%val(:,:,1) !*field_src%mask(:,:) !2D
    IF (field_src%io_file=="sfc") tmp(:,:,1) = field_src%val(:,:,1) !2D no mask
    IF (field_src%io_file=="ice") tmp(:,:,1:nz_) = field_src%val(:,:,1:nz_)
  END IF ! field_src%nz > 1

  CALL mpp_update_domains (tmp, geom_src%Domain%mpp_domain)

  ! Convert src field to target field at zstar coord

  CALL mpp_global_field (geom_src%Domain%mpp_domain, tmp(:,:,1:nz_), gdata(:,:,1:nz_) )
  CALL roms_hinterp (geom_des,tmp2(:,:,1:nz_),gdata,mask_(:,:),nz_,missing,lon_in,lat_in,field_des%lon,field_des%lat)

  CALL mpp_update_domains (tmp2, geom_des%Domain%mpp_domain)

  ! Final step: vertical remapping to desired vertical coordinate

  IF (allocated(h1)) deallocate(h1)
  IF (allocated(h2)) deallocate(h2)
  allocate (h1(nz_),h2(field_des%nz))

  IF ( field_des%nz > 1 .and. field_des%io_file/="ice") THEN
    DO j = jsc2, jec2
      DO i = isc2, iec2
        tmp_nz = nz_ !assume geom_src%nzo_zstar == geom%des%nzo_zstar
        IF (field_des%name =="uocn") THEN
          IF (field_des%mask(i,j)>0.) THEN
            h1(1:tmp_nz) = 0.5 * ( h_new2(i,j,1:tmp_nz) + h_new2(i+1,j,1:tmp_nz) )
            h2(1:field_des%nz) = 0.5 * ( self%hocn_des(i,j,1:field_des%nz) + self%hocn_des(i+1,j,1:field_des%nz) )
            CALL remapping_core_h (remapCS2, tmp_nz, h1(1:tmp_nz), tmp2(i,j,1:tmp_nz), &
                                   field_des%nz, h2(1:field_des%nz), field_des%val(i,j,1:field_des%nz))
          END IF
        ELSE IF (field_des%name =="vocn") THEN
          IF (field_des%mask(i,j)>0.) THEN
            h1(1:tmp_nz) = 0.5 * ( h_new2(i,j,1:tmp_nz) + h_new2(i,j+1,1:tmp_nz) )
            h2(1:field_des%nz) = 0.5 * ( self%hocn_des(i,j,1:field_des%nz) + self%hocn_des(i,j+1,1:field_des%nz) )
            CALL remapping_core_h (remapCS2, tmp_nz, h1(1:tmp_nz), tmp2(i,j,1:tmp_nz), &
                                   field_des%nz, h2(1:field_des%nz), field_des%val(i,j,1:field_des%nz))
          END IF
        ELSE
          IF (field_des%mask(i,j)>0.) THEN
            CALL remapping_core_h (remapCS2, tmp_nz, h_new2(i,j,1:tmp_nz), tmp2(i,j,1:tmp_nz), &
                                   field_des%nz, self%hocn_des(i,j,1:field_des%nz), field_des%val(i,j,1:field_des%nz))
          END IF
        END IF
      END DO !j
    END DO !i
  ELSE
   IF (field_des%io_file=="ocn") field_des%val(:,:,1) = tmp2(:,:,1)*field_des%mask(:,:) ! 2D
   IF (field_des%io_file=="sfc") field_des%val(:,:,1) = tmp2(:,:,1) ! 2D no mask
   IF (field_des%io_file=="ice") field_des%val(:,:,1:field_des%nz) = tmp2(:,:,1:field_des%nz)
  END IF ! nz > 1

  CALL mpp_update_domains (field_des%val, geom_des%Domain%mpp_domain)

END SUBROUTINE roms_convertstate_change_resol

! ------------------------------------------------------------------------------

SUBROUTINE ROMS_HINTERP (self,field2,gdata,mask2,nz,missing,lon_in,lat_in,lon_out,lat_out)

  CLASS (roms_geom),  intent(inout) :: self
  real(kind=kind_real), dimension(self%isd:self%ied,self%jsd:self%jed,1:nz), intent(inout) :: field2
  real(kind=kind_real), dimension(:,:,:), intent(in) :: gdata
  real(kind=kind_real), dimension(self%isd:self%ied,self%jsd:self%jed), intent(in) :: mask2
  integer, intent(in) :: nz
  real(kind=kind_real), intent(in) :: missing
  real(kind=kind_real), dimension(:), intent(in) :: lon_in, lat_in
  real(kind=kind_real), dimension(self%isd:self%ied,self%jsd:self%jed), intent(in) :: lon_out, lat_out


  integer :: i, j, k, isg, ieg, jsg, jeg, jeg1
  integer :: isc2, iec2, jsc2, jec2, npoints
  real(kind=kind_real) :: roundoff = 1.e-5
  real(kind=kind_real) :: PI_180
  type(horiz_interp_type) :: Interp
  type(ocean_grid_type) :: grid
  real(kind_real), dimension(:), allocatable :: lath_inp
  real(kind_real), dimension(:,:), allocatable :: lon_inp, lat_inp, tr_inp, mask_in_
  real(kind_real), dimension(self%isd:self%ied,self%jsd:self%jed) :: tr_out, fill, good, prev, mask_out_
  real(kind=kind_real) :: max_lat,min_lat, pole, npole, varavg
  real(kind=kind_real), dimension(:), allocatable :: last_row, lonh, lath
  logical :: add_np, add_sp

  PI_180=ATAN(1.0d0)/45.0d0

  isg = 1; jsg = 1;
  ieg = SIZE(gdata,1); jeg = SIZE(gdata,2)

  ! Indices for compute domain for regional model

  isc2 = self%isc ; iec2 = self%iec ; jsc2 = self%jsc ; jec2 = self%jec

  grid%isc = self%isc ; grid%iec = self%iec ; grid%jsc = self%jsc ; grid%jec = self%jec
  grid%isd = self%isd ; grid%ied = self%ied ; grid%jsd = self%jsd ; grid%jed = self%jed
  grid%Domain => self%Domain

  jeg1=jeg
  max_lat = MAXVAL(lat_in)
  add_np=.false.
  IF (max_lat < 90.0) THEN
    add_np=.true.
    jeg1=jeg1+1
    allocate (lath(jsg:jeg1))
    lath(jsg:jeg)=lat_in(:)
    lath(jeg1)=90.d0
  ELSE
    allocate (lath(jsg:jeg1))
    lath(:) = lat_in
  END IF
  min_lat = MINVAL(lat_in)
  add_sp=.false.
  IF (min_lat > -90.0) THEN
    add_sp=.true.
    jeg1=jeg1+1
    IF (allocated(lath_inp)) deallocate(lath_inp)
    allocate (lath_inp(jeg1))
    lath_inp(jsg+1:jeg1)=lath(:)
    lath_inp(jsg)=-90.d0
    IF (allocated (lath)) deallocate(lath)
    allocate (lath(jsg:jeg1))
    lath(:)=lath_inp(:)
  END IF

  allocate (lonh(isg:ieg))
  lonh(:) = lon_in(:)

  allocate (lon_inp(isg:ieg,jsg:jeg1))
  allocate (lat_inp(isg:ieg,jsg:jeg1))
  CALL meshgrid (lonh,lath,lon_inp,lat_inp)

  allocate (mask_in_(isg:ieg,jsg:jeg1))
  allocate (tr_inp(isg:ieg,jsg:jeg1))
  allocate (last_row(isg:ieg))

  DO k = 1, nz
    ! extrapolate the input data to the north pole using the northerm-most latitude
    IF (is_root_pe()) THEN
      IF (add_np) THEN
        last_row(:)=gdata(:,jeg,k); pole=0.d0; npole=0.d0
        DO i=isg,ieg
          IF (ABS(gdata(i,jeg,k)-missing) > ABS(roundoff)) THEN
            pole = pole+last_row(i)
            npole = npole+1.d0
          END IF
        END DO
        IF (npole > 0) THEN
          pole=pole/npole
        ELSE
          pole=missing
        END IF

        IF (add_sp) THEN
          tr_inp(:,jsg) = gdata(:,jsg,k)
          tr_inp(:,jsg+1:jeg1-1) = gdata(:,:,k)
          tr_inp(:,jeg1) = pole
        ELSE
          tr_inp(:,jsg:jeg) = gdata(:,:,k)
          tr_inp(:,jeg1) = pole
        ENDIF

      ELSE
        IF (add_sp) THEN
          tr_inp(:,jsg) = gdata(:,jsg,k)
          tr_inp(:,jsg+1:jeg1) = gdata(:,:,k)
        ELSE
          tr_inp(isg:ieg,jsg:jeg) = gdata(isg:ieg,jsg:jeg,k)
        END IF !add_sp
      END IF !add_np
    END IF !root_pe

    CALL mpp_sync ()
    CALL mpp_broadcast (tr_inp, ieg*jeg1, root_PE())
    CALL mpp_sync_self ()

    mask_in_ = 1.d0
    DO j=jsg,jeg1 ; do i=isg,ieg
      IF (ABS(tr_inp(i,j)-missing) <= ABS(roundoff)) THEN
        tr_inp(i,j) = missing
        mask_in_(i,j) = 0.d0;
      END IF
    END DO ; END DO

    tr_out(:,:) = 0.d0

    ! initialize horizontal remapping

    IF (k==1) CALL horiz_interp_new (Interp, lon_inp(:,:)*PI_180, lat_inp(:,:)*PI_180, lon_out(isc2:iec2,jsc2:jec2)*PI_180, &
       lat_out(isc2:iec2,jsc2:jec2)*PI_180, interp_method='bilinear', src_modulo=.true., mask_in=mask_in_)

    CALL horiz_interp (Interp, tr_inp, tr_out(isc2:iec2,jsc2:jec2), mask_in=mask_in_, missing_value=missing, missing_permit=3)

    mask_out_ = 1.d0 ; fill = 0.d0 ; good = 0.d0
    npoints = 0 ; varavg = 0.d0
    DO j=jsc2,jec2
      DO i=isc2,iec2
        IF (ABS(tr_out(i,j)-missing) < ABS(roundoff)) mask_out_(i,j)=0.d0
        IF (mask_out_(i,j) < 1.0d0) THEN
          tr_out(i,j) = missing
        ELSE
          good(i,j) = 1.0d0
          npoints = npoints + 1
          varavg = varavg + tr_out(i,j)
        END IF
        IF (mask2(i,j) == 1.d0 .and. mask_out_(i,j) < 1.0d0) fill(i,j) = 1.d0
      END DO !i
    END DO !j
    CALL pass_var (fill, self%Domain) ; CALL pass_var (good, self%Domain)
    CALL sum_across_pes (npoints) ; CALL sum_across_pes (varavg)
    IF (npoints > 0) THEN
      varavg = varavg/REAL(npoints)
    END IF

    IF (k==1) prev(:,:) = tr_out(:,:)
    CALL fill_miss_2d (tr_out, good, fill, prev=prev, G=grid, smooth=.true.)

    !TODO: In case fill_miss_2d failed at surface (k=1), use IDW to fill data pt that is located in ocean mask
    !Problem: IDW is compiler-dependent

    field2(:,:,k) = tr_out(:,:)*mask2(:,:)
    prev(:,:) = field2(:,:,k)

  END DO

END SUBROUTINE roms_hinterp

END MODULE roms_convert_state_mod
