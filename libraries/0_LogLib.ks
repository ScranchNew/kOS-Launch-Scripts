// library of kOS functions for printing mission info to the console

@LAZYGLOBAL OFF.

// ________________________________________________________________________________________________________________
// s:[Screen] Everything for printing information to the screen.
// ________________________________________________________________________________________________________________

GLOBAL LogLib_Loaded TO True.
s_Layout().

function s_Layout {
// Fills the screen with a layout for displaying the mission status
// Use the s_... functions (e.g.: s_Log() or s_Info_push()) to push Information to the layout
    DECLARE Parameter NewData TO lexicon("clear", True).
        // NewData: lexicon with "where to write":"what to write"

    IF (DEFINED layoutDone) = False OR (NewData:haskey("clear") AND NewData["clear"]) OR (NewData:haskey("reset") AND NewData["reset"])
    {

        GLOBAL layoutDone TO True.          // make sure the declarations are only run once

        // around 20 chars are taken up by the clock each line
        GLOBAL Logl TO 2.					// Line for mission log
        GLOBAL Logw TO 70.                  // Linelength for mission log

        GLOBAL Ic TO 90.					// Info-column (name; e.g "Inclination.:")
        GLOBAL Ic2 TO Ic+15.				// Info-column (value; e.g "46°")
        GLOBAL Il TO 13.					// 1. line of info-area
        GLOBAL Mil TO 2.					// Line for mission-name
        GLOBAL Spl TO 5.					// Line for subprogram-name
        GLOBAL Stl TO 8.					// Line for subprogram-status

        IF (DEFINED mLog) = False OR (NewData:haskey("reset") AND NewData["reset"]) {
            GLOBAL mLog TO LIST().              // All lines logged
            GLOBAL mLogL TO 0.                  // The log line, that was last printed
            GLOBAL mMission TO "".              // The mission name
            GLOBAL mSubProg TO "".              // The subprogram name
            GLOBAL mStatus TO "".               // The program status
            GLOBAL mStage TO "".                // The current stage
            GLOBAL mInfo TO stack().            // The display information stack
            GLOBAL mInfoOff TO 0.               // The offset of the working information package on top of the stack
        }
        CLEARSCREEN.
        SET TERMINAL:HEIGHT TO 40.
        SET TERMINAL:WIDTH TO 120.
        SET TERMINAL:CHARHEIGHT TO 12.

        PRINT "Mission Log:" AT (0,0).
        PRINT "Mission:" AT (Ic-1,Mil-1).
        PRINT "Subprogram:" AT (Ic-1,Spl-1).
        PRINT "Status:" AT (Ic-1,Stl-1).
        PRINT "Stage:" AT (Ic,Il-2).
        PRINT "Info:" AT (Ic-1,Il-3).
    }

    IF NewData:istype("lexicon")
    {
        FOR key IN NewData:Keys
        {
            IF key = "Log" {            // Log a string at the current time by passing a string or a LIST of strings.
                LOCAL sTime TO TIME - MISSIONTIME.
                LOCAL mTime TO TIME - sTime:SECONDS.
                IF NewData[key]:istype("LIST")
                {
                    FOR line IN NewData[key]
                    {
                        mLog:ADD(LIST(mTime, line:TOSTRING)).
                    }
                } ELSE {
                    mLog:ADD(LIST(mTime, NewData[key]:TOSTRING)).
                }
                s_Print_Log().
            }
            ELSE IF key = "Mission" {   // Change the mission name string
                SET mMission TO NewData[key]:TOSTRING.
            }
            ELSE IF key = "Subprogram" {// Change the subprogram name string
                SET mSubProg TO NewData[key]:TOSTRING.
            }
            ELSE IF key = "Status" OR key = "State" {// Change the program state string
                SET mStatus TO NewData[key]:TOSTRING.
            }
            ELSE IF key = "Stage" {     // Change the stage infostring
                SET mStage TO NewData[key]:TOSTRING.
            }
            IF key = "Mission" OR key = "Subprogram" OR key = "Status" OR key = "State" OR key = "Stage" { // Prints Mission-changes
                s_Print_Mission().
            }
            ELSE IF key = "Info" {      // pushes a new info block or updates/removes the current info block
                LOCAL iType TO NewData[key]["Type"].

                // Pushes new information to the top of the infostack
                IF iType = "Push" AND NewData[key]["Info"]:LENGTH > 0
                {
                    IF mInfo:LENGTH > 0 {
                        SET mInfoOff TO mInfoOff + 1 + mInfo:PEEK():LENGTH.
                    }
                    mInfo:PUSH(NewData[key]["Info"]).
                }

                // Refreshes the information on top of the infostack
                ELSE IF iType = "Refresh" AND NewData[key]["Info"]:LENGTH > 0 AND mInfo:LENGTH > 0
                {
                    LOCAL Data TO mInfo:POP().
                    IF Data:LENGTH > NewData[key]["Info"]:LENGTH {
                        SET Data TO Data:SUBLIST(0, NewData[key]["Info"]:LENGTH).
                    }
                    FOR i IN RANGE(NewData[key]["Info"]:LENGTH) {
                        LOCAL NewInf TO NewData[key]["Info"][i].
                        IF i < Data:LENGTH {
                            IF NewInf[0] = "" {
                                SET Data[i][1] TO NewInf[1].
                            } ELSE {
                                SET Data[i] TO NewInf.
                            }
                        } ELSE {
                            Data:ADD(NewInf).
                        }
                    }
                    mInfo:PUSH(Data).
                }

                // Removes the information on top of the infostack
                ELSE IF iType = "Pop" 
                {
                    IF mInfo:LENGTH > 0 {
                        LOCAL Trash TO mInfo:POP().
                        LOCAL lCount TO 0.
                        FOR line in Trash {
                            PRINT "":PADRIGHT(14) AT (Ic ,Il + mInfoOff + lCount).
                            PRINT "":PADRIGHT(14) AT (Ic2,Il + mInfoOff + lCount).
                            SET lCount TO lCount + 1.
                        }
                        IF mInfo:LENGTH > 0 {
                            SET mInfoOff TO mInfoOff - 1 - mInfo:PEEK():LENGTH.
                        }
                    }
                }

                // Actually prints the information on top of the infostack
                IF iType = "Push" OR iType = "Refresh" AND mInfo:LENGTH > 0{
                    s_Print_Info().
                }
            } ELSE {RETURN False.}
        }
    } ELSE {RETURN False.}
    RETURN True.
}

function s_Print_Log {
//Prints the newest line in the mission log or reprints the whole thing
    DECLARE Parameter reprint TO False.

    IF (DEFINED layoutDone) = False 
    {
        s_Layout().
    }

    IF mLog:LENGTH < TERMINAL:HEIGHT - Logl - 1 AND (reprint = False) {
        UNTIL mLogL >= mLog:LENGTH {
            PRINT (s_TimeString(mLog[mLogL][0]) + mLog[mLogL][1]:TOSTRING:PADRIGHT(Logw):SUBSTRING(0,Logw)) AT (1,Logl + mLogL).
            SET mLogL TO mLogL + 1.
        }
    } ELSE {    //Reprints the whole log, only showing the part, that fits on screen (scrolled to the end)
        LOCAL maxLogHeight TO TERMINAL:HEIGHT - Logl - 1.
        LOCAL LogOff TO 0.
        FOR i IN RANGE(MAX(mLog:LENGTH - maxLogHeight, 0), mLog:LENGTH) {
            PRINT (s_TimeString(mLog[i][0]) + mLog[i][1]:TOSTRING:PADRIGHT(Logw):SUBSTRING(0,Logw)) AT (1,Logl + LogOff).
            SET LogOff TO LogOff + 1.
        }
    }
}

function s_SecondsToTime {
//Takes in a number of seconds and returns the timestamp that many seconds after 0
//Only way to use :clock with a time intervall due to stupid API restrictions
    DECLARE Parameter n_seconds.
    RETURN TIME - (TIME - n_seconds):SECONDS.
}

function s_TimeString {
//Takes a TimeStamp and returns a nicely formatted string of it in y.d | hh:mm:ss
    DECLARE Parameter tstamp TO MISSIONTIME.
    SET tstamp TO s_SecondsToTime(tstamp).
    RETURN ((tstamp:year) + "." + (tstamp:day) + "|" + tstamp:CLOCK):PADRIGHT(15).
}

function s_Logspace_Clear {
//Prints empty lines in the Log-space. Useful IF you want to use that space for a temporary UI
    FOR i IN RANGE(0,TERMINAL:HEIGHT - Logl - 1) {
        PRINT "":PADRIGHT(45) AT (1, Logl + i).
    }
}

function s_Choose_from_List {
// lets you choose an item from a LIST using the console
    DECLARE Parameter name, itemList.

    s_Logspace_Clear().
    PRINT "Choose one " + name + " from the LIST:" AT (1, Logl).
    PRINT "Your choice: " AT (1, Logl + 2).

    LOCAL inputstring TO "".
    LOCAL correctInput TO False.
    LOCAL choiceNum TO -1.                          // chosen item
    LOCAL topItem TO 0.                             // item at top of the screen
    LOCAL listSpace TO TERMINAL:HEIGHT - Logl - 9.  // Items shown at once

    PRINT "Up 1: [up-key]     | Up 1 page: [page-up]    " AT (1, Logl + 5).
    PRINT "_____________________________________________" AT (1, Logl + 6).
    PRINT "_____________________________________________" AT (1, TERMINAL:HEIGHT - 3).
    PRINT "Down 1: [down-key] | Down 1 page: [page-down]" AT (1, TERMINAL:HEIGHT - 2).

    LOCAL pLine TO LogL + 7.
    FOR item IN RANGE(topItem, MIN(listSpace, itemList:LENGTH)) 
    {
        PRINT "[" + item + "] :" AT (1,pLine).
        PRINT itemList[item]:TOSTRING:padright(35):substring(0,35) AT (10,pLine).
        SET pLine TO pLine + 1.
    }

    TERMINAL:Input:CLEAR().
    UNTIL correctInput
    {
        LOCAL retPress TO False.
        UNTIL retPress
        {
            LOCAL nxtchar TO TERMINAL:Input:GetChar().
            IF nxtchar <> TERMINAL:Input:Return
            {
                LOCAL moved TO False.
                IF nxtchar = TERMINAL:Input:Backspace AND inputString:LENGTH > 0      // Backspace
                {
                    SET inputString TO inputString:substring(0,inputString:length - 1).
                } ELSE IF "0123456789":CONTAINS(nxtchar)           // Number
                {
                    SET inputString TO inputString + nxtchar.
                } ELSE IF nxtchar = TERMINAL:Input:UPCURSORONE     // Directions
                {
                    SET topItem TO MAX(0, topItem - 1).
                    SET moved TO True.
                } ELSE IF nxtchar = TERMINAL:Input:DOWNCURSORONE
                {
                    SET topItem TO MIN(topItem + 1, MAX(0,  itemList:LENGTH-listSpace)).
                    SET moved TO True.
                } ELSE IF nxtchar = TERMINAL:Input:PAGEUPCURSOR
                {
                    SET topItem TO MAX(0, topItem - listSpace).
                    SET moved TO True.
                } ELSE IF nxtchar = TERMINAL:Input:PAGEDOWNCURSOR
                {
                    SET topItem TO MIN(topItem + listSpace, MAX(0,  itemList:LENGTH-listSpace)).
                    SET moved TO True.
                }
                IF moved {
                    LOCAL pLine TO LogL + 7.
                    FOR item IN RANGE(topItem, MIN(listSpace, itemList:LENGTH)) 
                    {
                        PRINT "[" + item + "]" AT (1,pLine).
                        PRINT itemList[item]:TOSTRING:padright(20):substring(0,20) AT (7,pLine).
                        SET pLine TO pLine + 1.
                    }
                }
                Print inputString:padright(20):substring(0,20) AT (10, Logl + 1).
                LOCAL inputNum TO inputString:TONUMBER(-1).
                IF inputNum < itemList:length AND inputNum >= 0 {
                    PRINT itemList[floor(inputNum)]:TOSTRING:padright(35):substring(0,35) AT (10, Logl + 3).
                } ELSE {
                    PRINT "":padright(35):substring(0,35) AT (10, Logl + 3).
                }
            } ELSE {
                SET retPress TO True.
            }
        }
        SET choiceNum TO inputString:TONUMBER(-1).
        IF choiceNum >= itemList:length OR choiceNum < 0
        {
            PRINT "":padright(20):substring(0,20) AT (10, Logl + 3).
            SET inputString TO "".
            Print inputString:padright(20):substring(0,20) AT (10, Logl + 1).
        } ELSE {
            SET choiceNum TO floor(choiceNum).
            SET correctInput TO True.
        }
    }
    s_Logspace_Clear().
    s_Print_Log(True).
    Return choiceNum.
}

function s_Print_Mission {
//Reprints all the mission info (Mission name, Subprogram name, Status, Stage)
    IF (DEFINED layoutDone) = False 
    {
        s_Layout().
    }
    PRINT mMission:PADRIGHT(29):SUBSTRING(0,29) AT (Ic, Mil).
    PRINT mSubProg:PADRIGHT(29):SUBSTRING(0,29) AT (Ic, Spl).
    PRINT mStatus:PADRIGHT(29):SUBSTRING(0,29) AT (Ic, Stl).
    PRINT mStage:PADRIGHT(14):SUBSTRING(0,14) AT (Ic2,Il-2).
}

function s_Print_Info {
//Prints the newly changed info or the whole info-stack
    DECLARE Parameter reprint TO False.

    IF reprint {
        LOCAL reverseInfo TO stack().
        UNTIL mInfo:LENGTH = 0 {    // Deletes all info from the stack and stores it.
            reverseInfo:PUSH(mInfo:POP()).
            LOCAL lCount TO 0.
            FOR line in Trash {
                PRINT "":PADRIGHT(14) AT (Ic ,Il + mInfoOff + lCount).
                PRINT "":PADRIGHT(14) AT (Ic2,Il + mInfoOff + lCount).
                SET lCount TO lCount + 1.
            }
            IF mInfo:LENGTH > 0 {
                SET mInfoOff TO mInfoOff - 1 - mInfo:PEEK():LENGTH.
            }
        }

        UNTIL reverseInfo:LENGTH = 0 {  // Pushes it back to the stack and prints it.
            IF mInfo:LENGTH > 0 {
                SET mInfoOff TO mInfoOff + 1 + mInfo:PEEK():LENGTH.
            }
            mInfo:PUSH(reverseInfo:POP()).
            s_Print_Info().
        }
    } ELSE {                            // Prints the top of the info stack.
        LOCAL Data TO mInfo:PEEK().
        LOCAL lCount TO 0.
        FOR line IN Data {
            PRINT line[0]:TOSTRING:PADRIGHT(14):SUBSTRING(0,14) AT (Ic ,Il + mInfoOff + lCount).
            PRINT line[1]:TOSTRING:PADRIGHT(14):SUBSTRING(0,14) AT (Ic2,Il + mInfoOff + lCount).
            SET lCount TO lCount + 1.
        }
    }
}

function s_Log {
//logs text to layout
    DECLARE Parameter text.
            //text:string or LIST of strings. text to log
            
    IF (DEFINED layoutDone) = False 
    {
        s_Layout().
    }

    RETURN s_Layout(lexicon("Log", text)).
}

function s_Info_push {
// pushes a new info block to the layout. This will now be the working block
    DECLARE Parameter name, text.
            //name: Name of info
            //text: Text of info
    
    IF (name:TYPENAME = "LIST" AND text:TYPENAME <> "LIST") OR (name:TYPENAME <> "LIST" AND text:TYPENAME = "LIST") {
        RETURN False.
    }

    // Adds tupels of name and info to the pushList
    LOCAL pushList TO LIST().
    IF name:TYPENAME = "LIST" {
        FOR i in RANGE(name:LENGTH) {
            IF text:LENGTH > i {
                pushList:ADD(LIST(name[i], text[i])).
            } ELSE {
                pushList:ADD(LIST(name[i], "")).
            }
        }
    } ELSE {
        pushList:ADD(LIST(name, text)).
    }

    IF DEFINED layoutDone = False {
        s_Layout().
    }
    // Pushes the info
    RETURN s_Layout(lexicon("Info", lexicon("Type", "Push", "Info", pushList))).
}

function s_Info_ref {
// refreshes the current info block in the layout
    DECLARE Parameter name, text.
            //name: Name of info
            //text: Text of info
    

    // Adds tupels of name and info to the pushList
    LOCAL refList TO LIST().
    IF name <> "" {
        IF (name:TYPENAME = "LIST" AND text:TYPENAME <> "LIST") OR (name:TYPENAME <> "LIST" AND text:TYPENAME = "LIST") {
            RETURN False.
        }
        IF name:TYPENAME = "LIST" {
            FOR i in RANGE(text:LENGTH) {
                IF name:LENGTH > i {
                    refList:ADD(LIST(name[i], text[i])).
                } ELSE {
                    refList:ADD(LIST("", text[i])).
                }
            }
        } ELSE {
            refList:ADD(LIST(name, text)).
        }
    } ELSE {
        IF text:TYPENAME = "LIST" {
            For i in RANGE(text:LENGTH) {
                refList:ADD(LIST("", text[i])).
            }
        } ELSE {
            refList:ADD(LIST("",text)).
        }
    }

    IF DEFINED layoutDone = False {
        s_Layout().
    }
    // Pushes the info
    RETURN s_Layout(lexicon("Info", lexicon("Type", "Refresh", "Info", refList))).
}

function s_Info_pop {
// Deletes the working info block in the layout.
    RETURN s_Layout(lexicon("Info", lexicon("Type", "Pop"))).
}

function s_Info_Clear {
// clears information in layout.
            
    IF (DEFINED layoutDone) = False 
    {
        s_Layout().
    }

    // Prints empty strings to all information fields
    PRINT "":PADRIGHT(30) AT (Ic,spl).
    PRINT "":PADRIGHT(30) AT (Ic,stl).

    UNTIL mInfo:LENGTH < 1 {
        s_Info_pop().
    }
}

function s_Mission {
// prints missionname to layout
    DECLARE Parameter name.
            //name: Name of mission
            
    IF (DEFINED layoutDone) = False 
    {
        s_Layout().
    }

    RETURN s_Layout(lexicon("Mission", name)).
}

function s_Sub_Prog {
// prints subprogramname to layout
    DECLARE Parameter name.
            //name: Name of mission
            
    IF (DEFINED layoutDone) = False 
    {
        s_Layout().
    }

    RETURN s_Layout(lexicon("Subprogram", name)).
}

function s_Status {
// prints programstate to layout
    DECLARE Parameter name.
            //name: Name of mission
            
    IF (DEFINED layoutDone) = False 
    {
        s_Layout().
    }
    
    RETURN s_Layout(lexicon("Status", name)).
}

function s_Stage {
// prints programstate to layout
    DECLARE Parameter name.
            //name: Name of mission
            
    IF (DEFINED layoutDone) = False 
    {
        s_Layout().
    }
    
    RETURN s_Layout(lexicon("Stage", name)).
}