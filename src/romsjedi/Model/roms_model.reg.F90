! (C) Copyright 2020-2025 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
! ------------------------------------------------------------------------------
!
!>
!! \brief   ROMS nonlinear Model class registry
!!
!! \author  Hernan G. Arango (Rutgers University)
!! \date    September 2021

MODULE roms_model_reg

USE roms_model_mod

implicit none

PRIVATE

!> Linked list interface - defines registry_t type

#define LISTED_TYPE roms_model
#include "oops/util/linkedList_i.f"

!> Global registry

TYPE (registry_t), public :: roms_model_registry

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

!> Linked list implementation

#include "oops/util/linkedList_c.f"

END MODULE roms_model_reg
