! (C) Copyright 2017-2025 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
! ------------------------------------------------------------------------------
!
!>
!! \brief    **GeometryIterator Class** ROMS-JEDI interface Registry
!!
!! \author   Hernan G. Arango (Rutgers University)
!! \date     October 2021

MODULE roms_geomIterator_reg

USE roms_geomIterator_mod

implicit none

PRIVATE

!> Linked list interface - defines registry_t type

#define LISTED_TYPE roms_geomIterator
#include "oops/util/linkedList_i.f"

!> Global registry

TYPE (registry_t), PUBLIC :: roms_geomIterator_registry

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

!> Linked list implementation

#include "oops/util/linkedList_c.f"

END MODULE roms_geomIterator_reg
