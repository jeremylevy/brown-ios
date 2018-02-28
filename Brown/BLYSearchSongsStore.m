//
//  BLYSearchSongsStore.m
//  Brown
//
//  Created by Jeremy Levy on 03/10/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "BLYSearchSongsStore.h"
#import "BLYSearchSong.h"
#import "BLYStore.h"
#import "BLYSearchSongAutocompleteResult.h"
#import "BLYSearchSongAutocompleteResults.h"
#import "NSString+Escaping.h"
#import "BLYAlbum.h"
#import "BLYSong.h"
#import "BLYArtist.h"
#import "BLYSongStore.h"
#import "BLYSearchSongResult.h"

const int BLYSearchSongsStoreMaxSearch = 8;

@implementation BLYSearchSongsStore

+ (BLYSearchSongsStore *)sharedStore
{
    static BLYSearchSongsStore *searchSongsStore = nil;
    
    if (!searchSongsStore) {
        searchSongsStore = [[BLYSearchSongsStore alloc] init];
    }
    
    return searchSongsStore;
}

- (NSArray *)searchSongs
{
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSManagedObjectModel *model = [[BLYStore sharedStore] model];
    NSEntityDescription *entity = [model.entitiesByName objectForKey:@"BLYSearchSong"];
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"searchedAt"
                                                                     ascending:NO];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"hidden = 0"];
    NSError *err = nil;
    
    request.entity = entity;
    request.predicate = predicate;
    
    NSArray *results = [[[BLYStore sharedStore] context] executeFetchRequest:request
                                                                       error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", err.localizedDescription];
    }
    
    results = [results sortedArrayUsingDescriptors:@[sortDescriptor]];
    
    return results;
}

- (NSArray *)hiddenSearchSongs
{
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSManagedObjectModel *model = [[BLYStore sharedStore] model];
    NSEntityDescription *entity = [model.entitiesByName objectForKey:@"BLYSearchSong"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"hidden = YES"];
    NSError *err = nil;
    
    request.entity = entity;
    request.predicate = predicate;
    
    NSArray *results = [[[BLYStore sharedStore] context] executeFetchRequest:request error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", [err localizedDescription]];
    }
    
    return results;
}

- (BLYSearchSongAutocompleteResults *)fetchSearchSongs
{
    BLYSearchSongAutocompleteResults *searchResults = [[BLYSearchSongAutocompleteResults alloc] init];
    NSArray *results = [self searchSongs];
    
    for (BLYSearchSong *searchSong in results) {
        BLYSearchSongResult *searchResult = [[BLYSearchSongResult alloc] init];
        
        searchResult.content = searchSong.search;
        
        [searchResults addResult:searchResult];
    }
    
    return searchResults;
}

- (BLYSearchSong *)fetchSearchSongWithSearch:(NSString *)search
{
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSManagedObjectModel *model = [[BLYStore sharedStore] model];
    NSEntityDescription *entity = [model.entitiesByName objectForKey:@"BLYSearchSong"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"search = %@",
                              [[search lowercaseString] bly_stringByRemovingAccents]];
    NSError *err = nil;
    
    request.entity = entity;
    request.predicate = predicate;
    
    NSArray *results = [[[BLYStore sharedStore] context] executeFetchRequest:request
                                                                       error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", err.localizedDescription];
    }
    
    return [results count] > 0 ? results[0] : nil;
}

- (BLYSearchSong *)fetchSearchSongWithArtist:(BLYArtist *)artist
{
    if (!artist) {
        return nil;
    }
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSManagedObjectModel *model = [[BLYStore sharedStore] model];
    NSEntityDescription *entity = [model.entitiesByName objectForKey:@"BLYSearchSong"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"artist = %@", artist];
    NSError *err = nil;
    
    request.entity = entity;
    request.predicate = predicate;
    
    NSArray *results = [[[BLYStore sharedStore] context] executeFetchRequest:request
                                                                       error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", err.localizedDescription];
    }
    
    return [results count] > 0 ? results[0] : nil;
}

- (BLYSearchSong *)fetchSearchSongWithAlbum:(BLYAlbum *)album
{
    if (!album) {
        return nil;
    }
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSManagedObjectModel *model = [[BLYStore sharedStore] model];
    NSEntityDescription *entity = [model.entitiesByName objectForKey:@"BLYSearchSong"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"ANY albums = %@", album];
    NSError *err = nil;
    
    request.includesPendingChanges = YES;
    request.entity = entity;
    request.predicate = predicate;
    
    NSArray *results = [[[BLYStore sharedStore] context] executeFetchRequest:request error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", err.localizedDescription];
    }
    
    return [results count] > 0 ? results[0] : nil;
}

- (void)updateSearchedAtDateOfSearchSong:(BLYSearchSong *)searchSong
{
    searchSong.searchedAt = [NSDate date];
    //searchSong.hidden = [NSNumber numberWithBool:NO];
    
//    NSArray *searchSongs = [self searchSongs];
//
//    if ([searchSongs count] > BLYSearchSongsStoreMaxSearch) {
//        [[BLYStore sharedStore] deleteObject:[searchSongs lastObject]];
//    }
    
    [[BLYStore sharedStore] saveChanges];
}

- (void)clearOldSongSearchs
{
    NSArray *searchSongs = [self searchSongs];
    
    if ([searchSongs count] <= BLYSearchSongsStoreMaxSearch) {
        return;
    }
    
    for (int i = BLYSearchSongsStoreMaxSearch; i < [searchSongs count]; i++) {
        [[BLYStore sharedStore] deleteObject:[searchSongs objectAtIndex:i]];
    }
}

- (BLYSearchSong *)insertSongsSearchWithSearch:(NSString *)search
                             andSearchedArtist:(BLYArtist *)artist
                                      withType:(NSString *)type
                                     butHideIt:(BOOL)hideIt
{
    BLYSearchSong *searchSong = [self fetchSearchSongWithArtist:artist];
    
    if (!searchSong) {
        searchSong = [NSEntityDescription insertNewObjectForEntityForName:@"BLYSearchSong"
                                                   inManagedObjectContext:[[BLYStore sharedStore] context]];
        
        // Searched artist
        if (artist && !search) {
            search = [[BLYSongStore sharedStore] realNameForArtist:artist];
        }
        
        searchSong.search = [[search lowercaseString] bly_stringByRemovingAccents];
        searchSong.searchedAt = [NSDate date];
        searchSong.type = type;
        searchSong.hidden = [NSNumber numberWithBool:hideIt];
        
        // Default value
        searchSong.lastSelectedSegment = [NSNumber numberWithInteger:NSNotFound];
        searchSong.lastSelectedAlbum = [NSNumber numberWithInteger:NSNotFound];
        
        searchSong.artist = artist;
        
        if (artist) {
            [self insertSongSearch:searchSong forArtist:artist];
        }
    } else if (!hideIt) {
        searchSong.hidden = [NSNumber numberWithBool:hideIt];
        
        [self updateSearchedAtDateOfSearchSong:searchSong];
    }
    
    //[[BLYStore sharedStore] saveChanges];
    
    if (!hideIt) {
        [self clearOldSongSearchs];
    }
    
    return searchSong;
}

- (void)clearHiddenSongSearchs
{
    [self clearHiddenSongSearchsExcept:nil];
}

- (void)clearHiddenSongSearchsExcept:(BLYSearchSong *)searchSongExcepted
{
    NSArray *hiddenSearchSongs = [self hiddenSearchSongs];
    
    for (BLYSearchSong *searchSong in hiddenSearchSongs) {
        if (searchSongExcepted && [searchSong isEqual:searchSongExcepted]) {
            continue;
        }
        
        [self deleteSearchSong:searchSong];
    }
}

- (void)deleteSearchSong:(BLYSearchSong *)searchSong
{
    [[BLYStore sharedStore] deleteObject:searchSong];
    
    [[BLYStore sharedStore] saveChanges];
}

- (BLYSearchSong *)insertSongSearch:(BLYSearchSong *)searchSong
                          forArtist:(BLYArtist *)artist
{
    artist.search = searchSong;
    
    return searchSong;
}

- (BLYSearchSong *)insertSongSearch:(BLYSearchSong *)searchSong
                           forAlbum:(BLYAlbum *)album
{
    NSSet *searchSongsSet = album.searches;
    NSMutableSet *searchSongs = [searchSongsSet mutableCopy];
    
    if (![searchSongs containsObject:searchSong]) {
        [searchSongs addObject:searchSong];
    }
    
    album.searches = [searchSongs copy];
    
    return searchSong;
}

- (BLYSearchSong *)insertSongSearch:(BLYSearchSong *)searchSong
                            forSong:(BLYSong *)song
{
    NSSet *searchSongsSet = song.searches;
    NSMutableSet *searchSongs = [searchSongsSet mutableCopy];
    
    if (![searchSongs containsObject:searchSong]) {
        [searchSongs addObject:searchSong];
    }
    
    song.searches = [searchSongs copy];
    
    return searchSong;
}

- (void)insertSongSearch:(BLYSearchSong *)searchSong
                forSongs:(NSMutableArray *)songs
{
    searchSong.songs = [NSOrderedSet orderedSetWithArray:[songs copy]];
    
    for (BLYSong *song in songs) {
        [self insertSongSearch:searchSong forSong:song];
    }
    
    //[[BLYStore sharedStore] saveChanges];
}

- (BLYSearchSong *)insertSongSearch:(BLYSearchSong *)searchSong
                           forVideo:(BLYSong *)video
{
    NSSet *searchVideosSet = video.searchesVideos;
    NSMutableSet *searchVideos = [searchVideosSet mutableCopy];
    
    if (![searchVideos containsObject:searchSong]) {
        [searchVideos addObject:searchSong];
    }
    
    video.searchesVideos = [searchVideos copy];
    
    return searchSong;
}

- (void)insertSongSearch:(BLYSearchSong *)searchSong
               forVideos:(NSMutableArray *)videos
{
    searchSong.videos = [NSOrderedSet orderedSetWithArray:[videos copy]];
    
    for (BLYSong *video in videos) {
        [self insertSongSearch:searchSong forVideo:video];
    }
    
    //[[BLYStore sharedStore] saveChanges];
}

- (void)insertSongSearch:(BLYSearchSong *)searchSong
               forAlbums:(NSMutableArray *)albums
{
    searchSong.albums = [NSOrderedSet orderedSetWithArray:[albums copy]];
    
    for (BLYAlbum *album in albums) {
        [self insertSongSearch:searchSong forAlbum:album];
    }
    
    //[[BLYStore sharedStore] saveChanges];
}

- (void)setHidden:(BOOL)hidden forSearchSong:(BLYSearchSong *)searchSong
{
    searchSong.hidden = [NSNumber numberWithBool:hidden];
    
    if (!hidden) {
        [self clearOldSongSearchs];
    }
    
    [[BLYStore sharedStore] saveChanges];
}

- (void)setLastSelectedSegment:(NSInteger)selectedSegment
                 forSearchSong:(BLYSearchSong *)searchSong
{
    searchSong.lastSelectedSegment = [NSNumber numberWithInteger:selectedSegment];
//    // Show it after user has played a song
//    searchSong.hidden = [NSNumber numberWithBool:NO];
    
    [[BLYStore sharedStore] saveChanges];
}

- (void)setLastSelectedAlbum:(NSInteger)selectedAlbum
               forSearchSong:(BLYSearchSong *)searchSong
{
    searchSong.lastSelectedAlbum = [NSNumber numberWithInteger:selectedAlbum];
    
    [[BLYStore sharedStore] saveChanges];
}

@end
