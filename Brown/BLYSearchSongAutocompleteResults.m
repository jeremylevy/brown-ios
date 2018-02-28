//
//  BLYSearchSongsAutocompleteResults.m
//  Brown
//
//  Created by Jeremy Levy on 21/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import "BLYSearchSongAutocompleteResults.h"

@interface BLYSearchSongAutocompleteResults ()

@property (strong, nonatomic) NSMutableArray *results;

@end

@implementation BLYSearchSongAutocompleteResults

- (id)init
{
    self = [super init];
    
    if (self) {
        _results = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (NSInteger)nbOfResults
{
    return [self.results count];
}

- (id <BLYSearchSongResultProtocol>)resultsAtIndex:(NSUInteger)index
{
    return [self.results objectAtIndex:index];
}

- (void)addResult:(id <BLYSearchSongResultProtocol>)result
{
    [self.results addObject:result];
}

@end
