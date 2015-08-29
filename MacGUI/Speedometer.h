/*
 * (C) 2011 Dirk W. Hoffmann. All rights reserved.
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

@interface Speedometer : NSObject {

	//! Current emulation speed in Mhz
    /*! Updated in updateWithCurrentCycle */
	double mhz;

	//! Current drawing speed in frames per second
    /*! Updated in updateWithCurrentCycle */
	double fps;

    //! Current jitter in clock cycles
    /*! Experimental */
    unsigned jitter;

    //! Stores when updateWithCurrentCycle was called the last time
    long latched_timestamp;

    //! Cycle count in previous call to updateWithCurrentCycle
	long latched_cycle;
	
	//! Previous frame count in previous call to updateWithCurrentCycle
	long latched_frame;
	
}

@property (readonly) double mhz;
@property (readonly) double fps;
@property (readonly) unsigned jitter;

/*!
 @abstract   Updates speed, frame and jitter information.
 @discussion This function needs to be invoked before reading mhz, fps or jitter.
 @param      cycles Current cycle count (processed cycles since emulator power up).
 @param      frame Current frame (processed frames since emulator power up).
 @param      expectedMhz Proposed emulator speed (50 Hz for PAL, 60 Hz for NTSC).
*/
- (void)updateWithCurrentCycle:(long)cycles currentFrame:(long)frame expectedSpeed:(double)expectedMhz;

@end
