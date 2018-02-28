//
//  BLYTrendingSearch+CoreDataProperties.h
//  Brown
//
//  Created by Jeremy Levy on 03/02/2018.
//  Copyright © 2018 Jeremy Levy. All rights reserved.
//
//

#import "BLYTrendingSearch+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface BLYTrendingSearch (CoreDataProperties)

+ (NSFetchRequest<BLYTrendingSearch *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *search;
@property (nullable, nonatomic, copy) NSNumber *rank;

@end

NS_ASSUME_NONNULL_END
