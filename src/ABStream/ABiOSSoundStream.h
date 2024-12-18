#if TARGET_OS_IPHONE


//
//  SoundInputStream.h
//  Created by Lukasz Karluk on 13/06/13.
//  http://julapy.com/blog
//
//  originally from NodeBeat
//
#pragma once

#include "ofSoundStream.h"
#include "ofSoundBaseTypes.h"

#import "LinkSoundInputStream.h"
#import "LinkSoundOutputStream.h"


// custom iOSSoundStream that supports AudioBus
class ABiOSSoundStream : public ofBaseSoundStream {
    
public:
    ABiOSSoundStream();
    ~ABiOSSoundStream();
    
    //not on iOS
    std::vector<ofSoundDevice> getDeviceList(ofSoundDevice::Api api) const;
    void setDeviceID(int deviceID);
    void setInput(ofBaseSoundInput * soundInput);
    void setOutput(ofBaseSoundOutput * soundOutput);
    
    bool setup(const ofSoundStreamSettings & settings);
    
    void printDeviceList() const;
    
    void start();
    void stop();
    void close();
    
    
    uint64_t getTickCount() const;
    int getNumInputChannels() const;
    int getNumOutputChannels() const;
    int getSampleRate() const;
    int getBufferSize() const;
    int getDeviceID() const;
    
    ofSoundDevice getInDevice() const{
        return ofSoundDevice();
    }
    
    ofSoundDevice getOutDevice() const{
        return ofSoundDevice();
    }
    
    static bool setMixWithOtherApps(bool bMix);
    
    //----------
    
    LinkSoundInputStream * getSoundInputStream();
    LinkSoundOutputStream * getSoundOutStream();
    
    /// these are not implemented on iOS
    
private:
    
    ofBaseSoundInput * soundInputPtr;
    ofBaseSoundOutput * soundOutputPtr;
    
    LinkSoundInputStream * soundInputStream;
    LinkSoundOutputStream * soundOutputStream;
    
    int numOfInChannels;
    int numOfOutChannels;
    int sampleRate;
    int bufferSize;
    int numOfBuffers;
    
    //void * soundInputStream;
    //void * LinkSoundOutputStream;
    
    ofSoundStreamSettings settings;
};

#endif
