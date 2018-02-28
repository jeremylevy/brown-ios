//
//  BLYTrendingSearch+CoreDataProperties.m
//  Brown
//
//  Created by Jeremy Levy on 03/02/2018.
//  Copyright © 2018 Jeremy Levy. All rights reserved.
//
//

#import "BLYTrendingSearch+CoreDataProperties.h"

@implementation BLYTrendingSearch (CoreDataProperties)

+ (NSFetchRequest<BLYTrendingSearch *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"BLYTrendingSearch"];
}

@dynamic search;
@dynamic rank;

@end
