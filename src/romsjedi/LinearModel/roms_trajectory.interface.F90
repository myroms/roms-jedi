! (C) Copyright 2017-2025 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

MODULE roms_trajectory_mod_c

USE iso_c_binding

USE datetime_mod

USE roms_geom_reg,        ONLY : roms_geom_registry
use roms_state_mod,       ONLY : roms_state
USE roms_state_reg,       ONLY : roms_state_registry
USE roms_trajectory_mod,  ONLY : roms_trajectory
USE roms_trajectory_reg,  ONLY : roms_trajectory_registry

implicit none

PRIVATE

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

SUBROUTINE roms_trajectory_set_c (c_key_self, c_key_state, c_dt)               &
                            BIND (c, name='roms_trajectory_set_f90')

  integer (c_int),  intent(inout) :: c_key_self   !< Trajectory object pointer
  integer (c_int),  intent(in   ) :: c_key_state  !< State object pointer
  TYPE (c_ptr),     intent(in   ) :: c_dt         !< Trajectory dateTime pointer

  TYPE (roms_state),      pointer :: state
  TYPE (roms_trajectory), pointer :: self
  TYPE (datetime)                 :: fdate

  CALL roms_state_registry%get (c_key_state, state)
  CALL roms_trajectory_registry%init ()
  CALL roms_trajectory_registry%add (c_key_self)
  CALL roms_trajectory_registry%get (c_key_self, self)
  CALL c_f_datetime (c_dt, fdate)

  CALL self%set (state, fdate)

END SUBROUTINE roms_trajectory_set_c

! ------------------------------------------------------------------------------

SUBROUTINE roms_trajectory_destroy_c (c_key_self)                            &
                                BIND (c, name='roms_trajectory_destroy_f90')

  integer (c_int),  intent(inout) :: c_key_self   !< trajectory object pointer

  TYPE (roms_trajectory), pointer :: self

  CALL roms_trajectory_registry%get (c_key_self, self)
  CALL self%destroy ()
  CALL roms_trajectory_registry%remove (c_key_self)

END SUBROUTINE roms_trajectory_destroy_c

! ------------------------------------------------------------------------------

END MODULE roms_trajectory_mod_c
