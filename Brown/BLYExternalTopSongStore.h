//
//  BLYExternalTopTracksStore.h
//  Brown
//
//  Created by Jeremy Levy on 19/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BLYSongStore.h"

@class BLYPlaylist, BLYExternalTopSongCountry;

extern NSString * const BLYExternalTopSongsStoreServiceURLPattern;
extern const int BLYExternalTopSongsStoreCacheDuration;

@interface BLYExternalTopSongStore : BLYSongStore

+ (BLYExternalTopSongStore *)sharedStore;

+ (NSURL *)URLForServiceToFetchForCountry:(NSString *)country
                                    limit:(int)limit;

- (BLYExternalTopSongCountry *)externalTopSongsForCountry:(NSString *)country;

- (NSArray *)externalTopSongCountries;

- (void)fetchTopSongsForCountry:(NSString *)country
                          limit:(int)count
                          force:(BOOL)force
                 withCompletion:(void (^)(BLYPlaylist *obj, NSError *err))block
            andCompletionForImg:(void (^)(BOOL hasDownloaded, BLYSong *song))imgBlock;

@end
