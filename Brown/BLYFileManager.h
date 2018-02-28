//
//  BLYFileManager.h
//  Brown
//
//  Created by Jeremy Levy on 06/01/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BLYFileManager : NSObject

- (BOOL)removeFilesWithExtension:(NSString *)extension
                          atPath:(NSString *)path
                           error:(NSError **)error;

@end
