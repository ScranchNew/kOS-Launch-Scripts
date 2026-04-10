@LAZYGLOBAL OFF.

// Loads all libraries from the archive to the ship
// If compiler is set to True they will be compiled first to save storage space
// If startProgram is set to True it will promt you to start a script from 0:/launch
// It will then load and execute the given script.

DECLARE Parameter compiler TO True, startProgram TO True.

WAIT 1.

// If there is RemoteTech intregration it will check for a connection first
LOCAL RT TO True.
IF ADDONS:RT:AVAILABLE {
    GLOBAL Remote TO ADDONS:RT.
    SET RT TO Remote:HASCONNECTION(SHIP).
}

IF RT OR SHIP:STATUS = "PRELAUNCH"
{
    // Compile ks file (so the ksm version can be run as bootloader).
    CD("0:/boot").
    COMPILE("Default.ks").
    COPYPATH("0:/boot/Default.ksm", "1:/boot/").
    PRINT "Compiled Bootloader".

    // Copy the libraries
    copyLibs().

    // Prompt for a launchfile
    IF startProgram {
        // Print all available launchfiles
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

            // Gets your input
            UNTIL retPress
            {
                LOCAL nxtchar TO Terminal:Input:GetChar().
                IF nxtchar <> Terminal:Input:Return
                {
                    IF nxtchar = Terminal:Input:Backspace {
                        SET inputstring TO inputstring:substring(0,inputstring:length - 1).
                    } ELSE {
                        SET inputstring TO inputstring + nxtchar.
                    }
                    Print inputstring:padright(20):substring(0,20) AT (21, 0).
                } ELSE {
                    SET retPress TO True.
                }
            }
            // Checks your input
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
        // Compiles and starts the selected file
        LOCAL fName TO filelist[fileNum]:tostring.
        SET fName TO fName:substring(0, fName:find("ks") - 1).
        CD("0:/launch").
        IF compiler {
            COMPILE (fName + ".ks").
        }
        IF EXISTS("1:/launch"){
            DELETEPATH("1:/launch").
        }
        CREATEDIR("1:/launch").
        IF compiler {
            COPYPATH(fName + ".ksm", "1:/launch/").
            DELETEPATH(fName + ".ksm").
        } ELSE {
            COPYPATH(fName + ".ks", "1:/launch/").
        }
        CD("1:/").
        RUNPATH("1:/launch/" + fName).
    }
} ELSE {
    PRINT "ERROR: No Connection".
}

function copyLibs{
// Compiles and copies libraries from "Archive/libraries" to "1:/libraries"PR
// It is important that you keep your libraries in an uncompiled form or ELSE this script might fuck up

// Libs: {filename: [isCompiled, .ks-file, .ksm-file]}

    LOCAL minspace TO 1500.

    LOCAL proc TO list().
    LIST PROCESSORS in proc.

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
                BREAK.
                // SET fname TO kFile:tostring:REMOVE(fname-4,4).
                // SET isCompiled TO True.
            } ELSE {
                SET fname TO kFile:tostring:REMOVE(fname-3,3).
                PRINT "Found file:" + fname.
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
    IF EXISTS("1:/launch"){
        DELETEPATH("1:/1:/launch").
    }
    LOCAL procspace TO proc[0]:volume:freespace.
    CREATEDIR("1:/libraries").
    FOR name in libs:KEYS
    {
        LOCAL fname TO "".
        LOCAL del TO False.
        IF compiler {
            IF libs[name][0] = False {
                COMPILE libs[name][1].
                SET libs[name][0] TO True.
                SET libs[name][2] TO name + ".ksm".
                SET fname TO libs[name][2].
                SET del TO True.
            } ELSE {
                SET fname TO libs[name][2].
            }
        } ELSE {
            SET fname TO libs[name][1].
        }
        LOCAL fsize TO open(fname):size.

        IF procspace - fsize > minspace {
            SET procspace TO procspace - fsize.
            COPYPATH(fname, "1:/libraries/").
            PRINT "Copied file:" + fname.
            IF del {DELETEPATH(fname).}
        } ELSE {
            IF del {DELETEPATH(fname).}
            PRINT "Ran out of space at: " + fname.
            BREAK.
        }
    }
    
    PRINT("Finished loading libraries").
    CD("0:/").
    COMPILE("runF.ks").
    COPYPATH("runF","1:/").
    DELETEPATH("runF.ksm").
    CD("1:/").
    PRINT("Loaded runf").
}