
#import "MyAppDelegate.h"
#import "ofApp.h"
#import <mach/mach.h>
#import <assert.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#define APP ((MyAppDelegate *)[[UIApplication sharedApplication] delegate])

//#include "ofxiOSExtras.h"
//#include "ofAppiOSWindow.h"


/* You might need to get a temporary key for this app from https://developer.audiob.us/ and maybe
change the AudioComponents Names in the plist to test this on a device */

static NSString *const AUDIOBUS_API_KEY= @"H4sIAAAAAAAAA2WOT2sCMRBHv4rMWY3b4B/2Lj0W2mNTJLsZdXA3CZNMcRG/e6dCL/X63m8ecwO8ZuIJWmi2dr2xO7t6gTl0EsOAh+hHVEVvH/urH/OAqoSHQ+nP+M8smuVq6SVQ6qS0zjij25y4Fmg/b1Cn/Lv3wiflT91Zkqo8YOmZcqUUVb9iRPY1sZoi3V+ixKBg9FGOvq/CyErfKZLSb+TyOG7uX3OgoMaZiqM+4nlaMJ6oVG3qxpkLTs7Ytd3C/QdP2jKCCAEAAA==:E65+/Yimyf+0FLB161irDJPpyp2MRq51pkkCKktKLngMyvsOEXHyRN1p0k6XAU1yJwE2n3dDVXL3OikX76Bk2a2MWkmldvWQZm6eq1RyxgALqVVoBfCE6rSlTjh0DjsC";

@implementation MyAppDelegate

ofApp *app;

static void onSessionTempoChanged(Float64 bpm, void* context) {
    //   ViewController* vc = (__bridge ViewController *)context;
    // [vc updateSessionTempo:bpm];
    NSLog(@"bpm change %f",bpm);

    if ( dynamic_cast<ofApp*>(ofGetAppPtr()) != NULL){
        app->link.bpm = bpm;
        app->ofelia.pd.sendFloat("bpm", bpm);
        if (APP.linkSettingShown) {
            [APP updateBPM];
        }
    }
}

- (void) sendLinkValues:(NSNotification *) notification {
    NSDictionary *dict = notification.userInfo;
    NSNumber *value = [dict valueForKey:@"value"];
    NSString *receiver = [dict valueForKey:@"pdReceiver"];
    if (value != nil && receiver != nil && app->ofelia.pd.isComputingAudio()) {
        app->ofelia.pd.sendFloat([receiver UTF8String], [value floatValue]);
    }
}

- (void)showLinkSettings {

    if (_navController.view.hidden) {
        _navController.view.hidden = NO;
        _linkSettingShown = YES;
    } else if (!_linkSettingShown ){
        _linkSettingShown = YES;
        _navController = [[UINavigationController alloc] initWithRootViewController:_linkSettings];


        _linkSettings.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self
                                                      action:@selector(hideLinkSettings:)];
        
        _navController.modalPresentationStyle = UIModalPresentationPopover;



        UIPopoverPresentationController *popC = _linkSettings.popoverPresentationController;
        popC.permittedArrowDirections = UIPopoverArrowDirectionAny;
        popC.sourceRect = [ofxiOSGetGLParentView() frame];


        // we recommend using a size of 320x400 for the display in a popover
        _linkSettings.preferredContentSize = CGSizeMake(320., 400.);

        //

        // UIButton *button = (UIButton *)sender;
        // popC.sourceView = button.superview;

        popC.backgroundColor = [UIColor whiteColor];
        _linkSettings.view.backgroundColor = [UIColor whiteColor];

        CGRect frame = _navController.view.frame;
        _bpmSlider = [[UISlider alloc] initWithFrame:CGRectMake(8., frame.size.height-116., frame.size.width-16., 20.)];
        [_bpmSlider addTarget:self action:@selector(setBPM:) forControlEvents:UIControlEventTouchUpInside];
        [_bpmSlider addTarget:self action:@selector(setBPM:) forControlEvents:UIControlEventTouchUpOutside];
        [_bpmSlider addTarget:self action:@selector(adjustBPM:) forControlEvents:UIControlEventValueChanged];
        _bpmSlider.minimumValue = 20.0;
        _bpmSlider.maximumValue = 300.0;
        _bpmSlider.continuous = YES;
        _bpmSlider.tintColor = [UIColor orangeColor];
        [_navController.view addSubview:_bpmSlider];

        _bpmLabel = [[UILabel alloc] initWithFrame:CGRectMake(8., frame.size.height-154, frame.size.width-16., 20.)];
        _bpmLabel.textColor = [UIColor orangeColor];
        [_navController.view addSubview:_bpmLabel];

        [ofxiOSGetGLParentView() addSubview:_navController.view];

    }
    [self updateBPM];
}

- (void) updateBPM {
    _bpmSlider.value = app->link.bpm;
    _bpmLabel.text = [NSString stringWithFormat:@"Session-BPM: %d", (int) round(app->link.bpm)];
    _quantumControl.selectedSegmentIndex = (int) app->link.quantum -1;
    _quantumLabel.text = [NSString stringWithFormat:@"Link-Quantum: %d", (int) round(app->link.quantum)];
}

- (void) adjustBPM:(id)sender {
    int bpm = (int) round(_bpmSlider.value);
    _bpmLabel.text = [NSString stringWithFormat:@"Session-BPM: %d", bpm];
}

- (void) setBPM:(id)sender {
    int bpm = (int) round(_bpmSlider.value);
    app->link.bpm = bpm;
    app->ofelia.pd.sendFloat("bpm", bpm);
}

- (void) setLinkQuantum:(id)sender {
    float quantum = _quantumControl.selectedSegmentIndex + 1;
    app->link.quantum = quantum;
    _quantumLabel.text = [NSString stringWithFormat:@"Link-Quantum: %d", (int) quantum];
    app->ofelia.pd.sendFloat("quantum", quantum);
}

- (void)hideLinkSettings:(id)sender {
#pragma unused(sender)
    _navController.view.hidden = YES;
    _linkSettingShown = NO;
}

static void * kAudiobusConnectedChanged = &kAudiobusConnectedChanged;


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    _linkSettingShown = NO;
    [super applicationDidFinishLaunching:application];
    app = new ofApp();
    self.uiViewController = [[ofxiOSViewController alloc] initWithFrame:[[UIScreen mainScreen] bounds] app:app ];
    
    [self.window setRootViewController:self.uiViewController];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sendLinkValues:) name:@"linkQuantumCount" object:nil];
    
    // Watch the connected and audiobusAppRunning properties to be notified when we connect/disconnect or Audiobus opens or closes
    [_audiobusController addObserver:self forKeyPath:@"connected" options:0 context:kAudiobusConnectedChanged];
    self.audiobusController = [[ABAudiobusController alloc] initWithApiKey:AUDIOBUS_API_KEY];
    self.audiobusController.connectionPanelPosition = ABConnectionPanelPositionTop;

    [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionInterruptionNotification object:nil queue:nil usingBlock:^(NSNotification *notification) {
        NSInteger type = [notification.userInfo[AVAudioSessionInterruptionTypeKey] integerValue];
        if ( type == AVAudioSessionInterruptionTypeBegan ) {
            [self stop];
        } else {
            [self start];
        }
    }];

//    [self getAudIOs];
    app->stream = new ABiOSSoundStream();
    app->setupAudioStream();
    app->link = app->getSoundStream()->getSoundOutStream();
    ABLLinkSetSessionTempoCallback(app->link.getLinkRef, onSessionTempoChanged, (__bridge void *)self);
    _linkSettings = [ABLLinkSettingsViewController instance:app->link.getLinkRef];
    

    self.audiobusSender = [[ABAudioSenderPort alloc] initWithName:@"iOSExample out"
                                                       title:@"iOSExample out"
                                   audioComponentDescription:(AudioComponentDescription) {
                                       .componentType = kAudioUnitType_RemoteGenerator,
                                       .componentSubType = 'asnd', // Note single quotes
                                        //this needs to match the audioComponents entry
                                       .componentManufacturer = 'Rini' }
                                                   audioUnit:app->link.audioUnit];
    [_audiobusController addAudioSenderPort:_audiobusSender];


    [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionInterruptionNotification object:nil queue:nil usingBlock:^(NSNotification *notification) {
        NSInteger type = [notification.userInfo[AVAudioSessionInterruptionTypeKey] integerValue];
        if ( type == AVAudioSessionInterruptionTypeBegan ) {
            [self stop];
        } else {
            [self start];
        }
    }];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(connectionsChanged:)
                                                 name:ABConnectionsChangedNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleRouteChange:) name:AVAudioSessionRouteChangeNotification object:[AVAudioSession sharedInstance]];
    
    ofxiOSDisableIdleTimer();
    
    NSString *_docsPath = [self docsPath];
    NSString *filePath = [_docsPath stringByAppendingPathComponent:@"808.wav"];
    NSString *luaFilePath = [_docsPath stringByAppendingPathComponent:@"808.lua"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:filePath]) {
        NSString *copyFile = [[NSBundle mainBundle] pathForResource:@"808" ofType:@"wav" inDirectory:@"pd/wavs"];
        NSString *copyLuaFile = [[NSBundle mainBundle] pathForResource:@"808" ofType:@"lua" inDirectory:@"pd/wavs"];
        NSError *error;
        BOOL copy = [fm copyItemAtPath:copyFile toPath: filePath error:&error];
        if (copy)
            NSLog(@"copied 808.wav File %@ to %@", copyFile, filePath);
        copy = [fm copyItemAtPath:copyLuaFile toPath: luaFilePath error:&error];
        if (copy)
            NSLog(@"copied 808.lua File %@ to %@", copyLuaFile, luaFilePath);
        filePath = [_docsPath stringByAppendingPathComponent:@"FourBar.wav"];
        luaFilePath = [_docsPath stringByAppendingPathComponent:@"FourBar.lua"];
        copyFile = [[NSBundle mainBundle] pathForResource:@"FourBar" ofType:@"wav" inDirectory:@"pd/wavs"];
        copyLuaFile = [[NSBundle mainBundle] pathForResource:@"FourBar" ofType:@"lua" inDirectory:@"pd/wavs"];
        copy = [fm copyItemAtPath:copyFile toPath: filePath error:&error];
        if (copy)
            NSLog(@"copied FourBar.wav File %@ to %@", copyFile, filePath);
        copy = [fm copyItemAtPath:copyLuaFile toPath: luaFilePath error:&error];
        if (copy)
            NSLog(@"copied FourBar.lua File %@ to %@", copyLuaFile, luaFilePath);
    }
    //send docsDirPath to pd
    [self sendSymbolsToPd:@[@[@"docsDir", _docsPath]]];;
    
    return YES;
}

- (void) sendSymbolsToPd: (NSArray*) symbols {
    if (app->ofelia.pd.isComputingAudio()) {
            for (NSArray *array in symbols) {
                app->ofelia.pd.sendSymbol([array[0] UTF8String], [array[1] UTF8String]);
            }
    }
    else {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(sendSymbolsToPd:) object:nil];
        [self performSelector:@selector(sendSymbolsToPd:) withObject:symbols afterDelay:0.5];
    }
}

- (NSString *) docsPath {
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error;
//    //Copy if needed
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docsPath = [paths objectAtIndex:0];
    BOOL isDir = NO;
    if (! [fm fileExistsAtPath:docsPath isDirectory:&isDir] && isDir == NO) {
        [fm createDirectoryAtPath:docsPath withIntermediateDirectories:NO attributes:nil error:&error];
    }
    return [paths objectAtIndex:0];
}

//app life cycle

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [super applicationDidEnterBackground:application];
    //I think this should stop the gl rendering in the background-mode, i have less cpu usage with this
    [ofxiOSGetGLView() stopAnimation];
    glFinish();
    [self start];
}



- (void)applicationWillResignActive:(UIApplication *)application {
    [super applicationWillResignActive:application];
    [self start];
}

- (void)applicationDidBecomeActive {
    [self start];
}

-(BOOL) application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    return [self getFileFromURL:url];
}

- (BOOL) getFileFromURL:(NSURL*)url {
    if([url.absoluteString isEqualToString:@"iOSExample.audiobus://"] ||
       [url.absoluteString isEqualToString:@"iOSExample-1.0.audiobus://"]) {
    }
    return YES;//it sends this on connection to audiobus
}

-(void)applicationWillTerminate:(UIApplication *)application {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self stop];
        app->stream->close();
    });
    [super applicationWillTerminate:application];
}

-(void)start{
    [[AVAudioSession sharedInstance] setActive:YES error:NULL];
    AudioOutputUnitStart(app->getSoundStream()->getSoundInputStream().audioUnit);
    AudioOutputUnitStart(app->link.audioUnit);

}

-(void)stop{
    AudioOutputUnitStop(app->getSoundStream()->getSoundInputStream().audioUnit);
    AudioOutputUnitStop(app->link.audioUnit);
    [[AVAudioSession sharedInstance] setActive:NO error:NULL];
}

-(void)connectionsChanged: (NSNotification*)notification {
    NSLog(@"Connection changed.");
    if (!_audiobusController.connected) {
        [self stop];
        app->stream->close();
        OF_EXIT_APP(1);
    }
    else {
        [self start];
    }
}


- (void)handleRouteChange:(NSNotification *)notification {
    NSLog(@"Route changed.");
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    if (audioSession.currentRoute) {
        if (audioSession.sampleRate != app->ofelia.pd.sampleRate()) {
            app->setAVSessionSampleRate(audioSession.sampleRate);

        }
    }
    else {
        [self start];
    }
}

- (float) cpu_usage {
    kern_return_t kr;
    task_info_data_t tinfo;
    mach_msg_type_number_t task_info_count;

    task_info_count = TASK_INFO_MAX;
    kr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)tinfo, &task_info_count);
    if (kr != KERN_SUCCESS) {
        return -1;
    }

    task_basic_info_t      basic_info;
    thread_array_t         thread_list;
    mach_msg_type_number_t thread_count;

    thread_info_data_t     thinfo;
    mach_msg_type_number_t thread_info_count;

    thread_basic_info_t basic_info_th;
    uint32_t stat_thread = 0; // Mach threads

    basic_info = (task_basic_info_t)tinfo;

    // get threads in the task
    kr = task_threads(mach_task_self(), &thread_list, &thread_count);
    if (kr != KERN_SUCCESS) {
        return -1;
    }
    if (thread_count > 0)
        stat_thread += thread_count;

    long tot_sec = 0;
    long tot_usec = 0;
    float tot_cpu = 0;
    int j;

    for (j = 0; j < (int)thread_count; j++)
    {
        thread_info_count = THREAD_INFO_MAX;
        kr = thread_info(thread_list[j], THREAD_BASIC_INFO,
                         (thread_info_t)thinfo, &thread_info_count);
        if (kr != KERN_SUCCESS) {
            return -1;
        }

        basic_info_th = (thread_basic_info_t)thinfo;

        if (!(basic_info_th->flags & TH_FLAGS_IDLE)) {
            tot_sec = tot_sec + basic_info_th->user_time.seconds + basic_info_th->system_time.seconds;
            tot_usec = tot_usec + basic_info_th->user_time.microseconds + basic_info_th->system_time.microseconds;
            tot_cpu = tot_cpu + basic_info_th->cpu_usage / (float)TH_USAGE_SCALE * 100.0;
        }

    } // for each thread

    kr = vm_deallocate(mach_task_self(), (vm_offset_t)thread_list, thread_count * sizeof(thread_t));
    assert(kr == KERN_SUCCESS);

    return tot_cpu;
}

@end

