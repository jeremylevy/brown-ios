//
//  BLYSongCachingStore.m
//  Brown
//
//  Created by Jeremy Levy on 21/10/2016.
//  Copyright © 2016 Jeremy Levy. All rights reserved.
//

#import "BLYSongCachingStore.h"
#import "BLYSong.h"
#import "BLYSong+Caching.h"
#import "BLYPlaylist.h"
#import "BLYAlbum.h"
#import "BLYHTTPConnection.h"
#import "BLYCachedSongStore.h"
#import "BLYVideoStore.h"
#import "BLYAppDelegate.h"
#import "BLYErrorStore.h"
#import "BLYVideoSong.h"
#import "BLYPlayerViewController.h"

NSString * const BLYSongCachingStoreDownloadSongProgressNotification = @"BLYSongCachingStoreDownloadSongProgressNotification";
NSString * const BLYSongCachingStoreDidDownloadSongNotification = @"BLYSongCachingStoreDidDownloadSongNotification";

NSString * const BLYSongCachingStoreWillDownloadSongNotification = @"BLYSongCachingStoreWillDownloadSongNotificationNotification";

NSString * const BLYSongCachingStoreDidDownloadSongWithErrorNotification = @"BLYSongCachingStoreDidDownloadSongWithErrorNotification";

NSString * const BLYSongCachingStoreDidStopDownloadingSongNotification = @"BLYSongCachingStoreDidStopDownloadingSongNotification";

@interface BLYSongCachingStore ()

@property (strong, nonatomic) NSMutableDictionary *songsCaching;
@property (strong, nonatomic) NSMutableArray *playlistsCaching;

@end

@implementation BLYSongCachingStore

+ (BLYSongCachingStore *)sharedStore
{
    static BLYSongCachingStore *songCachingStore = nil;
    
    if (!songCachingStore) {
        songCachingStore = [[BLYSongCachingStore alloc] init];
        
        songCachingStore.songsCaching = [[NSMutableDictionary alloc] init];
        songCachingStore.playlistsCaching = [[NSMutableArray alloc] init];
    }
    
    return songCachingStore;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if ([keyPath isEqualToString:@"requestProgress"]) {
        BLYSong *song = (__bridge BLYSong *)(context);
        NSNumber *progress = change[NSKeyValueChangeNewKey];
        
        [self setPercentageDownloaded:[change[NSKeyValueChangeNewKey] floatValue]
                              forSong:song];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:BLYSongCachingStoreDownloadSongProgressNotification
                                                            object:self
                                                          userInfo:@{@"song": song, @"percentageDownloaded": progress}];
    }
}

- (void)initEntryForSongIfNecessary:(BLYSong *)song
{
    if (_songsCaching[song.sid]) {
        return;
    }
    
    _songsCaching[song.sid] = [@{@"percentageDownloaded": [NSNumber numberWithFloat:0.0], @"isDownloading": [NSNumber numberWithBool:false], @"connection": [NSNull null], @"askedByUser":[NSNumber numberWithBool:NO]} mutableCopy];
}

- (void)setIsDownloading:(BOOL)isDownloading forSong:(BLYSong *)song init:(BOOL)init askedByUser:(BOOL)askedByUser
{
    [self initEntryForSongIfNecessary:song];
    
    _songsCaching[song.sid][@"isDownloading"] = [NSNumber numberWithBool:isDownloading];
    _songsCaching[song.sid][@"askedByUser"] = [NSNumber numberWithBool:askedByUser];
    
    if (init) {
        [self setPercentageDownloaded:0.0 forSong:song];
    }
}

- (void)setConnection:(BLYHTTPConnection *)connection forSong:(BLYSong *)song
{
    [self initEntryForSongIfNecessary:song];
    
    _songsCaching[song.sid][@"connection"] = connection;
    
    [connection addObserver:self
                 forKeyPath:@"requestProgress"
                    options:NSKeyValueObservingOptionNew
                    context:(__bridge void * _Nullable)(song)];
}

- (BOOL)isSongDownloading:(BLYSong *)song
{
    if (!_songsCaching[song.sid]) {
        return false;
    }
    
    return [_songsCaching[song.sid][@"isDownloading"] boolValue];
}

- (BOOL)isSongDownloadingHasBeenAskedByUser:(BLYSong *)song
{
    if (!_songsCaching[song.sid]) {
        return false;
    }
    
    return [self isSongDownloading:song] && [_songsCaching[song.sid][@"askedByUser"] boolValue];
}

- (BOOL)isPlaylistDownloading:(BLYPlaylist *)playlist
{
    return [_playlistsCaching indexOfObject:playlist] != NSNotFound;
}

- (void)setPercentageDownloaded:(float)percentageDownloaded forSong:(BLYSong *)song
{
    [self initEntryForSongIfNecessary:song];
    
    _songsCaching[song.sid][@"percentageDownloaded"] = [NSNumber numberWithFloat:percentageDownloaded];
}

- (float)percentageDownloadedForSong:(BLYSong *)song
{
    if (!_songsCaching[song.sid]) {
        return 0.0;
    }
    
    return [_songsCaching[song.sid][@"percentageDownloaded"] floatValue];
}

- (void)cacheSong:(BLYSong *)song forEntirePlaylist:(BLYPlaylist *)playlist askedByUser:(BOOL)askedByUser withCompletion:(void(^)(NSError *))completion
{
//    if (song.isCached) {
//        return;
//    }
    
    if ([self isSongDownloading:song]) {
        return;
    }
    
    // Remember that user may want to download a song
    // that is already downloading in background so "askedByUser"
    // may change during download
    BOOL (^songWasAskedByUser)(BLYSong *s) = ^(BLYSong *s){
        return [self isSongDownloadingHasBeenAskedByUser:s];
    };
    
    void (^handleError)(NSError *err) = ^(NSError *err){
        [self removeEntryForSong:song];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:BLYSongCachingStoreDidDownloadSongWithErrorNotification
                                                            object:self
                                                          userInfo:@{@"song": song}];
        
        if (completion) {
            completion(err);
            
            return;
        }
    };
    
    void (^handleTrackNotFound)(void) = ^{
        NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
        
        [userInfo setValue:NSLocalizedString(@"player_track_not_found", nil)
                    forKey:NSLocalizedDescriptionKey];
        
        NSError *err = [NSError errorWithDomain:@"com.brown.blyplayerviewcontroller"
                                           code:BLYPlayerViewControllerSongNotFoundErrorCode
                                       userInfo:userInfo];
        
        handleError(err);
    };
    
    void (^fetchVideoURLForSong)(BLYSong *song) = ^(BLYSong *song){
        [[BLYVideoStore sharedStore] fetchVideoURLForVideoOfSong:song
                                                    inBackground:!songWasAskedByUser(song)
                                                  withCompletion:^(NSURL *videoURL, NSError *err) {
                                                      if (err) {
                                                          return handleError(err);
                                                      }
                                                      
                                                      if (!videoURL) {
                                                          return handleTrackNotFound();
                                                      }
                                                      
                                                      BLYHTTPConnection *connection = [[BLYCachedSongStore sharedStore] cacheSong:song askedByUser:songWasAskedByUser withCompletion:^(NSError *err) {
                                                          
                                                          if (err) {
                                                              return handleError(err);
                                                          }
                                                          
                                                          [self removeEntryForSong:song];
                                                          
                                                          [[NSNotificationCenter defaultCenter] postNotificationName:BLYSongCachingStoreDidDownloadSongNotification
                                                                                                              object:self
                                                                                                            userInfo:@{@"song": song}];
                                                          
                                                          if (playlist) {
                                                              [self cacheEntirePlaylist:playlist askedByUser:askedByUser withCompletion:completion];
                                                          }
                                                          
                                                          if (completion) {
                                                              completion(nil);
                                                          }
                                                      }];
                                                      
                                                      [self setConnection:connection forSong:song];
                                                  }];
        
    };
    
    void (^fetchVideoIDCompletion)(NSMutableArray *, NSError *) = ^(NSMutableArray *videos, NSError *err){
        if (err) {
            return handleError(err);
        }
        
        if ([videos count] == 0) {
            return handleTrackNotFound();
        }
        
        fetchVideoURLForSong(song);
    };
    
    BLYAppDelegate *appDelegate = (BLYAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    if (![song.videos count]) {
        [[BLYVideoStore sharedStore] fetchVideoIDForSong:song
                                              andCountry:[appDelegate countryCodeForCurrentLocale]
                                            inBackground:!askedByUser
                                          withCompletion:fetchVideoIDCompletion];
    } else {
        fetchVideoIDCompletion([NSMutableArray arrayWithArray:[song.videos array]], nil);
    }
    
    [self setIsDownloading:YES
                   forSong:song
                      init:YES
               askedByUser:askedByUser];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BLYSongCachingStoreWillDownloadSongNotification
                                                        object:self
                                                      userInfo:@{@"song": song}];
}

- (void)cacheSong:(BLYSong *)song askedByUser:(BOOL)askedByUser withCompletion:(void(^)(NSError *))completion
{
    [self cacheSong:song forEntirePlaylist:nil askedByUser:askedByUser withCompletion:completion];
}

- (void)cacheEntirePlaylist:(BLYPlaylist *)playlist askedByUser:(BOOL)askedByUser withCompletion:(void(^)(NSError *))completion
{
    if ([_playlistsCaching indexOfObject:playlist] == NSNotFound) {
        [_playlistsCaching addObject:playlist];
    }
    
    for (BLYSong *s in playlist.songs) {
        if (s.isCached) {
            continue;
        }
        
        [self cacheSong:s forEntirePlaylist:playlist askedByUser:askedByUser withCompletion:completion];
        
        return;
    }
    
    [_playlistsCaching removeObject:playlist];
}

- (void)uncacheEntirePlaylist:(BLYPlaylist *)playlist
{
    // Avoid mutate during enumerate by calling reverseObjectEnumerator. Thanks SO.
    for (BLYSong *s in [playlist.songs reverseObjectEnumerator]) {
        if (!s.isCached) {
            
            if ([self isSongDownloading:s]) {
                [self stopCachingSong:s];
            }
            
            continue;
        }
        
        [self uncacheSong:s];
    }
    
    [_playlistsCaching removeObject:playlist];
}

- (void)stopCachingSong:(BLYSong *)song
{
    if (!_songsCaching[song.sid]) {
        return;
    }
    
    // [NSNull null] or BLYHTTPConnection *
    id connection = _songsCaching[song.sid][@"connection"];
    
    if (connection == [NSNull null]) {
        return;
    }
    
    [(BLYHTTPConnection *)connection cancel];
    
    [self removeEntryForSong:song];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BLYSongCachingStoreDidStopDownloadingSongNotification
                                                        object:self
                                                      userInfo:@{@"song": song}];
}

- (void)removeEntryForSong:(BLYSong *)song
{
    if (!_songsCaching[song.sid]) {
        return;
    }
    
    // [NSNull null] or BLYHTTPConnection *
    id connection = _songsCaching[song.sid][@"connection"];
    
    if (connection != [NSNull null]) {
        [connection removeObserver:self
                        forKeyPath:@"requestProgress"
                           context:(__bridge void * _Nullable)(song)];
    }
    
    [_songsCaching removeObjectForKey:song.sid];
}

- (void)uncacheSong:(BLYSong *)song
{
    [[BLYCachedSongStore sharedStore] removeCacheForSong:song];
}

- (BOOL)hasSongsCaching
{
    return [_songsCaching count] > 0;
}

@end
