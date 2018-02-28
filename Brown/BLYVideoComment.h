//
//  BLYVideoComment.h
//  Brown
//
//  Created by Jeremy Levy on 08/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class BLYVideo, BLYYoutubeUser;

@interface BLYVideoComment : NSManagedObject

@property (nonatomic, retain) NSDate * publishedAt;
@property (nonatomic, retain) NSString * content;
@property (nonatomic, retain) NSString * sid;
@property (nonatomic, retain) NSNumber * isDisplayed;
@property (nonatomic, retain) BLYYoutubeUser *author;
@property (nonatomic, retain) BLYVideo *video;

@end
