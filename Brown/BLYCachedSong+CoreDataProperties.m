//
//  BLYCachedSong+CoreDataProperties.m
//  Brown
//
//  Created by Jeremy Levy on 01/11/2016.
//  Copyright © 2016 Jeremy Levy. All rights reserved.
//

#import "BLYCachedSong+CoreDataProperties.h"

@implementation BLYCachedSong (CoreDataProperties)

+ (NSFetchRequest<BLYCachedSong *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"BLYCachedSong"];
}

@dynamic cachedAt;
@dynamic playedAt;
@dynamic cachedByUser;
@dynamic song;
@dynamic videoQuality;

@end
