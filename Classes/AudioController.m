/*
File: AudioViewController.m
Abstract: View controller class for SpeakHere. Sets up user interface, responds 
to and manages user interaction.

Version: 1.0

Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple Inc.
("Apple") in consideration of your agreement to the following terms, and your
use, installation, modification or redistribution of this Apple software
constitutes acceptance of these terms.  If you do not agree with these terms,
please do not use, install, modify or redistribute this Apple software.

In consideration of your agreement to abide by the following terms, and subject
to these terms, Apple grants you a personal, non-exclusive license, under
Apple's copyrights in this original Apple software (the "Apple Software"), to
use, reproduce, modify and redistribute the Apple Software, with or without
modifications, in source and/or binary forms; provided that if you redistribute
the Apple Software in its entirety and without modifications, you must retain
this notice and the following text and disclaimers in all such redistributions
of the Apple Software.
Neither the name, trademarks, service marks or logos of Apple Inc. may be used
to endorse or promote products derived from the Apple Software without specific
prior written permission from Apple.  Except as expressly stated in this notice,
no other rights or licenses, express or implied, are granted by Apple herein,
including but not limited to any patent rights that may be infringed by your
derivative works or by other works in which the Apple Software may be
incorporated.

The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO
WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
COMBINATION WITH YOUR PRODUCTS.

IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR
DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY OF
CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF
APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

Copyright (C) 2008 Apple Inc. All Rights Reserved.
 
 Modified by: lhunath, 2008
*/


#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "AudioController.h"

#define kLevelMeterWidth	238
#define kLevelMeterHeight	45
#define kLevelOverload		0.9
#define kLevelHot			0.7
#define kLevelMinimum		0.01

void interruptionListenerCallback (
    void	*inUserData,
	UInt32	interruptionState
) {
	// This callback, being outside the implementation block, needs a reference 
	//	to the AudioViewController object
	AudioController *controller = (AudioController *) inUserData;
	
	if (interruptionState == kAudioSessionBeginInterruption) {

		NSLog (@"Interrupted. Stopping playback or recording.");
		
        if (controller.audioPlayer) {
			// if currently playing, pause
			[controller pausePlayback];
			controller.interruptedOnPlayback = YES;
		}

	} else if ((interruptionState == kAudioSessionEndInterruption) && controller.interruptedOnPlayback) {
		// if the interruption was removed, and the app had been playing, resume playback
		[controller resumePlayback];
		controller.interruptedOnPlayback = NO;
	}
}

@implementation AudioController

@synthesize audioPlayer;			// the playback audio queue object
@synthesize soundFileURL;			// the sound file to record to and to play back
@synthesize interruptedOnPlayback;	// this allows playback to resume when an interruption ends. this app does not resume a recording for the user.

- (id) initWithFile: (NSString *) audioFile {

	if(![super init])
        return nil;

    // create the file URL that identifies the file that contains our audio data.
    CFBundleRef bundle = CFBundleGetMainBundle();
    CFURLRef fileURL = CFBundleCopyResourceURL(bundle, (CFStringRef) audioFile, NULL, NULL);
    NSLog (@"Audio file path: %@", fileURL);
		
    // save the sound file URL as an object attribute (as an NSURL object)
    if (fileURL) {
        self.soundFileURL = (NSURL *) fileURL;
        CFRelease(fileURL);
    }
		
    // initialize the audio session object for this application,
    //		registering the callback that Audio Session Services will invoke 
    //		when there's an interruption
    AudioSessionInitialize (
        NULL,
        NULL,
        interruptionListenerCallback,
        self
    );

	return self;
}


// this method gets called (by property listener callback functions) when a recording or playback 
// audio queue object starts or stops. 
- (void) updateUserInterfaceOnAudioQueueStateChange: (AudioQueueObject *) inQueue {

    /*AudioPlayer *player = (AudioPlayer *)inQueue;
    if([player donePlayingFile]) {
        [player openPlaybackFile:[player audioFileURL]];
        [player play];
    }*/
}


// respond to a tap on the Play button. If stopped, start playing. If playing, stop.
- (void) playOrStop {
	
	// if not playing, start playing
	if (self.audioPlayer == nil) {
	
		// before instantiating the playback audio queue object, 
		//	set the audio session category
		UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
		AudioSessionSetProperty (
			kAudioSessionProperty_AudioCategory,
			sizeof(sessionCategory),
			&sessionCategory
		);
			
		AudioPlayer *thePlayer = [[AudioPlayer alloc] initWithURL: self.soundFileURL];
		
		if (thePlayer) {
			self.audioPlayer = thePlayer;
			[thePlayer release];
			
			[self.audioPlayer setNotificationDelegate: self];	// sets up the playback object to receive property change notifications from the playback audio queue object

			// activate the audio session immmediately before playback starts
			AudioSessionSetActive(true);
			[self.audioPlayer play];
		}
		
	// else if playing, stop playing
	} else if (self.audioPlayer) {
	
			[self.audioPlayer setAudioPlayerShouldStopImmediately: YES];
			[self.audioPlayer stop];

			// now that playback has stopped, deactivate the audio session
			AudioSessionSetActive(false);
	}
}

// pausing is only ever invoked by the interruption listener callback function, which
//	is why this isn't an IBAction method(that is, 
//	there's no explicit UI for invoking this method)
- (void) pausePlayback {

	if (self.audioPlayer)
		[self.audioPlayer pause];
}

// resuming playback is only every invoked if the user rejects an incoming call
//	or other interruption, which is why this isn't an IBAction method (that is, 
//	there's no explicit UI for invoking this method)
- (void) resumePlayback {

	// before resuming playback, set the audio session
	// category and activate it
	UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
	AudioSessionSetProperty (
		kAudioSessionProperty_AudioCategory,
		sizeof (sessionCategory),
		&sessionCategory
	);
	AudioSessionSetActive(true);

	[self.audioPlayer resume];
}


-(void) dealloc {
    
    [super dealloc];
    
    [audioPlayer release];
    [soundFileURL release];
}


@end
