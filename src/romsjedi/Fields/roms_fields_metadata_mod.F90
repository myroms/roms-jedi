! (C) Copyright 2021-2021 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
!>
!! \brief   Field/Fields metadata class for ROMS
!!
!! \details This class handle the user configurable metadata need to process
!!          each field in the state, increment, and other derived vectors.
!!          The metadata is read from input YAML configuration files.
!!
!! \author  Hernan G. Arango (Rutgers University)
!! \date    June 2021

MODULE roms_fields_metadata_mod

USE fckit_configuration_module, ONLY : fckit_configuration,                  &
                                       fckit_yamlconfiguration
USE fckit_pathname_module,      ONLY : fckit_pathname

implicit none

PRIVATE

PUBLIC  :: roms_field_metadata
PUBLIC  :: roms_fields_metadata

! ------------------------------------------------------------------------------
!> Structure holds user configurable metadata associated with a single field
! ------------------------------------------------------------------------------

TYPE :: roms_field_metadata

  logical                        :: masked              !< if interpolating, apply land mask?

  character (len=1)              :: gtype               !< C-grid type: 'r', 'u' or 'v'
  character (len=:), allocatable :: levels              !< "surface", or "full_ocn"
  character (len=:), allocatable :: name                !< ROMS internal field name
  character (len=:), allocatable :: getval_name         !< UFO variable name
  character (len=:), allocatable :: getval_name_surface !< If 3D, UFO surface name
  character (len=:), allocatable :: io_file             !< component file domain: 'ocn'
  character (len=:), allocatable :: io_name             !< I/O NetCDF file variable name
  character (len=:), allocatable :: property            !< physical property: "none" or "positive_definite"

END TYPE roms_field_metadata

! ------------------------------------------------------------------------------
!> Structure holds user configurable metadata associated for all fields
!  (state, increment, derived)
! ------------------------------------------------------------------------------

TYPE :: roms_fields_metadata

! PRIVATE

  TYPE (roms_field_metadata), allocatable :: metadata(:)

  CONTAINS

  PROCEDURE :: create => roms_fields_metadata_create
  PROCEDURE :: clone  => roms_fields_metadata_clone
  PROCEDURE :: get    => roms_fields_metadata_get

END TYPE roms_fields_metadata

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

SUBROUTINE roms_fields_metadata_create (self, filename)

  CLASS (roms_fields_metadata), intent(inout) :: self
  character (len=:), allocatable              :: filename

  TYPE (fckit_configuration)                  :: conf
  TYPE (fckit_Configuration), allocatable     :: conf_list(:)

  logical                                     :: bool
  integer                                     :: i, j, lstr
  character (len=:), allocatable              :: str

  ! Parse all the metadata from a YAML configuration file.

  conf = fckit_yamlconfiguration(fckit_pathname(filename))
  CALL conf%get_or_die ("", conf_list)

  allocate ( self%metadata(size(conf_list)))

  DO i=1, SIZE(self%metadata)

    CALL conf_list(i)%get_or_die ("name", self%metadata(i)%name)

    IF (.not.conf_list(i)%get("gtype", str)) THEN
      self%metadata(i)%gtype = 'r'
    ELSE
      self%metadata(i)%gtype = str
      deallocate (str)
    END IF

    IF (.not.conf_list(i)%get("masked", bool)) THEN
      self%metadata(i)%masked = .TRUE.
    ELSE
      self%metadata(i)%masked = bool
    END IF

    IF (.not.conf_list(i)%get("levels", str)) THEN
      allocate ( character(LEN=7) :: self%metadata(i)%levels )
      self%metadata(i)%levels = "surface"
    ELSE
      lstr = LEN_TRIM(str)
      allocate ( character(LEN=lstr) :: self%metadata(i)%levels )
      self%metadata(i)%levels = str
      deallocate (str)
    END IF

    IF (.not.conf_list(i)%get("getval name", str)) THEN
      lstr = LEN_TRIM(self%metadata(i)%name)
      allocate ( character(LEN=lstr) :: self%metadata(i)%getval_name )
      self%metadata(i)%getval_name = self%metadata(i)%name
    ELSE 
      lstr = LEN_TRIM(str)
      allocate ( character(LEN=lstr) :: self%metadata(i)%getval_name )
      self%metadata(i)%getval_name = str
      deallocate (str)
    END IF

    IF (.not.conf_list(i)%get("getval name surface", str)) THEN
      self%metadata(i)%getval_name_surface = ""
    ELSE
      lstr = LEN_TRIM(str)
      allocate ( character(LEN=lstr) :: self%metadata(i)%getval_name_surface )
      self%metadata(i)%getval_name_surface = str
      deallocate (str)
    END IF

    IF (.not.conf_list(i)%get("io name", str)) THEN
      self%metadata(i)%io_name = ""
    ELSE
      lstr = LEN_TRIM(str)
      allocate ( character(LEN=lstr) :: self%metadata(i)%io_name )
      self%metadata(i)%io_name = str
      deallocate (str)
    END IF

    IF (.not.conf_list(i)%get("io file", str)) THEN
      self%metadata(i)%io_file = ""
    ELSE
      lstr = LEN_TRIM(str)
      allocate ( character(LEN=lstr) :: self%metadata(i)%io_file )
      self%metadata(i)%io_file = str
      deallocate (str)
    END IF

    IF (.not.conf_list(i)%get("property", str)) THEN
      allocate ( character(LEN=4) :: self%metadata(i)%property )
      self%metadata(i)%property = "none"
    ELSE
      lstr = LEN_TRIM(str)
      allocate ( character(LEN=lstr) :: self%metadata(i)%property )
      self%metadata(i)%property = str
      deallocate (str)
    END IF

  END DO

  ! Check for duplicates entries.

  DO i = 1, SIZE(self%metadata)
    DO j = i+1, SIZE(self%metadata)
      IF ((self%metadata(i)%name .eq.                                        &
           self%metadata(j)%name) .or.                                       &
          (self%metadata(i)%name .eq.                                        &
           self%metadata(j)%getval_name) .or.                                &
          (self%metadata(i)%name .eq.                                        &
           self%metadata(j)%getval_name_surface) .or.                        &
          (self%metadata(i)%getval_name .eq.                                 &
           self%metadata(j)%name) .or.                                       &
          (self%metadata(i)%getval_name .eq.                                 &
           self%metadata(j)%getval_name) .or.                                &
          (self%metadata(i)%getval_name .eq.                                 &
           self%metadata(j)%getval_name_surface) .or.                        &
          ((self%metadata(i)%getval_name_surface .ne. "") .and.              &
           (self%metadata(i)%getval_name_surface .eq.                        &
            self%metadata(j)%name) .or.                                      &
           (self%metadata(i)%getval_name_surface .eq.                        &
            self%metadata(j)%getval_name))) THEN
        str = REPEAT(" ",1024)
        WRITE (str,*) "Duplicate field metadata: ",                          &
                      i, self%metadata(i)%name,                              &
                      j, self%metadata(j)%name
        CALL abor1_ftn (TRIM(str))
      END IF
    END DO
  END DO

END SUBROUTINE roms_fields_metadata_create

! ------------------------------------------------------------------------------
!> Clone Fields metadata object.

SUBROUTINE roms_fields_metadata_clone (self, other)

  CLASS (roms_fields_metadata), intent(in ) :: self
  CLASS (roms_fields_metadata), intent(out) :: other

  other%metadata = self%metadata

END SUBROUTINE roms_fields_metadata_clone

! ------------------------------------------------------------------------------
!> Get Field metadata object from any of its configured names.

FUNCTION roms_fields_metadata_get(self, name) RESULT (metadata)

  CLASS (roms_fields_metadata), intent(in) :: self
  character (len=:), allocatable           :: name

  integer                                  :: i
  TYPE (roms_field_metadata)               :: metadata

  ! Find the field by any of its internal or GetVaLs names.

  DO i = 1, SIZE(self%metadata)
    IF ((TRIM(self%metadata(i)%name) .eq. TRIM(name)) .or.                   &
        (TRIM(self%metadata(i)%getval_name) .eq. TRIM(name)) .or.            &
        (TRIM(self%metadata(i)%getval_name_surface) .eq. TRIM(name))) THEN
      metadata = self%metadata(i)
      RETURN
    END IF
  END DO

  CALL abor1_ftn ("Unable to find field metadata for: " // TRIM(name))

END FUNCTION roms_fields_metadata_get

! ------------------------------------------------------------------------------

END MODULE
