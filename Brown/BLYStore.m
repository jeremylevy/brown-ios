//
//  BLYStore.m
//  Brown
//
//  Created by Jeremy Levy on 28/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "BLYStore.h"
#import "BLYVideoURLType.h"

NSString * const BLYStoreFirstLoadUserDefaultsKey = @"BLYStoreFirstLoadUserDefaultsKey";
int const BLYStoreExpiredRequestErrorCode = 1;

@implementation BLYStore

+ (BLYStore *)sharedStore
{
    static BLYStore *store = nil;
    
    if (!store) {
        store = [[BLYStore alloc] init];
    }
    
    return store;
}

- (id)init
{
    self = [super init];
    
    if (self) {
        _model = [NSManagedObjectModel mergedModelFromBundles:nil];
        
        NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:_model];
        
        NSString *cacheDirectory = [self cacheDirectory];
        
        NSString *path = [self archivePath];
        NSURL *storeURL = [NSURL fileURLWithPath:path];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSError *error = nil;
        
        [defaults setBool:NO forKey:BLYStoreFirstLoadUserDefaultsKey];
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:storeURL.path]) {
            NSBundle *mainBundle = [NSBundle mainBundle];

            NSURL *rawStoreURL = [NSURL fileURLWithPath:[mainBundle pathForResource:@"brown_store"
                                                                             ofType:@"sqlite"]];
            NSURL *shmStoreURL = [NSURL fileURLWithPath:[mainBundle pathForResource:@"brown_store"
                                                                             ofType:@"sqlite-shm"]];
            NSURL *walStoreURL = [NSURL fileURLWithPath:[mainBundle pathForResource:@"brown_store"
                                                                             ofType:@"sqlite-wal"]];

            NSArray *storeFiles = [NSArray arrayWithObjects:rawStoreURL, shmStoreURL,  walStoreURL, nil];
            NSError *err = nil;

            for (NSURL *storeFile in storeFiles) {
                NSString *toURLAsString = [cacheDirectory stringByAppendingString:@"/"];
                
                toURLAsString = [toURLAsString stringByAppendingString:[storeFile.path lastPathComponent]];

                NSURL *toURL = [NSURL fileURLWithPath:toURLAsString];

                if (![[NSFileManager defaultManager] copyItemAtURL:storeFile
                                                             toURL:toURL
                                                             error:&err]) {

                    [NSException raise:@"Error with preloaded data"
                                format:@"Reason: %@", err.localizedDescription];
                }
            }

            [defaults setBool:YES forKey:BLYStoreFirstLoadUserDefaultsKey];
        }
        
        NSNumber *yesAsNSNumber = [NSNumber numberWithBool:YES];
        NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                                 yesAsNSNumber, NSMigratePersistentStoresAutomaticallyOption,
                                 [yesAsNSNumber copy], NSInferMappingModelAutomaticallyOption, nil];
        
        if (![psc addPersistentStoreWithType:NSSQLiteStoreType
                               configuration:nil
                                         URL:storeURL
                                     options:options
                                       error:&error]) {
            
            [NSException raise:@"Open failed"
                        format:@"Reason: %@", error.localizedDescription];
        }
        
        _context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        
        _context.persistentStoreCoordinator = psc;
        _context.undoManager = nil;
    }
    
    return self;
}

- (NSString *)cacheDirectory
{
    NSArray *cacheDirectories = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDirectory = [cacheDirectories objectAtIndex:0];
    
    return cacheDirectory;
}

- (NSString *)archivePath
{
    NSString *cacheDirectory = [self cacheDirectory];
    
    return [cacheDirectory stringByAppendingPathComponent:@"brown_store.sqlite"];
}

- (BOOL)saveChanges
{
    NSError *err = nil;
    BOOL successful = [self.context save:&err];
    
    if (!successful) {
        NSLog(@"Error saving: %@", err.localizedDescription);
    }
    
    return successful;
}

- (id)uniqueEntityOf:(NSString *)entityName withSid:(id)sid
{
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:entityName
                                              inManagedObjectContext:self.context];
    NSPredicate *predicate = nil;
    
    if ([sid isKindOfClass:[NSNumber class]]) {
        predicate = [NSPredicate predicateWithFormat:@"sid = %d", [sid intValue]];
    } else if ([sid isKindOfClass:[NSString class]]) {
        predicate = [NSPredicate predicateWithFormat:@"sid = %@", sid];
    } else {
        [NSException raise:@"BLYStore::uniqueEntityOf:withSid: error"
                    format:@"Reason: sid must be NSString* or NSNumber*"];
    }
    
    NSError *err = nil;
    
    request.entity = entity;
    request.predicate = predicate;
    
    NSArray *results = [self.context executeFetchRequest:request error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", err.localizedDescription];
    }
    
    return [results count] > 0 ? [results objectAtIndex:0] : nil;
}

- (NSError *)timeoutError
{
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
    
    [userInfo setValue:@"La requête a expiré."
                forKey:NSLocalizedDescriptionKey];
    
    NSError *err = [NSError errorWithDomain:@"com.brown.blystore"
                                       code:BLYStoreExpiredRequestErrorCode
                                   userInfo:userInfo];
    
    return err;
}

- (void)deleteObject:(NSManagedObject *)object
{
    if (!object) {
        return;
    }
    
    [self.context deleteObject:object];
}

- (BOOL)fileIsCachedAtPath:(NSString *)path
{
    NSString *cacheDirectory = [self cacheDirectory];
    
    path = [cacheDirectory stringByAppendingPathComponent:path];
    
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

@end
