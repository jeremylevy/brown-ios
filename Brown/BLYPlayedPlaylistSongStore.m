//
//  BLYPlayedPlaylistSongStore.m
//  Brown
//
//  Created by Jeremy Levy on 28/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import "BLYPlayedPlaylistSongStore.h"
#import "BLYStore.h"
#import "BLYPlayedPlaylistSong.h"
#import "BLYSong.h"

@implementation BLYPlayedPlaylistSongStore

+ (BLYPlayedPlaylistSongStore *)sharedStore
{
    static id playedPlaylistSongStore = nil;
    
    if (!playedPlaylistSongStore) {
        playedPlaylistSongStore = [[BLYPlayedPlaylistSongStore alloc] init];
    }
    
    return playedPlaylistSongStore;
}

- (void)cleanPlayedPlaylistSongs
{
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [[[[BLYStore sharedStore] model] entitiesByName] objectForKey:@"BLYPlayedPlaylistSong"];
    NSError *err = nil;
    
    [request setEntity:entity];
    
    NSArray *results = [[[BLYStore sharedStore] context] executeFetchRequest:request error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", [err localizedDescription]];
    }
    
    for (BLYPlayedPlaylistSong *playedPlaylistSong in results) {
        [[BLYStore sharedStore] deleteObject:playedPlaylistSong];
    }
    
    [[BLYStore sharedStore] saveChanges];
}

- (void)cleanCurrentPlayedPlaylistSong
{
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [[[[BLYStore sharedStore] model] entitiesByName] objectForKey:@"BLYPlayedPlaylistSong"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isCurrent = %@", [NSNumber numberWithBool:YES]];
    NSError *err = nil;
    
    [request setEntity:entity];
    [request setPredicate:predicate];
    
    NSArray *results = [[[BLYStore sharedStore] context] executeFetchRequest:request error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", [err localizedDescription]];
    }
    
    for (BLYPlayedPlaylistSong *playedPlaylistSong in results) {
        playedPlaylistSong.isCurrent = [NSNumber numberWithBool:NO];
    }
    
    [[BLYStore sharedStore] saveChanges];
}

- (BLYPlayedPlaylistSong *)insertPlayedPlaylistSongWithRank:(int)rank
                                                    current:(BOOL)current
                                            loadedFromAlbum:(BOOL)loadedFromAlbum
                                                    forSong:(BLYSong *)song
{
    BLYPlayedPlaylistSong *playedPlaylistSong = [NSEntityDescription insertNewObjectForEntityForName:@"BLYPlayedPlaylistSong"
                                                                inManagedObjectContext:[[BLYStore sharedStore] context]];
    
    playedPlaylistSong.rank = [NSNumber numberWithInt:rank];
    playedPlaylistSong.isCurrent = [NSNumber numberWithBool:current];
    playedPlaylistSong.song = song;
    playedPlaylistSong.isLoadedFromAlbum = [NSNumber numberWithBool:loadedFromAlbum];
    
    song.playedPlaylistSong = playedPlaylistSong;
    
    [[BLYStore sharedStore] saveChanges];
    
    return playedPlaylistSong;
}

- (BLYPlayedPlaylistSong *)updateIsCurrent:(BOOL)current
                     forPlayedPlaylistSong:(BLYPlayedPlaylistSong *)playedPlaylistSong
{
    [self cleanCurrentPlayedPlaylistSong];
    
    playedPlaylistSong.isCurrent = [NSNumber numberWithBool:current];
    
    [[BLYStore sharedStore] saveChanges];
    
    return playedPlaylistSong;
}

- (NSArray *)fetchPlayedPlaylistSongs
{
    NSMutableArray *playedPlaylistSongs = [[NSMutableArray alloc] init];
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [[[[BLYStore sharedStore] model] entitiesByName] objectForKey:@"BLYPlayedPlaylistSong"];
    
    NSSortDescriptor *dateSort = [[NSSortDescriptor alloc] initWithKey:@"rank" ascending:YES];
    NSError *err = nil;
    
    [request setEntity:entity];
    [request setSortDescriptors:@[dateSort]];
    
    NSArray *results = [[[BLYStore sharedStore] context] executeFetchRequest:request error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", [err localizedDescription]];
    }
    
    for (BLYPlayedPlaylistSong *playedPlaylistSong in results) {
        [playedPlaylistSongs addObject:playedPlaylistSong];
    }
    
    return [playedPlaylistSongs copy];
}

@end
