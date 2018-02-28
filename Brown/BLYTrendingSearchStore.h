//
//  BLYTrendingSearchStore.h
//  Brown
//
//  Created by Jeremy Levy on 03/02/2018.
//  Copyright © 2018 Jeremy Levy. All rights reserved.
//

@class BLYTrendingSearch, BLYSearchSongAutocompleteResults;

@interface BLYTrendingSearchStore : NSObject

+ (BLYTrendingSearchStore *)sharedStore;

- (BLYTrendingSearch *)insertTrendingSearchWithSearch:(NSString *)search andRank:(int)rank;
- (BLYSearchSongAutocompleteResults *)fetchTrendingSearchesAsAutocompleteResultsWithCompletionForUpdate:(void (^)(BLYSearchSongAutocompleteResults *results, NSError *err))block;

@end
