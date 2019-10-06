// The most basic script to launch into an orbit
@LAZYGLOBAL OFF.

LOCAL Ap TO 100 * 1000. // The desired apoapsis in [m].
LOCAL Pe TO Ap.         // The desired periapsis
LOCAL Inc TO 0.         // The orbital inclination in [°]


IF ship:status = "PRELAUNCH"
{
    // These are used to load the necessary libraries if not already loaded from "boot/default.ks"
    runoncepath("libraries/LaunchLib").
    runoncepath("libraries/DeltaVLib").

    // Set the mission name
    s_Mission("Launch to " + round((Ap + Pe)/2000) + " km").
    // Launch to an orbit with the given parameters
    p_Launch(Ap, Pe, Inc).
    // Leave the vessel in a safe position and wait for manual exit of the program.
    // Tapping the brakes will exit
    Quit().
}