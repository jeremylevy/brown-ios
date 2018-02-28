//
//  BLYSearchSongsAutocompleteResultsStore.m
//  Brown
//
//  Created by Jeremy Levy on 20/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import "BLYSearchSongAutocompleteResultsStore.h"
#import "BLYHTTPConnection.h"
#import "BLYSearchSongAutocompleteResults.h"
#import "BLYSearchSongAutocompleteResult.h"
#import "NSString+Escaping.h"
#import "BLYStore.h"
#import "BLYSearchSongAutocomplete.h"

NSString * const BLYSearchSongsAutocompleteResultsStoreServiceURLPattern = @"http://suggestqueries.google.com/complete/search?hl=%@&ds=yt&client=youtube&hjson=t&q=%@&cp=1";
const int BLYSearchSongAutocompleteResultsStoreAutocompleteResultsCacheTime = 7 * 24 * 3600;

@implementation BLYSearchSongAutocompleteResultsStore

+ (BLYSearchSongAutocompleteResultsStore *)sharedStore
{
    static BLYSearchSongAutocompleteResultsStore *autocompleteResultsStore = nil;
    
    if (!autocompleteResultsStore) {
        autocompleteResultsStore = [[BLYSearchSongAutocompleteResultsStore alloc] init];
    }
    
    return autocompleteResultsStore;
}

+ (NSURL *)URLForServiceToFetchForCountry:(NSString *)country withQuery:(NSString *)query
{
    country = [country bly_stringByAddingPercentEscapesForQuery];
    query = [query bly_stringByAddingPercentEscapesForQuery];
    
    NSString *url = [NSString stringWithFormat:BLYSearchSongsAutocompleteResultsStoreServiceURLPattern, country, query];
    
    return [NSURL URLWithString:url];
}

- (BLYSearchSongAutocomplete *)fetchSearchSongAutocompleteWithSearch:(NSString *)search
{
    BLYStore *store = [BLYStore sharedStore];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [store.model.entitiesByName objectForKey:@"BLYSearchSongAutocomplete"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"search = %@", search];
    
    request.entity = entity;
    request.predicate = predicate;
    
    NSError *err = nil;
    NSArray *results = [store.context executeFetchRequest:request error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", err.localizedDescription];
    }
    
    return [results count] > 0 ? [results objectAtIndex:0] : nil;
}

- (BLYSearchSongAutocomplete *)insertSearchSongAutocompleteWithSearch:(NSString *)search
{
    BLYStore *store = [BLYStore sharedStore];
    
    BLYSearchSongAutocomplete *searchAutocomplete = [NSEntityDescription insertNewObjectForEntityForName:@"BLYSearchSongAutocomplete"
                                                                                  inManagedObjectContext:store.context];
    
    searchAutocomplete.search = search;
    searchAutocomplete.searchedAt = [NSDate date];
    
    return searchAutocomplete;
}

- (BLYSearchSongAutocompleteResult *)fetchSearchSongAutocompleteResultWithContent:(NSString *)content
{
    BLYStore *store = [BLYStore sharedStore];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [store.model.entitiesByName objectForKey:@"BLYSearchSongAutocompleteResult"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"content = %@", content];
    
    request.entity = entity;
    request.predicate = predicate;
    
    NSError *err = nil;
    NSArray *results = [store.context executeFetchRequest:request error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", err.localizedDescription];
    }
    
    return [results count] > 0 ? [results objectAtIndex:0] : nil;
}

- (BLYSearchSongAutocompleteResult *)insertSearchSongAutocompleteResultWithContent:(NSString *)content
                                                                   forAutocomplete:(BLYSearchSongAutocomplete *)autocomplete
{
    BLYStore *store = [BLYStore sharedStore];
    BLYSearchSongAutocompleteResult *searchAutocompleteResult = [self fetchSearchSongAutocompleteResultWithContent:content];
    
    if (!searchAutocompleteResult) {
        searchAutocompleteResult = [NSEntityDescription insertNewObjectForEntityForName:@"BLYSearchSongAutocompleteResult"
                                                                 inManagedObjectContext:store.context];
        
        searchAutocompleteResult.content = content;
    }
    
    [searchAutocompleteResult addSearchesObject:autocomplete];
    
    NSOrderedSet *results = autocomplete.results;
    
    if (!results) {
        results = [[NSOrderedSet alloc] init];
    }
    
    NSMutableArray *resultsAsArray = [[results array] mutableCopy];
    
    [resultsAsArray addObject:searchAutocompleteResult];
    
    autocomplete.results = [NSOrderedSet orderedSetWithArray:[resultsAsArray copy]];
    
    return searchAutocompleteResult;
}

- (void)deleteSearchSongAutocomplete:(BLYSearchSongAutocomplete *)searchAutocomplete
{
    BLYStore *store = [BLYStore sharedStore];
    
    [store deleteObject:searchAutocomplete];
}

- (void)removeOrphanedSearchSongAutocompleteResults
{
    BLYStore *store = [BLYStore sharedStore];
    NSEntityDescription *entity = [store.model.entitiesByName objectForKey:@"BLYSearchSongAutocompleteResult"];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"searches.@count = 0"];
    
    request.entity = entity;
    request.predicate = predicate;
    
    NSError *error = nil;
    NSArray *results = [store.context executeFetchRequest:request error:&error];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", error.localizedDescription];
    }
    
    for (BLYSearchSongAutocompleteResult *result in results) {
        [store deleteObject:result];
    }
}

- (void)fetchSearchAutocompleteResultsForCountry:(NSString *)country
                                       withQuery:(NSString *)query
                                   andCompletion:(void (^)(BLYSearchSongAutocompleteResults *results, NSError *err))block;
{
    BLYSearchSongAutocomplete *searchSongAutocomplete = [self fetchSearchSongAutocompleteWithSearch:query];
    
    if (searchSongAutocomplete) {
        NSTimeInterval searchedAt = [searchSongAutocomplete.searchedAt timeIntervalSinceNow] * -1.0;
        
        if (searchedAt < BLYSearchSongAutocompleteResultsStoreAutocompleteResultsCacheTime) {
            
            BLYSearchSongAutocompleteResults *results = [[BLYSearchSongAutocompleteResults alloc] init];
            NSOrderedSet *searchResults = searchSongAutocomplete.results;
            
            for (BLYSearchSongAutocompleteResult *searchResult in searchResults) {
                [results addResult:searchResult];
            }
            
            return block(results, nil);
        }
        
        [self deleteSearchSongAutocomplete:searchSongAutocomplete];
    }
    
    // Prepare a request URL, including the argument from the controller
    NSURL *url = [BLYSearchSongAutocompleteResultsStore URLForServiceToFetchForCountry:country
                                                                             withQuery:query];
    
    // Set up the connection as normal
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    __block BOOL expired = NO;
    
    // Set user agent to avoid null return
    [req setValue:@"Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; Trident/6.0)"
forHTTPHeaderField:@"User-Agent"];
    
    BLYHTTPConnection *connection = [[BLYHTTPConnection alloc] initWithRequest:req];
    __weak BLYSearchSongAutocompleteResultsStore *weakSelf = self;
    
    [connection setCompletionBlock:^(NSData *obj, NSError *err){
        if (expired) {
            return;
        }
        
        expired = true;
        
        BLYSearchSongAutocompleteResults *results = [[BLYSearchSongAutocompleteResults alloc] init];
        
        if (!err) {
            NSArray *returnedResults = [NSJSONSerialization JSONObjectWithData:obj options:0 error:nil][1];
            
            BLYSearchSongAutocomplete *searchSongAutocomplete = [weakSelf insertSearchSongAutocompleteWithSearch:query];
            
            for (NSArray *returnedResult in returnedResults) {
                BLYSearchSongAutocompleteResult *result = [weakSelf insertSearchSongAutocompleteResultWithContent:returnedResult[0]
                                                                                                  forAutocomplete:searchSongAutocomplete];
                
                [results addResult:result];
            }
            
            [[BLYStore sharedStore] saveChanges];
        }
        
        block(results, err);
    }];
    
    [connection start];
    
    [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:NO block:^(NSTimer * _Nonnull timer) {
        if (expired) {
            return;
        }
        
        expired = true;
        
        BLYSearchSongAutocompleteResults *results = [[BLYSearchSongAutocompleteResults alloc] init];
        
        block(results, [[BLYStore sharedStore] timeoutError]);
    }];
}

@end
