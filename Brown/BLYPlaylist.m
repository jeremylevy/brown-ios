//
//  BLYPlaylist.m
//  Brown
//
//  Created by Jeremy Levy on 20/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//
#import "BLYPlaylist.h"
#import "BLYSong.h"
#import "BLYAlbum.h"
#import "BLYArtistSong.h"
#import "BLYArtist.h"
#import "BLYSong+Caching.h"
#import "NSMutableArray+Shuffling.h"
#import "BLYCachedSongStore.h"
#import "BLYSongStore.h"

NSString * const BLYPlaylistDidUpdateSongNotification = @"BLYPlaylistDidUpdateSongNotification";

@implementation BLYPlaylist

- (id)init
{
    self = [super init];
    
    if (self) {
        _songs = [[NSMutableArray alloc] init];
        _firstLoadedSongMustBeSetInRepeatMode = NO;
        _isAnAlbumPlaylist = NO;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleCachedSongStoreDidDeleteCacheForSongNotification:)
                                                     name:BLYCachedSongStoreDidDeleteCacheForSong
                                                   object:nil];
    }
    
    return self;
}

- (void)setSongs:(NSMutableArray *)songs
{
    NSMutableArray *uniqueSongs = [[NSMutableArray alloc] init];
    
    // Sometimes iTunes returns same song twice in US top...
    // Gone mad with indexOfSong/containSong... methods...
    // So make sure all songs in playlist are different
    for (BLYSong *s in songs) {
        if ([uniqueSongs indexOfObject:s] != NSNotFound) {
            // TODO: Better way to handle duplicate in playlist...
            continue;
        } else {
            [uniqueSongs addObject:s];
        }
    }
    
    _songs = uniqueSongs;
}

- (NSInteger)nbOfSongs
{
    return [self.songs count];
}

- (NSInteger)nbOfSongsCached
{
    NSInteger nbOfSongsCached = 0;
    
    for (BLYSong *s in self.songs) {
        if (!s.isCached) {
            continue;
        }
        
        nbOfSongsCached++;
    }
    
    return nbOfSongsCached;
}

- (id)songAtIndex:(NSUInteger)index
{
    return [self.songs objectAtIndex:index];
}

- (void)addSong:(id)song
{
    [self.songs addObject:song];
}

- (void)insertSong:(id)song atIndex:(NSUInteger)index
{
    [self.songs insertObject:song
                     atIndex:index];
}

- (NSInteger)indexOfSong:(id)song
{
    return [self.songs indexOfObject:song];
}

- (BOOL)containsSong:(id)song
{
    return [self indexOfSong:song] != NSNotFound;
}

- (void)removeSongAtIndex:(NSUInteger)index
{
    [self.songs removeObjectAtIndex:index];
}

- (void)shuffleSongs
{
    [self.songs bly_shuffle];
}

- (void)replaceSongAtIndex:(NSUInteger)index withSong:(id)song
{
    [self.songs replaceObjectAtIndex:index
                          withObject:song];
}

- (BLYPlaylist *)playlistByRemovingDuplicatedSongs
{
    BLYPlaylist *newPlaylist = [self copy];
    NSMutableArray *songs = [self songs];
    
    NSMutableArray *songsInserted = [[NSMutableArray alloc] init];
    NSMutableArray *songsToInsert = [[NSMutableArray alloc] init];
    
    for (BLYSong *song in songs) {
        NSString *songFormat = [NSString stringWithFormat:@"%@ - %@", song.album.artist.ref.sid, song.title];
        
        if ([songsInserted indexOfObject:songFormat] != NSNotFound) {
            continue;
        }
        
        [songsInserted addObject:songFormat];
        [songsToInsert addObject:song];
    }
    
    newPlaylist.songs = songsToInsert;
    
    return newPlaylist;
}

- (BOOL)hasCachedSong
{
    for (BLYSong *song in _songs) {
        if ([song isCached]) {
            return YES;
        }
    }
    
    return NO;
}

- (id)firstCachedSong
{
    for (BLYSong *song in _songs) {
        if ([song isCached]) {
            return song;
        }
    }
    
    return nil;
}

- (BOOL)isCached
{
    for (BLYSong *song in _songs) {
        if (![song isCached]) {
            return NO;
        }
    }
    
    return true;
}

// Replace uncached song if it was in playlist
- (void)handleCachedSongStoreDidDeleteCacheForSongNotification:(NSNotification *)n
{
    NSDictionary *userInfo = [n userInfo];
    BLYSong *song = [userInfo objectForKey:@"song"];
    NSUInteger indexOfSong = [self indexOfSong:song];
    
    if (indexOfSong == NSNotFound) {
        return;
    }
    
    [self replaceSongAtIndex:indexOfSong withSong:song];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BLYPlaylistDidUpdateSongNotification
                                                        object:self
                                                      userInfo:userInfo];
}

- (id)copyWithZone:(NSZone *)zone
{
    BLYPlaylist *playlist = [[BLYPlaylist alloc] init];
    
    playlist.songs = [self.songs mutableCopy];
    playlist.isAnAlbumPlaylist = self.isAnAlbumPlaylist;
    playlist.firstLoadedSongMustBeSetInRepeatMode = self.firstLoadedSongMustBeSetInRepeatMode;
    
    return playlist;
}

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[BLYPlaylist class]]) {
        return [super isEqual:object];
    }
    
    return [self.songs isEqualToArray:((BLYPlaylist *)object).songs];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
