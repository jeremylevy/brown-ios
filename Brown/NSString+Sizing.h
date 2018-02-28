//
//  NSString+Sizing.h
//  Brown
//
//  Created by Jeremy Levy on 01/12/2013.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Sizing)

- (CGFloat)bly_heightForStringWithAttributes:(NSDictionary *)attributes;
- (CGFloat)bly_widthForStringWithAttributes:(NSDictionary *)attributes;
- (NSRange)bly_fullRange;

@end
