//
//  BLYTimeManager.m
//  Brown
//
//  Created by Jeremy Levy on 23/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import "BLYTimeManager.h"

@interface BLYTimeManager ()

@property (strong, nonatomic) NSDateComponents *dc;
@property (strong, nonatomic) NSCalendar *cal;

@end

@implementation BLYTimeManager

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        _dc = [[NSDateComponents alloc] init];
        _cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    }
    
    return self;
}

- (NSDateComponents *)dateComponentsFromSecond:(float)second
{
    NSDateComponents *c = self.dc;
    NSCalendar *calendar = self.cal;
    
    [c setSecond:second];
    
    NSDate *date = [calendar dateFromComponents:c];
    
    NSDateComponents *result = [calendar components:NSCalendarUnitHour |
                                NSCalendarUnitMinute |
                                NSCalendarUnitSecond
                                      fromDate:date];
    
    return result;
}

- (NSString *)durationAsString:(float)duration
{
    NSDateComponents *durationDateComponents = [self dateComponentsFromSecond:duration];
    NSString *stringWithFormatForDuration = nil;
    
    if ([durationDateComponents hour] == 0) {
        stringWithFormatForDuration = [NSString stringWithFormat:@"%02d:%02d",
                                       (int)[durationDateComponents minute],
                                       (int)[durationDateComponents second]];
    } else {
        stringWithFormatForDuration = [NSString stringWithFormat:@"%02d:%02d:%02d",
                                       (int)[durationDateComponents hour],
                                       (int)[durationDateComponents minute],
                                       (int)[durationDateComponents second]];
    }
    
    return stringWithFormatForDuration;
}

- (int)ISO8601TimeToSeconds:(NSString*)duration
{
    int hours = 0;
    int minutes = 0;
    int seconds = 0;
    
    //Get Time part from ISO 8601 formatted duration http://en.wikipedia.org/wiki/ISO_8601#Durations
    duration = [duration substringFromIndex:[duration rangeOfString:@"T"].location];
    
    while ([duration length] > 1) { //only one letter remains after parsing
        duration = [duration substringFromIndex:1];
        
        NSScanner *scanner = [[NSScanner alloc] initWithString:duration];
        
        NSString *durationPart = [[NSString alloc] init];
        [scanner scanCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789"]
                            intoString:&durationPart];
        
        NSRange rangeOfDurationPart = [duration rangeOfString:durationPart];
        
        duration = [duration substringFromIndex:rangeOfDurationPart.location + rangeOfDurationPart.length];
        
        if ([[duration substringToIndex:1] isEqualToString:@"H"]) {
            hours = [durationPart intValue];
        }
        if ([[duration substringToIndex:1] isEqualToString:@"M"]) {
            minutes = [durationPart intValue];
        }
        if ([[duration substringToIndex:1] isEqualToString:@"S"]) {
            seconds = [durationPart intValue];
        }
    }
    
    seconds += hours * 3600;
    seconds += minutes * 60;
    
    return seconds;
}

@end
