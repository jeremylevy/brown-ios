//
//  BLYAlbum.h
//  Brown
//
//  Created by Jeremy Levy on 28/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class BLYAlbumThumbnail, BLYArtistSong, BLYPlayedAlbum, BLYCachedAlbum, BLYSearchSong, BLYSong;

@interface BLYAlbum : NSManagedObject

@property (nonatomic, retain) NSString * country;
@property (nonatomic, retain) NSNumber * isASingle;
@property (nonatomic, retain) NSNumber * isFullyLoaded;
@property (nonatomic, retain) NSNumber * isCached;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSDate * playedAt;
@property (nonatomic, retain) NSDate * cachedAt;
@property (nonatomic, retain) NSDate * releaseDate;
@property (nonatomic, retain) NSNumber * sid;
@property (nonatomic, retain) BLYArtistSong *artist;
@property (nonatomic, retain) NSSet *thumbnails;
@property (nonatomic, retain) NSSet *searches;
@property (nonatomic, retain) NSSet *songs;
@property (nonatomic, retain) BLYPlayedAlbum *playedAlbum;
@property (nonatomic, retain) BLYCachedAlbum *cachedAlbum;
@end

@interface BLYAlbum (CoreDataGeneratedAccessors)

- (void)addSearchesObject:(BLYSearchSong *)value;
- (void)removeSearchesObject:(BLYSearchSong *)value;
- (void)addSearches:(NSSet *)values;
- (void)removeSearches:(NSSet *)values;

- (void)addThumbnailsObject:(BLYAlbumThumbnail *)value;
- (void)removeThumbnailsObject:(BLYAlbumThumbnail *)value;
- (void)addThumbnails:(NSSet *)values;
- (void)removeThumbnails:(NSSet *)values;

- (void)addSongsObject:(BLYSong *)value;
- (void)removeSongsObject:(BLYSong *)value;
- (void)addSongs:(NSSet *)values;
- (void)removeSongs:(NSSet *)values;

@end
