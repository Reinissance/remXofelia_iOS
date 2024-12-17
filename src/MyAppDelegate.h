
#import "ofxiOSAppDelegate.h"
//#import "ofxiOSViewController.h"
//#import <Foundation/Foundation.h>
#import "Audiobus.h"
#import "ABLLinkSettingsViewController.h"

@interface MyAppDelegate : ofxiOSAppDelegate

//@property (nonatomic, strong) ofxiOSViewController * rootViewController;

@property (strong, nonatomic) UINavigationController *navController;

@property (nonatomic, assign) ABLLinkSettingsViewController *linkSettings;

@property (strong, nonatomic) ABAudiobusController *audiobusController;

@property (strong, nonatomic) ABAudioSenderPort *audiobusSender;

@property (strong, nonatomic) ABAudioReceiverPort *audiobusReceiver;

@property (strong, nonatomic) ABAudioFilterPort *audiobusFilter;


@property (strong, nonatomic) UISlider *bpmSlider;
@property (strong, nonatomic) UILabel *bpmLabel;
@property (strong, nonatomic) UISegmentedControl *quantumControl;
@property (strong, nonatomic) UILabel *quantumLabel;

- (NSString *) docsPath;

//@property (nonatomic) float cpu_usage;

- (void)showLinkSettings;;
//- (void)cleanImageFolder;
@property BOOL linkSettingShown;

- (void)hideLinkSettings:(id)sender;

@end

