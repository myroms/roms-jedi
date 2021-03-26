! (C) Copyright 2017-2020 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

MODULE roms_fieldsutils_mod

USE fckit_configuration_module, ONLY : fckit_configuration
USE datetime_mod,               ONLY : datetime, &
                                       datetime_to_string, &
                                       datetime_create, &
                                       datetime_diff
USE duration_mod,               ONLY : duration, &
                                       duration_to_string
USE kinds,                      ONLY : kind_real

implicit none

PRIVATE

PUBLIC  :: fldinfo
PUBLIC  :: roms_genfilename

INTERFACE fldinfo
  MODULE PROCEDURE fldinfo3d, fldinfo2d
END INTERFACE fldinfo

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------

SUBROUTINE fldinfo3d (fld, mask, info)

  real(kind=kind_real),  intent(in) :: fld(:,:,:)
  logical,               intent(in) :: mask(:,:)
  real(kind=kind_real), intent(out) :: info(3)

  integer                           :: k
  real(kind=kind_real)              :: buffer(3,size(fld, dim=3))

  ! Calculate the min/max/sum separately for each masked level

  DO k = 1, SIZE(buffer, dim=2)
     buffer(1,z) = MINVAL(fld(:,:,k), mask=mask)
     buffer(2,z) = MAXVAL(fld(:,:,k), mask=mask)
     buffer(3,z) = SUM   (fld(:,:,k), mask=mask) / SIZE(fld, dim=3)
  end do

  ! Then, combine the min/max/sum over all levels

  info(1) = MINVAL(buffer(1,:))
  info(2) = MAXVAL(buffer(2,:))
  info(3) = SUM   (buffer(3,:))

END SUBROUTINE fldinfo3d

! ------------------------------------------------------------------------------

SUBROUTINE fldinfo2d (fld, mask, info)

  real(kind=kind_real),  intent(in) :: fld(:,:)
  logical,               intent(in) :: mask(:,:)
  real(kind=kind_real), intent(out) :: info(3)

  info(1) = minval(fld, mask=mask)
  info(2) = maxval(fld, mask=mask)
  info(3) = sum(   fld, mask=mask)

END SUBROUTINE fldinfo2d

! ------------------------------------------------------------------------------
!> Generate filename (based on oops/qg)

FUNCTION roms_genfilename (f_conf, length, vdate, domain_type)

  type(fckit_configuration),  intent(in) :: f_conf
  integer,                    intent(in) :: length
  type(datetime),             intent(in) :: vdate
  character(len=3), optional, intent(in) :: domain_type

  integer                                :: lenfn
  character(len=length)                  :: roms_genfilename
  character(len=length)                  :: fdbdir, expver, typ, validitydate, &
                                          & referencedate, sstep, prefix, mmb
  type(datetime)                         :: rdate
  type(duration)                         :: step
  character(len=:),          allocatable :: str

  CALL f_conf%get_or_die ("datadir", str)
  fdbdir = str

  CALL f_conf%get_or_die ("exp", str)
  expver = str

  CALL f_conf%get_or_die ("type", str)
  typ = str

  IF (present(domain_type)) THEN
    expver = trim(domain_type)//"."//expver
  ELSE
    expver = "ocn.ice."//expver
  END IF

  IF (typ=="ens") THEN
    CALL f_conf%get_or_die ("member", str)
    mmb = str
    lenfn = LEN_TRIM(fdbdir) + 1 + LEN_TRIM(expver) + 1 + LEN_TRIM(typ) + 1 + LEN_TRIM(mmb)
    prefix = TRIM(fdbdir) // "/" // TRIM(expver) // "." // TRIM(typ) // "." // TRIM(mmb)
  ELSE
    lenfn = LEN_TRIM(fdbdir) + 1 + LEN_TRIM(expver) + 1 + LEN_TRIM(typ)
    prefix = TRIM(fdbdir) // "/" // TRIM(expver) // "." // TRIM(typ)
  END IF

  IF (typ=="fc" .or. typ=="ens") THEN
     CALL f_conf%get_or_die ("date", str)
     referencedate = str
     CALL datetime_to_string (vdate, validitydate)
     CALL datetime_create (TRIM(referencedate), rdate)
     CALL datetime_diff (vdate, rdate, step)
     CALL duration_to_string (step, sstep)
     lenfn = lenfn + 1 + LEN_TRIM(referencedate) + 1 + LEN_TRIM(sstep)
     roms_genfilename = TRIM(prefix) // "." // TRIM(referencedate) // "." // TRIM(sstep)
  END IF

  IF (typ=="an" .or. typ=="incr") THEN
     CALL datetime_to_string (vdate, validitydate)
     lenfn = lenfn + 1 + LEN_TRIM(validitydate)
     roms_genfilename = TRIM(prefix) // "." // TRIM(validitydate)
  END IF

  IF (lenfn > length) THEN
    CALL abor1_ftn ("fields:genfilename: filename too long")
  END IF

  IF ( allocated(str) ) DEALLOCATE (str)

END FUNCTION roms_genfilename

! ------------------------------------------------------------------------------

END MODULE roms_fieldsutils_mod
