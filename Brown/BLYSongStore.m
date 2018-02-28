//
//  BLYSongStore.m
//  Brown
//
//  Created by Jeremy Levy on 29/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "BLYSongStore.h"
#import "BLYArtist.h"
#import "BLYArtistSong.h"
#import "BLYAlbum.h"
#import "BLYAlbum+Thumbnail.h"
#import "BLYSong.h"
#import "BLYStore.h"
#import "BLYPlayerViewController.h"
#import "BLYPlaylist.h"
#import "BLYAlbumThumbnail.h"
#import "NSString+Sizing.h"
#import "NSString+Matching.h"

@interface BLYSongStore ()

@end

@implementation BLYSongStore

+ (BLYSongStore *)sharedStore
{
    static BLYSongStore *sharedStore = nil;
    
    if (!sharedStore) {
        sharedStore = [[BLYSongStore alloc] init];
    }
    
    return sharedStore;
}

- (id)init
{
    self = [super init];
    
    if (self) {
        
    }
    
    return self;
}

- (BLYArtist *)artistWithSid:(NSString *)sid
{
    BLYStore *store = [BLYStore sharedStore];
    
    return [store uniqueEntityOf:@"BLYArtist" withSid:sid];
}

- (BLYArtist *)insertArtistWithSid:(NSString *)sid inCountry:(NSString *)country
{
    return [self insertArtistWithSid:sid
                 andIsYoutubeChannel:NO
                           inCountry:country];
}

- (BLYArtist *)insertArtistWithSid:(NSString *)sid
               andIsYoutubeChannel:(BOOL)isYoutubeChannel
                         inCountry:(NSString *)country
{
    BLYStore *store = [BLYStore sharedStore];
    NSManagedObjectContext *context = [store context];
    
    BLYArtist *artist = [self artistWithSid:sid];
    
    if (!artist) {
        artist = [NSEntityDescription insertNewObjectForEntityForName:@"BLYArtist"
                                               inManagedObjectContext:context];
    }
    
    artist.sid = sid;
    artist.country = country;
    artist.isYoutubeChannel = [NSNumber numberWithBool:isYoutubeChannel];
    
    return artist;
}

- (BLYArtistSong *)fetchArtistSongForArtist:(BLYArtist *)artist
                                   withName:(NSString *)artistName
{
    BLYStore *store = [BLYStore sharedStore];
    NSManagedObjectModel *model = store.model;
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    
    NSEntityDescription *entity = [model.entitiesByName objectForKey:@"BLYArtistSong"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"ref = %@ && name = %@", artist, artistName];
    
    NSError *err = nil;
    
    request.entity = entity;
    request.predicate = predicate;
    
    NSArray *results = [store.context executeFetchRequest:request error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", err.localizedDescription];
    }
    
    return [results count] > 0 ? [results objectAtIndex:0] : nil;
}

- (NSString *)realNameForArtist:(BLYArtist *)artist
{
    BLYStore *store = [BLYStore sharedStore];
    NSManagedObjectModel *model = store.model;
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    
    NSEntityDescription *entity = [model.entitiesByName objectForKey:@"BLYArtistSong"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"ref = %@ && isRealName = YES", artist];
    
    NSError *err = nil;
    
    request.entity = entity;
    request.predicate = predicate;
    
    NSArray *results = [store.context executeFetchRequest:request error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", err.localizedDescription];
    }
    
    return [results count] > 0 ? [[results objectAtIndex:0] name] : nil;
}

- (BLYArtistSong *)insertArtistSongForArtist:(BLYArtist *)artist
                                    withName:(NSString *)artistName
{
    return [self insertArtistSongForArtist:artist
                                  withName:artistName
                             andIsRealName:NO];
}

- (BLYArtistSong *)insertArtistSongForArtist:(BLYArtist *)artist
                                    withName:(NSString *)artistName
                               andIsRealName:(BOOL)isRealName
{
    BLYStore *store = [BLYStore sharedStore];
    NSManagedObjectContext *context = store.context;
    
    BLYArtistSong *artistSong = [self fetchArtistSongForArtist:artist
                                                      withName:artistName];
    
    NSNumber *isRealNameAsNumber = [NSNumber numberWithBool:isRealName];
    
    if (!artistSong) {
        artistSong = [NSEntityDescription insertNewObjectForEntityForName:@"BLYArtistSong"
                                                   inManagedObjectContext:context];
        
        artistSong.name = artistName;
        artistSong.ref = artist;
        artistSong.isRealName = isRealNameAsNumber;
        
        [self insertArtistSong:artistSong forArtist:artist];
    }
    
    if (isRealName && ![artistSong.isRealName boolValue]) {
        artistSong.isRealName = isRealNameAsNumber;
    }
    
    return artistSong;
}

- (BLYArtistSong *)insertSong:(BLYSong *)song forArtistSong:(BLYArtistSong *)artistSong
{
    NSMutableSet *songs = [artistSong.songs mutableCopy];
    
    if (![songs containsObject:song]) {
        [songs addObject:song];
    }
    
    artistSong.songs = [songs copy];
    
    return artistSong;
}

- (void)insertAlbum:(BLYAlbum *)album forArtistSong:(BLYArtistSong *)artistSong
{
    NSMutableSet *albums = [artistSong.albums mutableCopy];
    
    if (![albums containsObject:album]) {
        [albums addObject:album];
    }
    
    artistSong.albums = albums;
}

- (void)insertArtistSong:(BLYArtistSong *)artistSong forArtist:(BLYArtist *)artist
{
    NSSet *artistSongsSet = artist.artistSongs;
    NSMutableSet *artistSongs = [artistSongsSet mutableCopy];
    
    for (BLYArtistSong *artistSong in artistSongs) {
        if ([artistSongs containsObject:artistSong]) {
            continue;
        }
        
        [artistSongs addObject:artistSong];
    }
    
    artist.artistSongs = artistSongs;
}

- (BLYAlbum *)albumWithSid:(int)sid
{
    return [[BLYStore sharedStore] uniqueEntityOf:@"BLYAlbum"
                                          withSid:[NSNumber numberWithInt:sid]];
}

- (BLYAlbum *)insertAlbumWithName:(NSString *)name
                              sid:(int)sid
                          country:(NSString *)country
                     thumbnailURL:(NSString *)thumbnailURL
                   andReleaseDate:(NSDate *)releaseDate
                    forArtistSong:(BLYArtistSong *)artistSong
                          replace:(BOOL)replace
{
    BLYAlbum *album = [self albumWithSid:sid];
    
    if (!album || replace) {
        if (!album) {
            album = [NSEntityDescription insertNewObjectForEntityForName:@"BLYAlbum"
                                                  inManagedObjectContext:[[BLYStore sharedStore] context]];
            
            [self insertThumbnailWithData:nil size:@"225x225" andURL:thumbnailURL forAlbum:album];
        }
        
        album.sid = [NSNumber numberWithInt:sid];
        album.name = name;
        
        album.releaseDate = releaseDate;
        album.artist = artistSong;
        
        album.country = [country lowercaseString];
        
        BOOL isASingle = [self isASingle:album];
        
        album.isASingle = [NSNumber numberWithBool:isASingle];
        
        [self insertAlbum:album forArtistSong:artistSong];
    }
    
    return album;
}

- (BLYAlbumThumbnail *)thumbnailWithSize:(NSString *)size forAlbum:(BLYAlbum *)album
{
    BLYStore *store = [BLYStore sharedStore];
    NSManagedObjectModel *model = store.model;
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    
    NSEntityDescription *entity = [model.entitiesByName objectForKey:@"BLYAlbumThumbnail"];
    // size is reserved word in Core Data so add '#' to escape
    NSString *predicateFormat = @"#size = %@ && album = %@";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateFormat, size, album];
    
    NSError *err = nil;
    
    request.entity = entity;
    request.predicate = predicate;
    
    NSArray *results = [store.context executeFetchRequest:request error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", err.localizedDescription];
    }
    
    return [results count] > 0 ? [results objectAtIndex:0] : nil;
}

- (void)loadThumbnailsForAlbums:(NSArray *)albums withCompletionForAlbum:(void (^)(BOOL, BLYAlbum *))albumBlock andCompletionBlock:(void (^)(void))completionBlock
{
    dispatch_group_t serviceGroup = dispatch_group_create();
    
    if ([albums count] < 1) {
        if (completionBlock) {
            completionBlock();
        }
        
        return;
    }
    
    for (BLYAlbum *a in albums) {
        dispatch_group_enter(serviceGroup);
        
        [self loadThumbnail:[a smallThumbnail] withCompletionBlock:^(BOOL hasDownloaded){
           dispatch_group_leave(serviceGroup);
           
            if (albumBlock) {
               albumBlock(hasDownloaded, a);
           }
       }];
    }
    
    dispatch_group_notify(serviceGroup, dispatch_get_main_queue(),^{
        if (completionBlock) {
            completionBlock();
        }
    });
}

- (void)loadThumbnailsForPlaylist:(BLYPlaylist *)playlist withCompletionForSong:(void (^)(BOOL, BLYSong *))songBlock andCompletionBlock:(void (^)(void))completionBlock
{
    if ([playlist nbOfSongs] < 1) {
        if (completionBlock) {
            completionBlock();
        }
        
        return;
    }
    
    NSMutableArray *albums = [[NSMutableArray alloc] init];
    NSMutableDictionary *songsForAlbum = [[NSMutableDictionary alloc] init];
    
    for (BLYSong *s in playlist.songs) {
        if (!songsForAlbum[s.album.sid]) {
            songsForAlbum[s.album.sid] = [[NSMutableArray alloc] init];
            
            [albums addObject:s.album];
        }
        
        [songsForAlbum[s.album.sid] addObject:s];
    }
    
    [self loadThumbnailsForAlbums:albums withCompletionForAlbum:^(BOOL hasDownloaded, BLYAlbum *a){
        for (BLYSong *s in songsForAlbum[a.sid]) {
            songBlock(hasDownloaded, s);
        }
    } andCompletionBlock:completionBlock];
}

- (void)loadThumbnail:(BLYAlbumThumbnail *)thumbnail
         withCompletionBlock:(void (^)(BOOL))block
{
    __weak BLYSongStore *weakSelf = self;
    BLYAlbum *album = thumbnail.album;
    
    BOOL hasDownloaded = NO;
    
    if (thumbnail.data) {
        return dispatch_async(dispatch_get_main_queue(), ^{
            block(hasDownloaded);
        });
    }
    
    if ([album.thumbnailIsDownloading boolValue]) {
        return dispatch_async(dispatch_get_main_queue(), ^{
            block(hasDownloaded);
        });
    }
    
    NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration:defaultConfigObject];
    
    NSURLSessionDataTask *task = [defaultSession dataTaskWithURL:[NSURL URLWithString:thumbnail.url]
                                               completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                      
                       NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
                       
                       // Make sure core data method is called on main thread (mainQueueContext)
                       dispatch_async(dispatch_get_main_queue(), ^{
                           BOOL hasDownloaded = true;
                           
                           album.thumbnailIsDownloading = [NSNumber numberWithBool:NO];
                           
                           if (error || [httpResponse statusCode] != 200) {
                               NSLog(@"%@", error);
                               
                               hasDownloaded = false;
                               
                               return block(hasDownloaded);
                           }
                           
                           [weakSelf insertThumbnailWithData:data
                                                        size:thumbnail.size
                                                      andURL:thumbnail.url
                                                    forAlbum:album];
                           
                           block(hasDownloaded);
                       });
                  }];
    
    album.thumbnailIsDownloading = [NSNumber numberWithBool:YES];
    
    [task resume];
    
    [defaultSession finishTasksAndInvalidate];
}

- (BLYAlbumThumbnail *)insertThumbnailWithData:(NSData *)data
                                          size:(NSString *)size
                                        andURL:(NSString *)URL
                                      forAlbum:(BLYAlbum *)album
{
    BLYAlbumThumbnail *albumThumbnail = [self thumbnailWithSize:size forAlbum:album];
    
    if (!albumThumbnail) {
        albumThumbnail = [NSEntityDescription insertNewObjectForEntityForName:@"BLYAlbumThumbnail"
                                                       inManagedObjectContext:[[BLYStore sharedStore] context]];
        
        [album addThumbnailsObject:albumThumbnail];
    }
    
    albumThumbnail.data = data;
    albumThumbnail.url = URL;
    albumThumbnail.size = size;
    
    [[BLYStore sharedStore] saveChanges];
    
    return albumThumbnail;
}

- (BOOL)isASingle:(BLYAlbum *)album
{
    NSString *singlePattern = @"- single$";
    
    return [album.name bly_match:singlePattern];
}

- (void)insertSong:(BLYSong *)song forAlbum:(BLYAlbum *)album
{
    NSSet *songsSet = album.songs;
    NSMutableSet *songs = [songsSet mutableCopy];
    
    if (![songs containsObject:song]) {
        [songs addObject:song];
    }
    
    album.songs = songs;
}

- (void)setVideosReordered:(BOOL)videosReordered forSong:(BLYSong *)song
{
    song.videosReordered = [NSNumber numberWithBool:videosReordered];
    
    [[BLYStore sharedStore] saveChanges];
}

- (BLYSong *)songWithSid:(NSString *)sid
{
    return [[BLYStore sharedStore] uniqueEntityOf:@"BLYSong"
                                          withSid:sid];
}

- (BLYSong *)songWithTitle:(NSString *)title albumName:(NSString *)albumName forArtist:(NSString *)artist
{
    BLYStore *store = [BLYStore sharedStore];
    NSManagedObjectModel *model = store.model;
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    
    NSEntityDescription *entity = [model.entitiesByName objectForKey:@"BLYSong"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"title = %@ && album.name = %@ && artist.name = %@", title, albumName, artist];
    
    NSError *err = nil;
    
    request.entity = entity;
    request.predicate = predicate;
    
    NSArray *results = [store.context executeFetchRequest:request error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", err.localizedDescription];
    }
    
    return [results count] > 0 ? [results objectAtIndex:0] : nil;
}

- (BLYSong *)insertSongWithTitle:(NSString *)title
                             sid:(NSString *)sid
                      artistSong:(BLYArtistSong *)artistSong
                        duration:(int)duration
                  andRankInAlbum:(int)rank
                        forAlbum:(BLYAlbum *)album
{
    return [self insertSongWithTitle:title
                                 sid:sid
                          artistSong:artistSong
                            duration:duration
                             isVideo:NO
                      andRankInAlbum:rank
                            forAlbum:album];
}

- (BLYSong *)insertSongWithTitle:(NSString *)title
                             sid:(NSString *)sid
                      artistSong:(BLYArtistSong *)artistSong
                        duration:(int)duration
                         isVideo:(BOOL)isVideo
                  andRankInAlbum:(int)rank
                        forAlbum:(BLYAlbum *)album
{
    BLYSong *song = [self songWithSid:sid];
    BOOL isANewSong = NO;
    
    if (!song) {
        // Itunes Track ID non consistent accross countries...
        // Itunes US top tracks for french users for example...
        song = [self songWithTitle:title albumName:album.name forArtist:artistSong.name];
    }
    
    if (!song) {
        song = [NSEntityDescription insertNewObjectForEntityForName:@"BLYSong"
                                             inManagedObjectContext:[[BLYStore sharedStore] context]];
        
        [self insertSong:song forArtistSong:artistSong];
        [self insertSong:song forAlbum:album];
        
        isANewSong = YES;
        
        song.title = title;
        song.rankInAlbum = [NSNumber numberWithInt:rank];
        song.sid = sid;
        song.duration = [NSNumber numberWithInt:duration];
        song.album = album;
        song.artist = artistSong;
        song.isVideo = [NSNumber numberWithBool:isVideo];
        song.videosReordered = [NSNumber numberWithBool:NO];
    }
    
    // External top set this to 0
    if (!isANewSong && [song.duration intValue] == 0 && duration > 0) {
        song.duration = [NSNumber numberWithInt:duration];
    }
    
    // External top set this to 0
    if (!isANewSong && [song.rankInAlbum intValue] == 0 && rank > 0) {
        song.rankInAlbum = [NSNumber numberWithInt:rank];
    }
    
    return song;
}

- (void)updateSongDuration:(int)duration forSongWithID:(NSString *)songID
{
    BLYSong *song = [self songWithSid:songID];
    
    song.duration = [NSNumber numberWithInt:duration];
}

- (void)setLastPlayPlayedPercent:(double)percent forSong:(BLYSong *)song
{
    song.lastPlayPlayedPercent = [NSNumber numberWithDouble:percent];
    
    [[BLYStore sharedStore] saveChanges];
}

- (void)removeOrphanedSongs
{
    BLYStore *store = [BLYStore sharedStore];
    NSManagedObjectModel *model = store.model;
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    
    NSEntityDescription *entity = [model.entitiesByName objectForKey:@"BLYSong"];
    NSString *predicateFormat = @"externalTopSongs.@count = 0 && personalTopSong = nil && playedSong = nil && cachedSong = nil && searches.@count = 0 && searchesVideos.@count = 0 && album.searches.@count = 0 && album.playedAlbum = nil &&  relatedToSongs.@count = 0 && videoRepresentation = nil && playedPlaylistSong = nil";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateFormat];
    
    NSError *err = nil;
    
    request.entity = entity;
    request.predicate = predicate;
    
    NSArray *results = [store.context executeFetchRequest:request error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", [err localizedDescription]];
    }
    
    if ([results count] == 0) {
        return;
    }
    
    for (BLYSong *song in results) {
        [store.context deleteObject:song];
        
        song.album.isFullyLoaded = [NSNumber numberWithBool:NO];
    }
    
    [store saveChanges];
    
    [self removeOrphanedAlbums];
    [self removeOrphanedArtistSongs];
    [self removeOrphanedArtists];
}

- (void)removeOrphanedArtistSongs
{
    BLYStore *store = [BLYStore sharedStore];
    NSManagedObjectModel *model = store.model;
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    
    NSEntityDescription *entity = [model.entitiesByName objectForKey:@"BLYArtistSong"];
    NSString *predicateFormat = @"albums.@count = 0 && songs.@count = 0";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateFormat];
    
    NSError *err = nil;
    
    request.entity = entity;
    request.predicate = predicate;
    
    NSArray *results = [store.context executeFetchRequest:request error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", err.localizedDescription];
    }
    
    if ([results count] == 0) {
        return;
    }
    
    for (BLYArtistSong *artistSong in results) {
        [store.context deleteObject:artistSong];
    }
    
    [store saveChanges];
}

- (void)removeOrphanedArtists
{
    BLYStore *store = [BLYStore sharedStore];
    NSManagedObjectModel *model = store.model;
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    
    NSEntityDescription *entity = [model.entitiesByName objectForKey:@"BLYArtist"];
    NSString *predicateFormat = @"artistSongs.@count = 0 && search = nil";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateFormat];
    
    NSError *err = nil;
    
    request.entity = entity;
    request.predicate = predicate;
    
    NSArray *results = [store.context executeFetchRequest:request error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", err.localizedDescription];
    }
    
    if ([results count] == 0) {
        return;
    }
    
    for (BLYArtist *artist in results) {
        [store.context deleteObject:artist];
    }
    
    [store saveChanges];
}

- (void)removeOrphanedAlbums
{
    BLYStore *store = [BLYStore sharedStore];
    NSManagedObjectModel *model = store.model;
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    
    NSEntityDescription *entity = [model.entitiesByName objectForKey:@"BLYAlbum"];
    NSString *predicateFormat = @"songs.@count = 0 && searches.@count = 0 && playedAlbum = nil && cachedAlbum = nil";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateFormat];
    
    NSError *err = nil;
    
    request.entity = entity;
    request.predicate = predicate;
    
    NSArray *results = [store.context executeFetchRequest:request error:&err];
    
    if (!results) {
        [NSException raise:@"Fetch failed" format:@"Reason: %@", err.localizedDescription];
    }
    
    if ([results count] == 0) {
        return;
    }
    
    for (BLYAlbum *album in results) {
        [store.context deleteObject:album];
    }
    
    [store saveChanges];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
