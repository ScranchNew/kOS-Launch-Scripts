// Launches to test
@LAZYGLOBAL OFF.

IF ship:status = "PRELAUNCH"
{
    runoncepath("libraries/LaunchLib").
    runoncepath("libraries/DeltaVLib").
    runoncepath("libraries/DockLib").
    s_Mission("Launch to rendevouz").
    p_Launch_To_Rendevouz().
    p_Direct_Rendevouz().
    p_Close_Dist().
    Quit().
}