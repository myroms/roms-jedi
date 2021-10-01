! (C) Copyright 2017-2021 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
!>
!! \brief    Fortran and C++ binding interface for ROMS-JEDI Model class
!!
!! \details  Interoperability mechanism for the Model class that allows
!!           Fortran to invoke C++ functions and vice versa C++ to invoke
!!           Fortran procedures.
!!
!! \author   Hernan G. Arango (Rutgers University)
!! \date     September 2021

MODULE roms_model_mod_c

USE iso_c_binding
USE datetime_mod
USE duration_mod
USE fckit_configuration_module,  ONLY : fckit_configuration

USE roms_geom_mod_c,             ONLY : roms_geom_registry
USE roms_geom_mod,               ONLY : roms_geom
USE roms_model_mod,              ONLY : roms_model
USE roms_model_reg
USE roms_state_mod
USE roms_state_reg

implicit none

PRIVATE

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------
!> Binding interface to create ROMS NLM kernel object.

SUBROUTINE roms_model_create_c (c_conf, c_key_geom, c_key_self)              &
                          BIND (c, name='roms_model_create_f90')

  integer (c_int), intent(inout) :: c_key_self   !< Model object pointer
  integer (c_int), intent(in   ) :: c_key_geom   !< Geometry object pointer
  TYPE (c_ptr),    intent(in   ) :: c_conf       !< Config object pointer

  TYPE (roms_model), pointer     :: self
  TYPE (roms_geom),  pointer     :: geom
  TYPE (fckit_configuration)     :: f_conf

  CALL roms_geom_registry%get (c_key_geom, geom)
  CALL roms_model_registry%init ()
  CALL roms_model_registry%add (c_key_self)
  CALL roms_model_registry%get (c_key_self, self)

  f_conf = fckit_configuration(c_conf)

  CALL self%create (geom, f_conf)

END SUBROUTINE roms_model_create_c

! ------------------------------------------------------------------------------
!> Binding interface to delete ROMS NLM kernel object.

SUBROUTINE roms_model_delete_c (c_key_self)                                  &
                          BIND (c, name='roms_model_delete_f90')

  integer (c_int), intent(inout) :: c_key_self

  TYPE (roms_model), pointer     :: self

  CALL roms_model_registry%get (c_key_self, self)
  CALL self%delete ()
  CALL roms_model_registry%remove (c_key_self)

END SUBROUTINE roms_model_delete_c

! ------------------------------------------------------------------------------
!> Binding interface to initialize ROMS NLM kernel object.

SUBROUTINE roms_model_initialize_c (c_key_self, c_key_state)                 &
                              BIND (c, name='roms_model_initialize_f90')

  integer (c_int), intent(in) :: c_key_self      !< Model object pointer
  integer (c_int), intent(in) :: c_key_state     !< State object pointer

  TYPE (roms_model), pointer  :: self
  TYPE (roms_state), pointer  :: state

  CALL roms_state_registry%get (c_key_state, state)
  CALL roms_model_registry%get (c_key_self, self)

  CALL self%initialize (state)

END SUBROUTINE roms_model_initialize_c

! ------------------------------------------------------------------------------
!> Binding interface to advance ROMS NLM kernel for specified time interval.

SUBROUTINE roms_model_step_c (c_key_self, c_key_state, c_key_geom, c_dt)     &
                        BIND (c, name='roms_model_step_f90')

  integer (c_int), intent(in   ) :: c_key_self   !< Model object pointer
  integer (c_int), intent(in   ) :: c_key_state  !< State object pointer
  integer (c_int), intent(in   ) :: c_key_geom   !< Geometry object pointer
  TYPE (c_ptr),    intent(inout) :: c_dt         !< DateTime object pointer

  TYPE (roms_model), pointer     :: self
  TYPE (roms_state), pointer     :: state
  TYPE (roms_geom),  pointer     :: geom
  TYPE (datetime)                :: fdate

  CALL roms_model_registry%get (c_key_self, self)
  CALL roms_state_registry%get (c_key_state, state)
  CALL roms_geom_registry%get (c_key_geom, geom)
  CALL c_f_datetime (c_dt, fdate)

  CALL self%step (state, geom, fdate)

END SUBROUTINE roms_model_step_c

! ------------------------------------------------------------------------------
!> Bindinf interface to finalize ROMS NLM kernel integration.

SUBROUTINE roms_model_finalize_c (c_key_self, c_key_state)                   &
                            BIND (c, name='roms_model_finalize_f90')

  integer (c_int), intent(in) :: c_key_self      !< Model object pointer
  integer (c_int), intent(in) :: c_key_state     !< State object pointer

  TYPE (roms_model), pointer  :: self
  TYPE (roms_state), pointer  :: state

  CALL roms_state_registry%get (c_key_state, state)
  CALL roms_model_registry%get (c_key_self, self)

  CALL self%finalize (state)

END SUBROUTINE roms_model_finalize_c

! ------------------------------------------------------------------------------

END MODULE roms_model_mod_c

