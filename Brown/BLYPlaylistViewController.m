//
//  BLYPlaylistViewController.m
//  Brown
//
//  Created by Jeremy Levy on 26/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import "BLYPlaylistViewController.h"
#import "BLYPlayerViewController.h"
#import "BLYPlaylistSongCell.h"
#import "BLYSong.h"
#import "BLYSong+Caching.h"
#import "BLYPlaylist.h"
#import "BLYAlbum.h"
#import "BLYAlbum+Thumbnail.h"
#import "BLYAlbumViewController.h"
#import "BLYArtist.h"
#import "BLYArtistSong.h"
#import "BLYNetworkStore.h"
#import "BLYVideo.h"
#import "BLYVideoStore.h"
#import "BLYSearchSongsStore.h"
#import "BLYAppDelegate.h"
#import "BLYFullScreenPlayerViewController.h"
#import "BLYTimeManager.h"
#import "BLYVideoStore.h"
#import "BLYSongCachingStore.h"
#import "BLYAlbumThumbnail.h"
#import "BLYVideoSong.h"
#import "BLYPlayedSongViewController.h"
#import "BLYHTTPConnection.h"
#import "BLYErrorStore.h"
#import "BLYCachedSongStore.h"
#import "NSString+Matching.h"
#import "NSString+Sizing.h"
#import "NSString+Escaping.h"
#import "Brown-Swift.h"
#import "BLYAppSettingsStore.h"
#import "BLYBaseTabBarController.h"
#import "BLYSearchSongResultsViewController.h"

NSString * const BLYPlaylistViewControllerWillLoadPlaylistNotification = @"BLYPlaylistViewControllerWillLoadPlaylistNotification";

NSString * const BLYPlaylistViewControllerHasSelectedSong = @"BLYPlaylistViewControllerHasSelectedSong";

static void * const BLYPlaylistViewControllerKVOContext = (void*)&BLYPlaylistViewControllerKVOContext;

@interface BLYPlaylistViewController ()

@property (strong, nonatomic) BLYTimeManager *timeManager;
@property (nonatomic) NSInteger songsListSection;
@property (strong, nonatomic) AVAudioPlayer *shakePlayer;
@property (strong, nonatomic) ActivityViewController *presentedShakeActivityVC;

@end

@implementation BLYPlaylistViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self) {
        // Custom initialization
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handlePlayerHasLoadedASongNotification:)
                                                     name:BLYPlayerViewControllerDidLoadSongNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handlePlayerHasPausedASongNotification:)
                                                     name:BLYPlayerViewControllerDidPauseSongNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handlePlayerHasPlayedASongNotification:)
                                                     name:BLYPlayerViewControllerDidPlaySongNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handlePlayerHasLoadedASongWithErrorNotification:)
                                                     name:BLYPlayerViewControllerDidLoadSongWithErrorNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleSearchSongsStoreDidUpdateSongsDurationNotification:)
                                                     name:BLYVideoStoreDidUpdateSongsDurationNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleDownloadSongWillStartNotification:)
                                                     name:BLYSongCachingStoreWillDownloadSongNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleDownloadSongProgressNotification:)
                                                     name:BLYSongCachingStoreDownloadSongProgressNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleSongHasBeenDownloadedNotification:)
                                                     name:BLYSongCachingStoreDidDownloadSongNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleSongHasBeenDownloadedWithErrorNotification:)
                                                     name:BLYSongCachingStoreDidDownloadSongWithErrorNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleSongHasBeenStoppedDownloadingNotification:)
                                                     name:BLYSongCachingStoreDidStopDownloadingSongNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleSongHasBeenUncachedNotification:)
                                                     name:BLYCachedSongStoreDidDeleteCacheForSong
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleSettingHasChangedNotification:)
                                                     name:BLYAppSettingsStoreSettingHasChanged
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleAlbumThumbnailReloaded:)
                                                     name:BLYAlbumThumbnailDidRedownloadNotification
                                                   object:nil];
        
        _dismissOnPlay = NO;
        
        _playerStatusForLastNotification = BLYPlayerViewControllerPlayerStatusUnknown;
        _timeManager = [[BLYTimeManager alloc] init];
        
        _songCachingStore = [BLYSongCachingStore sharedStore];
        
        [self loadShakePlayer];
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
	// Do any additional setup after loading the view.
    
    // Load the NIB file
    UINib *nib = [UINib nibWithNibName:@"BLYPlaylistSongCell" bundle:nil];
    
    // Register this NIB which contains the cell
    [self.songsList registerNib:nib forCellReuseIdentifier:@"BLYPlaylistSongCell"];
    
    [self.songsList setRowHeight:65.0];
    
    // Player listen to it to post corresponding player status notification
    [[NSNotificationCenter defaultCenter] postNotificationName:BLYPlaylistViewControllerWillLoadPlaylistNotification
                                                        object:self];
    
    [self.songsList addObserver:self
                     forKeyPath:@"hidden"
                        options:NSKeyValueObservingOptionNew
                        context:NULL];
    
    [self.songsList setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    
    UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc]
                                          initWithTarget:self action:@selector(handleLongPressOnCell:)];
    
    lpgr.minimumPressDuration = 2.0;
    lpgr.delegate = self;
    
    [self.songsList addGestureRecognizer:lpgr];
    
    //[self navigationBarLightBorder];
}

- (void)viewDidAppear:(BOOL)animated
{
    [self becomeFirstResponder];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (object == self.songsList) {
        if ([keyPath isEqualToString:@"hidden"]) {
            BOOL hidden = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
            
            // Dismiss on play if songs list is not hidden and if this VC is presented modally
            [self setDismissOnPlay:self.presentingViewController && !hidden];
        }
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)loadShakePlayer
{
    NSURL *soundURL = [NSURL URLWithString:@"/System/Library/Audio/UISounds/shake.caf"];
    NSError *error = nil;
    
    AVAudioPlayer *shakePlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:soundURL error:&error];
    
    if (error) {
        return;
    }
    
    [shakePlayer setVolume:1.0];
    
    _shakePlayer = shakePlayer;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    BLYPlaylist *playlist = self.playlist;
    
    return playlist ? [playlist nbOfSongs] : 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    BLYPlaylistSongCell *cell = [self.songsList dequeueReusableCellWithIdentifier:@"BLYPlaylistSongCell"];
    BLYSong *song = [self.playlist songAtIndex:indexPath.row];
    
    BLYPlayerViewController *playerVC = self.playerVC;
    
    // Don't use [playerVC playerStatus] here ! Player status is updated before player VC post corresponding notification...
    BLYPlayerViewControllerPlayerStatus playerStatus = self.playerStatusForLastNotification;
    
    BOOL itsCurrentSong = [playerVC isCurrentSong:song];
    
    self.songsListSection = indexPath.section;
    
    UIColor *selectedCellColor = [UIColor colorWithRed:247 / 255.f green:247 / 255.f blue:247 / 255.f alpha:1.0];
    UIColor *highlightedCellColor = [UIColor colorWithRed:236 / 255.f green:236 / 255.f blue:236 / 255.f alpha:1.0];
    UIView *selectedView = [[UIView alloc] init];
    
    [selectedView setBackgroundColor:highlightedCellColor];
    [cell setSelectedBackgroundView:selectedView];
    
    [cell setSelectionStyle:UITableViewCellSelectionStyleDefault];
    
    [cell.rank setText:[NSString stringWithFormat:@"%d", (int)indexPath.row + 1]];
    [cell.title setText:song.title];
    
    if (![self isKindOfClass:[BLYAlbumViewController class]]) {
        if (![song.album.isASingle boolValue] && ![song.isVideo boolValue]) {
            [cell.artist setText:[song.artist.name stringByAppendingString:[NSString stringWithFormat:@" - %@", song.album.name]]];
        } else {
            [cell.artist setText:song.artist.name];
        }
    } else {
        NSString *featPattern = @"\\s*(?:\\(|\\[|\\{)(?:feat\\.|ft\\.|featuring)(.+)(?:\\)|\\]|\\})";
        
        NSString *songTitleForAlbumVC = song.title;
        NSString *artistNameForAlbumVC = song.artist.name;
        
        if ([song.title bly_match:featPattern]) {
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
                NSString *featArtistName = [songTitleForAlbumVC substringWithRange:matchRange];
                
                artistNameForAlbumVC = [artistNameForAlbumVC stringByAppendingString:[NSString stringWithFormat:@" feat.%@", featArtistName]];
                
                songTitleForAlbumVC = [songTitleForAlbumVC bly_stringByReplacingPattern:featPattern withString:@""];
                
                break;
            }
        }
        
        [cell.title setText:songTitleForAlbumVC];
        [cell.artist setText:artistNameForAlbumVC];
    }
    
    [cell.thumbnail setImage:[song.album smallThumbnailAsImg]];
    
    if (itsCurrentSong || true) {
        cell.thumbnailOverlay.hidden = YES;

        // For performance with corner radius
        // See https://stackoverflow.com/questions/12236184/tableview-scrolling-lack-of-performance-using-cornerradius-whats-alternatives
        [cell.contentView setOpaque:YES];
        [cell.backgroundView setOpaque:YES];


        cell.thumbnail.layer.cornerRadius = 25.0;
        cell.thumbnail.layer.masksToBounds = YES;
        // Performance improvement here depends on the size of your view
        cell.thumbnail.layer.shouldRasterize = YES;
        cell.thumbnail.layer.rasterizationScale = [UIScreen mainScreen].scale;
    } else {
        cell.thumbnailOverlay.hidden = NO;
    }
    
    [cell.loader setHidden:YES];
    [cell.playIcon setHidden:YES];
    
    [cell.pauseIcon setHidden:YES];
    [cell.loader stopAnimating];
    
    [cell.rank setHidden:NO];
    
    if ([song.isVideo boolValue]
        && [song.duration intValue] > 0
        && (![song isCached] || YES)
        && [self isKindOfClass:[BLYSearchSongResultsViewController class]]) {
        // Player always display video duration with one second less.
        // Todo: Learn why
        cell.duration.text = [self.timeManager durationAsString:[song.duration floatValue]];
        
        cell.duration.hidden = NO;
    } else {
        cell.duration.text = @"";
        cell.duration.hidden = YES;
    }
    
    if ([song isCached]) {
        cell.cachedIndicator.hidden = YES;
    } else {
        cell.cachedIndicator.hidden = YES;
    }
    
    if ([_songCachingStore isSongDownloading:song] && [_songCachingStore isSongDownloadingHasBeenAskedByUser:song]) {
        cell.cachingProgressView.progress = [_songCachingStore percentageDownloadedForSong:song];
        cell.cachingProgressView.hidden = NO;
        
        cell.cachingActivityIndicator.hidden = NO;
        [cell.cachingActivityIndicator startAnimating];
    } else {
        cell.cachingProgressView.hidden = YES;
        
        cell.cachingActivityIndicator.hidden = YES;
        [cell.cachingActivityIndicator stopAnimating];
    }
    
    [cell.loader setHidden:YES];
    [cell.playIcon setHidden:YES];
    [cell.pauseIcon setHidden:YES];
    
    if (((![[BLYNetworkStore sharedStore] networkIsReachableViaWifi]
        && [[BLYAppSettingsStore sharedStore] boolForSetting:BLYAppSettingsStoreForbidUcachedSongsListeningSetting]
        && ![song isCached])
        || (![[BLYNetworkStore sharedStore] networkIsReachable]
            && ![song isCached]))
        && !itsCurrentSong) {
        
        cell.userInteractionEnabled = NO;
        cell.contentView.layer.opacity = 0.4;
    } else {
        cell.userInteractionEnabled = YES;
        cell.contentView.layer.opacity = 1.0;
    }
    
    if (itsCurrentSong && playerStatus != BLYPlayerViewControllerPlayerStatusError) {
        [cell setContainsCurrentSong:YES];
        [cell setBackgroundColor:selectedCellColor];
        [cell.rank setHidden:YES];
        
        if (playerStatus == BLYPlayerViewControllerPlayerStatusLoading) {
            [cell.loader setHidden:NO];
            [cell.loader startAnimating];
        } else if (playerStatus == BLYPlayerViewControllerPlayerStatusPlaying) {
            [cell.pauseIcon setHidden:NO];
        } else if (playerStatus == BLYPlayerViewControllerPlayerStatusPaused) {
            [cell.playIcon setHidden:NO];
        }
        
        return cell;
    }
    
    [cell setBackgroundColor:[UIColor whiteColor]];
    [cell setContainsCurrentSong:NO];
    
    return cell;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    return indexPath;
    
    BLYPlaylistSongCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    
    [cell.contentView setOpaque:YES];
    [cell.backgroundView setOpaque:YES];
    cell.thumbnail.layer.cornerRadius = 25.0;
    cell.thumbnail.layer.masksToBounds = YES;
    // Performance improvement here depends on the size of your view
    cell.thumbnail.layer.shouldRasterize = YES;
    cell.thumbnail.layer.rasterizationScale = [UIScreen mainScreen].scale;
    cell.thumbnailOverlay.hidden = true;
    
    return indexPath;
}

- (void)tableView:(UITableView *)tableView didHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    return;
    
    BLYPlaylistSongCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    
    [cell.contentView setOpaque:YES];
    [cell.backgroundView setOpaque:YES];
    cell.thumbnail.layer.cornerRadius = 25.0;
    cell.thumbnail.layer.masksToBounds = YES;
    // Performance improvement here depends on the size of your view
    cell.thumbnail.layer.shouldRasterize = YES;
    cell.thumbnail.layer.rasterizationScale = [UIScreen mainScreen].scale;
    cell.thumbnailOverlay.hidden = true;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self loadSongAtIndexPath:indexPath forceRefresh:NO];
}

- (void)loadSongAtIndexPath:(NSIndexPath *)indexPath forceRefresh:(BOOL)forceRefresh
{
    BLYSong *song = [self.playlist songAtIndex:indexPath.row];
    BLYPlayerViewController *playerVC = self.playerVC;
    
    if (!self.playerVC) {
        return;
    }
    
    BLYAppDelegate *appDelegate = (BLYAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    if ([playerVC isCurrentSong:song]
        && playerVC.playerStatus != BLYPlayerViewControllerPlayerStatusError
        && !forceRefresh) {
        
        // Don't use toggleplaypause, here. User may be select many times too fast..
        if (playerVC.playerStatus == BLYPlayerViewControllerPlayerStatusPaused) {
            [playerVC play];
        } else if (playerVC.playerStatus == BLYPlayerViewControllerPlayerStatusPlaying) {
            [playerVC pause:YES];
        }
        
//        [appDelegate trackEventWithCategory:@"playlist_ui"
//                                     action:@"select_song"
//                                      label:@"current_song"
//                                      value:nil];
        
        return;
    }
    
    [playerVC loadPlaylist:self.playlist
          andStartWithSong:song
               askedByUser:YES
              forceRefresh:forceRefresh];
    
    [self setDismissOnPlay:!!self.presentingViewController];
    
//    [appDelegate trackEventWithCategory:@"playlist_ui"
//                                 action:@"select_song"
//                                  label:NSStringFromClass([self class])
//                                  value:nil];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BLYPlaylistViewControllerHasSelectedSong
                                                        object:self];
}

- (void)handleLongPressOnCell: (UILongPressGestureRecognizer *)gestureRecognizer
{
    CGPoint p = [gestureRecognizer locationInView:self.songsList];
    
    NSIndexPath *indexPath = [self.songsList indexPathForRowAtPoint:p];
    
    if (indexPath == nil) {
        return;
    }
    
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        [self loadSongAtIndexPath:indexPath forceRefresh:true];
    }
}

//- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
//    return [[self tableView:self.songsList editActionsForRowAtIndexPath:indexPath] count] > 0;
//}
//
//- (NSArray *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
//    __weak BLYPlaylistViewController *weakSelf = self;
//    NSMutableArray *editActions = [[NSMutableArray alloc] init];
//    
//    BLYSong *song = [self.playlist songAtIndex:indexPath.row];
//    
//    BLYPlayerViewController *playerVC = self.playerVC;
//    BOOL itsCurrentSong = [playerVC isCurrentSong:song];
//    
//    if (([self isKindOfClass:[BLYPlayedSongViewController class]] && !itsCurrentSong) || (song.isCached && NO)) {
//        UITableViewRowAction *deleteAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:NSLocalizedString(@"playlist_delete_song", nil) handler:^(UITableViewRowAction *action, NSIndexPath *indexPath){
//            
//            if ([weakSelf isKindOfClass:[BLYPlayedSongViewController class]]) {
//                [weakSelf tableView:self.songsList
//             commitEditingStyle:UITableViewCellEditingStyleDelete
//              forRowAtIndexPath:indexPath];
//            } else {
//                [weakSelf.songCachingStore uncacheSong:song];
//            }
//        }];
//        
//        [editActions addObject:deleteAction];
//    }
//    
//    return [editActions copy];
//    
//    UITableViewRowAction *downloadAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault title:NSLocalizedString(@"playlist_download_song_abbr", nil) handler:^(UITableViewRowAction *action, NSIndexPath *indexPath){
//        
//        BLYSong *song = [weakSelf.playlist songAtIndex:indexPath.row];
//        
//        
//        // Update "asked by" user flag to display progress view
//        if ([weakSelf.songCachingStore isSongDownloading:song]) {
//            [weakSelf.songCachingStore setIsDownloading:YES forSong:song init:NO askedByUser:YES];
//            
//            [weakSelf.songsList reloadData];
//            
//            return;
//        }
//        
//        [weakSelf.songCachingStore cacheSong:song askedByUser:YES withCompletion:^(NSError *err) {
//            if (err) {
//                return [[BLYErrorStore sharedStore] manageError:err forViewController:self];
//            }
//        }];
//    }];
//    
//    downloadAction.backgroundColor = [UIColor colorWithRed:102.0 / 255.0 green:204.0 / 255.0 blue:255.0 / 255.0 alpha:1.0];
//
//    UITableViewRowAction *stopDownloadingAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault title:NSLocalizedString(@"playlist_stop_download_song_abbr", nil) handler:^(UITableViewRowAction *action, NSIndexPath *indexPath){
//        
//        BLYSong *song = [weakSelf.playlist songAtIndex:indexPath.row];
//        
//        [weakSelf.songCachingStore stopCachingSong:song];
//    }];
//    
//    stopDownloadingAction.backgroundColor = [UIColor orangeColor];
//    
//    if (!song.isCached) {
//        if ([self.songCachingStore isSongDownloading:song]
//            && [_songCachingStore isSongDownloadingHasBeenAskedByUser:song]) {
//            
//            if ([editActions count] == 0) {
//                stopDownloadingAction.title = NSLocalizedString(@"playlist_stop_download_song", nil);
//            }
//
//            [editActions addObject:stopDownloadingAction];
//        } else {
//            if ([editActions count] == 0) {
//                downloadAction.title = NSLocalizedString(@"playlist_download_song", nil);
//            }
//            
//            [editActions addObject:downloadAction];
//        }
//    } else {
//        ((UITableViewRowAction *)editActions[0]).title = NSLocalizedString(@"playlist_delete_song", nil);
//    }
//    
//    return [editActions copy];
//}

- (void)handlePlayerHasLoadedASongNotification:(NSNotification *)n
{
    [self setPlayerStatusForLastNotification:BLYPlayerViewControllerPlayerStatusLoading];
    
    [self.songsList reloadData];
}

- (void)handlePlayerHasLoadedASongWithErrorNotification:(NSNotification *)n
{
    [self setPlayerStatusForLastNotification:BLYPlayerViewControllerPlayerStatusError];
    
    [self.songsList reloadData];
}

- (void)handlePlayerHasPausedASongNotification:(NSNotification *)n
{
    [self setPlayerStatusForLastNotification:BLYPlayerViewControllerPlayerStatusPaused];
    
    [self.songsList reloadData];
}

- (void)handlePlayerHasPlayedASongNotification:(NSNotification *)n
{
    [self setPlayerStatusForLastNotification:BLYPlayerViewControllerPlayerStatusPlaying];
    
    if (self.dismissOnPlay) {
        self.dismissOnPlay = NO;
        
        [self dismissMe:nil];
        
        return;
    }
    
    if (_presentedShakeActivityVC) {
        _presentedShakeActivityVC = nil;
        
        self.tabBarController.selectedIndex = BLYBaseTabBarControllerPlayerIndex;
        
        [self dismissViewControllerAnimated:NO completion:^{
            if (self.presentingViewController) {
                ((BLYBaseTabBarController *)self.presentingViewController).selectedIndex = BLYBaseTabBarControllerPlayerIndex;
                
                [self dismissMe:nil];
            }
        }];
    }
    
    [self.songsList reloadData];
}

- (void)handleSearchSongsStoreDidUpdateSongsDurationNotification:(NSNotification *)n
{
    [self.songsList reloadData];
}

- (void)handleDownloadSongWillStartNotification:(NSNotification *)n
{
    [self.songsList reloadData];
}

- (void)handleSettingHasChangedNotification:(NSNotification *)n
{
    NSDictionary *userInfo = n.userInfo;
    
    if ([userInfo[@"setting"] intValue] != BLYAppSettingsStoreForbidUcachedSongsListeningSetting) {
        return;
    }
    
    [self.songsList reloadData];
}

- (void)handleDownloadSongProgressNotification:(NSNotification *)n
{
    NSDictionary *infos = [n userInfo];
    BLYSong *song = infos[@"song"];
    
    NSInteger indexOfSong = [self.playlist indexOfSong:song];
    
    // Not in this playlist
    if (NSNotFound == indexOfSong) {
        return;
    }
    
    BLYPlaylistSongCell *cell = [self.songsList cellForRowAtIndexPath:[NSIndexPath indexPathForRow:indexOfSong inSection:self.songsListSection]];
    
    // returns nil if cell is not visible or index path is out of range
    if (!cell) {
        return;
    }
    
    cell.cachingProgressView.progress = [infos[@"percentageDownloaded"] floatValue];
}

- (void)handleSongHasBeenDownloadedNotification:(NSNotification *)n
{
    [self.songsList reloadData];
}

- (void)handleSongHasBeenDownloadedWithErrorNotification:(NSNotification *)n
{    
    [self.songsList reloadData];
}

- (void)handleSongHasBeenUncachedNotification:(NSNotification *)n
{
    [self.songsList reloadData];
}

- (void)handleSongHasBeenStoppedDownloadingNotification:(NSNotification *)n
{
    [self.songsList reloadData];
}

- (void)handleAlbumThumbnailReloaded:(NSNotification *)n
{
    [self.songsList reloadData];
}

- (void)handleNetworkReachable:(NSNotification *)n
{
    [self.songsList reloadData];
}

- (void)handleNetworkNotReachable:(NSNotification *)n
{
    [self.songsList reloadData];
}

- (void)handleNetworkTypeChange:(NSNotification *)n
{
    [self.songsList reloadData];
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    if (motion != UIEventSubtypeMotionShake) {
        return;
    }
    
    [self handleLoadRandomPlaylistOnShake];
}

- (BLYPlaylist *)playlistToRunOnShake
{
    return [self.playlist copy];
}

- (BLYSong *)handleLoadRandomPlaylistOnShake
{
    if (![[BLYAppSettingsStore sharedStore] boolForSetting:BLYAppSettingsStoreShakeToRandomizePlaylistSetting]) {
        return nil;
    }
    
    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
        return nil;
    }
    
    BLYPlaylist *currentPlaylist = [self playlistToRunOnShake];
    BLYSong *startSong = nil;
    
    [currentPlaylist shuffleSongs];
    
    startSong = [currentPlaylist songAtIndex:0];
    
    if (![[BLYNetworkStore sharedStore] networkIsReachableViaWifi]
        && [[BLYAppSettingsStore sharedStore] boolForSetting:BLYAppSettingsStoreForbidUcachedSongsListeningSetting]) {
        
        if (![currentPlaylist hasCachedSong]) {
            return nil;
        }
        
        startSong = [currentPlaylist firstCachedSong];
    }
    
    if ([[[[self.tabBarController tabBar] items] objectAtIndex:BLYBaseTabBarControllerPlayerIndex] isEnabled]) {
        self.tabBarController.selectedIndex = BLYBaseTabBarControllerPlayerIndex;
    } else if ([[[[((BLYBaseTabBarController *)self.presentingViewController) tabBar] items] objectAtIndex:BLYBaseTabBarControllerPlayerIndex] isEnabled]) {
        ((BLYBaseTabBarController *)self.presentingViewController).selectedIndex = BLYBaseTabBarControllerPlayerIndex;
        
        [self dismissMe:nil];
    } else {
        ActivityViewController *activityVC = [[ActivityViewController alloc] initWithMessage:NSLocalizedString(@"Loading...", nil)];

        [self presentViewController:activityVC animated:NO completion:^{}];

        _presentedShakeActivityVC = activityVC;
    }
    
    [_playerVC loadPlaylist:currentPlaylist
           andStartWithSong:startSong
                askedByUser:YES];
    
    [_shakePlayer play];
    
    return startSong;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self.songsList removeObserver:self forKeyPath:@"hidden"];
    
    // Avoid "err_bad_excess" when pop this view controller
    [self.songsList setDelegate:nil];
    [self.songsList setDataSource:nil];
}

@end
