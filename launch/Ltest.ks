// Launches to test
@LAZYGLOBAL OFF.

{
    runoncepath("libraries/LaunchLib").
    runoncepath("libraries/DeltaVLib").
    runoncepath("libraries/DockLib").
    LOCAL testList TO list().
    LIST bodies in testList.
    LOCAL char TO s_choose_from_list("Character",testList).
    s_Log(char).
    Quit().
}