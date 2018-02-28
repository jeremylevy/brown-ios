//
//  BLYVideoSong.h
//  Brown
//
//  Created by Jeremy Levy on 07/11/2013.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class BLYSong, BLYVideo;

@interface BLYVideoSong : NSManagedObject

@property (nonatomic, retain) NSNumber * possibleGarbage;
@property (nonatomic, retain) BLYSong *song;
@property (nonatomic, retain) BLYVideo *video;

@end
