//
//  BLYPlayedAlbum.h
//  Brown
//
//  Created by Jeremy Levy on 28/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class BLYAlbum;

@interface BLYPlayedAlbum : NSManagedObject

@property (nonatomic, retain) NSDate * playedAt;
@property (nonatomic, retain) BLYAlbum *album;

@end
