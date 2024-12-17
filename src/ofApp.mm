#include "ofApp.h"
#import <AVFoundation/AVFoundation.h>
#import "MyAppDelegate.h"
#include "ofxOfeliaSetup.h"

#define APP ((MyAppDelegate *)[[UIApplication sharedApplication] delegate])

//--------------------------------------------------------------

ABiOSSoundStream* ofApp::getSoundStream(){
    return stream;
}

void ofApp::setupAudioStream(){
    
    inChannels = 0;
    outChannels = 2;
    // setup OF sound stream using the current *actual* samplerate and Channels
    int ticksPerBuffer = (ofelia.pd.isInited()) ? ofelia.pd.ticksPerBuffer() : 8; // 4 * 64 = buffer len of 256
    ofSoundStreamSettings settings;
    settings.numInputChannels = inChannels;
    settings.numOutputChannels = outChannels;
    settings.sampleRate = setAVSessionSampleRate(48000);
    settings.bufferSize = ticksPerBuffer;
    settings.setInListener(this);
    settings.setOutListener(this);
    stream->setup(settings);
    // setup Pd
    //
    // set 4th arg to true for queued message passing using an internal ringbuffer,
    // this is useful if you need to control where and when the message callbacks
    // happen (ie. within a GUI thread)
    //
    // note: you won't see any message prints until update() is called since
    // the queued messages are processed there, this is normal
    //
    if(!ofelia.pd.init(inChannels, outChannels, stream->getSampleRate(), stream->getBufferSize(), false)) {
        OF_EXIT_APP(1);
    }
    
}
void ofApp::setup()
{
    ofSetFrameRate(15);
    ofelia.pd.addReceiver(*this);
    ofelia.pd.subscribe("showLinkSettings");
    ofelia.pd.subscribe("xLength");
    ofelia.pd.subscribe("yLength");
    ofelia.pd.subscribe("connectMidiInSource");
    ofelia.pd.subscribe("connectMidiOutSource");
    ofelia.pd.subscribe("setBPM");
    ofelia.pd.subscribe("interruptDraw");
    
//    const bool bOpenMidiInPort = true; // whether to open midi input port in init()
//    const bool bOpenMidiOutPort = true; // whether to open midi output port in init()
//    const int midiInPortNum = 0; // midi input port number to open
//    const int midiOutPortNum = 0; // midi output port number to open
    const bool bOpenPatch = true; // whether to open a patch in init()
    const string &patchName = "pd/main.pd"; // path of the patch to open
    
    // load externals
    ofelia_setup();
    
    // add message receiver, required if you want to recieve messages
    ofelia.pd.addReceiver(ofelia); // automatically receives from all subscribed sources
    
    // add midi receiver, required if you want to recieve midi messages
    ofelia.pd.addMidiReceiver(*this); // automatically receives from all channels
    
    // setup midi
//    const int numMidiInPorts = bOpenMidiInPort ? ofelia.midiIn.getNumInPorts() : 0;
//    const int numMidiOutPorts = bOpenMidiOutPort ? ofelia.midiOut.getNumOutPorts() : 0;
//    if (numMidiInPorts)
//    {
//        // open midi input port by number
//        if (!ofelia.midiIn.openPort(midiInPortNum))
//            OF_EXIT_APP(1);
////            return false;
//
//        // don't ignore sysex, timing, & active sense messages,
//        // these are ignored by default
//        ofelia.midiIn.ignoreTypes(false, false, false);
//
//        // add this as a listener
//        ofelia.midiIn.addListener(this);
//    }
//    if (numMidiOutPorts)
//    {
//        // open midi output port by number
//        if (!ofelia.midiOut.openPort(midiOutPortNum))
//            OF_EXIT_APP(1);
////            return false;
//    }
    
    ofxMidi::enableNetworking();
    
    ofxMidiIn input;
    ofxMidiOut output;
    input.listInPorts();
    output.listOutPorts();
    
    // create input ports
    for(int i = 0; i < input.getNumInPorts(); ++i) {
        
        // new object
        inputs.push_back(new ofxMidiIn);
        activeIns.push_back(1);
        
        // ports have to be opened manually
        
//        if (i == 0) {
            // set this class to receive incoming midi events
//        inputs[i]->addListener(this);

            // open input port via port number
        inputs[i]->openPort(i);
        
        inNames.push_back(inputs[i]->getName());
    }
    
    // create output ports
    for(int i = 0; i < output.getNumOutPorts(); ++i) {
        
        // new object
        outputs.push_back(new ofxMidiOut);
        activeOuts.push_back(1);
        
        // ports have to be opened manually
        
//        if (i == 0)
        // open input port via port number
        outputs[i]->openPort(i);
        outNames.push_back(outputs[i]->getName());
    }
    
    ofxMidi::setConnectionListener(this);
    
    // audio processing on
    ofelia.pd.start();
    
    // open patch
    if (bOpenPatch)
    {
        ofelia.patch = ofelia.pd.openPatch(patchName);
        if (!ofelia.patch.isValid())
//            return false;
            OF_EXIT_APP(1);
    }
    ofelia.setup();
    ofelia.pd.sendFloat("bpm", link.bpm);
    
    sendMidiInPorts();
    sendMidiOutPorts();
    
}

void ofApp::sendMidiInPorts() {
    
    ofelia.pd.sendBang("cleanMidiInPorts");
//    vector<ofxMidiIn*>::iterator iter;
    for( int i = 0; i < inputs.size(); ++i) {
//        ofxMidiIn *input = inputs[i];
//        ofelia.pd.sendSymbol("addMidiInPort", input->getName());
        List list;
        list.addSymbol(inNames[i]);
//        list.addFloat(activeIns[i]);
        ofelia.pd.sendList("addMidiInPort", list);
    }
    ofelia.pd.sendBang("putMidiInPorts");
}


void ofApp::sendMidiOutPorts() {
    ofelia.pd.sendBang("cleanMidiOutPorts");
//    vector<ofxMidiOut*>::iterator oter;
    for( int i = 0; i < outputs.size(); ++i) {
//        ofxMidiOut *output = outputs[i];
//        ofelia.pd.sendSymbol("addMidiOutPort", output->getName());
        List list;
        list.addSymbol(outNames[i]);
//        list.addFloat(activeOuts[i]);
        ofelia.pd.sendList("addMidiOutPort", list);
    }
    ofelia.pd.sendBang("putMidiOutPorts");
}

//--------------------------------------------------------------
void ofApp::update()
{
    ofelia.update();
}

//--------------------------------------------------------------
void ofApp::draw()
{
    ofelia.draw();
}

//--------------------------------------------------------------
void ofApp::exit()
{
    ofelia.exit();
    
    // clear resources
    ofelia.clear();
    
    for(int i = 0; i < inputs.size(); ++i) {
        inputs[i]->closePort();
        inputs[i]->removeListener(this);
        delete inputs[i];
    }

    for(int i = 0; i < outputs.size(); ++i) {
        outputs[i]->closePort();
        delete outputs[i];
    }
}

//--------------------------------------------------------------
void ofApp::touchDown(ofTouchEventArgs &e)
{
    ofelia.touchDown(e);
}

//--------------------------------------------------------------
void ofApp::touchMoved(ofTouchEventArgs &e)
{
    ofelia.touchMoved(e);
}

//--------------------------------------------------------------
void ofApp::touchUp(ofTouchEventArgs &e)
{
    ofelia.touchUp(e);
}

//--------------------------------------------------------------
void ofApp::touchDoubleTap(ofTouchEventArgs &e)
{
    ofelia.touchDoubleTap(e);
}

//--------------------------------------------------------------
void ofApp::touchCancelled(ofTouchEventArgs &e)
{
    ofelia.touchCancelled(e);
}

//--------------------------------------------------------------
void ofApp::lostFocus()
{
    ofelia.lostFocus();
}

//--------------------------------------------------------------
void ofApp::gotFocus()
{
    ofelia.gotFocus();
}

//--------------------------------------------------------------
void ofApp::gotMemoryWarning()
{
    ofelia.gotMemoryWarning();
}

//--------------------------------------------------------------
void ofApp::deviceOrientationChanged(int newOrientation)
{
    ofelia.deviceOrientationChanged(newOrientation);
}

//--------------------------------------------------------------
void ofApp::launchedWithURL(std::string url)
{
    ofelia.launchedWithURL(url);
}

//--------------------------------------------------------------
// set the samplerate the Apple approved way since newer devices
// like the iPhone 6S only allow certain sample rates,
// the following code may not be needed once this functionality is
// incorporated into the ofxiOSSoundStream
// thanks to Seth aka cerupcat
float ofApp::setAVSessionSampleRate(float preferredSampleRate)
{
    NSError *audioSessionError = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    
    // disable active
    [session setActive:NO error:&audioSessionError];
    if (audioSessionError)
        NSLog(@"Error %ld, %@", (long)audioSessionError.code, audioSessionError.localizedDescription);
    
    // set category
    [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionAllowBluetooth|AVAudioSessionCategoryOptionMixWithOthers|AVAudioSessionCategoryOptionDefaultToSpeaker error:&audioSessionError];
    if (audioSessionError)
        NSLog(@"Error %ld, %@", (long)audioSessionError.code, audioSessionError.localizedDescription);
    
    // try to set the preferred sample rate
    [session setPreferredSampleRate:preferredSampleRate error:&audioSessionError];
    if (audioSessionError)
        NSLog(@"Error %ld, %@", (long)audioSessionError.code, audioSessionError.localizedDescription);
    
    // *** Activate the audio session before asking for the "current" values ***
    [session setActive:YES error:&audioSessionError];
    if (audioSessionError)
        NSLog(@"Error %ld, %@", (long)audioSessionError.code, audioSessionError.localizedDescription);

    ofLogNotice() << "AVSession samplerate: " << session.sampleRate << ", I/O buffer duration: " << session.IOBufferDuration;
    
    // our actual samplerate, might be differnt aka 48k on iPhone 6S
    return session.sampleRate;
}

//--------------------------------------------------------------
void ofApp::audioReceived(float * input, int bufferSize, int nChannels) {
    ofelia.pd.audioIn(input, bufferSize, nChannels);
    if (bufferSize != ofelia.pd.bufferSize()) {
        if (!ofelia.pd.init(inChannels, outChannels, stream->getSampleRate(), stream->getBufferSize(), false))
        NSLog(@"ofxPD couldn't set requested buffersize: %d", bufferSize);
    }
}

//--------------------------------------------------------------
void ofApp::audioRequested(float * output, int bufferSize, int nChannels) {
    ofelia.pd.audioOut(output, bufferSize, nChannels);
    if (bufferSize != ofelia.pd.bufferSize()) {
        if (!ofelia.pd.init(inChannels, outChannels, stream->getSampleRate(), stream->getBufferSize(), false))
        NSLog(@"ofxPD couldn't set requested buffersize: %d", bufferSize);
    }
}

//--------------------------------------------------------------
void ofApp::receiveBang(const std::string& dest) {
    if (dest == "showLinkSettings")
        APP.showLinkSettings;
}

void ofApp::receiveFloat(const std::string &dest, float num) {
    if (dest == "setBPM")
        link.bpm = num;
}

void ofApp::receiveList(const std::string& dest, const List& list) {
    if (dest == "connectMidiInSource") {
        string name = list.getSymbol(0);

//        vector<ofxMidiIn*>::iterator iter;
        for(int i = 0; i < inputs.size(); ++i) {
            ofxMidiIn *input = inputs[i];
            if(input->getName() == name) {
                    input->addListener(this);
                    activeIns[i] = 1;
            }
            else {
                input->removeListener(this);
                activeIns[i] = 0;
            }
        }
    }
    else if (dest == "connectMidiOutSource") {
        
        string name = list.getSymbol(0);
        

//        vector<ofxMidiOut*>::iterator iter;
        for(int i = 0; i < outputs.size(); ++i) {
            ofxMidiOut *output = outputs[i];
            if (output->getName() == name) {
                output->openPort(name);
                activeOuts[i] = 1;
            }
            else {
                output->closePort();
                activeOuts[i] = 0;
            }
        }
    }
}

//--------------------------------------------------------------
void ofApp::newMidiMessage(ofxMidiMessage& msg)
{
    midiMessage = msg;
    midiChan = midiMessage.channel;
    
    if (midiMessage.getStatusString(midiMessage.status) == "Note Off")
        ofelia.pd.sendNoteOn(midiChan, midiMessage.pitch, 0);
    else if (midiMessage.getStatusString(midiMessage.status) == "Note On")
        ofelia.pd.sendNoteOn(midiChan, midiMessage.pitch, midiMessage.velocity);
    else if (midiMessage.getStatusString(midiMessage.status) == "Control Change")
        ofelia.pd.sendControlChange(midiChan, midiMessage.control, midiMessage.value);
    else if (midiMessage.getStatusString(midiMessage.status) == "Program Change")
        ofelia.pd.sendProgramChange(midiChan, midiMessage.value); // note: pgm num range is 1 - 128
    else if (midiMessage.getStatusString(midiMessage.status) == "Pitch Bend")
        ofelia.pd.sendPitchBend(midiChan, midiMessage.value - 8192); //note: ofxPd uses -8192 - 8192 while
        // [bendin] returns 0 - 16383,
        // so sending a val of 2000 gives 10192 in pd
    else if (midiMessage.getStatusString(midiMessage.status) == "Aftertouch")
        ofelia.pd.sendAftertouch(midiChan, midiMessage.value);
    else if (midiMessage.getStatusString(midiMessage.status) == "Poly Aftertouch")
        ofelia.pd.sendPolyAftertouch(midiChan, midiMessage.pitch, midiMessage.value);
    else if (midiMessage.getStatusString(midiMessage.status) == "Sysex")
    {
        ofelia.pd.sendSysex(midiMessage.portNum, midiMessage.value);       // note: pd adds +2 to the port number from
        ofelia.pd.sendSysRealTime(midiMessage.portNum, midiMessage.value); // [midiin], [sysexin], & [realtimein].
        ofelia.pd.sendMidiByte(midiMessage.portNum, midiMessage.value);    // so sending to port 0 gives port 2 in pd
    }
}
void ofApp::midiInputAdded(string name, bool isNetwork) {
//    stringstream msg;
//    msg << "ofxMidi: input added: " << name << " network: " << isNetwork;
//    addMessage(msg.str());
    
    // create and open a new input port
    ofxMidiIn *newInput = new ofxMidiIn;
    newInput->openPort(name);
    newInput->addListener(this);
    inputs.push_back(newInput);
    activeIns.push_back(1);
    inNames.push_back(name);
    
    sendMidiInPorts();
}

//--------------------------------------------------------------
void ofApp::midiInputRemoved(string name, bool isNetwork) {
//    stringstream msg;
//    msg << "ofxMidi: input removed: " << name << " network: " << isNetwork << endl;
//    addMessage(msg.str());
    
    // close and remove input port
//    vector<ofxMidiIn*>::iterator iter;
    for( int i = 0; i < inputs.size(); ++i) {
//        ofxMidiIn *input = inputs[i];
        if(inputs[i]->getName() == name) {
            inputs[i]->closePort();
            inputs[i]->removeListener(this);
//            delete input;
            inputs.erase(inputs.begin()+i);
            activeIns.erase(activeIns.begin()+i);
            inNames.erase(inNames.begin()+i);
            break;
        }
    }
    
    sendMidiInPorts();
}

//--------------------------------------------------------------
void ofApp::midiOutputAdded(string name, bool isNetwork) {
//    stringstream msg;
//    msg << "ofxMidi: output added: " << name << " network: " << isNetwork << endl;
//    addMessage(msg.str());
    
    // create and open new output port
    ofxMidiOut *newOutput = new ofxMidiOut;
    newOutput->openPort(name);
    outputs.push_back(newOutput);
    activeOuts.push_back(1);
    outNames.push_back(name);
    
    sendMidiOutPorts();
}

//--------------------------------------------------------------
void ofApp::midiOutputRemoved(string name, bool isNetwork) {
//    stringstream msg;
//    msg << "ofxMidi: output removed: " << name << " network: " << isNetwork << endl;
//    addMessage(msg.str());
    
    // close and remove output port
//    vector<ofxMidiOut*>::iterator iter;
    for(int i = 0; i < outputs.size(); ++i) {
//        ofxMidiOut *output = outputs[i];
        if(outputs[i]->getName() == name) {
            outputs[i]->closePort();
//            delete output;
            outputs.erase(outputs.begin() + i);
            activeOuts.erase(activeOuts.begin()+i);
            outNames.erase(outNames.begin()+i);
            break;
        }
    }
    
    sendMidiOutPorts();
}


//--------------------------------------------------------------
void ofApp::receiveNoteOn(const int channel, const int pitch, const int velocity)
{
    vector<ofxMidiOut*>::iterator iter;
    for(iter = outputs.begin(); iter != outputs.end(); ++iter) {
        ofxMidiOut *midiOut = (*iter);
        if (midiOut->isOpen())
            midiOut->sendNoteOn(channel, pitch, velocity);
    }
}

void ofApp::receiveControlChange(const int channel, const int controller, const int value)
{
    vector<ofxMidiOut*>::iterator iter;
    for(iter = outputs.begin(); iter != outputs.end(); ++iter) {
        ofxMidiOut *midiOut = (*iter);
        if (midiOut->isOpen())
            midiOut->sendControlChange(channel, controller, value);
    }
}

// note: pgm nums are 1-128 to match pd
void ofApp::receiveProgramChange(const int channel, const int value)
{
    vector<ofxMidiOut*>::iterator iter;
    for(iter = outputs.begin(); iter != outputs.end(); ++iter) {
        ofxMidiOut *midiOut = (*iter);
        if (midiOut->isOpen())
            midiOut->sendProgramChange(channel, value);
    }
}

void ofApp::receivePitchBend(const int channel, const int value)
{
    vector<ofxMidiOut*>::iterator iter;
    for(iter = outputs.begin(); iter != outputs.end(); ++iter) {
        ofxMidiOut *midiOut = (*iter);
        if (midiOut->isOpen())
            midiOut->sendPitchBend(channel, value);
    }
}

void ofApp::receiveAftertouch(const int channel, const int value)
{
    vector<ofxMidiOut*>::iterator iter;
    for(iter = outputs.begin(); iter != outputs.end(); ++iter) {
        ofxMidiOut *midiOut = (*iter);
        if (midiOut->isOpen())
            midiOut->sendAftertouch(channel, value);
    }
}

void ofApp::receivePolyAftertouch(const int channel, const int pitch, const int value)
{
    vector<ofxMidiOut*>::iterator iter;
    for(iter = outputs.begin(); iter != outputs.end(); ++iter) {
        ofxMidiOut *midiOut = (*iter);
        if (midiOut->isOpen())
            midiOut->sendPolyAftertouch(channel, pitch, value);
    }
}

// note: pd adds +2 to the port num, so sending to port 3 in pd to [midiout],
//       shows up at port 1 in ofxPd
void ofApp::receiveMidiByte(const int port, const int byte)
{
    vector<ofxMidiOut*>::iterator iter;
    for(iter = outputs.begin(); iter != outputs.end(); ++iter) {
        ofxMidiOut *midiOut = (*iter);
        if (midiOut->isOpen())
            midiOut->sendMidiByte(byte);
    }
}
