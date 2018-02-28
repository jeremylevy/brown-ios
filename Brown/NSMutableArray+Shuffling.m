//
//  NSMutableArray+Shuffling.m
//  Brown
//
//  Created by Jeremy Levy on 06/10/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import "NSMutableArray+Shuffling.h"

@implementation NSMutableArray (Shuffling)

- (void)bly_shuffle
{
    NSUInteger count = [self count];
    
    for (NSUInteger i = 0; i < count; ++i) {
        // Select a random element between i and end of array to swap with.
        NSInteger nElements = count - i;
        NSInteger n = (arc4random() % nElements) + i;
        
        [self exchangeObjectAtIndex:i withObjectAtIndex:n];
    }
}

@end
