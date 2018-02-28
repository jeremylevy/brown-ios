//
//  BLYSearchSongResult.h
//  Brown
//
//  Created by Jeremy Levy on 28/11/2013.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BLYSearchSongResultProtocol.h"

@interface BLYSearchSongResult : NSObject <BLYSearchSongResultProtocol>

@property (strong, nonatomic) NSString *content;

@end
