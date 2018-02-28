//
//  BLYVideoURLType.h
//  Brown
//
//  Created by Jeremy Levy on 07/11/2013.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class BLYVideoURL;

@interface BLYVideoURLType : NSManagedObject

@property (nonatomic, retain) NSString * defaultContainer;
@property (nonatomic, retain) NSNumber * itag;
@property (nonatomic, retain) NSSet *urls;
@end

@interface BLYVideoURLType (CoreDataGeneratedAccessors)

- (void)addUrlsObject:(BLYVideoURL *)value;
- (void)removeUrlsObject:(BLYVideoURL *)value;
- (void)addUrls:(NSSet *)values;
- (void)removeUrls:(NSSet *)values;

@end
