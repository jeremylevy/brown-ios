//
//  BLYPersonalTopSongStore.h
//  Brown
//
//  Created by Jeremy Levy on 26/10/2013.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const BLYPersonalTopSongStoreDidAddSong;
extern int const BLYPersonalTopSongStoreMaxSongsInDisplayedTop;
extern int const BLYPersonalTopSongStoreMaxSongs;

@class BLYSong, BLYPersonalTopSong, BLYHTTPConnection, BLYVideo;

@interface BLYPersonalTopSongStore : NSObject

+ (BLYPersonalTopSongStore *)sharedStore;

- (BLYPersonalTopSong *)insertPersonalTopSongForSong:(BLYSong *)song;
- (NSArray *)fetchPersonalTopSong;

- (NSMutableArray *)fetchPersonalTopSongWithCachedVideos;
- (BLYSong *)fetchFirstPersonalTopSongWithoutCache;

- (NSUInteger)countDisplayedPersonalTopSong;

@end
