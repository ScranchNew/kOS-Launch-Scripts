// Launches to test
@LAZYGLOBAL OFF.

{
    cd("1:launch").
    runoncepath("../libraries/LaunchLib").
    runoncepath("../libraries/DeltaVLib").
    runoncepath("../libraries/DockLib").
    cd("1:").
    s_Mission("Make Orbit 1000x1000").

    p_Slow_Rendevouz(0,-120).

    //LOCAL targ_obt TO c_Obt_From_Mission(491085, 391978, 186, 330.9, 85.8, MUN).

    Quit().
}