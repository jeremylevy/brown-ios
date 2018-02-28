//
//  BLYSongStore.h
//  Brown
//
//  Created by Jeremy Levy on 29/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BLYArtist, BLYArtistSong, BLYAlbum, BLYSong, BLYAlbumThumbnail, BLYPlaylist;

@interface BLYSongStore : NSObject

+ (BLYSongStore *)sharedStore;

- (BLYSong *)songWithSid:(NSString *)sid;

- (BLYArtist *)artistWithSid:(NSString *)sid;

- (BLYArtist *)insertArtistWithSid:(NSString *)sid
                         inCountry:(NSString *)country;

- (BLYArtist *)insertArtistWithSid:(NSString *)sid
               andIsYoutubeChannel:(BOOL)isYoutubeChannel
                         inCountry:(NSString *)country;

- (BLYArtistSong *)insertArtistSongForArtist:(BLYArtist *)artist
                                    withName:(NSString *)name;

- (BLYArtistSong *)insertArtistSongForArtist:(BLYArtist *)artist
                                    withName:(NSString *)artistName
                               andIsRealName:(BOOL)isRealName;


- (BLYAlbum *)insertAlbumWithName:(NSString *)name
                              sid:(int)sid
                          country:(NSString *)country
                     thumbnailURL:(NSString *)thumbnailURL
                   andReleaseDate:(NSDate *)releaseDate
                    forArtistSong:(BLYArtistSong *)artistSong
                          replace:(BOOL)replace;

- (BLYSong *)insertSongWithTitle:(NSString *)title
                             sid:(NSString *)sid
                      artistSong:(BLYArtistSong *)artist
                        duration:(int)duration
                  andRankInAlbum:(int)rank
                        forAlbum:(BLYAlbum *)album;

- (BLYSong *)insertSongWithTitle:(NSString *)title
                             sid:(NSString *)sid
                      artistSong:(BLYArtistSong *)artistSong
                        duration:(int)duration
                         isVideo:(BOOL)isVideo
                  andRankInAlbum:(int)rank
                        forAlbum:(BLYAlbum *)album;

- (void)setLastPlayPlayedPercent:(double)percent forSong:(BLYSong *)song;

- (BLYAlbum *)albumWithSid:(int)sid;

- (NSString *)realNameForArtist:(BLYArtist *)artist;

- (BLYAlbumThumbnail *)insertThumbnailWithData:(NSData *)data
                                          size:(NSString *)size
                                        andURL:(NSString *)URL
                                      forAlbum:(BLYAlbum *)album;

- (void)loadThumbnail:(BLYAlbumThumbnail *)thumbnail
   withCompletionBlock:(void (^)(BOOL))block;

- (void)loadThumbnailsForAlbums:(NSArray *)albums withCompletionForAlbum:(void (^)(BOOL, BLYAlbum *))albumBlock andCompletionBlock:(void (^)(void))completionBlock;
- (void)loadThumbnailsForPlaylist:(BLYPlaylist *)playlist withCompletionForSong:(void (^)(BOOL, BLYSong *))songBlock andCompletionBlock:(void (^)(void))completionBlock;

- (BLYAlbumThumbnail *)thumbnailWithSize:(NSString *)size forAlbum:(BLYAlbum *)album;

- (void)removeOrphanedSongs;

- (void)updateSongDuration:(int)duration forSongWithID:(NSString *)songID;

- (void)setVideosReordered:(BOOL)videosReordered forSong:(BLYSong *)song;

@end
