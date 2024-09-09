! (C) Copyright 2017-2024 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

MODULE roms_linearModel_mod_c

USE iso_c_binding

USE datetime_mod
USE duration_mod
USE fckit_configuration_module, ONLY : fckit_configuration
USE oops_variables_mod

USE roms_geom_mod,              ONLY : roms_geom
USE roms_geom_reg,              ONLY : roms_geom_registry
USE roms_increment_mod,         ONLY : roms_increment
USE roms_increment_reg,         ONLY : roms_increment_registry
USE roms_linearModel_mod,       ONLY : roms_linearModel
USE roms_linearModel_reg,       ONLY : roms_linearModel_registry
USE roms_trajectory_mod,        ONLY : roms_trajectory
USE roms_trajectory_reg,        ONLY : roms_trajectory_registry

implicit none

PRIVATE

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
!> Binding interface to create ROMS LinearModel object.

SUBROUTINE roms_linearModel_create_c (c_key_self, c_key_geom, c_conf)          &
                                BIND (c, name='roms_linearModel_create_f90')

  integer (c_int),     intent(inout) :: c_key_self !< LinearModel object pointer
  integer (c_int),     intent(in   ) :: c_key_geom !< Geometry object pointer
  TYPE (c_ptr), value, intent(in   ) :: c_conf     !< Config object pointer

  TYPE (roms_linearModel), pointer   :: self
  TYPE (roms_geom),        pointer   :: geom

  CALL roms_geom_registry%get (c_key_geom, geom)
  CALL roms_linearModel_registry%init ()
  CALL roms_linearModel_registry%add (c_key_self)
  CALL roms_linearModel_registry%get (c_key_self, self)

  CALL self%create (geom, fckit_configuration(c_conf))

END SUBROUTINE roms_linearModel_create_c

! ------------------------------------------------------------------------------
!> Binding interface to delete ROMS LinearModel object.

SUBROUTINE roms_linearModel_delete_c (c_key_self)                              &
                                BIND (c, name='roms_linearModel_delete_f90')

  integer (c_int), intent(inout)   :: c_key_self  !< LinearModel object pointer

  TYPE (roms_linearModel), pointer :: self

  CALL roms_linearModel_registry%get (c_key_self, self)
  CALL self%delete ()
  CALL roms_linearModel_registry%remove (c_key_self)

END SUBROUTINE roms_linearModel_delete_c

! ------------------------------------------------------------------------------
!> Binding interface to initialize TLROMS object.

SUBROUTINE roms_linearModel_initialize_tl_c (c_key_self, c_key_incr,           &
                                             c_key_traj, c_dt)                 &
                           BIND (c, name='roms_linearModel_initialize_tl_f90')

  integer (c_int),      intent(in) :: c_key_self  !< LinearModel object pointer
  integer (c_int),      intent(in) :: c_key_incr  !< Increment object pointer
  integer (c_int),      intent(in) :: c_key_traj  !< Trajectory object pointer
  TYPE (c_ptr),         intent(in) :: c_dt        !< Increment dateTime pointer

  TYPE (roms_linearModel), pointer :: self
  TYPE (roms_increment),   pointer :: incr
  TYPE (roms_trajectory),  pointer :: traj
  TYPE (datetime)                  :: fdate

  CALL roms_increment_registry%get (c_key_incr, incr)
  CALL roms_linearModel_registry%get (c_key_self, self)
  CALL roms_trajectory_registry%get (c_key_traj, traj)
  CALL c_f_datetime (c_dt, fdate)

  CALL self%initialize_tl (incr, traj, fdate)

END SUBROUTINE roms_linearModel_initialize_tl_c

! ------------------------------------------------------------------------------
!> Binding interface to advance TLROMS kernel for specified time interval.

SUBROUTINE roms_linearModel_step_tl_c (c_key_self, c_key_incr,                 &
                                       c_key_traj, c_dt)                       &
                           BIND (c, name='roms_linearModel_step_tl_f90')

  integer (c_int),      intent(in) :: c_key_self  !< LinearModel object pointer
  integer (c_int),      intent(in) :: c_key_incr  !< Increment object pointer
  integer (c_int),      intent(in) :: c_key_traj  !< Trajectory object pointer
  TYPE (c_ptr),      intent(inout) :: c_dt        !< DateTime object pointer

  TYPE (roms_linearModel), pointer :: self
  TYPE (roms_increment),   pointer :: incr
  TYPE (roms_trajectory),  pointer :: traj
  TYPE (datetime)                  :: fdate

  CALL roms_linearModel_registry%get (c_key_self, self)
  CALL roms_increment_registry%get (c_key_incr, incr)
  CALL roms_trajectory_registry%get (c_key_traj, traj)
  CALL c_f_datetime (c_dt, fdate)

  CALL self%step_tl (incr, traj, fdate)

END SUBROUTINE roms_linearModel_step_tl_c

! ------------------------------------------------------------------------------
!> Binding interface to finalize TLROMS kernel integration.

SUBROUTINE roms_linearModel_finalize_tl_c (c_key_self, c_key_incr)             &
                           BIND (c, name='roms_linearModel_finalize_tl_f90')

  integer (c_int),      intent(in) :: c_key_self  !< LinearModel object pointer
  integer (c_int),      intent(in) :: c_key_incr  !< Increment object pointer


  TYPE (roms_linearModel), pointer :: self
  TYPE (roms_increment),   pointer :: incr

  CALL roms_increment_registry%get (c_key_incr, incr)
  CALL roms_linearModel_registry%get (c_key_self, self)

  CALL self%finalize_tl (incr)

END SUBROUTINE roms_linearModel_finalize_tl_c

! ------------------------------------------------------------------------------
!> Binding interface to initialize ADROMS object.

SUBROUTINE roms_linearModel_initialize_ad_c (c_key_self, c_key_incr,           &
                                             c_key_traj, c_dt)                 &
                           BIND (c, name='roms_linearModel_initialize_ad_f90')

  integer (c_int),      intent(in) :: c_key_self  !< LinearModel object pointer
  integer (c_int),      intent(in) :: c_key_incr  !< Increment object pointer
  integer (c_int),      intent(in) :: c_key_traj  !< Trajectory object pointer
  TYPE (c_ptr),         intent(in) :: c_dt        !< Increment dateTime pointer

  TYPE (roms_linearModel), pointer :: self
  TYPE (roms_increment),   pointer :: incr
  TYPE (roms_trajectory),  pointer :: traj
  TYPE (datetime)                  :: fdate

  CALL roms_increment_registry%get (c_key_incr, incr)
  CALL roms_linearModel_registry%get (c_key_self, self)
  CALL roms_trajectory_registry%get (c_key_traj, traj)
  CALL c_f_datetime (c_dt, fdate)

  CALL self%initialize_ad (incr, traj, fdate)

END SUBROUTINE roms_linearModel_initialize_ad_c

! ------------------------------------------------------------------------------
!> Binding interface to timestep backwards ADROMS for specified time interval.

SUBROUTINE roms_linearModel_step_ad_c (c_key_self, c_key_incr,                 &
                                       c_key_traj, c_dt)                       &
                           BIND (c, name='roms_linearModel_step_ad_f90')

  integer (c_int),   intent(in   ) :: c_key_self  !< LinearModel object pointer
  integer (c_int),   intent(in   ) :: c_key_incr  !< Increment object pointer
  integer (c_int),   intent(in   ) :: c_key_traj  !< Trajectory object pointer
  TYPE (c_ptr),      intent(inout) :: c_dt        !< Increment dateTime pointer

  TYPE (roms_linearModel), pointer :: self
  TYPE (roms_increment),   pointer :: incr
  TYPE (roms_trajectory),  pointer :: traj
  TYPE (datetime)                  :: fdate

  CALL roms_linearModel_registry%get (c_key_self, self)
  CALL roms_increment_registry%get (c_key_incr, incr)
  CALL roms_trajectory_registry%get (c_key_traj, traj)
  CALL c_f_datetime (c_dt, fdate)

  CALL self%step_ad (incr, traj, fdate)

END SUBROUTINE roms_linearModel_step_ad_c

! ------------------------------------------------------------------------------
!> Binding interface to finalize ADROMS kernel integration.

SUBROUTINE roms_linearModel_finalize_ad_c (c_key_self, c_key_incr)             &
                           BIND (c, name='roms_linearModel_finalize_ad_f90')

  integer (c_int),      intent(in) :: c_key_self  !< LinearModel object pointer
  integer (c_int),      intent(in) :: c_key_incr  !< Increment object pointer

  TYPE (roms_linearModel), pointer :: self
  TYPE (roms_increment),   pointer :: incr

  CALL roms_increment_registry%get (c_key_incr, incr)
  CALL roms_linearModel_registry%get (c_key_self, self)

  CALL self%finalize_ad (incr)

END SUBROUTINE roms_linearModel_finalize_ad_c

! ------------------------------------------------------------------------------

END MODULE roms_linearModel_mod_c
