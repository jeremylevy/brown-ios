//
//  BLYTrendingSearchStore.m
//  Brown
//
//  Created by Jeremy Levy on 03/02/2018.
//  Copyright © 2018 Jeremy Levy. All rights reserved.
//

#import "BLYTrendingSearchStore.h"
#import "BLYTrendingSearch+CoreDataProperties.h"
#import "BLYExternalTopSongStore.h"
#import "BLYSearchSongAutocompleteResults.h"
#import "BLYSearchSongResult.h"
#import "BLYStore.h"
#import "BLYHTTPConnection.h"
#import "BLYPlaylist.h"
#import "BLYSong.h"
#import "BLYArtistSong.h"
#import "NSString+Matching.h"

NSString * const BLYTrendingSearchStoreServiceURLPattern = @"http://api.deezer.com/1.0/gateway.php?method=mobile_searchtrendings&output=3&input=3&api_key=ZAIVAHCEISOHWAICUQUEXAEPICENGUAFAEZAIPHAELEEVAHPHUCUFONGUAPASUAY&sid=freda3e6c083329ef333f7c67ef35759ac583322";

@implementation BLYTrendingSearchStore

+ (BLYTrendingSearchStore *)sharedStore
{
    static BLYTrendingSearchStore *trendingSearchesStore = nil;
    
    if (!trendingSearchesStore) {
        trendingSearchesStore = [[BLYTrendingSearchStore alloc] init];
    }
    
    return trendingSearchesStore;
}

- (BLYTrendingSearch *)insertTrendingSearchWithSearch:(NSString *)search andRank:(int)rank
{
    BLYStore *store = [BLYStore sharedStore];
    BLYTrendingSearch *trendingSearch = [NSEntityDescription insertNewObjectForEntityForName:@"BLYTrendingSearch"
                                                                      inManagedObjectContext:store.context];
    
    trendingSearch.search = search;
    trendingSearch.rank = [NSNumber numberWithInt:rank];
    
    [store saveChanges];
    
    return trendingSearch;
}

- (NSArray *)fetchTrendingSearches
{
    BLYStore *store = [BLYStore sharedStore];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [store.model.entitiesByName objectForKey:@"BLYTrendingSearch"];
    
    request.entity = entity;
    
    NSError *err = nil;
    NSArray *results = [store.context executeFetchRequest:request error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", err.localizedDescription];
    }
    
    NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"rank" ascending:YES];
    
    NSArray *sortedResults = [results sortedArrayUsingDescriptors:[NSArray arrayWithObject:sort]];
    
    return sortedResults;
}

- (BLYSearchSongAutocompleteResults *)fetchTrendingSearchesAsAutocompleteResultsWithCompletionForUpdate:(void (^)(BLYSearchSongAutocompleteResults *results, NSError *err))block
{
    BLYSearchSongAutocompleteResults * (^constructAutocompleteResults)(NSArray *results) = ^(NSArray *results){
        BLYSearchSongAutocompleteResults *searchResults = [[BLYSearchSongAutocompleteResults alloc] init];
        
        for (BLYTrendingSearch *trendingSearch in results) {
            BLYSearchSongResult *searchResult = [[BLYSearchSongResult alloc] init];
            
            searchResult.content = trendingSearch.search;
            
            [searchResults addResult:searchResult];
        }
        
        return searchResults;
    };
    
    NSArray *results = [self fetchAndUpdateTrendingSearchesWithCompletionForUpdate:^(NSArray *results, NSError *err) {
        if (block) {
            if (err) {
                return block(nil, err);
            }
            
            block(constructAutocompleteResults(results), err);
        }
    }];
    
    return constructAutocompleteResults(results);
}

- (NSArray *)fetchAndUpdateTrendingSearchesWithCompletionForUpdate:(void (^)(NSArray *results, NSError *err))block
{
    __weak BLYTrendingSearchStore *weakSelf = self;
    NSArray *oldTrendingSearches = [self fetchTrendingSearches];
    
//    [[BLYExternalTopSongStore sharedStore] fetchTopSongsForCountry:@"us" limit:10 force:NO withCompletion:^(BLYPlaylist *playlist, NSError *err) {
//        if (err) {
//            if (block) {
//                block(nil, err);
//            }
//
//            return;
//        }
//
//        NSMutableArray *trendingSearchesObj = [[NSMutableArray alloc] init];
//        NSMutableArray *artists = [[NSMutableArray alloc] init];
//        int rank = 1;
//
//        for (BLYSong *song in playlist.songs) {
//            if (rank > 5) {
//                break;
//            }
//
////            if ([song.artist.name bly_match:@"&|,"]) {
////                continue;
////            }
//
//            if ([artists containsObject:song.artist.name]) {
//                continue;
//            }
//
//            [artists addObject:song.artist.name];
//
//            BLYTrendingSearch *trendingSearchObj = [weakSelf insertTrendingSearchWithSearch:song.artist.name andRank:rank];
//
//            [trendingSearchesObj addObject:trendingSearchObj];
//
//            rank++;
//        }
//
//        if ([oldTrendingSearches count]) {
//            for (BLYTrendingSearch *oldTrendingSearch in oldTrendingSearches) {
//                [[BLYStore sharedStore] deleteObject:oldTrendingSearch];
//            }
//
//            [[BLYStore sharedStore] saveChanges];
//        }
//
//        if (block) {
//            block(trendingSearchesObj, nil);
//        }
//    } andCompletionForImg:^(BOOL hasDownloaded, BLYSong *song) {
//
//    }];
    
    void(^completionBlock)(NSData *obj, NSError *err) = ^(NSData *obj, NSError *err){
        if (err) {
            if (block) {
                block(nil, err);
            }

            return;
        }

        NSDictionary *d = [NSJSONSerialization JSONObjectWithData:obj options:0 error:nil];
        NSArray *error = [d objectForKey:@"error"];

        if ([error count]) {
            if (block) {
                block(nil, [NSError errorWithDomain:@"com.brown.blytrendingsearchesstore"
                                               code:0
                                           userInfo:@{}]);
            }

            return;
        }

        NSDictionary *results = [d objectForKey:@"results"];
        NSArray *trendingSearches = [results objectForKey:@"data"];
        NSMutableArray *trendingSearchesObj = [[NSMutableArray alloc] init];
        int rank = 0;

        for (NSDictionary *trendingSearch in trendingSearches) {
            BLYTrendingSearch *trendingSearchObj = [weakSelf insertTrendingSearchWithSearch:[trendingSearch objectForKey:@"QUERY"] andRank:rank];

            [trendingSearchesObj addObject:trendingSearchObj];

            rank++;
        }

        if ([oldTrendingSearches count]) {
            for (BLYTrendingSearch *oldTrendingSearch in oldTrendingSearches) {
                [[BLYStore sharedStore] deleteObject:oldTrendingSearch];
            }

            [[BLYStore sharedStore] saveChanges];
        }

        if (block) {
            block(trendingSearchesObj, nil);
        }
    };

    NSURL *url = [NSURL URLWithString:BLYTrendingSearchStoreServiceURLPattern];

    // Set up the connection as normal
    NSURLRequest *req = [NSURLRequest requestWithURL:url];

    BLYHTTPConnection *connection = [[BLYHTTPConnection alloc] initWithRequest:req];

    connection.displayActivityIndicator = NO;
    connection.completionBlock = completionBlock;

    [connection start];
    
    return oldTrendingSearches;
}

@end
