//
//  BLYCachedSongStore.h
//  Brown
//
//  Created by Jeremy Levy on 22/10/2016.
//  Copyright © 2016 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const BLYCachedSongStoreDidDeleteCacheForSong;
extern NSString * const BLYCachedSongStoreDidCacheAlbum;
extern NSString * const BLYCachedSongStoreDidUncacheAlbum;

@class BLYSong, BLYCachedSong, BLYHTTPConnection, BLYVideo;

@interface BLYCachedSongStore : NSObject

+ (BLYCachedSongStore *)sharedStore;

- (void)insertCachedSong:(BLYSong *)song withVideoQuality:(NSString *)videoQuality askedByUser:(BOOL)askedByUser;

- (NSArray *)fetchCachedSongs;
- (NSArray *)fetchCachedSongsIn3GP;

- (NSArray *)fetchCachedAlbums;

- (BLYCachedSong *)cachedSongWithSong:(BLYSong *)song;
- (BLYSong *)songThatMustBeCachedButWhichAreNot;

- (void)updatePlayedAtForCachedSong:(BLYCachedSong *)cachedSong;

- (void)deleteCachedSong:(BLYCachedSong *)cachedSong;

- (BLYHTTPConnection *)cacheSong:(BLYSong *)song askedByUser:(BOOL (^)(BLYSong *))askedByUser withCompletion:(void (^)(NSError *))completion;

- (void)removeCacheForSong:(BLYSong *)song;
- (void)removeUnusedCachedSongs;

- (void)updateCachedSongDependingOnReorderedVideos:(BLYSong *)song;

- (void)moveDownloadedSong:(BLYSong *)song from:(NSString *)from videoQuality:(NSString *)videoQuality askedByUser:(BOOL)askedByUser withCompletion:(void (^)(NSError *))completion;

@end
