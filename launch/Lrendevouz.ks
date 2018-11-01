// Launches to test
@LAZYGLOBAL OFF.

IF ship:status = "PRELAUNCH"
{
    runoncepath("libraries/LaunchLib").
    runoncepath("libraries/DeltaVLib").
    runoncepath("libraries/DockLib").
    s_Mission("Launch to rendevouz").
    p_Launch().
    p_Direct_Rendevouz().
    p_Close_Dist().
    p_Dock().
    Quit().
}