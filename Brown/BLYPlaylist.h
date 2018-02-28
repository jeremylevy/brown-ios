//
//  BLYPlaylist.h
//  Brown
//
//  Created by Jeremy Levy on 20/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const BLYPlaylistDidUpdateSongNotification;

@interface BLYPlaylist : NSObject <NSCopying>

@property (strong, nonatomic) NSMutableArray *songs;
@property (nonatomic) BOOL firstLoadedSongMustBeSetInRepeatMode;
@property (nonatomic) BOOL isAnAlbumPlaylist;

// Use id not BLYSONG* because externalTopSongs set ExternalTopSong*
- (NSInteger)nbOfSongs;
- (NSInteger)nbOfSongsCached;

- (id)songAtIndex:(NSUInteger)index;
- (void)addSong:(id)song;

- (void)insertSong:(id)song atIndex:(NSUInteger)index;
- (NSInteger)indexOfSong:(id)song;

- (void)removeSongAtIndex:(NSUInteger)index;
- (void)shuffleSongs;

- (void)replaceSongAtIndex:(NSUInteger)index withSong:(id)song;
- (BLYPlaylist *)playlistByRemovingDuplicatedSongs;

- (BOOL)hasCachedSong;
- (id)firstCachedSong;

- (BOOL)isCached;

- (BOOL)containsSong:(id)song;

@end
