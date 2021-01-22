
    !-------------------------------------------------------------------------------------------------------------
    !
    !> \file    CompExcessGibbsEnergySUBI.f90
    !> \brief   Compute the partial molar excess Gibbs energy of mixing of solution phase constituents in a
    !!          SUBI solution phase.
    !> \author  M.H.A. Piro
    !> \date    January 19, 2021
    !> \sa      CompExcessGibbsEnergy.f90
    !> \sa      CompExcessGibbsEnergyRKMP.f90
    !> \sa      CompExcessGibbsEnergyQKTO.f90
    !
    !
    ! Revisions:
    ! ==========
    !
    !   Date            Programmer      Description of change
    !   ----            ----------      ---------------------
    !   01/19/2021      M. POschmann     Original code
    !
    !
    ! Purpose:
    ! ========
    !
    !> \details The purpose of this subroutine is to compute the partial molar excess Gibbs energy of mixing
    !! (dPartialExcessGibbs) of all constituents in a non-ideal solution phase designated as 'SUBI'
    !! (Ionic Liquid Model).
    !!
    !
    ! Pertinent variables:
    ! ====================
    !
    !> \param[in] iSolnIndex    Absolute index of a solution phase
    !
    ! nSpeciesPhase             An integec vector representing the last index of a species in a particular
    !                            solution phase
    ! nParamPhase               An integer vector representing the number of parameters for a particular phase.
    ! nSublattice               An integer scalar representing the number of sublattices associated with this
    !                            particular phase (used for convenience).
    ! nSublatticePhase          An integer vector representing the number of sublattices for each charged phase.
    ! iChargedPhaseID           An integer scalar representing the relative index of the charged phase.
    ! iParam                    An integer scalar representing the index number of a parameter.
    ! iPhaseSublattice          An integer vector representing the relative index of a charged phase corresponding
    !                            to each solution phase in the system.  Thus, it is equal to zero for a phase
    !                            that does not contain any sublattices.
    ! iRegularParam             An integer matrix representing the relative indices of species mixing for a
    !                            particular parmater.
    ! iFirst             An integer scalar representing the absolute index of the first species in a phase.
    ! iLast              An integer scalar representing the absolute index of the last species in a phase.
    ! dChemicalPotential        A double real vector representing the chemical potential for every species in the
    !                            system.
    ! dMolFraction              A double real vector representing hte mole fraction of all species in the system.
    ! dSiteFraction             A double real array representing the site fraction of each constituent on each
    !                            sublattice.  The first dimension corresponds to the charged phase index, the
    !                            second dimension corresponds to the sublattice index and the third dimension
    !                            corresponds to the constituent index.
    ! dExcessGibbsParam         A double real vector representing the molar excess Gibbs energy of mixing for
    !                            each subsystem.
    ! dPartialExcessGibbs       Partial molar excess Gibbs energy of mixing of species.
    ! dMolFraction              Current estimated mole fraction.
    ! cSolnPhaseType            A character vector representing the solution phase type.
    ! iConstituentSublattice    An integer array representing the constituent index for a particular sublattice
    !                            phase.  The first dimension refers to the relative phase index for charged phases,
    !                            the second dimension represents the sublattice index and the third dimension
    !                            corresponds to the relative component index (not absolute).
    ! iFirstParam               An integer scalar representing the constituent index of the first constituent
    !                            that is being mixed for a mixing parameter.
    ! iSeconParam               An integer scalar representing the constituent index of the second constituent
    !                            that is being mixed for a mixing parameter.
    ! iSubParam                 An integer scalar representing the sublattice index corresponding to the mixing
    !                            parameter.
    !
    !-------------------------------------------------------------------------------------------------------------


subroutine CompExcessGibbsEnergySUBI(iSolnIndex)

    USE ModuleThermo
    USE ModuleThermoIO
    USE ModuleGEMSolver

    implicit none

    integer :: i, j, l, k, k1, l1, k2, l2, m, n, s, c, d
    integer :: iSolnIndex, nSublattice, iChargedPhaseID, iMixType
    integer :: iFirst, iLast, iFirstParam, iSecondParam, iSubParam, iFirstParam2, iSecondParam2, iSubParam2
    integer :: iTempParam1, iTempParam2, iExponent, iTempSub, iThirdParam, iTernaryCon
    real(8) :: dTemp, dPreFactor, dFirstParam, dSecondParam, dFirstParam2, dSecondParam2, dThirdParam
    real(8) :: dTempParam1, dTempParam2, KD, dSum, dEnt
    real(8), dimension(nMaxSublatticeSys):: dTempVec


    ! Only proceed if the correct phase type is selected:
    IF_SUBL: if (cSolnPhaseType(iSolnIndex) == 'SUBI') then

        ! Define temporary variables for sake of convenience:
        iChargedPhaseID = iPhaseSublattice(iSolnIndex)
        nSublattice     = nSublatticePhase(iChargedPhaseID)
        iFirst          = nSpeciesPhase(iSolnIndex-1) + 1
        iLast           = nSpeciesPhase(iSolnIndex)

        ! Initialize variables:
        dSiteFraction(iChargedPhaseID,1:nSublattice,1:nMaxConstituentSys) = 0D0
        dChemicalPotential(iFirst:iLast)                                  = 0D0
        dPartialExcessGibbs(iFirst:iLast)                                 = 0D0
        dTempVec                                                          = 0D0

        ! Compute site fractions on each sublattice:
        LOOP_SiteFraction: do i = iFirst, iLast

            ! Relative component index:
            m = i - iFirst + 1

            ! Loop through sublattices:
            do s = 1, nSublattice
                ! Store constituent index on sublattice s:
                c = iConstituentSublattice(iChargedPhaseID,s,m)
                if (c > 0) dSiteFraction(iChargedPhaseID,s,c) = dSiteFraction(iChargedPhaseID,s,c) + dMolFraction(i)
            end do
        end do LOOP_SiteFraction

        ! print *, 'SITE FRACTIONS'
        ! print *, dSiteFraction(iChargedPhaseID,1,:)
        ! print *, dSiteFraction(iChargedPhaseID,2,:)

        ! Compute P and Q
        dStoichSublattice(iChargedPhaseID,1:2) = 0D0
        ! Q first
        do i = 1, nConstituentSublattice(iChargedPhaseID,1)
            dStoichSublattice(iChargedPhaseID,2) = dStoichSublattice(iChargedPhaseID,2) + &
                dSublatticeCharge(iChargedPhaseID,1,i) * dSiteFraction(iChargedPhaseID,1,i)
        end do
        ! Then P
        do i = 1, nConstituentSublattice(iChargedPhaseID,2)
            if ((cConstituentNameSUB(iChargedPhaseID,2,i) == 'VA') .OR. &
                (cConstituentNameSUB(iChargedPhaseID,2,i) == 'Va') .OR. &
                (cConstituentNameSUB(iChargedPhaseID,2,i) == 'va')) then
                ! Correct vacancy site fraction
                dSiteFraction(iChargedPhaseID,2,i) = dSiteFraction(iChargedPhaseID,2,i) / dStoichSublattice(iChargedPhaseID,2)
                ! Use Q as charge if this constituent is vacancy
                dStoichSublattice(iChargedPhaseID,1) = dStoichSublattice(iChargedPhaseID,1) + &
                    dStoichSublattice(iChargedPhaseID,2) * dSiteFraction(iChargedPhaseID,2,i)
            else
                dStoichSublattice(iChargedPhaseID,1) = dStoichSublattice(iChargedPhaseID,1) - &
                    dSublatticeCharge(iChargedPhaseID,2,i) * dSiteFraction(iChargedPhaseID,2,i)
            end if
        end do

        ! print *, 'Q: ', dStoichSublattice(iChargedPhaseID,2), 'P: ', dStoichSublattice(iChargedPhaseID,1)

        ! REFERENCE GIBBS ENERGY AND IDEAL MIXING
        ! ---------------------------------------

        ! Compute the chemical potential for each phase component assuming ideal mixing:
        LOOP_Ideal: do i = iFirst, iLast
            ! Relative species index:
            m = i - iFirst + 1

            ! Loop through components:
            LOOP_Ideal_Components: do j = iFirst, iLast
                ! Relative species index:
                n = j - iFirst + 1

                ! Compute pre-factor term:
                dTemp = -1D0

                ! Store constituent indices:
                k2 = iConstituentSublattice(iChargedPhaseID,2,m)
                l2 = iConstituentSublattice(iChargedPhaseID,2,n)

                ! Update the reference molar Gibbs energy:
                if ((dSublatticeCharge(iChargedPhaseID,2,k2) == 0D0)) then
                    ! Effectively apply Kronecker-Delta term to pre-factor:
                    if (k2 == l2)  dTemp = dTemp + 1D0 / dSiteFraction(iChargedPhaseID,2,k2)
                    dTemp = dTemp + 1D0
                    dChemicalPotential(i) = dChemicalPotential(i) + dTemp * dMolFraction(j) * dStdGibbsEnergy(j)
                else
                    ! Effectively apply Kronecker-Delta term to pre-factor:
                    if ((k2 == l2) .AND. (k2 > 0))  dTemp = dTemp + 1D0 / dSiteFraction(iChargedPhaseID,2,k2)
                    ! Store constituent indices:
                    k1 = iConstituentSublattice(iChargedPhaseID,1,m)
                    l1 = iConstituentSublattice(iChargedPhaseID,1,n)

                    ! Effectively apply Kronecker-Delta term to pre-factor:
                    if ((k1 == l1) .AND. (k1 > 0))  dTemp = dTemp + 1D0 / dSiteFraction(iChargedPhaseID,1,k1)
                    if ((cConstituentNameSUB(iChargedPhaseID,2,k2) == 'VA') .OR. &
                        (cConstituentNameSUB(iChargedPhaseID,2,k2) == 'Va') .OR. &
                        (cConstituentNameSUB(iChargedPhaseID,2,k2) == 'va')) then
                        dTemp = dTemp / dStoichSublattice(iChargedPhaseID,2)
                    end if
                    dChemicalPotential(i) = dChemicalPotential(i) + dTemp * dMolFraction(j) * dStdGibbsEnergy(j)
                end if
            end do LOOP_Ideal_Components
            ! print *, cSpeciesName(i), ' Reference ', dChemicalPotential(i) * dIdealConstant * dTemperature

            dEnt = 0D0
            ! Add ideal mixing contribution:
            c = iConstituentSublattice(iChargedPhaseID,2,m)
            if ((cConstituentNameSUB(iChargedPhaseID,2,c) == 'VA') .OR. &
                (cConstituentNameSUB(iChargedPhaseID,2,c) == 'Va') .OR. &
                (cConstituentNameSUB(iChargedPhaseID,2,c) == 'va')) then
                dEnt = dEnt + DLOG(dSiteFraction(iChargedPhaseID,2,c))
                c = iConstituentSublattice(iChargedPhaseID,1,m)
                dEnt = dEnt + dSiteFraction(iChargedPhaseID,1,c) * DLOG(dSiteFraction(iChargedPhaseID,1,c))
            else
                dEnt = dEnt + dStoichSublattice(iChargedPhaseID,2) * DLOG(dSiteFraction(iChargedPhaseID,2,c))
                c = iConstituentSublattice(iChargedPhaseID,1,m)
                if (dSiteFraction(iChargedPhaseID,1,c) > 0) then
                    dEnt = dEnt + dStoichSublattice(iChargedPhaseID,1) * DLOG(dSiteFraction(iChargedPhaseID,1,c))
                end if
            end if

            ! print *, cSpeciesName(i), ' Entropy ', dEnt * dIdealConstant * dTemperature
            dChemicalPotential(i) = dChemicalPotential(i) + dEnt

            ! Sum stoichiometry and add large penalty if this species is vacancies only and a large mole fraction
            dSum = 0D0
            do j = 1, nElements
                dSum = dSum + ABS(dStoichSpecies(i,j))
            end do
            if ((dSum == 0D0) .AND. (dMolFraction(i) > 0.9D0)) dChemicalPotential(i) = dChemicalPotential(i) + 1D3
        end do LOOP_Ideal

        ! dTemp = 0D0
        ! do i = iFirst, iLast
        !   dTemp = dTemp + dMolesSpecies(i)*dChemicalPotential(i)*dTemperature*dIdealConstant
        !   print *, cSpeciesName(i), dMolesSpecies(i),dMolesSpecies(i)*dStoichSpecies(i,1),dMolesSpecies(i)*dStoichSpecies(i,2), &
        !        dChemicalPotential(i)*dTemperature*dIdealConstant
        ! end do
        ! print *, dTemp

        ! EXCESS TERMS
        ! ------------

        ! Return control to the parent subroutine if there aren't any interaction parameters for this phase:
        if (nParamPhase(iSolnIndex) - nParamPhase(iSolnIndex-1) == 0) return

        ! Loop through parameters:
        LOOP_Param: do l = nParamPhase(iSolnIndex-1) + 1, nParamPhase(iSolnIndex)

            ! Reinitialize temporary variable:
            dPreFactor = 1D0
            iFirstParam = 0
            iSecondParam = 0
            iFirstParam2 = 0
            iSecondParam2 = 0

            iMixType = 0

            ! Store the number of constituents involved in this parameter:
            n = iRegularParam(l,1)
            ! print *, iSUBLParamData(l,:)
            ! Determine the mixing parameter type
            if ((iSUBLParamData(l,1) == 1) .AND. (iSUBLParamData(l,3) == 2)) then
                iMixType = 2

                ! Loop through constituents associated with this parameter:
                do k = 2, n + 1
                    ! Determine constituent and sublattice indices:
                    c = MOD(iRegularParam(l,k), 10000)
                    s = iRegularParam(l,k) - c
                    s = s / 10000

                    ! Compute prefactor term:
                    dPreFactor = dPreFactor * dSiteFraction(iChargedPhaseID,s,c)

                    ! Store the first and second site fractions:
                    if (k == iSUBLParamData(l,2)) then
                        dFirstParam = dSiteFraction(iChargedPhaseID,s,c)
                        iFirstParam = c
                        iSubParam   = s
                    else if (k == iSUBLParamData(l,2) + 1) then
                        dSecondParam = dSiteFraction(iChargedPhaseID,s,c)
                        iSecondParam = c
                    end if
                end do

                ! Multiply prefactor term by excess Gibbs energy parameter:
                iExponent = iRegularParam(l,n+2)
                dPreFactor = dPreFactor * dExcessGibbsParam(l) * (dFirstParam - dSecondParam)**(iExponent)
            else if ((iSUBLParamData(l,1) == 1) .AND. (iSUBLParamData(l,3) == 3)) then
                iMixType = 3
                iTernaryCon = iRegularParam(l,n+2)

                ! Loop through constituents associated with this parameter:
                do k = 2, n + 1
                    ! Determine constituent and sublattice indices:
                    c = MOD(iRegularParam(l,k), 10000)
                    s = iRegularParam(l,k) - c
                    s = s / 10000

                    ! Compute prefactor term:
                    dPreFactor = dPreFactor * dSiteFraction(iChargedPhaseID,s,c)

                    ! Store the first and second site fractions:
                    if (k == iSUBLParamData(l,2) + iTernaryCon) then
                        dFirstParam = dSiteFraction(iChargedPhaseID,s,c)
                        iFirstParam = c
                        iSubParam   = s
                    else if (k == iSUBLParamData(l,2) + MOD(iTernaryCon + 1, 3)) then
                        dSecondParam = dSiteFraction(iChargedPhaseID,s,c)
                        iSecondParam = c
                    else if (k == iSUBLParamData(l,2) + MOD(iTernaryCon + 2, 3)) then
                        dThirdParam = dSiteFraction(iChargedPhaseID,s,c)
                        iThirdParam = c
                    end if
                end do

                ! Multiply prefactor term by excess Gibbs energy parameter:
                iExponent = 0
                dPreFactor = dPreFactor * dExcessGibbsParam(l)
                dPreFactor = dPreFactor * (dFirstParam + (1D0 - dFirstParam - dSecondParam - dThirdParam) / 3D0)
            else if ((iSUBLParamData(l,1) == 2) .AND. (iSUBLParamData(l,3) == 2) .AND. (iSUBLParamData(l,5) == 2)) then
                iMixType = 4
                ! Loop through constituents associated with this parameter:
                do k = 2, n + 1

                    ! Determine constituent and sublattice indices:
                    c = MOD(iRegularParam(l,k), 10000)
                    s = iRegularParam(l,k) - c
                    s = s / 10000

                    ! Compute prefactor term:
                    dPreFactor = dPreFactor * dSiteFraction(iChargedPhaseID,s,c)

                    ! Store the site fractions:
                    if (k == iSUBLParamData(l,2)) then
                        dFirstParam = dSiteFraction(iChargedPhaseID,s,c)
                        iFirstParam = c
                        iSubParam   = s
                    else if (k == iSUBLParamData(l,2) + 1) then
                        dSecondParam = dSiteFraction(iChargedPhaseID,s,c)
                        iSecondParam = c
                    else if (k == iSUBLParamData(l,4)) then
                        dFirstParam2 = dSiteFraction(iChargedPhaseID,s,c)
                        iFirstParam2 = c
                        iSubParam2   = s
                    else if (k == iSUBLParamData(l,4) + 1) then
                        dSecondParam2 = dSiteFraction(iChargedPhaseID,s,c)
                        iSecondParam2 = c
                    end if
                end do

                ! Multiply prefactor term by excess Gibbs energy parameter:
                if (MOD(iRegularParam(l,n+2),2) == 0) then
                    iExponent = iRegularParam(l,n+2)/2
                else if (MOD(iRegularParam(l,n+2),2) == 1) then
                    iExponent = (iRegularParam(l,n+2)-1)/2
                    iTempParam1 = iFirstParam
                    iTempParam2 = iSecondParam
                    dTempParam1 = dFirstParam
                    dTempParam2 = dSecondParam

                    iFirstParam = iFirstParam2
                    iSecondParam = iSecondParam2
                    dFirstParam = dFirstParam2
                    dSecondParam = dSecondParam2

                    iFirstParam2 = iTempParam1
                    iSecondParam2 = iTempParam2
                    dFirstParam2 = dTempParam1
                    dSecondParam2 = dTempParam2

                    iTempSub = iSubParam
                    iSubParam = iSubParam2
                    iSubParam2 = iTempSub
                end if

                dPreFactor = dPreFactor * dExcessGibbsParam(l) * (dFirstParam - dSecondParam)**(iExponent)

                ! print *, dExcessGibbsParam(l), dFirstParam, dSecondParam, dFirstParam2, dSecondParam2
            else
                print *, 'Unrecognized excess mixing term in SUBI phase ', cSolnPhaseName(iSolnIndex)
                INFOThermo = 36
                return
            end if

            ! Loop through species in phase:
            LOOP_Param_Species: do i = iFirst, iLast

                ! Reinitialize variables:
                KD    = 0D0
                m     = i - iFirst + 1
                if ((iMixType == 2) .OR. (iMixType == 4)) then
                    dTemp = -DFLOAT(nSublattice + iExponent)
                else if (iMixType == 3) then
                    dTemp = -3D0
                end if

                ! Loop through sublattices associated with this phase:
                LOOP_Param_Sub: do s = 1, nSublattice
                    ! Store constituent index corresponding to component i on sublattice s:
                    c = iConstituentSublattice(iChargedPhaseID,s,m)

                    ! Assign Kronecker-Delta term if this component contains the constituent corresponding
                    ! to the mixing parameter:
                    if (s == iSubParam) then
                        if (c == iFirstParam) then
                            ! This is the first mixing constituent:
                            if ((iMixType == 2) .OR. (iMixType == 4)) then
                                KD = 1D0
                            else if (iMixType == 3) then
                                KD = 2D0/3D0
                            end if
                        elseif (c == iSecondParam) then
                            ! This is the second mixing constituent:
                            if ((iMixType == 2) .OR. (iMixType == 4)) then
                                KD = -1D0
                            else if (iMixType == 3) then
                                KD = -1D0/3D0
                            end if
                        elseif (c == iThirdParam) then
                            ! This is the second mixing constituent:
                            if (iMixType == 3) then
                                KD = -1D0/3D0
                            end if
                        else
                            ! The constituents don't match:
                            KD = 0
                        end if
                    end if

                    ! Loop through constituents involved in this mixing parameter:
                    LOOP_Param_Const: do j = 2, n + 1
                        k = MOD(iRegularParam(l,j), 10000)  ! Constituent index corresponding to parameter.
                        d = iRegularParam(l,j) - k
                        d = d / 10000                       ! Sublattice index corresponding to parameter.

                        ! Cycle if they are on different sublattices:
                        if (d /= s) cycle LOOP_Param_Const

                        ! Cycle if they are different constituents:
                        if (k /= c) cycle LOOP_Param_Const

                        ! Include contribution from this site fraction:
                        dTemp = dTemp + 1D0 / dSiteFraction(iChargedPhaseID,s,c)

                    end do LOOP_Param_Const ! j
                end do LOOP_Param_Sub       ! s

                ! Apply higher order terms
                if (iMixType == 2) then
                    ! only if dFirstParam and dSecondParam are not the same:
                    if (dFirstParam /= dSecondParam) then
                        dTemp = dTemp + KD * DFLOAT(iExponent) / (dFirstParam - dSecondParam)
                    end if
                else if (iMixType == 3) then
                    dTemp = dTemp + KD / (dFirstParam + (1D0 - dFirstParam - dSecondParam - dThirdParam) / 3D0)
                else if (iMixType == 4) then
                    ! only if dFirstParam and dSecondParam are not the same:
                    if (dFirstParam /= dSecondParam) then
                        dTemp = dTemp + KD * DFLOAT(iExponent) / (dFirstParam - dSecondParam)
                    end if
                    dTemp = dTemp - 1D0
                end if

                ! Apply partial molar excess Gibbs energy of mixing:
                dPartialExcessGibbs(i) = dPartialExcessGibbs(i) + dPreFactor * dTemp

            end do LOOP_Param_Species       ! i

        end do LOOP_Param                   ! l

    end if IF_SUBL

    return

end subroutine CompExcessGibbsEnergySUBI
