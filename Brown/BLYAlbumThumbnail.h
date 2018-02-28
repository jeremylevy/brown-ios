//
//  BLYAlbumThumbnail.h
//  Brown
//
//  Created by Jeremy Levy on 01/06/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class BLYAlbum;

@interface BLYAlbumThumbnail : NSManagedObject

@property (nonatomic, retain) NSData * data;
@property (nonatomic, retain) NSString * size;
@property (nonatomic, retain) NSString * url;
@property (nonatomic, retain) BLYAlbum *album;

@end
