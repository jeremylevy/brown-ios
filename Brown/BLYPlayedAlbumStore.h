//
//  BLYPlayedAlbumStore.h
//  Brown
//
//  Created by Jeremy Levy on 28/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>

extern const int BLYPlayedAlbumStoreMaxAlbums;

@class BLYSong, BLYPlayedAlbum, BLYAlbum;

@interface BLYPlayedAlbumStore : NSObject

+ (BLYPlayedAlbumStore *)sharedStore;

- (void)insertPlayedAlbum:(BLYAlbum *)album;
- (NSArray *)fetchPlayedAlbums;
- (BLYPlayedAlbum *)playedAlbumWithAlbum:(BLYAlbum *)album;
- (void)updatePlayedAtForPlayedAlbum:(BLYPlayedAlbum *)playedAlbum;
- (void)deletePlayedAlbum:(BLYPlayedAlbum *)playedAlbum;

@end
