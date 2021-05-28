! (C) Copyright 2020-2020 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
! Hernan G. Arango, Rutgers University, Apr 2021

! ------------------------------------------------------------------------------

MODULE roms_increment_reg

USE roms_increment_mod

implicit none

PRIVATE

PUBLIC  :: roms_increment_registry

#define LISTED_TYPE roms_increment

!> Linked list interface - defines registry_t type

#include "oops/util/linkedList_i.f"

!> Global registry

TYPE (registry_t) :: roms_increment_registry

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

!> Linked list implementation

#include "oops/util/linkedList_c.f"

END MODULE roms_increment_reg
