//
//  BLYYoutubeUser.h
//  Brown
//
//  Created by Jeremy Levy on 07/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface BLYYoutubeUser : NSManagedObject

@property (nonatomic, retain) NSString * sid;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSSet *videoComments;
@end

@interface BLYYoutubeUser (CoreDataGeneratedAccessors)

- (void)addVideoCommentsObject:(NSManagedObject *)value;
- (void)removeVideoCommentsObject:(NSManagedObject *)value;
- (void)addVideoComments:(NSSet *)values;
- (void)removeVideoComments:(NSSet *)values;

@end
