! (C) Copyright 2020-2021 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
!>
!! \author  Hernan G. Arango (Rutgers University)
!! \date    December 2021

MODULE roms_lineargetvalues_reg

USE roms_lineargetvalues_mod

implicit none

PRIVATE

!> Linked list interface - defines registry_t TYPE

#define LISTED_TYPE roms_lineargetvalues
#include "oops/util/linkedList_i.f"

!> Global registry

TYPE (registry_t), PUBLIC:: roms_lineargetvalues_registry

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

!> Linked list implementation

#include "oops/util/linkedList_c.f"

END MODULE roms_lineargetvalues_reg
