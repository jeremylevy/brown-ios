//
//  BLYTimeManager.h
//  Brown
//
//  Created by Jeremy Levy on 23/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BLYTimeManager : NSObject

- (NSDateComponents *)dateComponentsFromSecond:(float)second;
- (NSString *)durationAsString:(float)duration;
- (int)ISO8601TimeToSeconds:(NSString *)duration;

@end
