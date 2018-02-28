//
//  BLYAlbumStore.m
//  Brown
//
//  Created by Jeremy Levy on 28/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import "BLYAlbumStore.h"
#import "BLYHTTPConnection.h"
#import "BLYPlaylist.h"
#import "BLYAlbum.h"
#import "NSString+Escaping.h"
#import "NSString+Sizing.h"
#import "BLYStore.h"

NSString * const BLYAlbumStoreServiceURLPattern = @"http://itunes.apple.com/lookup?id=%d&entity=song&country=%@";

@implementation BLYAlbumStore

+ (BLYAlbumStore *)sharedStore
{
    static BLYAlbumStore *albumStore = nil;
    
    if (!albumStore) {
        albumStore = [[BLYAlbumStore alloc] init];
    }
    
    return albumStore;
}

+ (NSURL *)URLForServiceToFetchAlbum:(int)albumSid forCountry:(NSString *)country
{
    country = [country bly_stringByAddingPercentEscapesForQuery];
    
    NSString *url = [NSString stringWithFormat:BLYAlbumStoreServiceURLPattern, albumSid, country];
    
    return [NSURL URLWithString:url];
}

- (BLYHTTPConnection *)fetchAlbum:(int)albumSid
                       forCountry:(NSString *)country
                   withCompletion:(void (^)(BLYAlbum *album, NSError *err))completionBlock
              andCompletionForImg:(void (^)(BOOL hasDownloaded, BLYAlbum *album))imgBlock
{
    // Prepare a request URL, including the argument from the controller
    NSURL *url = [BLYAlbumStore URLForServiceToFetchAlbum:albumSid forCountry:country];
    
    // Set up the connection as normal
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    
    // Set user agent to avoid null return
    [req setValue:@"Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; Trident/6.0)"
forHTTPHeaderField:@"User-Agent"];
    
    BLYHTTPConnection *connection = [[BLYHTTPConnection alloc] initWithRequest:req];
    
    __weak BLYAlbumStore *weakSelf = self;
    __block BOOL expired = NO;
    
    [connection setCompletionBlock:^(NSData *obj, NSError *err){
        if (expired) {
            return;
        }
        
        expired = true;
        
        BLYAlbum *album = nil;
        
        if (!err) {
            NSDictionary *returnedResults = [NSJSONSerialization JSONObjectWithData:obj options:0 error:nil];
            
            // > 1 : One entry for collection, one (or more) for songs
            if (returnedResults && [returnedResults[@"resultCount"] intValue] > 1) {
                
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
                    
                    BLYArtist *artist = [weakSelf insertArtistWithSid:[NSString stringWithFormat:@"%@", artistSid]
                                                            inCountry:country];
                    
                    BLYArtistSong *artistSong = [weakSelf insertArtistSongForArtist:artist
                                                                           withName:artistName];
                    
                    album = [weakSelf insertAlbumWithName:albumName
                                                      sid:[albumSid intValue]
                                                  country:country
                                             thumbnailURL:thumbnailURLAsString
                                           andReleaseDate:albumReleaseDate
                                            forArtistSong:artistSong
                                                  replace:YES];
                    
                    album.isFullyLoaded = [NSNumber numberWithBool:YES];
                    
                    [[BLYStore sharedStore] saveChanges];
                    
//                    [weakSelf loadThumbnailWithURL:thumbnailURL
//                                          forAlbum:album
//                               withCompletionBlock:^{
//                        imgBlock(album);
//                    }];
                    
                    break;
                }
                
                for (NSDictionary *result in returnedResults[@"results"]) {
                    
                    if (![result[@"wrapperType"] isEqualToString:@"track"]
                        || ![result[@"kind"] isEqualToString:@"song"]) {
                        continue;
                    }
                    
                    NSNumber *songSid = result[@"trackId"];
                    NSString *songTitle = result[@"trackCensoredName"];
                    
                    NSNumber *trackNumber = result[@"trackNumber"];
                    
                    NSString *artistName = result[@"artistName"];
                    NSNumber *artistSid = result[@"artistId"];
                    
                    BLYArtist *artist = [weakSelf insertArtistWithSid:[NSString stringWithFormat:@"%@", artistSid]
                                                            inCountry:country];
                    
                    BLYArtistSong *artistSong = [weakSelf insertArtistSongForArtist:artist
                                                                           withName:artistName];
                    
                    int trackNumberAsInt = [trackNumber intValue];
                    
                    [weakSelf insertSongWithTitle:songTitle
                                              sid:[NSString stringWithFormat:@"%@", songSid]
                                       artistSong:artistSong
                                         duration:0
                                   andRankInAlbum:trackNumberAsInt
                                         forAlbum:album];
                }
            }
        }
        
        [weakSelf loadThumbnailsForAlbums:@[album] withCompletionForAlbum:^(BOOL hasDownloaded, BLYAlbum *album) {
            imgBlock(hasDownloaded, album);
        } andCompletionBlock:nil];
        
        completionBlock(album, err);
    }];
    
    [connection start];
    
    [NSTimer scheduledTimerWithTimeInterval:8.0 repeats:NO block:^(NSTimer * _Nonnull timer) {
        if (expired) {
            return;
        }
        
        expired = true;
        
        BLYAlbum *album = nil;
        
        completionBlock(album, [[BLYStore sharedStore] timeoutError]);
    }];
    
    return connection;
}

- (void)updatePlayedAtForAlbum:(BLYAlbum *)album
{
    [album setPlayedAt:[NSDate date]];
    
    [[BLYStore sharedStore] saveChanges];
}

@end
