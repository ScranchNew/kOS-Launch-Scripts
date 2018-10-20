@LAZYGLOBAL OFF.

function parseDeltaV {
// Parses the whole craft for engines, fuel, mass, etc. and calculates deltaV per stage
    DECLARE Parameter pressure TO 0.
            // pressure used for the ISP, thrust, etc. Default is vacuum(0).

    global deltaVdone TO TRUE.

    global stagePartDict TO lexicon().      // lists parts per stage
    global stageEngineDict TO lexicon().    // lists engines per stage
    global rawDict is lexicon().            // lists stages with mass[0], drymass[1], ISP[2], F[3], M°[4] and engines[5] (list)
    global deltaVDict is lexicon().         // lists stages with deltaV[0], TWR at start[1], TWR at the end[2] and whole mass[3]

    LOCAL highStage TO 0.

    LOCAL shipParts TO list().
    LIST PARTS in shipParts.

    FOR part in shipParts
    {
        IF part:typename = "ENGINE"
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

    LOCAL quietEng TO False.
    LOCK throttle TO 0.

    FOR stageNum in stageEngineDict:KEYS
    {
        FOR eng in stageEngineDict[stageNum]
        {
            IF eng:ignition = False
            {
                SET quietEng TO TRUE.
                eng:activate.
            }
            LOCAL maxStage TO eng:stage.
            LOCAL minStage TO eng:parent:stage + 1.
            SET rawDict[minStage][0] TO rawDict[minStage][0] + eng:MASS.
            SET rawDict[minStage][1] TO rawDict[minStage][1] + eng:DRYMASS.
            FOR relevStage in Range(minStage, maxStage + 1)
            {
                SET rawDict[relevStage][2] TO rawDict[relevStage][2] + eng:availablethrustat(pressure)/eng:ispat(pressure).
                SET rawDict[relevStage][3] TO rawDict[relevStage][3] + eng:availablethrustat(pressure).
                SET rawDict[relevStage][4] TO rawDict[relevStage][4] + eng:availablethrustat(pressure)/(eng:ispat(pressure) * 9.81).
                rawDict[relevStage][5]:add(eng).
            }
            IF quietEng
            {
                eng:shutdown.
                SET quietEng to False.
            }
            
        }
    }
    FOR stageNum in rawDict:KEYS
    {
        IF rawDict[stageNum][2] <> 0{
            SET rawDict[stageNum][2] TO rawDict[stageNum][3]/rawDict[stageNum][2].
        }
    }

    LOCAL accMass TO 0.
    FOR stageNum in Range(0, highStage + 1)
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
// Calculates when in time the mean of a given burn is done
    declare Parameter dv, pressure TO 0, stageTime TO 2.
            // dv: deltaV of the burn
            // stageTime: Time alotted to each staging

    IF (DEFINED deltaVdone) = False {
        RUNPATH("/libraries/DeltaVLib").
    }

    LOCAL wholeDV TO 0.
    LOCAL burnTime TO 0.
    LOCAL burnMean TO 0.

    LOCAL finalStage TO stage:number.
    LOCAL deltV TO 0.

    parseDeltaV(pressure).

    UNTIL (wholeDV >= dv) 
    {
        IF deltaVDict:HASKEY(finalStage) {
            SET deltV TO deltaVDict[finalStage][0].
        } ELSE {
            SET deltV TO 0.
        }
        
        IF deltV >= dv - wholeDV
        {
            SET deltV TO dv - wholeDV.
        }
        IF deltV > 0 {
            SET wholeDV TO wholeDV + deltV.

            LOCAL F TO rawDict[finalStage][3].
            LOCAL m_d TO rawDict[finalStage][4].
            LOCAL m_0 TO deltaVDict[finalStage][3].

            LOCAL t_1 TO - (CONSTANT:E^(ln(m_0)-(deltV*m_d)/F)-m_0)/m_d.
            LOCAL t_m TO (m_0*ln((m_d*t_1-m_0)/-m_0)+m_d*t_1)/(m_d*ln((m_0-m_d*t_1)/m_0)).
            SET burnMean TO burnMean + (burnTime + t_m)*deltV.
            SET burnTime TO burnTime + stageTime + t_1.
        }
        SET finalStage TO finalStage - 1.
        IF finalStage < 0 {
            BREAK.
        }
    }
    SET burnMean TO burnMean/wholeDV.
    return list(burnMean, burnTime).
}