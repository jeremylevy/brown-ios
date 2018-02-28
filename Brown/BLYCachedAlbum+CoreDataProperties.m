//
//  BLYCachedAlbum+CoreDataProperties.m
//  Brown
//
//  Created by Jeremy Levy on 22/10/2016.
//  Copyright © 2016 Jeremy Levy. All rights reserved.
//

#import "BLYCachedAlbum+CoreDataProperties.h"

@implementation BLYCachedAlbum (CoreDataProperties)

+ (NSFetchRequest<BLYCachedAlbum *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"BLYCachedAlbum"];
}

@dynamic cachedAt;
@dynamic album;

@end
