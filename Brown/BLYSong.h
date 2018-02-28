//
//  BLYSong.h
//  Brown
//
//  Created by Jeremy Levy on 31/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class BLYAlbum, BLYArtistSong, BLYExternalTopSong, BLYPersonalTopSong, BLYPlayedPlaylistSong, BLYPlayedSong, BLYCachedSong, BLYSearchSong, BLYSong, BLYVideo, BLYVideoSong;

@interface BLYSong : NSManagedObject

@property (nonatomic, retain) NSNumber * duration;
@property (nonatomic, retain) NSNumber * isVideo;
@property (nonatomic, retain) NSNumber * lastPlayPlayedPercent;
@property (nonatomic, retain) NSNumber * loadedByUser;
@property (nonatomic, retain) NSNumber * rankInAlbum;
@property (nonatomic, retain) NSString * sid;
@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSNumber * videosReordered;
@property (nonatomic, retain) BLYAlbum *album;
@property (nonatomic, retain) BLYArtistSong *artist;
@property (nonatomic, retain) NSSet *externalTopSongs;
@property (nonatomic, retain) BLYPersonalTopSong *personalTopSong;
@property (nonatomic, retain) BLYPlayedPlaylistSong *playedPlaylistSong;
@property (nonatomic, retain) BLYPlayedSong *playedSong;
@property (nonatomic, retain) BLYCachedSong *cachedSong;
@property (nonatomic, retain) NSOrderedSet *relatedSongs;
@property (nonatomic, retain) NSSet *relatedToSongs;
@property (nonatomic, retain) NSSet *searches;
@property (nonatomic, retain) NSSet *searchesVideos;
@property (nonatomic, retain) BLYVideo *videoRepresentation;
@property (nonatomic, retain) NSOrderedSet *videos;
@end

@interface BLYSong (CoreDataGeneratedAccessors)

- (void)addExternalTopSongsObject:(BLYExternalTopSong *)value;
- (void)removeExternalTopSongsObject:(BLYExternalTopSong *)value;
- (void)addExternalTopSongs:(NSSet *)values;
- (void)removeExternalTopSongs:(NSSet *)values;

- (void)insertObject:(BLYSong *)value inRelatedSongsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromRelatedSongsAtIndex:(NSUInteger)idx;
- (void)insertRelatedSongs:(NSArray *)value atIndexes:(NSIndexSet *)indexes;
- (void)removeRelatedSongsAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInRelatedSongsAtIndex:(NSUInteger)idx withObject:(BLYSong *)value;
- (void)replaceRelatedSongsAtIndexes:(NSIndexSet *)indexes withRelatedSongs:(NSArray *)values;
- (void)addRelatedSongsObject:(BLYSong *)value;
- (void)removeRelatedSongsObject:(BLYSong *)value;
- (void)addRelatedSongs:(NSOrderedSet *)values;
- (void)removeRelatedSongs:(NSOrderedSet *)values;
- (void)addRelatedToSongsObject:(BLYSong *)value;
- (void)removeRelatedToSongsObject:(BLYSong *)value;
- (void)addRelatedToSongs:(NSSet *)values;
- (void)removeRelatedToSongs:(NSSet *)values;

- (void)addSearchesObject:(BLYSearchSong *)value;
- (void)removeSearchesObject:(BLYSearchSong *)value;
- (void)addSearches:(NSSet *)values;
- (void)removeSearches:(NSSet *)values;

- (void)addSearchesVideosObject:(BLYSearchSong *)value;
- (void)removeSearchesVideosObject:(BLYSearchSong *)value;
- (void)addSearchesVideos:(NSSet *)values;
- (void)removeSearchesVideos:(NSSet *)values;

- (void)insertObject:(BLYVideoSong *)value inVideosAtIndex:(NSUInteger)idx;
- (void)removeObjectFromVideosAtIndex:(NSUInteger)idx;
- (void)insertVideos:(NSArray *)value atIndexes:(NSIndexSet *)indexes;
- (void)removeVideosAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInVideosAtIndex:(NSUInteger)idx withObject:(BLYVideoSong *)value;
- (void)replaceVideosAtIndexes:(NSIndexSet *)indexes withVideos:(NSArray *)values;
- (void)addVideosObject:(BLYVideoSong *)value;
- (void)removeVideosObject:(BLYVideoSong *)value;
- (void)addVideos:(NSOrderedSet *)values;
- (void)removeVideos:(NSOrderedSet *)values;
@end
