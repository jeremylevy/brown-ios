//
//  BLYCachedSongStore.m
//  Brown
//
//  Created by Jeremy Levy on 22/10/2016.
//  Copyright © 2016 Jeremy Levy. All rights reserved.
//

#import "BLYStore.h"
#import "BLYCachedSongStore.h"
#import "BLYCachedSong+CoreDataClass.h"
#import "BLYCachedSong+CoreDataProperties.h"
#import "BLYSong.h"
#import "BLYSong+Caching.h"
#import "BLYVideo.h"
#import "BLYVideoSong.h"
#import "BLYVideoStore.h"
#import "BLYPersonalTopSongStore.h"
#import "BLYPlayedSongStore.h"
#import "BLYPersonalTopSong.h"
#import "BLYPlayedSong.h"
#import "BLYHTTPConnection.h"
#import "BLYVideoURL.h"
#import "BLYVideoURLType.h"
#import "BLYAlbum.h"
#import "BLYAlbumStore.h"

NSString * const BLYCachedSongStoreDidDeleteCacheForSong = @"BLYCachedSongStoreDidDeleteCacheForSong";
NSString * const BLYCachedSongStoreDidCacheAlbum = @"BLYCachedSongStoreDidCacheAlbum";
NSString * const BLYCachedSongStoreDidUncacheAlbum = @"BLYCachedSongStoreDidUncacheAlbum";

// BLYPersonalTopSongStoreMaxSongsInDisplayedTop + BLYPlayedSongStoreMaxSongs;
int const BLYCachedSongStoreMaxCachedSongs = 45;

@implementation BLYCachedSongStore

+ (BLYCachedSongStore *)sharedStore
{
    static id cachedSongStore = nil;
    
    if (!cachedSongStore) {
        cachedSongStore = [[BLYCachedSongStore alloc] init];
    }
    
    return cachedSongStore;
}

- (NSArray *)fetchCachedSongs
{
    NSMutableArray *cachedSongs = [[NSMutableArray alloc] init];
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [[[[BLYStore sharedStore] model] entitiesByName] objectForKey:@"BLYCachedSong"];
    
    NSSortDescriptor *playedAtSort = [[NSSortDescriptor alloc] initWithKey:@"playedAt" ascending:NO];
    NSSortDescriptor *cachedAtSort = [[NSSortDescriptor alloc] initWithKey:@"cachedAt" ascending:NO];
    
    NSError *err = nil;
    
    [request setEntity:entity];
    [request setSortDescriptors:@[playedAtSort, cachedAtSort]];
    
    NSArray *results = [[[BLYStore sharedStore] context] executeFetchRequest:request error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", [err localizedDescription]];
    }
    
    for (BLYCachedSong *cachedSong in results) {
        [cachedSongs addObject:cachedSong];
    }
    
    return [cachedSongs copy];
}

- (NSArray *)fetchCachedSongsIn3GP
{
    NSMutableArray *cachedSongs = [[NSMutableArray alloc] init];
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [[[[BLYStore sharedStore] model] entitiesByName] objectForKey:@"BLYCachedSong"];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"videoQuality = %@", @"3gp"];
    
    NSError *err = nil;
    
    [request setEntity:entity];
    [request setPredicate:predicate];
    
    NSArray *results = [[[BLYStore sharedStore] context] executeFetchRequest:request error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", [err localizedDescription]];
    }
    
    for (BLYCachedSong *cachedSong in results) {
        [cachedSongs addObject:cachedSong];
    }
    
    return [cachedSongs copy];
}

- (NSArray *)fetchCachedAlbums
{
    NSMutableArray *cachedAlbums = [[NSMutableArray alloc] init];
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [[[[BLYStore sharedStore] model] entitiesByName] objectForKey:@"BLYAlbum"];
    
    NSSortDescriptor *playedAtSort = [[NSSortDescriptor alloc] initWithKey:@"playedAt" ascending:NO];
    NSSortDescriptor *cachedAtSort = [[NSSortDescriptor alloc] initWithKey:@"cachedAt" ascending:NO];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isCached == 1"];
    
    NSError *err = nil;
    
    [request setEntity:entity];
    
    [request setSortDescriptors:@[playedAtSort, cachedAtSort]];
    [request setPredicate:predicate];
    
    NSArray *results = [[[BLYStore sharedStore] context] executeFetchRequest:request error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", [err localizedDescription]];
    }
    
    for (BLYAlbum *cachedAlbum in results) {
        [cachedAlbums addObject:cachedAlbum];
    }
    
    return [cachedAlbums copy];
}

- (BLYCachedSong *)cachedSongWithSong:(BLYSong *)song
{
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [[[[BLYStore sharedStore] model] entitiesByName] objectForKey:@"BLYCachedSong"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"song = %@", song];
    NSError *err = nil;
    
    [request setEntity:entity];
    [request setPredicate:predicate];
    
    NSArray *results = [[[BLYStore sharedStore] context] executeFetchRequest:request error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", [err localizedDescription]];
    }
    
    return [results count] > 0 ? results[0] : nil;
}

- (void)insertCachedSong:(BLYSong *)song withVideoQuality:(NSString *)videoQuality askedByUser:(BOOL)askedByUser
{
    BLYCachedSong *cachedSong = [self cachedSongWithSong:song];
    
    if (!cachedSong) {
        cachedSong = [NSEntityDescription insertNewObjectForEntityForName:@"BLYCachedSong"
                                                   inManagedObjectContext:[[BLYStore sharedStore] context]];
    }
    
    [cachedSong setCachedAt:[NSDate date]];
    [cachedSong setPlayedAt:[NSDate date]];
    
    [cachedSong setVideoQuality:videoQuality];
    
    [cachedSong setSong:song];
    [cachedSong setCachedByUser:[NSNumber numberWithBool:askedByUser]];
    
    [song setCachedSong:cachedSong];
    
    [[BLYStore sharedStore] saveChanges];
    
    BLYAlbum *songAlbum = song.album;
    
    if (![songAlbum.isFullyLoaded boolValue]
        || [songAlbum.isCached boolValue]) {
        
        return;
    }
    
    NSSet *albumSongs = songAlbum.songs;
    BOOL albumIsCached = YES;
    
    for (BLYSong *s in albumSongs) {
        if (!s.isCached) {
            albumIsCached = NO;
            break;
        }
    }
    
    if (albumIsCached) {
        [self updateAlbumThatWasCached:songAlbum];
        
        NSDictionary *userInfo = @{@"album": songAlbum};
        
        [[NSNotificationCenter defaultCenter] postNotificationName:BLYCachedSongStoreDidCacheAlbum
                                                            object:self
                                                          userInfo:userInfo];
    }
}

- (void)updateAlbumThatWasCached:(BLYAlbum *)album
{
    [album setCachedAt:[NSDate date]];
    [album setIsCached:[NSNumber numberWithBool:YES]];
    
    [[BLYStore sharedStore] saveChanges];
}

- (void)updatePlayedAtForCachedSong:(BLYCachedSong *)cachedSong
{
    [cachedSong setPlayedAt:[NSDate date]];
    
    [[BLYStore sharedStore] saveChanges];
}

- (void)updateCachedSongDependingOnReorderedVideos:(BLYSong *)song
{
    BLYVideoSong *videoSong = nil;
    BLYVideo *video = nil;
    
    if (![song.videos count]) {
        [self removeCacheForSong:song];
        
        return;
    }
    
    videoSong = [song.videos objectAtIndex:0];
    video = videoSong.video;
    
    if (!video.path) {
        [self removeCacheForSong:song];
    } else {
        BOOL (^songWasAskedByUser)(BLYSong *s) = ^(BLYSong *s){
            return YES;
        };
        
        [self cacheSong:song askedByUser:songWasAskedByUser withCompletion:nil];
    }
}

- (void)removeUnusedCachedSongs
{
    NSArray *cachedSongs = [self fetchCachedSongs];
    NSString *path = [NSString stringWithFormat:@"%@/videos", [[BLYStore sharedStore] cacheDirectory]];
    
    unsigned long paths = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil] count];
    
//    if ([cachedSongs count] <= BLYCachedSongStoreMaxCachedSongs) {
//        return;
//    }
    
    NSMutableArray *cachedPersonalTopSongs = [[BLYPersonalTopSongStore sharedStore] fetchPersonalTopSongWithCachedVideos];
    NSMutableArray *cachedPlayedSongs = [[BLYPlayedSongStore sharedStore] fetchPlayedSongsWithCachedVideos];
    NSMutableArray *cachedSongsToKeep = [cachedPersonalTopSongs mutableCopy];
    
    // If personal top song contains less than BLYCachedSongStoreMaxCachedSongs songs
    // Add played songs to songs to keep
    if ([cachedSongsToKeep count] < BLYCachedSongStoreMaxCachedSongs || YES) {
        for (BLYSong *playedSong in cachedPlayedSongs) {
//            if ([cachedSongsToKeep count] == BLYCachedSongStoreMaxCachedSongs) {
//                break;
//            }
            
            if ([cachedSongsToKeep containsObject:playedSong]) {
                continue;
            }
            
            [cachedSongsToKeep addObject:playedSong];
        }
    }
    
    NSMutableDictionary *deletedSongs = [[NSMutableDictionary alloc] init];
    
    for (BLYCachedSong *cachedSong in cachedSongs) {
        BLYSong *song = cachedSong.song;
        
        if ([cachedSongsToKeep containsObject:song] || [cachedSong.cachedByUser boolValue]) {
            continue;
        }
        
        BLYVideoSong *videoSong = [song.videos objectAtIndex:0];
        BLYVideo *video = videoSong.video;
        NSUInteger nbSongAttachedToVideo = [video.videoSongs count];
        
        if (nbSongAttachedToVideo <= 1) {
            [self removeCacheForSong:song];
        } else {
            BOOL deleteVideoOrNot = YES;
            
            for (BLYVideoSong *videoSongForVideo in video.videoSongs) {
                if ([cachedSongsToKeep containsObject:videoSongForVideo.song]) {
                    deleteVideoOrNot = NO;
                }
            }
            
            if (deleteVideoOrNot) {
                for (BLYVideoSong *videoSongForVideo in video.videoSongs) {
                    [self removeCacheForSong:videoSongForVideo.song];
                }
            }
            
//            NSNumber *remainingSongs = [deletedSongs objectForKey:video.sid];
//            unsigned long _nbSongAttachedToVideo = 0;
//
//            if (!remainingSongs) {
//                remainingSongs = [NSNumber numberWithUnsignedLong:nbSongAttachedToVideo];
//            }
//
//            _nbSongAttachedToVideo = [remainingSongs unsignedLongValue] - 1;
//
//            if (_nbSongAttachedToVideo <= 0) {
//                [deletedSongs removeObjectForKey:video.sid];
//
//                deleteVideo();
//            } else {
//                [deletedSongs setObject:[NSNumber numberWithUnsignedLong:_nbSongAttachedToVideo]
//                                 forKey:video.sid];
//            }
        }
    }
}

- (BLYSong *)songThatMustBeCachedButWhichAreNot
{
    NSArray *personalTopSongs = [[BLYPersonalTopSongStore sharedStore] fetchPersonalTopSong];
    NSArray *playedSongs = [[BLYPlayedSongStore sharedStore] fetchPlayedSongs];
    NSMutableArray *songsThatMustBeCached = [[NSMutableArray alloc] init];
    
    for (BLYPersonalTopSong *personalTopSong in personalTopSongs) {
        [songsThatMustBeCached addObject:personalTopSong.song];
    }
    
    if ([songsThatMustBeCached count] < BLYCachedSongStoreMaxCachedSongs && NO) {
        
        for (BLYPlayedSong *playedSong in playedSongs) {
            
            if ([songsThatMustBeCached containsObject:playedSong.song]) {
                continue;
            }
            
            [songsThatMustBeCached addObject:playedSong.song];
            
            if ([songsThatMustBeCached count] == BLYCachedSongStoreMaxCachedSongs) {
                break;
            }
        }
    }
    
    BLYSong *songThatMustBeCachedButWichAreNot = nil;
    
    for (BLYSong *songThatMustBeCached in songsThatMustBeCached) {
        if (songThatMustBeCached.isCached) {
            continue;
        }
        
        songThatMustBeCachedButWichAreNot = songThatMustBeCached;
        
        break;
    }
    
    return songThatMustBeCachedButWichAreNot;
}


- (BLYHTTPConnection *)cacheSong:(BLYSong *)song askedByUser:(BOOL (^)(BLYSong *))askedByUser withCompletion:(void (^)(NSError *))completion
{
    BLYVideoSong *videoSong = nil;
    BLYVideo *video = nil;
    
    videoSong = [song.videos objectAtIndex:0];
    video = videoSong.video;
    
//    if (song.isCached) {
//        if (completion) {
//            completion(nil);
//        }
//
//        return nil;
//    }
//
//    if (video.path) {
//        [self insertCachedSong:song withVideoQuality:[video.path pathExtension] askedByUser:askedByUser(song)];
//
//        if (completion) {
//            completion(nil);
//        }
//
//        return nil;
//    }
    
    BLYVideoURL *videoURL = [[BLYVideoStore sharedStore] bestURLForCacheAndVideo:video];
    NSURL *url = [NSURL URLWithString:videoURL.value];
    
    // Set up the connection as normal
    NSURLRequest *req = [NSURLRequest requestWithURL:url];
    
    BLYHTTPConnection *connection = [[BLYHTTPConnection alloc] initWithRequest:req];
    
    connection.displayActivityIndicator = askedByUser(song);
    
    void(^completionBlock)(NSData *data, NSError *err) = ^(NSData *data, NSError *err){
        if (err) {
            NSLog(@"Error when caching video: %@", err.localizedDescription);
            
            if (completion) {
                completion(err);
            }
            
            return;
        }
        
        if ([data length] == 0) {
            if (completion) {
                completion(err);
            }
            
            return;
        }
        
        NSString *tmpVideoPath = [[NSString alloc] initWithData:data
                                                       encoding:NSUTF8StringEncoding];
        
        [self moveDownloadedSong:song
                            from:tmpVideoPath
                    videoQuality:videoURL.type.defaultContainer
                     askedByUser:askedByUser(song)
                  withCompletion:completion];
    };
    
    connection.completionBlock = completionBlock;
    connection.containerType = BLYHTTPConnectionContainerTypeFile;
    
    [connection start];
    
    return connection;
}

- (void)moveDownloadedSong:(BLYSong *)song from:(NSString *)from videoQuality:(NSString *)videoQuality askedByUser:(BOOL)askedByUser withCompletion:(void (^)(NSError *))completion
{
    BLYVideoSong *videoSong = nil;
    BLYVideo *video = nil;
    
    videoSong = [song.videos objectAtIndex:0];
    video = videoSong.video;
    
    NSString *cacheDirectory = [[BLYStore sharedStore] cacheDirectory];
    NSString *tmpVideoPath = from;
    
    NSString *videoName = [NSString stringWithFormat:@"videos/%@.%@", video.sid, videoQuality];
    NSString *videoPath = [cacheDirectory stringByAppendingPathComponent:videoName];
    NSError *error;
    
    if (![[NSFileManager defaultManager] createDirectoryAtPath:[cacheDirectory stringByAppendingPathComponent:@"videos"]
                                   withIntermediateDirectories:YES
                                                    attributes:nil
                                                         error:&error]) {
        NSLog(@"Unable to create videos cache directory: %@", error.localizedDescription);
        
        if (completion) {
            completion(error);
        }
        
        return;
    }
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:videoPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:videoPath error:&error];
    }
    
    if (error) {
        NSLog(@"Error during attempt to remove old video: %@", error.localizedDescription);
        
        if (completion) {
            completion(error);
        }
        
        return;
    }
    
    [[NSFileManager defaultManager] moveItemAtPath:tmpVideoPath
                                            toPath:videoPath
                                             error:&error];
    
    if (error) {
        NSLog(@"Error during attempt to move temporary video to final destination: %@", error.localizedDescription);
        
        if (song.isCached) {
            [self removeCacheForSong:song];
        }
        
        if (completion) {
            completion(error);
        }
        
        return;
    }
    
    if (song.isCached) {
        [self deleteCachedSong:song.cachedSong];
    }
    
    [self insertCachedSong:song withVideoQuality:videoQuality askedByUser:askedByUser];
    
    // Path needs to be reconstructed each time app is runned.
    // It seems that the path for cache directory is different on each run.
    [[BLYVideoStore sharedStore] setPath:videoName forVideo:video];
    
    // Make sure completion was called before player
    // update current song due to removeUnusedCachedVideos's notification
    if (completion) {
        completion(nil);
    }
    
    // TODO: If we enable auto caching
    [self removeUnusedCachedSongs];
}

- (void)deleteCachedSong:(BLYCachedSong *)cachedSong
{
    [[BLYStore sharedStore] deleteObject:cachedSong];
    
    [[BLYStore sharedStore] saveChanges];
}

- (void)removeCacheForSong:(BLYSong *)song
{
    if (!song.isCached) {
        return;
    }
    
    if ([song.videos count]) {
        BLYVideoSong *videoSong = [song.videos objectAtIndex:0];
        BLYVideo *video = videoSong.video;
        
        int nbOfSongsAttachedToCachedVideo = 0;
        
        if ([video.videoSongs count] > 1) {
            for (BLYVideoSong *videoSong in video.videoSongs) {
                if (videoSong.song.isCached) {
                    nbOfSongsAttachedToCachedVideo++;
                }
            }
        }
        
        if (nbOfSongsAttachedToCachedVideo <= 1) {
            [[BLYVideoStore sharedStore] deleteVideoFileForVideo:video];
            
            [[BLYVideoStore sharedStore] setPath:nil forVideo:video];
        }
    }
    
    [self deleteCachedSong:song.cachedSong];
    
    NSDictionary *userInfo = @{@"song": song};
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BLYCachedSongStoreDidDeleteCacheForSong
                                                        object:self
                                                      userInfo:userInfo];
    
    BLYAlbum *uncachedAlbum = song.album;
    
    [self removeCacheForAlbum:uncachedAlbum];
    
    userInfo = @{@"album": uncachedAlbum};
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BLYCachedSongStoreDidUncacheAlbum
                                                        object:self
                                                      userInfo:userInfo];
}

- (void)removeCacheForAlbum:(BLYAlbum *)album
{
    [album setIsCached:[NSNumber numberWithBool:NO]];
    
    [[BLYStore sharedStore] saveChanges];
}

@end
