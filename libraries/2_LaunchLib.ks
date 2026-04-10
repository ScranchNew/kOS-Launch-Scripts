// library of kOS functions

@LAZYGLOBAL OFF.

GLOBAL LaunchLib_Loaded TO True.
            
IF (DEFINED LogLib_Loaded) = False OR (DEFINED DeltaVLib_Loaded) = False {
    CD("1:libraries").
    RUNONCEPATH("0_LogLib").
    RUNONCEPATH("1_DeltaVLib").
    CD("1:").
}

// ________________________________________________________________________________________________________________
// a:[Auto] Small functions for improved usability.
// ________________________________________________________________________________________________________________

function a_Stage {
// Checks if staging is neccessary and does if it is
    DECLARE Parameter stageTime TO 2.
            
    IF (DEFINED layoutDone) = False {
        s_Layout().
    }

    IF (DEFINED lastStage) = False
    {
        GLOBAL lastStage TO 0.  // The missiontime the last staging event happened
    }

    // leaves at least "stageTime" seconds between staging actions
    IF missiontime - lastStage > stageTime OR SHIP:STATUS = "Prelaunch"
    {
        LOCAL eng TO 0.
        LIST engines IN eng.

        // Stages if an engine is flamed out, one of the fuel resources is depleted or the ship is in the launch pad

        LOCAL stageFlag TO False.
        IF AVAILABLETHRUST = 0 OR SHIP:STATUS = "Prelaunch"
        {
            SET stageFlag TO True.
        } ELSE {
            FOR e IN eng
            {
                IF e:flameout
                {
                    SET stageFlag TO True.
                    BREAK.
                }
            }
            // The fuels checked are LiquidFuel, Oxidizer and SolidFuel (Not in this order)
            IF  (STAGE:RESOURCES[0]:AMOUNT = 0 AND STAGE:RESOURCES[0]:CAPACITY > 0) OR 
                (STAGE:RESOURCES[2]:AMOUNT = 0 AND STAGE:RESOURCES[2]:CAPACITY > 0) OR
                (STAGE:RESOURCES[4]:AMOUNT = 0 AND STAGE:RESOURCES[4]:CAPACITY > 0) 
            {
                SET stageFlag to True.
            }
        }

        IF stageFlag AND (STAGE:NUMBER > 0)
        {
            IF missiontime > 1  // The launch event will not log
            {
                s_Log("Stage " + STAGE:NUMBER).
            }
            s_Stage(STAGE:NUMBER-1).
            STAGE.
            SET lastStage TO missiontime.
            RETURN True.
        }
    }
    RETURN False.
}

function a_Wait_For_Enter {
// waits until an enter keypress. Great for debugging
    UNTIL False{
        LOCAL nxtchar TO TERMINAL:INPUT:GETCHAR().
        IF nxtchar = TERMINAL:INPUT:RETURN{BREAK.}
    }
}

function a_Warp_To {
// Time warps to or for a specified TIME
// E.g.: a_Warp_To(20, 0) warps 20 seconds into the future
//       a_Warp_To(time:seconds + 20, 1) does the same
    DECLARE Parameter step, mode TO 0, safety TO 1.
            // step: timestamp/TIME amount.
            // mode: switches between relative[0] and absolute[1] TIME warping

    IF (DEFINED layoutDone) = False {
        s_Layout().
    }

    IF mode = 0
    {
        SET step TO TIME:SECONDS + step.
    }

    LOCAL old_Orientation TO FACING.
    IF (step - TIME):SECONDS > 3600 AND safety AND "SUB_ORBITAL, ORBITING, ESCAPING":CONTAINS(SHIP:STATUS) {
        s_Status("Orienting panels").
        SAS off.
        LOCAL safeOrientation TO c_Safe_Orientation().
        LOCK STEERING TO safeOrientation.
        WAIT UNTIL VANG(FACING:VECTOR, safeOrientation:VECTOR) + VANG(FACING:STARVECTOR, safeOrientation:STARVECTOR) < 10.
        a_Warp_To(step - 1200, 1, 0).
        LOCK STEERING TO old_Orientation.
        WAIT UNTIL VANG(FACING:VECTOR, old_Orientation:VECTOR) + VANG(FACING:STARVECTOR, old_Orientation:STARVECTOR) < 10.
    }

    s_Info_push("Time to warp:" , "").

    s_Info_ref("", (step - TIME):CLOCK).

    KUNIVERSE:TIMEWARP:CANCELWARP.
    WAIT 1.
    IF "ORBITING, SUB_ORBITAL, LANDED, PRELAUNCH, ESCAPING":CONTAINS(SHIP:STATUS)
    {
        WarpTo(step-1).
        SET KUNIVERSE:TIMEWARP:MODE TO "RAILS".
        s_Status("On Rails timewarp").
    } ELSE {
        s_Status("Can't warp right now").
    }

    UNTIL (step - TIME:SECONDS) < 120
    {
        s_Info_ref("", (step - TIME):CLOCK).
        IF "ORBITING, SUB_ORBITAL, LANDED, PRELAUNCH, ESCAPING":CONTAINS(SHIP:STATUS)
        {
            WarpTo(step-1).
        SET KUNIVERSE:TIMEWARP:MODE TO "RAILS".
            s_Status("On Rails timewarp").
        } ELSE {
            s_Status("Can't warp right now").
        }
        WAIT 10.
    }
    UNTIL (step - TIME:SECONDS) < 1
    {
        s_Info_ref("", (step - TIME):CLOCK).
        WAIT 0.25.
    }
    s_Info_pop().
}

// ________________________________________________________________________________________________________________
// m:[Math] Simple math functions.
// ________________________________________________________________________________________________________________

function m_Clamp {
// clamps a value via modulo between two values. 
// E.g.: m_Clamp(-45,360, 0) = 325 or m_Clamp(270,180,-180) = -90.
// Great for working with angles.
    DECLARE Parameter val, b_max TO 360, b_min TO 0.
    LOCAL m TO b_max - b_min.
    RETURN MOD(MOD(val, m) - b_min + m, m) + b_min.
}

function m_SINH {
// The sinh(x)
    DECLARE Parameter x.
    Return (CONSTANT:E^x - CONSTANT:E^(-x))/2.
}

function m_COSH {
// The sinh(x)
    DECLARE Parameter x.
    Return (CONSTANT:E^x + CONSTANT:E^(-x))/2.
}

function m_TANH {
// The sinh(x)
    DECLARE Parameter x.
    Return (1 - CONSTANT:E^(-2*x))/(1 + CONSTANT:E^(-2*x)).
}

function m_ARCSINH {
// The inverse of the tanh(x)
    DECLARE parameter x.
    Return LN(x + SQRT(x^2 + 1)).
}

function m_ARCCOSH {
// The inverse of the tanh(x)
    DECLARE parameter x.
    Return LN(x + SQRT(x^2 - 1)).
}

function m_ARCTANH {
// The inverse of the tanh(x)
    DECLARE parameter x.
    Return 0.5*LN((1+x)/(1-x)).
}

function m_Deg_to_Rad {
// Converts degrees to radiant
    DECLARE Parameter deg.
    Return deg*CONSTANT:PI/180.
}

function m_Rad_to_Deg {
// Converts degrees to radiant
    DECLARE Parameter rad.
    Return rad*180/CONSTANT:PI.
}

function m_Line_Circle_Intersect {
// takes a base and a direction vector and a radius r
// Calculates, where the line along the direction vector would intersect a circle of radius r
// Returns a lexicon:
// ["HasInt"] bool : if there is an intersect
// ["Vec_1"] vector: first intersection
// ["Vec_2"] vector: second intersection (can be same as Vec_1)
// ["a_1"] float   : multiple of v_dir to reach first intersect
// ["a_2"] float   : multiple of v_dir to reach second intersect

    DECLARE Parameter v_base, v_dir, rad TO 1.

    LOCAL a TO VDOT(v_dir, v_dir).
    LOCAL b TO VDOT(v_base, v_dir).
    LOCAL c TO VDOT(v_base, v_base) - rad*rad.

    LOCAL root_inp TO b*b - a*c.

    IF root_inp < 0 {
        RETURN lexicon(
            "HasInt", False,
            "Vec_1" , 0*v_dir,
            "Vec_2" , 0*v_dir,
            "a_1"   , 0,
            "a_2"   , 0
        ).
    }
    LOCAL a_fac_1 TO (-b - SQRT(root_inp))/a.
    LOCAL a_fac_2 TO (-b + SQRT(root_inp))/a.

    LOCAL v_int_1 TO v_base + a_fac_1*v_dir.
    LOCAL v_int_2 TO v_base + a_fac_2*v_dir.
    RETURN lexicon(
        "HasInt", True,
        "Vec_1" , v_int_1,
        "Vec_2" , v_int_2,
        "a_1"   , a_fac_1,
        "a_2"   , a_fac_2
    ).
}

// ________________________________________________________________________________________________________________
// c:[Calc] Small functions that RETURN up-to-date calculated information.
// ________________________________________________________________________________________________________________

function c_Orb_Vel {
// RETURN orbital speed at a given altitude for a given orbit
    DECLARE Parameter pBody TO 0, pNode1 TO 0, pNode2 TO 0, pAlt TO 0, goalPos TO 1.
            // pBody:body	,the chosen body
            // pNode1:int	,node1 (Ap/Pe)
            // pNode2:int	,node2 (")
            // pAlt:int	    ,where to calculate the velocity
            // goalPos:int  ,[1] IF distances are measured from the surface of the BODY
            //              ,[0] IF from measured center of the BODY
            
    IF (DEFINED layoutDone) = False {
        s_Layout().
    }

    IF pBody = 0 {SET pBody TO BODY.}
    IF pNode1 = 0 {SET pNode1 TO APOAPSIS.}
    IF pNode2 = 0 {SET pNode2 TO PERIAPSIS.}
    IF pAlt = 0 {SET pAlt TO ALTITUDE.}

    SET pAlt TO pAlt + pBody:RADIUS*goalPos.

    LOCAL SMA TO (pNode1+pNode2)/2+pBody:RADIUS*goalPos.
    RETURN SQRT(pBody:MU*(2/pAlt-1/SMA)).
}

function c_Simple_Man {
// creates a maneuver-node for a pro-/retrograde Apo-/Periapsis burn.
    DECLARE Parameter x1, x2.
            // x1:bool	,at Apoapsis? (1 equals Ap, everything ELSE Pe)
            // x2:int	,new other node altitude
            
    IF (DEFINED layoutDone) = False {
        s_Layout().
    }

    s_Sub_Prog("c_Simple_Man").

    LOCK THROTTLE TO 0.

    LOCAL burnPoint TO PERIAPSIS.
    IF x1 = 1 {
        SET burnPoint TO APOAPSIS.
    }

    LOCAL vdiff TO c_Orb_Vel(0,x2,burnPoint,burnPoint) - c_Orb_Vel(0,0,0,burnPoint).

    LOCAL esta TO ETA:PERIAPSIS.
    IF x1 = 1 {
        SET esta TO ETA:APOAPSIS.
    }

    LOCAL burnNode is Node(TIME:SECONDS+esta,0,0,vdiff).
    RETURN burnNode.
}

function c_Circ_Man {
// calculates a maneuver node for a maneuver given as transition between two combinations of velocities outward and forward in orbit
    DECLARE Parameter dTime, vStart, vEnd, incChange IS 0.
            // dTime:[int]:                         time difference to the start of the manouver
            // vStart:[LIST](vTangential, vRadial): velocity combination at start
            // vEnd:[LIST](vTangential, vRadial):   velocity combination at the end
            // incChange:[float]:                   additional inclination change

            // For example if the radial velocity (pointing in the up-direction) is 0, you are at apoapsis or periapsis.
            // In a circular orbit there is only tangential velocity.

    LOCAL _alpha TO ARCTAN(vStart[1]/vStart[0]).

    LOCAL vec_End TO V( COS(incChange) * vEnd[0],
                        -SIN(incChange) * vEnd[0],
                        vEnd[1]).

    LOCAL vec_Start TO V(vStart[0],
                       0,
                       vStart[1]).

    LOCAL delt_Vec TO vec_End - vec_Start.
    LOCAL man_Vec TO V( COS(_alpha) * delt_Vec:X + SIN(_alpha) * delt_Vec:Z,
                        -SIN(_alpha)* delt_Vec:X + COS(_alpha) * delt_Vec:Z,
                        delt_Vec:Y).
    
    RETURN node(TIME:SECONDS + dTime, man_Vec:Y, man_Vec:Z, man_Vec:X).
}

function c_Inc_Change {
// creates a maneuver-node to change the orbital inclination.
    DECLARE Parameter inc, mode TO 0.
                    // The target inclination either:
                    //      absolute:   mode=[0]
                    //      relative:   mode=[1]
    LOCAL myANDN TO c_AnDn_Anomaly(OBT, 0).
    LOCAL ANnext TO True.
    LOCAL next_Node TO myANDN["AN"].
    IF m_Clamp(next_Node["TrueAn"] - OBT:TRUEANOMALY,180,-180) < 0 {
        SET next_Node TO myANDN["DN"].
        SET ANnext TO False.
    }
    LOCAL myVNode TO c_Orbit_Velocity_Vector(next_Node["TrueAn"]).
    LOCAL deltTime TO c_Time_from_MeanAn(m_Clamp(next_Node[2]-c_MeanAN(),360)).
    IF mode = 0 {
        IF ANnext {
            SET inc TO ABS(myANDN["relInc"]) - inc.
        } ELSE {
            SET inc TO inc - ABS(myANDN["relInc"]).
        }
    }
    RETURN c_Circ_Man(deltTime,myVNode,myVNode,inc).
}

function c_Orbit_Velocity_Vector {
// calculates the radial and tangential components of the orbital velocity of an orbit at a given true anomaly
// The radial velocity is positive in the up direction
// The tangential velocity is always positive
    DECLARE Parameter truAn, orbit_or_sma TO OBT:SEMIMAJORAXIS, _e TO OBT:ECCENTRICITY, _mu TO OBT:BODY:MU.
            // truAn: The true anomaly at that point
            // orbt: The orbit

    //Returns a LIST with [0]: The absolute value of the orbital velocity in the turning direction
    //                    [1]: The value of the orbital velocity in radial outwards direction

    if orbit_or_sma:typename = "Orbit" {
        SET _mu TO orbit_or_sma:BODY:MU.
        SET _e TO orbit_or_sma:ECCENTRICITY.
        SET orbit_or_sma TO orbit_or_sma:SEMIMAJORAXIS.
    }

    LOCAL _h TO SQRT(_mu * orbit_or_sma * (1-_e^2)).
    LOCAL _r TO orbit_or_sma * (1-_e^2) / (1 + _e * COS(truAn)).

    LOCAL v_forw TO _h / _r.
    LOCAL v_rad TO _mu * _e * SIN(truAn) / _h.
    RETURN LIST(v_forw, v_rad).
} 

function c_Orbit_Vector {
// calculates the normal vector of the orbit, the vector pointing along the Ascending Node of the orbit
// and a forward vector perpendicular to both using the solarprimevector as x-axis and north as z-axis.

// !!Warning this is using a right-handed coordinate system!!
// !! Kos and KSP by Default use a left-handed system      !!
    DECLARE Parameter orbit_ref.
    
    LOCAL r_inc TO orbit_ref:INCLINATION.
    LOCAL r_lan TO orbit_ref:LAN.
    LOCAL r_AgPe TO orbit_ref:argumentofperiapsis.
    LOCAL r_nu TO orbit_ref:trueanomaly.
    LOCAL r_Mean TO c_MeanAN(orbit_ref).

    // orbit normal vector
    LOCAL v_n TO v(SIN(r_inc)*SIN(r_lan),-SIN(r_inc)*COS(r_lan),COS(r_inc)).
    // orbit LAN vector
    LOCAL v_Lan TO v(COS(r_lan), SIN(r_lan),0).
    // orbit forward vector (90° ahead of LAN)
    LOCAL v_Forw TO v(-SIN(r_lan)*COS(r_inc), COS(r_lan)*COS(r_inc),SIN(r_inc)).
    // orbit periapsis vector
    LOCAL v_Pe TO cos(r_AgPe)*v_Lan + sin(r_AgPe)*v_Forw.
    // orbit true anomaly vector
    LOCAL v_Nu TO cos(r_AgPe + r_nu)*v_Lan + sin(r_AgPe + r_nu)*v_Forw.
    // orbit true anomaly vector
    LOCAL v_MeanAn TO cos(r_AgPe + r_Mean)*v_Lan + sin(r_AgPe + r_Mean)*v_Forw.
    RETURN lexicon(
        "v_n", v_n,
        "v_Lan", v_Lan,
        "v_Forw", v_Forw,
        "v_Pe", v_Pe,
        "v_Nu", v_Nu,
        "v_MeanAn", v_MeanAn
    ).
}

function c_Angle_From_Ref_Vectors {
// takes in a vector and two reference x/y-vectors 
// returns the angle of the vector in that x/y system
// this assumes x/y are normed and perpendicular
    DECLARE Parameter vec, x_vec, y_vec.

    LOCAL x_part TO VDOT(vec, x_vec).
    LOCAL y_part TO VDOT(vec, y_vec).

    RETURN arcTan2(y_part, x_part).
}

function c_Time_from_MeanAn {
// calculates the time it takes to pass a given amount of mean anomaly given the orbital period
    DECLARE Parameter meaAn, OrbOrPeriod TO OBT.
            // meaAn: the amount of mean anomaly    // OrbOrPeriod: The orbit or the relevant period in s
    IF OrbOrPeriod:TYPENAME = "Orbit" {
        SET OrbOrPeriod TO OrbOrPeriod:PERIOD.
    }
    RETURN(OrbOrPeriod * meaAn/360).
}

function c_Time_between_Tru {
// calculates the time it takes to pass from one true anomaly to the next
    DECLARE Parameter Nu_2, Nu_1 TO OBT:trueanomaly, orb TO OBT.
    RETURN c_Time_from_MeanAn(m_Clamp(c_Mean_An_between_Tru(Nu_2, Nu_1, orb),360), orb).
}

function c_Mean_An_between_Tru {
// calculates the mean anomaly it takes to pass from one true anomaly to the next
    DECLARE Parameter Nu_2, Nu_1 TO OBT:trueanomaly, orb TO OBT.
    RETURN c_Mean_An_from_Tru(Nu_2, orb) - c_Mean_An_from_Tru(Nu_1, orb).
}

function c_MeanAn_from_Time {
// calculates the time it takes to pass a given amount of mean anomaly given the orbital period
    DECLARE Parameter dTime, OrbOrPeriod TO OBT.
            // dTime: the amount of time    // OrbOrPeriod: The orbit or the relevant period in s
    IF OrbOrPeriod:TYPENAME = "Orbit" {
        SET OrbOrPeriod TO OrbOrPeriod:PERIOD.
    }
    RETURN(360 * dTime / OrbOrPeriod).
}

function c_Ecc_An_from_Tru {
// calculates the Eccentric Anomaly from the True one
    DECLARE Parameter Nu TO OBT:TRUEANOMALY, Orb TO OBT.

    LOCAL ec TO Orb:ECCENTRICITY.
    LOCAL E TO 0.

    IF ec < 1 {
        SET E TO m_Clamp(2 * ARCTAN(TAN(Nu/2) * SQRT((1- ec)/(1 + ec))), 360).
    } ELSE {
        SET E TO m_Rad_to_Deg(m_ARCCOSH((ec + COS(Nu))/(1 + ec * COS(Nu)))).
        IF m_Clamp(Nu, 180, -180) < 0 {
            SET E TO -E.
        }
    }
    RETURN E.
}

function c_Mean_An_from_Ecc {
// calculates the Eccentric Anomaly from the True one
    DECLARE Parameter E TO c_Ecc_An_from_Tru(), Orb TO OBT.

    LOCAL ec TO Orb:ECCENTRICITY.

    IF ec < 1 {
        RETURN m_Clamp((m_Rad_to_Deg(m_Deg_to_Rad(E) - ec * SIN(E))), 360).
    } ELSE {
        RETURN m_Rad_to_Deg(ec * m_SINH(m_Deg_to_Rad(E)) - m_Deg_to_Rad(E)).
    }
}

function c_Mean_An_from_Tru {
// calculates the Mean Anomaly from the True one
    DECLARE Parameter Nu TO OBT:TRUEANOMALY, Orb TO OBT.

    LOCAL E TO c_Ecc_An_from_Tru(Nu, Orb).
    RETURN c_Mean_An_from_Ecc(E, Orb).
}

function c_Tru_An_from_Mean {
// calculates the True Anomaly from the Mean one
// As this can't be analytically solved, it is only an approximation and takes a good bit of processing power to make exact.
// I suggest raising the allowed operations per tick for kOS.

    DECLARE Parameter M, Orb TO OBT.

    SET M TO m_Clamp(M, 180, -180).
    LOCAL ec TO Orb:ECCENTRICITY.

    LOCAL err TO 180*ec^3.
    // Initialized with a good approximation
    LOCAL Nu_m TO M + 180/CONSTANT:PI*(2*ec-0.25*ec^3)*sin(M) + 180/CONSTANT:PI*(1.25*ec^2)*sin(2*M) + 180/CONSTANT:PI*(13/12*ec^3)*sin(3*M).
    LOCAL Nu_0 TO 0.
    LOCAL Nu_1 TO 0.
    IF M > 0 {
        SET Nu_0 TO MAX(0, Nu_m - err).
        SET Nu_1 TO MIN(180, Nu_m + err).
    } ELSE {
        SET Nu_0 TO MAX(-180, Nu_m - err).
        SET Nu_1 TO MIN(0, Nu_m + err).
    }
    LOCAL M_m TO m_Clamp(c_Mean_An_from_Tru(Nu_m, Orb), 180, -180).
    UNTIL ABS(M_m - M) < 0.001 {
        IF M_m > M {
            SET Nu_1 TO Nu_m.
            SET Nu_m TO (Nu_0 + Nu_1)/2.
        } ELSE {
            SET Nu_0 TO Nu_m.
            SET Nu_m TO (Nu_0 + Nu_1)/2.
        }
        SET M_m TO m_Clamp(c_Mean_An_from_Tru(Nu_m, Orb), -180, 180).
    }
    RETURN m_Clamp(Nu_m,360).
}

function c_r_from_Tru {
// calculates the height over the BODY center from the true anomaly
    DECLARE Parameter Nu, Orb TO OBT, ec TO False, sma TO False.

    IF Orb:TYPENAME = "Orbit" {
        IF False = ec   {SET ec TO Orb:ECCENTRICITY.}
        IF False = sma  {SET sma TO Orb:SEMIMAJORAXIS.}
    }

    RETURN sma * (1 - ec^2) / (1 + ec*COS(Nu)).
}

function c_Tru_from_r {
// calculates the true anomaly from the height over the center of the BODY
    DECLARE Parameter r_val, Orb TO OBT, ec TO False, sma TO False.

    IF Orb:TYPENAME = "Orbit" {
        IF False = ec   {SET ec TO Orb:ECCENTRICITY.}
        IF False = sma  {SET sma TO Orb:SEMIMAJORAXIS.}
    }

    RETURN 360 - ARCCOS((sma*(1 - ec^2) - r_val)/(ec*r_val)).
}

function c_Tru_After_t {
// calculates the true anomaly after time t passes

    DECLARE Parameter Orb TO OBT, t TO 0.

    LOCAL Mean TO c_Mean_An_from_Tru(Orb:TRUEANOMALY, Orb) + c_MeanAn_from_Time(t, Orb).
    LOCAL Nu TO c_Tru_An_from_Mean(Mean, Orb).

    RETURN Nu.
}

function c_Orbit_Pos {
// calculates the position in orbit in relation to the parent body and the solarprimevector
// It uses the solarprimevector as x-axis and north as z-axis.

// !!Warning this is using a right-handed coordinate system!!

    DECLARE Parameter Orb TO OBT, Nu TO 0, argPe TO 0, lan TO 0, inc TO 0, ec TO False, sma TO False.

    IF Orb:TYPENAME = "Orbit" {
        IF False = Nu       {SET Nu TO Orb:TRUEANOMALY.}
        IF False = argPe    {SET argPe TO Orb:ARGUMENTOFPERIAPSIS.}
        IF False = lan      {SET lan TO Orb:LAN.}
        IF False = inc      {SET inc TO Orb:INCLINATION..}
    }
    
    LOCAL r_val TO c_r_from_Tru(Nu, Orb, ec, sma).
    RETURN V((-sin(lan)*cos(inc)*sin(Nu + argPe)+cos(lan)*cos(Nu + argPe))*r_val, 
             (sin(lan)*cos(Nu + argPe)+cos(lan)*cos(inc)*sin(Nu + argPe))*r_val,
              sin(inc)*sin(Nu + argPe)*r_val).
}

function c_Orbit_Period {
// calculates the orbit period of a given sma (Semimajoraxis) and mu (BODY:MU / Gravitational parameter) combination
    DECLARE Parameter a, mu TO BODY:MU.
    RETURN 2*CONSTANT:PI * SQRT((a)^3/mu).
}

function c_Sma_From_Period {
// calculates the orbit semi-major axis from the period and the mu (BODY:MU / Gravitational parameter)
    DECLARE Parameter period, mu TO BODY:MU.
    RETURN (((period/(2*CONSTANT:PI)))^2*mu)^(1/3).
}

function c_MeanAN {
// calculates the mean anomaly of an orbit a given time from now
    DECLARE Parameter Orb TO OBT, dTime TO 0.
                    // orb: the orbit 
                    // dTime: time from now
    IF OBT:ECCENTRICITY >= 1 {
        LOCAL Nu TO Orb:TRUEANOMALY.
        RETURN c_Mean_An_from_Tru(Nu, Orb) + SQRT((OBT:BODY:MU)/(-OBT:SEMIMAJORAXIS^3))*(dTime).
    } ELSE {
        RETURN m_Clamp(Orb:MEANANOMALYATEPOCH + 360 * (TIME:SECONDS + dTime - Orb:EPOCH) / Orb:PERIOD, 360).
    }
}

function c_Safe_Orientation {
// calculates an orientation where all extendable solar panels will be exposed as much as possible.

    LOCAL sParts TO SHIP:PARTS.
    LOCAL sPanels TO LIST().
    FOR item IN sParts {
        IF item:name = "largeSolarPanel" {
            sPanels:ADD(LIST(item, 15.25)).
        } ELSE IF item:name = "solarPanels3" OR item:name = "solarPanels4" {
            sPanels:ADD(LIST(item, 1)).
        }
    }
    LOCAL currentVector TO V(0,0,0).
    for panel in sPanels {
        LOCAL pVec TO panel[0]:FACING:STARVECTOR.
        SET pVec TO (pVec*pVec:Y/ABS(pVec:Y)):VEC.
        SET currentVector TO currentVector + panel[1]*pVec.
    }
    SET currentVector TO currentVector:NORMALIZED.
    LOCAL rotVec TO VCRS(currentVector, V(0,1,0)).
    LOCAL neededRotation TO ANGLEAXIS(VANG(currentVector, V(0,1,0)), rotVec).
    LOCAL newFacing TO neededRotation * SHIP:FACING:VECTOR.
    LOCAL newTop TO neededRotation * SHIP:FACING:TOPVECTOR.
    LOCAL newDir TO LOOKDIRUP(newFacing, newTop).
    RETURN newDir.
}

function c_Obt_From_Mission {
// returns an Orbit Object with the desired parameters
// all inputs can be directly taken from the mission description
    DECLARE Parameter Ap, Pe, Inclination, LAN, ArgPe, Bod.
                    // Ap: The Apoapsis
                    // Pe: The Periapsis
                    // LAN: The Longitude of the Ascending Node
                    // ArgPe: The Argument of Periapsis

    LOCAL apo TO max(Ap,Pe) + Bod:RADIUS.
    LOCAL per TO min(Ap,Pe) + Bod:RADIUS.
    LOCAL ecc TO (apo - per)/(apo + per).
    LOCAL sma TO (apo + per) / 2.

    LOCAL this_orbit TO createOrbit(Inclination, ecc, sma, LAN, ArgPe, 0, 0, Bod).
    RETURN this_orbit.
}

// ________________________________________________________________________________________________________________
// p:[Program] Scripts to perform complex maneuvers.
// ________________________________________________________________________________________________________________

function p_Orb_Burn {
// executes a given maneuver-node.
    DECLARE Parameter manNode TO 0.
            //manNode:node	,the manouver node to execute.

    LOCAL dvOffset TO 1.

    IF (DEFINED deltaVdone) = False {
        parseDeltaV().
    }
    IF (DEFINED layoutDone) = False {
        s_Layout().
    }

    IF manNode = 0 {
        IF HASNODE {
            SET manNode TO NEXTNODE.
        } ELSE {
            s_Status("No node to execute").
            RETURN False.
        }
    }
    LOCAL nodeBackup TO LIST().
    FOR node IN allNodes
    {
        IF node <> manNode{
            nodeBackup:ADD(node).
        }
        REMOVE node.
    }
    ADD manNode.

    s_Sub_Prog("p_Orb_Burn").
    s_Info_push("deltaV:", round(manNode:DELTAV:MAG ,2) + " m/s").

    LOCAL LOCK acc TO AVAILABLETHRUST/MASS.
    LOCAL LOCK safeacc TO MAX(acc, 0.001).
    SAS off.

    LOCAL burnMean TO calc_Burn_Mean(manNode:DELTAV:MAG)[0].

    LOCAL scale TO (manNode:DELTAV:MAG + dvOffset)/manNode:DELTAV:MAG.

    SET manNode:PROGRADE TO manNode:PROGRADE * scale.
    SET manNode:RADIALOUT TO manNode:RADIALOUT * scale.
    SET manNode:NORMAL TO manNode:NORMAL * scale.

    LOCK STEERING TO manNode:DELTAV.
    s_Status("turn to maneuver").
    WAIT UNTIL (VANG(FACING:VECTOR, manNode:DELTAV) < 5) OR (manNode:ETA < burnMean + 5).
    // warp to node with TIME for turning and some tolerance
    a_Warp_To(manNode:ETA - burnMean - 5).
    LOCK STEERING TO manNode:DELTAV.

    s_Sub_Prog("p_Orb_Burn").
    WAIT UNTIL manNode:ETA < burnMean.

    // do the burn, THROTTLE down when below 30 m/s.
    LOCK STEERING TO manNode:deltav.
    LOCK THROTTLE TO ((manNode:DELTAV:MAG/20)^2+0.01)*20/safeacc.
    s_Status("burning").

    UNTIL manNode:DELTAV:MAG < dvOffset{
        a_Stage().
        s_Info_ref("", round(manNode:DELTAV:MAG - dvOffset,2) + " m/s ").
        WAIT 0.
    }
    UNLOCK STEERING.
    LOCK THROTTLE TO 0.
    REMOVE manNode.

    s_Status("burn clomplete ").
    FOR node IN nodeBackup
    {
        ADD node.
    }
    s_Info_pop().
    RETURN True.
}

function p_Launch {
// launches into a circular with a given apoapsis, periapsis and inclination
    DECLARE Parameter pAlt1 TO 100000, pAlt2 TO pAlt1, pInc TO 0.
            //pAlt:int	,orbit height
            //pInc:int	,orbit inclination

    LOCAL allowedTWR TO 3.

    LOCAL incPID_ks TO LIST(0.04, 0.07, 0.03).

    IF (DEFINED layoutDone) = False {
        s_Layout().
    }

    IF SHIP:STATUS <> "LANDED" AND SHIP:STATUS <> "PRELAUNCH"
    {
        s_Status("Error: Ship not landed").
        RETURN False.
    }

    LOCAL peAlt TO MIN(pAlt1, pAlt2).
    LOCAL apAlt is MAX(pAlt1, pAlt2).
    SET pInc TO m_Clamp(pInc, 180, -180).

    s_Sub_Prog("p_Launch").

    s_Info_push(LIST("Periapsis:",             "Apoapsis:",              "Obt. inc.:"),
                LIST(round(peAlt/1000) + "km", round(apAlt/1000) + "km", round(pInc) + "°")).

    s_Status("Engine warmup").

    // Initialize thrust calculus
    LOCAL LOCK acc TO AVAILABLETHRUST/MASS.
    LOCAL LOCK safeAcc TO MAX(acc, 0.0001).
    LOCAL LOCK TWR TO safeacc/(BODY:MU/(BODY:RADIUS^2)).
    LOCAL LOCK goalTWR TO min(TWR, allowedTWR).
    LOCAL LOCK maxThrot TO goalTWR/TWR.

    // startup procedure
    LOCAL tnow TO TIME:SECONDS.
    a_Stage().
    IF STAGE:RESOURCESLEX:haskey("SolidFuel") = False
    {
        LOCK THROTTLE TO maxThrot*(TIME:SECONDS - tnow)/3.
        WAIT until (TIME:SECONDS - tnow > 5).
    } ELSE {
        LOCK THROTTLE TO maxThrot*(TIME:SECONDS - tnow)/1.
        WAIT until (TIME:SECONDS - tnow > 1).
    }
    a_Stage().
    LOCK THROTTLE TO maxThrot.
    s_Stage(STAGE:NUMBER - 1).

    // The height, where the rocket flies at an angle of 45°
    LOCAL sheight TO BODY:ATM:HEIGHT/3.
    IF NOT BODY:ATM:EXISTS
    {
        SET sheight TO peAlt/5.
    }

    // Calculates the orbital speed the rocket should have after reaching it's desired inclination.
    LOCAL vRef TO c_Orb_Vel(0, 70000 - BODY:RADIUS, peAlt, MAX(BODY:ATM:HEIGHT, 20000)).

    // Calculates the direction the rocket will steer towards.
    LOCAL Linc TO ARCTAN((vRef * SIN(pInc)/SQRT(2))/(vRef * COS(pInc)/SQRT(2) - VELOCITY:ORBIT:MAG)).
    IF pInc >= 0 
    {
        IF Linc < 0 { SET Linc TO Linc + 180.}
    } ELSE {
        IF Linc > 0 { SET Linc TO Linc - 180.}
    }

    // The above horizon, the rocket steers towards. It follows a log(x) curve.
    LOCAL LOCK Lang TO ARCTAN(sheight/(ALTITUDE * SQRT(MAX(goalTWR, 1)/2))).

    // Start the steering
    LOCK STEERING TO HEADING(90-Linc,Lang).

    LOCAL incSign TO 1.
    IF pInc < 0 {
        SET incSign TO -1.   
    }
    LOCAL LOCK rIncl TO incSign * ORBIT:INCLINATION. // The actual inclination

    // After reaching the desired inclination this PID-LOOP keeps it there by updating Linc.
    LOCAL incPIDon TO False.
    LOCAL incPID TO PIDLOOP(incPID_ks[0], incPID_ks[1], incPID_ks[2], -5, 5).
    SET incPID:SETPOINT TO pInc.


    IF ABS(pInc) > 0.5
    {
        WHEN (ABS(rIncl - pInc) < 0.3 AND Lang < 55) THEN 
        {
            s_Log("Target inclination reached").
            incPID:RESET.
            SET incPIDon TO True.
            ON SHIP:STATUS {incPID:RESET.}
        }
    }

    s_Log("Liftoff!").
    s_Status("ascending").

    WHEN Lang < 80 then
    {
        s_Log("Starting gravity turn").
        s_Status("Gravity turn").
    }

    WHEN ALTITUDE > BODY:ATM:HEIGHT * 0.8 THEN{
        TOGGLE ag1.						// open fairings
        s_Log("Opening fairing").
        LOCAL timeFairing TO MISSIONTIME.
        WHEN missiontime > timeFairing + 5 THEN {
            TOGGLE ag2.                 // solar panels, etc
            s_Log("Deploying electronics").
        }
    }


    UNTIL (APOAPSIS >= peAlt - 1 and SHIP:STATUS	<> "FLYING")		//autostageing and PID
    {
        IF a_Stage() {
            IF AVAILABLETHRUST = 0 {    // Point forward to avoid collisions with stage parts.
                LOCK STEERING TO SRFPROGRADE.
            } ELSE {
                LOCK STEERING TO HEADING(90-Linc,Lang).
            }
        }

        // The change of apoapsis per change of forward speed
        LOCAL dAPdV TO (PERIAPSIS + APOAPSIS + 2*BODY:RADIUS)^2 * SQRT(BODY:MU*(2/(ALTITUDE + BODY:RADIUS) - 2/(PERIAPSIS + APOAPSIS + 2*BODY:RADIUS)))/BODY:MU.
        LOCAL apErr TO apAlt - APOAPSIS.
        LOCAL maxAcc TO apErr/dAPdV.        // Acceleration to reach the target Apoapsis in 1 second
        LOCAL goalThrot TO maxAcc/safeAcc.  // Throttle needed for that

        LOCK THROTTLE TO min(maxThrot, SQRT(max(0, goalThrot))).

        LOCAL PIDinc TO incPID:UPDATE(TIME:SECONDS, rIncl).
        IF incPIDon
        {
            SET Linc TO pInc + PIDinc.
        }

        WAIT 0.
    }

    s_Log("Coast to Apoapsis").
    IF p_Orb_Burn(c_Simple_Man(1, apAlt))			// circularize
    {
        s_Sub_Prog("p_Launch").
        s_Log("Orbit complete").
    } ELSE {
        s_Status("Could not circularize orbit").
        s_Info_pop().
        RETURN False.
    }

    TOGGLE ag3.							// deploy mission hardware
    s_Log("Deploying mission hardware").
    s_Info_pop().
    RETURN True.
}

function p_Launch_To_Rendevouz {
// Launches into an orbit of the same inclination as a given target for a rendevouz.
    DECLARE Parameter targ TO 0.

    IF (DEFINED layoutDone) = False {
        s_Layout().
    }

    IF SHIP:STATUS <> "LANDED" AND SHIP:STATUS <> "PRELAUNCH"
    {
        s_Status("Can't launch in current state").
        RETURN False.
    }

    s_Sub_Prog("p_Launch_To_Rendevouz").
    s_Status("Checking for Errors").

    SET targ TO a_Check_Target(targ, 1+4+8).
    UNTIL targ:TYPENAME <> "BOOLEAN" {
        IF targ:TYPENAME = "BOOLEAN" {
            SET targ TO a_Prompt_Target(True).
        }
        SET targ TO a_Check_Target(targ, 1+4+8).
    }
    LOCAL targObt TO targ.
    IF targ:TYPENAME <> "Orbit" {
        SET targObt TO targ:OBT.
    }

    s_Status("Calculating parameters").

    LOCAL SMA TO (targObt:APOAPSIS + targObt:PERIAPSIS)/2.                                            // calculating a sensible orbit height
    LOCAL minAlt TO BODY:ATM:HEIGHT + 20000.
    LOCAL goalAlt TO BODY:RADIUS / 6.
    LOCAL goalDist TO goalAlt / 6.

    SET goalAlt TO MIN(MIN(SMA - goalDist, goalAlt), targObt:PERIAPSIS).
    IF goalAlt < minAlt {
        SET goalAlt TO SMA + goalDist.
    }

    LOCAL vRef TO c_Orb_Vel(0, 70000 - BODY:RADIUS, goalAlt, MAX(BODY:ATM:HEIGHT, 20000)).	            // calculating when to start the launch

    IF (DEFINED deltaVdone) = False {
        parseDeltaV().
    }

    LOCAL insertTime TO calc_Burn_Mean(vRef).
    SET insertTime TO 5 + insertTime[1] - insertTime[0]/SQRT(2).

    LOCAL insertLanAng TO insertTime*360 / BODY:ROTATIONPERIOD.

    LOCAL upVec TO UP:FOREVECTOR.
    LOCAL forVec TO VCRS(NORTH:FOREVECTOR, UP:FOREVECTOR).
    LOCAL solVec TO SOLARPRIMEVECTOR.
    LOCAL upProd TO VDOT(upVec, solVec).
    LOCAL forProd TO VDOT(forVec, solVec).
    LOCAL lanAng TO m_Clamp(ARCCOS(upProd), 360).
    IF forProd < 0 {SET lanAng TO 360 - lanAng.}

    LOCAL dLan TO m_Clamp(targObt:LAN - lanAng - insertLanAng, 360).
    LOCAL goalInc TO targObt:INCLINATION.
    IF dLan > 180 {
        SET dLan TO dLan - 180.
        SET goalInc TO -goalInc.
    }
    LOCAL dTime TO dLan / 360 * BODY:ROTATIONPERIOD.
    LOCAL dTTime TO TIME - (TIME - dTime):SECONDS.

    IF ABS(goalInc) > 1.5 {
        s_Status("Calculations complete").
        s_Log(LIST("Launch calculations complete:", "Wait " + dTTime:CLOCK + " for launch")).
        a_Warp_To(dTime).
    }
    p_Launch(goalAlt, goalAlt, goalInc).
}

// [QUIT] Always called last in a scrip. Closes everything.
// _________________________________________________

function Quit {
// call last in a script. Asks user to quit the program so it stays in a controlled state

    IF (DEFINED layoutDone) = False {
        s_Layout().
    }

    s_Info_Clear().

    s_Sub_Prog("Quit").
    s_Log("program ended").

    LOCK THROTTLE to 0.
    LOCAL safeOrientation TO c_Safe_Orientation().
    Sas OFF.
    LOCK STEERING TO safeOrientation.
    Brakes OFF.
    s_Info_push("Use brakes to ", "quit !").
    WAIT until brakes.				// using brakes finishes program
    Brakes OFF.
    UNLOCK STEERING.
    Sas ON.
    Rcs OFF.
    s_Layout().
}