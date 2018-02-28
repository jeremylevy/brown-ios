//
//  BLYPlayedPlaylistSongStore.h
//  Brown
//
//  Created by Jeremy Levy on 28/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BLYSong, BLYPlayedPlaylistSong;

@interface BLYPlayedPlaylistSongStore : NSObject

+ (BLYPlayedPlaylistSongStore *)sharedStore;

- (void)cleanPlayedPlaylistSongs;
- (BLYPlayedPlaylistSong *)insertPlayedPlaylistSongWithRank:(int)rank
                                                    current:(BOOL)current
                                            loadedFromAlbum:(BOOL)loadedFromAlbum
                                                    forSong:(BLYSong *)song;
- (NSArray *)fetchPlayedPlaylistSongs;

- (BLYPlayedPlaylistSong *)updateIsCurrent:(BOOL)current
                     forPlayedPlaylistSong:(BLYPlayedPlaylistSong *)playedPlaylistSong;

@end
