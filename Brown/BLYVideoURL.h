//
//  BLYVideoURL.h
//  Brown
//
//  Created by Jeremy Levy on 07/11/2013.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class BLYVideo, BLYVideoURLType;

@interface BLYVideoURL : NSManagedObject

@property (nonatomic, retain) NSDate * expiresAt;
@property (nonatomic, retain) NSString * ipAddress;
@property (nonatomic, retain) NSString * value;
@property (nonatomic, retain) BLYVideoURLType *type;
@property (nonatomic, retain) BLYVideo *video;

@end
