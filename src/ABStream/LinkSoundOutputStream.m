//
//  SoundOutputStream.m
//  Created by Lukasz Karluk on 13/06/13.
//  http://julapy.com/blog
//
//  Original code by,
//  Memo Akten, http://www.memo.tv
//  Marek Bareza http://mrkbrz.com/
//  Updated 2012 by Dan Wilcox <danomatika@gmail.com>
//
//  references,
//  http://www.cocoawithlove.com/2010/10/ios-tone-generator-introduction-to.html
//  http://atastypixel.com/blog/using-remoteio-audio-unit/
//  http://www.stefanpopp.de/2011/capture-iphone-microphone/
//

#import "LinkSoundOutputStream.h"
#include <mach/mach_time.h>
#include <libkern/OSAtomic.h>
#include <AudioToolbox/AudioToolbox.h>
#include <AVFoundation/AVFoundation.h>
static OSSpinLock lock;

#define INVALID_BEAT_TIME DBL_MIN
#define INVALID_BPM DBL_MIN
//link structs



//----
/*
 * Pull data from the main thread to the audio thread if lock can be
 * obtained. Otherwise, just use the local copy of the data.
 */
static void pullEngineData(LinkData* linkData, EngineData* output) {
	// Always reset the signaling members to their default state
	output->resetToBeatTime = INVALID_BEAT_TIME;
	output->proposeBpm = INVALID_BPM;
	
	// Attempt to grab the lock guarding the shared engine data but
	// don't block if we can't get it.
	if (OSSpinLockTry(&lock)) {
		// Copy non-signaling members to the local thread cache
		linkData->localEngineData.outputLatency =
		linkData->sharedEngineData.outputLatency;
		linkData->localEngineData.quantum = linkData->sharedEngineData.quantum;
		linkData->localEngineData.isPlaying = linkData->sharedEngineData.isPlaying;
		
		// Copy signaling members directly to the output and reset
		output->resetToBeatTime = linkData->sharedEngineData.resetToBeatTime;
		linkData->sharedEngineData.resetToBeatTime = INVALID_BEAT_TIME;
		
		output->proposeBpm = linkData->sharedEngineData.proposeBpm;
		linkData->sharedEngineData.proposeBpm = INVALID_BPM;
		
		OSSpinLockUnlock(&lock);
	}
	
	// Copy from the thread local copy to the output. This happens
	// whether or not we were able to grab the lock.
	output->outputLatency = linkData->localEngineData.outputLatency;
	output->quantum = linkData->localEngineData.quantum;
	output->isPlaying = linkData->localEngineData.isPlaying;
}//----

/*
 * Render a metronome sound into the given buffer according to the
 * given timeline and quantum.
 */
static void renderMetronomeIntoBuffer(
									  const ABLLinkSessionStateRef session_state,
									  const Float64 quantum,
									  const UInt64 beginHostTime,
									  const Float64 sampleRate,
									  const Float64 secondsToHostTime,
									  const UInt32 bufferSize,
									  UInt64 timeAtLastClick,
									  SInt16* buffer,
									  double* quantumCount
                                      )
{
	
	// The number of host ticks that elapse between samples
	const Float64 hostTicksPerSample = secondsToHostTime / sampleRate ;
	
	for (UInt32 i = 0; i < bufferSize; ++i) {
		// Compute the host time for this sample.
		const UInt64 hostTime = beginHostTime + llround(i * hostTicksPerSample);
		const UInt64 lastSampleHostTime = hostTime - llround(hostTicksPerSample);
		// Only make sound for positive beat magnitudes. Negative beat
		// magnitudes are count-in beats.
		double bb = ABLLinkBeatAtTime(session_state, hostTime, quantum);
		*quantumCount = bb;
	}
}

BOOL bpmFromSession;
BOOL syncedToSession;
BOOL firstSync;
//----

static OSStatus soundOutputStreamRenderCallback(void *inRefCon,
												AudioUnitRenderActionFlags *ioActionFlags,
												const AudioTimeStamp *inTimeStamp,
												UInt32 inBusNumber,
												UInt32 inNumberFrames,
												AudioBufferList *ioData) {
	
	LinkSoundOutputStream * stream = (LinkSoundOutputStream *)inRefCon;
    
    
    AudioBuffer *audioBuffer;
    int bufferSize;
    
        audioBuffer = &ioData->mBuffers[0];
        // clearing the buffer before handing it off to the user
        // this saves us from horrible noises if the user chooses not to write anything
        memset(audioBuffer->mData, 0, audioBuffer->mDataByteSize);
        
        bufferSize = (audioBuffer->mDataByteSize / sizeof(Float32)) / audioBuffer->mNumberChannels;
        bufferSize = MIN(bufferSize, MAX_BUFFER_SIZE / audioBuffer->mNumberChannels);
//    }
    
	
	//--------------- ableton link
	
	// Get a copy of the current link timeline.
	//LinkData linkData = stream.getLinkData;
	
	const ABLLinkSessionStateRef session_state =
    ABLLinkCaptureAudioSessionState(stream.getLinkRef);
    if (!bpmFromSession) {
        //get BPM on start
        stream.bpm = ABLLinkGetTempo(session_state);
    }
	
	// Get a copy of relevant engine parameters.
	EngineData engineData;
	pullEngineData(stream.getLinkData, &engineData);
	
	
	const UInt64 hostTimeAtBufferBegin =
	inTimeStamp->mHostTime + engineData.outputLatency;
    if (!syncedToSession) {
        ABLLinkCommitAudioSessionState(stream.getLinkRef, session_state);
        syncedToSession = ABLLinkIsConnected(stream.getLinkRef);
        if (syncedToSession && bpmFromSession) {
            firstSync = YES;
            [stream syncLink];
        }
    }
	// When playing, render the metronome sound
	
	// Handle a timeline reset
	if (engineData.resetToBeatTime != INVALID_BEAT_TIME) {
		// Reset the beat timeline so that the requested beat time
		// occurs near the beginning of this buffer. The requested beat
		// time may not occur exactly at the beginning of this buffer
		// due to quantization, but it is guaranteed to occur within a
		// quantum after the beginning of this buffer. The returned beat
		// time is the actual beat time mapped to the beginning of this
		// buffer, which therefore may be less than the requested beat
		// time by up to a quantum.
		ABLLinkRequestBeatAtTime(
								 session_state, engineData.resetToBeatTime, hostTimeAtBufferBegin,
								 engineData.quantum);
	}
	
	// Handle a tempo proposal
	if (engineData.proposeBpm != INVALID_BPM) {
		// Propose that the new tempo takes effect at the beginning of
		// this buffer.
		ABLLinkSetTempo(session_state, engineData.proposeBpm, hostTimeAtBufferBegin);
	}
	
	if([stream.delegate respondsToSelector:@selector(soundStreamRequested:output:bufferSize:numOfChannels:)]) {
		[stream.delegate soundStreamRequested:stream
                                       output:(float*)audioBuffer->mData
								   bufferSize:bufferSize
								numOfChannels:audioBuffer->mNumberChannels];
	}
    
	
	
	// When playing, render the metronome sound
	if (engineData.isPlaying) {
		// Only render the metronome sound to the first channel. This
		// might help with source separate for timing analysis.
		renderMetronomeIntoBuffer(
                                  session_state, (!bpmFromSession || firstSync) ? engineData.quantum : stream.quantum, hostTimeAtBufferBegin, stream.getLinkData->sampleRate, (firstSync) ? engineData.resetToBeatTime : stream.getLinkData->secondsToHostTime, inNumberFrames, stream.getLinkData->timeAtLastClick,
                                  (SInt16*)ioData->mBuffers[0].mData, stream.getQuantumCountPtr);
	}
    
    NSNumber *val = [[NSNumber alloc] initWithDouble:stream.quantumCount];
    NSDictionary *dict = [NSDictionary dictionaryWithObjects:@[val, @"linkQuantumCount"] forKeys:@[@"value", @"pdReceiver"]];
    NSNotification *myNotification = [NSNotification notificationWithName:@"linkQuantumCount"
                                                                   object:stream
                                                                 userInfo:dict];
    [[NSNotificationCenter defaultCenter] postNotification:myNotification];
	
    ABLLinkCommitAudioSessionState(stream.getLinkData->ablLink, session_state);
    
    bpmFromSession = YES;
    if (syncedToSession && firstSync) {
        int sync = (int) fmod(stream.quantumCount, stream.quantum);
        NSLog(@"connected: %d, sync: %d, firstsync: %d", ABLLinkIsConnected(stream.getLinkRef), sync, firstSync);
        syncedToSession = (ABLLinkIsConnected(stream.getLinkRef) && (sync == stream.quantum-1));
    }
    else syncedToSession = ABLLinkIsConnected(stream.getLinkRef);
    firstSync = NO;
    
	return noErr;
}

//----------------------------------------------------------------
@interface LinkSoundOutputStream() {
	//
	LinkData _linkData;
}
@end


@implementation LinkSoundOutputStream

- (id)initWithNumOfChannels:(NSInteger)value0
			 withSampleRate:(NSInteger)value1
			 withBufferSize:(NSInteger)value2 {
	self = [super initWithNumOfChannels:value0
						 withSampleRate:value1
						 withBufferSize:value2];
	if(self) {
		streamType = SoundStreamTypeOutput;
//        _counter = 4.;
	}
	
	return self;
}

- (BOOL)isPlaying {
	return _linkData.sharedEngineData.isPlaying;
}

- (const double *) getQuantumCountPtr{
	return &_quantumCount;
}

- (void)setIsPlaying:(BOOL)isPlaying {
	OSSpinLockLock(&lock);
	_linkData.sharedEngineData.isPlaying = isPlaying;
	if (isPlaying) {
		_linkData.sharedEngineData.resetToBeatTime = 0;
	}
	OSSpinLockUnlock(&lock);
}

- (void)setBpm:(Float64)bpm {
	OSSpinLockLock(&lock);
	_linkData.sharedEngineData.proposeBpm = bpm;
	OSSpinLockUnlock(&lock);
    _bpm = bpm;
}

- (void)initLinkData:(Float64)bpm {
    _linkData.ablLink = ABLLinkNew(bpm);
    mach_timebase_info_data_t timeInfo;
    mach_timebase_info(&timeInfo);
    _quantumCount = 0;
    lock = OS_SPINLOCK_INIT;
    _linkData.sampleRate = [[AVAudioSession sharedInstance] sampleRate];
    _linkData.secondsToHostTime = (1.0e9 * timeInfo.denom) / (Float64)timeInfo.numer;
    _linkData.sharedEngineData.outputLatency =
    (UInt32)(_linkData.secondsToHostTime * [AVAudioSession sharedInstance].outputLatency);
    _linkData.sharedEngineData.resetToBeatTime = INVALID_BEAT_TIME;
    _linkData.sharedEngineData.proposeBpm = INVALID_BPM;
    _linkData.sharedEngineData.quantum = 4; // quantize to 4 beats
    _linkData.sharedEngineData.isPlaying = false;
    _linkData.localEngineData = _linkData.sharedEngineData;
    _linkData.timeAtLastClick = 0;
}

- (ABLLinkRef)getLinkRef{
	return _linkData.ablLink;
}

- (const LinkData*)getLinkData{
	return &_linkData;
}


- (void)dealloc {
	[self stop];
    ABLLinkDelete([self getLinkRef]);
	[super dealloc];
}

- (void)handleRouteChange:(NSNotification *)notification {
#pragma unused(notification)
	
	const UInt32 outputLatency =
	(UInt32)(_linkData.secondsToHostTime * [AVAudioSession sharedInstance].outputLatency);
	OSSpinLockLock(&lock);
	_linkData.sharedEngineData.outputLatency = outputLatency;
	OSSpinLockUnlock(&lock);
}

- (void)start {
	
	[super start];
	
    if([self isStreaming] == YES) {
        return; // already running.
    }
    
	///custome ableton link
	[self initLinkData:120];
    _bpm = 120;
    _quantum = 4;
	
	[self configureAudioSession];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(handleRouteChange:)
												 name:AVAudioSessionRouteChangeNotification
											   object:[AVAudioSession sharedInstance]];
	
	
	//---------------------------------------------------------- audio unit.
	
	// Configure the search parameters to find the default playback output unit
	// (called the kAudioUnitSubType_RemoteIO on iOS but
	// kAudioUnitSubType_DefaultOutput on Mac OS X)
	AudioComponentDescription desc = {
		.componentType         = kAudioUnitType_Output,
		.componentSubType      = kAudioUnitSubType_RemoteIO,
		.componentManufacturer = kAudioUnitManufacturer_Apple,
		
	};
	
	// get component and get audio units.
	AudioComponent inputComponent = AudioComponentFindNext(NULL, &desc);
	[self checkStatus:AudioComponentInstanceNew(inputComponent, &audioUnit)];
	
	//---------------------------------------------------------- enable io.
	
	// enable output out of AudioUnit.
    UInt32 on = 1;
    [self checkStatus:AudioUnitSetProperty(audioUnit,
                                           kAudioOutputUnitProperty_EnableIO,
                                           kAudioUnitScope_Output,
                                           kOutputBus,
                                           &on,
                                           sizeof(on))];
    
    UInt32 enableInput = 0;    // to enable input
    //    AudioUnitElement inputBus = 1;
    
    AudioUnitSetProperty (
                          audioUnit,
                          kAudioOutputUnitProperty_EnableIO,
                          kAudioUnitScope_Input,
                          kInputBus,
                          &enableInput,
                          sizeof (enableInput)
                          );
	
	//---------------------------------------------------------- format.
    
    // Describe format
    AudioStreamBasicDescription audioFormat = [self audioFormat];
    
    // Apply format
    [self checkStatus:AudioUnitSetProperty(audioUnit,
                                           kAudioUnitProperty_StreamFormat,
                                           kAudioUnitScope_Input,
                                           kOutputBus,
                                           &audioFormat,
                                           sizeof(AudioStreamBasicDescription))];
    
    //---------------------------------------------------------- render callback.
    
	
	AURenderCallbackStruct callback = {soundOutputStreamRenderCallback, self};
	
	[self checkStatus:AudioUnitSetProperty(audioUnit,
										   kAudioUnitProperty_SetRenderCallback,
										   kAudioUnitScope_Global,
										   kOutputBus,
										   &callback,
										   sizeof(callback))];
	//---------------------------------------------------------- go!
	
	[self checkStatus:AudioUnitInitialize(audioUnit)];
	[self checkStatus:AudioOutputUnitStart(audioUnit)];
	
	[self setIsPlaying:TRUE];
}

- (AudioStreamBasicDescription) audioFormat {
    AudioStreamBasicDescription audioFormat;
    audioFormat.mSampleRate       = sampleRate,
    audioFormat.mFormatID         = kAudioFormatLinearPCM,
    audioFormat.mFormatFlags      = kAudioFormatFlagsNativeFloatPacked,
    audioFormat.mFramesPerPacket  = 1,
    audioFormat.mChannelsPerFrame = numOfChannels,
    audioFormat.mBytesPerFrame    = sizeof(Float32) * numOfChannels,
    audioFormat.mBytesPerPacket   = sizeof(Float32) * numOfChannels,
    audioFormat.mBitsPerChannel   = sizeof(Float32) * 8;
    
    return audioFormat;
};

- (void)stop {
	[super stop];
	
	if([self isStreaming] == NO) {
		return;
	}
	
	[self checkStatus:AudioOutputUnitStop(audioUnit)];
	[self checkStatus:AudioUnitUninitialize(audioUnit)];
	[self checkStatus:AudioComponentInstanceDispose(audioUnit)];
	audioUnit = nil;
}

@end
