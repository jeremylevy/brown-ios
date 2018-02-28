//
//  BLYSearchSongResultsStore.h
//  Brown
//
//  Created by Jeremy Levy on 02/10/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BLYSongStore.h"

@class BLYPlaylist, BLYArtist, BLYHTTPConnection, BLYSearchSongResultsViewController;

extern NSString * const BLYSearchSongResultsStoreServiceURLPattern;
extern NSString * const BLYSearchSongResultsStoreArtistSearchURLPattern;
extern NSString * const BLYSearchSongResultsStoreAlbumsSearchURLPattern;

@interface BLYSearchSongResultsStore : BLYSongStore

@property (weak, nonatomic) BLYSearchSongResultsViewController *searchSongResultsVC;

+ (BLYSearchSongResultsStore *)sharedStore;

+ (NSURL *)URLForServiceToFetchForCountry:(NSString *)country withQuery:(NSString *)query;
+ (NSURL *)URLForServiceToFetchAlbumsForArtist:(int)artistSid andCountry:(NSString *)country;

- (void)fetchSearchResultsForCountry:(NSString *)country
                           withQuery:(NSString *)query
                            orArtist:(BLYArtist *)artist
                       andCompletion:(void (^)(NSMutableDictionary *results, NSError *err))block
                 andCompletionForImg:(void (^)(BOOL hasDownloaded, BLYSong *song))imgBlock;

- (BLYHTTPConnection *)fetchAlbumsForArtist:(int)artistSid
                                   orSearch:(NSString *)search
                                 andCountry:(NSString *)country
                             withCompletion:(void (^)(NSMutableArray *results, NSError *err))completionBlock
                        andCompletionForImg:(void (^)(BOOL hasDownloaded, BLYAlbum *album))imgBlock;

@end
