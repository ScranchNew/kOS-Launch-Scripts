// library of kOS functions for roundevouing in orbit

@LAZYGLOBAL OFF.

GLOBAL RendevouzLib_Loaded TO True.

IF (DEFINED LaunchLib_Loaded) = False OR (DEFINED LogLib_Loaded) = False OR (DEFINED DockLib_Loaded) = False {
    CD("1:libraries").
    RUNONCEPATH("0_LogLib").
    RUNONCEPATH("2_LaunchLib").
    RUNONCEPATH("3_DockLib").
    CD("1:").
}

function a_Check_Target {
// checks IF a target fills certain criteria.
    DECLARE Parameter targ TO 0, targType TO 0.
                    // targ: 0: choose targetet vessel ELSE set to the target
                    // targType:0: All allowed          // you can add_ them to get combinations (e.g.: 1 + 2 means Vessels and Dockingports allowed)
                    //          1: Vessel
                    //          2: Dockingport
                    //          4: Body
                    //          8: rendevouzable
                    //         16: Orbit

    IF (DEFINED layoutDone) = False {
        s_Layout().
    }

    LOCAL cVes TO 0.
    LOCAL cDoc TO 0.
    LOCAL cBod TO 0.
    LOCAL cRen TO 0.
    LOCAL cObt TO 0.

    SET targType TO MOD(targType, 32).
    IF targType >= 16 {
        SET cObt TO 1.
        SET targType TO targType - 16.
    }
    IF targType >= 8 {
        SET cRen TO 1.
        SET targType TO targType - 8.
    }
    IF targType >= 4 {
        SET cBod TO 1.
        SET targType TO targType - 4.
    }
    IF targType >= 2 {
        SET cDoc TO 1.
        SET targType TO targType - 2.
    }
    IF targType >= 1 {
        SET cVes TO 1.
    }

    IF targ = 0 {
        IF HASTARGET {
            SET targ TO TARGET.
        } ELSE {
            s_Status("Error: No target chosen").
            RETURN False.
        }
    }

    LOCAL targParent TO targ.

    // Spaghetti code to check all possibilities
    IF targ:TYPENAME = "Orbit" {
        IF cObt = True {
            RETURN targ.
        } ELSE {
            s_Status("Error: Target is ORBIT").
            RETURN False.
        }
    }
    IF targ:TYPENAME = "BODY" {
        IF cBod = True {
            RETURN targ.
        } ELSE {
            s_Status("Error: Target is BODY").
            RETURN False.
        }
    }
    IF targ:TYPENAME = "DOCKINGPORT" AND cDoc = False {
        s_Status("Error: Target is DOCKINGPORT").
        RETURN False.
    } ELSE IF targ:TYPENAME = "DOCKINGPORT" {
        SET targParent TO targ:SHIP.
    } 
    IF targ:TYPENAME <> "VESSEL" AND targ:TYPENAME <> "BODY" AND targ:SHIP:TYPENAME = "VESSEL" AND cVes {
        IF NOT (targ:TYPENAME = "DOCKINGPORT" AND cDoc) {
            SET targ TO targ:SHIP.
        }
    }
    IF targ:TYPENAME = "VESSEL" AND cVes = False {
        s_Status("Error: Target is VESSEL").
        RETURN False.
    }
    IF targ:TYPENAME <> "VESSEL" AND targ:TYPENAME <> "BODY" AND targ:SHIP:TYPENAME <> "VESSEL" AND cRen {
        s_Status("Error: Target not RENDEVOUZABLE").
        RETURN False.
    }
    IF targ:name:contains("Sun") AND cRen {
        s_Status("Error: Can't rendevouz with sun.").
        RETURN False.
    } ELSE IF targ = SHIP AND cRen {
        s_Status("Error: Can't rendevouz with yourself").
        RETURN False.
    }
    IF SHIP:BODY <> targParent:BODY AND cRen {
        s_Status("Error: Target not in same SOI").
        RETURN False.
    }
    IF targ:TYPENAME <> "BODY" AND (targ:TYPENAME = "VESSEL" OR targ:SHIP:TYPENAME = "VESSEL") AND cRen {
        IF targParent:OBT:PERIAPSIS < BODY:ATM:HEIGHT  OR targParent:OBT:APOAPSIS < 0{
            s_Status("Error: Target not in orbit").
            RETURN False.
        }
    }
    RETURN targ.
}

function a_Prompt_Target {
// prompts the player to select a target. 
    DECLARE Parameter useList TO False.

    If useList 
    {
        LOCAL targType TO s_Choose_from_List("targettype",LIST("Vessel","Body","SpaceObject")).
        LOCAL targList TO LIST().
        LOCAL listString TO "".
        LOCAL counter TO 0.
        IF targType = 0 {
            SET listString TO "Vessel".
            LIST targets IN targList.
            FOR targ in RANGE(0, targList:LENGTH) {
                IF targList[counter]:typename = "SpaceObject" OR targList[counter]:name:CONTAINS("Debris") {
                    targList:REMOVE(counter).
                } ELSE {
                    SET counter TO counter + 1.
                }
            }
        } ELSE IF targType = 2 {
            SET listString TO "SpaceObject".
            FOR targ in RANGE(0, targList:LENGTH) {
                IF targList[counter] <> "SpaceObject" {
                    targList:REMOVE(counter).
                } ELSE {
                    SET counter TO counter + 1.
                }
            }
        } ELSE {
            SET listString TO "Body".
            LIST bodies in targList.
        }
        LOCAL targNum TO s_Choose_from_List(listString, targList).
        SET TARGET TO targList[targNum].
    }
    ELSE
    {
        s_Info_push("Select target: ","").
        LOCAL correctInput TO False.
        Terminal:Input:CLEAR.
        UNTIL correctInput
        {
            LOCAL retPress TO False.
            LOCAL nxtchar TO " ".
            UNTIL retPress
            {
                IF Terminal:input:hasChar() {
                    SET nxtchar TO Terminal:Input:GetChar().
                }
                IF nxtchar <> Terminal:Input:Return
                {
                    IF HASTARGET {
                        s_Info_ref("", TARGET:NAME).
                    } ELSE {
                        s_Info_ref("", "No selection").
                    }
                } ELSE {
                    SET retPress TO True.
                }
            }
            IF NOT HASTARGET {
                SET retPress TO False.
            } ELSE {
                SET correctInput TO True.
            }
        }
        s_Info_pop().
    }
    RETURN TARGET.
}

function c_AnDn_Anomaly {
// calculates the ascending and descending node from one orbit to another.
    DECLARE Parameter ref TO OBT, targ TO 1.
            // ref:  orbit:  the reference orbit for the ascending and descending node.
            // targ: Int: [0]: calculate for the current body
            //            [1]: calculate for the current target
            //       vessel: calculate for that vessel
            //       body:   calculate for that body
            //       orbit:  calculate for that orbit

    // Returns a lexicon of 3 items:
    //      ["AN"]:     a Lexicon containing the ["TrueAn"]: True Anomaly of the Ascending Node
    //                                           ["EccAn"]: Eccentric Anomaly of the Ascending Node
    //                                           ["MeanAn"]: Mean Anomaly of the Ascending Node
    //                                           ["Alt"]: Altitude of the Ascending Node above the BODY
    //      ["DN"]:     a LIST containing the same items as ["AN"] for the Descending Node
    //      ["relInc"]: the relative inclination between the orbits
    
    IF targ = 1 {
        IF HASTARGET {
            SET targ TO TARGET.
            IF targ:TYPENAME = "PART" {
                SET targ TO targ:SHIP.
            }
        } ELSE {
            s_Status("No target set").
            RETURN False.
        }
    }
    IF targ:TYPENAME = "vessel" OR targ:TYPENAME = "body" {
        IF targ:HASOBT {
            SET targ TO targ:OBT.
        } ELSE {
            s_Status("Target does not have orbit").
            RETURN False.
        }
    }

    LOCK THROTTLE TO 0.
    RCS OFF.
    WAIT 1.

    LOCAL r_vec TO c_Orbit_Vector(ref).
    LOCAL t_vec TO lexicon(
        "v_n", v(0,0,1),
        "v_Lan", v(1,0,0),
        "v_Forw", v(0,1,0),
        "v_Pe", v(1,0,0),
        "v_Nu", v(1,0,0),
        "v_MeanAn", v(1,0,0)
    ).
    IF targ:TYPENAME = "ORBIT" AND targ <> ref{
        SET t_vec TO c_Orbit_Vector(targ).
    }
    LOCAL v_An TO VCRS(t_vec["v_n"], r_vec["v_n"]):NORMALIZED.  // Vector towards the ascending node
    LOCAL relInc TO VANG(t_vec["v_n"], r_vec["v_n"]).           // Angle between orbits.

    LOCAL angle_lan_to_an TO c_Angle_From_Ref_Vectors(v_An, r_vec["v_Lan"], r_vec["v_Forw"]).

    LOCAL orbNodes TO lexicon(
        "AN", lexicon(),
        "DN", lexicon()
    ).
    FOR _node in orbNodes:Keys {
        LOCAL offs TO 0.
        IF _node = "DN" {SET offs TO 180.}
        // true Anomaly             in [°]
        LOCAL trueAn TO m_Clamp(angle_lan_to_an - ref:ARGUMENTOFPERIAPSIS + offs, 360).
        orbNodes[_node]:ADD("TrueAn",trueAn).

        LOCAL TrueAnValid TO True.
        IF ref:ECCENTRICITY >= 1 {
            LOCAL ang_eta TO ARCCOS(-1/ref:ECCENTRICITY).
            SET TrueAnValid TO (trueAn < ang_eta) OR (trueAn > 360 - ang_eta).
        }
        LOCAL eccAn TO -1.
        LOCAL meaAn TO -1.
        IF TrueAnValid {
            // eccentric Anomaly        in [°]
            SET eccAn TO c_Ecc_An_from_Tru(trueAn, ref).
            // mean Anomaly             in [°]
            SET meaAn TO c_Mean_An_from_Ecc(eccAn, ref).
        }
        orbNodes[_node]:ADD("EccAn",eccAn).
        orbNodes[_node]:ADD("MeanAn", meaAn).

        // orbit height of node     in [m]
        LOCAL altNo TO c_r_from_Tru(trueAn, ref).
        orbNodes[_node]:ADD("Alt", altNo - ref:BODY:RADIUS).
    }

    orbNodes["AN"]:ADD("v_Node", v_An).
    orbNodes["DN"]:ADD("v_Node", -v_An).
    SET orbNodes["relInc"] TO relInc.
    RETURN(orbNodes).
}

function c_Equ_AnModel {
// calculates where two orbital planes intersect and relative to that point gives
// back values to calculate equivalent anomalies
// can take into account if the rel. inclination is at or above 90°

    DECLARE Parameter orb1, orb2.

    LOCAL vecs_1 TO c_Orbit_Vector(orb1).
    LOCAL vecs_2 TO c_Orbit_Vector(orb2).

    LOCAL v_an_1_to_2 TO VCRS(vecs_2["v_n"], vecs_1["v_n"]).
    LOCAL obt_norm_dot TO VDOT(vecs_2["v_n"], vecs_1["v_n"]).

    LOCAL alpha_an_1 TO c_Angle_From_Ref_Vectors(v_an_1_to_2, vecs_1["v_Lan"], vecs_1["v_Forw"]).
    LOCAL alpha_an_2 TO c_Angle_From_Ref_Vectors(v_an_1_to_2, vecs_2["v_Lan"], vecs_2["v_Forw"]).

    LOCAL nu_an_1 TO alpha_an_1 - orb1:ARGUMENTOFPERIAPSIS.
    LOCAL nu_an_2 TO alpha_an_2 - orb2:ARGUMENTOFPERIAPSIS.

    RETURN lexicon(
        "nu_1", nu_an_1,
        "nu_2", nu_an_2,
        "norm_prod", obt_norm_dot
    ).
}

function c_Equ_TruAn {
// calculates the True Anomaly for the second orbit where both positions have the same rotation relative to 
// their ascending/descending nodes useful for some kind of rendevouz calculations
    DECLARE Parameter EquAnModel, Nu, From2To1 TO False.

    LOCAL Nu_x_ref TO EquAnModel["nu_1"].
    LOCAL Nu_x_tgt TO EquAnModel["nu_2"].
    IF From2To1 {
        SET Nu_x_ref TO EquAnModel["nu_2"].
        SET Nu_x_tgt TO EquAnModel["nu_1"].
    }

    LOCAL Nu_1_rel TO Nu - Nu_x_ref.
    IF EquAnModel["norm_prod"] < 0 {
        SET Nu_1_rel TO -Nu_1_rel.
    }
    LOCAL Nu_out TO Nu_1_rel + Nu_x_tgt.
    RETURN m_Clamp(Nu_out, 360).
}

function c_Phase_Angle_after_Nu {
// calculates the phase angle (in true anomaly => actual spacial angle) 
// between these two orbits after a given amount of true anomaly in orbit 1
// Returns a lexicon of [TruePhaseAngle]: How much true anomaly orb2 is ahead of orb1
//                      [MeanPhaseAngle]: How much mean anomaly orb2 is ahead of orb1
//                      [PhaseTime]: How much time obt1 would need to wait without moving for obt2 to reach its position
//                      [deltaT]: Time for orb1 to reach the given extra true anomaly

    DECLARE Parameter orb1, orb2, Nu TO 0.

    LOCAL deltaT TO 0.
    IF Nu <> 0 {
        SET deltaT TO c_Time_between_Tru(orb1:TRUEANOMALY + Nu, orb1:TRUEANOMALY, orb1).
    }
    LOCAL MeAn_1 TO c_MeanAn(orb1, deltaT).
    LOCAL MeAn_2 TO c_MeanAn(orb2, deltaT).

    LOCAL TruAn_1 TO c_Tru_An_from_Mean(MeAn_1, orb1).
    LOCAL TruAn_2 TO c_Tru_An_from_Mean(MeAn_2, orb2).

    LOCAL Equ_AnModel TO c_Equ_AnModel(orb1, orb2).
    LOCAL TruAn_1_in_2 TO c_Equ_TruAn(Equ_AnModel, TruAn_1).
    LOCAL MeAn_1_in_2 TO c_Mean_An_from_Tru(TruAn_1_in_2, orb2).

    LOCAL MeanPhaseAngle TO m_Clamp(MeAn_2 - MeAn_1_in_2, 360).
    LOCAL TruePhaseAngle TO m_Clamp(TruAn_2 - TruAn_1_in_2, 360).

    LOCAL PhaseTime TO c_Time_from_MeanAn(MeanPhaseAngle, orb2).

    RETURN lexicon(
        "TruePhaseAngle", TruePhaseAngle,
        "MeanPhaseAngle", MeanPhaseAngle,
        "PhaseTime", PhaseTime,
        "deltaT", deltaT
    ).
}

function c_Closest_Approach {
// calculates the closest approaches between orbit 1 and orbit 2
// As this can't be analytically solved it is only an approximation and can take a lot of processing power (Uses "c_Tru_An_from_Mean()" a lot).
// I suggest raising the allowed operations per tick for kOS.

    DECLARE Parameter orb1, orb2, anomalyOffset TO 0, Nu_min TO 0, delt_Nu TO 360, Nu_start TO orb1:TRUEANOMALY, epoch_start TO TIME:SECONDS.
    // It RETURNs a LIST of [n]: Encounter-lists with each having:
        // [0]: The distance at Encounter
        // [1]: Mean Anomaly of orbit 1 at Encounter
        // [2]: True Anomaly of orbit 1 at Encounter
        // [3]: Mean Anomaly of orbit 2 at Encounter
        // [4]: True Anomaly of orbit 2 at Encounter
        // [5]: Radius in orbit 1 at Encounter from center of BODY

    LOCAL div TO 8.

    LOCAL M1_0 TO m_Clamp(orb1:MEANANOMALYATEPOCH + (epoch_start - orb1:EPOCH) * 360/orb1:PERIOD, 360).
    LOCAL M2_0 TO m_Clamp(orb2:MEANANOMALYATEPOCH + anomalyOffset + (epoch_start - orb2:EPOCH) * 360/orb2:PERIOD, 360).

    LOCAL distList TO LIST().
    FOR i IN RANGE(0,div) {
        LOCAL Nu TO Nu_min + i*delt_Nu/div.
        LOCAL Nu_1 TO m_Clamp(Nu_start + Nu, 360).
        LOCAL pos_1 TO c_Orbit_Pos(orb1, Nu_1).
        LOCAL M_1 TO c_Mean_An_from_Tru(Nu_1, orb1).
        LOCAL T TO m_Clamp(M_1 - M1_0, 360) * orb1:PERIOD / 360.
        LOCAL M_2 TO m_Clamp(M2_0 + T * 360 / orb2:PERIOD, 360).
        LOCAL Nu_2 TO c_Tru_An_from_Mean(M_2, orb2).
        LOCAL pos_2 TO c_Orbit_Pos(orb2, Nu_2).
        distList:ADD(LIST((pos_1 - pos_2):MAG, M_2, Nu_2)).
    }
    LOCAL retList TO LIST().
    LOCAL lastDist TO distList[div - 1][0].
    LOCAL nextDist TO distList[1][0].
    FOR i in RANGE(0,div) {
        IF i = div - 1 {
            SET nextDist TO distList[0][0].
        } ELSE {
            SET nextDist TO distList[i+1][0].
        }
        IF distList[i][0] < lastDist AND distList[i][0] < nextDist {
            LOCAL NuClose TO Nu_min + i * delt_Nu/div.
            LOCAL rClose TO c_r_from_Tru(NuClose + Nu_start, orb1).
            IF rClose * delt_Nu * CONSTANT:PI/(180*div) < 20 {
                LOCAL M_1 TO c_Mean_An_from_Tru(NuClose + Nu_start, orb1).
                retList:ADD(LIST(distList[i][0], M_1, NuClose + Nu_start, distList[i][1], distList[i][2], rClose)).
            } ELSE {
                LOCAL subRetList TO c_Closest_Approach(orb1, orb2, anomalyOffset, NuClose - delt_Nu/div, 2*delt_Nu/div, Nu_start, epoch_start).
                FOR Ret in subRetList {
                    retList:ADD(Ret).
                }
            }
        }
        SET lastDist TO distList[i][0].
    }
    RETURN retList.
}

function p_Slow_Rendevouz {
// Rendevouz the craft with a given target.
    DECLARE Parameter targ TO 0, anomalyOffset TO 0.
    IF (DEFINED layoutDone) = False {
        s_Layout().
    }

    IF SHIP:STATUS <> "ORBITING"
    {
        s_Status("Ship needs to be in orbit").
        RETURN False.
    }

    s_Sub_Prog("p_Slow_Rendevouz").
    s_Status("Checking for Errors").

    SET targ TO a_Check_Target(targ, 1+4+8+16).
    UNTIL targ:TYPENAME <> "BOOLEAN" {
        IF targ:TYPENAME = "BOOLEAN" {
            SET targ TO a_Prompt_Target(True).
        }
        SET targ TO a_Check_Target(targ, 1+4+8+16).
    }
    LOCAL targObt TO targ.
    IF targ:TYPENAME <> "Orbit" {
        SET targObt TO targ:OBT.
    }

    s_Status("Calc. transfer burn").
    // First we go into a transfer orbit which connects both orbits at the ascending or descending node

    LOCAL myANDN TO c_AnDn_Anomaly(SHIP:OBT, targObt).         // AS and DEscending node from my orbit to target orbit
    LOCAL tarANDN TO c_AnDn_Anomaly(targObt, SHIP:OBT).        // AS and DEscending node from target orbit to my orbit
    LOCAL relInc TO myANDN["relInc"].

    // If it uses the descending or ascending Node
    LOCAL useDE TO True.
    IF tarANDN["DN"]["Alt"] - myANDN["AN"]["Alt"] > tarANDN["AN"]["Alt"] - myANDN["DN"]["Alt"] {    // Burn so the transfer-orbit is as cicular as possible
        SET useDE TO False.
    }

    LOCAL myNode TO myANDN["DN"].
    LOCAL tarNode TO tarANDN["DN"].
    IF useDE = False {
        SET myNode TO myANDN["AN"].
        SET tarNode TO tarANDN["AN"].
        SET relInc TO -relInc.
    }

    LOCAL vMyNode TO c_Orb_Vel(0, myNode["Alt"], tarNode["Alt"], myNode["Alt"]).    // calculates parameter
    LOCAL vCurrentMyNode TO c_Orbit_Velocity_Vector(myNode["TrueAn"]).

    LOCAL targetIsLower TO 0.      // if the target node is lower do an early inclination change
    IF myNode["Alt"] > tarNode["Alt"] {
        SET targetIsLower TO 1.
    }

    LOCAL meanAnToNode TO m_Clamp(myNode["MeanAn"] - c_MeanAN(), 360).

    LOCAL timeToNode TO c_Time_from_MeanAn(meanAnToNode).

    s_Log("Calculated transfer maneuver").

    // we only do the inclination change at the high-point of the transfer
    // that could be this burn or the next
    LOCAL manNode TO c_Circ_Man(timeToNode, vCurrentMyNode, LIST(vMyNode, 0), targetIsLower * -relInc).
    p_Orb_Burn(manNode).
    s_Sub_Prog("p_Slow_Rendevouz").
    // update Node Position after burn
    LOCAL EquAnModel TO c_Equ_AnModel(OBT, targObt).
    LOCAL myNuAtNode TO c_Equ_TruAn(EquAnModel, tarNode["TrueAn"], True).

    // Now we sit in the transfer maneuver which connects the old and the target orbit at the ascending or descending node.
    // Next we raise or lower the node not touching the target orbit to syncronize our position by waiting

    s_Status("Calc. wait burn").

    // the phase angle at the orbit intersection
    LOCAL phaseAngle TO c_Phase_Angle_after_Nu(OBT, targObt, m_Clamp(myNuAtNode - OBT:TRUEANOMALY, 360)).
    SET   timeToNode TO phaseAngle["deltaT"].

    LOCAL tarDeltaMeanAtNode TO m_Clamp(phaseAngle["MeanPhaseAngle"] + anomalyOffset, 360).
    LOCAL tarDeltaNuAtNode TO m_Clamp(phaseAngle["TruePhaseAngle"] + anomalyOffset, 360).

    LOCAL targPosStart TO tarDeltaMeanAtNode / 360.
    LOCAL waitMyOrbNum TO 0.
    LOCAL targPosNew TO 0.
    LOCAL targPosMin TO targPosStart.
    LOCAL targPosMax TO targPosStart.

    LOCAL min_Change TO min(OBT:PERIOD, targObt:PERIOD)/targObt:PERIOD.
    LOCAL max_Change TO max(OBT:PERIOD, targObt:PERIOD)/targObt:PERIOD.
    
    s_Log("PhaseAngle Change/Obt: [" + ROUND(min_Change*360) + "°," + ROUND(max_Change*360) + "°]").

    LOCAL foundWaitObt TO False.
    UNTIL foundWaitObt {
        SET waitMyOrbNum TO waitMyOrbNum + 1.
        SET targPosMin TO targPosMin + min_Change.
        SET targPosMax TO targPosMax + max_Change.

        IF FLOOR(targPosMin) < FLOOR(targPosMax) {
            SET targPosNew TO CEILING(targPosMin).
            SET foundWaitObt TO True.
        }
    }
    s_Log("Pos min/max at " + waitMyOrbNum + " Obt: [" + ROUND((targPosMin-waitMyOrbNum)*360) + "/" + ROUND((targPosMax-waitMyOrbNum)*360) +"]").
    LOCAL waitTgtOrbNum TO targPosNew - targPosStart.

    s_Info_push(LIST("Wait for",                 "At Target:",                "M Phase Ang.",           "Nu Phase Ang."),
                LIST(waitMyOrbNum + " orbit(s)", waitTgtOrbNum + " orbit(s)", tarDeltaMeanAtNode + "°", tarDeltaNuAtNode + "°")).


    // Calculating the waiting orbit
    LOCAL waitPeriod TO waitTgtOrbNum * targObt:PERIOD.
    LOCAL wait_orbit_period TO waitPeriod / waitMyOrbNum.
    s_Log("Adjust Obt. period to: " + s_SecondsToTime(wait_orbit_period):Clock).

    LOCAL sma_wait TO c_Sma_From_Period(wait_orbit_period) - BODY:RADIUS.
    LOCAL vAfterNode TO c_Orb_Vel(0, sma_wait, sma_wait, tarNode["Alt"]).

    LOCAL MyVAtNode TO c_Orbit_Velocity_Vector(myNuAtNode, OBT).
    LOCAL TarVAtNode TO c_Orbit_Velocity_Vector(tarNode["TrueAn"], targObt).

    LOCAL My_Vec TO v(MyVAtNode[0], MyVAtNode[1], 0).
    LOCAL Tar_Vec TO v(TarVAtNode[0], TarVAtNode[1], 0).
    LOCAL After_Vec TO m_Line_Circle_Intersect(My_Vec, Tar_Vec-My_Vec, vAfterNode).
    IF After_Vec["HasInt"] = False {
        s_Log("Error! No Intermediate Vector found!").
        a_Wait_For_Enter().
    }
    LOCAL burn_frac TO After_Vec["a_1"].
    LOCAL burn_vec TO After_Vec["Vec_1"].
    IF burn_frac < 0 {
        SET burn_frac TO After_Vec["a_2"].
        SET burn_vec TO After_Vec["Vec_2"].
    }
    if burn_frac > 1 {
        s_Log("Error! Needs to overshoot target!:" + burn_frac).
        a_Wait_For_Enter().
    }

    // we split the inclination change between the waiting maneuver and the final speedmatch
    // if the waiting maneuver goes most of the way it gets most of the inclination change and vice versa
    LOCAL inc_wait TO burn_frac * relInc.
    
    s_Log("Started waiting (" + waitMyOrbNum + " Orbits)").

    SET manNode TO c_Circ_Man(timeToNode, MyVAtNode, LIST(burn_vec:X, burn_vec:Y), (1 - targetIsLower) * inc_wait).

    p_Orb_Burn(manNode).
    s_Sub_Prog("p_Slow_Rendevouz").
    // update Node Position after burn
    SET EquAnModel TO c_Equ_AnModel(OBT, targObt).
    SET myNuAtNode TO c_Equ_TruAn(EquAnModel, tarNode["TrueAn"], True).

    s_Status("Waiting").

    LOCAL safeOrientation TO c_Safe_Orientation().
    LOCK STEERING TO safeOrientation.
    WAIT UNTIL VANG(FACING:STARVECTOR, safeOrientation:STARVECTOR) < 10.

    // one correction before the final orbit
    IF waitMyOrbNum >= 2 {
        LOCAL orbitsToWarp TO waitMyOrbNum - 1.

        a_Warp_To(OBT:PERIOD*orbitsToWarp - 10*60, 0, 0).

        // the phase angle at the orbit intersection
        SET phaseAngle TO c_Phase_Angle_after_Nu(OBT, targObt, m_Clamp(myNuAtNode - OBT:TRUEANOMALY, 360)).
        SET timeToNode TO phaseAngle["deltaT"].
        
        SET tarDeltaMeanAtNode TO m_Clamp(phaseAngle["MeanPhaseAngle"] + anomalyOffset, 360).
        SET tarDeltaNuAtNode TO m_Clamp(phaseAngle["TruePhaseAngle"] + anomalyOffset, 360).
        SET targPosStart TO tarDeltaMeanAtNode / 360.

        SET targPosNew TO ROUND(OBT:PERIOD / targObt:PERIOD + targPosStart).
        SET waitTgtOrbNum TO targPosNew - targPosStart.

        s_Info_ref(LIST("Wait for",   "At Target:",                        "M Phase Ang.",             "Nu Phase Ang."),
                   LIST(1 + " orbit", targPosNew-targPosStart + " orbits", tarDeltaMeanAtNode + "°", tarDeltaNuAtNode + "°")).

        // Calculating the waiting orbit
        SET waitPeriod TO waitTgtOrbNum * targObt:PERIOD.
        s_Log("Adjust Obt. period to: " + s_SecondsToTime(wait_orbit_period):Clock).

        SET sma_wait TO c_Sma_From_Period(waitPeriod) - BODY:RADIUS.
        SET vAfterNode TO c_Orb_Vel(0, sma_wait, sma_wait, tarNode["Alt"]).

        SET MyVAtNode TO c_Orbit_Velocity_Vector(myNuAtNode, OBT).
        SET TarVAtNode TO c_Orbit_Velocity_Vector(tarNode["TrueAn"], targObt).

        SET My_Vec TO v(MyVAtNode[0], MyVAtNode[1], 0).
        SET Tar_Vec TO v(TarVAtNode[0], TarVAtNode[1], 0).
        SET After_Vec TO m_Line_Circle_Intersect(My_Vec, Tar_Vec-My_Vec, vAfterNode).
        IF After_Vec["HasInt"] = False {
            s_Log("Error! No Intermediate Vector found!").
            a_Wait_For_Enter().
        }
        SET burn_frac TO After_Vec["a_1"].
        SET burn_vec TO After_Vec["Vec_1"].
        IF burn_frac < 0 {
            SET burn_frac TO After_Vec["a_2"].
            SET burn_vec TO After_Vec["Vec_2"].
        }

        IF (burn_frac * (Tar_Vec-My_Vec)):MAG > 0.01 {
            s_Log("Performing final correction").
            SET manNode TO c_Circ_Man(timeToNode, MyVAtNode, LIST(burn_vec:X, burn_vec:Y), 0).

            p_Orb_Burn(manNode).
            s_Sub_Prog("p_Slow_Rendevouz").
            // update Node Position after burn
            SET EquAnModel TO c_Equ_AnModel(OBT, targObt).
            SET myNuAtNode TO c_Equ_TruAn(EquAnModel, tarNode["TrueAn"], True).
        } ELSE {
            a_Warp_To(OBT:PERIOD).
        }
    }
    
    SET timeToNode TO c_Time_from_MeanAn(m_clamp(c_Mean_An_from_Tru(myNuAtNode) - c_Mean_An_from_Tru(), 360)).

    LOCAL v_0 TO c_Orbit_Velocity_Vector(myNuAtNode).
    LOCAL v_1 TO c_Orbit_Velocity_Vector(tarNode["TrueAn"], targObt).

    LOCAL burnNode TO c_Circ_Man(timeToNode, v_0, v_1, (1 - targetIsLower) * (relInc - inc_wait)).
    p_Orb_Burn(burnNode).
    s_Sub_Prog("p_Slow_Rendevouz").
    s_Log("Orbit matched").

    s_Info_pop().
}

function p_Direct_Rendevouz {
// Rendevouz the craft with a given target at a given mean anomaly in front of the target.  
    DECLARE Parameter targ TO 0, anomalyOffset TO 0.
    IF (DEFINED layoutDone) = False {
        s_Layout().
    }

    IF SHIP:STATUS <> "ORBITING"
    {
        s_Status("Ship needs to be in orbit").
        RETURN False.
    }

    s_Sub_Prog("p_Direct_Rendevouz").
    s_Status("Checking for Errors").

    SET targ TO a_Check_Target(targ, 1+4+8+16).
    UNTIL targ:TYPENAME <> "BOOLEAN" {
        IF targ:TYPENAME = "BOOLEAN" {
            SET targ TO a_Prompt_Target(True).
        }
        SET targ TO a_Check_Target(targ, 1+4+8+16).
    }
    LOCAL targObt TO targ.
    IF targ:TYPENAME <> "Orbit" {
        SET targObt TO targ:OBT.
    }

    LOCAL dirOutwards TO True.
    IF OBT:SEMIMAJORAXIS > targObt:SEMIMAJORAXIS {
        SET dirOutwards TO False.
        IF OBT:PERIAPSIS < targObt:APOAPSIS {
            s_Status("Error: Orbit-alt intersect").
            RETURN False.
        }
    } ELSE {
        IF OBT:APOAPSIS > targObt:PERIAPSIS {
            s_Status("Error: Orbit-alt intersect").
            RETURN False.
        }
    }

    s_Log("Calculating direct transfer").
    s_Status("Calc. transfer burn").

    LOCAL myANDN TO c_AnDn_Anomaly(OBT, targObt).

    LOCAL k TO targObt:SEMIMAJORAXIS/OBT:SEMIMAJORAXIS.
    LOCAL goal_phase_angle TO m_Clamp(180 - 180 * SQRT((0.5+k/2)^3) / k^(3/2), 360).


    LOCAL phase_angle_per_s TO 360/targObt:PERIOD - 360/OBT:PERIOD.

    LOCAL d_t_offset TO 0.
    LOCAL iterations TO 8.
    For i in RANGE(0,iterations) {
        UNTIL NOT HASNODE {
            REMOVE NEXTNODE.
        }

        // Find roughly the right time to start the transfer
        LOCAL phase_angle TO c_Phase_Angle_after_Nu(OBT, targObt).
        LOCAL current_phase_angle TO phase_angle["TruePhaseAngle"].

        LOCAL d_t_trans TO m_Clamp(current_phase_angle - goal_phase_angle, 360) /-phase_angle_per_s.
        IF phase_angle_per_s > 0 {
            SET d_t_trans TO m_Clamp(goal_phase_angle - current_phase_angle, 360) / phase_angle_per_s.
        }
        SET d_t_trans TO d_t_trans + d_t_offset.
        LOCAL t_trans TO TIME + d_t_trans.

        // Find the radius and true anomaly of the transfer point
        LOCAL my_Nu_trans TO m_Clamp(OBT:TRUEANOMALY + 360*d_t_trans/OBT:PERIOD, 360).
        LOCAL my_r_trans TO c_r_from_Tru(my_Nu_trans).
        
        // Find the radius of the intercept point with the target
        LOCAL tar_r_trans TO c_r_from_Tru(m_Clamp(targObt:TRUEANOMALY + anomalyOffset + 360*d_t_trans/targObt:PERIOD + 180 - goal_phase_angle,360)
                                        ,targObt).

        // Calculate my velocity change at the transfer point
        LOCAL my_v_0_trans TO c_Orbit_Velocity_Vector(my_Nu_trans).
        LOCAL my_v_1_trans TO c_Orb_Vel(0,my_r_trans, tar_r_trans, my_r_trans, 0).
        LOCAL trans_node TO c_Circ_Man(d_t_trans, my_v_0_trans, LIST(my_v_1_trans, 0), 0).
        ADD trans_node.

        // Calculate the height, true anomaly and eccentricity of the transfer orbit at the inclination change
        LOCAL r_inc_ch TO trans_node:ORBIT:SEMIMAJORAXIS.
        LOCAL ec_inc_ch TO trans_node:ORBIT:ECCENTRICITY.
        LOCAL Nu_inc_ch TO c_Tru_from_r(r_inc_ch, trans_node:ORBIT).

        IF (dirOutwards = False AND Nu_inc_ch < 180) OR (dirOutwards = True AND Nu_inc_ch > 180) {
            SET Nu_inc_ch TO 360 - Nu_inc_ch.
        }
        LOCAL M_inc_ch TO c_Mean_An_from_Tru(Nu_inc_ch, trans_node:ORBIT).
        IF (dirOutwards = False AND M_inc_ch < 180) OR (dirOutwards = True AND M_inc_ch > 180) {
            SET M_inc_ch TO 360 - M_inc_ch.
        }

        // Calculate the time of the inclination change
        LOCAL d_t_inc_ch TO c_Time_from_MeanAn(m_Clamp(M_inc_ch, 180), trans_node:ORBIT).
        SET d_t_inc_ch TO d_t_inc_ch + (t_trans - TIME):SECONDS.
        LOCAL t_inc_ch TO d_t_inc_ch + TIME.

        // Calculates the needed inclination change for a close encounter
        LOCAL d_ang_encounter TO SIN(m_Clamp(myANDN["AN"]["TrueAn"] - my_Nu_trans, 360))^2 * myANDN["relInc"].
        LOCAL beta_inc_ch TO ARCTAN(TAN(d_ang_encounter)/SIN(180 - Nu_inc_ch)).
        IF m_Clamp(myANDN["AN"]["TrueAn"] - my_Nu_trans, 360) < 180 {
            SET beta_inc_ch TO -beta_inc_ch. 
        }
        IF dirOutwards = False {
            SET beta_inc_ch TO -beta_inc_ch. 
        }

        LOCAL v_0_inc_ch TO c_Orbit_Velocity_Vector(Nu_inc_ch, r_inc_ch, ec_inc_ch).

        LOCAL inc_node TO c_Circ_Man(d_t_inc_ch, v_0_inc_ch, v_0_inc_ch, -beta_inc_ch).
        ADD inc_node.

        // Get the closest encounter and the phase angle at the encounter.
        LOCAL encounters TO c_Closest_Approach(inc_node:ORBIT, targObt, anomalyOffset, 0, 360, inc_node:ORBIT:TRUEANOMALY, inc_node:ORBIT:EPOCH).
        LOCAL minDist TO encounters[0][5] * 3.
        LOCAL minEnc TO LIST().
        FOR enc in encounters {
            IF enc[0] < minDist {
                SET minEnc TO enc.
                SET minDist TO enc[0].
            }
        }
        LOCAL Equ_AnModel TO c_Equ_AnModel(inc_node:ORBIT, targObt).
        LOCAL d_Nu TO m_Clamp(minEnc[4] - c_Equ_TruAn(Equ_AnModel, minEnc[2]),90,-270).
        SET d_t_offset TO d_t_offset + d_Nu/-phase_angle_per_s.

        IF i < iterations - 1 {
            REMOVE trans_node.
            REMOVE inc_node.
        }
    }
    p_Orb_Burn(NEXTNODE).
    p_Orb_Burn(NEXTNODE).

    IF targ:TYPENAME = "Vessel" {
        p_Match_Orbit(targ, 0.05, anomalyOffset).
    }
}

function p_Match_Orbit {
// Matches orbital velocity at the closest approach
    DECLARE Parameter targ TO 0, maxDist TO 0.02, anomalyOffset TO 0.

    IF (DEFINED layoutDone) = False {
        s_Layout().
    }

    IF SHIP:STATUS <> "ORBITING"
    {
        s_Status("Ship needs to be in orbit").
        RETURN False.
    }

    s_Sub_Prog("p_Match_Orbit").
    s_Status("Checking for Errors").

    SET targ TO a_Check_Target(targ, 1+8+16).
    UNTIL targ:TYPENAME <> "BOOLEAN" {
        IF targ:TYPENAME = "BOOLEAN" {
            SET targ TO a_Prompt_Target(True).
        }
        SET targ TO a_Check_Target(targ, 1+8+16).
    }
    LOCAL targObt TO targ.
    IF targ:TYPENAME <> "Orbit" {
        SET targObt TO targ:OBT.
    }

    s_Status("Get closest intersect").
    LOCAL encounters TO c_Closest_Approach(OBT, targObt, anomalyOffset).
    s_Log("Calculated matching maneuver").
    LOCAL minDist TO encounters[0][5] * 3.
    LOCAL minEnc TO LIST().
    FOR enc in encounters {
        IF enc[0] < minDist {
            SET minEnc TO enc.
            SET minDist TO enc[0].
        }
    }
    IF minDist > maxDist * minEnc[5] {RETURN False.}

    LOCAL myANDN TO c_AnDn_Anomaly().
    LOCAL incChange TO myANDN["relInc"].
    IF m_Clamp(myANDN["AN"]["TrueAn"] - OBT:TRUEANOMALY, 360) < m_Clamp(myANDN["DN"]["TrueAn"] - OBT:TRUEANOMALY, 360) {
        SET incChange TO - incChange.
    }

    LOCAL v_0 TO c_Orbit_Velocity_Vector(minEnc[2]).
    LOCAL v_1 TO c_Orbit_Velocity_Vector(minEnc[4], targObt:SEMIMAJORAXIS, targObt:ECCENTRICITY, targObt:BODY:MU).
    LOCAL t_burn TO c_Time_from_MeanAn(m_Clamp(minEnc[1] - c_MeanAN(),360)).

    IF minDist < 200 {
        LOCAL vRel TO SQRT((v_0[0]-v_1[0])^2 + (v_0[1]-v_1[1])^2).
        set t_burn TO t_burn - (200 - minDist)/vRel.
    }

    LOCAL burnNode TO c_Circ_Man(t_burn, v_0, v_1, -incChange).
    p_Orb_Burn(burnNode).
    s_Log("Orbit matched").
    RETURN True.
}

function p_Close_Dist {
// closes the distance to the target if they are already close together in orbit
    DECLARE Parameter targ IS 0.

    LOCAL maxSpeed TO 25.

    IF (DEFINED layoutDone) = False {
        s_Layout().
    }

    IF SHIP:STATUS <> "ORBITING"
    {
        s_Status("Ship needs to be in orbit").
        RETURN False.
    }

    s_Sub_Prog("p_Close_Dist").
    s_Status("Checking Target").

    SET targ TO a_Check_Target(targ, 1+8).
    UNTIL targ:TYPENAME <> "BOOLEAN" {
        IF targ:TYPENAME = "BOOLEAN" {
            SET targ TO a_Prompt_Target(True).
        }
        SET targ TO a_Check_Target(targ, 1+8).
    }
    LOCAL targObt TO targ.
    IF targ:TYPENAME <> "Orbit" {
        SET targObt TO targ:OBT.
    }

    LOCAL LOCK dist_raw TO targ:POSITION - SHIP:POSITION.
    LOCAL LOCK vel_raw TO OBT:VELOCITY:ORBIT - targObt:VELOCITY:ORBIT.

    IF dist_raw:MAG > 0.1 * (ALTITUDE + BODY:RADIUS) {
        s_Status("Vessels too far apart").
        RETURN False.
    } ELSE IF dist_raw:MAG < 201 {
        s_Status("Vessels  close enough").
        RETURN False.
    }

    LOCAL v_Pro TO PROGRADE:FOREVECTOR.
    LOCAL v_Rad TO PROGRADE:TOPVECTOR.
    LOCAL v_Nor TO -PROGRADE:STARVECTOR.
    
    LOCAL LOCK vel TO V(VDOT(v_Pro, vel_raw), VDOT(v_Rad, vel_raw), VDOT(v_Nor, vel_raw)).
    LOCAL LOCK dist TO V(VDOT(v_Pro, dist_raw), VDOT(v_Rad, dist_raw), VDOT(v_Nor, dist_raw)).

    LOCAL LOCK acc TO MAX(AVAILABLETHRUST,0.0001)/MASS.

    LOCAL transSpeed TO MIN(maxSpeed, 3*acc*SQRT((dist:MAG-200)/acc)).

    LOCAL burnTime TO transSpeed/acc.                                           // time for one start or stop burn
    LOCAL coastTime TO (dist:MAG-200)/transSpeed - transSpeed/acc.              // time spent coasting

    LOCAL LOCK targVelVec TO (transSpeed + 1) * dist_raw:NORMALIZED.
    LOCAL LOCK dVelVec TO targVelVec - vel_raw.

    SAS OFF.
    RCS OFF.
    LOCK STEERING TO LOOKDIRUP(dVelVec,UP:VECTOR).

    s_Log("Burning to close distance").

    WAIT UNTIL VANG(dVelVec, FACING:VECTOR) < 10.
    LOCK THROTTLE TO ((dVelVec:MAG/10)^2+0.02)*20/acc.
    s_Info_push("deltaV:", round(dVelVec:MAG-1,1) + " m/s ").
    UNTIL dVelVec:MAG < 1{
        a_Stage().
        s_Info_ref("", round(dVelVec:MAG-1,1) + " m/s ").
        WAIT 0.
    }
    LOCK THROTTLE TO 0.
    s_Info_pop().

    LOCAL LOCK etaTime TO (dist:MAG-200)/transSpeed - 1/2 * transSpeed/acc.     // time until deceleration

    UNTIL etaTime < 30 {
        IF etaTime > 150 {
            a_Warp_To(100).
            WAIT UNTIL VANG(dVelVec, FACING:VECTOR) < 10.
            LOCK THROTTLE TO ((dVelVec:MAG/10)^2+0.02)*20/acc.
            s_Info_push("deltaV:", round(dVelVec:MAG-1,1) + " m/s ").
            UNTIL dVelVec:MAG < 1{
                a_Stage().
                s_Info_ref("", round(dVelVec:MAG-1,1) + " m/s ").
                WAIT 0.
            }
            LOCK THROTTLE TO 0.
            s_Info_pop().
        } ELSE {
            LOCK STEERING TO LOOKDIRUP(dVelVec, UP:VECTOR).
            WAIT UNTIL (VANG(dVelVec, FACING:VECTOR) < 10).
            a_Warp_To(etaTime - 30).
        }
    }
    UNLOCK targVelVec.
    LOCAL targVelVec TO -1 * dist_raw:NORMALIZED.
    WAIT UNTIL (etaTime < 0).
    LOCK THROTTLE TO ((dVelVec:MAG/10)^2+0.02)*20/acc.
    s_Info_push("deltaV:", round(dVelVec:MAG-1,1) + " m/s ").
    UNTIL dVelVec:MAG < 1{
        a_Stage().
        s_Info_ref("", round(dVelVec:MAG-1,1) + " m/s ").
        WAIT 0.
    }
    LOCK THROTTLE TO 0.
    s_Info_pop().
    s_Log("Distance closed").
}

function p_Dock {
// Docks with a fitting Docking Port on the target vessel
    DECLARE Parameter targ TO 0.

    IF (DEFINED layoutDone) = False {
        s_Layout().
    }

    IF SHIP:STATUS <> "ORBITING"
    {
        s_Status("Ship needs to be in orbit").
        RETURN False.
    }

    s_Sub_Prog("p_Dock").
    s_Status("Checking Target").

    SET targ TO a_Check_Target(targ, 1+2+8).
    UNTIL targ:TYPENAME <> "BOOLEAN" {
        IF targ:TYPENAME = "BOOLEAN" {
            SET targ TO a_Prompt_Target(True).
        }
        SET targ TO a_Check_Target(targ, 1+2+8).
    }
    LOCAL targObt TO targ.
    IF targ:TYPENAME <> "Orbit" {
        SET targObt TO targ:OBT.
    }

    IF (targ:POSITION - ship:POSITION):MAG > 1000 {
        s_Status("Too far apart").
        RETURN False.
    }

    LOCAL smallPort TO 0.
    LOCAL medPort TO 0.
    LOCAL bigPort TO 0.

    FOR port in SHIP:DOCKINGPORTS {
        IF (port:STATE = "Ready" OR port:STATE = "Disabled") {
            IF port:name = "dockingPort3" {
                SET smallPort TO smallPort + 1.
            } ELSE IF port:name = "dockingPort2" OR port:name = "dockingPort1" OR port:name = "dockingPortLateral" OR port:name = "mk2DockingPort" {
                SET medPort TO medPort + 1.
            } ELSE IF port:name = "dockingPortLarge" {
                SET bigPort TO bigPort + 1.
            }
        }
    }
    IF smallPort + medPort + bigPort = 0 {
        s_Status("Error no port on ship").
        RETURN False.
    }

    LOCAL targPort TO 0.
    LOCAL portType TO 0.

    IF targ:TYPENAME = "DOCKINGPORT" {
        LOCAL portViable TO 1.
        LOCAL pportType TO 0.
        IF (targ:STATE = "Ready") {
            IF smallPort AND targ:name = "dockingPort3" {
                SET pportType TO 1.
            } ELSE IF medPort AND targ:name = "dockingPort2" OR targ:name = "dockingPort1" OR targ:name = "dockingPortLateral" OR targ:name = "mk2DockingPort" {
                SET pportType TO 2.
            } ELSE IF bigPort AND targ:name = "dockingPortLarge" {
                SET pportType TO 3.
            } ELSE {
                SET portViable TO 0.
            }
        } ELSE {
            SET portViable TO 0.
        }
        IF portViable {
            SET targPort TO targ.
            SET portType TO pportType.
        } ELSE {
            SET targ TO targ:SHIP.
        }
    }

    IF targ:TYPENAME = "VESSEL" {
        LOCAL bestFacing TO 180.
        LOCAL bestDist TO 2000.

        FOR port in targ:DOCKINGPORTS {
            LOCAL portViable TO 1.
            LOCAL pportType TO 0.
            IF (port:STATE = "Ready") {
                IF smallPort AND port:name = "dockingPort3" {
                    SET pportType TO 1.
                } ELSE IF medPort AND port:name = "dockingPort2" OR port:name = "dockingPort1" OR port:name = "dockingPortLateral" OR port:name = "mk2DockingPort" {
                    SET pportType TO 2.
                } ELSE IF bigPort AND port:name = "dockingPortLarge" {
                    SET pportType TO 3.
                } ELSE {
                    SET portViable TO 0.
                }
            } ELSE {
                SET portViable TO 0.
            }
            IF portViable {
                LOCAL pFacing TO VANG(port:FACING:VECTOR, (SHIP:POSITION - port:POSITION):NORMALIZED).
                LOCAL pDist TO (SHIP:POSITION - port:POSITION):MAG.
                IF 15/90*pFacing + pDist - 5* pportType < 15/90*bestFacing + bestDist - 5*portType {
                    SET targPort TO port.
                    SET bestFacing TO pFacing.
                    SET bestDist TO pDist.
                    SET portType TO pportType.
                }
            }
        }
        IF targPort <> 0 {
            SET TARGET TO targPort.
        } ELSE {
            s_Status("Error: No fitting port").
            RETURN False.
        }
    }

    LOCAL myPort TO 0.
    FOR port in SHIP:DOCKINGPORTS {
        LOCAL pType TO 0.
        IF port:name = "dockingPort3" {
            SET pType TO 1.
        } ELSE IF port:name = "dockingPort2" OR port:name = "dockingPort1" OR port:name = "dockingPortLateral" OR port:name = "mk2DockingPort" {
            SET pType TO 2.
        } ELSE IF port:name = "dockingPortLarge" {
            SET pType TO 3.
        }
        IF pType = portType AND (port:STATE = "Ready" OR port:STATE = "Disabled") {
            SET myPort TO port.
            IF myPort = SHIP:CONTROLPART {
                BREAK.
            }
        }
    }
    IF myPort:TYPENAME = "DOCKINGPORT" {
        myPort:controlfrom().
        IF myPort:STATE = "Disabled" {
            TOGGLE ag10.
        }
    } ELSE {
        RETURN False.
    }

    s_Log("Starting docking procedure").
    s_Status("Translating to dock.").
    dock_with_port(0, 1, 0, 1, 1).
    s_Log("Docked").
}