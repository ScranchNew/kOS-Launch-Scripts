// Launches to test
@LAZYGLOBAL OFF.

IF ship:status = "PRELAUNCH"
{
    runoncepath("libraries/LaunchLib").
    runoncepath("libraries/DeltaVLib").
    s_Mission("Launch to 200 by 200 km").
    p_Launch(200000, 200000, 25).
    Quit().
}