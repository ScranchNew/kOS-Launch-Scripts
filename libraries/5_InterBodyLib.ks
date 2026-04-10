// library of kOS functions for interplanetary maneuvers

@LAZYGLOBAL OFF.

GLOBAL InterBodyLib_Loaded TO True.

IF (DEFINED LaunchLib_Loaded) = False OR (DEFINED RendevouzLib_Loaded) = False {
    CD("1:libraries").
    RUNONCEPATH("2_LaunchLib").
    RUNONCEPATH("4_RendevouzLib").
    CD("1:").
}

function p_Insertion {
// Perform an orbital insertion after the next SOI-Change
    DECLARE Parameter Alt1 TO 100000, Alt2 TO Alt1, inc TO 0, targ TO 0, aerobrake TO False.
        // Alt1: New first node after the full insertion (Ap or Pe), 
        // Alt2: New second node after the full insertion, 
        // inc: New inclination after the full insertion.
        // targ: If not 0, the inclination will be relative to a given target
        // aerobrake: TODO

    LOCAL Ap TO max(Alt1, Alt2).
    LOCAL Pe TO min(Alt1, Alt2).

    s_Sub_Prog("p_Insertion").
    IF NOT "ORBITING ESCAPING":CONTAINS(SHIP:STATUS){
        s_Status("ship not in orbit").
        RETURN False.
    }
    IF OBT:TRANSITION = "ENCOUNTER" {
        s_Status("Wait for encounter").
        a_Warp_To(ETA:TRANSITION + 120).
    }

    s_Status("Checking for Errors").

    IF targ <> 0 
    {
        IF NOT "Vessel,Body,SpaceObject,Orbit":CONTAINS(targ:typename){
            SET targ TO 0.
        }
        SET targ TO a_Check_Target(targ, 1+4+8+16).
        UNTIL targ:TYPENAME <> "BOOLEAN" {
            IF targ:TYPENAME = "BOOLEAN" {
                SET targ TO a_Prompt_Target(True).
            }
            SET targ TO a_Check_Target(targ, 1+4+8+16).
        }
        LOCAL targObt TO targ.
        IF targ:TYPENAME <> "Orbit" and targ:HASOBT {
            SET targObt TO targ:OBT.
        }
    }

    // The closest Approach while doing the flyby
    LOCAL pe_insertion TO min(BODY:RADIUS/6, BODY:ATM:HEIGHT + 30000).
    // The Semi-Mayor-Axis should stay the same, but with raised periapsis
    LOCAL ap_insertion TO APOAPSIS + PERIAPSIS - pe_insertion.

    IF ap_insertion < pe_insertion AND ap_insertion + BODY:RADIUS > 0
    {
        s_Status("Orbit too low").
        Return False.
    }

    // First comes a transfer from orbit 0 (the current one) to orbit 1 (a close flyby)

    // Altitude of the first burn to adjust approach (Two minutes from now)
    LOCAL alt_0 TO ALTITUDE + BODY:RADIUS + VERTICALSPEED*120.

    LOCAL Nu_0 TO c_Tru_from_r(alt_0).
    IF m_Clamp((360 - Nu_0) - OBT:TRUEANOMALY, 360) < m_Clamp(Nu_0 - OBT:TRUEANOMALY, 360) {
        SET Nu_0 TO 360 - Nu_0.
    }

    LOCAL vel_0 TO c_Orbit_Velocity_Vector(Nu_0).

    LOCAL d_t_adjustment_burn TO 0.
    IF OBT:ECCENTRICITY >= 1 {
        SET d_t_adjustment_burn TO c_Time_from_MeanAn(c_Mean_An_from_Tru(Nu_0) - c_MeanAN(), 2*CONSTANT:PI*SQRT((-OBT:SEMIMAJORAXIS^3)/BODY:MU)).
    } ELSE {
        SET d_t_adjustment_burn TO c_Time_from_MeanAn(m_Clamp(c_Mean_An_from_Tru(Nu_0) - c_MeanAN(), 360)).
    }

    LOCAL ecc_1 TO (ap_insertion - pe_insertion)/(ap_insertion + pe_insertion + 2*BODY:RADIUS).
    LOCAL sma_1 TO (ap_insertion + pe_insertion)/2 + BODY:RADIUS.
    LOCAL Nu_1 TO c_Tru_from_r(alt_0, False, ecc_1, sma_1).
    LOCAL vel_1 TO c_Orbit_Velocity_Vector(Nu_1, sma_1, ecc_1, BODY:MU).
    IF vel_1[1] / vel_0[1] < 0 {
        SET vel_1[1] TO -vel_1[1].
    }

    LOCAL adjustment_nodes TO c_AnDn_Anomaly(OBT, targ).

    LOCAL inc_0 TO adjustment_nodes["relInc"].
    LOCAL argPe_0 TO OBT:ARGUMENTOFPERIAPSIS.
    LOCAL inc_adjustment TO ARCTAN(SIN(inc_0)*COS(Nu_0+argPe_0)/SQRT(SIN(Nu_0+argPe_0)^2+COS(inc_0)^2*COS(Nu_0+argPe_0)^2)).
    IF inc_0 > 90 {
        SET inc_adjustment TO 180 - inc_adjustment.
    }
    IF adjustment_nodes["DN"]["TrueAn"] > 180 {
        SET inc_adjustment TO - inc_adjustment.
    }

    LOCAL adjustment_burn to c_Circ_Man(d_t_adjustment_burn, vel_0, vel_1, inc_adjustment).
    s_Log("Adjusting insertion approach").
    ADD adjustment_burn.
    p_Orb_Burn(adjustment_burn).
    s_Sub_Prog("p_Insertion").

    LOCAL inc_nodes TO c_AnDn_Anomaly(OBT, targ).
    LOCAL insertion_node TO inc_nodes["AN"].
    LOCAL inc_insertion TO inc_nodes["relInc"] - ABS(inc).
    IF ABS(m_Clamp(inc_nodes["DN"]["TrueAn"], 180, -180)) < ABS(m_Clamp(insertion_node["TrueAn"], 180, -180)) {
        SET insertion_node TO inc_nodes["DN"].
        SET inc_insertion TO -inc_insertion.
    }

    // If the current body has a moon, you want to be below it.
    LOCAL bods TO 0.
    LOCAL safeAlt TO BODY:SOIRADIUS - BODY:RADIUS.

    LOCAL BodChilds TO BODY:ORBITINGCHILDREN.
    FOR Bod IN BodChilds {
        SET safeAlt TO MIN(safeAlt, BOD:ALTITUDE - BOD:SOIRADIUS).
    }
    
    SET safeAlt TO safeAlt/2.

    IF insertion_node["Alt"] < -BODY:RADIUS OR insertion_node["Alt"] > pe_insertion * 5 {
        LOCAL first_insertion TO c_Simple_Man(0, safeAlt).
        s_Log("Safety insertion").
        p_Orb_Burn(first_insertion).
        s_Sub_Prog("p_Insertion").

        SET inc_nodes TO c_AnDn_Anomaly(OBT, targ).
        SET insertion_node TO inc_nodes["AN"].
        SET inc_insertion TO inc_nodes["relInc"] - ABS(inc).
        IF ABS(m_Clamp(inc_nodes["DN"]["TrueAn"], 180, -180)) < ABS(m_Clamp(insertion_node["TrueAn"], 180, -180)) {
            SET insertion_node TO inc_nodes["DN"].
            SET inc_insertion TO -inc_insertion.
        }
    }

    LOCAL d_t_insertion_burn TO 0.
    IF OBT:ECCENTRICITY >= 1 {
        SET d_t_insertion_burn TO c_Time_from_MeanAn(insertion_node["MeanAn"] - c_MeanAN(), 2*CONSTANT:PI*SQRT((-OBT:SEMIMAJORAXIS^3)/BODY:MU)).
    } ELSE {
        SET d_t_insertion_burn TO c_Time_from_MeanAn(m_Clamp(insertion_node["MeanAn"] - c_MeanAN(), 360)).
    }

    LOCAL vel_2 TO c_Orbit_Velocity_Vector(insertion_node["TrueAn"]).

    LOCAL ecc_3 TO (MAX(Ap, safeAlt) - pe_insertion)/(MAX(Ap, safeAlt) + pe_insertion + 2*BODY:RADIUS).
    LOCAL sma_3 TO (MAX(Ap, safeAlt) + pe_insertion + 2*BODY:RADIUS)/2.
    LOCAL Nu_3 TO c_Tru_from_r(insertion_node["Alt"] + BODY:RADIUS, False, ecc_3, sma_3).
    LOCAL vel_3 TO c_Orbit_Velocity_Vector(Nu_3, sma_3, ecc_3, BODY:MU).

    IF vel_2[1] / vel_3[1] < 0 {
        SET vel_3[1] TO -vel_3[1].
    }

    LOCAL insertion_burn to c_Circ_Man(d_t_insertion_burn, vel_2, vel_3, inc_insertion*0).
    s_Log("Insertion").
    ADD insertion_burn.
    p_Orb_Burn(insertion_burn).
    s_Sub_Prog("p_Insertion").

    // 
    SET inc_nodes TO c_AnDn_Anomaly(OBT, targ).
    SET insertion_node TO inc_nodes["AN"].
    IF inc_nodes["DN"]["Alt"] > insertion_node["Alt"] + 45 {
        SET insertion_node TO inc_nodes["DN"].
    }

    LOCAL d_t_inclination_burn TO c_Time_from_MeanAn(m_Clamp(insertion_node["MeanAn"] - c_MeanAN(), 360)).

    LOCAL vel_4 TO c_Orbit_Velocity_Vector(insertion_node["TrueAn"]).
    LOCAL vel_5_mag TO c_Orb_Vel(0, insertion_node["Alt"], pe, insertion_node["Alt"]).
    LOCAL vel_5 TO list(vel_5_mag, 0).
    LOCAL inclination_burn to c_Circ_Man(d_t_inclination_burn, vel_4, vel_5, -inc_insertion*1).
    s_Log("Inclination change and set Pe").
    ADD inclination_burn.
    p_Orb_Burn(inclination_burn).
    s_Sub_Prog("p_Insertion").

    s_Log("Finalizing orbit").
    p_Orb_Burn(c_Simple_Man(0,ap)).
}

function p_Land_vacum {
// TODO
// Lands your ship engine first at some given coordinates
    DECLARE Parameter Long TO 0, Lat TO 0.
        

}