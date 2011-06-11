/*
 * (C) 2008 Dirk W. Hoffmann. All rights reserved.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#import <Cocoa/Cocoa.h>

#import <Cocoa/Cocoa.h>

// Initial viewpoint translation values eyeX, eyeY, and eyeZ
// On a real C64, the upper and lower border are of different height and the left and right border are of different width
// The following values will be used to adjust the viewpoint such that the initial screen shows up in a centered position
#define NTSC_INITIAL_EYE_X 0.000000
#define NTSC_INITIAL_EYE_Y -0.024490
#define NTSC_INITIAL_EYE_Z 0.0
//0.065306
#define PAL_INITIAL_EYE_X 0.016327
#define PAL_INITIAL_EYE_Y 0.008163
#define PAL_INITIAL_EYE_Z 0.0
// 0.065306

/* System */
extern NSString *VC64PALorNTSCKey;
extern NSString *VC64BasicRomFileKey;
extern NSString *VC64CharRomFileKey;
extern NSString *VC64KernelRomFileKey;
extern NSString *VC64VC1541RomFileKey;

/* Peripherals */
extern NSString *VC64WarpLoadKey;

/* Audio */
extern NSString *VC64SIDFilterKey;

/* Video */
extern NSString *VC64EyeX;
extern NSString *VC64EyeY;
extern NSString *VC64EyeZ;
extern NSString *VC64ColorSchemeKey;
extern NSString *VC64VideoFilterKey;

@interface PropertiesDialog : NSWindow
{
    C64Proxy *c64;
    MyController *controller;
    
	/* System */
	IBOutlet NSButtonCell *pal;
	IBOutlet NSButtonCell *ntsc;
	IBOutlet NSMatrix *palntsc;
	IBOutlet NSButton *flag;
	IBOutlet NSTextField *systemText1;
	IBOutlet NSTextField *systemText2;
	IBOutlet NSTextField *systemText3;
	
	/* Peripherals */
	IBOutlet NSButton *warpLoad;
	
	/* Audio */
	IBOutlet NSButton *SIDFilter;
	
	/* Video */
	int customColor[16];
	IBOutlet NSSlider *eyeXSlider;
	IBOutlet NSSlider *eyeYSlider;
	IBOutlet NSSlider *eyeZSlider;
	IBOutlet NSPopUpButton *colorScheme;
	IBOutlet NSPopUpButton *videoFilter;
	IBOutlet NSColorWell *colorWell0;
	IBOutlet NSColorWell *colorWell1;
	IBOutlet NSColorWell *colorWell2;
	IBOutlet NSColorWell *colorWell3;
	IBOutlet NSColorWell *colorWell4;
	IBOutlet NSColorWell *colorWell5;
	IBOutlet NSColorWell *colorWell6;
	IBOutlet NSColorWell *colorWell7;
	IBOutlet NSColorWell *colorWell8;
	IBOutlet NSColorWell *colorWell9;
	IBOutlet NSColorWell *colorWell10;
	IBOutlet NSColorWell *colorWell11;
	IBOutlet NSColorWell *colorWell12;
	IBOutlet NSColorWell *colorWell13;
	IBOutlet NSColorWell *colorWell14;
	IBOutlet NSColorWell *colorWell15;	
}

- (void) initialize:(MyController *)mycontroller;

// Update methods
- (void) update;

// System
- (IBAction)setPalAction:(id)sender;
- (IBAction)setNtscAction:(id)sender;
- (IBAction)togglePalNtscAction:(id)sender;

// VC 1541
- (IBAction)warpLoadAction:(id)sender;

// SID
- (IBAction)SIDFilterAction:(id)sender;

// VIC
- (IBAction)changeColorScheme:(id)sender;
- (IBAction)setVideoFilterAction:(id)sender;
- (IBAction)setEyeXAction:(id)sender;
- (IBAction)setEyeYAction:(id)sender;
- (IBAction)setEyeZAction:(id)sender;

// Action buttons
- (IBAction)useAsDefaultAction:(id)sender;
- (IBAction)factorySettingsAction:(id)sender;


@end