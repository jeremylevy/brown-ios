//
//  BLYCachedAlbum+CoreDataProperties.h
//  Brown
//
//  Created by Jeremy Levy on 22/10/2016.
//  Copyright © 2016 Jeremy Levy. All rights reserved.
//

#import "BLYCachedAlbum+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface BLYCachedAlbum (CoreDataProperties)

+ (NSFetchRequest<BLYCachedAlbum *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSDate *cachedAt;
@property (nullable, nonatomic, retain) BLYAlbum *album;

@end

NS_ASSUME_NONNULL_END
