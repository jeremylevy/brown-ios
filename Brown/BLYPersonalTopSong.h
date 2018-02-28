//
//  BLYPersonalTopSong.h
//  Brown
//
//  Created by Jeremy Levy on 26/10/2013.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class BLYSong;

@interface BLYPersonalTopSong : NSManagedObject

@property (nonatomic, retain) NSNumber * playCount;
@property (nonatomic, retain) NSDate * time;
@property (nonatomic, retain) NSNumber * score;
@property (nonatomic, retain) BLYSong *song;

@end
