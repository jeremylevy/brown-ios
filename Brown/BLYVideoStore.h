//
//  BLYVideoStore.h
//  Brown
//
//  Created by Jeremy Levy on 22/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BLYSong;
@class BLYVideo;
@class BLYVideoURL;
@class BLYHTTPConnection;
@class BLYVideoComment;
@class BLYPlaylist;

extern NSString * const BLYVideoStoreServiceURLPattern;
extern NSString * const BLYVideoStoreYoutubeApiKey;

extern NSString * const BLYVideoStoreServiceToGetPlayerConfigPattern;
extern NSString * const BLYVideoStoreServiceToGetVideoURLPattern;

extern NSString * const BLYVideoStoreVideoURLTypesWasLoadedUserDefaultsKey;
extern NSString * const BLYVideoStoreDidUpdateSongsDurationNotification;

typedef enum {
    BLYVideoStoreFetchVideoRequestTimeoutBackground = 4,
    BLYVideoStoreFetchVideoRequestTimeoutActive = 4
} BLYVideoStoreFetchVideoRequestTimeout;

@interface BLYVideoStore : NSObject

+ (BLYVideoStore *)sharedStore;

+ (NSURL *)URLForServiceToFetchForQuery:(NSString *)query duration:(NSNumber *)duration andSongTitleMatchAlbumTitle:(BOOL)songTitleIsSame andCountry:(NSString *)country limit:(int)limit;

+ (NSURL *)URLForServiceToLookupVideosWithIDs:(NSArray *)videoIDs withParts:(NSString *)parts;

+ (NSURL *)URLForServiceToFetchPlayerConfigForVideoID:(NSString *)videoID;

+ (NSURL *)URLForServiceToFetchVideoURLForPlayerConfig:(NSString *)playerConfig;

+ (int)durationFromISO8601Time:(NSString*)duration;

- (void)fetchVideoIDForSong:(BLYSong *)song
                 andCountry:(NSString *)country
               inBackground:(BOOL)inBackground
             withCompletion:(void (^)(NSMutableArray *videos, NSError *err))block;

- (void)fetchVideoURLForVideoOfSong:(BLYSong *)song
                       inBackground:(BOOL)inBackground
                     withCompletion:(void (^)(NSURL *videoURL, NSError *err))block;

- (BLYVideoURL *)urlForVideo:(BLYVideo *)video
                     withQuality:(NSString *)wantedQuality
                        andBound:(NSString *)bound;

- (BLYVideoURL *)bestURLForCurrentNetworkAndVideo:(BLYVideo *)video;
- (BLYVideoURL *)bestURLForCacheAndVideo:(BLYVideo *)video;

- (void)setVideos:(NSOrderedSet *)videos
          forSong:(BLYSong *)song;

- (void)setPath:(NSString *)path
       forVideo:(BLYVideo *)video;

- (void)removeVideosForSong:(BLYSong *)song;
- (void)deleteVideoFileForVideo:(BLYVideo *)video;

- (void)setIsVevo:(BOOL)isVevo
         forVideo:(BLYVideo *)video;

- (NSArray *)supportedItags;

- (BLYVideoStoreFetchVideoRequestTimeout)fetchVideoRequestTimeout;

- (void)fetchCommentsForVideo:(BLYVideo *)video
               withCompletion:(void (^)(NSArray *, NSError *))completion;

- (void)updateIsDisplayedFlag:(BOOL)flag
                   forComment:(BLYVideoComment *)comment;

- (NSArray *)fetchUndisplayedCommentsForVideo:(BLYVideo *)video;

- (void)cleanVideoComments;

- (BLYHTTPConnection *)fetchVideosForQuery:(NSString *)query
                                 orChannel:(NSString *)channel
                                andCountry:(NSString *)country
                            withCompletion:(void (^)(NSMutableDictionary *results, NSError *err))block
                       andCompletionForImg:(void (^)(BOOL hasDownloaded, BLYSong *song))imgBlock;

- (BLYHTTPConnection *)fetchRelatedVideosForVideo:(BLYVideo *)video
                                           ofSong:(BLYSong *)song
                                       andCountry:(NSString *)country
                                   withCompletion:(void (^)(BLYPlaylist *, NSError *))block
                              andCompletionForImg:(void (^)(BOOL hasDownloaded, BLYSong *song))imgBlock;

- (void)lookupVideosWithIDs:(NSArray *)videos
                 forCountry:(NSString *)country
             withCompletion:(void (^)(BLYPlaylist *, NSError *))block
        andCompletionForImg:(void (^)(BOOL hasDownloaded, BLYSong *song))imgBlock;

- (void)removeOrphanedVideoSongs;

- (void)removeOrphanedVideos;

- (void)removeRelatedSongsOfSong:(BLYSong *)song;

- (NSInteger)uniqueAlbumIDForVideo;

@end
