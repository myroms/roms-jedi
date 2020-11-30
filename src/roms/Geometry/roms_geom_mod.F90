! (C) Copyright 2017-2020 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!

module roms_geom_mod

use kinds,                      only: kind_real
use fckit_configuration_module, only: fckit_configuration
use fckit_mpi_module,           only: fckit_mpi_comm

implicit none

private
public :: roms_geom

!> Geometry data structure

type :: roms_geom
    type(fckit_mpi_comm) :: f_comm

    contains
    procedure :: init => geom_init
    procedure :: end => geom_end
    procedure :: clone => geom_clone

end type roms_geom

! ------------------------------------------------------------------------------
contains
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
!> Setup geometry object

subroutine geom_init(self, f_conf, f_comm)
  class(roms_geom),          intent(out) :: self
  type(fckit_configuration), intent(in)  :: f_conf
  type(fckit_mpi_comm),      intent(in)  :: f_comm

  ! MPI communicator
  self%f_comm = f_comm

end subroutine geom_init

! ------------------------------------------------------------------------------
!> Geometry destructor

subroutine geom_end(self)
  class(roms_geom), intent(out)  :: self

end subroutine geom_end

! ------------------------------------------------------------------------------
!> Clone, self = other

subroutine geom_clone(self, other)
  class(roms_geom), intent( in) :: self
  class(roms_geom), intent(out) :: other

  ! Clone communicator
  other%f_comm = self%f_comm

end subroutine geom_clone

! ------------------------------------------------------------------------------

end module roms_geom_mod
