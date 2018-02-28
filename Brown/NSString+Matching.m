//
//  NSString+Matching.m
//  Brown
//
//  Created by Jeremy Levy on 02/12/2013.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import "NSString+Matching.h"
#import "NSString+Sizing.h"

@implementation NSString (Matching)

- (BOOL)bly_match:(NSString *)pattern
{
    NSRegularExpression *reg = [[NSRegularExpression alloc] initWithPattern:pattern
                                                                    options:NSRegularExpressionCaseInsensitive
                                                                      error:nil];
    
    return [reg numberOfMatchesInString:self
                                options:0
                                  range:[self bly_fullRange]] > 0;
}

@end
