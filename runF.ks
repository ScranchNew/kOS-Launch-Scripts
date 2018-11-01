// library of kOS functions

@LAZYGLOBAL OFF.

DECLARE Parameter function, pars TO "".

cd("libraries").

LOCAL libs TO list().
LIST FILES IN libs.

cd("..").

LOG "nope" TO "tempRun.ks".
DELETEPATH("tempRun.ks").

LOG "cd("  + char(34) + "libraries"  + char(34) + ")." TO "tempRun.ks".
FOR lib IN libs{
    LOG "RUNONCEPATH("  + char(34) + lib:tostring + char(34) + ")." TO "tempRun.ks".
}
LOG "cd("  + char(34) + ".."  + char(34) + ")." TO "tempRun.ks".

LOG "print " + function:tostring + "(" + pars + ")." TO "tempRun.ks".

RUNPATH("tempRun.ks").
DELETEPATH("tempRun.ks").