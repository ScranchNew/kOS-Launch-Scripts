@LAZYGLOBAL OFF.

//KOS
//  undo the lastmost drawing by diraxesdraw
//

IF (DEFINED draws) = False {
  GLOBAL draws TO list().
}

LOCAL axisNum to draws[draws:length-1]:length -1.
UNTIL axisNum < 0 {
  LOCAL thisOne to draws[draws:length-1][axisNum].
  SET thisOne:SHOW to false.
  draws[draws:length-1]:REMOVE(axisNum).
  SET axisNum to axisNum - 1.
}.
draws:REMOVE(draws:length-1).
