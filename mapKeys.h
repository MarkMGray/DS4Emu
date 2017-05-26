R3 = DOWN(59);
dpadRight = DOWN(124);
dpadDown = DOWN(125);
options = DOWN(48);
L2 = rightMouse;
X = DOWN(49);
R2 = leftMouse;
leftX = leftY = 0;
if(DOWN(0)) leftX -= 1;
O = DOWN(8);
if(DOWN(2)) leftX += 1;
L1 = DOWN(5);
L3 = DOWN(56);
dpadUp = DOWN(126);
triangle = DOWN(12);
PS = DOWN(35);
if(DOWN(1)) leftY += 1;
square = DOWN(15);
touchpad = DOWN(17);
if(DOWN(13)) leftY -= 1;
R1 = DOWN(9);
dpadLeft = DOWN(123);
if(mouseMoved) {
	rightX = -mouseAccelX;
	rightY = mouseAccelY;
	mouseMoved = false;
} else {
	rightX /= 10;
	rightY /= 10;
	if(fabs(rightX) > 0.1 || fabs(rightY) > 0.1) {
		NSLog(@"Still decaying... %f %f", rightX, rightY);
		//[self decayKick];
	} else {
		rightX = rightY = 0;
	}
}
