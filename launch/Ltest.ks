// Launches to test
@LAZYGLOBAL OFF.

{
    runoncepath("libraries/LaunchLib").
    runoncepath("libraries/DeltaVLib").
    runoncepath("libraries/DockLib").
    p_orb_burn(c_inc_change(0)).
    Quit().
}