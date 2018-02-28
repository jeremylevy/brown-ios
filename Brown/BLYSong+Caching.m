//
//  BLYSong+Caching.m
//  Brown
//
//  Created by Jeremy Levy on 21/10/2016.
//  Copyright © 2016 Jeremy Levy. All rights reserved.
//

#import "BLYSong+Caching.h"
#import "BLYVideoSong.h"
#import "BLYVideo.h"

@interface BLYSong ()

@property (nonatomic) BOOL isDownloadingForCache;
@property (nonatomic) float percentageDownloadedForCache;

@end

@implementation BLYSong (Caching)

- (BOOL)isCached
{
    return !!self.cachedSong;
}

@end
