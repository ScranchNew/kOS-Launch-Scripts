//KOS
//  undo the lastmost drawing by diraxesdraw
//
SET axisNum to draws[draws:length-1]:length -1.
UNTIL axisNum < 0 {
  SET thisOne to draws[draws:length-1][axisNum].
  set thisOne:SHOW to false.
  draws[draws:length-1]:REMOVE(axisNum).
  SET axisNum to axisNum - 1.
}.
draws:REMOVE(draws:length-1).
