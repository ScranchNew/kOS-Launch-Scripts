// Launches to test
@LAZYGLOBAL OFF.

IF ship:status = "PRELAUNCH"
{
    cd("1:libraries").
    runoncepath("../libraries/0_LogLib").
    runoncepath("../libraries/1_DeltaVLib").
    runoncepath("../libraries/2_LaunchLib").
    runoncepath("../libraries/3_DockLib").
    cd("1:").
    
    s_Mission("Launch to rendevouz").
    p_Launch_To_Rendevouz().
    p_Slow_Rendevouz().
    p_Close_Dist().
    Quit().
}