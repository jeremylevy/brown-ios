//
//  BLYPlayedSongStore.m
//  Brown
//
//  Created by Jeremy Levy on 01/10/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import "BLYStore.h"
#import "BLYPlayedSongStore.h"
#import "BLYSong.h"
#import "BLYSong+Caching.h"
#import "BLYPlayedSong.h"
#import "BLYHTTPConnection.h"
#import "BLYVideo.h"
#import "BLYVideoStore.h"
#import "BLYVideoSong.h"
#import "BLYPersonalTopSongStore.h"
#import "BLYNetworkStore.h"
#import "BLYVideoURL.h"
#import "BLYHTTPConnection.h"
#import "BLYPersonalTopSong.h"
#import "BLYCachedSongStore.h"
#import "BLYAlbumStore.h"

const int BLYPlayedSongStoreMaxSongs = 25;
const int BLYPlayedSongStoreExpiredURLErrorCode = 0;

@implementation BLYPlayedSongStore

+ (BLYPlayedSongStore *)sharedStore
{
    static id playedSongStore = nil;
    
    if (!playedSongStore) {
        playedSongStore = [[BLYPlayedSongStore alloc] init];
        
        // In case song was added to played song
        // without being added to personal top
        // (if app was terminated before trigerring timer for example)
        [playedSongStore deleteFirstPlayedSongIfNecessary];
    }
    
    return playedSongStore;
}

- (NSArray *)fetchPlayedSongs
{
    NSMutableArray *playedSongs = [[NSMutableArray alloc] init];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [[[[BLYStore sharedStore] model] entitiesByName] objectForKey:@"BLYPlayedSong"];
    NSSortDescriptor *dateSort = [[NSSortDescriptor alloc] initWithKey:@"playedAt" ascending:NO];
    NSError *err = nil;
    
    [request setEntity:entity];
    [request setSortDescriptors:@[dateSort]];
    
    NSArray *results = [[[BLYStore sharedStore] context] executeFetchRequest:request error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", [err localizedDescription]];
    }
    
    for (BLYPlayedSong *playedSong in results) {
        [playedSongs addObject:playedSong];
    }
    
    return [playedSongs copy];
}

- (BLYPlayedSong *)playedSongWithSong:(BLYSong *)song
{
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [[[[BLYStore sharedStore] model] entitiesByName] objectForKey:@"BLYPlayedSong"];
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

- (void)updatePlayedAtForPlayedSong:(BLYPlayedSong *)playedSong
{
    [playedSong setPlayedAt:[NSDate date]];
    
    if ([playedSong.song isCached]) {
        [[BLYCachedSongStore sharedStore] updatePlayedAtForCachedSong:playedSong.song.cachedSong];
    }
    
    [[BLYAlbumStore sharedStore] updatePlayedAtForAlbum:playedSong.song.album];
    
    [[BLYStore sharedStore] saveChanges];
}

- (void)insertPlayedSong:(BLYSong *)song
{
//    NSArray *playedSongs = [self fetchPlayedSongs];
//
//    if ([playedSongs count] >= BLYPlayedSongStoreMaxSongs) {
//        [self deletePlayedSong:[playedSongs lastObject]];
//    }
    
    BLYPlayedSong *playedSong = [NSEntityDescription insertNewObjectForEntityForName:@"BLYPlayedSong"
                                                              inManagedObjectContext:[[BLYStore sharedStore] context]];
    
    [playedSong setSong:song];
    
    // Played song needs to have a song!
    [self updatePlayedAtForPlayedSong:playedSong];
    
    [song setPlayedSong:playedSong];
    
    [[BLYStore sharedStore] saveChanges];
}

- (void)deletePlayedSong:(BLYPlayedSong *)playedSong
{
    [[BLYStore sharedStore] deleteObject:playedSong];
    
    [[BLYStore sharedStore] saveChanges];
}

- (void)deleteLastPlayedSong
{
    NSArray *playedSongs = [self fetchPlayedSongs];
    
    if (![playedSongs count]) {
        return;
    }
    
    BLYPlayedSong *lastPlayedSong = [playedSongs objectAtIndex:0];
    
    [self deletePlayedSong:lastPlayedSong];
}

- (void)deleteFirstPlayedSongIfNecessary
{
    NSArray *playedSongs = [[BLYPlayedSongStore sharedStore] fetchPlayedSongs];
    
    if ([playedSongs count] > BLYPlayedSongStoreMaxSongs) {
        [[BLYPlayedSongStore sharedStore] deletePlayedSong:[playedSongs lastObject]];
    }
}

//- (BLYHTTPConnection *)cachePlayedSong:(BLYSong *)playedSong
//                        withCompletion:(void(^)(NSError *))completion
//{
//    NSOrderedSet *videos = playedSong.videos;
//    
//    if (!videos || [videos count] == 0) {
//        return nil;
//    }
//    
//    BLYSong *song = playedSong;
//    BLYVideoSong *videoSong = [videos objectAtIndex:0];
//    BLYVideo *video = videoSong.video;
//    
//    if (!video
//        || !video.urls
//        || [video.urls count] == 0
//        || video.path) {
//        return nil;
//    }
//    
//    BOOL expiredURL = NO;
//    
//    BLYVideoURL *videoURL = [video.urls anyObject];
//    
//    if ([videoURL.expiresAt timeIntervalSinceNow] <= 0) {
//        expiredURL = YES;
//    }
//    
//    void(^hookedCompletion)(NSError *) = ^(NSError *err){
//        if (!completion) {
//            return;
//        }
//        
//        if (!err) {
//            return completion(nil);
//        }
//        
//        NSDictionary *userInfo = err.userInfo;
//        
//        // Forbidden
//        if (err.code == BLYHTTPConnectionHTTPErrorCode
//            && [[userInfo objectForKey:@"HTTPStatusCode"] longValue] == 403
//            && expiredURL) {
//            
//            NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
//            
//            [userInfo setValue:@"Expired video URL."
//                        forKey:NSLocalizedDescriptionKey];
//            
//            [userInfo setValue:song
//                        forKey:@"loadedSong"];
//            
//            err = [NSError errorWithDomain:@"com.brown.blyplayedsongstore"
//                                      code:BLYPlayedSongStoreExpiredURLErrorCode
//                                  userInfo:userInfo];
//        }
//        
//        completion(err);
//    };
//    
//    return [[BLYVideoStore sharedStore] cacheVideo:video
//                                    withCompletion:hookedCompletion];
//}

- (NSMutableArray *)fetchPlayedSongsWithCachedVideos
{
    NSArray *playedSongs = [self fetchPlayedSongs];
    NSMutableArray *cachedPlayedSongs = [[NSMutableArray alloc] init];
    
    for (BLYPlayedSong *playedSong in playedSongs) {
        BLYSong *song = playedSong.song;
        
        if (!song.isCached) {
            continue;
        }
        
        [cachedPlayedSongs addObject:song];
    }
    
    return cachedPlayedSongs;
}

@end
