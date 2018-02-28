//
//  NSString+Size.m
//  Brown
//
//  Created by Jeremy Levy on 01/12/2013.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import "NSString+Sizing.h"

@implementation NSString (Sizing)

- (CGSize)bly_sizeForStringWithAttributes:(NSDictionary *)attributes
{
    NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:self
                                                                     attributes:attributes];
    
    return attrString.size;
}

- (CGFloat)bly_widthForStringWithAttributes:(NSDictionary *)attributes
{
    CGSize size = [self bly_sizeForStringWithAttributes:attributes];
    
    return size.width;
}

- (CGFloat)bly_heightForStringWithAttributes:(NSDictionary *)attributes
{
    CGSize size = [self bly_sizeForStringWithAttributes:attributes];
    
    return size.height;
}

- (NSRange)bly_fullRange
{
    return NSMakeRange(0, [self length]);
}

@end
