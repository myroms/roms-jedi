! (C) Copyright 2017-2022 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!
!>
!! \brief   Field/Fields metadata class for ROMS
!!
!! \details This class handle the user configurable metadata need to process
!!          each field in the state, increment, and other derived vectors.
!!          The metadata is read from input YAML configuration files.
!!
!! \author  Hernan G. Arango (Rutgers University)
!! \date    June 2021


MODULE roms_trajectory_mod

USE kinds,                ONLY : kind_real
USE datetime_mod,         ONLY : datetime
USE fckit_mpi_module,     ONLY : fckit_mpi_comm

USE roms_field_mod,       ONLY : roms_field
USE roms_fields_mod,      ONLY : roms_fields
USE roms_fieldsutils_mod, ONLY : date2string
USE roms_state_mod,       ONLY : roms_state

implicit none

!> Fortran derived type object to hold linearize model trajectory

TYPE, PUBLIC, EXTENDS(roms_fields) :: roms_trajectory

  logical :: doSnapshots            !< ROMS NLM trajectory saved by snapshots

  integer :: snapshotIndex          !< snapshot rolling time index (1 or 2)

  real (kind=kind_real) :: romsTime !< ROMS time (seconds since referece date)

  character (len=22) :: DateTimeStr !< trajectory date and time string

  CONTAINS

  ! Field constructors and destructors.

  PROCEDURE :: construct  => roms_trajectory_construct
  PROCEDURE :: destroy    => roms_trajectory_destroy
  PROCEDURE :: duplicate  => roms_trajectory_duplicate
  PROCEDURE :: set        => roms_trajectory_set

END TYPE roms_trajectory

PRIVATE

! Switch for printing fields information during debugging.

logical :: LdebugTrajectory = .FALSE.

! MPI communicator.

TYPE (fckit_mpi_comm) :: my_comm

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
!> Allocates and zero initialize trajectory object containing mandatory State
!! fields and additonal fields needed to linearize the tangent linear and
!! adjoint models.

SUBROUTINE roms_trajectory_construct (self, state)

  CLASS (roms_trajectory), intent(inout) :: self      !< Trajectory object
  CLASS (roms_state),      intent(in   ) :: state     !< State object

  integer                                :: LBi, UBi, LBj, UBj, LBk, UBk
  integer                                :: Nvars, i

  ! Make sure current object has not already been allocated.

  IF (allocated(self%fields)) THEN
    CALL abor1_ftn ("roms_fields::create(): object already allocated")
  END IF

  ! Associate geometry.

  self%geom => state%geom

  LBi = state%geom%LBi
  UBi = state%geom%UBi
  LBj = state%geom%LBj
  UBj = state%geom%UBj

  ! Currently, the ROMS NLM trajectory is saved at every timestep. Need to
  ! figure out how to set-up the data time snapshot policy with intervals
  ! greater than a timestep. The trajectory fields will be time interpolated
  ! between data snapshots.

  self%doSnapshots = .FALSE.

  ! Allocate fields structure. It must include fields that are part of the
  ! state increment and additional fields needed for the linearization of
  ! the tangent linear and adjoint kernels.

  Nvars = SIZE(state%fields)
  
  allocate ( self%fields(Nvars) )
  
  ! Assign properties from the State object and allocate trajectory fields.

  DO i = 1, Nvars

    self%fields(i)%name     =  state%fields(i)%name
    self%fields(i)%metadata =  state%geom%fieldsinfo%get(self%fields(i)%name)
    self%fields(i)%bounds   =  state%fields(i)%bounds
    self%fields(i)%N        =  state%fields(i)%N
    self%fields(i)%angle    => state%fields(i)%angle
    self%fields(i)%lon      => state%fields(i)%lon
    self%fields(i)%lat      => state%fields(i)%lat
    self%fields(i)%mask     => state%fields(i)%mask

    ! Determine number of vertical levels.

    SELECT CASE (self%fields(i)%metadata%levels)
      CASE ('full_ocn')                             ! 3D field, full r-column
        LBk = 1
        UBk = state%geom%N
      CASE ('wfull_ocn')                            ! 3D field, full w-column
        LBk = 0
        UBk = state%geom%N
      CASE ('1', 'surface')                         ! 2D field                         
        LBk = 1
        UBk = 1
      CASE DEFAULT
        CALL abor1_ftn ('roms_trajectory::construct: Illegal levels ' //     &
                        self%fields(i)%metadata%levels //                    &
                        ' given for ' // self%fields(i)%name)
    END SELECT

    allocate ( self%fields(i)%val(LBi:UBi, LBj:UBj, LBk:UBk) )

    self%fields(i)%val = 0.0_kind_real

  END DO

END SUBROUTINE roms_trajectory_construct

! ------------------------------------------------------------------------------
!> It deallocates trajectory field array.

SUBROUTINE roms_trajectory_destroy (self)

 CLASS (roms_trajectory), intent(inout) :: self       !< Trajectory object

 integer                                :: i

 DO i = 1, SIZE(self%fields)
   IF (allocated(self%fields(i)%val)) deallocate (self%fields(i)%val)
 END DO

END SUBROUTINE roms_trajectory_destroy

! ------------------------------------------------------------------------------
!> It copies trajectory fields from RHS to self object. The SELF trajectory
!! must be allocate first elsewhere.

SUBROUTINE roms_trajectory_duplicate (self, rhs)

 CLASS (roms_trajectory), intent(inout) :: self       !< LHF Trajectory object
 CLASS (roms_trajectory), intent(in   ) :: rhs        !< RHS Trajectory object

 integer                                :: i

 ! Congruent trajectories, copy RHS field values into SELF.

 IF (SIZE(self%fields) .eq. SIZE(rhs%fields)) THEN
   DO i = 1, SIZE(self%fields)
     IF ((self%fields(i)%name .eq.                                           &
          rhs %fields(i)%name) .and.                                         &
         (self%fields(i)%N .eq.                                              &
          rhs %fields(i)%N) .and.                                            &
         (SIZE(SHAPE(self%fields(i)%val)) .eq.                               &
          SIZE(SHAPE(rhs %fields(i)%val))) .and.                             &
         (SIZE(self%fields(i)%val) .eq.                                      &
          SIZE(rhs %fields(i)%val))) THEN
        self%fields(i)%val = rhs%fields(i)%val
     END IF
   END DO
 END IF

END SUBROUTINE roms_trajectory_duplicate

! ------------------------------------------------------------------------------
!> Copies state fields into trajectory object.

SUBROUTINE roms_trajectory_set (self, state, vdate)

  USE mod_scalars,   ONLY : jic, INItime, time4jedi
  USE mod_stepping,  ONLY : nnew

  CLASS (roms_trajectory), intent(inout) :: self    !< Trajectory object
  CLASS (roms_state),      intent(in   ) :: state   !< State object
  TYPE (datetime),         intent(in   ) :: vdate   !< Trajectory valid datetime

  TYPE (roms_field), pointer             :: field
  integer                                :: i, ng
  real (kind=kind_real)                  :: fstats(3)

  ! Initialize.

  ng = state%geom%ng

  ! Allocate and zero intialize trajectory arrays.

  CALL self%construct (state)

  ! Set trajetory date/time.

  self%romsTime = MAX(INItime(ng), time4jedi(ng))     ! cannot be less than IC

  CALL date2string (vdate, self%DateTimeStr, ISO=.FALSE.)

  ! Copy trajectory fields from state object.

  IF (LdebugTrajectory .and. (my_comm%rank() .eq. 0))                          &
    PRINT 10, 'ROMS_DEBUG roms_trajectory::set: Processing fields',            &
              MAX(0,jic(ng)-1), nnew(ng), TRIM(self%DateTimeStr),              &
              self%romsTime/86400.0_kind_real

  DO i = 1, SIZE(self%fields)
    IF (state%has(self%fields(i)%name)) THEN
      CALL state%get (self%fields(i)%name, field)
      self%fields(i)%val = field%val

      CALL field%stats (fstats)
      self%fields(i)%MinValue = fstats(1)
      self%fields(i)%MaxValue = fstats(2)
      self%fields(i)%Checksum = fstats(3)
      IF (LdebugTrajectory .and. (my_comm%rank() .eq. 0))                      &
        PRINT 20, self%fields(i)%metadata%getval_name,                         &
                  self%fields(i)%metadata%io_name,                             &
                  fstats(1), fstats(2), INT(fstats(3),KIND=8)
    END IF
  END DO

  10 FORMAT (2x,a,', timestep = ',i5.5,',timelevel = ',i0,', date: ',a,        &
             ', romsTime = ',f0.8)
  20 FORMAT (19x,'- ',a,': ',a,/,22x,'(Min = ',1p,e15.8,' Max = ',1p,e15.8,    &
             ')',t93,'Checksum = ',i0)

END SUBROUTINE roms_trajectory_set

! ------------------------------------------------------------------------------

END MODULE roms_trajectory_mod
