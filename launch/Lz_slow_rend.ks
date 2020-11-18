// Launches to test
@LAZYGLOBAL OFF.

IF ship:status = "PRELAUNCH"
{
    cd("1:launch").
    runoncepath("../libraries/LaunchLib").
    runoncepath("../libraries/DeltaVLib").
    runoncepath("../libraries/DockLib").
    cd("1:").
    
    s_Mission("Launch to rendevouz").
    p_Launch_To_Rendevouz().
    p_Slow_Rendevouz().
    p_Close_Dist().
    Quit().
}