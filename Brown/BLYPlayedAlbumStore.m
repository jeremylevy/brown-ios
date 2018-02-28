//
//  BLYPlayedAlbumStore.m
//  Brown
//
//  Created by Jeremy Levy on 28/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import "BLYStore.h"
#import "BLYPlayedAlbumStore.h"
#import "BLYAlbum.h"
#import "BLYPlayedAlbum.h"

const int BLYPlayedAlbumStoreMaxAlbums = 25;

@implementation BLYPlayedAlbumStore

+ (BLYPlayedAlbumStore *)sharedStore
{
    static id playedAlbumStore = nil;
    
    if (!playedAlbumStore) {
        playedAlbumStore = [[BLYPlayedAlbumStore alloc] init];
    }
    
    return playedAlbumStore;
}

- (void)insertPlayedAlbum:(BLYAlbum *)album
{
    NSArray *playedAlbums = [self fetchPlayedAlbums];
    
    if ([playedAlbums count] >= BLYPlayedAlbumStoreMaxAlbums) {
        [self deletePlayedAlbum:[playedAlbums lastObject]];
    }
    
    BLYPlayedAlbum *playedAlbum = [NSEntityDescription insertNewObjectForEntityForName:@"BLYPlayedAlbum"
                                                                inManagedObjectContext:[[BLYStore sharedStore] context]];
    
    [playedAlbum setPlayedAt:[NSDate date]];
    [playedAlbum setAlbum:album];
    
    [album setPlayedAlbum:playedAlbum];
    
    [[BLYStore sharedStore] saveChanges];
}

- (NSArray *)fetchPlayedAlbums
{
    NSMutableArray *playedAlbums = [[NSMutableArray alloc] init];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [[[[BLYStore sharedStore] model] entitiesByName] objectForKey:@"BLYPlayedAlbum"];
    NSSortDescriptor *dateSort = [[NSSortDescriptor alloc] initWithKey:@"playedAt" ascending:NO];
    NSError *err = nil;
    
    [request setEntity:entity];
    [request setSortDescriptors:@[dateSort]];
    
    NSArray *results = [[[BLYStore sharedStore] context] executeFetchRequest:request error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", [err localizedDescription]];
    }
    
    for (BLYPlayedAlbum *playedAlbum in results) {
        [playedAlbums addObject:playedAlbum];
    }
    
    return [playedAlbums copy];
}

- (BLYPlayedAlbum *)playedAlbumWithAlbum:(BLYAlbum *)album
{
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [[[[BLYStore sharedStore] model] entitiesByName] objectForKey:@"BLYPlayedAlbum"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"album = %@", album];
    NSError *err = nil;
    
    [request setEntity:entity];
    [request setPredicate:predicate];
    
    NSArray *results = [[[BLYStore sharedStore] context] executeFetchRequest:request error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", [err localizedDescription]];
    }
    
    return [results count] > 0 ? results[0] : nil;
}

- (void)updatePlayedAtForPlayedAlbum:(BLYPlayedAlbum *)playedAlbum
{
    [playedAlbum setPlayedAt:[NSDate date]];
    
    [[BLYStore sharedStore] saveChanges];
}

- (void)deletePlayedAlbum:(BLYPlayedAlbum *)playedAlbum
{
    [[BLYStore sharedStore] deleteObject:playedAlbum];
    
    [[BLYStore sharedStore] saveChanges];
}

@end
