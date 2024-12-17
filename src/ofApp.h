#pragma once

#include "ofMain.h"
#include "ofxiOS.h"
#include "ofxiOSExtras.h"
#include "ofxOfelia.h"
#include "ABiOSSoundStream.h"
#import "LinkSoundOutputStream.h"
#include "ofxMidi.h"

class ofApp : public ofxiOSApp, public PdReceiver, public PdMidiReceiver, public ofxMidiListener, public ofxMidiConnectionListener
{
public:
    void setup();
    void update();
    void draw();
    void exit();
    void touchDown(ofTouchEventArgs &e);
    void touchMoved(ofTouchEventArgs &e);
    void touchUp(ofTouchEventArgs &e);
    void touchDoubleTap(ofTouchEventArgs &e);
    void touchCancelled(ofTouchEventArgs &e);
    void lostFocus();
    void gotFocus();
    void gotMemoryWarning();
    void deviceOrientationChanged(int newOrientation);
    void launchedWithURL(std::string url);
    
    // sets the preferred sample rate, returns the *actual* samplerate
    // which may be different ie. iPhone 6S only wants 48k
    float setAVSessionSampleRate(float preferredSampleRate);
    
    // ofxOfelia
    ofxOfelia ofelia;

    //Link
    LinkSoundOutputStream *link;

    //    Audiobus
        
    void setupAudioStream();
    void setupPd();
    void unsetPd();

    ABiOSSoundStream* stream;
    ABiOSSoundStream* getSoundStream();

    // audio callbacks
    void audioReceived(float * input, int bufferSize, int nChannels);
    void audioRequested(float * output, int bufferSize, int nChannels);
    
    
    int CPU;
    int inChannels;
    int outChannels;
    int updateCount;
    
    BOOL settingChannels;

    // ofxPd
    void receiveBang(const std::string& dest);
    void receiveList(const std::string& dest, const List& list);
    void receiveFloat(const std::string &dest, float num);
    
    // ofxMidi
    void newMidiMessage(ofxMidiMessage& eventArgs);
    
    private:
    ofxMidiMessage midiMessage;
    int midiChan = 0;
    
    // midi device (dis)connection event callbacks
    void midiInputAdded(string name, bool isNetwork);
    void midiInputRemoved(string name, bool isNetwork);
    
    void midiOutputAdded(string nam, bool isNetwork);
    void midiOutputRemoved(string name, bool isNetwork);

    vector<ofxMidiIn*> inputs;
    vector<ofxMidiOut*> outputs;
    vector<int> activeIns;
    vector<int> activeOuts;
    vector<string> inNames;
    vector<string> outNames;
//    std::variant<ofxMidiIn*, int, string> midiIns;
//    std::variant<ofxMidiOut*, int, string> midiIns;
    
    void sendMidiInPorts();
    void sendMidiOutPorts();
    
    /// midi callbacks
    void receiveNoteOn(const int channel, const int pitch, const int velocity);
    void receiveControlChange(const int channel, const int controller, const int value);
    void receiveProgramChange(const int channel, const int value);
    void receivePitchBend(const int channel, const int value);
    void receiveAftertouch(const int channel, const int value);
    void receivePolyAftertouch(const int channel, const int pitch, const int value);
    void receiveMidiByte(const int port, const int byte);
};


