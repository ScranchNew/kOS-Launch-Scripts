//***********************************/
//*		  Auto-docking system		*/
//*				  -					*/
//* © FAITO Aerospace Inc.  -  2059 */
//***********************************/

//	Author : HerrCrazi

@LAZYGLOBAL OFF.

GLOBAL DockLibDone TO True.

function vproj
{
	parameter a.
	parameter b.

	return vdot(a, b) / b:mag.
}

function getSignedMag
{
	parameter vect.
	parameter baseVect.

	local vangle is vang(vect, baseVect).
	if ( vangle > 90 and vangle < 270 )
	{
		return vect:mag.
	} else {
		return -vect:mag.
	}
}

function dock_with_port {
// Docks ship with target
    DECLARE parameter trgt is 0, visual is 1, verbose is 0, v_max is 1, a_max is 1.
    // trgt: Give a docking-port as target or target it manually and pass a 0 as parameter
    // visual: Set visual to true to see some vectors on the screen showing the ship's speed & position
    // verbose: Set verbose to true to print detailed info to the console screen showing the ship's speed & position
    // v_max: maximum velocity in one axis => real maximum is SQRT(3*v_max^2)
    // a_max: the maximum amount the RCS thrusters are allowed to fire

    clearvecdraws().
    if verbose {clearscreen.}

    //PID loop controlling the translation of the vessel
    //Tweaking the PID : 
    //	- Increase the P factor to increase the strengh of the corection. The higher it is, the harder the correction will be (and consume more fuel)
    //	- Increasing the I factor will increase the importance of past errors in the correction. It can help bringing the vessel in line with the target
    //	- Increasing the D factor will make the PID "predict" the future error and adapt the correction to that. This factor will make it slow slightly 
    //	  before reaching the setpoint, which improves precision.


    // this version uses a cascading PID controller (only P right now, because the other parts are not necessary here)

    // This PID tries to control the position of the ship and gives out a velocity, the ship should have to reach that position

    // Always keep p_s lower (like at least 5 times) than p_v or you get oscilations
    LOCAL p_s TO 0.1.
    LOCAL i_s TO 0.
    LOCAL d_s TO 0.
    
    LOCAL PID_s_x to pidloop(p_s,i_s,d_s).
    set PID_s_x:setpoint to 5.

    LOCAL PID_s_y to pidloop(p_s,i_s,d_s).
    set PID_s_y:setpoint to 0.

    LOCAL PID_s_z to pidloop(p_s,i_s,d_s).
    set PID_s_z:setpoint to 0.

    // This PID tries to archieve the velocity given out by the position PID using the RCS thrusters
    LOCAL p_v TO 10.
    LOCAL i_v TO 0.
    LOCAL d_v TO 0.

    LOCAL PID_v_x to pidloop(p_v,i_v,d_v,-a_max,a_max).
    set PID_v_x:setpoint to 0.

    LOCAL PID_v_y to pidloop(p_v,i_v,d_v,-a_max,a_max).
    set PID_v_y:setpoint to 0.

    LOCAL PID_v_z to pidloop(p_v,i_v,d_v,-a_max,a_max).
    set PID_v_z:setpoint to 0.

    rcs off.
    sas off.

    // If a docking port is given as argument it will be targeted

    if trgt = 0 and HASTARGET {
        SET trgt TO TARGET.
    } else {
        SET TARGET TO trgt.
    }

    if HASTARGET and target:targetable
    {
        LOCAL tShip TO trgt:ship.

        LOCAL safeDist TO 0. // distance kept from the target vessel for safety reasons.
        FOR prt in tShip:parts{
            SET safeDist TO MAX((prt:position - tShip:position):MAG, safeDist).
        }
        SET safeDist TO safeDist + 5.

        LOCAL controllingPart to ship:controlpart.

        //LOCK steering to the same orientation than the target's port, but in the opposite direction (so the ship is facing the target port)
        LOCK steering to lookdirup(-trgt:portfacing:forevector, trgt:portfacing:upvector).
        wait until vang(ship:facing:forevector, -trgt:portfacing:forevector) < 5 and vang(ship:facing:upvector, trgt:portfacing:upvector) < 5.
    
        rcs on.

        //Target-centered base, with the x axis pointing forward out of the target
        LOCK vtx to trgt:portfacing:forevector.     //x axis is straight out of the target
        LOCK vty to trgt:portfacing:upvector.		//y axis is straight up out of the target
        LOCK vtz to trgt:portfacing:rightvector.	//z axis is starboard out of the target

        //Ship and target position in SHIP-RAW coordinates
        LOCK spos to ship:controlpart:position.
        LOCK tpos to trgt:position.
        LOCK tspos TO tShip:position.

        LOCK targetVel to tShip:velocity:orbit - ship:velocity:orbit.	//Target-relative velocity

        LOCAL stop to false.

        on BRAKES
        {
            toggle stop.
        }

        LOCAL inSafeZone to False.
        LOCAL portAligned to False.

        until stop or ( trgt:state <> "Ready" and trgt:state <> "PreAttached" )//Press Brakes to stop at any moment
        {
            LOCAL v_ShipToTarget to tpos - spos.	//A vector going from the ship to the target-port
            LOCAL v_ShipToTShip to tspos - spos.     //A vector going from the ship to the target

            //Convert the position vector of the ship relative to the target from SHIP-RAW to target-port-relative coordinates
            LOCAL trgt_x to getSignedMag(vtx * vproj(v_ShipToTarget, vtx), vtx).
            LOCAL trgt_y to getSignedMag(vty * vproj(v_ShipToTarget, vty), vty).
            LOCAL trgt_z to getSignedMag(vtz * vproj(v_ShipToTarget, vtz), vtz).

            //Convert the position vector of the ship relative to the target from SHIP-RAW to target-relative coordinates
            LOCAL tShip_x to getSignedMag(vtx * vproj(v_ShipToTShip, vtx), vtx).
            LOCAL tShip_y to getSignedMag(vty * vproj(v_ShipToTShip, vty), vty).
            LOCAL tShip_z to getSignedMag(vtz * vproj(v_ShipToTShip, vtz), vtz).

            //Same for their relative velocity
            LOCAL targetVel_x to -getSignedMag(vtx * vproj(targetVel, vtx), vtx).
            LOCAL targetVel_y to -getSignedMag(vty * vproj(targetVel, vty), vty).
            LOCAL targetVel_z to -getSignedMag(vtz * vproj(targetVel, vtz), vtz).

            // Now I'm setting the the goal position for the PID controllers

            LOCAL goalPos TO V(0,0,0).
            LOCAL refPos TO V(0,0,0).

            LOCAL tShip_vec TO V(tShip_x, tShip_y, tShip_z).
            LOCAL trgt_vec TO V(trgt_x, trgt_y, trgt_z).

            // Three phases of docking (here in reverse order because of the IF statement)

            IF (trgt_x > SQRT(trgt_y^2 + trgt_z^2)) {
                // 3: Moves in front of the port and the closes in if you are within a 45° arc of the port-facing

                //PRINT "Closing in to dock          " AT (terminal:width / 2, terminal:height - 15).
                SET refPos TO V(trgt_x, trgt_y, trgt_z).
                SET goalPos TO V(3, 0, 0).
                IF (refPos - goalPos):Y^2 + (refPos - goalPos):Z^2 < 0.1^2 OR portAligned {
                    SET portAligned TO True.
                    SET goalPos TO V(0.5,0,0).
                }
            } ELSE IF VANG(tShip_vec, tShip_vec - trgt_vec) < 10 OR inSafeZone {
                // 2: If you are close to the line connecting the port and the target ship center you are allowed to move in and dock

                //PRINT "Translating in front of port" AT (terminal:width / 2, terminal:height - 15).
                SET inSafeZone TO True.
                SET refPos TO V(trgt_x, trgt_y, trgt_z).
                SET goalPos TO V(5, 0, 0).
            } ELSE {
                // 1: Uses fancy (in retrospect quite simple) vector math to get you to stage 2 while staying at a safe distance

                //PRINT "Approach from safe distance " AT (terminal:width / 2, terminal:height - 15).
                SET goalPos TO VCRS(trgt_vec, VCRS(tShip_vec, trgt_vec)).
                SET goalPos TO goalPos:NORMALIZED * safeDist.
                SET refPos TO V(tShip_x, tShip_y, tShip_z).
            }

            set PID_s_x:setpoint TO goalPos:X.
            set PID_s_y:setpoint TO goalPos:Y.
            set PID_s_z:setpoint TO goalPos:Z.

            // Setting the goal velocity using the position pids.

            LOCAL goalVel TO V(-PID_s_x:update(time:seconds, refPos:X), 
                               -PID_s_y:update(time:seconds, refPos:Y), 
                               -PID_s_z:update(time:seconds, refPos:Z)).
                               
            IF goalVel:MAG > v_max {
                SET goalVel TO goalVel:NORMALIZED * v_max.
            }

            // Here you see how the position PIDs set the target velocity for the velocity PIDs.

            set PID_v_x:setpoint        to  goalVel:X.
            set ship:control:fore       to  PID_v_x:update(time:seconds, targetVel_x).

            set PID_v_y:setpoint        to  goalVel:Y.
            set ship:control:top        to -PID_v_y:update(time:seconds, targetVel_y).

            set PID_v_z:setpoint        to  goalVel:Z.
            set ship:control:starboard  to  PID_v_z:update(time:seconds, targetVel_z).

            //Draw some fancy vectors
            if visual
            {
                clearvecdraws().
                LOCAL vdt TO VECDRAW(trgt:position, (trgt:portfacing:forevector) * 1.5, yellow, "Trgt", 1, true, 0.05).
                LOCAL vds TO VECDRAW(spos, (ship:facing:forevector) * 1.5, yellow, "Ship", 1, true, 0.05).

                LOCAL toGoalVec1 TO goalPos-refPos.
                LOCAL toGoalVec2 TO vtx * toGoalVec1:X + vty * toGoalVec1:Y + vtz * toGoalVec1:Z.
                LOCAL toGoal TO VECDRAW( spos, toGoalVec2, white, "Goal", 1, true, 0.1).

                //LOCAL x to VECDRAW( V(0,0,0),-vtx * trgt_x , red, "x", 1, true, 0.1).
                //LOCAL y to VECDRAW( -vtx * trgt_x, -vty * trgt_y , green, "y", 1, true, 0.1).
                //LOCAL z to VECDRAW( -vtx * trgt_x - vty * trgt_y,  -vtz * trgt_z , blue, "z", 1, true, 0.1).

                LOCAL tx to VECDRAW( spos, -vtx * targetVel_x * 10, red, "Tx", 1, true, 0.05).
                LOCAL ty to VECDRAW( spos, -vty * targetVel_y * 10, green, "Ty", 1, true, 0.05).
                LOCAL tz to VECDRAW( spos, -vtz * targetVel_z * 10, blue, "Tz", 1, true, 0.05).
            }

            //Print stuff for debugging or if you like cool numbers
            if verbose {
                print "Dist.    : " + round(refPos:X, 3) + " m      " at (0, terminal:height - 9).
                print "Right    : " + round(refPos:Y, 3) + " m      " at (0, terminal:height - 8).
                print "Up       : " + round(refPos:Z, 3) + " m      " at (0, terminal:height - 7).
        
                print "Vel. X   : " + round(targetVel_x, 3) + " m/s      " at (terminal:width / 2, terminal:height - 9).
                print "Vel. Y   : " + round(targetVel_y, 3) + " m/s      " at (terminal:width / 2, terminal:height - 8).
                print "Vel. Z   : " + round(targetVel_z, 3) + " m/s      " at (terminal:width / 2, terminal:height - 7).

                print "Corr. v_X   : " + round(PID_s_x:output, 3) + " m/s " at (0, terminal:height - 5).
                print "Corr. v_Y   : " + round(PID_s_y:output, 3) + " m/s " at (0, terminal:height - 4).
                print "Corr. v_Z   : " + round(PID_s_z:output, 3) + " m/s " at (0, terminal:height - 3).

                print "Corr. a_X  : " + round(PID_v_x:output,3) + " m/s^2 " at (terminal:width / 2, terminal:height - 5).
                print "Corr. a_Y  : " + round(PID_v_y:output,3) + " m/s^2 " at (terminal:width / 2, terminal:height - 4).
                print "Corr. a_Z  : " + round(PID_v_z:output, 3) + " m/s^2 " at (terminal:width / 2, terminal:height - 3).

                print "Rel. ang : " + round(vang( (-trgt:portfacing:forevector), ship:facing:forevector ),2) +"°   " at (0, terminal:height - 1).
            }
            wait 0.1.
        }

        unlock all.
        set ship:control:neutralize to true.

        sas off.
        clearvecdraws().
    }
}