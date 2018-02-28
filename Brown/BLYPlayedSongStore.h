//
//  BLYPlayedSongStore.h
//  Brown
//
//  Created by Jeremy Levy on 01/10/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BLYSong;
@class BLYPlayedSong;
@class BLYHTTPConnection;

extern const int BLYPlayedSongStoreMaxSongs;
extern const int BLYPlayedSongStoreExpiredURLErrorCode;

@interface BLYPlayedSongStore : NSObject

+ (BLYPlayedSongStore *)sharedStore;

- (void)insertPlayedSong:(BLYSong *)song;
- (NSArray *)fetchPlayedSongs;

- (BLYPlayedSong *)playedSongWithSong:(BLYSong *)song;
- (void)updatePlayedAtForPlayedSong:(BLYPlayedSong *)playedSong;

//- (BLYHTTPConnection *)cachePlayedSong:(BLYSong *)playedSong withCompletion:(void(^)(NSError *))completion;
- (NSMutableArray *)fetchPlayedSongsWithCachedVideos;

- (void)deleteFirstPlayedSongIfNecessary;
- (void)deletePlayedSong:(BLYPlayedSong *)playedSong;
- (void)deleteLastPlayedSong;

@end
