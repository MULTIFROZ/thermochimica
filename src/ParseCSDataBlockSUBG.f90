

    !-------------------------------------------------------------------------------------------------------------
    !
    !> \file    ParseCSDataBlockSUBG.f90
    !> \brief   Parse the data block section corresponding to a SUBG phase of a ChemSage data-file.
    !> \author  M.H.A. Piro
    !> \date    Mar. 4, 2018
    !> \sa      ParseCSDataFile.f90
    !> \sa      ParseCSDataBlock.f90
    !> \sa      ParseCSDataBlockGibbs.f90
    !> \todo    There are a number of lines in SUBG phases that I do not yet understand.
    !!           I've asked some experts and they don't know either, which tells me that
    !!           they're not important. Once I
    !!           gain more experience with these models, this will likely become more clear.
    !
    !
    ! DISCLAIMER
    ! ==========
    !
    ! All of the programming herein is original unless otherwise specified and is completely
    ! independent of ChemApp and related products, including Solgas, Solgasmix, Fact, FactSage
    ! and ChemSage.
    !
    !
    ! Revisions:
    ! ==========
    !
    !   Date            Programmer      Description of change
    !   ----            ----------      ---------------------
    !   03/04/2018      M.H.A. Piro     Original code
    !
    !
    ! Purpose:
    ! ========
    !
    !> \details The purpose of this subroutine is to parse the "data block" section of a ChemSage data-file
    !! containing a "SUBG" phase, which represents the modified quasichemical model. This phase differs
    !! from many other types of thermodynamic models in that it attempts to capture Short Range Order (SRO)
    !! in liquid or solid solutions. This is achieved by focusing on pairs of species, rather than the species
    !! themselves. For more information, see the following paper:
    !!
    !! A.D. Pelton, S.A. Degterov, G. Eriksson, C. Roberlin, Y. Dessureault, "The Modified Quasichemical
    !! Model I -- Binary Solutions", Metallurgical and Materials Transactions B, 31B (2000) 651-659.
    !!
    !
    !
    ! Pertinent variables:
    ! ====================
    !
    ! INFO                      A scalar integer that indicates a successful exit or identifies an error.
    ! nSpeciesCS                Number of species in the system (combined solution species and pure
    !                            separate phases).
    ! nGibbsEqSpecies           Number of Gibbs energy equations for a particular species.
    ! iSpeciesAtomsCS           Integer matrix representing the number of atoms of a particular
    !                            elements in a species.
    ! iParticlesPerMoleCS       An integer vector containing the number of particles per mole of the
    !                            constituent species formula mass.  The default value is 1.
    ! cSolnPhaseNameCS          The name of a solution phase.
    ! cSolnPhaseTypeCS          The type of a solution phase.
    ! cSolnPhaseTypeSupport     A character array representing solution phase types that are supported.
    ! iRegularParamCS           An integer matrix representing the parameter index for the first dimension
    !                            and the mixing terms on the second dimension.  For the second dimension, the
    !                            first coefficient indicates whether the parameter is a binary or ternary term (n),
    !                            the next n coefficients correspond to the constituent indices, and the last
    !                            coefficient corresponds to the exponent.
    !
    !-------------------------------------------------------------------------------------------------------------


subroutine ParseCSDataBlockSUBG( i )

    USE ModuleParseCS

    implicit none

    integer                     :: i, j, k, l, n, x, y, p, a, b, nPairs, nCSCS, nTotalConst
    integer                     :: iaaxy, ibbxy, iabxx, iabyy
    integer,     dimension(10)  :: iTempVec
    real(8)                     :: qa, qb, qx, qy, za, zb, zx, zy, dF
    real(8),     dimension(20)  :: dTempVec
    character(8),dimension(20)  :: cTempVec
    logical, dimension(:), allocatable :: lPairSet

    real(8), dimension(nSpeciesCS,nElementsCS) :: dStoichSpeciesOld

    nCSCS = nCountSublatticeCS

    ! Initialize variables:
    dTempVec = 0D0
    iTempVec = 0

    ! SUBG phases appear to be represented as multi-sublattice phases; however,
    ! they don't appear to make use of any sublattice information. I'm going to
    ! to read these lines for now, but it may need to be revised at a later time.

    ! This line contains N integers (where N is the number of sublattices)
    ! where each integer represents the number of constituents on the respective
    ! sublattice. I think there are always two sublattices for SUBG phases.
    read (1,*,IOSTAT = INFO) nSublatticeElementsCS(nCSCS,1:2)
    nConstituentSublatticeCS(nCSCS,1:2) = nSublatticeElementsCS(nCSCS,1:2)
    nSublatticePhaseCS(nCSCS) = 2
    nTotalConst = nConstituentSublatticeCS(nCSCS,1)+nConstituentSublatticeCS(nCSCS,2)
    allocate(dStoichConstituentCS(nTotalConst,nElementsCS))
    dStoichConstituentCS = 0D0

    nPairs = nSublatticeElementsCS(nCSCS,1) * nSublatticeElementsCS(nCSCS,2)

    ! Read in names of constituents on first sublattice:
    ! NOTE: THIS LINE MAY NEED TO BE REVISED IF THERE ARE A LARGE # OF CONSTITUENTS:
    read (1,*,IOSTAT = INFO) cConstituentNameSUBCS(nCSCS,1,1:nSublatticeElementsCS(nCSCS,1))
    ! Match elements on 1st sublattice with elements in dat file order
    LOOP_Sub1Names: do k = 1, nSublatticeElementsCS(nCSCS,1)
        call ParseConstituentName(k,1)
    end do LOOP_Sub1Names

    ! Read in names of constituents on second sublattice: (ignore for now):
    read (1,*,IOSTAT = INFO) cConstituentNameSUBCS(nCSCS,2,1:nSublatticeElementsCS(nCSCS,2))
    ! Match elements on 2nd sublattice with elements in dat file order
    LOOP_Sub2Names: do k = 1, nSublatticeElementsCS(nCSCS,2)
        call ParseConstituentName(k + nSublatticeElementsCS(nCSCS,1),2)
    end do LOOP_Sub2Names

    ! Read in the charge of each constituent on the first sublattice.
    ! This seems unnecessary so I'm going to ignore it for now:
    read (1,*,IOSTAT = INFO) dSublatticeChargeCS(nCSCS,1,1:nSublatticeElementsCS(nCSCS,1))

    ! Chemical groups on sublattice 1:
    read (1,*,IOSTAT = INFO) iChemicalGroupCS(nCSCS,1,1:nSublatticeElementsCS(nCSCS,1))

    ! Read in the charge of each constituent on the second sublattice.
    ! This seems unnecessary so I'm going to ignore it for now:
    read (1,*,IOSTAT = INFO) dSublatticeChargeCS(nCSCS,2,1:nSublatticeElementsCS(nCSCS,2))

    ! Chemical groups on sublattice 2:
    read (1,*,IOSTAT = INFO) iChemicalGroupCS(nCSCS,2,1:nSublatticeElementsCS(nCSCS,2))

    ! This entry appears to represent the IDs matching constituents on the first sublattice to species:
    read (1,*,IOSTAT = INFO) iConstituentSublatticeCS(nCSCS, 1, 1:nPairs)

    ! This entry appears to represent the IDs matching constituents on the second sublattice to species:
    read (1,*,IOSTAT = INFO) iConstituentSublatticeCS(nCSCS, 2, 1:nPairs)

    ! Set up default pair IDs and coordination numbers
    ! dCoordinationNumberCS(nCSCS,1:nMaxSpeciesPhaseCS,1:4) = 6D0
    dCoordinationNumberCS(nCSCS,1:nMaxSpeciesPhaseCS,1:4) = 0D0
    do y = 1, nSublatticeElementsCS(nCSCS,2)
        LOOP_sroPairsOuter: do x = 1, nSublatticeElementsCS(nCSCS,2)
            if (x == y) then
                p = (x - 1) * (nSublatticeElementsCS(nCSCS,1) * (nSublatticeElementsCS(nCSCS,1) + 1) / 2)
            else if (x > y) then
                cycle LOOP_sroPairsOuter
            else
                p = (nSublatticeElementsCS(nCSCS,2) + (x - 1) + ((y-2)*(y-1)/2)) &
                  * (nSublatticeElementsCS(nCSCS,1) * (nSublatticeElementsCS(nCSCS,1) + 1) / 2)
            end if
            do k = 1, nSublatticeElementsCS(nCSCS,1)
                LOOP_sroPairsInner: do j = 1, nSublatticeElementsCS(nCSCS,1)
                    if (j == k) then
                        l = j
                    else if (j > k) then
                        cycle LOOP_sroPairsInner
                    else
                        l = nSublatticeElementsCS(nCSCS,1) + j + ((k-2)*(k-1)/2)
                    end if
                    iPairIDCS(nCSCS, l + p, 1) = j
                    iPairIDCS(nCSCS, l + p, 2) = k
                    iPairIDCS(nCSCS, l + p, 3) = x + nSublatticeElementsCS(nCSCS,1)
                    iPairIDCS(nCSCS, l + p, 4) = y + nSublatticeElementsCS(nCSCS,1)
                    end do LOOP_sroPairsInner
            end do
        end do LOOP_sroPairsOuter
    end do

    ! Parse the co-ordination numbers corresponding to all pairs in the phase.
    ! Note that since these lines correspond to pairs, there will always be the same number of
    ! integers and reals on a line, but the number of lines corresponds to the number of pairs.
    ! The SUBG model considers quadruplets, which is why there are four sets.
    ! Note that a quadruplet must satisfy the following constraint:
    ! q(i)/Z(i) + q(j)/Z(j) =  q(x)/Z(x) + q(y)/Z(y)
    allocate(lPairSet(nSpeciesPhaseCS(i) - nSpeciesPhaseCS(i-1)))
    lPairSet = .FALSE.
    LOOP_readPairs: do n = 1, nPairsSROCS(nCSCS,2)
        read (1,*,IOSTAT = INFO) j, k, x, y, dTempVec(1:4)
        x = x - nSublatticeElementsCS(nCSCS,1)
        y = y - nSublatticeElementsCS(nCSCS,1)
        if (x == y) then
            p = (x - 1) * (nSublatticeElementsCS(nCSCS,1) * (nSublatticeElementsCS(nCSCS,1) + 1) / 2)
        else if (x > y) then
            cycle LOOP_readPairs
        else
            p = (nSublatticeElementsCS(nCSCS,2) + (x - 1) + ((y-2)*(y-1)/2)) &
              * (nSublatticeElementsCS(nCSCS,1) * (nSublatticeElementsCS(nCSCS,1) + 1) / 2)
        end if
        if (j == k) then
            l = j
        else if (j > k) then
            cycle LOOP_readPairs
        else
            l = nSublatticeElementsCS(nCSCS,1) + j + ((k-2)*(k-1)/2)
        end if
        dCoordinationNumberCS(nCSCS, l + p, 1) = dTempVec(1)
        dCoordinationNumberCS(nCSCS, l + p, 2) = dTempVec(2)
        dCoordinationNumberCS(nCSCS, l + p, 3) = dTempVec(3)
        dCoordinationNumberCS(nCSCS, l + p, 4) = dTempVec(4)
        lPairSet(l + p) = .TRUE.
    end do LOOP_readPairs

    ! Increase pairs counter to include default pairs
    nPairsSROCS(nCSCS,2) = nSpeciesPhaseCS(i) - nSpeciesPhaseCS(i-1)

    ! This loop sets default coordination numbers for quadruplets not explicitly listed in data file
    LOOP_allSROPairs: do k = 1, nPairsSROCS(nCSCS,2)

        ! If coordinations already set, skip rest
        if (lPairSet(k)) cycle LOOP_allSROPairs

        ! Constituent indices:
        a = iPairIDCS(nCSCS,k,1)
        b = iPairIDCS(nCSCS,k,2)
        x = iPairIDCS(nCSCS,k,3) - nSublatticeElementsCS(nCSCS,1)
        y = iPairIDCS(nCSCS,k,4) - nSublatticeElementsCS(nCSCS,1)

        ! Constituent charges
        qa = dSublatticeChargeCS(nCSCS,1,a)
        qb = dSublatticeChargeCS(nCSCS,1,b)
        qx = dSublatticeChargeCS(nCSCS,2,x)
        qy = dSublatticeChargeCS(nCSCS,2,y)

        if ((a /= b) .AND. (x == y)) then
            p = (x - 1) * (nSublatticeElementsCS(nCSCS,1) * (nSublatticeElementsCS(nCSCS,1) + 1) / 2)
            za = dCoordinationNumberCS(nCSCS, p + a, 1)
            zb = dCoordinationNumberCS(nCSCS, p + b, 1)

            dCoordinationNumberCS(nCSCS, k, 1) = za
            dCoordinationNumberCS(nCSCS, k, 2) = zb
            dCoordinationNumberCS(nCSCS, k, 3) = (qx + qy) / ((qa / za) + (qb / zb))
            dCoordinationNumberCS(nCSCS, k, 4) = (qx + qy) / ((qa / za) + (qb / zb))
        else if ((a == b) .AND. (x /= y)) then
            p = (x - 1) * (nSublatticeElementsCS(nCSCS,1) * (nSublatticeElementsCS(nCSCS,1) + 1) / 2)
            zx = dCoordinationNumberCS(nCSCS, p + a, 3)
            p = (y - 1) * (nSublatticeElementsCS(nCSCS,1) * (nSublatticeElementsCS(nCSCS,1) + 1) / 2)
            zy = dCoordinationNumberCS(nCSCS, p + a, 3)

            dCoordinationNumberCS(nCSCS, k, 1) = (qa + qb) / ((qx / zx) + (qy / zy))
            dCoordinationNumberCS(nCSCS, k, 2) = (qa + qb) / ((qx / zx) + (qy / zy))
            dCoordinationNumberCS(nCSCS, k, 3) = zx
            dCoordinationNumberCS(nCSCS, k, 4) = zy
        else if ((a /= b) .AND. (x /= y)) then
            ! Indices for AA/XY and BB/XY
            p = (nSublatticeElementsCS(nCSCS,2) + (x - 1) + ((y-2)*(y-1)/2)) &
              * (nSublatticeElementsCS(nCSCS,1) * (nSublatticeElementsCS(nCSCS,1) + 1) / 2)
            iaaxy = a + p
            ibbxy = b + p
            ! Indices for AB/XX and AB/YY
            l = nSublatticeElementsCS(nCSCS,1) + a + ((b-2)*(b-1)/2)
            p = (x - 1) * (nSublatticeElementsCS(nCSCS,1) * (nSublatticeElementsCS(nCSCS,1) + 1) / 2)
            iabxx = l + p
            p = (y - 1) * (nSublatticeElementsCS(nCSCS,1) * (nSublatticeElementsCS(nCSCS,1) + 1) / 2)
            iabyy = l + p
            ! Coordinations of specific species for the above quadruplets
            za = dCoordinationNumberCS(nCSCS,iaaxy,1)
            zb = dCoordinationNumberCS(nCSCS,ibbxy,1)
            zx = dCoordinationNumberCS(nCSCS,iabxx,3)
            zy = dCoordinationNumberCS(nCSCS,iabyy,3)
            ! Equation 24 from part iv paper
            dF = (1D0/8D0)*((qa/za)+(qb/zb)+(qx/zx)+(qy/zy))
            ! Equation 23 from part iv paper
            dCoordinationNumberCS(nCSCS, k, 1) = &
                                  1D0 / (((zx/(qx*dCoordinationNumberCS(nCSCS,iabxx,1))) &
                                        + (zy/(qy*dCoordinationNumberCS(nCSCS,iabyy,1)))) * dF)
            dCoordinationNumberCS(nCSCS, k, 2) = &
                                  1D0 / (((zx/(qx*dCoordinationNumberCS(nCSCS,iabxx,2))) &
                                        + (zy/(qy*dCoordinationNumberCS(nCSCS,iabyy,2)))) * dF)
            dCoordinationNumberCS(nCSCS, k, 3) = &
                                  1D0 / (((za/(qa*dCoordinationNumberCS(nCSCS,iaaxy,3))) &
                                        + (zb/(qb*dCoordinationNumberCS(nCSCS,ibbxy,3)))) * dF)
            dCoordinationNumberCS(nCSCS, k, 4) = &
                                  1D0 / (((za/(qa*dCoordinationNumberCS(nCSCS,iaaxy,4))) &
                                        + (zb/(qb*dCoordinationNumberCS(nCSCS,ibbxy,4)))) * dF)
        end if
    end do LOOP_allSROPairs

    ! Copy previously-read end member info into appropriate variables before it gets overwritten by
    ! quadruplet data calculated below.
    cPairNameCS(nCSCS,1:nPairsSROCS(nCSCS,1)) = &
                cSpeciesNameCS((nSpeciesPhaseCS(i-1)+1):(nSpeciesPhaseCS(i-1)+nPairsSROCS(nCSCS,1)))
    dStoichSpeciesOld = dStoichSpeciesCS(1:nSpeciesCS,1:nElementsCS)
    dStoichPairsCS(nCSCS,1:nPairsSROCS(nCSCS,2),1:nElementsCS) &
                  = dStoichSpeciesCS((nSpeciesPhaseCS(i-1) + 1):nSpeciesPhaseCS(i),1:nElementsCS)
    dStoichSpeciesCS((nSpeciesPhaseCS(i-1) + 1):nSpeciesPhaseCS(i),1:nElementsCS) = 0D0

    ! Loop through all pairs to calculate stoichiometry entries for quadruplets:
    do j = 1, nPairsSROCS(nCSCS,2)
        a = iPairIDCS(nCSCS, j, 1)
        b = iPairIDCS(nCSCS, j, 2)
        x = iPairIDCS(nCSCS, j, 3)
        y = iPairIDCS(nCSCS, j, 4)

        l = j + nSpeciesPhaseCS(i-1)

        do k = 1, nElementsCS
            dStoichSpeciesCS(l,k) = dStoichSpeciesCS(l,k) + (dStoichConstituentCS(a,k) / dCoordinationNumberCS(nCSCS, j, 1))
            dStoichSpeciesCS(l,k) = dStoichSpeciesCS(l,k) + (dStoichConstituentCS(b,k) / dCoordinationNumberCS(nCSCS, j, 2))
            dStoichSpeciesCS(l,k) = dStoichSpeciesCS(l,k) + (dStoichConstituentCS(x,k) / dCoordinationNumberCS(nCSCS, j, 3))
            dStoichSpeciesCS(l,k) = dStoichSpeciesCS(l,k) + (dStoichConstituentCS(y,k) / dCoordinationNumberCS(nCSCS, j, 4))
        end do

        ! Create quadruplet names
        cSpeciesNameCS(l) = TRIM(cConstituentNameSUBCS(nCSCS,1,a)) // '-' &
                         // TRIM(cConstituentNameSUBCS(nCSCS,1,b)) // '-' &
                         // TRIM(cConstituentNameSUBCS(nCSCS,2,x - nSublatticeElementsCS(nCSCS,1))) // '-' &
                         // TRIM(cConstituentNameSUBCS(nCSCS,2,y - nSublatticeElementsCS(nCSCS,1)))

    end do

    ! Loop through excess mixing parameters:
    j = 0
    LOOP_ExcessMixingSUBG: do
        j = j + 1
        ! Read in number of constituents involved in parameter:
        read (1,*,IOSTAT = INFO) iRegularParamCS(nParamCS+1,1)

        ! The end of the parameter listing is marked by "0":
        ! or a negative number indicating the number of extra parameter lines
        if (iRegularParamCS(nParamCS+1,1) <= 0) then
            do k = 1, -iRegularParamCS(nParamCS+1,1)
                read (1,*,IOSTAT = INFO) cTempVec(1:10)
            end do
            exit LOOP_ExcessMixingSUBG
        end if

        ! Check if the parameter is binary or ternary:
        if ((iRegularParamCS(nParamCS+1,1) == 3) .OR. (iRegularParamCS(nParamCS+1,1) == 4)) then

            ! Count the number of parameters:
            nParamCS = nParamCS + 1

            ! Mixing terms:
            read (1,*,IOSTAT = INFO) cRegularParamCS(nParamCS), iRegularParamCS(nParamCS,2:9)
            if (.NOT.((cRegularParamCS(nParamCS) == 'G') &
                .OR. (cRegularParamCS(nParamCS) == 'Q') .OR. (cRegularParamCS(nParamCS) == 'R') &
                 .OR. (cRegularParamCS(nParamCS) == 'B'))) then
                INFO = 10000 + 1000*j + i
                return
            end if

            ! According to Patrice Chartrand, he has no idea what these two lines mean. Ignore.
            read (1,*,IOSTAT = INFO) dTempVec(1:6)
            read (1,*,IOSTAT = INFO) dTempVec(1:6)

            ! Read in the excess gibbs energy of mixing terms.
            read (1,*,IOSTAT = INFO) iRegularParamCS(nParamCS,10:11), dRegularParamCS(nParamCS,1:6)

        else
            !! This parameter is not recognized; record an error.
            INFO = 10000 + 1000*j + i
            return
        end if

    end do LOOP_ExcessMixingSUBG

    ! Report an error if necessary:
    if (INFO /= 0) INFO = 1600 + i

    deallocate(lPairSet,dStoichConstituentCS)

    return

end subroutine ParseCSDataBlockSUBG

subroutine ParseConstituentName(k, iSub)
    USE ModuleParseCS

    implicit none

    integer                     :: j, k, iSub, nCSCS, iFirstCapital, iCurrent, iElement, iTemp, iNumber
    integer, dimension(26)      :: iCapital
    character(8)                :: cConstituentName
    character(1),dimension(26)  :: capitalLetters, lowerLetters
    character(1),dimension(10)  :: numbers
    logical                     :: nextIsLower

    nCSCS = nCountSublatticeCS
    cConstituentName = cConstituentNameSUBCS(nCSCS,iSub,k - nSublatticeElementsCS(nCSCS,1)*(iSub-1))

    ! First do the default (sensible) cases, then move on to the madness
    if (cConstituentName == 'Va') then
        return
    end if
    do j = 1, nElementsCS
        if (cConstituentName == cElementNameCS(j)) then
            dStoichConstituentCS(k,j) = 1D0
            return
        end if
    end do

    ! Now for the madness... to handle compound constituents it looks like I have to parse the text...

    ! I honestly can't believe it has come to this
    capitalLetters = (/'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z'/)
    lowerLetters =   (/'a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','e','s','r','u','v','w','x','y','z'/)
    numbers = (/'1','2','3','4','5','6','7','8','9','0'/)

    iCurrent = 0

    ! This block of code is so bad
    ! that we might as well just meme it at this point
    do while (.TRUE.)
        iCurrent = iCurrent + 1

        do j = 1, 26
            iCapital(j) = INDEX(cConstituentName(iCurrent:),capitalLetters(j))
            if (iCapital(j) == 0) iCapital(j) = 100
        end do

        iFirstCapital = MINVAL(iCapital)
        iCurrent = iCurrent + iFirstCapital - 1

        if (iFirstCapital == 100) then
            ! print *, 'Cannot parse constituent ', TRIM(cConstituentName), ' in solution phase ', cSolnPhaseNameCS(i)
            ! INFO = 1600 + i
            return
        end if

        nextIsLower = .FALSE.
        iTemp = 0
        do j = 1, 26
            if (cConstituentName(iCurrent+1:iCurrent+1) == lowerLetters(j)) then
                iTemp = 1
                nextIsLower = .TRUE.
            end if
        end do

        do j = 1, nElementsCS
            if (cConstituentName(iCurrent:iCurrent+iTemp) == cElementNameCS(j)) then
                iElement = j
            end if
        end do

        iNumber = 1
        do j = 1, 9
            if (cConstituentName(iCurrent+iTemp+1:iCurrent+iTemp+1) == numbers(j)) then
                iNumber = j
            end if
        end do

        if (iNumber > 1) then
            if ((cConstituentName(iCurrent+iTemp+2:iCurrent+iTemp+2) == '+') &
           .OR. (cConstituentName(iCurrent+iTemp+2:iCurrent+iTemp+2) == '-')) then
                iNumber = 1
            end if
        end if

        if (iElement > 0) dStoichConstituentCS(k,iElement) = dStoichConstituentCS(k,iElement) + iNumber * 1D0

    end do

    return

end subroutine ParseConstituentName
