@LAZYGLOBAL OFF.

function parseDeltaV {
// Parses the whole craft for engines, fuel, mass, etc. and calculates deltaV per stage
// Does not work if you mix different fuel types being burned in one stage

    DECLARE Parameter pressure TO 0.
            // pressure used for the ISP, thrust, etc. Default is vacuum(0).

    GLOBAL deltaVdone TO TRUE.

    GLOBAL stagePartDict TO lexicon().      // lists parts per stage
    GLOBAL stageEngineDict TO lexicon().    // lists engines per stage
    GLOBAL rawDict TO lexicon().            // lists stages with mass[0], drymass[1], ISP[2], F[3], M°[4] and engines[5] (list)
    GLOBAL deltaVDict TO lexicon().         // lists stages with deltaV[0], TWR at start[1], TWR at the end[2] and whole mass[3]

    LOCAL highStage TO 0.                   // the highest stage in the ship

    LOCAL shipParts TO list().
    LIST PARTS in shipParts.

    FOR part in shipParts                   // builds stagePartDict, stageEngineDict and rawDict
    {
        IF part:typename = "ENGINE" AND part:name <> "sepMotor1"    // Ignores Separatrons 
                                                                    // TODO Ignore or manually work with solid rocket boosters
        {
            LOCAL sNum TO part:stage.
            IF stageEngineDict:HASKEY(sNUM) = False {
                SET stageEngineDict[sNum] TO list().
                SET highStage to max(highStage, sNum).
            }
            stageEngineDict[sNum]:add(part).
        } ELSE {
            LOCAL sNum TO part:stage + 1.
            IF stagePartDict:HASKEY(sNum) = False {
                SET stagePartDict[sNum] TO list().
                SET rawDict[sNum] TO list(0,0,0,0,0,list()).
                SET highStage to max(highStage, sNum).
            }
            stagePartDict[sNum]:add(part).
            SET rawDict[sNum][0] TO rawDict[sNum][0] + part:MASS.
            SET rawDict[sNum][1] TO rawDict[sNum][1] + part:DRYMASS.
        }
    }

    // To get the engine thrust kOS has to shortly activate every engine.
    LOCAL quietEng TO False.        // temporary flag if the engine was off before starting this script
    LOCK throttle TO 0.             // Stops all engines while measuring deltaV

    FOR stageNum in stageEngineDict:KEYS
    {
        FOR eng in stageEngineDict[stageNum]
        {
            IF eng:ignition = False
            {
                SET quietEng TO TRUE.
                eng:activate.
            }
            // This part uses how the stage number for each part is listed in KSP to get all active engines (and their thrust/isp/etc) for each stage
            // This also accounts for asparagus staging

            LOCAL maxStage TO eng:stage.            // The engine stage always is the last stage the engine is active in
            LOCAL minStage TO eng:parent:stage + 1. // The parent stage is the first stage the engine is active in (somehow)

            SET rawDict[minStage][0] TO rawDict[minStage][0] + eng:MASS.    // Adds up the mass
            SET rawDict[minStage][1] TO rawDict[minStage][1] + eng:DRYMASS. // And the dry mass

            FOR relevStage in Range(minStage, maxStage + 1)
            {
                // Sums up the thrust per ISP
                SET rawDict[relevStage][2] TO rawDict[relevStage][2] + eng:availablethrustat(pressure)/eng:ispat(pressure).
                // Sums up the thrust
                SET rawDict[relevStage][3] TO rawDict[relevStage][3] + eng:availablethrustat(pressure).
                // Sums up the massflow
                SET rawDict[relevStage][4] TO rawDict[relevStage][4] + eng:availablethrustat(pressure)/(eng:ispat(pressure) * 9.81).
                // Adds all relevant engines
                rawDict[relevStage][5]:add(eng).
            }
            IF quietEng
            {
                eng:shutdown.
                SET quietEng to False.
            }
            
        }
    }
    FOR stageNum in rawDict:KEYS        // Gets the mean isp per stage
    {
        IF rawDict[stageNum][2] <> 0
        {
            // By dividing combined thrust by the thrust per ISP you get the effective ISP
            SET rawDict[stageNum][2] TO rawDict[stageNum][3]/rawDict[stageNum][2].
        }
    }

    LOCAL accMass TO 0.
    FOR stageNum in Range(0, highStage + 1)     // Calculates the actual deltaV and TWR per Stage
    {
        IF rawDict:HASKEY(stageNum) = False{
            rawDict:add(stageNum, list(0,0,0,0,0,list())).
        }
        SET deltaVDict[stageNum] TO list(0, 0, 0, 0).
        SET deltaVDict[stageNum][0] TO 9.81 * rawDict[stageNum][2] * ln((accMass + rawDict[stageNum][0])/(accMass + rawDict[stageNum][1])).
        SET deltaVDict[stageNum][1] TO rawDict[stageNum][3]/(accMass + rawDict[stageNum][0])/9.81.
        SET deltaVDict[stageNum][2] TO rawDict[stageNum][3]/(accMass + rawDict[stageNum][1])/9.81.
        SET accMass TO accMass + rawDict[stageNum][0].
        SET deltaVDict[stageNum][3] TO accMass.
    }
}

function calc_Burn_Mean {
// Calculates when in time the mean of a given burn is done. 
// For example a 10s burn with constant acceleration will have a burn mean of 5s.
// With constantly rising acceleration it would be closer to 7s.

// If the burn means lines up with the maneuver node you will hit the orbital change pretty much perfectly every time
// #itjustworks

// (Full throttle is assumed for the burn duration)

    declare Parameter dv, pressure TO 0, stageTime TO 2.
            // dv: deltaV needed for the burn
            // pressure: at what pressure level the burn is performed (0 is vacuum, 1 is the Kerbal Space Center)
            // stageTime: Time alotted to each staging process

    LOCAL wholeDV TO 0.                 // sum of the full deltaV of all stages accounted for in the burn 
    LOCAL burnTime TO 0.                // time of the whole burn
    LOCAL burnMean TO 0.                // mean time of the whole burn

    LOCAL finalStage TO stage:number.   // starts at the current stage and will contain the last stage participating in the burn at the end.
    LOCAL deltV TO 0.                   // deltaV in the stage we are currently calculating

    parseDeltaV(pressure).              // updates the deltaV dictionary for the whole ship

    UNTIL (wholeDV >= dv)               // Now we calculate the deltaV and burn time for stage after stage, until we have enough for the burn
    {
        IF deltaVDict:HASKEY(finalStage) {
            SET deltV TO deltaVDict[finalStage][0].
        } ELSE {
            SET deltV TO 0.
        }
        
        IF deltV >= dv - wholeDV        // if the current stage has more than enough deltaV, you only calculate for the part you need
        {
            SET deltV TO dv - wholeDV.
        }
        IF deltV > 0 {                  // add the burn time and burn mean time in the right way
            SET wholeDV TO wholeDV + deltV.

            LOCAL F TO rawDict[finalStage][3].
            LOCAL m_d TO rawDict[finalStage][4].
            LOCAL m_0 TO deltaVDict[finalStage][3].

            // I used the rocket equation, Wolfram Alpha, Maple and some evil Integrals to get to these formulas.
            // Don't mess with them.
            
            LOCAL t_1 TO - (CONSTANT:E^(ln(m_0)-(deltV*m_d)/F)-m_0)/m_d.                    // stage burn time
            LOCAL t_m TO (m_0*ln((m_d*t_1-m_0)/-m_0)+m_d*t_1)/(m_d*ln((m_0-m_d*t_1)/m_0)).  // stage mean burn time

            SET burnMean TO burnMean + (burnTime + t_m)*deltV.      // burn mean actually holds the sum of the (stage mean time) * (stage dV)
                                                                    // this makes it easier to get the correct mean afterwards
            SET burnTime TO burnTime + stageTime + t_1.
        }

        // If you get to the root stage of your ship you don't have the juice to do the burn and won't go to space today
        // (or at least not do the full burn)
        SET finalStage TO finalStage - 1.
        IF finalStage < 0 {             
            BREAK.
        }
    }
    IF wholeDV > 0 {
        SET burnMean TO burnMean/wholeDV.
        return list(burnMean, burnTime).
    } ELSE {
        return list(0,0).
    }
}
