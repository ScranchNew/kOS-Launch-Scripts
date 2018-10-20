// Launches to test
@LAZYGLOBAL OFF.

IF ship:status = "PRELAUNCH"
{
    runoncepath("libraries/LaunchLib").
    runoncepath("libraries/DeltaVLib").
    s_Mission("Launch to 150 km").
    p_Launch(150000).
    Quit().
}