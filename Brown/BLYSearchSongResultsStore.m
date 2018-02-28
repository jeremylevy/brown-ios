//
//  BLYSearchSongResultsStore.m
//  Brown
//
//  Created by Jeremy Levy on 02/10/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import "BLYSearchSongResultsStore.h"
#import "BLYHTTPConnection.h"
#import "BLYPlaylist.h"
#import "BLYAlbum.h"
#import "BLYArtist.h"
#import "BLYArtistSong.h"
#import "BLYSong.h"
#import "NSString+Escaping.h"
#import "NSString+Sizing.h"
#import "NSString+Matching.h"
#import "NSString+Levenshtein.h"
#import "BLYStore.h"
#import "BLYSearchSongResultsViewController.h"
#import "BLYTimeManager.h"
#import "NSString+Levenshtein.h"

NSString * const BLYSearchSongResultsStoreServiceURLPattern = @"https://itunes.apple.com/search?term=%@&media=music&entity=song&country=%@&limit=100";
NSString * const BLYSearchSongResultsStoreAlbumsSearchURLPattern = @"https://itunes.apple.com/search?term=%@&media=music&entity=album&country=%@&limit=100&sort=recent";
NSString * const BLYSearchSongResultsStoreArtistSearchURLPattern = @"https://itunes.apple.com/lookup?id=%d&entity=song&country=%@&limit=60";
NSString * const BLYSearchSongResultsStoreAlbumsLookupURLPattern = @"https://itunes.apple.com/lookup?id=%d&entity=album&country=%@&limit=100&sort=recent";

@interface BLYSearchSongResultsStore ()

@end

@implementation BLYSearchSongResultsStore

+ (BLYSearchSongResultsStore *)sharedStore
{
    static BLYSearchSongResultsStore *resultsStore = nil;
    
    if (!resultsStore) {
        resultsStore = [[BLYSearchSongResultsStore alloc] init];
    }
    
    return resultsStore;
}

- (id)init
{
    self = [super init];
    
    if (self) {
        
    }
    
    return self;
}

+ (NSURL *)URLForServiceToFetchForCountry:(NSString *)country withQuery:(NSString *)query
{
    country = [country bly_stringByAddingPercentEscapesForQuery];
    
    query = [BLYSearchSongResultsStore stringByRemovingNoiseForSongSearchWithQuery:query];
    query = [query stringByReplacingOccurrencesOfString:@" " withString:@"+"];
    //query = [query bly_stringByAddingPercentEscapes];
    
    NSString *url = [NSString stringWithFormat:BLYSearchSongResultsStoreServiceURLPattern, query, country];
    
    return [NSURL URLWithString:url];
}

+ (NSString *)stringByRemovingNoiseForSongSearchWithQuery:(NSString *)query
{
    NSArray *noise = @[@"clip", @"clip officiel", @"official video", @"official music video", @"paroles", @"paroles français", @"paroles traductions", @"paroles karaoké", @"paroles karaoke", @"paroles françaises", @"lyrics", @"lyrics karaoke", @"karaoke", @"traduction", @"traduction francaise", @"traduction française", @"live", @"piano tutorial", @"vevo", @"chipmunks", @"chipmunk", @"feat", @"featuring", @"ft\\.", @"\\sft(?=\\s)", @"official", @"officiel", @"\\salbum complet", @"\\sfull album"];
    NSString *noisePattern = [noise componentsJoinedByString:@"|"];
    
    query = [query bly_stringByReplacingPattern:noisePattern withString:@""];
    
    return [query bly_stringByReplacingMultipleConsecutiveSpacesToOne];
}

+ (NSURL *)URLForServiceToFetchAlbumsForCountry:(NSString *)country withQuery:(NSString *)query
{
    country = [country bly_stringByAddingPercentEscapesForQuery];
    
    query = [BLYSearchSongResultsStore stringByRemovingNoiseForSongSearchWithQuery:query];
    query = [query stringByReplacingOccurrencesOfString:@" " withString:@"+"];
    //query = [query bly_stringByAddingPercentEscapes];
    
    NSString *url = [NSString stringWithFormat:BLYSearchSongResultsStoreAlbumsSearchURLPattern, query, country];
    
    return [NSURL URLWithString:url];
}

+ (NSURL *)URLForServiceToFetchSongsForArtist:(int)artistSid andCountry:(NSString *)country
{
    country = [country bly_stringByAddingPercentEscapesForQuery];
    
    NSString *url = [NSString stringWithFormat:BLYSearchSongResultsStoreArtistSearchURLPattern, artistSid, country];
    
    return [NSURL URLWithString:url];
}

+ (NSURL *)URLForServiceToFetchAlbumsForArtist:(int)artistSid andCountry:(NSString *)country
{
    country = [country bly_stringByAddingPercentEscapesForQuery];
    
    NSString *url = [NSString stringWithFormat:BLYSearchSongResultsStoreAlbumsLookupURLPattern, artistSid, country];
    
    return [NSURL URLWithString:url];
}

- (void)fetchSearchResultsForCountry:(NSString *)country
                           withQuery:(NSString *)query
                            orArtist:(BLYArtist *)artist
                       andCompletion:(void (^)(NSMutableDictionary *results, NSError *err))block
                 andCompletionForImg:(void (^)(BOOL hasDownloaded, BLYSong *song))imgBlock
{
    // Prepare a request URL, including the argument from the controller
    NSURL *url = nil;

    if (artist) {
        if ([artist.isYoutubeChannel boolValue]) {
            return;
        }
        
        url = [BLYSearchSongResultsStore URLForServiceToFetchSongsForArtist:[artist.sid intValue]
                                                                 andCountry:artist.country];
    }
    
    if (!url) {
        url = [BLYSearchSongResultsStore URLForServiceToFetchForCountry:country
                                                              withQuery:query];
    }
    
    // Set up the connection as normal
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    
    // Set user agent to avoid null return
    [req setValue:@"Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; Trident/6.0)"
forHTTPHeaderField:@"User-Agent"];
    
    BLYHTTPConnection *connection = [[BLYHTTPConnection alloc] initWithRequest:req];
    
    __weak BLYSearchSongResultsStore *weakSelf = self;
    __block BOOL expired = NO;
    
    [connection setCompletionBlock:^(NSData *obj, NSError *err) {
        if (expired) {
            return;
        }
        
        expired = true;
        
        NSMutableDictionary *results = [[NSMutableDictionary alloc] init];
        BLYPlaylist *playlist = [[BLYPlaylist alloc] init];
        
        if (!err) {
            NSDictionary *returnedResults = [NSJSONSerialization JSONObjectWithData:obj options:0 error:nil];
            
            if (returnedResults && returnedResults[@"resultCount"] > 0) {
                NSMutableArray *resultTitles = [[NSMutableArray alloc] init];
                
                for (NSDictionary *result in returnedResults[@"results"]) {
                    NSString *albumName = result[@"collectionCensoredName"];
                    NSNumber *albumSid = result[@"collectionId"];
                    
                    NSString *albumReleaseDateAsString = [result[@"releaseDate"] substringToIndex:10];
                    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                    
                    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
                    
                    NSDate *albumReleaseDate = [dateFormatter dateFromString:albumReleaseDateAsString];
                    
                    NSNumber *songSid = result[@"trackId"];
                    NSString *songTitle = result[@"trackCensoredName"];
                    
                    NSNumber *trackNumber = result[@"trackNumber"];
                    
                    NSString *artistName = result[@"artistName"];
                    NSNumber *artistSid = result[@"artistId"];
                    
                    NSMutableString *thumbnailURLAsString = [result[@"artworkUrl100"] mutableCopy];
                    
                    [thumbnailURLAsString replaceOccurrencesOfString:@"100x100"
                                                          withString:@"225x225"
                                                             options:NSCaseInsensitiveSearch
                                                               range:[thumbnailURLAsString bly_fullRange]];
                    
                    NSURL *thumbnailURL = [NSURL URLWithString:thumbnailURLAsString];
                    NSString *cleanSongTitle = [songTitle lowercaseString];
                    // NSString *cleanSongTitle = [[songTitle lowercaseString] bly_stringByRemovingParenthesisAndBracketsContent];
                    
                    // Lookup by player VC
                    if ([result[@"wrapperType"] isEqualToString:@"artist"]) {
                        NSNumber *artistSid = result[@"artistId"];
                        NSString *artistName = result[@"artistName"];
                        
                        BLYArtist *artist = [weakSelf insertArtistWithSid:[NSString stringWithFormat:@"%@", artistSid]
                                                                inCountry:country];
                        
                        [weakSelf insertArtistSongForArtist:artist
                                                   withName:artistName
                                              andIsRealName:YES];
                        
                        continue;
                    }
                    
                    cleanSongTitle = [cleanSongTitle bly_stringByRemovingAccents];
                    
                    if ([resultTitles containsObject:cleanSongTitle]) {
                        continue;
                    }
                    
                    [resultTitles addObject:cleanSongTitle];
                    
                    BLYArtist *artist = [weakSelf insertArtistWithSid:[NSString stringWithFormat:@"%@", artistSid]
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
                                                              sid:[NSString stringWithFormat:@"%@", songSid]
                                                       artistSong:artistSong
                                                         duration:0
                                                   andRankInAlbum:[trackNumber intValue]
                                                         forAlbum:album];
                    
                    [playlist addSong:song];
                    
//                    [weakSelf loadThumbnailWithURL:thumbnailURL
//                                          forAlbum:album
//                               withCompletionBlock:^{
//                                   imgBlock();
//                               }];
                
                }
            }
        }
        
        // Single search with results from different albums
        // Keep only one song
//        if ([playlist nbOfSongs] > 1) {
//            NSMutableArray *scores = [[NSMutableArray alloc] init];
//            
//            for (BLYSong *song in playlist.songs) {
//                BLYSong *firstSong = [playlist songAtIndex:0];
//                NSString *firstSongTitle = [firstSong.title bly_stringByRemovingNonAlphanumericCharacters];
//                
//                NSString *songTitle = [song.title bly_stringByRemovingNonAlphanumericCharacters];
//                float score = [songTitle compareWithString:firstSongTitle];
//                
//                [scores addObject:[NSNumber numberWithFloat:score]];
//            }
//            
//            NSNumber *scoreAverage = [scores valueForKeyPath:@"@avg.self"];
//            
//            if ([scoreAverage floatValue] <= 2.8) {
//                playlist.songs = [NSMutableArray arrayWithObject:[playlist songAtIndex:0]];
//            }
//        }
        
        if ([playlist nbOfSongs] > 1) {
            NSMutableArray *albumsSid = [[NSMutableArray alloc] init];
            BOOL sameAlbumMultipleTimes = NO;
            
            for (BLYSong *song in playlist.songs) {
                if ([albumsSid containsObject:song.album.sid]) {
                    sameAlbumMultipleTimes = YES;
                    break;
                }
                
                [albumsSid addObject:song.album.sid];
            }
            
            if (!sameAlbumMultipleTimes) {
                playlist.songs = [NSMutableArray arrayWithObject:[playlist songAtIndex:0]];
            }
        }
        
        [weakSelf loadThumbnailsForPlaylist:playlist withCompletionForSong:^(BOOL hasDownloaded, BLYSong *s){
            imgBlock(hasDownloaded, s);
        } andCompletionBlock:nil];
        
        results[@"playlist"] = playlist;
        
        block(results, err);
    }];
    
    [connection start];
    
    [NSTimer scheduledTimerWithTimeInterval:8.0 repeats:NO block:^(NSTimer * _Nonnull timer) {
        if (expired) {
            return;
        }
        
        expired = true;
        
        NSMutableDictionary *results = [[NSMutableDictionary alloc] init];
        BLYPlaylist *playlist = [[BLYPlaylist alloc] init];
        
        results[@"playlist"] = playlist;
        
        block(results, [[BLYStore sharedStore] timeoutError]);
    }];
    
    if (!self.searchSongResultsVC) {
        return;
    }
    
    self.searchSongResultsVC.launchedConnection = connection;
}

- (BLYHTTPConnection *)fetchAlbumsForArtist:(int)artistSid
                                   orSearch:(NSString *)search
                                 andCountry:(NSString *)country
                             withCompletion:(void (^)(NSMutableArray *results, NSError *err))completionBlock
                        andCompletionForImg:(void (^)(BOOL hasDownloaded, BLYAlbum *album))imgBlock
{
    NSURL *url = nil;
    
    if (artistSid) {
        url = [BLYSearchSongResultsStore URLForServiceToFetchAlbumsForArtist:artistSid andCountry:country];
    } else {
        url = [BLYSearchSongResultsStore URLForServiceToFetchAlbumsForCountry:country withQuery:search];
    }
    
    // Set up the connection as normal
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    
    // Set user agent to avoid null return
    [req setValue:@"Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; Trident/6.0)"
forHTTPHeaderField:@"User-Agent"];
    
    BLYHTTPConnection *connection = [[BLYHTTPConnection alloc] initWithRequest:req];
    
    __weak BLYSearchSongResultsStore *weakSelf = self;
    __block BOOL expired = NO;
    
    [connection setCompletionBlock:^(NSData *obj, NSError *err) {
        if (expired) {
            return;
        }
        
        expired = true;
        
        NSMutableArray *albums = [[NSMutableArray alloc] init];
        
        if (!err) {
            NSDictionary *returnedResults = [NSJSONSerialization JSONObjectWithData:obj options:0 error:nil];
            
            if (returnedResults && returnedResults[@"resultCount"] > 0) {
                NSMutableArray *resultNames = [[NSMutableArray alloc] init];
                
                for (NSDictionary *result in returnedResults[@"results"]) {
                    if (![result[@"wrapperType"] isEqualToString:@"collection"]) {
                        continue;
                    }
                    
                    NSString *albumName = result[@"collectionCensoredName"];
                    NSNumber *albumSid = result[@"collectionId"];
                    
                    NSString *albumReleaseDateAsString = [result[@"releaseDate"] substringToIndex:10];
                    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                    
                    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
                    
                    NSDate *albumReleaseDate = [dateFormatter dateFromString:albumReleaseDateAsString];
                    
                    NSString *artistName = result[@"artistName"];
                    NSNumber *artistSid = result[@"artistId"];
                    
                    NSMutableString *thumbnailURLAsString = [result[@"artworkUrl100"] mutableCopy];
                    
                    [thumbnailURLAsString replaceOccurrencesOfString:@"100x100"
                                                          withString:@"225x225"
                                                             options:NSCaseInsensitiveSearch
                                                               range:[thumbnailURLAsString bly_fullRange]];
                    
                    NSURL *thumbnailURL = [NSURL URLWithString:thumbnailURLAsString];
                    
                    if ([resultNames containsObject:albumName]) {
                        continue;
                    }
                    
                    [resultNames addObject:albumName];
                    
                    BLYArtist *artist = [weakSelf insertArtistWithSid:[NSString stringWithFormat:@"%@", artistSid]
                                                            inCountry:country];
                    
                    BLYArtistSong *artistSong = [weakSelf insertArtistSongForArtist:artist
                                                                           withName:artistName];
                    
                    BLYAlbum *album = [weakSelf insertAlbumWithName:albumName
                                                                sid:[albumSid intValue]
                                                            country:country
                                                       thumbnailURL:thumbnailURLAsString
                                                     andReleaseDate:albumReleaseDate
                                                      forArtistSong:artistSong
                                                            replace:YES];
                    
                    [albums addObject:album];
                    
//                    [weakSelf loadThumbnailWithURL:thumbnailURL
//                                          forAlbum:album
//                               withCompletionBlock:^{
//                                   imgBlock();
//                               }];
                }
            }
            
            // Remove single albums
            NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *bindings){
                BLYAlbum *album = obj;
                
                return ![album.isASingle boolValue];
            }];
            
            NSMutableArray *originalAlbums = [albums mutableCopy];
            
            [albums filterUsingPredicate:predicate];
            
            if ([albums count] == 0 && [originalAlbums count] > 0) {
                albums = originalAlbums;
            }
            
            NSMutableArray *albumsWithDeluxeVersion = [[NSMutableArray alloc] init];
            NSString *deluxeAlbumPattern = @"\\(.*deluxe.*\\)";
            
            for (BLYAlbum *album in albums) {
                if ([album.name bly_match:deluxeAlbumPattern]) {
                    NSString *originalAlbumName = [album.name bly_stringByRemovingParenthesisAndBracketsContent];
                    
                    if ([albumsWithDeluxeVersion indexOfObject:originalAlbumName] != NSNotFound) {
                        continue;
                    }
                    
                    [albumsWithDeluxeVersion addObject:originalAlbumName];
                }
            }
            
            // Remove non-deluxe versions
            predicate = [NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *bindings){
                BLYAlbum *album = obj;
                
                if (![album.name bly_match:deluxeAlbumPattern] && [albumsWithDeluxeVersion indexOfObject:[album.name bly_stringByRemovingParenthesisAndBracketsContent]] != NSNotFound) {
                    
                    return false;
                }
                
                return true;
            }];
            
            [albums filterUsingPredicate:predicate];
        }
        
        [weakSelf loadThumbnailsForAlbums:albums withCompletionForAlbum:^(BOOL hasDownloaded, BLYAlbum *a){
            imgBlock(hasDownloaded, a);
        } andCompletionBlock:nil];
        
        completionBlock(albums, err);
    }];
    
    [connection start];
    
    [NSTimer scheduledTimerWithTimeInterval:8.0 repeats:NO block:^(NSTimer * _Nonnull timer) {
        if (expired) {
            return;
        }
        
        expired = true;
        
        NSMutableArray *albums = [[NSMutableArray alloc] init];
        
        completionBlock(albums, [[BLYStore sharedStore] timeoutError]);
    }];
    
    return connection;
}

@end
