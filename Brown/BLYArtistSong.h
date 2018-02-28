//
//  BLYArtistSong.h
//  Brown
//
//  Created by Jeremy Levy on 09/11/2013.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class BLYAlbum, BLYArtist, BLYSong;

@interface BLYArtistSong : NSManagedObject

@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSNumber * isRealName;
@property (nonatomic, retain) NSSet *songs;
@property (nonatomic, retain) BLYArtist *ref;
@property (nonatomic, retain) NSSet *albums;
@end

@interface BLYArtistSong (CoreDataGeneratedAccessors)

- (void)addSongsObject:(BLYSong *)value;
- (void)removeSongsObject:(BLYSong *)value;
- (void)addSongs:(NSSet *)values;
- (void)removeSongs:(NSSet *)values;

- (void)addAlbumsObject:(BLYAlbum *)value;
- (void)removeAlbumsObject:(BLYAlbum *)value;
- (void)addAlbums:(NSSet *)values;
- (void)removeAlbums:(NSSet *)values;

@end
