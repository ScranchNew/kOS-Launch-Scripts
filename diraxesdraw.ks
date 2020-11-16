@LAZYGLOBAL OFF.

//KOS
// diraxesdraw - Draw the XYZ axes of a given direction (rotation).
//
// Assumes you've already made a list like so:
//  SET DRAWS TO LIST().
// Before calling it the first time.
//
declare parameter dir, baseColor, scale, label.

IF (DEFINED draws) = False {
  GLOBAL draws TO list().
}

draws:add(list()).
LOCAL colorOffset to 0.3.
draws[draws:length-1]:ADD(
  VECDRAWARGS(
    V(0,0,0), dir*V(1,0,0),
    RGB( baseColor:RED+colorOffset, baseColor:GREEN-colorOffset, baseColor:BLUE-colorOffset ),
    label + " X", scale, true, 0.1 ) ).
draws[draws:length-1]:ADD(
  VECDRAWARGS(
    V(0,0,0), dir*V(0,1,0),
    RGB( baseColor:RED-colorOffset, baseColor:GREEN+colorOffset, baseColor:BLUE-colorOffset ),
    label + " Y", scale, true, 0.1 ) ).
draws[draws:length-1]:ADD(
  VECDRAWARGS(
    V(0,0,0), dir*V(0,0,1),
    RGB( baseColor:RED-colorOffset, baseColor:GREEN-colorOffset, baseColor:BLUE+colorOffset ),
    label + " Z", scale, true, 0.1 ) ).

