//
//  BLYVideo.h
//  Brown
//
//  Created by Jeremy Levy on 27/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class BLYSong, BLYVideoComment, BLYVideoSong, BLYVideoURL;

@interface BLYVideo : NSManagedObject

@property (nonatomic, retain) NSNumber * duration;
@property (nonatomic, retain) NSNumber * isVevo;
@property (nonatomic, retain) NSString * path;
@property (nonatomic, retain) NSString * sid;
@property (nonatomic, retain) NSOrderedSet *comments;
@property (nonatomic, retain) NSSet *urls;
@property (nonatomic, retain) NSSet *videoSongs;
@property (nonatomic, retain) BLYSong *songRepresentation;
@end

@interface BLYVideo (CoreDataGeneratedAccessors)

- (void)insertObject:(BLYVideoComment *)value inCommentsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromCommentsAtIndex:(NSUInteger)idx;
- (void)insertComments:(NSArray *)value atIndexes:(NSIndexSet *)indexes;
- (void)removeCommentsAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInCommentsAtIndex:(NSUInteger)idx withObject:(BLYVideoComment *)value;
- (void)replaceCommentsAtIndexes:(NSIndexSet *)indexes withComments:(NSArray *)values;
- (void)addCommentsObject:(BLYVideoComment *)value;
- (void)removeCommentsObject:(BLYVideoComment *)value;
- (void)addComments:(NSOrderedSet *)values;
- (void)removeComments:(NSOrderedSet *)values;
- (void)addUrlsObject:(BLYVideoURL *)value;
- (void)removeUrlsObject:(BLYVideoURL *)value;
- (void)addUrls:(NSSet *)values;
- (void)removeUrls:(NSSet *)values;

- (void)addVideoSongsObject:(BLYVideoSong *)value;
- (void)removeVideoSongsObject:(BLYVideoSong *)value;
- (void)addVideoSongs:(NSSet *)values;
- (void)removeVideoSongs:(NSSet *)values;

@end
