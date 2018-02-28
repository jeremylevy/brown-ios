//
//  NSString+Escaping.h
//  Brown
//
//  Created by Jeremy Levy on 14/10/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Escaping)

- (NSString *)bly_stringByAddingPercentEscapesForQuery;
- (NSString *)bly_stringByRemovingPercentEscapes;
- (NSString *)bly_stringByRemovingAccents;
- (NSString *)bly_stringByReplacingMultipleConsecutiveSpacesToOne;
- (NSString *)bly_artistNameByRemovingRightPartOfComposedArtist;
- (NSString *)bly_stringByRemovingParenthesisAndBrackets;
- (NSString *)bly_stringByRemovingParenthesisAndBracketsContent;
- (NSString *)bly_stringByRemovingSpaces;
- (NSString *)bly_stringByRemovingNonAlphanumericCharacters;
- (NSString *)bly_stringByReplacingPattern:(NSString *)pattern
                                withString:(NSString *)replace;

@end
