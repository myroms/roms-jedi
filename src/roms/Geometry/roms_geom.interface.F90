! (C) Copyright 2017-2020 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

module roms_geom_mod_c

use iso_c_binding
use fckit_configuration_module, only: fckit_configuration
use fckit_mpi_module,           only: fckit_mpi_comm
use roms_geom_mod,              only: roms_geom

implicit none

private
public :: roms_geom_registry

#define LISTED_TYPE roms_geom

!> Linked list interface - defines registry_t type

#include "oops/util/linkedList_i.f"

!> Global registry

type(registry_t) :: roms_geom_registry

! ------------------------------------------------------------------------------
contains
! ------------------------------------------------------------------------------

!> Linked list implementation

#include "oops/util/linkedList_c.f"

! ------------------------------------------------------------------------------
!> Setup geometry object

subroutine c_roms_geo_setup(c_key_self, c_conf, c_comm) bind(c,name='roms_geo_setup_f90')

  integer(c_int),  intent(inout) :: c_key_self
  type(c_ptr),        intent(in) :: c_conf
  type(c_ptr), value, intent(in) :: c_comm

  type(roms_geom), pointer :: self

  call roms_geom_registry%init()
  call roms_geom_registry%add(c_key_self)
  call roms_geom_registry%get(c_key_self,self)

  call self%init(fckit_configuration(c_conf), fckit_mpi_comm(c_comm) )

end subroutine c_roms_geo_setup

! ------------------------------------------------------------------------------
!> Clone geometry object

subroutine c_roms_geo_clone(c_key_self, c_key_other) bind(c,name='roms_geo_clone_f90')

  integer(c_int), intent(inout) :: c_key_self
  integer(c_int), intent(in)    :: c_key_other

  type(roms_geom), pointer :: self, other

  call roms_geom_registry%get(c_key_other, other)
  call roms_geom_registry%init()
  call roms_geom_registry%add(c_key_self)
  call roms_geom_registry%get(c_key_self , self )

  call self%clone(other)

end subroutine c_roms_geo_clone

! ------------------------------------------------------------------------------
!> Geometry destructor

subroutine c_roms_geo_delete(c_key_self) bind(c,name='roms_geo_delete_f90')

  integer(c_int), intent(inout) :: c_key_self

  type(roms_geom), pointer :: self

  call roms_geom_registry%get(c_key_self, self)
  call self%end()
  call roms_geom_registry%remove(c_key_self)

end subroutine c_roms_geo_delete

! ------------------------------------------------------------------------------

end module roms_geom_mod_c
