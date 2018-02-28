//
//  BLYExternalTopSongCountry.h
//  Brown
//
//  Created by Jeremy Levy on 28/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface BLYExternalTopSongCountry : NSManagedObject

@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSDate * updatedAt;
@property (nonatomic, retain) NSSet *songs;
@end

@interface BLYExternalTopSongCountry (CoreDataGeneratedAccessors)

- (void)addSongsObject:(NSManagedObject *)value;
- (void)removeSongsObject:(NSManagedObject *)value;
- (void)addSongs:(NSSet *)values;
- (void)removeSongs:(NSSet *)values;

@end
