//
//  BLYPlayedSong.h
//  Brown
//
//  Created by Jeremy Levy on 01/10/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class BLYSong;

@interface BLYPlayedSong : NSManagedObject

@property (nonatomic, retain) NSDate * playedAt;
@property (nonatomic, retain) BLYSong *song;

@end
