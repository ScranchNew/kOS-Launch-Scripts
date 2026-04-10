// Launches to test
@LAZYGLOBAL OFF.

{
    cd("1:libraries").
    runoncepath("../libraries/0_LogLib").
    runoncepath("../libraries/1_DeltaVLib").
    runoncepath("../libraries/2_LaunchLib").
    runoncepath("../libraries/3_DockLib").
    runoncepath("../libraries/4_RendevouzLib").
    runoncepath("../libraries/5_InterBodyLib").
    cd("1:").
    
    s_Mission("Rendevouz with mission orbit").

    LOCAL targ_moon TO MINMUS.

    LOCAL targ_obt TO c_Obt_From_Mission(498413, 51323,135.2,306,102.9, targ_moon).

    p_Launch_To_Rendevouz(targ_moon).
    p_Direct_Rendevouz(targ_moon).
    p_Insertion(50000, 50000, 0, targ_obt).
    p_Slow_Rendevouz(targ_obt).

    Quit().
}