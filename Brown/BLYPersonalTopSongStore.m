//
//  BLYPersonalTopSongStore.m
//  Brown
//
//  Created by Jeremy Levy on 26/10/2013.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import "BLYPersonalTopSongStore.h"
#import "BLYPersonalTopSong.h"
#import "BLYSong.h"
#import "BLYSong+Caching.h"
#import "BLYStore.h"
#import "BLYHTTPConnection.h"
#import "BLYVideoStore.h"
#import "BLYVideoURL.h"
#import "BLYVideo.h"
#import "BLYVideoSong.h"

NSString * const BLYPersonalTopSongStoreDidAddSong = @"BLYPersonalTopSongStoreDidAddSong";
int const BLYPersonalTopSongStoreMaxSongsInDisplayedTop = 20;
int const BLYPersonalTopSongStoreMaxSongs = 20;

@implementation BLYPersonalTopSongStore

+ (BLYPersonalTopSongStore *)sharedStore
{
    static BLYPersonalTopSongStore *personalTopSongStore = nil;
    
    if (!personalTopSongStore) {
        personalTopSongStore = [[BLYPersonalTopSongStore alloc] init];
    }
    
    return personalTopSongStore;
}

- (BLYPersonalTopSong *)fetchPersonalTopSongWithSong:(BLYSong *)song
{
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [[[[BLYStore sharedStore] model] entitiesByName] objectForKey:@"BLYPersonalTopSong"];
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

- (BLYPersonalTopSong *)insertPersonalTopSongForSong:(BLYSong *)song
{
    BLYPersonalTopSong *topSong = [self fetchPersonalTopSongWithSong:song];
    double playCountToAdd = 1.0;
//    double (^timeFactor)(NSNumber *playCount) = ^double(NSNumber *playCount) {
//        return MAX(0.0, 1.0 - (0.05 * ([playCount intValue] - 1)));
//    };
    double currentTime = [[NSDate date] timeIntervalSince1970];
    
    if (!topSong) {
        topSong = [NSEntityDescription insertNewObjectForEntityForName:@"BLYPersonalTopSong"
                                                inManagedObjectContext:[[BLYStore sharedStore] context]];
        
        [topSong setSong:song];
        [topSong setTime:[NSDate dateWithTimeIntervalSince1970:currentTime]];
        
        [song setPersonalTopSong:topSong];
    }
//    else {
//        double time = [[topSong time] timeIntervalSince1970];
//
//        currentTime = time + ((currentTime - time) * timeFactor([topSong playCount]));
//    }
    
    
    double songPlayCount = [[topSong playCount] doubleValue];
    
    // Interest for a song increase first then slowly receding
    if (songPlayCount >= 40.0) {
        playCountToAdd = 1.0 - (songPlayCount / 100.0);

        if (playCountToAdd < 0.0) {
            playCountToAdd = 0.0;
        }
    }
    
    [topSong setPlayCount:[NSNumber numberWithDouble:playCountToAdd + songPlayCount]];
    
    // [topSong setTime:[NSDate dateWithTimeIntervalSince1970:currentTime]];
    [[BLYStore sharedStore] saveChanges];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BLYPersonalTopSongStoreDidAddSong
                                                        object:self];
    
    return topSong;
}

- (void)deletePersonalTopSongs:(NSArray *)songs
{
    for (BLYPersonalTopSong *song in songs) {
        [[BLYStore sharedStore] deleteObject:song];
    }
    
    [[BLYStore sharedStore] saveChanges];
}

- (NSUInteger)countDisplayedPersonalTopSong
{
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [[[[BLYStore sharedStore] model] entitiesByName] objectForKey:@"BLYPersonalTopSong"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"playCount > 1.0"];
    
    [request setEntity:entity];
    [request setPredicate:predicate];
    
    NSError *err = nil;
    NSUInteger count = [[[BLYStore sharedStore] context] countForFetchRequest:request error:&err];
    
    return count;
}

- (NSArray *)fetchPersonalTopSong
{
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [[[[BLYStore sharedStore] model] entitiesByName] objectForKey:@"BLYPersonalTopSong"];
    NSError *err = nil;
    
    float gravity = 1.0;
    double currentTime = [[NSDate date] timeIntervalSince1970];
    
    [request setEntity:entity];
    
    NSArray *results = [[[BLYStore sharedStore] context] executeFetchRequest:request error:&err];
    NSArray *scoreSupToZeroResults = @[];
    NSArray *scoreZeroResults = @[];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", [err localizedDescription]];
    }
    
    for (BLYPersonalTopSong *topSong in results) {
        double time = [[topSong time] timeIntervalSince1970];
        double hoursSinceFirstPlay = (currentTime - time) / 3600;
        
        // Hacker News ranking algorithm
        // -1 is to negate first play
        // https://medium.com/hacking-and-gonzo/how-hacker-news-ranking-algorithm-works-1d9b0cf2c08d
        // pow(hoursSinceFirstPlay + 2.0, gravity)
        // double score = ([[topSong playCount] doubleValue] - 1.0) / pow(hoursSinceFirstPlay + 2.0, gravity);
        double score = ([[topSong playCount] doubleValue] - 1.0) - (hoursSinceFirstPlay * gravity);
        
        if (([[topSong playCount] doubleValue] - 1.0) == 0.0) {
            score = 0.0;
        }
        
        [topSong setScore:[NSNumber numberWithDouble:score]];
    }
    
    NSPredicate *scoreSupToZeroPredicate = [NSPredicate predicateWithFormat:@"SELF.playCount > 1.0"];
    NSPredicate *scoreZeroPredicate = [NSPredicate predicateWithFormat:@"SELF.playCount = 1.0"];
    
    scoreZeroResults = [results filteredArrayUsingPredicate:scoreZeroPredicate];
    scoreSupToZeroResults = [results filteredArrayUsingPredicate:scoreSupToZeroPredicate];
    
    // Most recents first
    scoreZeroResults = [scoreZeroResults sortedArrayUsingComparator:^NSComparisonResult(BLYPersonalTopSong *obj1, BLYPersonalTopSong *obj2){
        double interval1 = [[obj1 time] timeIntervalSince1970];
        double interval2 = [[obj2 time] timeIntervalSince1970];
        
        if (interval1 < interval2) {
            return NSOrderedDescending;
        }
        
        return NSOrderedAscending;
    }];
    
    // Most score first
    scoreSupToZeroResults = [scoreSupToZeroResults sortedArrayUsingComparator:^NSComparisonResult(BLYPersonalTopSong *obj1, BLYPersonalTopSong *obj2){
        double score1 = [[obj1 score] doubleValue];
        double score2 = [[obj2 score] doubleValue];
        
        // sortedArray sort in ascending order
        // so inverse result for descending order
        if (score1 < score2) {
            return NSOrderedDescending;
        }
        
        return NSOrderedAscending;
    }];
    
    // Delete personal top songs with index above BLYPersonalTopSongStoreMaxSongsInCachedTop
    if ([scoreSupToZeroResults count] > BLYPersonalTopSongStoreMaxSongs) {
        NSRange range = NSMakeRange(BLYPersonalTopSongStoreMaxSongs,
                                    [scoreSupToZeroResults count] - BLYPersonalTopSongStoreMaxSongs);
        NSArray *songsToDelete = [scoreSupToZeroResults subarrayWithRange:range];
        
        [self deletePersonalTopSongs:songsToDelete];
    }
    
    if ([scoreZeroResults count] > BLYPersonalTopSongStoreMaxSongs) {
        NSRange range = NSMakeRange(BLYPersonalTopSongStoreMaxSongs,
                                    [scoreZeroResults count] - BLYPersonalTopSongStoreMaxSongs);
        NSArray *songsToDelete = [scoreZeroResults subarrayWithRange:range];
        
        [self deletePersonalTopSongs:songsToDelete];
    }
    
    if ([scoreSupToZeroResults count] > BLYPersonalTopSongStoreMaxSongsInDisplayedTop) {
        NSRange range = NSMakeRange(0, BLYPersonalTopSongStoreMaxSongsInDisplayedTop);
        
        scoreSupToZeroResults = [scoreSupToZeroResults subarrayWithRange:range];
    }
    
    return scoreSupToZeroResults;
}

- (NSMutableArray *)fetchPersonalTopSongWithCachedVideos
{
    NSArray *topSongs = [self fetchPersonalTopSong];
    NSMutableArray *cachedTopSongs = [[NSMutableArray alloc] init];
    
    for (BLYPersonalTopSong *topSong in topSongs) {
        BLYSong *song = topSong.song;
        
        if (!song.isCached) {
            continue;
        }
        
        [cachedTopSongs addObject:song];
    }
    
    return cachedTopSongs;
}

- (BLYSong *)fetchFirstPersonalTopSongWithoutCache
{
    NSArray *personalTopSongs = [self fetchPersonalTopSong];
    BLYSong *uncachedSong = nil;
    
    for (BLYPersonalTopSong *personalTopSong in personalTopSongs) {
        BLYSong *song = personalTopSong.song;
        BLYVideoSong *videoSong = nil;
        BLYVideo *video = nil;
        
        if (!song.videos || [song.videos count] == 0) {
            continue;
        }
        
        videoSong = [song.videos objectAtIndex:0];
        video = videoSong.video;
        
        if (!video
            || !video.urls
            || [video.urls count] == 0) {
            continue;
        }
        
        if (!video.path) {
            uncachedSong = personalTopSong.song;
            break;
        }
    }
    
    return uncachedSong;
}

@end
