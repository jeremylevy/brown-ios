//
//  BLYSearchSongAutocomplete.h
//  Brown
//
//  Created by Jeremy Levy on 27/11/2013.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class BLYSearchSongAutocompleteResult;

@interface BLYSearchSongAutocomplete : NSManagedObject

@property (nonatomic, retain) NSString * search;
@property (nonatomic, retain) NSDate * searchedAt;
@property (nonatomic, retain) NSOrderedSet *results;
@end

@interface BLYSearchSongAutocomplete (CoreDataGeneratedAccessors)

- (void)insertObject:(BLYSearchSongAutocompleteResult *)value inResultsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromResultsAtIndex:(NSUInteger)idx;
- (void)insertResults:(NSArray *)value atIndexes:(NSIndexSet *)indexes;
- (void)removeResultsAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInResultsAtIndex:(NSUInteger)idx withObject:(BLYSearchSongAutocompleteResult *)value;
- (void)replaceResultsAtIndexes:(NSIndexSet *)indexes withResults:(NSArray *)values;
- (void)addResultsObject:(BLYSearchSongAutocompleteResult *)value;
- (void)removeResultsObject:(BLYSearchSongAutocompleteResult *)value;
- (void)addResults:(NSOrderedSet *)values;
- (void)removeResults:(NSOrderedSet *)values;
@end
