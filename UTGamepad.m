/*
 * Library to inject into UT2004 to make modern gamepads work with UT2004.
 *
 * Copyright (c) 2024 Jonathan Schleifer <js@nil.im>
 *
 * https://github.com/Midar/UTGamepad
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND ISC DISCLAIMS ALL WARRANTIES WITH
 * REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS.  IN NO EVENT SHALL ISC BE LIABLE FOR ANY SPECIAL, DIRECT,
 * INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
 * LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE
 * OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 * PERFORMANCE OF THIS SOFTWARE.
 */

#import <ObjFW/ObjFW.h>
#import <ObjFWHID/ObjFWHID.h>

static enum {
	unknownGame,
	UT99,
	UT2004
} game;
static OFMutableArray *openedControllers = nil;

static void
init(void)
{
	@autoreleasepool {
		OFPlugin *plugin = [OFPlugin pluginWithPath: nil];

		if ([plugin addressForSymbol: @"LocalPackageNameSDLDrv"] != nil)
			game = UT99;
		else if ([plugin addressForSymbol: @"GSDLDrvPackage"] != nil)
			game = UT2004;
		else {
			OFLog(@"Warning: Injected into unknown game!");
			game = unknownGame;
		}
	}

	openedControllers = [[OFMutableArray alloc] init];
}

int
SDL_NumJoysticks(void)
{
	@autoreleasepool {
		return OHGameController.controllers.count;
	}
}

const char *
SDL_JoystickName(int index)
{
	/*
	 * XXX: Unfortunately this is leaky, as the API requires return of an
	 *	unowned string.
	 */
	return OHGameController.controllers[index].name.UTF8String;
}

OHGameController *
SDL_JoystickOpen(int index)
{
	static OFOnceControl onceControl = OFOnceControlInitValue;

	OFOnce(&onceControl, init);

	@autoreleasepool {
		OHGameController *controller =
		    OHGameController.controllers[index];

		if (controller.extendedGamepad == nil)
			return nil;

		@synchronized (openedControllers) {
			[openedControllers addObject: controller];
		}

		return controller;
	}
}

int
SDL_JoystickNumAxes(OHGameController *controller)
{
	switch (game) {
	case UT99:
		/*
		 * UT99 seems to use 0 and 1 for movement and 4 and 5 for
		 * looking.
		 */
		return 6;
	case UT2004:
		/*
		 * UT2004 seems to use 0 and 1 for movement and 5 and 6 for
		 * looking.
		 */
		return 7;
	default:
		return 4;
	}
}

int
SDL_JoystickNumBalls(OHGameController *controller)
{
	/* Queried by UT99 and UT2004, but SDL_JoystickGetBall is never used. */
	return 0;
}

int
SDL_JoystickNumHats(OHGameController *controller)
{
	/* Queried by UT99 and UT2004, but SDL_JoystickGetHat is never used. */
	return 0;
}

int
SDL_JoystickNumButtons(OHGameController *controller)
{
	return 16;
}

void
SDL_JoystickUpdate(void)
{
	@synchronized (openedControllers) {
		for (OHGameController *controller in openedControllers)
			[controller updateState];
	}
}

int16_t
SDL_JoystickGetAxis(OHGameController *controller, int axis)
{
	id <OHExtendedGamepad> gamepad = controller.extendedGamepad;

	switch (game) {
	case UT99:
		switch (axis) {
		case 0:
			return gamepad.leftThumbstick.xAxis.value * 32767;
		case 1:
			/* UT99 wants this axis reversed as the only one?! */
			return gamepad.leftThumbstick.yAxis.value * -32767;
		case 2:
		case 3:
			/* It's requested but its use unknown. */
			return 0;
		case 4:
			return gamepad.rightThumbstick.xAxis.value * 32767;
		case 5:
			return gamepad.rightThumbstick.yAxis.value * 32767;
		}
		break;
	case UT2004:
		switch (axis) {
		case 0:
			return gamepad.leftThumbstick.xAxis.value * 32767;
		case 1:
			return gamepad.leftThumbstick.yAxis.value * 32767;
		case 2:
		case 3:
		case 4:
			/* It's requested but its use unknown. */
			return 0;
		case 5:
			return gamepad.rightThumbstick.xAxis.value * 32767;
		case 6:
			/* UT2004 wants this axis reversed as the only one?! */
			return gamepad.rightThumbstick.yAxis.value * -32767;
		}
		break;
	default:
		switch (axis) {
		case 0:
			return gamepad.leftThumbstick.xAxis.value * 32767;
		case 1:
			return gamepad.leftThumbstick.yAxis.value * 32767;
		case 2:
			return gamepad.rightThumbstick.xAxis.value * 32767;
		case 3:
			return gamepad.rightThumbstick.yAxis.value * 32767;
		}
		break;
	}

	OFLog(@"Warning: Invalid axis %d requested", axis);
	return 0;
}

uint8_t
SDL_JoystickGetButton(OHGameController *controller, int button)
{
	id <OHExtendedGamepad> gamepad = controller.extendedGamepad;

	switch (button) {
	case 0:
		return gamepad.southButton.pressed;
	case 1:
		return gamepad.westButton.pressed;
	case 2:
		return gamepad.eastButton.pressed;
	case 3:
		return gamepad.northButton.pressed;
	case 4:
		return gamepad.leftShoulderButton.pressed;
	case 5:
		return gamepad.rightShoulderButton.pressed;
	case 6:
		return gamepad.leftTriggerButton.pressed;
	case 7:
		return gamepad.rightTriggerButton.pressed;
	case 8:
		return gamepad.leftThumbstickButton.pressed;
	case 9:
		return gamepad.rightThumbstickButton.pressed;
	case 10:
		return gamepad.dPad.left.pressed;
	case 11:
		return gamepad.dPad.right.pressed;
	case 12:
		return gamepad.dPad.up.pressed;
	case 13:
		return gamepad.dPad.down.pressed;
	case 14:
		return gamepad.menuButton.pressed;
	case 15:
		return gamepad.optionsButton.pressed;
	}

	OFLog(@"Warning: Invalid button %d requested", button);
	return 0;
}

void
SDL_JoystickClose(OHGameController *controller)
{
	@synchronized (openedControllers) {
		[openedControllers removeObjectIdenticalTo: controller];
	}
}
