//
//  BLYExternalTopSong.h
//  Brown
//
//  Created by Jeremy Levy on 29/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class BLYExternalTopSongCountry, BLYSong;

@interface BLYExternalTopSong : NSManagedObject

@property (nonatomic, retain) NSNumber * rank;
@property (nonatomic, retain) BLYExternalTopSongCountry *country;
@property (nonatomic, retain) BLYSong *song;

@end
