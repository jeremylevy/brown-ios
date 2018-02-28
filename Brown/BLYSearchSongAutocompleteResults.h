//
//  BLYSearchSongsAutocompleteResults.h
//  Brown
//
//  Created by Jeremy Levy on 21/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BLYSearchSongResultProtocol.h"

@class BLYSearchSongAutocompleteResult;

@interface BLYSearchSongAutocompleteResults : NSObject

- (NSInteger) nbOfResults;
- (id <BLYSearchSongResultProtocol>)resultsAtIndex:(NSUInteger)index;
- (void)addResult:(id <BLYSearchSongResultProtocol>)result;

@end
