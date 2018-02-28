//
//  BLYCachedSong+CoreDataProperties.h
//  Brown
//
//  Created by Jeremy Levy on 01/11/2016.
//  Copyright © 2016 Jeremy Levy. All rights reserved.
//

#import "BLYCachedSong+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface BLYCachedSong (CoreDataProperties)

+ (NSFetchRequest<BLYCachedSong *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSDate *cachedAt;
@property (nullable, nonatomic, copy) NSDate *playedAt;
@property (nullable, nonatomic, copy) NSNumber *cachedByUser;
@property (nullable, nonatomic, retain) BLYSong *song;
@property (nullable, nonatomic, copy) NSString *videoQuality;

@end

NS_ASSUME_NONNULL_END
