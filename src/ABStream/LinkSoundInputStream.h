//
//  SoundInputStream.h
//  Created by Lukasz Karluk on 13/06/13.
//  http://julapy.com/blog
//

#pragma once

#import "SoundStream.h"
#import "Audiobus.h"

@interface LinkSoundInputStream : SoundStream {
@public
    AudioStreamBasicDescription audioFormat;
}

@end
