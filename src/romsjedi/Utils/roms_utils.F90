! (C) Copyright 2017-2025 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!>
!! \brief    ROMS-JEDI Utility Module
!!
!! \details  This module includes several support routines:
!!
!!             1.  Vector components variable changes from A-grid to C-grid
!!             2.  Vector components variable changes from C-grid to A-grid
!!
!! \author   Hernan G. Arango (Rutgers University)
!! \date     November 2021

MODULE roms_utils_mod

USE kinds,                ONLY : kind_real

USE fckit_mpi_module,     ONLY : fckit_mpi_comm,                               &
                                 fckit_mpi_min,                                &
                                 fckit_mpi_max,                                &
                                 fckit_mpi_sum

!> ROMS modules association.!> ROMS-JEDI interface module association.

USE mod_param,            ONLY : p2dvar, r2dvar, u2dvar, v2dvar,               &
                                 DOMAIN
USE mp_exchange_mod,      ONLY : ad_mp_exchange3d,                             &
                                 mp_exchange3d

!> ROMS-JEDI interface module association.

USE roms_geom_mod,        ONLY : roms_geom
USE roms_fieldsutils_mod, ONLY : field_info,                                   &
                                 LdebugLinearModel

implicit none

PRIVATE

PUBLIC  :: set_string        !> Assigns allocatable strings

PUBLIC  :: vector_a_to_c     !> Components variable change from A-grid to C-grid
PUBLIC  :: vector_a_to_c_ad  !>                                 adjoint routine
PUBLIC  :: vector_c_to_a     !> Components variable change from C-grid to A-grid
PUBLIC  :: vector_c_to_a_ad  !>                                 adjoint routine

! ------------------------------------------------------------------------------
CONTAINS
! ------------------------------------------------------------------------------

! ------------------------------------------------------------------------------
!>  It assigns allocatable strings. It allocates/reallocates output string
!!  variable

FUNCTION set_string (inp_string, out_string) RESULT (ErrFlag)

  character (len=*),              intent(in   ) :: inp_string
  character (len=:), allocatable, intent(inout) :: out_string

  integer                                       :: lstr
  integer                                       :: ErrFlag

  ! Allocate output string to the size of input string.

  ErrFlag = -1

  lstr = LEN_TRIM(inp_string)

  IF (.not.allocated(out_string)) THEN
    allocate ( character(LEN=lstr) :: out_string, STAT=ErrFlag)
  ELSE
    deallocate (out_string)
    allocate ( character(LEN=lstr) :: out_string, STAT=ErrFlag)
  END IF

  ! Assign provided value.

  out_string = inp_string

END FUNCTION set_string

! ------------------------------------------------------------------------------
!>  It transforms A-grid vector components to C-grid.

SUBROUTINE vector_a_to_c (G, Ua, Va, Uc, Vc)

  TYPE (roms_geom),      intent(in   ) :: G                        !< geometry
  real (kind=kind_real), intent(in   ) :: Ua(G%LBi:,G%LBj:,:)      !< A-grid U
  real (kind=kind_real), intent(in   ) :: Va(G%LBi:,G%LBj:,:)      !< A-grid V
  real (kind=kind_real), intent(inout) :: Uc(G%LBi:,G%LBj:,:)      !< C-grid U
  real (kind=kind_real), intent(inout) :: Vc(G%LBi:,G%LBj:,:)      !< C-grid V

  integer                              :: N, cgrid, i, j, k
  integer                              :: Istr, Iend, IstrR, IendR
  integer                              :: Jstr, Jend, JstrR, JendR

  real (kind=kind_real), dimension(G%LBi:G%UBi,G%LBj:G%UBj)     :: Ur,  Vr
  real (kind=kind_real), dimension(G%LBi:G%UBi,G%LBj:G%UBj,G%N) :: U_a, V_a

  ! Initialize.

  cgrid = r2dvar
  Istr  = G%bounds(cgrid) % IstrC
  Iend  = G%bounds(cgrid) % IendC
  Jstr  = G%bounds(cgrid) % JstrC
  Jend  = G%bounds(cgrid) % JendC
  IstrR = G%bounds(cgrid) % IstrD
  IendR = G%bounds(cgrid) % IendD
  JstrR = G%bounds(cgrid) % JstrD
  JendR = G%bounds(cgrid) % JendD
  N     = SIZE(Ua, 3)

  Ur    = 0.0_kind_real
  Vr    = 0.0_kind_real
  U_a   = 0.0_kind_real
  V_a   = 0.0_kind_real

  ! Duplicate input A-grid vector components and perform halo exchanges.

  U_a(IstrR:IendR,JstrR:JendR,1:N) = Ua(IstrR:IendR,JstrR:JendR,1:N)
  V_a(IstrR:IendR,JstrR:JendR,1:N) = Va(IstrR:IendR,JstrR:JendR,1:N)

  CALL mp_exchange3d (G%ng, G%tile, G%model, 2,                                &
                      G%LBi, G%UBi, G%LBj, G%UBj, 1, N,                        &
                      G%NghostPoints,                                          &
                      G%EWperiodic, G%NSperiodic,                              &
                      U_a, V_a)

  ! Transform vector components from A-grid (cell center) to staggered Arakawa
  ! C-grid.

  K_LOOP : DO k = 1, N

    ! Rotate from geographical Eastward and Northward directions to
    ! computational (XI,ETA) directions.

    DO j=Jstr-1,JendR
      DO i=Istr-1,IendR
        Ur(i,j) = U_a(i,j,k) * G%CosAngler(i,j)+                               &
                  V_a(i,j,k) * G%SinAngler(i,j)
        Vr(i,j) = V_a(i,j,k) * G%CosAngler(i,j)-                               &
                  U_a(i,j,k) * G%SinAngler(i,j)
      END DO
    END DO

    ! Compute staggered C-grid components.

    DO j=JstrR,JendR
      DO i=Istr,IendR
        Uc(i,j,k) = 0.5_kind_real * (Ur(i-1,j) + Ur(i,j))
        Uc(i,j,k) = Uc(i,j,k) * G%umask(i,j)
      END DO
    END DO

    DO j=Jstr,JendR
      DO i=IstrR,IendR
        Vc(i,j,k) = 0.5_kind_real * (Vr(i,j-1) + Vr(i,j))
        Vc(i,j,k) = Vc(i,j,k) * G%vmask(i,j)
      END DO
    END DO

  END DO K_LOOP

  ! Perform halo exchanges.

  CALL mp_exchange3d (G%ng, G%tile, G%model, 2,                                &
                      G%LBi, G%UBi, G%LBj, G%UBj, 1, N,                        &
                      G%NghostPoints,                                          &
                      G%EWperiodic, G%NSperiodic,                              &
                      Uc, Vc)

END SUBROUTINE vector_a_to_c

! ------------------------------------------------------------------------------
!>  It transforms A-grid adjoint vector components to C-grid.

SUBROUTINE vector_a_to_c_ad (G, ad_Ua, ad_Va, ad_Uc, ad_Vc)

  TYPE (roms_geom),      intent(in   ) :: G                        !< geometry
  real (kind=kind_real), intent(inout) :: ad_Ua(G%LBi:,G%LBj:,:)   !< A-grid U
  real (kind=kind_real), intent(inout) :: ad_Va(G%LBi:,G%LBj:,:)   !< A-grid V
  real (kind=kind_real), intent(inout) :: ad_Uc(G%LBi:,G%LBj:,:)   !< C-grid U
  real (kind=kind_real), intent(inout) :: ad_Vc(G%LBi:,G%LBj:,:)   !< C-grid V

  integer                              :: N, cgrid, i, j, k
  integer                              :: Istr, Iend, IstrR, IendR
  integer                              :: Jstr, Jend, JstrR, JendR

  real (kind=kind_real)                :: adfac, adfac1, adfac2
  real (kind=kind_real)                :: stats(4,2)

  real(kind=kind_real), dimension(G%LBi:G%UBi,G%LBj:G%UBj)     :: ad_Ur, ad_Vr
  real(kind=kind_real), dimension(G%LBi:G%UBi,G%LBj:G%UBj,G%N) :: ad_U_a, ad_V_a

  character (len=1)                    :: grid_type

  ! Report.

  IF (LdebugLinearModel) THEN
    IF (G%f_comm%rank() .eq. 0)                                                  &
      PRINT '(a)', 'ROMS_DEBUG vector_a_to_c_ad: AD ROMS - jedi2roms input'
    grid_type = 'a'
    CALL vector_stats (G, ad_Ua, ad_Va, grid_type, stats)
    IF (G%f_comm%rank() .eq. 0) THEN
      PRINT 10, 'uaocn', 'eastward_sea_water_velocity',                          &
                stats(1,1), stats(2,1), INT(stats(4,1),KIND=8)
      PRINT 10, 'vaocn', 'northward_sea_water_velocity',                         &
                stats(1,2), stats(2,2), INT(stats(4,2),KIND=8)
    END IF
  END IF

  ! Initialize.

  cgrid = r2dvar
  Istr  = G%bounds(cgrid) % IstrC
  Iend  = G%bounds(cgrid) % IendC
  Jstr  = G%bounds(cgrid) % JstrC
  Jend  = G%bounds(cgrid) % JendC
  IstrR = G%bounds(cgrid) % IstrD
  IendR = G%bounds(cgrid) % IendD
  JstrR = G%bounds(cgrid) % JstrD
  JendR = G%bounds(cgrid) % JendD
  N     = SIZE(ad_Ua, 3)

  adfac  = 0.0_kind_real
  adfac1 = 0.0_kind_real
  adfac2 = 0.0_kind_real

  ad_Ur  = 0.0_kind_real
  ad_Vr  = 0.0_kind_real
  ad_U_a = 0.0_kind_real
  ad_V_a = 0.0_kind_real

  !  Adjoint of perform halo exchange.

!>   CALL mp_exchange3d (G%ng, G%tile, G%model, 2,                             &
!>                       G%LBi, G%UBi, G%LBj, G%UBj, 1, N,                     &
!>                       G%NghostPoints,                                       &
!>                       G%EWperiodic, G%NSperiodic,                           &
!>                       Uc, Vc)
!>
  CALL ad_mp_exchange3d (G%ng, G%tile, G%model, 2,                             &
                         G%LBi, G%UBi, G%LBj, G%UBj, 1, N,                     &
                         G%NghostPoints,                                       &
                         G%EWperiodic, G%NSperiodic,                           &
                         ad_Uc, ad_Vc)

  ! Adjoint of transform vector components from A-grid (cell center) to
  ! staggered Arakawa C-grid.

  K_LOOP : DO k = 1, N

    ! Adjoint Compute staggered C-grid components.

    DO j=Jstr,JendR
      DO i=IstrR,IendR
!>      Vc(i,j,k) = Vc(i,j,k) * G%vmask(i,j)
!>
        ad_Vc(i,j,k) = ad_Vc(i,j,k) * G%vmask(i,j)

!>      Vc(i,j,k) = 0.5_kind_real * (Vr(i,j-1) + Vr(i,j))
!>
        adfac=0.5_kind_real * ad_Vc(i,j,k)
        ad_Vr(i,j-1) = ad_Vr(i,j-1) + adfac
        ad_Vr(i,j  ) = ad_Vr(i,j  ) + adfac
        ad_Vc(i,j,k) = 0.0_kind_real
      END DO
    END DO

    DO j=JstrR,JendR
      DO i=Istr,IendR
!>      Uc(i,j,k) = Uc(i,j,k) * G%umask(i,j)
!>
        ad_Uc(i,j,k) = ad_Uc(i,j,k) * G%umask(i,j)

!>      Uc(i,j,k) = 0.5_kind_real * (Ur(i-1,j) + Ur(i,j))
!>
        adfac = 0.5_kind_real * ad_Uc(i,j,k)
        ad_Ur(i-1,j) = ad_Ur(i-1,j) + adfac
        ad_Ur(i  ,j) = ad_Ur(i  ,j) + adfac
        ad_Uc(i,j,k) = 0.0_kind_real
      END DO
    END DO

    ! Adjoint of rotate from geographical Eastward and Northward directions to
    ! computational (XI,ETA) directions.

    DO j=Jstr-1,JendR
      DO i=Istr-1,IendR
!>      Vr(i,j) = V_a(i,j,k) * G%CosAngler(i,j)-                               &
!>                U_a(i,j,k) * G%SinAngler(i,j)
!>
        adfac1 = G%CosAngler(i,j) * ad_Vr(i,j)
        adfac2 = G%SinAngler(i,j) * ad_Vr(i,j)
        ad_V_a(i,j,k) = ad_V_a(i,j,k) + adfac1
        ad_U_a(i,j,k) = ad_U_a(i,j,k) - adfac2
        ad_Vr(i,j)=0.0_kind_real

!>      Urho(i,j) = U_a(i,j,k) * G%CosAngler(i,j)+                             &
!>                  V_a(i,j,k) * G%SinAngler(i,j)
!>
        adfac1 = G%CosAngler(i,j) * ad_Ur(i,j)
        adfac2 = G%SinAngler(i,j) * ad_Ur(i,j)
        ad_U_a(i,j,k) = ad_U_a(i,j,k) + adfac1
        ad_V_a(i,j,k) = ad_V_a(i,j,k) + adfac2
        ad_Ur(i,j) = 0.0_kind_real
      END DO
    END DO

  END DO K_LOOP

  ! Adjoint of duplicate input A-grid vector components and perform halo
  ! exchanges.

!>  CALL mp_exchange3d (G%ng, G%tile, G%model, 2,                              &
!>                      G%LBi, G%UBi, G%LBj, G%UBj, 1, N,                      &
!>                      G%NghostPoints,                                        &
!>                      G%EWperiodic, G%NSperiodic,                            &
!>                      U_a, V_a)
!>
  CALL ad_mp_exchange3d (G%ng, G%tile, G%model, 2,                             &
                         G%LBi, G%UBi, G%LBj, G%UBj, 1, N,                     &
                         G%NghostPoints,                                       &
                         G%EWperiodic, G%NSperiodic,                           &
                         ad_U_a, ad_V_a)

!>  V_a(IstrR:IendR,JstrR:JendR,1:N) = Va(IstrR:IendR,JstrR:JendR,1:N)
!>
  ad_Va(IstrR:IendR,JstrR:JendR,1:N)  = ad_Va(IstrR:IendR,JstrR:JendR,1:N) +   &
                                        ad_V_a(IstrR:IendR,JstrR:JendR,1:N)
  ad_V_a(IstrR:IendR,JstrR:JendR,1:N) = 0.0_kind_real

!>  U_a(IstrR:IendR,JstrR:JendR,1:N) = Ua(IstrR:IendR,JstrR:JendR,1:N)
!>
  ad_Ua(IstrR:IendR,JstrR:JendR,1:N)  = ad_Ua(IstrR:IendR,JstrR:JendR,1:N) +   &
                                        ad_U_a(IstrR:IendR,JstrR:JendR,1:N)
  ad_U_a(IstrR:IendR,JstrR:JendR,1:N) = 0.0_kind_real

  ! Report.

  IF (LdebugLinearModel) THEN
    IF (G%f_comm%rank() .eq. 0)                                                  &
      PRINT '(a)', 'ROMS_DEBUG vector_a_to_c_ad: AD ROMS - jedi2roms output'
    grid_type = 'a'
    CALL vector_stats (G, ad_Ua, ad_Va, grid_type, stats)
    IF (G%f_comm%rank() .eq. 0) THEN
      PRINT 10, 'uaocn', 'eastward_sea_water_velocity',                          &
                stats(1,1), stats(2,1), INT(stats(4,1),KIND=8)
      PRINT 10, 'vaocn', 'northward_sea_water_velocity',                         &
                stats(1,2), stats(2,2), INT(stats(4,2),KIND=8)
    END IF
    grid_type = 'c'
    CALL vector_stats (G, ad_Uc, ad_Vc, 'c', stats)
    IF (G%f_comm%rank() .eq. 0) THEN
      PRINT 10, 'uocn', 'sea_water_x_velocity',                                  &
                stats(1,1), stats(2,1), INT(stats(4,1),KIND=8)
      PRINT 10, 'vocn', 'sea_water_y_velocity',                                  &
                stats(1,2), stats(2,2), INT(stats(4,2),KIND=8)
    END IF
  END IF

  10 FORMAT (19x,'- ',a,': ',a,/,22x,'(Min = ',1p,e15.8,' Max = ',1p,e15.8,')',  &
             t93,'Checksum = ',i0)

END SUBROUTINE vector_a_to_c_ad

! ------------------------------------------------------------------------------
!>  It transforms C-grid vector components to A-grid. It used from ROMS-to-JEDI
!   implying that halos C-grid vector omponents were exhchanged in ROMS.

SUBROUTINE vector_c_to_a (G, Uc, Vc, Ua, Va)

  TYPE (roms_geom),      intent(in   ) :: G                        !< geometry
  real (kind=kind_real), intent(in   ) :: Uc(G%LBi:,G%LBj:,:)      !< C-grid U
  real (kind=kind_real), intent(in   ) :: Vc(G%LBi:,G%LBj:,:)      !< C-grid V
  real (kind=kind_real), intent(out  ) :: Ua(G%LBi:,G%LBj:,:)      !< A-grid U
  real (kind=kind_real), intent(out  ) :: Va(G%LBi:,G%LBj:,:)      !< A-grid V

  integer                              :: N, cgrid, i, j, k
  integer                              :: Istr, Iend, IstrR, IendR
  integer                              :: Jstr, Jend, JstrR, JendR

  real (kind=kind_real)                :: UaCosA, UaSinA
  real (kind=kind_real)                :: VaCosA, VaSinA

  ! Initialize.

  cgrid = r2dvar
  Istr  = G%bounds(cgrid) % IstrC
  Iend  = G%bounds(cgrid) % IendC
  Jstr  = G%bounds(cgrid) % JstrC
  Jend  = G%bounds(cgrid) % JendC
  IstrR = G%bounds(cgrid) % IstrD
  IendR = G%bounds(cgrid) % IendD
  JstrR = G%bounds(cgrid) % JstrD
  JendR = G%bounds(cgrid) % JendD
  N     = SIZE(Uc, 3)

  ! Transform vector components from staggered Arakawa C-grid to A-grid (cell
  ! center).

  K_LOOP : DO k = 1, N

    ! Compute A-grid (cell center) vector components and apply lateral boundary
    ! conditions.

    DO j=JstrR,JendR
      DO i=Istr,Iend
        Ua(i,j,k) = 0.5_kind_real * (Uc(i,j,k) + Uc(i+1,j,k))
        IF (.not. G%EWperiodic) THEN
          IF (DOMAIN(G%ng)%Western_Edge(G%tile)) THEN
            Ua(Istr-1,j,k) = Ua(Istr,j,k)
          END IF
          IF (DOMAIN(G%ng)%Eastern_Edge(G%tile)) THEN
            Ua(Iend+1,j,k) = Ua(Iend,j,k)
          END IF
        END IF
      END DO
    END DO

    DO j=Jstr,Jend
      DO i=IstrR,IendR
        Va(i,j,k) = 0.5_kind_real *(Vc(i,j,k) + Vc(i,j+1,k))
        IF (.not. G%NSperiodic) THEN
          IF (DOMAIN(G%ng)%Southern_Edge(G%tile)) THEN
            Va(i,Jstr-1,k) = Va(i,Jstr,k)
          END IF
          IF (DOMAIN(G%ng)%Northern_Edge(G%tile)) THEN
            Va(i,Jend+1,k) = Va(i,Jend,k)
          END IF
        END IF
      END DO
    END DO

    ! Rotate from computational to gegraphical Eastward and Northward
    ! directions.

    DO j=JstrR,JendR
      DO i=IstrR,IendR
        UaCosA = Ua(i,j,k) * G%CosAngler(i,j)
        UaSinA = Ua(i,j,k) * G%SinAngler(i,j)
        VaCosA = Va(i,j,k) * G%CosAngler(i,j)
        VaSinA = Va(i,j,k) * G%SinAngler(i,j)
        Ua(i,j,k) = UaCosA - VaSinA
        Va(i,j,k) = VaCosA + UaSinA
        Ua(i,j,k) = Ua(i,j,k) * G%rmask(i,j)
        Va(i,j,k) = Va(i,j,k) * G%rmask(i,j)
      END DO
    END DO

  END DO K_LOOP

  ! Perform halo exchange.

  CALL mp_exchange3d (G%ng, G%tile, G%model, 2,                                &
                      G%LBi, G%UBi, G%LBj, G%UBj, 1, N,                        &
                      G%NghostPoints,                                          &
                      G%EWperiodic, G%NSperiodic,                              &
                      Ua, Va)

END SUBROUTINE vector_c_to_a

! ------------------------------------------------------------------------------
!>  Adjoint of transforming for C-grid vector components to A-grid. It used from
!   ROMS-to-JEDI implying that halos C-grid vector omponents were exhchanged in
!   ROMS.

SUBROUTINE vector_c_to_a_ad (G, ad_Uc, ad_Vc, ad_Ua, ad_Va)

  TYPE (roms_geom),      intent(in   ) :: G                        !< geometry
  real (kind=kind_real), intent(inout) :: ad_Uc(G%LBi:,G%LBj:,:)   !< C-grid U
  real (kind=kind_real), intent(inout) :: ad_Vc(G%LBi:,G%LBj:,:)   !< C-grid V
  real (kind=kind_real), intent(inout) :: ad_Ua(G%LBi:,G%LBj:,:)   !< A-grid U
  real (kind=kind_real), intent(inout) :: ad_Va(G%LBi:,G%LBj:,:)   !< A-grid V

  integer                              :: N, cgrid, i, j, k
  integer                              :: Istr, Iend, IstrR, IendR
  integer                              :: Jstr, Jend, JstrR, JendR
  real (kind=kind_real)                :: adfac
  real (kind=kind_real)                :: ad_UaCosA, ad_UaSinA
  real (kind=kind_real)                :: ad_VaCosA, ad_VaSinA
  real (kind=kind_real)                :: stats(4,2)

  character (len=1)                    :: grid_type

  ! Report.

  IF (LdebugLinearModel) THEN
    IF (G%f_comm%rank() .eq. 0)                                                  &
      PRINT '(a)', 'ROMS_DEBUG vector_c_to_a_ad: AD ROMS - roms2jedi input' 
    grid_type = 'c'
    CALL vector_stats (G, ad_Uc, ad_Vc, grid_type, stats)
    IF (G%f_comm%rank() .eq. 0) THEN
      PRINT 10, 'uocn', 'sea_water_x_velocity',                                  &
                stats(1,1), stats(2,1), INT(stats(4,1),KIND=8)
      PRINT 10, 'vocn', 'sea_water_y_velocity',                                  &
                stats(1,2), stats(2,2), INT(stats(4,2),KIND=8)
    END IF
  END IF

  ! Initialize.

  cgrid = r2dvar
  Istr  = G%bounds(cgrid) % IstrC
  Iend  = G%bounds(cgrid) % IendC
  Jstr  = G%bounds(cgrid) % JstrC
  Jend  = G%bounds(cgrid) % JendC
  IstrR = G%bounds(cgrid) % IstrD
  IendR = G%bounds(cgrid) % IendD
  JstrR = G%bounds(cgrid) % JstrD
  JendR = G%bounds(cgrid) % JendD
  N     = SIZE(ad_Uc, 3)

  adfac     = 0.0_kind_real
  ad_UaCosA = 0.0_kind_real
  ad_UaSinA = 0.0_kind_real
  ad_VaCosA = 0.0_kind_real
  ad_VaSinA = 0.0_kind_real

  ! Adjoint of halo.

!> CALL mp_exchange3d (G%ng, G%tile, G%model, 2,                               &
!>                     G%LBi, G%UBi, G%LBj, G%UBj, 1, N,                       &
!>                     G%NghostPoints,                                         &
!>                     G%EWperiodic, G%NSperiodic,                             &
!>                     Ua, Va)
!>
  CALL ad_mp_exchange3d (G%ng, G%tile, G%model, 2,                             &
                         G%LBi, G%UBi, G%LBj, G%UBj, 1, N,                     &
                         G%NghostPoints,                                       &
                         G%EWperiodic, G%NSperiodic,                           &
                         ad_Ua, ad_Va)

  ! Adjoint of transform vector components from staggered Arakawa C-grid to
  ! A-grid (cell center).

  K_LOOP : DO k = 1, N

    ! Adjoint of rotate from computational to gegraphical Eastward and
    ! Northward directions.

    DO j=JstrR,JendR
      DO i=IstrR,IendR
!>      Va(i,j,k) = Va(i,j,k) * G%rmask(i,j)
!>
        ad_Va(i,j,k) = ad_Va(i,j,k) * G%rmask(i,j)

!>      Ua(i,j,k) = Ua(i,j,k) * G%rmask(i,j)
!>
        ad_Ua(i,j,k) = ad_Ua(i,j,k) * G%rmask(i,j)

!>      Va(i,j,k) = VaCosA + UaSinA
!>
        ad_UaSinA = ad_UaSinA + ad_Va(i,j,k)
        ad_VaCosA = ad_VaCosA + ad_Va(i,j,k)
        ad_Va(i,j,k) = 0.0_kind_real

!>      Ua(i,j,k) = UaCosA - VaSinA
!>
        ad_VaSinA = ad_VaSinA - ad_Ua(i,j,k)
        ad_UaCosA = ad_UaCosA + ad_Ua(i,j,k)
        ad_Ua(i,j,k) = 0.0_kind_real

!>      VaSinA = Va(i,j,k) * G%SinAngler(i,j)
!>
        ad_Va(i,j,k) = ad_Va(i,j,k) + G%SinAngler(i,j) * ad_VaSinA
        ad_VaSinA = 0.0_kind_real

!>      VaCosA = Va(i,j,k) * G%CosAngler(i,j)
!>
        ad_Va(i,j,k) = ad_Va(i,j,k) + G%CosAngler(i,j) * ad_VaCosA
        ad_VaCosA = 0.0_kind_real

!>      UaSinA = Ua(i,j,k) * G%SinAngler(i,j)
!>
        ad_Ua(i,j,k) = ad_Ua(i,j,k) + G%SinAngler(i,j) * ad_UaSinA
        ad_UaSinA = 0.0_kind_real

!>      UaCosA = Ua(i,j,k) * G%CosAngler(i,j)
!>
        ad_Ua(i,j,k) = ad_Ua(i,j,k) + G%CosAngler(i,j) * ad_UaCosA
        ad_UaCosA = 0.0_kind_real
      END DO
    END DO

    ! Adjoint of compute A-grid (cell center) vector components.

    DO j=Jstr,Jend
      DO i=IstrR,IendR
        IF (.not. G%NSperiodic) THEN
          IF (DOMAIN(G%ng)%Northern_Edge(G%tile)) THEN
!>          Va(i,Jend+1,k) = Va(i,Jend,k)
!>
            ad_Va(i,Jend,k) = ad_Va(i,Jend,k) + ad_Va(i,Jend+1,k)
            ad_Va(i,Jend+1,k) = 0.0_kind_real
          END IF
          IF (DOMAIN(G%ng)%Southern_Edge(G%tile)) THEN
!>          Va(i,Jstr-1,k) = Va(i,Jstr,k)
!>
            ad_Va(i,Jstr,k) = ad_Va(i,Jstr,k) + ad_Va(i,Jstr-1,k)
            ad_Va(i,Jstr-1,k) = 0.0_kind_real
          END IF
        END IF
!>      Va(i,j,k) = 0.5_kind_real *(Vc(i,j,k) + Vc(i,j+1,k))
!>
        adfac = 0.5_kind_real * ad_Va(i,j,k)
        ad_Vc(i,j  ,k) = ad_Vc(i,j  ,k) + adfac
        ad_Vc(i,j+1,k) = ad_Vc(i,j+1,k) + adfac
        ad_Va(i,j,k) = 0.0_kind_real
      END DO
    END DO

    DO j=JstrR,JendR
      DO i=Istr,Iend
        IF (.not.G%EWperiodic) THEN
          IF (DOMAIN(G%ng)%Eastern_Edge(G%tile)) THEN
!>          Ua(Iend+1,j,k) = Ua(Iend,j,k)
!>
            ad_Ua(Iend,j,k) = ad_Ua(Iend,j,k) + ad_Ua(Iend+1,j,k)
            ad_Ua(Iend+1,j,k) = 0.0_kind_real
          END IF
          IF (DOMAIN(G%ng)%Western_Edge(G%tile)) THEN
!>          Ua(Istr-1,j,k) = Ua(Istr,j,k)
!>
            ad_Ua(Istr,j,k) = ad_Ua(Istr,j,k) + ad_Ua(Istr-1,j,k)
            ad_Ua(Istr-1,j,k) = 0.0_kind_real
          END IF
        END IF
!>      Ua(i,j,k) = 0.5_kind_real * (Uc(i,j,k) + Uc(i+1,j,k))
!>
        adfac = 0.5_kind_real * ad_Ua(i,j,k)
        ad_Uc(i  ,j,k) = ad_Uc(i  ,j,k) + adfac
        ad_Uc(i+1,j,k) = ad_Uc(i+1,j,k) + adfac
        ad_Ua(i,j,k) = 0.0_kind_real
      END DO
    END DO

  END DO K_LOOP

  ! Report.

  IF (LdebugLinearModel) THEN
    IF (G%f_comm%rank() .eq. 0)                                                  &
      PRINT '(a)', 'ROMS_DEBUG vector_c_to_a_ad: AD ROMS - roms2jedi output'
    grid_type = 'c'
    CALL vector_stats (G, ad_Uc, ad_Vc, grid_type, stats)
    IF (G%f_comm%rank() .eq. 0) THEN
      PRINT 10, 'uocn', 'sea_water_x_velocity',                                  &
                stats(1,1), stats(2,1), INT(stats(4,1),KIND=8)
      PRINT 10, 'vocn', 'sea_water_y_velocity',                                  &
                stats(1,2), stats(2,2), INT(stats(4,2),KIND=8)
    END IF
    grid_type = 'a'
    CALL vector_stats (G, ad_Ua, ad_Va, grid_type, stats)
    IF (G%f_comm%rank() .eq. 0) THEN
      PRINT 10, 'uaocn', 'eastward_sea_water_velocity',                          &
                stats(1,1), stats(2,1), INT(stats(4,1),KIND=8)
      PRINT 10, 'vaocn', 'northward_sea_water_velocity',                         &
                stats(1,2), stats(2,2), INT(stats(4,2),KIND=8)
    END IF
  END IF

  10 FORMAT (19x,'- ',a,': ',a,/,22x,'(Min = ',1p,e15.8,' Max = ',1p,e15.8,')',  &
             t93,'Checksum = ',i0)

END SUBROUTINE vector_c_to_a_ad

! ------------------------------------------------------------------------------
!> Calculate global statistics for vector components (min, max, average).

SUBROUTINE vector_stats (G, U, V, grid_type, stats)

  TYPE (roms_geom),      intent(in   ) :: G                  !< geometry
  real (kind=kind_real), intent(in   ) :: U(G%LBi:,G%LBj:,:) !< U-component
  real (kind=kind_real), intent(in   ) :: V(G%LBi:,G%LBj:,:) !< V-component
  character (len=*),     intent(in   ) :: grid_type          !< 'a' or 'c'
  real (kind=kind_real), intent(inout) :: stats(4,2)         !< [min, max, mean]

  logical, allocatable                 :: Umask(:,:), Vmask(:,:)
  integer                              :: IstrU, IendU, JstrU, JendU
  integer                              :: IstrV, IendV, JstrV, JendV
  real (kind=kind_real)                :: my_water_cells, water_cells
  real (kind=kind_real)                :: buffer(4)

  ! Indices for computational domain.

  SELECT CASE (grid_type)

    CASE ('a', 'A')
      IstrU = G%bounds(r2dvar)%IstrD
      IendU = G%bounds(r2dvar)%IendD
      JstrU = G%bounds(r2dvar)%JstrD
      JendU = G%bounds(r2dvar)%JendD

      allocate ( Umask(IstrU:IendU, JstrU:JendU) )
      Umask = G%rmask(IstrU:IendU, JstrU:JendU) > 0.0

      IstrV = G%bounds(r2dvar)%IstrD
      IendV = G%bounds(r2dvar)%IendD
      JstrV = G%bounds(r2dvar)%JstrD
      JendV = G%bounds(r2dvar)%JendD

      allocate ( Vmask(IstrV:IendV, JstrV:JendV) )
      Vmask = G%rmask(IstrV:IendV, JstrV:JendV) > 0.0

    CASE ('c', 'C')
      IstrU = G%bounds(u2dvar)%IstrD
      IendU = G%bounds(u2dvar)%IendD
      JstrU = G%bounds(u2dvar)%JstrD
      JendU = G%bounds(u2dvar)%JendD

      allocate ( Umask(IstrU:IendU, JstrU:JendU) )
      Umask = G%umask(IstrU:IendU, JstrU:JendU) > 0.0

      IstrV = G%bounds(v2dvar)%IstrD
      IendV = G%bounds(v2dvar)%IendD
      JstrV = G%bounds(v2dvar)%JstrD
      JendV = G%bounds(v2dvar)%JendD

      allocate ( Vmask(IstrV:IendV, JstrV:JendV) )
      Vmask = G%vmask(IstrV:IendV, JstrV:JendV) > 0.0

  END SELECT

  ! Calculate global min, max, mean, and CheckSum for each U-component.

  my_water_cells = COUNT(Umask)

  CALL G%f_comm%allreduce (my_water_cells, water_cells, fckit_mpi_sum())

  CALL field_info (U(IstrU:IendU, JstrU:JendU,:), Umask, buffer)

  CALL G%f_comm%allreduce (buffer(1), stats(1,1), fckit_mpi_min())
  CALL G%f_comm%allreduce (buffer(2), stats(2,1), fckit_mpi_max())
  CALL G%f_comm%allreduce (buffer(3), stats(3,1), fckit_mpi_sum())

  stats(3,1) = stats(3,1) / water_cells                  ! mean
  stats(4,1) = buffer(4)                                 ! CheckSum

  ! Calculate global min, max, mean and CheckSum for each V-component.

  my_water_cells = COUNT(Vmask)

  CALL G%f_comm%allreduce (my_water_cells, water_cells, fckit_mpi_sum())

  CALL field_info (V(IstrV:IendV, JstrV:JendV,:), Vmask, buffer)

  CALL G%f_comm%allreduce (buffer(1), stats(1,2), fckit_mpi_min())
  CALL G%f_comm%allreduce (buffer(2), stats(2,2), fckit_mpi_max())
  CALL G%f_comm%allreduce (buffer(3), stats(3,2), fckit_mpi_sum())

  stats(3,2) = stats(3,2) / water_cells                  ! mean
  stats(4,2) = buffer(4)                                 ! CheckSum

  ! Deallocate local arrays

  deallocate (Umask)
  deallocate (Vmask)

END SUBROUTINE vector_stats

! ------------------------------------------------------------------------------

END MODULE roms_utils_mod
