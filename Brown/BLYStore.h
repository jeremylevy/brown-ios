//
//  BLYStore.h
//  Brown
//
//  Created by Jeremy Levy on 28/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

extern NSString * const BLYStoreFirstLoadUserDefaultsKey;
extern int const BLYStoreExpiredRequestErrorCode;

@class NSManagedObject;

@interface BLYStore : NSObject

@property (strong, nonatomic) NSManagedObjectContext *context;
@property (strong, nonatomic) NSManagedObjectModel *model;

+ (BLYStore *)sharedStore;
- (NSString *)archivePath;
- (NSString *)cacheDirectory;
- (NSError *)timeoutError;
- (BOOL)saveChanges;
- (id)uniqueEntityOf:(NSString *)entityName withSid:(id)sid;
- (void)deleteObject:(NSManagedObject *)object;
- (BOOL)fileIsCachedAtPath:(NSString *)path;

@end
