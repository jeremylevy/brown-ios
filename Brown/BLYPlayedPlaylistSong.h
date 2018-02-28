//
//  BLYPlayedPlaylistSong.h
//  Brown
//
//  Created by Jeremy Levy on 28/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class BLYSong;

@interface BLYPlayedPlaylistSong : NSManagedObject

@property (nonatomic, retain) NSNumber * rank;
@property (nonatomic, retain) NSNumber * isCurrent;
@property (nonatomic, retain) NSNumber * isLoadedFromAlbum;
@property (nonatomic, retain) BLYSong *song;

@end
