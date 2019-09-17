// Launches to test
@LAZYGLOBAL OFF.

LOCAL Ap TO 150 * 1000.
LOCAL Pe TO Ap.
LOCAL Inc TO 0.


IF ship:status = "PRELAUNCH"
{
    runoncepath("libraries/LaunchLib").
    runoncepath("libraries/DeltaVLib").
    s_Mission("Launch to " + round((Ap + Pe)/2000) + " km").
    p_Launch(Ap, Pe, Inc).
    Quit().
}