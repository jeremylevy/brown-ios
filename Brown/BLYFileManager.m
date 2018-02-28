//
//  BLYFileManager.m
//  Brown
//
//  Created by Jeremy Levy on 06/01/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import "BLYFileManager.h"

@implementation BLYFileManager

- (BOOL)removeFilesWithExtension:(NSString *)extension
                          atPath:(NSString *)path
                           error:(NSError **)error
{
    NSFileManager *manager = [NSFileManager defaultManager];
    
    // Grab all the files in the path dir
    NSArray *allFiles = [manager contentsOfDirectoryAtPath:path
                                                     error:error];
    
    if (error) {
        return NO;
    }
    
    // Filter the array for only files which end with specified extension
    NSString *predicateAsString = [NSString stringWithFormat:@"self ENDSWITH '.%@'", extension];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateAsString];
    NSArray *files = [allFiles filteredArrayUsingPredicate:predicate];
    
    // Use fast enumeration to iterate the array and delete the files
    for (NSString *file in files)
    {
        [manager removeItemAtPath:[path stringByAppendingPathComponent:file]
                            error:error];
        
        if (error) {
            return NO;
        }
    }
    
    return YES;
}

@end
