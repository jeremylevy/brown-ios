//
//  BLYSongCachingStore.h
//  Brown
//
//  Created by Jeremy Levy on 21/10/2016.
//  Copyright © 2016 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BLYSong, BLYPlaylist, BLYAlbum, BLYHTTPConnection;

extern NSString * const BLYSongCachingStoreDownloadSongProgressNotification;
extern NSString * const BLYSongCachingStoreDidDownloadSongNotification;

extern NSString * const BLYSongCachingStoreWillDownloadSongNotification;
extern NSString * const BLYSongCachingStoreDidDownloadSongWithErrorNotification;

extern NSString * const BLYSongCachingStoreDidStopDownloadingSongNotification;

@interface BLYSongCachingStore : NSObject

+ (BLYSongCachingStore *)sharedStore;
- (void)setIsDownloading:(BOOL)isDownloading forSong:(BLYSong *)song init:(BOOL)init askedByUser:(BOOL)askedByUser;
- (void)setConnection:(BLYHTTPConnection *)conn forSong:(BLYSong *)song;

- (void)stopCachingSong:(BLYSong *)song;

- (BOOL)isSongDownloading:(BLYSong *)song;
- (BOOL)isSongDownloadingHasBeenAskedByUser:(BLYSong *)song;

- (BOOL)isPlaylistDownloading:(BLYPlaylist *)playlist;

- (void)setPercentageDownloaded:(float)percentageDownloaded forSong:(BLYSong *)song;
- (float)percentageDownloadedForSong:(BLYSong *)song;

- (void)cacheSong:(BLYSong *)song askedByUser:(BOOL)askedByUser withCompletion:(void(^)(NSError *))completion;
- (void)cacheSong:(BLYSong *)song forEntirePlaylist:(BLYPlaylist *)playlist askedByUser:(BOOL)askedByUser withCompletion:(void(^)(NSError *))completion;

- (void)uncacheSong:(BLYSong *)song;

- (void)cacheEntirePlaylist:(BLYPlaylist *)playlist askedByUser:(BOOL)askedByUser withCompletion:(void(^)(NSError *))completion;
- (void)uncacheEntirePlaylist:(BLYPlaylist *)playlist;

- (BOOL)hasSongsCaching;

@end
