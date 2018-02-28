//
//  BLYSearchSongsAutocompleteResultsStore.h
//  Brown
//
//  Created by Jeremy Levy on 20/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const BLYSearchSongsAutocompleteResultsStoreServiceURLPattern;
extern const int BLYSearchSongAutocompleteResultsStoreAutocompleteResultsCacheTime;

@class BLYSearchSongAutocompleteResults, BLYSearchSongAutocompleteResult;

@interface BLYSearchSongAutocompleteResultsStore : NSObject

+ (BLYSearchSongAutocompleteResultsStore *)sharedStore;

+ (NSURL *)URLForServiceToFetchForCountry:(NSString *)country
                                withQuery:(NSString *)query;

- (void)fetchSearchAutocompleteResultsForCountry:(NSString *)country
                                       withQuery:(NSString *)query
                                   andCompletion:(void (^)(BLYSearchSongAutocompleteResults *results, NSError *err))block;

- (BLYSearchSongAutocompleteResult *)fetchSearchSongAutocompleteResultWithContent:(NSString *)content;

- (void)removeOrphanedSearchSongAutocompleteResults;

@end
