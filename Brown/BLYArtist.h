//
//  BLYArtist.h
//  Brown
//
//  Created by Jeremy Levy on 04/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class BLYArtistSong, BLYSearchSong;

@interface BLYArtist : NSManagedObject

@property (nonatomic, retain) NSString * country;
@property (nonatomic, retain) NSString * sid;
@property (nonatomic, retain) NSNumber * isYoutubeChannel;
@property (nonatomic, retain) NSSet *artistSongs;
@property (nonatomic, retain) BLYSearchSong *search;
@end

@interface BLYArtist (CoreDataGeneratedAccessors)

- (void)addArtistSongsObject:(BLYArtistSong *)value;
- (void)removeArtistSongsObject:(BLYArtistSong *)value;
- (void)addArtistSongs:(NSSet *)values;
- (void)removeArtistSongs:(NSSet *)values;

@end
