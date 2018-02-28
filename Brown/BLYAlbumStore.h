//
//  BLYAlbumStore.h
//  Brown
//
//  Created by Jeremy Levy on 28/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BLYSongStore.h"

@class BLYAlbum, BLYHTTPConnection;

extern NSString * const BLYAlbumStoreServiceURLPattern;

@interface BLYAlbumStore : BLYSongStore

+ (BLYAlbumStore *)sharedStore;

+ (NSURL *)URLForServiceToFetchAlbum:(int)albumSid
                          forCountry:(NSString *)country;

- (BLYHTTPConnection *)fetchAlbum:(int)albumSid
                       forCountry:(NSString *)country
                   withCompletion:(void (^)(BLYAlbum *album, NSError *err))completionBlock
              andCompletionForImg:(void (^)(BOOL hasDownloaded, BLYAlbum *album))imgBlock;

- (void)updatePlayedAtForAlbum:(BLYAlbum *)album;

@end
