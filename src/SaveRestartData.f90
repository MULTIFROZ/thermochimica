
    !-------------------------------------------------------------------------------------------------------------
    !
    !> \file    SaveRestartData.f90
    !> \brief   Save data for restarting calculation from previous results.
    !> \author  M. Poschmann
    !> \sa      LoadRestartData.f90
    !
    !
    ! References:
    ! ===========
    !
    ! Revisions:
    ! ==========
    !   Date            Programmer          Description of change
    !   ----            ----------          ---------------------
    !   30/11/2018      M. Poschmann         Create file.
    !
    !
    ! Purpose:
    ! ========
    !> \details The purpose of this subroutine is to save all pertinent data such that a new call to Thermochimica
    !! may be restarted from that data.
    !
    ! Pertinent variables:
    ! ====================
    !> \param   lRestart        A logical indicating whether restart data is available.
    !
    !-------------------------------------------------------------------------------------------------------------


subroutine SaveRestartData

  USE ModuleThermo
  USE ModuleRestart
  USE ModuleThermoIO

  implicit none

  ! Initialize storage variables if not allocated already
  if (.NOT. lRestartAvailable) then
    allocate(dElementPotential_Old(nElements))
  endif

  ! Save old chemical potential data
  dElementPotential_Old   = dElementPotential

  ! Set restart data flag to true
  lRestartAvailable = .TRUE.
  return

end subroutine SaveRestartData
