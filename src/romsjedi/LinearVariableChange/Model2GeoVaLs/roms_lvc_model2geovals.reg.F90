! (C) Copyright 2020-2020 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
!>
!! \brief    **Model2GeoVals Variable Change Class** Registry 
!!
!! \author   Hernan G. Arango (Rutgers University)
!! \date     December 2021

! ------------------------------------------------------------------------------

MODULE roms_lvc_model2geovals_reg

USE roms_lvc_model2geovals_mod

implicit none

PRIVATE

!> Linked list interface - defines registry_t type

#define LISTED_TYPE roms_lvc_model2geovals
#include "oops/util/linkedList_i.f"

!> Global registry

TYPE (registry_t), PUBLIC :: roms_lvc_model2geovals_registry

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

!> Linked list implementation

#include "oops/util/linkedList_c.f"

END MODULE roms_lvc_model2geovals_reg
