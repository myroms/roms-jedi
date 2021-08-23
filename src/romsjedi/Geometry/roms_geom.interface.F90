
! (C) Copyright 2017-2021 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
!>
!! \brief    Fortran and C++ binding interface for ROMS-JEDI Geometry class
!!
!! \details  Interoperability mechanism for the Geometry class that allows
!!           Fortran to invoke C++ functions and vice versa C++ to invoke
!!           Fortran procedures.
!!
!! \author   Hernan G. Arango (Rutgers University)
!! \date     April 2021

MODULE roms_geom_mod_c

USE iso_c_binding

USE atlas_module,               ONLY : atlas_fieldset,                       &
                                       atlas_functionspace_pointcloud
USE fckit_configuration_module, ONLY : fckit_configuration
USE fckit_mpi_module,           ONLY : fckit_mpi_comm
use oops_variables_mod

use roms_fields_metadata_mod
USE roms_geom_mod,              ONLY : roms_geom

implicit none

PRIVATE

PUBLIC :: roms_geom_registry

#define LISTED_TYPE roms_geom

!> Linked list interface - defines registry_t type

#include "oops/util/linkedList_i.f"

!> Global registry

TYPE (registry_t) :: roms_geom_registry

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

!> Linked list implementation

#include "oops/util/linkedList_c.f"

! ------------------------------------------------------------------------------
!> Setup geometry object

SUBROUTINE c_roms_geom_setup (c_key_self, c_conf, c_comm)                    &
                       BIND (c, name='roms_geom_setup_f90')

  integer (c_int),     intent(inout) :: c_key_self
  TYPE (c_ptr),        intent(in   ) :: c_conf
  TYPE (c_ptr), value, intent(in   ) :: c_comm

  TYPE (roms_geom), pointer          :: self

  CALL roms_geom_registry%init ()
  CALL roms_geom_registry%add (c_key_self)
  CALL roms_geom_registry%get (c_key_self, self)

  CALL self%init (fckit_configuration(c_conf), fckit_mpi_comm(c_comm))

END SUBROUTINE c_roms_geom_setup

! ------------------------------------------------------------------------------
!> Clone geometry object

SUBROUTINE c_roms_geom_clone (c_key_self, c_key_other)                       &
                        BIND (c, name='roms_geom_clone_f90')

  integer (c_int), intent(inout) :: c_key_self
  integer (c_int), intent(in   ) :: c_key_other

  TYPE (roms_geom), pointer      :: self, other

  CALL roms_geom_registry%add (c_key_self)
  CALL roms_geom_registry%get (c_key_self, self)
  CALL roms_geom_registry%get (c_key_other, other )

  CALL self%clone (other)

END SUBROUTINE c_roms_geom_clone

! ------------------------------------------------------------------------------
!> Geometry destructor

SUBROUTINE c_roms_geom_delete (c_key_self)                                   &
                         BIND (c, name='roms_geom_delete_f90')

  integer(c_int), intent(inout) :: c_key_self

  TYPE (roms_geom),     pointer :: self

  CALL roms_geom_registry%get (c_key_self, self)
  CALL self%end ()
  CALL roms_geom_registry%remove (c_key_self)

END SUBROUTINE c_roms_geom_delete

! ------------------------------------------------------------------------------
!> Get begin and end of local tile geometry

SUBROUTINE c_roms_geom_start_end (c_key_self, Istr, Iend, Jstr, Jend)        &
                            BIND (c, name='roms_geom_start_end_f90')

  integer (c_int), intent(in ) :: c_key_self
  integer (c_int), intent(out) :: Istr, Iend, Jstr, Jend

  TYPE (roms_geom), pointer    :: self

  CALL roms_geom_registry%get (c_key_self, self)

  Istr = self%Istr
  Iend = self%Iend
  Jstr = self%Jstr
  Jend = self%Jend

END SUBROUTINE c_roms_geom_start_end

! ------------------------------------------------------------------------------
!> Get geometry information

SUBROUTINE c_roms_geom_info (c_key_self, nx, ny, nz, tile,                   &
                             LBi, UBi, LBj, UBj,                             &
                             Istr, Iend, Jstr, Jend)                         &
                      BIND (c, name='roms_geom_info_f90')

  integer (c_int), intent(in ) :: c_key_self
  integer (c_int), intent(out) :: nx, ny, nz, tile
  integer (c_int), intent(out) :: LBi, UBi, LBj, UBj, Istr, Iend, Jstr, Jend

  TYPE (roms_geom), pointer    :: self

  CALL roms_geom_registry%get (c_key_self, self)

  ! Load grid geometry information

  nx = self%Lm
  ny = self%Mm
  nz = self%N

  tile = self%tile

  LBi = self%LBi
  UBi = self%UBi
  LBj = self%LBj
  UBj = self%UBj

  Istr = self%Istr
  Iend = self%Iend
  Jstr = self%Jstr
  Jend = self%Jend

END SUBROUTINE c_roms_geom_info

! ------------------------------------------------------------------------------

SUBROUTINE c_roms_geom_get_num_levels (c_key_self, c_vars,                   &
                                       c_levels_size, c_levels)              &
                                BIND (c, name='roms_geom_get_num_levels_f90')

  integer (c_int),     intent(in ) :: c_key_self
  TYPE (c_ptr), value, intent(in ) :: c_vars
  integer (c_size_t),  intent(in ) :: c_levels_size
  integer (c_size_t),  intent(out) :: c_levels(c_levels_size)

  TYPE (roms_field_metadata)       :: field
  TYPE (roms_geom), pointer        :: self
  TYPE (oops_variables)            :: vars
  integer                          :: i
  character(len=:), allocatable    :: field_name

  CALL roms_geom_registry%get (c_key_self, self)
  vars = oops_variables(c_vars)

  DO i = 1,vars%nvars()

    field_name = vars%variable(i)
    field = self%fields_metadata%get(field_name)

    SELECT CASE(field%levels)
      CASE ('1', 'surface')
        c_levels(i) = 1
      CASE ('full_ocn')
        IF (field_name .eq. field%getval_name_surface) THEN
          c_levels(i) = 1
        ELSE
          c_levels(i) = self%N
        END IF
      CASE DEFAULT
        CALL abor1_ftn ('c_roms_geo_get_num_levels: Unknown "levels" ' //    &
                        field%levels)
    END SELECT

  END DO

END SUBROUTINE c_roms_geom_get_num_levels

! ------------------------------------------------------------------------------
!> Set ATLAS functionspace pointer

SUBROUTINE c_roms_geom_set_atlas_functionspace_pointer (c_key_self,          &
                                                        c_afunctionspace)    &
           BIND (c, name='roms_geom_set_atlas_functionspace_pointer_f90')

  integer (c_int),     intent(in) :: c_key_self        !< Key to Geometry object
  TYPE (c_ptr), value, intent(in) :: c_afunctionspace  !< Key to ATLAS function

  TYPE (roms_geom), pointer       :: self

  CALL roms_geom_registry%get (c_key_self, self)

  self%afunctionspace = atlas_functionspace_pointcloud(c_afunctionspace)

END SUBROUTINE c_roms_geom_set_atlas_functionspace_pointer

! ------------------------------------------------------------------------------
!> Set ATLAS **lonlat** fieldset.

SUBROUTINE c_roms_geom_set_atlas_lonlat (c_key_self, c_afieldset)            &
           BIND (c, name='roms_geom_set_atlas_lonlat_f90')

  integer (c_int),     intent(in) :: c_key_self        !< Key to Geometry object
  TYPE (c_ptr), value, intent(in) :: c_afieldset       !< Key to ATLAS fieldset

  TYPE (roms_geom), pointer       :: self
  TYPE (atlas_fieldset)           :: afieldset

  CALL roms_geom_registry%get (c_key_self, self)
  afieldset = atlas_fieldset(c_afieldset)

  CALL self%set_atlas_lonlat (afieldset)

END SUBROUTINE c_roms_geom_set_atlas_lonlat

! ------------------------------------------------------------------------------
!> Fill ATLAS fieldset with cell area, vertical level units, am geographical
!! mask.

SUBROUTINE c_roms_geom_fill_atlas_fieldset (c_key_self, c_afieldset)         &
           BIND (c, name='roms_geom_fill_atlas_fieldset_f90')

  integer (c_int),    intent(in) :: c_key_self      !< Key to Geometry object
  type(c_ptr), value, intent(in) :: c_afieldset     !< Key to ATLAS fieldset

  TYPE (roms_geom), pointer      :: self
  TYPE (atlas_fieldset)          :: afieldset

  CALL roms_geom_registry%get (c_key_self, self)
  afieldset = atlas_fieldset(c_afieldset)

  CALL self%fill_atlas_fieldset (afieldset)

END SUBROUTINE c_roms_geom_fill_atlas_fieldset

! ------------------------------------------------------------------------------

END MODULE roms_geom_mod_c
