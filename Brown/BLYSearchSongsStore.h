//
//  BLYSearchSongsStore.h
//  Brown
//
//  Created by Jeremy Levy on 03/10/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BLYSongStore.h"

@class BLYSearchSong, BLYSearchSongAutocompleteResults, BLYArtistSong;

extern const int BLYSearchSongsStoreMaxSearch;

@interface BLYSearchSongsStore : BLYSongStore

+ (BLYSearchSongsStore *)sharedStore;

- (BLYSearchSong *)insertSongsSearchWithSearch:(NSString *)search
                             andSearchedArtist:(BLYArtist *)artist
                                      withType:(NSString *)type
                                     butHideIt:(BOOL)hideIt;

- (void)insertSongSearch:(BLYSearchSong *)searchSong
                forSongs:(NSMutableArray *)songs;

- (void)insertSongSearch:(BLYSearchSong *)searchSong
               forVideos:(NSMutableArray *)videos;

- (void)insertSongSearch:(BLYSearchSong *)searchSong
               forAlbums:(NSMutableArray *)albums;

- (BLYSearchSongAutocompleteResults *)fetchSearchSongs;

- (BLYSearchSong *)fetchSearchSongWithSearch:(NSString *)search;

- (BLYSearchSong *)fetchSearchSongWithArtist:(BLYArtist *)artist;

- (BLYSearchSong *)fetchSearchSongWithAlbum:(BLYAlbum *)album;

- (void)updateSearchedAtDateOfSearchSong:(BLYSearchSong *)searchSong;

- (void)clearHiddenSongSearchsExcept:(BLYSearchSong *)searchSong;

- (void)clearHiddenSongSearchs;

- (void)setLastSelectedSegment:(NSInteger)selectedSegment
                 forSearchSong:(BLYSearchSong *)searchSong;

- (void)setLastSelectedAlbum:(NSInteger)selectedAlbum
               forSearchSong:(BLYSearchSong *)searchSong;

- (void)setHidden:(BOOL)hidden forSearchSong:(BLYSearchSong *)searchSong;

- (void)deleteSearchSong:(BLYSearchSong *)searchSong;

@end
