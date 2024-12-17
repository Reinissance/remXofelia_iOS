//
//  SoundOutputStream.h
//  Created by Lukasz Karluk on 13/06/13.
//  http://julapy.com/blog
//

#pragma once

#import "SoundStream.h"
#import "ABLLink.h"
#import "Audiobus.h"
//#import "ABLLinkSettingsViewController.h"
/*
 * Structure that stores engine-related data that can be changed from
 * the main thread.
 */

typedef struct {
	UInt32 outputLatency; // Hardware output latency in HostTime
	Float64 resetToBeatTime;
	Float64 proposeBpm;
	Float64 quantum;
	BOOL isPlaying;
} EngineData;

/*
 * Structure that stores all data needed by the audio callback.
 */
typedef struct {
	ABLLinkRef ablLink;
	// Shared between threads. Only write when engine not running.
	Float64 sampleRate;
	// Shared between threads. Only write when engine not running.
	Float64 secondsToHostTime;
	// Shared between threads. Written by the main thread and only
	// read by the audio thread when doing so will not block.
	EngineData sharedEngineData;
	// Copy of sharedEngineData owned by audio thread.
	EngineData localEngineData;
	// Owned by audio thread
	UInt64 timeAtLastClick;
} LinkData;

@interface LinkSoundOutputStream : SoundStream

@property (nonatomic) ABAudioFilterPort * abFilter;
@property (nonatomic) Float64 bpm;
//@property (readonly, nonatomic) Float64 beatTime;
@property (nonatomic) Float64 quantum;
@property (nonatomic) BOOL isPlaying;
@property (readonly, nonatomic) BOOL isLinkEnabled;
@property (readonly, nonatomic) ABLLinkRef linkRef;
@property LinkData linkData;
@property (nonatomic) double quantumCount;

//@property (nonatomic) UInt64 counter;

- (ABLLinkRef)getLinkRef;
- (const LinkData *)getLinkData;
- (const double *) getQuantumCountPtr;

- (void)stop;
- (BOOL)isPlaying;

@end
