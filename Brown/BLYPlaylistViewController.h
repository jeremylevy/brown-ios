//
//  BLYPlaylistViewController.h
//  Brown
//
//  Created by Jeremy Levy on 26/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BLYPlayerViewController.h"
#import "BLYSongCachingStore.h"

@class BLYPlaylist, BLYSong, BLYPlayerViewController, BLYSongCachingStore;


extern NSString * const BLYPlaylistViewControllerWillLoadPlaylistNotification;
extern NSString * const BLYPlaylistViewControllerHasSelectedSong;

@interface BLYPlaylistViewController: BLYBaseViewController <UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate>

@property (strong, nonatomic) BLYPlaylist *playlist;
@property (weak, nonatomic) IBOutlet UITableView *songsList;

@property (weak, nonatomic) BLYPlayerViewController *playerVC;
@property (nonatomic) BLYPlayerViewControllerPlayerStatus playerStatusForLastNotification;
@property (strong, nonatomic) BLYSongCachingStore *songCachingStore;

@property (nonatomic) BOOL dismissOnPlay;

// Overrided by BLYPlayedSongViewController
- (void)handlePlayerHasPlayedASongNotification:(NSNotification *)n;
- (void)handlePlayerHasLoadedASongNotification:(NSNotification *)n;

- (void)handlePlayerHasLoadedASongWithErrorNotification:(NSNotification *)n;
- (void)handleSongHasBeenDownloadedNotification:(NSNotification *)n;

- (void)handleSongHasBeenDownloadedWithErrorNotification:(NSNotification *)n;
- (void)handleSongHasBeenUncachedNotification:(NSNotification *)n;

- (BLYSong *)handleLoadRandomPlaylistOnShake;
- (BLYPlaylist *)playlistToRunOnShake;

@end
