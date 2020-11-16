// Launches to test
@LAZYGLOBAL OFF.

{
    runoncepath("libraries/LaunchLib").
    runoncepath("libraries/DeltaVLib").
    runoncepath("libraries/DockLib").
    s_Mission("To Minmus at 300km").
    p_Launch().
    p_Direct_Rendevouz(Minmus).
    p_Insertion(300000).
    Quit().
}