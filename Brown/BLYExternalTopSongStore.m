//
//  BLYExternalTopTracksStore.m
//  Brown
//
//  Created by Jeremy Levy on 19/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "BLYExternalTopSongStore.h"
#import "BLYHTTPConnection.h"
#import "BLYPlaylist.h"
#import "BLYSong.h"
#import "BLYVideo.h"
#import "BLYExternalTopSongCountry.h"
#import "BLYAlbum.h"
#import "BLYArtist.h"
#import "BLYExternalTopSong.h"
#import "BLYStore.h"
#import "NSString+Escaping.h"
#import "NSString+Sizing.h"
#import "BLYNetworkStore.h"
#import "BLYVideoStore.h"
#import "BLYAppDelegate.h"
#import "BLYAppSettingsStore.h"

NSString * const BLYExternalTopSongsStoreServiceURLPattern = @"https://rss.itunes.apple.com/api/v1/%@/itunes-music/top-songs/all/%d/explicit.json";
NSString * const BLYExternalTopSongsStoreYouTubeURLPattern = @"https://www.googleapis.com/youtube/v3/playlistItems?part=id,snippet&key=%@&playlistId=%@&maxResults=%d";
//NSString * const BLYExternalTopSongsStoreYouTubeURLPattern = @"https://app-7d6f71f6-b0cd-47aa-9f16-7de290b81ef0.cleverapps.io/playlist?id=%@&limit=%d";

const int BLYExternalTopSongsStoreCacheDuration = 2 * 24 * 3600; // In seconds (two days)

@implementation BLYExternalTopSongStore

+ (BLYExternalTopSongStore *)sharedStore
{
    static BLYExternalTopSongStore *externalTopSongStore = nil;
    
    if (!externalTopSongStore) {
        externalTopSongStore = [[BLYExternalTopSongStore alloc] init];
    }
    
    return externalTopSongStore;
}

+ (NSURL *)URLForServiceToFetchForCountry:(NSString *)country limit:(int)limit
{
    NSString *url = nil;
    
    country = [country bly_stringByAddingPercentEscapesForQuery];
    
    if ([country isEqualToString:@"youtube"]) {
        BLYAppDelegate *appDelegate = (BLYAppDelegate *)[[UIApplication sharedApplication] delegate];
        
        country = [[appDelegate countryCodeForCurrentLocale] bly_stringByAddingPercentEscapesForQuery];
        
        url = [NSString stringWithFormat:BLYExternalTopSongsStoreYouTubeURLPattern, BLYVideoStoreYoutubeApiKey, @"PLFgquLnL59ak5FwmTB7DRJqX3M2B1D7xI", limit];
    } else {
        url = [NSString stringWithFormat:BLYExternalTopSongsStoreServiceURLPattern, country, limit];
    }
    
    return [NSURL URLWithString:url];
}

- (NSArray *)externalTopSongCountries
{
    BLYStore *store = [BLYStore sharedStore];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [store.model.entitiesByName objectForKey:@"BLYExternalTopSongCountry"];
    NSError *err = nil;
    
    request.entity = entity;
    
    NSArray *results = [store.context executeFetchRequest:request error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", err.localizedDescription];
    }
    
    return results;
}

- (BLYExternalTopSongCountry *)externalTopSongsForCountry:(NSString *)country
{
    BLYStore *store = [BLYStore sharedStore];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [store.model.entitiesByName objectForKey:@"BLYExternalTopSongCountry"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name = %@", country];
    NSError *err = nil;
    
    request.entity = entity;
    request.predicate = predicate;
    
    NSArray *results = [store.context executeFetchRequest:request error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", err.localizedDescription];
    }
    
    return [results count] > 0 ? [results objectAtIndex:0] : nil;
}

- (void)cleanExternalTopSongsForCountry:(NSString *)country
{
    BLYStore *store = [BLYStore sharedStore];
    BLYExternalTopSongCountry *topSongsForCountry = [self externalTopSongsForCountry:country];
    
    if (!topSongsForCountry) {
        return;
    }
    
    for (BLYExternalTopSong *song in topSongsForCountry.songs) {
        [store deleteObject:song];
    }
    
    [store saveChanges];
}

- (BLYExternalTopSongCountry *)insertExternalTopSongCountryWithName:(NSString *)name
{
    BLYStore *store = [BLYStore sharedStore];
    BLYExternalTopSongCountry *externalTopSongCountry = [NSEntityDescription insertNewObjectForEntityForName:@"BLYExternalTopSongCountry"
                                                                                      inManagedObjectContext:store.context];
    
    externalTopSongCountry.name = name;
    
    return externalTopSongCountry;
}

- (BLYExternalTopSong *)insertSong:(BLYSong *)song
                          withRank:(int)rank
                        forCountry:(BLYExternalTopSongCountry *)country
{
    BLYStore *store = [BLYStore sharedStore];
    BLYExternalTopSong *topSong = [NSEntityDescription insertNewObjectForEntityForName:@"BLYExternalTopSong"
                                                                inManagedObjectContext:store.context];
    
    topSong.rank = [NSNumber numberWithInt:rank];
    topSong.country = country;
    topSong.song = song;
    
    [self insertExternalTopSong:topSong forCountry:country];
    
    [song addExternalTopSongsObject:topSong];
    
    return topSong;
}

- (void)insertExternalTopSong:(BLYExternalTopSong *)topSong
                   forCountry:(BLYExternalTopSongCountry *)country
{
    NSMutableSet *topSongs = [country.songs mutableCopy];
    
    if (![topSongs containsObject:topSong]) {
        [topSongs addObject:topSong];
    }
    
    country.songs = [topSongs copy];
}

- (void)sortSongOfPlaylist:(BLYPlaylist *)playlist
{
    NSMutableArray *playlistSongs = playlist.songs;
    NSMutableArray *songsToSetInPlaylist = [[NSMutableArray alloc] init];
    NSSortDescriptor *sd = [NSSortDescriptor sortDescriptorWithKey:@"rank" ascending:YES];
    
    [playlistSongs sortUsingDescriptors:@[sd]];
    
    for (BLYExternalTopSong *topSong in playlistSongs) {
        if (!topSong.song) {
            continue;
        }
        
        [songsToSetInPlaylist addObject:topSong.song];
    }
    
    playlist.songs = songsToSetInPlaylist;
}

- (void)fetchTopSongsForCountry:(NSString *)country
                          limit:(int)count
                          force:(BOOL)force
                 withCompletion:(void (^)(BLYPlaylist *obj, NSError *err))block
            andCompletionForImg:(void (^)(BOOL hasDownloaded, BLYSong *song))imgBlock
{
//    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
//    BOOL firstLoad = [defaults boolForKey:BLYStoreFirstLoadUserDefaultsKey];
//
    // Update "updated at" for all countries at first app launch
//    if (firstLoad) {
//        NSArray *countries = [self externalTopSongCountries];
//
//        for (BLYExternalTopSongCountry *externalTopSongCountry in countries) {
//            externalTopSongCountry.updatedAt = [NSDate date];
//        }
//
//        [[BLYStore sharedStore] saveChanges];
//
//        [defaults setBool:NO forKey:BLYStoreFirstLoadUserDefaultsKey];
//    }
    
    BLYExternalTopSongCountry *topSongCountry = [self externalTopSongsForCountry:country];
    
    if (!force) {
        if (topSongCountry) {
            // How old is the cache?
            NSTimeInterval cacheAge = [topSongCountry.updatedAt timeIntervalSinceNow];
            
            BLYPlaylist *playlist = [[BLYPlaylist alloc] init];
            
            NSArray *songsAsArray = [topSongCountry.songs allObjects];
            NSMutableArray *songs = [songsAsArray mutableCopy];
            
            playlist.songs = songs;
            
            [self sortSongOfPlaylist:playlist];
            
            // Display top songs even if cache is begin updating (prevent empty table view...)
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                block(playlist, nil);
            }];
            
            // block(playlist, nil);
            
            return;
            
            if ((cacheAge > - BLYExternalTopSongsStoreCacheDuration
                 || ![[BLYNetworkStore sharedStore] networkIsReachable])
                && [topSongCountry.songs count] == count) {
                
                // Don't need to make the request, just get out of this method
                return;
            }
            
            if (![[BLYNetworkStore sharedStore] networkIsReachableViaWifi]
                && [[BLYAppSettingsStore sharedStore] boolForSetting:BLYAppSettingsStoreForbidUcachedSongsListeningSetting]) {
                
                return;
            }
        } else {
            topSongCountry = [self insertExternalTopSongCountryWithName:country];
        }
    }
    
    __weak BLYExternalTopSongStore *weakSelf = self;
    __block BOOL expired = NO;
    
    void(^completionBlock)(NSData *obj, NSError *err) = ^(NSData *obj, NSError *err){
        if (expired) {
            return;
        }
        
        expired = true;
        
        BLYPlaylist *playlist = [[BLYPlaylist alloc] init];
        
        if (!err) {
            NSDictionary *d = [NSJSONSerialization JSONObjectWithData:obj options:0 error:nil];
            NSDictionary *feed = [d objectForKey:@"feed"];
            NSArray *songs = [feed objectForKey:@"results"];
            int rank = 0;
            
            if ([songs count] > 0) {
                [weakSelf cleanExternalTopSongsForCountry:country];
            }
            
            for (NSDictionary *song in songs) {
                rank++;
                
                NSString *albumName = song[@"collectionName"];
                
                NSString *albumSid = @"0";
                NSString *albumURL = song[@"url"];
                NSRegularExpression *albumSidReg = [[NSRegularExpression alloc] initWithPattern:@"/([0-9]+)"
                                                                                        options:NSRegularExpressionCaseInsensitive
                                                                                          error:nil];
                NSArray *matchesAlbumSid = [[NSArray alloc] init];
                
                if (albumURL) {
                    matchesAlbumSid = [albumSidReg matchesInString:albumURL
                                                           options:0
                                                             range:[albumURL bly_fullRange]];
                }
                
                if ([matchesAlbumSid count] > 0) {
                    NSTextCheckingResult *resultAlbumSid = [matchesAlbumSid objectAtIndex:0];
                    
                    if ([resultAlbumSid numberOfRanges] >= 2) {
                        albumSid = [albumURL substringWithRange:[resultAlbumSid rangeAtIndex:1]];
                    }
                }
                
                NSString *albumReleaseDateAsString = song[@"releaseDate"];
                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                
                [dateFormatter setDateFormat:@"yyyy-MM-dd"];
                
                NSDate *albumReleaseDate = [dateFormatter dateFromString:albumReleaseDateAsString];
                
                NSString *songSid = song[@"id"];
                NSString *songTitle = song[@"name"];
                NSString *artistName = song[@"artistName"];
                
                NSString *artistSid = @"0";
                NSString *artistURL = song[@"artistUrl"];
                
                NSRegularExpression *artistSidReg = [[NSRegularExpression alloc] initWithPattern:@"/([0-9]+)"
                                                                                        options:NSRegularExpressionCaseInsensitive error:nil];
                
                NSArray *matchesArtistSid = [artistSidReg matchesInString:artistURL ? artistURL : @"0"
                                                                  options:0
                                                                    range:[artistURL bly_fullRange]];
                
                if ([matchesArtistSid count] > 0) {
                    NSTextCheckingResult *resultArtistSid = [matchesArtistSid objectAtIndex:0];
                    
                    if ([resultArtistSid numberOfRanges] >= 2) {
                        artistSid = [artistURL substringWithRange:[resultArtistSid rangeAtIndex:1]];
                    }
                }
                
                NSMutableString *thumbnailURLAsString = [song[@"artworkUrl100"] mutableCopy];
                
                [thumbnailURLAsString replaceOccurrencesOfString:@"200x200"
                                                      withString:@"225x225"
                                                         options:NSCaseInsensitiveSearch
                                                           range:[thumbnailURLAsString bly_fullRange]];
                
                BLYArtist *artist = [weakSelf insertArtistWithSid:artistSid
                                                        inCountry:country];
                
                BLYArtistSong *artistSong = [weakSelf insertArtistSongForArtist:artist
                                                                       withName:artistName];
                
                BLYAlbum *album = [weakSelf insertAlbumWithName:albumName
                                                            sid:[albumSid intValue]
                                                        country:country
                                                   thumbnailURL:thumbnailURLAsString
                                                 andReleaseDate:albumReleaseDate
                                                  forArtistSong:artistSong
                                                        replace:NO];
                
                BLYSong *song = [weakSelf insertSongWithTitle:songTitle
                                                          sid:songSid
                                                   artistSong:artistSong
                                                     duration:0
                                               andRankInAlbum:0
                                                     forAlbum:album];
                
                BLYExternalTopSong *externalTopSong = [weakSelf insertSong:song
                                                                  withRank:rank
                                                                forCountry:topSongCountry];
                
                [playlist addSong:externalTopSong];
                
//                    [weakSelf loadThumbnailWithURL:thumbnailURL
//                                          forAlbum:album
//                               withCompletionBlock:^{
//                                   dispatch_async(dispatch_get_main_queue(), ^(void) {
//                                       imgBlock();
//                                   });
//                               }];
            }
        }
        
        [self sortSongOfPlaylist:playlist];
        
        [weakSelf loadThumbnailsForPlaylist:playlist withCompletionForSong:^(BOOL hasDownloaded, BLYSong *s){
            imgBlock(hasDownloaded, s);
        } andCompletionBlock:nil];
        
        block(playlist, err);
    };
    
    void(^completionBlockForYouTube)(NSData *obj, NSError *err) = ^(NSData *obj, NSError *err){
        if (expired) {
            return;
        }
        
        expired = true;
        
        BLYPlaylist *playlist = [[BLYPlaylist alloc] init];
        
        if (!err) {
            NSDictionary *returnedResults = [NSJSONSerialization JSONObjectWithData:obj options:0 error:nil];
            NSMutableArray *videoIDs = [[NSMutableArray alloc] init];
            
            if (returnedResults && returnedResults[@"pageInfo"][@"totalResults"] > 0) {
                for (NSDictionary *result in returnedResults[@"items"]) {
                    [videoIDs addObject:result[@"snippet"][@"resourceId"][@"videoId"]];
                }
                
                NSURL *url = [BLYVideoStore URLForServiceToLookupVideosWithIDs:videoIDs
                                                                     withParts:@"id,snippet,contentDetails"];
                
                NSURLRequest *req = [NSURLRequest requestWithURL:url];
                
                BLYHTTPConnection *connection = [[BLYHTTPConnection alloc] initWithRequest:req];
                __block BOOL expired2 = NO;
                
                connection.completionBlock = ^(NSData *obj, NSError *err) {
                    if (expired2) {
                        return;
                    }
                    
                    expired2 = true;
                    
                    if (!err) {
                        NSDictionary *returnedResults = [NSJSONSerialization JSONObjectWithData:obj options:0 error:nil];
                        
                        int rank = 0;
                        
                        if (returnedResults && returnedResults[@"pageInfo"][@"totalResults"] > 0) {
                            [weakSelf cleanExternalTopSongsForCountry:country];
                            
                            for (NSDictionary *result in returnedResults[@"items"]) {
                                rank++;
                                
                                NSString *albumName = @"";
                                NSNumber *albumSid = [NSNumber numberWithInt:[[BLYVideoStore sharedStore] uniqueAlbumIDForVideo]];
                                
                                NSString *albumReleaseDateAsString = [result[@"snippet"][@"publishedAt"] substringToIndex:10];
                                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                                
                                [dateFormatter setDateFormat:@"yyyy-MM-dd"];
                                
                                NSDate *albumReleaseDate = [dateFormatter dateFromString:albumReleaseDateAsString];
                                
                                NSString *songSid = result[@"id"];
                                NSString *songTitle = result[@"snippet"][@"title"];
                                
                                NSNumber *trackNumber = [NSNumber numberWithInt:1];
                                int trackDuration = [BLYVideoStore durationFromISO8601Time:result[@"contentDetails"][@"duration"]] ;
                                
                                NSString *artistName = result[@"snippet"][@"channelTitle"];
                                NSString *artistSid = result[@"snippet"][@"channelId"];
                                
                                // Fix YouTube API Bug
                                if ([artistName isEqualToString:@""]) {
                                    artistName = @"Unknown";
                                }
                                
                                NSMutableString *thumbnailURLAsString = [result[@"snippet"][@"thumbnails"][@"high"][@"url"] mutableCopy];
                                
                                BLYArtist *artist = [weakSelf insertArtistWithSid:artistSid
                                                              andIsYoutubeChannel:YES
                                                                        inCountry:country];
                                
                                BLYArtistSong *artistSong = [weakSelf insertArtistSongForArtist:artist
                                                                                       withName:artistName
                                                                                  andIsRealName:YES];
                                
                                BLYAlbum *album = [weakSelf insertAlbumWithName:albumName
                                                                            sid:[albumSid intValue]
                                                                        country:country
                                                                   thumbnailURL:thumbnailURLAsString
                                                                 andReleaseDate:albumReleaseDate
                                                                  forArtistSong:artistSong
                                                                        replace:NO];
                                
                                BLYSong *song = [weakSelf insertSongWithTitle:songTitle
                                                                          sid:songSid
                                                                   artistSong:artistSong
                                                                     duration:trackDuration
                                                                      isVideo:YES
                                                               andRankInAlbum:[trackNumber intValue] * 1000
                                                                     forAlbum:album];
                                
                                BLYExternalTopSong *externalTopSong = [weakSelf insertSong:song
                                                                                  withRank:rank
                                                                                forCountry:topSongCountry];
                                
                                [playlist addSong:externalTopSong];
                                
                                //                        [weakSelf loadThumbnailWithURL:thumbnailURL
                                //                                              forAlbum:album
                                //                                   withCompletionBlock:^{
                                //                                       dispatch_async(dispatch_get_main_queue(), ^(void) {
                                //                                           imgBlock();
                                //                                       });
                                //                                   }];
                            }
                        }
                    }
                    
                    [self sortSongOfPlaylist:playlist];
                    
                    [weakSelf loadThumbnailsForPlaylist:playlist withCompletionForSong:^(BOOL hasDownloaded, BLYSong *s){
                        imgBlock(hasDownloaded, s);
                    } andCompletionBlock:nil];
                    
                    block(playlist, err);
                };
                
                [connection start];
                
                [NSTimer scheduledTimerWithTimeInterval:8.0 repeats:NO block:^(NSTimer * _Nonnull timer) {
                    if (expired2) {
                        return;
                    }
                    
                    expired2 = true;
                    
                    BLYPlaylist *playlist = [[BLYPlaylist alloc] init];
                    
                    block(playlist, [[BLYStore sharedStore] timeoutError]);
                }];
            } else {
                block(playlist, err);
            }
        } else {
            block(playlist, err);
        }
    };
    
    topSongCountry.updatedAt = [NSDate date];
    
    // Prepare a request URL, including the argument from the controller
    NSURL *url = [BLYExternalTopSongStore URLForServiceToFetchForCountry:country
                                                                   limit:count];
    
    // Set up the connection as normal
    NSURLRequest *req = [NSURLRequest requestWithURL:url];
    
    BLYHTTPConnection *connection = [[BLYHTTPConnection alloc] initWithRequest:req];
    
    if ([country isEqualToString:@"youtube"]) {
        connection.completionBlock = completionBlockForYouTube;
    } else {
        connection.completionBlock = completionBlock;
    }
    
    [connection start];
    
    [NSTimer scheduledTimerWithTimeInterval:8.0 repeats:NO block:^(NSTimer * _Nonnull timer) {
        if (expired) {
            return;
        }
        
        expired = true;
        
        BLYPlaylist *playlist = [[BLYPlaylist alloc] init];
        
        block(playlist, [[BLYStore sharedStore] timeoutError]);
    }];
}

@end
