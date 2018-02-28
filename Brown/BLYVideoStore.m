//
//  BLYVideoStore.m
//  Brown
//
//  Created by Jeremy Levy on 22/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import "BLYVideoStore.h"
#import "BLYHTTPConnection.h"
#import "BLYVideoSong.h"
#import "BLYVideo.h"
#import "BLYSong.h"
#import "BLYSong+Caching.h"
#import "BLYStore.h"
#import "BLYVideoURL.h"
#import "BLYVideoURLType.h"
#import "BLYNetworkStore.h"
#import "NSString+Escaping.h"
#import "NSString+Sizing.h"
#import "NSString+Matching.h"
#import "BLYArtist.h"
#import "BLYArtistSong.h"
#import "BLYAlbum.h"
#import "BLYPersonalTopSongStore.h"
#import "BLYPersonalTopSong.h"
#import "BLYPlayedSongStore.h"
#import "BLYPlayedSong.h"
#import "NSString+Matching.h"
#import "BLYYoutubeExtractor.h"
#import "BLYYoutubeUser.h"
#import "BLYVideoComment.h"
#import "BLYTimeManager.h"
#import "BLYPlaylist.h"
#import "BLYSongStore.h"
#import "BLYAlbumThumbnail.h"
#import "BLYCachedSongStore.h"

NSString * const BLYVideoStoreYoutubeApiKey = @"AIzaSyAQqDKFR4xUTJTxJF9kImo17tzaaSYXV9A";
int const BLYVideoStoreMaxVideoResultsForQuery = 5;

NSString * const BLYVideoStoreServiceURLPattern = @"https://www.googleapis.com/youtube/v3/search?q=%@&maxResults=%d&part=id,snippet&key=%@&type=video&regionCode=%@";
//NSString * const BLYVideoStoreServiceURLPattern = @"https://app-7d6f71f6-b0cd-47aa-9f16-7de290b81ef0.cleverapps.io/search-video?q=%@&duration=%d&song-title-is-same-than-album=%d&country=%@&limit=%d";
NSString * const BLYVideoStoreServiceToLookupVideo = @"https://www.googleapis.com/youtube/v3/videos?id=%@&part=id,snippet&key=%@";
NSString * const BLYVideoStoreServiceToGetPlayerConfigPattern = @"http://www.youtube.com/watch?v=%@";
NSString * const BLYVideoStoreVideosSearchURLPattern = @"https://www.googleapis.com/youtube/v3/search?part=id%%2Csnippet%@%@&key=%@&maxResults=50&type=video&regionCode=%@";
NSString * const BLYVideoStoreVideosLookupURLPattern = @"https://www.googleapis.com/youtube/v3/videos?id=%@&part=%@&key=%@";
NSString * const BLYVideoStoreServiceToFetchVideoComments = @"https://www.googleapis.com/youtube/v3/commentThreads?key=%@&textFormat=plainText&videoId=%@&order=time&part=snippet";
NSString * const BLYVideoStoreServiceToFetchRelatedVideos = @"https://www.googleapis.com/youtube/v3/search?part=id%%2Csnippet&relatedToVideoId=%@&type=video&key=%@&regionCode=%@&maxResults=14";
NSString * const BLYVideoStoreServiceToGetVideoURLPattern = @"http://176.58.120.95:8080/video-url-for-player-config";
NSString * const BLYVideoStoreVideoURLTypesWasLoadedUserDefaultsKey = @"videoURLTypesLoaded";

NSString * const BLYVideoStoreDidUpdateSongsDurationNotification = @"BLYSearchSongResultsStoreDidUpdateSongsDuration";

@interface BLYVideoStore ()

@property (nonatomic) BLYVideoStoreFetchVideoRequestTimeout fetchVideoRequestTimeout;

@end

@implementation BLYVideoStore

+ (BLYVideoStore *)sharedStore
{
    static BLYVideoStore *videosSongsStore = nil;
    
    if (!videosSongsStore) {
        videosSongsStore = [[BLYVideoStore alloc] init];
    }
    
    return videosSongsStore;
}

- (id)init
{
    self = [super init];
    
    if (self) {
        [self loadVideoURLTypes];
    }
    
    return self;
}

- (void)loadVideoURLTypes
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL loaded = [defaults boolForKey:BLYVideoStoreVideoURLTypesWasLoadedUserDefaultsKey];
    
    if (!loaded) {
        NSArray *itags = @[
           @{@"itag": @13, @"defaultContainer": @"3GP"},
           @{@"itag": @17, @"defaultContainer": @"3GP"},
           @{@"itag": @18, @"defaultContainer": @"MP4"},
           @{@"itag": @22, @"defaultContainer": @"MP4"},
           @{@"itag": @36, @"defaultContainer": @"3GP"},
           @{@"itag": @37, @"defaultContainer": @"MP4"},
           @{@"itag": @38, @"defaultContainer": @"MP4"},
//           @{@"itag": @82, @"defaultContainer": @"MP4"},
//           @{@"itag": @83, @"defaultContainer": @"MP4"},
//           @{@"itag": @84, @"defaultContainer": @"MP4"},
//           @{@"itag": @85, @"defaultContainer": @"MP4"},
//           @{@"itag": @133, @"defaultContainer": @"MP4"},
//           @{@"itag": @134, @"defaultContainer": @"MP4"},
//           @{@"itag": @135, @"defaultContainer": @"MP4"},
//           @{@"itag": @136, @"defaultContainer": @"MP4"},
//           @{@"itag": @137, @"defaultContainer": @"MP4"},
//           @{@"itag": @139, @"defaultContainer": @"MP4"},
//           //@{@"itag": @140, @"defaultContainer": @"MP4"},
//           @{@"itag": @141, @"defaultContainer": @"MP4"},
//           @{@"itag": @160, @"defaultContainer": @"MP4"}
        ];
        
        for (NSDictionary *d in itags) {
            BLYVideoURLType *type = [NSEntityDescription insertNewObjectForEntityForName:@"BLYVideoURLType"
                                                                  inManagedObjectContext:[[BLYStore sharedStore] context]];
            
            type.itag = d[@"itag"];
            type.defaultContainer = [d[@"defaultContainer"] lowercaseString];
        }
        
        [[BLYStore sharedStore] saveChanges];
        
        [defaults setBool:YES
                   forKey:BLYVideoStoreVideoURLTypesWasLoadedUserDefaultsKey];
    }
}

+ (NSURL *)URLForServiceToFetchForQuery:(NSString *)query duration:(NSNumber *)duration andSongTitleMatchAlbumTitle:(BOOL)songTitleIsSame andCountry:(NSString *)country limit:(int)limit
{
    country = [country bly_stringByAddingPercentEscapesForQuery];
    query = [[query bly_stringByAddingPercentEscapesForQuery] bly_stringByRemovingAccents];
    
    NSString *url = [NSString stringWithFormat:BLYVideoStoreServiceURLPattern, query, limit, BLYVideoStoreYoutubeApiKey, country];
    
    //NSString *url = [NSString stringWithFormat:BLYVideoStoreServiceURLPattern, query, [duration integerValue] / 1000, songTitleIsSame, country, limit];
    
    return [NSURL URLWithString:url];
}

+ (NSURL *)URLForServiceToFetchPlayerConfigForVideoID:(NSString *)videoID
{
    videoID = [videoID bly_stringByAddingPercentEscapesForQuery];
    
    NSString *url = [NSString stringWithFormat:BLYVideoStoreServiceToGetPlayerConfigPattern, videoID];
    
    return [NSURL URLWithString:url];
}

+ (NSURL *)URLForServiceToFetchVideoURLForPlayerConfig:(NSString *)playerConfig
{
    NSString *url = BLYVideoStoreServiceToGetVideoURLPattern;
    
    return [NSURL URLWithString:url];
}

+ (NSURL *)URLForServiceToLookupVideo:(NSString *)videoID
{
    videoID = [videoID bly_stringByAddingPercentEscapesForQuery];
    
    NSString *url = [NSString stringWithFormat:BLYVideoStoreServiceToLookupVideo, videoID, BLYVideoStoreYoutubeApiKey];
    
    return [NSURL URLWithString:url];
}

+ (NSURL *)URLForServiceToFetchCommentsForVideo:(NSString *)videoID
{
    videoID = [videoID bly_stringByAddingPercentEscapesForQuery];
    
    NSString *url = [NSString stringWithFormat:BLYVideoStoreServiceToFetchVideoComments, BLYVideoStoreYoutubeApiKey, videoID];
    
    return [NSURL URLWithString:url];
}

+ (NSURL *)URLForServiceToFetchVideosForQuery:(NSString *)query
                                    orChannel:(NSString *)channelID
                                   andCountry:(NSString *)country
{
    if (query) {
        query = [@"&q=" stringByAppendingString:[query bly_stringByAddingPercentEscapesForQuery]];
    } else {
        query = @"";
    }
    
    if (channelID) {
        channelID =[@"&channelId=" stringByAppendingString:[channelID bly_stringByAddingPercentEscapesForQuery]];
    } else {
        channelID = @"";
    }
    
    NSString *url = [NSString stringWithFormat:BLYVideoStoreVideosSearchURLPattern,
                     query,
                     channelID,
                     BLYVideoStoreYoutubeApiKey,
                     country];
    
    return [NSURL URLWithString:url];
}

+ (NSURL *)URLForServiceToLookupVideosWithIDs:(NSArray *)videoIDs withParts:(NSString *)parts
{
    NSString *videoIDsAsString = [videoIDs componentsJoinedByString:@"%2C"];
    NSString *url = [NSString stringWithFormat:BLYVideoStoreVideosLookupURLPattern,
                     videoIDsAsString,
                     [parts bly_stringByAddingPercentEscapesForQuery],
                     BLYVideoStoreYoutubeApiKey];
    
    return [NSURL URLWithString:url];
}

+ (NSURL *)URLForServiceToFetchRelatedVideosForVideo:(NSString *)videoID
                                          andCountry:(NSString *)country
{
    videoID = [videoID bly_stringByAddingPercentEscapesForQuery];
    
    NSString *url = [NSString stringWithFormat:BLYVideoStoreServiceToFetchRelatedVideos,
                     videoID,
                     BLYVideoStoreYoutubeApiKey,
                     country];
    
    return [NSURL URLWithString:url];
}

- (void)setVideos:(NSOrderedSet *)videos forSong:(BLYSong *)song
{
    BLYVideoSong *firstVideo = [videos count] > 0 ? [videos objectAtIndex:0] : nil;
    
    // Make sure `setVideos` was called after because
    // we need cached video to be first video
    if (song.isCached) {
        [[BLYCachedSongStore sharedStore] removeCacheForSong:song];
    }
    
    [song setVideos:videos];
    
    if (firstVideo && firstVideo.video.path) {
        BOOL (^songWasAskedByUser)(BLYSong *s) = ^(BLYSong *s){
            return YES;
        };
        
        [[BLYCachedSongStore sharedStore] cacheSong:song askedByUser:songWasAskedByUser withCompletion:nil];
    }
    
    //[[BLYCachedSongStore sharedStore] updateCachedSongDependingOnReorderedVideos:song];
    
    [[BLYStore sharedStore] saveChanges];
}

- (void)removeVideosForSong:(BLYSong *)song
{
    [self setVideos:[[NSOrderedSet alloc] init] forSong:song];
}

- (void)removeOrphanedVideoSongs
{
    BLYStore *store = [BLYStore sharedStore];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [store.model.entitiesByName objectForKey:@"BLYVideoSong"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"song = nil"];
    NSError *err = nil;
    
    request.entity = entity;
    request.predicate = predicate;
    
    NSArray *results = [store.context executeFetchRequest:request
                                                    error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", err.localizedDescription];
    }
    
    for (BLYVideoSong *videoSong in results) {
        [store deleteObject:videoSong];
    }
    
    [store saveChanges];
}

- (void)removeOrphanedVideos
{
    BLYStore *store = [BLYStore sharedStore];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [store.model.entitiesByName objectForKey:@"BLYVideo"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"videoSongs.@count = 0"];
    NSError *err = nil;
    
    request.entity = entity;
    request.predicate = predicate;
    
    NSArray *results = [store.context executeFetchRequest:request error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", err.localizedDescription];
    }
    
    for (BLYVideo *video in results) {
        [store deleteObject:video];
        
        [self deleteVideoFileForVideo:video];
    }
    
    [store saveChanges];
}

- (BLYVideo *)insertVideoWithID:(NSString *)ID
                       duration:(int)duration
                         isVevo:(BOOL)isVevo
             andPossibleGarbage:(BOOL)possibleGarbage
                        forSong:(BLYSong *)song
{
    BLYStore *store = [BLYStore sharedStore];
    BLYVideo *video = [store uniqueEntityOf:@"BLYVideo"
                                    withSid:ID];
    
    BLYVideoSong *videoSong = [NSEntityDescription insertNewObjectForEntityForName:@"BLYVideoSong"
                                                            inManagedObjectContext:store.context];
    
    if (!video) {
        video = [NSEntityDescription insertNewObjectForEntityForName:@"BLYVideo"
                                              inManagedObjectContext:store.context];
        
        video.sid = ID;
        video.duration = [NSNumber numberWithInt:duration];
        video.isVevo = [NSNumber numberWithBool:isVevo];
        video.videoSongs = [NSSet setWithObject:videoSong];
    } else {
        [video addVideoSongsObject:videoSong];
    }
    
    videoSong.possibleGarbage = [NSNumber numberWithBool:possibleGarbage];
    videoSong.song = song;
    videoSong.video = video;

    // Don't use addVideosObject method here, see: http://stackoverflow.com/questions/7385439/exception-thrown-in-nsorderedset-generated-accessors
    NSMutableOrderedSet *videos = [song.videos mutableCopy];
    
    [videos addObject:videoSong];
    
    [self setVideos:[videos copy]
            forSong:song];
    
    return video;
}

- (void)insertURLs:(NSArray *)urls forVideo:(BLYVideo *)video
{
    BLYStore *store = [BLYStore sharedStore];
    
    [self removeURLsOfVideo:video];
    
    for (NSString *url in urls) {
        BLYVideoURL *videoURL = [NSEntityDescription insertNewObjectForEntityForName:@"BLYVideoURL"
                                                              inManagedObjectContext:store.context];
    
        BLYVideoURLType *videoURLType = [self urlTypeForURL:url];
        
        if (!videoURLType) {
            continue;
        }
        
        int expiresAtAsTimestamp = 0;
        NSRegularExpression *expiresAtReg = [[NSRegularExpression alloc] initWithPattern:@"expire(?:/|=)([0-9]+)"
                                                                                 options:NSRegularExpressionCaseInsensitive
                                                                                   error:nil];
        
        NSArray *matchesExpiresAt = [expiresAtReg matchesInString:url
                                                          options:0
                                                            range:[url bly_fullRange]];
        
        if ([matchesExpiresAt count] > 0) {
            NSTextCheckingResult *resultExpiresAt = [matchesExpiresAt objectAtIndex:0];
            
            if ([resultExpiresAt numberOfRanges] >= 2) {
                NSRange range = [resultExpiresAt rangeAtIndex:1];
                
                expiresAtAsTimestamp = [[url substringWithRange:range] intValue];
            }
        }
        
        NSString *IPAddress = @"";
        NSRegularExpression *IPAddressReg = [[NSRegularExpression alloc] initWithPattern:@"ip(?:/|=)([^%]+)"
                                                                                 options:NSRegularExpressionCaseInsensitive
                                                                                   error:nil];
        
        NSArray *matchesIPAddress = [IPAddressReg matchesInString:url
                                                          options:0
                                                            range:[url bly_fullRange]];
        
        if ([matchesIPAddress count] > 0) {
            NSTextCheckingResult *resultIPAddress = [matchesIPAddress objectAtIndex:0];
            
            if ([resultIPAddress numberOfRanges] >= 2) {
                IPAddress = [url substringWithRange:[resultIPAddress rangeAtIndex:1]];
            }
        }
        
        videoURL.value = url;
        videoURL.expiresAt = [NSDate dateWithTimeIntervalSince1970:expiresAtAsTimestamp];
        videoURL.ipAddress = IPAddress;
        
        videoURL.video = video;
        [video addUrlsObject:videoURL];
        
        videoURL.type = videoURLType;
        [videoURLType addUrlsObject:videoURL];
     }
    
    [store saveChanges];
}

- (NSArray *)supportedItags
{
    BLYStore *store = [BLYStore sharedStore];
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [store.model.entitiesByName objectForKey:@"BLYVideoURLType"];
    NSError *error = nil;
    
    request.entity = entity;
    
    NSArray *results = [store.context executeFetchRequest:request
                                                    error:&error];
    NSMutableArray *itags = [[NSMutableArray alloc] init];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", error.localizedDescription];
    }
    
    for (BLYVideoURLType *URLType in results) {
        [itags addObject:URLType.itag];
    }
    
    return [itags copy];
}

- (BLYVideoURLType *)urlTypeForURL:(NSString *)url
{
    BLYStore *store = [BLYStore sharedStore];
    int itag = [self itagFromURL:url];
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [store.model.entitiesByName objectForKey:@"BLYVideoURLType"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"itag = %d", itag];
    NSError *err = nil;
    
    request.entity = entity;
    request.predicate = predicate;
    
    NSArray *results = [store.context executeFetchRequest:request
                                                    error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", err.localizedDescription];
    }
    
    if (![results count]) {
        return nil;
    }
    
    return [results objectAtIndex:0];
}

- (int)itagFromURL:(NSString *)url
{
    int itag = -1;
    NSRegularExpression *itagReg = [[NSRegularExpression alloc] initWithPattern:@"itag(?:/|=)([0-9]+)"
                                                                        options:NSRegularExpressionCaseInsensitive
                                                                          error:nil];
    NSArray *matchesItag = [itagReg matchesInString:url
                                            options:0
                                              range:[url bly_fullRange]];
    
    if ([matchesItag count] > 0) {
        NSTextCheckingResult *resultItag = [matchesItag objectAtIndex:0];
        
        if ([resultItag numberOfRanges] >= 2) {
            NSRange range = [resultItag rangeAtIndex:1];
            
            itag = [[url substringWithRange:range] intValue];
        }
    }
    
    return itag;
}

- (void)removeURLsOfVideo:(BLYVideo *)video
{
    video.urls = [[NSSet alloc] init];
    
    [[BLYStore sharedStore] saveChanges];
}

- (void)setIsVevo:(BOOL)isVevo forVideo:(BLYVideo *)video
{
    video.isVevo = [NSNumber numberWithBool:isVevo];
    
    [[BLYStore sharedStore] saveChanges];
}

- (BLYVideoStoreFetchVideoRequestTimeout)fetchVideoRequestTimeout
{
    UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
    
    if (appState == UIApplicationStateBackground) {
        return BLYVideoStoreFetchVideoRequestTimeoutBackground;
    }
    
    return BLYVideoStoreFetchVideoRequestTimeoutActive;
}

- (void)fetchVideoIDForSong:(BLYSong *)song
                 andCountry:(NSString *)country
               inBackground:(BOOL)inBackground
             withCompletion:(void (^)(NSMutableArray *videos, NSError *err))block
{
    static BOOL isNoResultsFetch = NO;
    
    NSString *artistName = song.artist.name;
    NSString *albumName = song.album.name;
    NSString *albumArtistName = song.album.artist.name;
    
    NSString *query = nil;
    
    if (![song.isVideo boolValue]) {
        if (!albumArtistName) {
            albumArtistName = @"";
        }
        
        NSString *multipleArtistsPattern = @"\\s*,.+";
        NSString *singlePattern = @"\\s+(single|EP)$";
        NSString *variousArtistsPattern = @"Various Artists|Multi-interprètes";
        //NSString *soundTrackPattern = @"(?:\\(|\\[).*Bande originale|soundtrack";
        
        // If multiple artists or soundtrack, query = album name + song title
        // || [albumName bly_match:soundTrackPattern]
        if ([artistName bly_match:multipleArtistsPattern]
            || [albumArtistName bly_match:variousArtistsPattern]
            || [artistName bly_match:variousArtistsPattern]) {
                
            NSString *cleanAlbumName = [albumName bly_stringByRemovingParenthesisAndBracketsContent];
            
            if (![albumName bly_match:singlePattern]) {
                query = [cleanAlbumName stringByAppendingString:[NSString stringWithFormat:@"  %@", song.title]];
            } else {
                NSString *mainArtistName = [artistName bly_artistNameByRemovingRightPartOfComposedArtist];
                
                query = [mainArtistName stringByAppendingString:[NSString stringWithFormat:@" %@", song.title]];
            }
        } else {
            NSString *featPattern = @"\\s*(?:\\(|\\[|\\{)(?:feat\\.|ft\\.|featuring)(.+)(?:\\)|\\]|\\})";
            NSString *mainArtistName = artistName;
            NSString *songTitle = song.title;
            
            if ([song.title bly_match:featPattern] || isNoResultsFetch) {
                mainArtistName = [artistName bly_artistNameByRemovingRightPartOfComposedArtist];
                
                NSRegularExpression *nameExpression = [NSRegularExpression regularExpressionWithPattern:featPattern
                                                                                                options:NSRegularExpressionCaseInsensitive
                                                                                                  error:nil];
                
                NSArray *matches = [nameExpression matchesInString:song.title
                                                           options:0
                                                             range:[song.title bly_fullRange]];
                
                for (NSTextCheckingResult *match in matches) {
                    if ([match numberOfRanges] < 2) {
                        continue;
                    }
                    
                    NSRange matchRange = [match rangeAtIndex:1];
                    NSString *featArtistName = [songTitle substringWithRange:matchRange];
                    
                    songTitle = [songTitle bly_stringByReplacingPattern:featPattern withString:featArtistName];
                    
                    break;
                }
            }
            
            query = [mainArtistName stringByAppendingString:[NSString stringWithFormat:@" %@", songTitle]];
        }
        
        query = [query lowercaseString];
        query = [query bly_stringByRemovingAccents];
        
        if (!isNoResultsFetch) {
            // Remove brackets after first brackets
            NSString *garbagePattern = @"(?<=(\\)|\\]|\\}))\\s*(?:\\(|\\[|\\{).+$";
            query = [query bly_stringByReplacingPattern:garbagePattern
                                             withString:@""];
            
            // Remove all brackets except feat, acoustique, (re)mix
            // @"\\s*(?:\\(|\\[)((feat|ft)\\..+|radio edit|from .+|extrait de .+|single version)(?:\\)|\\])?"
            NSString *versionPattern = @"\\s*(?:\\(|\\[|\\{)(?!feat|ft\\.|acoustic|acoustique|.*remix.*|.*mix.*).+";
            query = [query bly_stringByReplacingPattern:versionPattern
                                             withString:@""];
        } else {
            query = [query bly_stringByRemovingParenthesisAndBracketsContent];
        }
        
        // Replace non-alphanumeric characters by space
        NSString *nonAlphanumericPattern = @"[^a-z0-9A-Z\\s'\\\"-]";
        query = [query bly_stringByReplacingPattern:nonAlphanumericPattern
                                         withString:@" "];
        
        // Replace multiple spaces with one space
        query = [query bly_stringByReplacingMultipleConsecutiveSpacesToOne];
    }
    
    NSURL *url = [BLYVideoStore URLForServiceToFetchForQuery:query
                                                    duration:song.duration
                                 andSongTitleMatchAlbumTitle:[[song.title lowercaseString] isEqualToString:[[song.album.name bly_stringByRemovingParenthesisAndBracketsContent] lowercaseString]]
                                                  andCountry:country
                                                       limit:BLYVideoStoreMaxVideoResultsForQuery];
    
    if ([song.isVideo boolValue]) {
        url = [BLYVideoStore URLForServiceToLookupVideo:song.sid];
    }
    
    // Set up the connection as normal
    NSURLRequest *req = [NSURLRequest requestWithURL:url];
    
    BLYHTTPConnection *connection = [[BLYHTTPConnection alloc] initWithRequest:req];
    
    connection.displayActivityIndicator = !inBackground;
    
    __weak BLYVideoStore *weakSelf = self;
    
    BOOL _isNoResultsFetch = isNoResultsFetch;
    __block BOOL expired = NO;
    
    isNoResultsFetch = NO;
    
    [connection setCompletionBlock:^(NSData *obj, NSError *err) {
        if (expired) {
            return;
        }
        
        expired = true;
        
        NSMutableArray *videos = [[NSMutableArray alloc] init];
        NSMutableArray *videoObjects = [[NSMutableArray alloc] init];
        NSMutableArray *videoIDs = [[NSMutableArray alloc] init];
        
        if (!err) {
            NSDictionary *d = [NSJSONSerialization JSONObjectWithData:obj options:0 error:nil];
            NSDictionary *data = d;
            
            NSString * (^cleanSongTitle)(NSString *songTitle) = ^NSString * (NSString *songTitle){
                NSString *s = [[songTitle lowercaseString] bly_stringByRemovingAccents];
                
                s = [s bly_stringByRemovingParenthesisAndBracketsContent];
                NSString *nonAlphanumericPattern = @"[^a-z0-9A-Z]";
                s = [s bly_stringByReplacingPattern:nonAlphanumericPattern withString:@""];
                
                return [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            };
            
            float trackTime = [[song duration] intValue] / 1000;
            BOOL(^isGoodDuration)(NSDictionary *, BOOL) = ^BOOL(NSDictionary *video, BOOL minLimit){
                return (!trackTime ||
                        ((!minLimit || [video[@"duration"] intValue] >= trackTime)
                         && [video[@"duration"] intValue] <= (4 * trackTime)));
            };
            
            [weakSelf removeVideosForSong:song];
            
            if ([data[@"items"] count] > 0) {
                // Search videos for song
                if (![song.isVideo boolValue]) {
                    for (NSDictionary *video in data[@"items"]) {
                        [videos addObject:@[video, [NSNumber numberWithBool:NO]]];
                    }
                    
                    // Avoid full album
//                    if (trackTime > 0) {
//                        for (NSDictionary *video in data[@"items"]) {
//                            if (isGoodDuration(video, YES)
//                                && ![videoIDs containsObject:video[@"id"]]) {
//                                [videos addObject:@[video, [NSNumber numberWithBool:NO]]];
//                                [videoIDs addObject:video[@"id"][@"videoId"]];
//                            }
//                        }
//                    } else {
//                        // Keep song under 10 minutes
//                        for (NSDictionary *video in data[@"items"]) {
//                            if ([video[@"duration"] intValue] < 60 * 10) {
//                                [videos addObject:@[video, [NSNumber numberWithBool:NO]]];
//                                [videoIDs addObject:video[@"id"][@"videoId"]];
//                            }
//                        }
//                    }
//
//                    for (NSDictionary *video in data[@"items"]) {
//                        if (![videoIDs containsObject:video[@"id"][@"videoId"]]) {
//                            [videos addObject:@[video, [NSNumber numberWithBool:NO]]];
//                        }
//                    }
                    
                    // If video description contains copyright symbol it's probably official video
                    // so put it on the top of the videos array
    //                NSString *copyrightPattern = @"\\(C\\)|©";
    //                
    //                [videos sortUsingComparator:^NSComparisonResult(id obj1, id obj2){
    //                    NSDictionary *video1 = [obj1 objectAtIndex:0];
    //                    NSDictionary *video2 = [obj2 objectAtIndex:0];
    //                    
    //                    if ([video1[@"description"] bly_match:copyrightPattern]
    //                        && ![video2[@"description"] bly_match:copyrightPattern]) {
    //                            return NSOrderedAscending;
    //                    } else if (![video1[@"description"] bly_match:copyrightPattern]
    //                                && [video2[@"description"] bly_match:copyrightPattern]) {
    //                            return NSOrderedDescending;
    //                    }
    //                    
    //                    return NSOrderedSame;
    //                }];
                    
                    // If video uploader contains vevo it's probably official video
                    // so put it on the top of the videos array
                    NSString *vevoPattern = @"vevo$";
                    NSString *audioPattern = @"\\(audio.*\\)";
                    NSString *remixPattern = @"remix";
                    NSString *vevoLivePattern = @"\\(vevo presents\\)";
                    __block BOOL hasVevo = NO;
                    
                    [videos sortUsingComparator:^NSComparisonResult(id obj1, id obj2){
                        NSDictionary *video1 = [obj1 objectAtIndex:0][@"snippet"];
                        NSDictionary *video2 = [obj2 objectAtIndex:0][@"snippet"];
                        
                        if ([video1[@"channelTitle"] bly_match:vevoPattern]
                            && [video1[@"title"] bly_match:audioPattern]
                            && ![video1[@"title"] bly_match:remixPattern]
                            && ![video1[@"title"] bly_match:vevoLivePattern]) {
                            hasVevo = YES;
                            
                            return NSOrderedAscending;
                        } else if ([video2[@"channelTitle"] bly_match:vevoPattern]
                                   && [video2[@"title"] bly_match:audioPattern]
                                   && ![video2[@"title"] bly_match:remixPattern]
                                   && ![video2[@"title"] bly_match:vevoLivePattern]) {
                            hasVevo = YES;
                            
                            return NSOrderedDescending;
                        }
                        
                        return NSOrderedSame;
                    }];
//
//                    // Make sure Vevo video corresponds to searched song...
//                    if (hasVevo) {
//                        NSString *cleanedSongTitle = cleanSongTitle(song.title);
//                        
//                        [videos sortUsingComparator:^NSComparisonResult(id obj1, id obj2){
//                            NSDictionary *video1 = [obj1 objectAtIndex:0][@"snippet"];
//                            NSDictionary *video2 = [obj2 objectAtIndex:0][@"snippet"];
//                            
//                            NSString *video1Title = cleanSongTitle(video1[@"title"]);
//                            NSString *video2Title = cleanSongTitle(video2[@"title"]);
//                            
//                            if ([video1Title rangeOfString:cleanedSongTitle].location != NSNotFound
//                                && [video2Title rangeOfString:cleanedSongTitle].location == NSNotFound) {
//                                return NSOrderedAscending;
//                            } else if ([video1Title rangeOfString:cleanedSongTitle].location == NSNotFound
//                                       && [video2Title rangeOfString:cleanedSongTitle].location != NSNotFound) {
//                                return NSOrderedDescending;
//                            }
//                            
//                            return NSOrderedSame;
//                        }];
//                    }
                } else { // Video lookup
                    [videos addObject:@[data[@"items"][0], [NSNumber numberWithBool:NO]]];
                }
                
                for (NSArray *video in videos) {
                    NSString *videoID = ![song.isVideo boolValue] ? video[0][@"id"][@"videoId"] : video[0][@"id"];
                    NSString *uploader = video[0][@"snippet"][@"channelTitle"];
                    
                    int videoDuration = 300;
                    BOOL possibleGarbage = [video[1] boolValue];
                    
                    NSString *vevoPattern = @"vevo$";
                    BOOL isVevo = [uploader bly_match:vevoPattern];
                    
                    BLYVideo *insertedVideo = [weakSelf insertVideoWithID:videoID
                                                                 duration:videoDuration
                                                                   isVevo:isVevo
                                                       andPossibleGarbage:possibleGarbage
                                                                  forSong:song];
                    
                    [videoObjects addObject:insertedVideo];
                }
                
                [[BLYStore sharedStore] saveChanges];
            } else if (!_isNoResultsFetch) {
                isNoResultsFetch = YES;
                
                return [self fetchVideoIDForSong:song
                                      andCountry:country
                                    inBackground:inBackground
                                  withCompletion:block];
            }
        }
            
        block(videoObjects, err);
    }];
    
    [connection start];
    
    [NSTimer scheduledTimerWithTimeInterval:self.fetchVideoRequestTimeout * 1.0 repeats:NO block:^(NSTimer * _Nonnull timer) {
        if (expired) {
            return;
        }
        
        expired = true;
        
        block([[NSMutableArray alloc] init], [[BLYStore sharedStore] timeoutError]);
    }];
}

- (void)fetchVideoURLForVideoOfSong:(BLYSong *)song
                       inBackground:(BOOL)inBackground
                     withCompletion:(void (^)(NSURL *videoURL, NSError *err))block
{
    NSOrderedSet *videoSongs = song.videos;
    BLYVideoSong *videoSong = [videoSongs objectAtIndex:0];
    BLYVideo *video = videoSong.video;
    __block BOOL expired = NO;
    
    __weak BLYVideoStore *weakSelf = self;
    
    BLYYoutubeExtractor *ytExtractor = [[BLYYoutubeExtractor alloc] init];
    float timeout = self.fetchVideoRequestTimeout * 2.0;
    
//    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive
//        && ![[song loadedByUser] boolValue]) {
//
//        timeout = self.fetchVideoRequestTimeout * 1.0;
//    }
    
    [ytExtractor urlsForVideo:video inBackground:inBackground andCompletionBlock:^(NSArray *videoURLs, NSError *error){
        if (expired) {
            return;
        }
        
        expired = true;
        
        if (error) {
            NSMutableOrderedSet *videoSongsAsSet = [videoSongs mutableCopy];
            
            if ([videoSongsAsSet count] > 0) {
                BLYVideoSong *videoSongToRemove = [videoSongsAsSet objectAtIndex:0];
                
                [videoSongsAsSet removeObjectAtIndex:0];
                
                videoSongToRemove.song = nil;
                
                [weakSelf setVideos:[videoSongsAsSet copy]
                            forSong:song];
            }
            
            // Check after eventual remove
            if ([videoSongsAsSet count] > 0) {
                return [weakSelf fetchVideoURLForVideoOfSong:song
                                                inBackground:inBackground
                                              withCompletion:block];
            }
                
            return block(nil, nil);
        }
        
        NSURL *videoURL = nil;
        
        if ([videoURLs count] > 0) {
            NSString *videoURLAsString = [videoURLs objectAtIndex:0];
            
            videoURL = [[NSURL alloc] initWithString:videoURLAsString];
            
            [weakSelf insertURLs:videoURLs forVideo:video];
        }
        
        return block(videoURL, nil);
    }];
    
    [NSTimer scheduledTimerWithTimeInterval:timeout repeats:NO block:^(NSTimer * _Nonnull timer) {
        if (expired) {
            return;
        }
        
        expired = true;
        
        block(nil, [[BLYStore sharedStore] timeoutError]);
    }];
}

- (BLYVideoURL *)urlForVideo:(BLYVideo *)video
                 withQuality:(NSString *)wantedQuality
                    andBound:(NSString *)bound
{
    NSArray *urls = [video.urls allObjects];
    BLYVideoURL *chosenURL = nil;
    NSNumber *chosenItag = nil;
    
    for (BLYVideoURL *url in urls) {
        int itag = [url.type.itag intValue];
        
        if ([url.type.defaultContainer isEqualToString:wantedQuality]) {
            if (!chosenItag
                || ([bound isEqualToString:@"min"] && [chosenItag intValue] > itag)
                || ([bound isEqualToString:@"max"] && [chosenItag intValue] < itag)) {
                
                chosenItag = url.type.itag;
                chosenURL = url;
            }
        }
    }
    
    return chosenURL;
}

- (BLYVideoURL *)bestURLForCurrentNetworkAndVideo:(BLYVideo *)video
{
    NSArray *urls = [video.urls allObjects];
    BLYNetworkStore *networkStore = [BLYNetworkStore sharedStore];
    
    BLYVideoURL *chosenURL = nil;
    BLYNetworkStoreNetworkType networkType = [networkStore networkType];
    
    NSString *wantedQuality = @"3gp";
    NSString *bound = @"min";
    
    if (!urls) {
        return nil;
    }
    
    if (networkType == BLYNetworkStoreNetworkTypeWIFI
        || networkType == BLYNetworkStoreNetworkType4G
        || networkType == BLYNetworkStoreNetworkType3G5) {
        wantedQuality = @"mp4";
    } else if (networkType == BLYNetworkStoreNetworkType3G) {
        bound = @"max";
    }
    
    chosenURL = [self urlForVideo:video
                      withQuality:wantedQuality
                         andBound:bound];
    
    if (!chosenURL) {
        chosenURL = [urls firstObject];
    }
    
    return chosenURL;
}

- (BLYVideoURL *)bestURLForCacheAndVideo:(BLYVideo *)video
{
    BLYVideoURL *chosenURL = nil;
    NSArray *urls = [video.urls allObjects];
    
    chosenURL = [self urlForVideo:video
                      withQuality:@"mp4"
                         andBound:@"min"];
    
    if (!chosenURL) {
        chosenURL = [urls firstObject];
    }
    
    return chosenURL;
}

- (void)setPath:(NSString *)path
       forVideo:(BLYVideo *)video
{
    video.path = path;
    
    [[BLYStore sharedStore] saveChanges];
}

- (void)deleteVideoFileForVideo:(BLYVideo *)video
{
    if (!video.path) {
        return;
    }
    
    NSString *cacheDirectory = [[BLYStore sharedStore] cacheDirectory];
    NSString *videoPath = [cacheDirectory stringByAppendingPathComponent:video.path];
    
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    NSError *error = nil;
    
    if (![fileMgr removeItemAtPath:videoPath error:&error]) {
        NSLog(@"Unable to delete file: %@", error.localizedDescription);
    }
}

- (void)fetchCommentsForVideo:(BLYVideo *)video
               withCompletion:(void (^)(NSArray *, NSError *))completion
{
    NSMutableArray *comments = [[self fetchUndisplayedCommentsForVideo:video] mutableCopy];
    
    // Undisplayed comments ?
    if ([comments count] > 0) {
        // Returns video.comments to also return displayed comments
        return completion([video.comments array], nil);
    }
    
    comments = [[NSMutableArray alloc] init];
    
    // Prepare a request URL, including the argument from the controller
    NSURL *url = [BLYVideoStore URLForServiceToFetchCommentsForVideo:video.sid];
    
    // Set up the connection as normal
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    
    // Set user agent to avoid null return
    [req setValue:@"Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; Trident/6.0)"
forHTTPHeaderField:@"User-Agent"];
    
    BLYHTTPConnection *connection = [[BLYHTTPConnection alloc] initWithRequest:req];
    __weak BLYVideoStore *weakSelf = self;
    
    [connection setCompletionBlock:^(NSData *obj, NSError *err){
        if (!err) {
            NSDictionary *returnedResults = [NSJSONSerialization JSONObjectWithData:obj options:0 error:nil];
            NSArray *items = returnedResults[@"items"];
            
            if ([items count] > 0) {
                for (NSDictionary *comment in items) {
                    NSString *sid = comment[@"id"];
                    NSString *content = comment[@"snippet"][@"topLevelComment"][@"snippet"][@"textDisplay"];
                    
                    if ([content isEqualToString:@""]) {
                        continue;
                    }
                    
                    content = [content stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    
                    NSString *publishedAtAsString = comment[@"snippet"][@"topLevelComment"][@"snippet"][@"publishedAt"];
                    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                    
                    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
                    
                    NSDate *publishedAt = [dateFormatter dateFromString:publishedAtAsString];
                    
                    NSString *authorName = comment[@"snippet"][@"topLevelComment"][@"snippet"][@"authorDisplayName"];
                    NSString *authorID = comment[@"snippet"][@"topLevelComment"][@"snippet"][@"authorChannelId"][@"value"];
                    
                    if ([authorName isEqualToString:@""]) {
                        authorName = @"Unknown";
                    }
                    
                    BLYYoutubeUser *user = [weakSelf insertYoutubeUserWithID:authorID
                                                                        name:authorName];
                    
                    BLYVideoComment *comment = [weakSelf insertYoutubeCommentWithSid:sid
                                                                          andContent:content
                                                                      andPublishedAt:publishedAt
                                                                            forVideo:video
                                                                      andYoutubeUser:user];
                    
                    [comments addObject:comment];
                }
                
                [[BLYStore sharedStore] saveChanges];
            }
        }
        
        completion(comments, err);
    }];
    
    [connection start];
}

- (BLYYoutubeUser *)insertYoutubeUserWithID:(NSString *)ID
                                       name:(NSString *)name
{
    BLYStore *store = [BLYStore sharedStore];
    BLYYoutubeUser *user = [store uniqueEntityOf:@"BLYYoutubeUser"
                                         withSid:ID];
    
    if (user) {
        return user;
    }
    
    user = [NSEntityDescription insertNewObjectForEntityForName:@"BLYYoutubeUser"
                                         inManagedObjectContext:store.context];
    
    user.sid = ID;
    user.name = name;
    
    return user;
}

- (BLYVideoComment *)insertYoutubeCommentWithSid:(NSString *)sid
                                      andContent:(NSString *)content
                                  andPublishedAt:(NSDate *)publishedAt
                                        forVideo:(BLYVideo *)video
                                  andYoutubeUser:(BLYYoutubeUser *)user
{
    BLYStore *store = [BLYStore sharedStore];
    BLYVideoComment *comment = [store uniqueEntityOf:@"BLYVideoComment"
                                             withSid:sid];
    NSMutableOrderedSet *comments = [video.comments mutableCopy];
    NSMutableSet *userComments = [user.videoComments mutableCopy];
    
    if (comment) {
        return comment;
    }
    
    comment = [NSEntityDescription insertNewObjectForEntityForName:@"BLYVideoComment"
                                            inManagedObjectContext:store.context];
    
    comment.sid = sid;
    comment.content = content;
    comment.publishedAt = publishedAt;
    comment.video = video;
    comment.author = user;
    
    
    [comments addObject:comment];
    [userComments addObject:comment];
    
    video.comments = [comments copy];
    user.videoComments = [userComments copy];
    
    return comment;
}

- (void)updateIsDisplayedFlag:(BOOL)flag forComment:(BLYVideoComment *)comment
{
    comment.isDisplayed = [NSNumber numberWithBool:flag];
    
    [[BLYStore sharedStore] saveChanges];
}

- (NSArray *)fetchUndisplayedCommentsForVideo:(BLYVideo *)video
{
    NSMutableArray *returnedComments = [[NSMutableArray alloc] init];
    NSOrderedSet *comments = video.comments;
    
    if (!comments || [comments count] == 0) {
        return [returnedComments copy];
    }
    
    for (BLYVideoComment *comment in comments) {
        if ([comment.isDisplayed boolValue]) {
            continue;
        }
        
        [returnedComments addObject:comment];
    }
    
    return [returnedComments copy];
}

- (void)cleanVideoComments
{
    BLYStore *store = [BLYStore sharedStore];
    NSManagedObjectModel *model = store.model;
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    
    NSEntityDescription *entity = [model.entitiesByName objectForKey:@"BLYVideoComment"];
    NSError *err = nil;
    
    request.entity = entity;
    
    NSArray *results = [store.context executeFetchRequest:request error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", err.localizedDescription];
    }
    
    if ([results count] == 0) {
        return;
    }
    
    for (BLYVideoComment *comment in results) {
        [store.context deleteObject:comment];
    }
    
    [store saveChanges];
}

- (BLYHTTPConnection *)fetchVideosForQuery:(NSString *)query
                                 orChannel:(NSString *)channel
                                andCountry:(NSString *)country
                            withCompletion:(void (^)(NSMutableDictionary *results, NSError *err))block
                       andCompletionForImg:(void (^)(BOOL hasDownloaded, BLYSong *song))imgBlock
{
    // Prepare a request URL, including the argument from the controller
    NSURL *url = [BLYVideoStore URLForServiceToFetchVideosForQuery:query
                                                         orChannel:channel
                                                        andCountry:country];
    
    // Set up the connection as normal
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    
    // Set user agent to avoid null return
    [req setValue:@"Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; Trident/6.0)"
forHTTPHeaderField:@"User-Agent"];
    
    BLYHTTPConnection *connection = [[BLYHTTPConnection alloc] initWithRequest:req];
    BLYSongStore *songStore = [BLYSongStore sharedStore];
    
    __weak BLYVideoStore *weakSelf = self;
    __block BOOL expired = NO;
    
    [connection setCompletionBlock:^(NSData *obj, NSError *err){
        if (expired) {
            return;
        }
        
        expired = true;
        
        NSMutableDictionary *results = [[NSMutableDictionary alloc] init];
        BLYPlaylist *playlist = [[BLYPlaylist alloc] init];
        
        if (!err) {
            NSDictionary *returnedResults = [NSJSONSerialization JSONObjectWithData:obj options:0 error:nil];
            NSMutableArray *videoIDs = [[NSMutableArray alloc] init];
            
            if (returnedResults && returnedResults[@"pageInfo"][@"totalResults"] > 0) {
                for (NSDictionary *result in returnedResults[@"items"]) {
                    NSString *searchResultKind = result[@"id"][@"kind"];
                    NSString *albumName = @"";
                    NSNumber *albumSid = [NSNumber numberWithInt:[self uniqueAlbumIDForVideo]];
                    
                    if (![searchResultKind isEqualToString:@"youtube#video"]) {
                        continue;
                    }
                    
                    NSString *albumReleaseDateAsString = [result[@"snippet"][@"publishedAt"] substringToIndex:10];
                    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                    
                    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
                    
                    NSDate *albumReleaseDate = [dateFormatter dateFromString:albumReleaseDateAsString];
                    
                    NSString *songSid = result[@"id"][@"videoId"];
                    NSString *songTitle = result[@"snippet"][@"title"];
                    
                    [videoIDs addObject:songSid];
                    
                    NSNumber *trackNumber = [NSNumber numberWithInt:1];
                    
                    NSString *artistName = result[@"snippet"][@"channelTitle"];
                    NSString *artistSid = result[@"snippet"][@"channelId"];
                    
                    // Fix YouTube API Bug
                    if ([artistName isEqualToString:@""]) {
                        artistName = @"Unknown";
                    }
                    
                    NSMutableString *thumbnailURLAsString = [result[@"snippet"][@"thumbnails"][@"high"][@"url"] mutableCopy];
                    
                    NSURL *thumbnailURL = [NSURL URLWithString:thumbnailURLAsString];
                    
                    BLYArtist *artist = [songStore insertArtistWithSid:artistSid
                                                   andIsYoutubeChannel:YES
                                                             inCountry:country];
                    
                    BLYArtistSong *artistSong = [songStore insertArtistSongForArtist:artist
                                                                            withName:artistName
                                                                       andIsRealName:YES];
                    
                    BLYAlbum *album = [songStore insertAlbumWithName:albumName
                                                                 sid:[albumSid intValue]
                                                             country:country
                                                        thumbnailURL:thumbnailURLAsString
                                                      andReleaseDate:albumReleaseDate
                                                      forArtistSong:artistSong
                                                            replace:NO];
                    
                    BLYSong *song = [songStore insertSongWithTitle:songTitle
                                                               sid:songSid
                                                        artistSong:artistSong
                                                          duration:0
                                                           isVideo:YES
                                                    andRankInAlbum:[trackNumber intValue]
                                                          forAlbum:album];
                    
                    [playlist addSong:song];
                    
//                    [songStore loadThumbnailWithURL:thumbnailURL
//                                           forAlbum:album
//                                withCompletionBlock:^{
//                                   imgBlock();
//                                }];
                }
                
                // Make sure to save before update duration
                [[BLYStore sharedStore] saveChanges];
                
                [weakSelf updateDurationForVideosWithIDs:videoIDs];
            }
        }
        
        results[@"playlist"] = playlist;
        
        [songStore loadThumbnailsForPlaylist:playlist withCompletionForSong:^(BOOL hasDownloaded, BLYSong *s){
            imgBlock(hasDownloaded, s);
        } andCompletionBlock:nil];
        
        block(results, err);
    }];
    
    [connection start];
    
    [NSTimer scheduledTimerWithTimeInterval:self.fetchVideoRequestTimeout * 1.0 repeats:NO block:^(NSTimer * _Nonnull timer) {
        if (expired) {
            return;
        }
        
        expired = true;
        
        NSMutableDictionary *results = [[NSMutableDictionary alloc] init];
        BLYPlaylist *playlist = [[BLYPlaylist alloc] init];
        
        results[@"playlist"] = playlist;
        
        block(results, [[BLYStore sharedStore] timeoutError]);
    }];
    
    return connection;
}

- (void)updateDurationForVideosWithIDs:(NSArray *)videoIDs
{
    // Prepare a request URL, including the argument from the controller
    NSURL *url = [BLYVideoStore URLForServiceToLookupVideosWithIDs:videoIDs
                                                         withParts:@"contentDetails"];
    
    // Set up the connection as normal
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    
    // Set user agent to avoid null return
    [req setValue:@"Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; Trident/6.0)"
forHTTPHeaderField:@"User-Agent"];
    
    BLYHTTPConnection *connection = [[BLYHTTPConnection alloc] initWithRequest:req];
    __weak BLYVideoStore *weakSelf = self;
    
    [connection setCompletionBlock:^(NSData *obj, NSError *err){
        if (!err) {
            NSDictionary *returnedResults = [NSJSONSerialization JSONObjectWithData:obj options:0 error:nil];
            BLYTimeManager *timeManager = [[BLYTimeManager alloc] init];
            
            if (returnedResults && returnedResults[@"pageInfo"][@"totalResults"] > 0) {
                for (NSDictionary *result in returnedResults[@"items"]) {
                    int duration = [timeManager ISO8601TimeToSeconds:result[@"contentDetails"][@"duration"]];
                    
                    [[BLYSongStore sharedStore] updateSongDuration:duration forSongWithID:result[@"id"]];
                }
                
                [[BLYStore sharedStore] saveChanges];
                
                [[NSNotificationCenter defaultCenter] postNotificationName:BLYVideoStoreDidUpdateSongsDurationNotification
                                                                    object:weakSelf];
            }
        }
    }];
    
    connection.displayActivityIndicator = NO;
    
    [connection start];
}

- (void)lookupVideosWithIDs:(NSArray *)videos
                 forCountry:(NSString *)country
             withCompletion:(void (^)(BLYPlaylist *, NSError *))block
        andCompletionForImg:(void (^)(BOOL hasDownloaded, BLYSong *song))imgBlock
{
    NSMutableArray *videoIDs = [[NSMutableArray alloc] init];
    BLYPlaylist *playlist = [[BLYPlaylist alloc] init];
    BLYSongStore *songStore = [BLYSongStore sharedStore];
    
    for (BLYVideoSong *v in videos) {
        if (v.video.songRepresentation) {
            [playlist addSong:v.video.songRepresentation];
            
//            // Retry to load missing thumbnail
//            if (!v.video.songRepresentation.album.thumbnail
//                // URL was addded in version 1.1
//                && v.video.songRepresentation.album.privateThumbnail.url) {
//                NSURL *url = [NSURL URLWithString:v.video.songRepresentation.album.privateThumbnail.url];
//
//                [songStore loadThumbnailWithURL:url
//                                       forAlbum:v.video.songRepresentation.album
//                            withCompletionBlock:^{
//                                imgBlock();
//                            }];
//            }
        }
        
        [videoIDs addObject:v.video.sid];
    }
    
    // All videos have song representation ?
    if ([playlist nbOfSongs] == [videos count]) {
        return block(playlist, nil);
    } else {
        playlist = [[BLYPlaylist alloc] init];
    }
    
    // Prepare a request URL, including the argument from the controller
    NSURL *url = [BLYVideoStore URLForServiceToLookupVideosWithIDs:videoIDs
                                                         withParts:@"id,snippet"];
    
    // Set up the connection as normal
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    
    // Set user agent to avoid null return
    [req setValue:@"Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; Trident/6.0)"
forHTTPHeaderField:@"User-Agent"];
    
    BLYHTTPConnection *connection = [[BLYHTTPConnection alloc] initWithRequest:req];
    __weak BLYVideoStore *weakSelf = self;
    __block BOOL expired = NO;
    
    [connection setCompletionBlock:^(NSData *obj, NSError *err){
        if (expired) {
            return;
        }
        
        expired = true;
        
        if (!err) {
            NSDictionary *returnedResults = [NSJSONSerialization JSONObjectWithData:obj options:0 error:nil];
            NSMutableArray *videoIDs = [[NSMutableArray alloc] init];
            
            if (returnedResults && returnedResults[@"pageInfo"][@"totalResults"] > 0) {
                for (NSDictionary *result in returnedResults[@"items"]) {
                    NSString *albumName = @"";
                    NSNumber *albumSid = [NSNumber numberWithInt:[self uniqueAlbumIDForVideo]];
                    
                    NSString *albumReleaseDateAsString = [result[@"snippet"][@"publishedAt"] substringToIndex:10];
                    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                    
                    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
                    
                    NSDate *albumReleaseDate = [dateFormatter dateFromString:albumReleaseDateAsString];
                    
                    NSString *songSid = result[@"id"];
                    NSString *songTitle = result[@"snippet"][@"title"];
                    
                    [videoIDs addObject:songSid];
                    
                    NSNumber *trackNumber = [NSNumber numberWithInt:1];
                    
                    NSString *artistName = result[@"snippet"][@"channelTitle"];
                    NSString *artistSid = result[@"snippet"][@"channelId"];
                    
                    // Fix YouTube API Bug
                    if ([artistName isEqualToString:@""]) {
                        artistName = @"Unknown";
                    }
                    
                    NSMutableString *thumbnailURLAsString = [result[@"snippet"][@"thumbnails"][@"high"][@"url"] mutableCopy];
                    
                    NSURL *thumbnailURL = [NSURL URLWithString:thumbnailURLAsString];
                    
                    BLYArtist *artist = [songStore insertArtistWithSid:artistSid
                                                   andIsYoutubeChannel:YES
                                                             inCountry:country];
                    
                    BLYArtistSong *artistSong = [songStore insertArtistSongForArtist:artist
                                                                            withName:artistName
                                                                       andIsRealName:YES];
                    
                    BLYAlbum *album = [songStore insertAlbumWithName:albumName
                                                                 sid:[albumSid intValue]
                                                             country:country
                                                        thumbnailURL:thumbnailURLAsString
                                                      andReleaseDate:albumReleaseDate
                                                       forArtistSong:artistSong
                                                             replace:NO];
                    
                    BLYSong *song = [songStore insertSongWithTitle:songTitle
                                                               sid:songSid
                                                        artistSong:artistSong
                                                          duration:0
                                                           isVideo:YES
                                                    andRankInAlbum:[trackNumber intValue]
                                                          forAlbum:album];
                    
                    [playlist addSong:song];
                    
//                    [songStore loadThumbnailWithURL:thumbnailURL
//                                           forAlbum:album
//                                withCompletionBlock:^{
//                                    imgBlock();
//                                }];
                    
                    for (BLYVideoSong *v in videos) {
                        if ([v.video.sid isEqualToString:song.sid]) {
                            song.videoRepresentation = v.video;
                            
                            v.video.songRepresentation = song;
                            
                            break;
                        }
                    }
                }
                
                // Make sure to save before update duration
                [[BLYStore sharedStore] saveChanges];
                
                [weakSelf updateDurationForVideosWithIDs:videoIDs];
            }
        }
        
        [songStore loadThumbnailsForPlaylist:playlist withCompletionForSong:^(BOOL hasDownloaded, BLYSong *s){
            imgBlock(hasDownloaded, s);
        } andCompletionBlock:nil];
        
        block(playlist, err);
    }];
    
    [connection start];
    
    [NSTimer scheduledTimerWithTimeInterval:self.fetchVideoRequestTimeout * 1.4 repeats:NO block:^(NSTimer * _Nonnull timer) {
        if (expired) {
            return;
        }
        
        expired = true;
        
        block(playlist, [[BLYStore sharedStore] timeoutError]);
    }];
}

- (void)removeRelatedSongsOfSong:(BLYSong *)song
{
    song.relatedSongs = [[NSOrderedSet alloc] init];
    
    [[BLYStore sharedStore] saveChanges];
}


- (BLYHTTPConnection *)fetchRelatedVideosForVideo:(BLYVideo *)video
                                           ofSong:(BLYSong *)currentSong
                                       andCountry:(NSString *)country
                                   withCompletion:(void (^)(BLYPlaylist *, NSError *))block
                              andCompletionForImg:(void (^)(BOOL hasDownloaded, BLYSong *song))imgBlock
{
    BLYSongStore *songStore = [BLYSongStore sharedStore];
    
    if (currentSong.relatedSongs && [currentSong.relatedSongs count] > 0) {
        NSMutableArray *songs = [[currentSong.relatedSongs array] mutableCopy];
        BLYPlaylist *playlist = [[BLYPlaylist alloc] init];
        
//        for (BLYSong *s in songs) {
//            if (!s.album.thumbnail
//                // URL was addded in version 1.1
//                && s.album.privateThumbnail.url) {
//                NSURL *url = [NSURL URLWithString:s.album.privateThumbnail.url];
//                
//                [songStore loadThumbnailWithURL:url
//                                       forAlbum:s.album
//                            withCompletionBlock:^{
//                                imgBlock();
//                            }];
//            }
//        }
        
        playlist.songs = songs;
        
        block(playlist, nil);
        
        return nil;
    }
    
    // Prepare a request URL, including the argument from the controller
    NSURL *url = [BLYVideoStore URLForServiceToFetchRelatedVideosForVideo:video.sid
                                                               andCountry:country];
    
    // Set up the connection as normal
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    
    // Set user agent to avoid null return
    [req setValue:@"Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; Trident/6.0)"
forHTTPHeaderField:@"User-Agent"];
    
    BLYHTTPConnection *connection = [[BLYHTTPConnection alloc] initWithRequest:req];
    __weak BLYVideoStore *weakSelf = self;
    __block BOOL expired = NO;
    
    NSMutableArray *thumbnails = [[NSMutableArray alloc] init];
    NSMutableArray *videoIDs = [[NSMutableArray alloc] init];
    
    [connection setCompletionBlock:^(NSData *obj, NSError *err){
        if (expired) {
            return;
        }
        
        expired = true;
        
        BLYPlaylist *playlist = [[BLYPlaylist alloc] init];
        
        if (!err) {
            NSDictionary *returnedResults = [NSJSONSerialization JSONObjectWithData:obj options:0 error:nil];
            
            if (returnedResults && returnedResults[@"pageInfo"][@"totalResults"] > 0) {
                for (NSDictionary *result in returnedResults[@"items"]) {
                    NSString *albumName = @"";
                    NSNumber *albumSid = [NSNumber numberWithInt:[self uniqueAlbumIDForVideo]];
                    
                    NSString *albumReleaseDateAsString = [result[@"snippet"][@"publishedAt"] substringToIndex:10];
                    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                    
                    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
                    
                    NSDate *albumReleaseDate = [dateFormatter dateFromString:albumReleaseDateAsString];
                    
                    NSString *songSid = result[@"id"][@"videoId"];
                    NSString *songTitle = result[@"snippet"][@"title"];
                    
                    [videoIDs addObject:songSid];
                    
                    NSNumber *trackNumber = [NSNumber numberWithInt:1];
                    
                    NSString *artistName = result[@"snippet"][@"channelTitle"];
                    NSString *artistSid = result[@"snippet"][@"channelId"];
                    
                    // Fix YouTube API Bug
                    if ([artistName isEqualToString:@""]) {
                        artistName = @"Unknown";
                    }
                    
                    NSMutableString *thumbnailURLAsString = [result[@"snippet"][@"thumbnails"][@"high"][@"url"] mutableCopy];
                    
                    NSURL *thumbnailURL = [NSURL URLWithString:thumbnailURLAsString];
                    
                    BLYArtist *artist = [songStore insertArtistWithSid:artistSid
                                                   andIsYoutubeChannel:YES
                                                             inCountry:country];
                    
                    BLYArtistSong *artistSong = [songStore insertArtistSongForArtist:artist
                                                                            withName:artistName
                                                                       andIsRealName:YES];
                    
                    BLYAlbum *album = [songStore insertAlbumWithName:albumName
                                                                 sid:[albumSid intValue]
                                                             country:country
                                                        thumbnailURL:thumbnailURLAsString
                                                      andReleaseDate:albumReleaseDate
                                                       forArtistSong:artistSong
                                                             replace:NO];
                    
                    BLYSong *song = [songStore insertSongWithTitle:songTitle
                                                               sid:songSid
                                                        artistSong:artistSong
                                                          duration:0
                                                           isVideo:YES
                                                    andRankInAlbum:[trackNumber intValue]
                                                          forAlbum:album];
                    
                    [playlist addSong:song];
                    
                    [thumbnails addObject:@[thumbnailURL, album]];
                    
                    if ([playlist nbOfSongs] == 12) {
                        break;
                    }
                }
                
                NSMutableArray *songs = playlist.songs;
                
                // We don't need to set the inverse relation here (aka relatedToSongs)
                // Core data make it for us
                currentSong.relatedSongs = [[NSOrderedSet alloc] initWithArray:songs];
                
                // Make sure to save before update duration
                [[BLYStore sharedStore] saveChanges];
                
                [weakSelf updateDurationForVideosWithIDs:videoIDs];
            }
        }
        
        [songStore loadThumbnailsForPlaylist:playlist withCompletionForSong:^(BOOL hasDownloaded, BLYSong *s){
            imgBlock(hasDownloaded, s);
        } andCompletionBlock:nil];
        
        block(playlist, err);
        
//        for (NSArray *thumbnail in thumbnails) {
//            [[NSOperationQueue currentQueue] addOperationWithBlock:^{
//                [songStore loadThumbnailWithURL:thumbnail[0]
//                                       forAlbum:thumbnail[1]
//                            withCompletionBlock:^{
//                                imgBlock();
//                            }];
//            }];
//        }
    }];
    
    [connection start];
    
    [NSTimer scheduledTimerWithTimeInterval:self.fetchVideoRequestTimeout * 2.0 repeats:NO block:^(NSTimer * _Nonnull timer) {
        if (expired) {
            return;
        }
        
        expired = true;
        
        BLYPlaylist *playlist = [[BLYPlaylist alloc] init];
        
        block(playlist, [[BLYStore sharedStore] timeoutError]);
    }];
    
    return connection;
}

+ (int)durationFromISO8601Time:(NSString*)duration
{
    int hours = 0;
    int minutes = 0;
    int seconds = 0;
    
    //Get Time part from ISO 8601 formatted duration http://en.wikipedia.org/wiki/ISO_8601#Durations
    duration = [duration substringFromIndex:[duration rangeOfString:@"T"].location];
    
    while ([duration length] > 1) { //only one letter remains after parsing
        duration = [duration substringFromIndex:1];
        
        NSScanner *scanner = [[NSScanner alloc] initWithString:duration];
        
        NSString *durationPart = [[NSString alloc] init];
        [scanner scanCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] intoString:&durationPart];
        
        NSRange rangeOfDurationPart = [duration rangeOfString:durationPart];
        
        duration = [duration substringFromIndex:rangeOfDurationPart.location + rangeOfDurationPart.length];
        
        if ([[duration substringToIndex:1] isEqualToString:@"H"]) {
            hours = [durationPart intValue];
        }
        if ([[duration substringToIndex:1] isEqualToString:@"M"]) {
            minutes = [durationPart intValue];
        }
        if ([[duration substringToIndex:1] isEqualToString:@"S"]) {
            seconds = [durationPart intValue];
        }
    }
    
    return (hours * 3600) + (minutes * 60) + seconds;
}

- (NSInteger)uniqueAlbumIDForVideo
{
    NSString *uniqueString = [[NSProcessInfo processInfo] globallyUniqueString];
    
    // - to not overlap with itunes IDs
    return -[uniqueString hash];
}

@end
