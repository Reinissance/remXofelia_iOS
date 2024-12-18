
#include "ofMain.h"
#include "ofApp.h"

int main()
{
    //  here are the most commonly used iOS window settings.
    //------------------------------------------------------
    ofiOSWindowSettings settings;
    settings.enableRetina = true; // enables retina resolution if the device supports it.
    settings.enableDepth = true; // enables depth buffer for 3d drawing.
    settings.enableAntiAliasing = false; // enables anti-aliasing which smooths out graphics on the screen.
    settings.numOfAntiAliasingSamples = 4; // number of samples used for anti-aliasing.
    settings.enableHardwareOrientation = true; // enables native view orientation.
    settings.enableHardwareOrientationAnimation = true; // enables native orientation changes to be animated.
    settings.glesVersion = OFXIOS_RENDERER_ES1; // type of renderer to use, ES1, ES2, ES3
//    settings.windowControllerType = ofxiOSWindowControllerType::GL_KIT; // Window Controller Type
    settings.colorType = ofxiOSRendererColorFormat::RGBA8888; // color format used default RGBA8888
    settings.depthType = ofxiOSRendererDepthFormat::DEPTH_NONE; // depth format (16/24) if depth enabled
    settings.stencilType = ofxiOSRendererStencilFormat::STENCIL_NONE; // stencil mode
    settings.windowMode = OF_FULLSCREEN;
//    ofCreateWindow(settings);
//    return ofRunApp(new ofApp);ofAppiOSWindow * window = (ofAppiOSWindow  *)(ofCreateWindow(settings).get());

    ofAppiOSWindow * window = (ofAppiOSWindow  *)(ofCreateWindow(settings).get());
    
    window->startAppWithDelegate("MyAppDelegate");
}
