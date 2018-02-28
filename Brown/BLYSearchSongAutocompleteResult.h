//
//  BLYSearchSongAutocompleteResult.h
//  Brown
//
//  Created by Jeremy Levy on 27/11/2013.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "BLYSearchSongResultProtocol.h"


@interface BLYSearchSongAutocompleteResult : NSManagedObject <BLYSearchSongResultProtocol>

@property (nonatomic, retain) NSString * content;
@property (nonatomic, retain) NSSet *searches;
@end

@interface BLYSearchSongAutocompleteResult (CoreDataGeneratedAccessors)

- (void)addSearchesObject:(NSManagedObject *)value;
- (void)removeSearchesObject:(NSManagedObject *)value;
- (void)addSearches:(NSSet *)values;
- (void)removeSearches:(NSSet *)values;

@end
