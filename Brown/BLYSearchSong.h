//
//  BLYSearchSong.h
//  Brown
//
//  Created by Jeremy Levy on 05/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class BLYAlbum, BLYArtist, BLYSong;

@interface BLYSearchSong : NSManagedObject

@property (nonatomic, retain) NSNumber * hidden;
@property (nonatomic, retain) NSString * search;
@property (nonatomic, retain) NSDate * searchedAt;
@property (nonatomic, retain) NSString * type;
@property (nonatomic, retain) NSNumber * lastSelectedSegment;
@property (nonatomic, retain) NSNumber * lastSelectedAlbum;
@property (nonatomic, retain) NSOrderedSet *albums;
@property (nonatomic, retain) BLYArtist *artist;
@property (nonatomic, retain) NSOrderedSet *songs;
@property (nonatomic, retain) NSOrderedSet *videos;
@end

@interface BLYSearchSong (CoreDataGeneratedAccessors)

- (void)insertObject:(BLYAlbum *)value inAlbumsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromAlbumsAtIndex:(NSUInteger)idx;
- (void)insertAlbums:(NSArray *)value atIndexes:(NSIndexSet *)indexes;
- (void)removeAlbumsAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInAlbumsAtIndex:(NSUInteger)idx withObject:(BLYAlbum *)value;
- (void)replaceAlbumsAtIndexes:(NSIndexSet *)indexes withAlbums:(NSArray *)values;
- (void)addAlbumsObject:(BLYAlbum *)value;
- (void)removeAlbumsObject:(BLYAlbum *)value;
- (void)addAlbums:(NSOrderedSet *)values;
- (void)removeAlbums:(NSOrderedSet *)values;
- (void)insertObject:(BLYSong *)value inSongsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromSongsAtIndex:(NSUInteger)idx;
- (void)insertSongs:(NSArray *)value atIndexes:(NSIndexSet *)indexes;
- (void)removeSongsAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInSongsAtIndex:(NSUInteger)idx withObject:(BLYSong *)value;
- (void)replaceSongsAtIndexes:(NSIndexSet *)indexes withSongs:(NSArray *)values;
- (void)addSongsObject:(BLYSong *)value;
- (void)removeSongsObject:(BLYSong *)value;
- (void)addSongs:(NSOrderedSet *)values;
- (void)removeSongs:(NSOrderedSet *)values;
- (void)insertObject:(BLYSong *)value inVideosAtIndex:(NSUInteger)idx;
- (void)removeObjectFromVideosAtIndex:(NSUInteger)idx;
- (void)insertVideos:(NSArray *)value atIndexes:(NSIndexSet *)indexes;
- (void)removeVideosAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInVideosAtIndex:(NSUInteger)idx withObject:(BLYSong *)value;
- (void)replaceVideosAtIndexes:(NSIndexSet *)indexes withVideos:(NSArray *)values;
- (void)addVideosObject:(BLYSong *)value;
- (void)removeVideosObject:(BLYSong *)value;
- (void)addVideos:(NSOrderedSet *)values;
- (void)removeVideos:(NSOrderedSet *)values;
@end
