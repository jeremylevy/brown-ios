//
//  BLYSong.m
//  Brown
//
//  Created by Jeremy Levy on 31/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import "BLYSong.h"
#import "BLYAlbum.h"
#import "BLYArtistSong.h"
#import "BLYExternalTopSong.h"
#import "BLYPersonalTopSong.h"
#import "BLYPlayedPlaylistSong.h"
#import "BLYPlayedSong.h"
#import "BLYSearchSong.h"
#import "BLYSong.h"
#import "BLYVideo.h"
#import "BLYVideoSong.h"


@implementation BLYSong

@dynamic duration;
@dynamic isVideo;
@dynamic lastPlayPlayedPercent;
@dynamic loadedByUser;
@dynamic rankInAlbum;
@dynamic sid;
@dynamic title;
@dynamic videosReordered;
@dynamic album;
@dynamic artist;
@dynamic externalTopSongs;
@dynamic personalTopSong;
@dynamic playedPlaylistSong;
@dynamic playedSong;
@dynamic cachedSong;
@dynamic relatedSongs;
@dynamic relatedToSongs;
@dynamic searches;
@dynamic searchesVideos;
@dynamic videoRepresentation;
@dynamic videos;

@end
