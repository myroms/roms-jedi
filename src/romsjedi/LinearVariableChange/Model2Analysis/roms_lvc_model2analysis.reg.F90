! (C) Copyright 2020-2025 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
!>
!! \brief    **Model2Analysis Linear Variable Change Class** Registry 
!!
!! \author   Hernan G. Arango (Rutgers University)
!! \date     November 2024

! ------------------------------------------------------------------------------

MODULE roms_lvc_model2analysis_reg

USE roms_lvc_model2analysis_mod

implicit none

PRIVATE

!> Linked list interface - defines registry_t type

#define LISTED_TYPE roms_lvc_model2analysis
#include "oops/util/linkedList_i.f"

!> Global registry

TYPE (registry_t), PUBLIC :: roms_lvc_model2analysis_registry

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

!> Linked list implementation

#include "oops/util/linkedList_c.f"

END MODULE roms_lvc_model2analysis_reg
