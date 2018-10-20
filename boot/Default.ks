@LAZYGLOBAL OFF.

DECLARE Parameter compiler TO True, startProgram TO True.

IF ADDONS:RT:AVAILABLE {
    GLOBAL Remote TO ADDONS:RT.
    IF Remote:HASCONNECTION(SHIP) OR SHIP:STATUS = "PRELAUNCH"
    {
        copyLibs().
        IF startProgram {
            CLEARSCREEN.
            PRINT "Choose a launchfile: ".
            PRINT " ".
            LOCAL filelist TO list().
            CD("0:/launch").
            LIST FILES in filelist.
            CD("1:/").
            PRINT filelist.
            PRINT "":padright(30) AT (0, 2).
            LOCAL inputstring TO "".
            LOCAL correctInput TO False.
            LOCAL fileNum TO -1.
            Terminal:Input:CLEAR.
            UNTIL correctInput
            {
                LOCAL retPress TO False.
                UNTIL retPress
                {
                    LOCAL char TO Terminal:Input:GetChar().
                    if char <> Terminal:Input:Return
                    {
                        if char = Terminal:Input:Backspace {
                            SET inputstring TO inputstring:substring(0,inputstring:length - 1).
                        } ELSE {
                            SET inputstring TO inputstring + char.
                        }
                        Print inputstring:padright(20):substring(0,20) AT (21, 0).
                    } ELSE {
                        SET retPress TO True.
                    }
                }
                SET fileNum TO inputstring:TONUMBER(-1).
                IF fileNum >= filelist:length OR fileNum < 0
                {
                    PRINT "Input not usable. Try again." AT (1,1).
                    SET inputstring TO "".
                    Print inputstring:padright(20):substring(0,20) AT (21, 0).
                } ELSE {
                    SET fileNum TO floor(fileNum).
                    SET correctInput TO True.
                }
            }
            LOCAL fName TO filelist[fileNum]:tostring.
            SET fName TO fName:substring(0, fName:find("ks") - 1).
            CD("0:/launch").
            COMPILE (fName + ".ks").
            COPYPATH(fName + ".ksm", "1:/").
            DELETEPATH(fName + ".ksm").
            CD("1:/").
            RUNPATH(fName).
        }
        
    }
}

function copyLibs{
// Compiles and copies libraries from "Archive/libraries" to "1:/"

    CD("0:/libraries").
    LOCAL libs TO lexicon().
    LOCAL filelist TO list().
    LIST FILES IN filelist.
    FOR kFile IN filelist
    {
        IF kFile:typename = "VolumeFile"
        {
            LOCAL fname TO kFile:tostring:length.
            LOCAL isCompiled TO False.

            IF kFile:tostring:contains(".ksm"){
                SET fname TO kFile:tostring:REMOVE(fname-4,4).
                SET isCompiled TO True.
            } ELSE {
                SET fname TO kFile:tostring:REMOVE(fname-3,3).
            }
            IF libs:haskey(fname) = False {
                SET libs[fname] TO list(False, "", "").
            }
            IF isCompiled {
                SET libs[fname][0] to True.
                SET libs[fname][2] to kFile:tostring.
            } ELSE {
                SET libs[fname][1] to kFile:tostring.
            }
        }
    }
    
    IF EXISTS("1:/libraries"){
        DELETEPATH("1:/libraries").
    }
    CREATEDIR("1:/libraries").
    FOR name in libs:KEYS
    {
        COMPILE libs[name][1].
        IF libs[name][0] = False {
            SET libs[name][0] TO True.
            SET libs[name][2] TO name + ".ksm".
        }
        IF compiler {
            COPYPATH(libs[name][2], "1:/libraries/").
        } ELSE {
            COPYPATH(libs[name][1], "1:/libraries/").
        }
        DELETEPATH(libs[name][2]).
    }
    CD("0:/").
    COMPILE("runF.ks").
    COPYPATH("runF","1:/").
    DELETEPATH("runF.ksm").
    CD("1:/").
}