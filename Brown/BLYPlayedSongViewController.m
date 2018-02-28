//
//  BLYPlayedSongsHistoryViewController.m
//  Brown
//
//  Created by Jeremy Levy on 19/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import "BLYPlayedSongViewController.h"
#import "BLYPlayedSong.h"
#import "BLYPlayedSongStore.h"
#import "BLYPlayedAlbumStore.h"
#import "BLYPlaylist.h"
#import "BLYSong.h"
#import "BLYSong+Caching.h"
#import "BLYPlayedAlbum.h"
#import "BLYAlbumViewController.h"
#import "BLYPlayedPlaylistSongStore.h"
#import "BLYPlayedSongOnLoadHeaderView.h"
#import "BLYAlbumsListHeaderView.h"
#import "BLYPlayedPlaylistSong.h"
#import "BLYArtistSong.h"
#import "BLYAlbum.h"
#import "BLYAlbum+Thumbnail.h"
#import "BLYPlayerPlaylistViewController.h"
#import "BLYTimeManager.h"
#import "BLYVideoStore.h"
#import "BLYCachedSongStore.h"
#import "BLYCachedSong+CoreDataClass.h"
#import "BLYBaseViewController.h"
#import "BLYBaseNavigationController.h"
#import "BLYPersonalTopSongStore.h"
#import "BLYPersonalTopSongViewController.h"
#import "BLYPersonalTopSong.h"
#import "BLYPlayedAlbumCell.h"
#import "BLYAppSettingsViewController.h"
#import "BLYPlaylistSongCell.h"
#import "BLYAppDelegate.h"
#import "BLYNetworkStore.h"
#import "BLYAppSettingsStore.h"

@interface BLYPlayedSongViewController ()

@property (strong, nonatomic) BLYPlaylist *reorderedPlayedSongsPlaylist;
@property (strong, nonatomic) BLYPlaylist *reorderedCachedSongsPlaylist;

@property (nonatomic) BOOL songIsLoadedFromAlbum;
@property (copy, nonatomic) BLYPlaylist *loadedPlaylist;

@property (nonatomic) BOOL displayLastPlaylist;
@property (strong, nonatomic) UIView *headerView;

@property (strong, nonatomic) BLYPlaylist *playlistToReload;
@property (strong, nonatomic) BLYSong *songToReload;

@property (nonatomic) BOOL playlistResumed;
@property (strong, nonatomic) BLYAlbumsListHeaderView *albumsListHeaderView;

@property (nonatomic) BOOL cachedSongsDisplayed;
@property (strong, nonatomic) NSMutableDictionary *playlistScrolls;

@property (strong, nonatomic) BLYSong *songToDelete;

@end

@implementation BLYPlayedSongViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self) {
        // Custom initialization
        UIImage *externalTopSongsTabBarIcon = [UIImage imageNamed:@"HistoryTabBarIcon"];
        UIImage *externalTopSongsSelectedTabBarIcon = [UIImage imageNamed:@"HistorySelectedTabBarIcon"];
        
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@""
                                                        image:externalTopSongsTabBarIcon
                                                selectedImage:externalTopSongsSelectedTabBarIcon];
        
        UIImage *appSettingsNavIcon = [UIImage imageNamed:@"AppSettings"];
        UIBarButtonItem *rightBarButton = [[UIBarButtonItem alloc] initWithImage:appSettingsNavIcon
                                                                          style:UIBarButtonItemStylePlain
                                                                         target:self
                                                                         action:@selector(showAppSettings:)];
        
        //self.navigationItem.rightBarButtonItem = rightBarButton;
        
        [self updateNavTitleView];
        
        _cachedSongsDisplayed = NO;
        
        // self.navigationItem.leftBarButtonItem = self.editButtonItem;
        
        if ([[self playedSongs] nbOfSongs] > 0) {
            self.playlist = [self playedSongs];
            self.albums = [self playedAlbums];
        } else {
            self.playlist = [self cachedSongs];
            self.albums = [self cachedAlbums];
            
            if ([self.playlist nbOfSongs] > 0) {
                _cachedSongsDisplayed = YES;
            }
        }
        
        self.albumsListHeaderView = [[[NSBundle mainBundle] loadNibNamed:@"BLYAlbumsListHeaderView" owner:nil options:nil] objectAtIndex:0];
        ;
        
        //self.albumsListHeaderView.albumsLoadingIndicator.hidden = YES;
        self.albumsListHeaderView.albumsLoadingLabel.hidden = YES;
        
        self.albumsListHeaderView.albums.dataSource = self;
        self.albumsListHeaderView.albums.delegate = self;
        
        //self.albumResults = self.albumsListHeaderView.albums;
        
        _displayLastPlaylist = NO;
        
        if ([[self playedSongs] nbOfSongs] == 0 && ![self hasCachedSongsOrAlbums]) {
            self.tabBarItem.enabled = NO;
        } else {
            NSDictionary *playedPlaylistSongs = [self playedPlaylistSongs];
            
            // Check For Before update to v1.1
            if ([(BLYPlaylist *)playedPlaylistSongs[@"playlist"] nbOfSongs] > 0
                && [playedPlaylistSongs[@"currentSong"] isKindOfClass:[BLYSong class]]) {
                
                _playlistToReload = playedPlaylistSongs[@"playlist"];
                _songToReload = playedPlaylistSongs[@"currentSong"];
                
                _displayLastPlaylist = YES;
            }
        }
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleSongAddedToPersonalTop:)
                                                     name:BLYPersonalTopSongStoreDidAddSong
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleAlbumHasBeenUncached:)
                                                     name:BLYCachedSongStoreDidUncacheAlbum
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleSettingHasChangedNotification:)
                                                     name:BLYAppSettingsStoreSettingHasChanged
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handlePlayerAddedToPersonalTop:)
                                                     name:BLYPlayerViewControllerDidAddToPersonalTop
                                                   object:nil];
        
        _playlistResumed = NO;
        _songToDelete = nil;
        
        _playlistScrolls = [[NSMutableDictionary alloc] init];
        
        _playlistScrolls[@"played"] = [NSValue valueWithCGPoint:CGPointZero];
        _playlistScrolls[@"cached"] = [NSValue valueWithCGPoint:CGPointZero];
        
        [self displayPersonalTopSongNavButtonIfNecessary];
    }
    
    return self;
}

- (BLYPlaylist *)playedSongs
{
    BLYPlaylist *playlist = [[BLYPlaylist alloc] init];
    NSArray *playedSongs = [[BLYPlayedSongStore sharedStore] fetchPlayedSongs];
    
    for (BLYPlayedSong *playedSong in playedSongs) {
        [playlist addSong:playedSong.song];
    }
    
    return playlist;
}

- (BOOL)hasCachedSongsOrAlbums
{
    return [[self cachedSongs] nbOfSongs] > 0 || [[self cachedAlbums] count] > 0;
}

- (BLYPlaylist *)cachedSongs
{
    BLYPlaylist *playlist = [[BLYPlaylist alloc] init];
    NSArray *cachedSongs = [[BLYCachedSongStore sharedStore] fetchCachedSongs];
    
    for (BLYCachedSong *cachedSong in cachedSongs) {
        if ([cachedSong.song.album.isCached boolValue]) {
            continue;
        }
        
        [playlist addSong:cachedSong.song];
    }
    
    return playlist;
}

- (NSMutableArray *)playedAlbums
{
    NSMutableArray *albums = [[NSMutableArray alloc] init];
    NSArray *playedAlbums = [[BLYPlayedAlbumStore sharedStore] fetchPlayedAlbums];
    
    for (BLYPlayedAlbum *playedAlbum in playedAlbums) {
        [albums addObject:playedAlbum.album];
    }
    
    return albums;
}

- (NSMutableArray *)cachedAlbums
{
    return [[[BLYCachedSongStore sharedStore] fetchCachedAlbums] mutableCopy];
}

- (NSDictionary *)playedPlaylistSongs
{
    NSArray *playedPlaylistSongs = [[BLYPlayedPlaylistSongStore sharedStore] fetchPlayedPlaylistSongs];
    BLYPlaylist *playlist = [[BLYPlaylist alloc] init];
    id songToReload = nil;
    
    for (BLYPlayedPlaylistSong *playedPlaylistSong in playedPlaylistSongs) {
        [playlist addSong:playedPlaylistSong.song];
        
        if ([playedPlaylistSong.isCurrent boolValue]) {
            songToReload = playedPlaylistSong.song;
        }
    }
    
    if (!songToReload) {
        songToReload = [NSNull null];
    } else {
        playlist.isAnAlbumPlaylist = [((BLYSong *)songToReload).playedPlaylistSong.isLoadedFromAlbum boolValue];
    }
    
    return @{@"playlist": playlist, @"currentSong": songToReload};
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self extendedNavigationBar];
    
    if (self.displayLastPlaylist) {
        [self initResumeLastPlaylistHeader];
    } else {
        [self initUI];
    }
    
    // Do any additional setup after loading the view from its nib.
    UINib *nib = [UINib nibWithNibName:@"BLYAlbumCell" bundle:nil];
    
    // Register this NIB which contains the cell
    [self.albumResults registerNib:nib
        forCellWithReuseIdentifier:@"BLYAlbumCell"];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    // Fix nav bar bottom border wrong offset
    // when returning from full screen
    if (!self.displayLastPlaylist) {
        [self normalNavigationBar];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Album VC use extended nav bar
    // so make sure we go back to normal size
    // when user return to this VC
    if (!self.displayLastPlaylist) {
        [self normalNavigationBar];
    }
    
    if (self.reorderedPlayedSongsPlaylist
        && [self.reorderedPlayedSongsPlaylist nbOfSongs] > 0
        && !_cachedSongsDisplayed) {
        
        self.playlist = self.reorderedPlayedSongsPlaylist;
        self.reorderedPlayedSongsPlaylist = nil;
        
        [self.songsList reloadData];
        [self.songsList setContentOffset:CGPointZero animated:NO];
    }
    
    if (self.reorderedCachedSongsPlaylist
        && [self.reorderedCachedSongsPlaylist nbOfSongs] > 0
        && _cachedSongsDisplayed) {
        
        self.playlist = self.reorderedCachedSongsPlaylist;
        self.reorderedCachedSongsPlaylist = nil;
        
        [self.songsList reloadData];
        [self.songsList setContentOffset:CGPointZero animated:NO];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self saveSongsListContentOffset];
}

- (void)updateAlbumsHeaderView
{
    if ([self.albums count] >= 1 && !self.displayLastPlaylist) {
        self.headerView = self.albumsListHeaderView;
    } else {
        self.headerView = nil;
    }
    
    [self.albumResults reloadData];
}

- (void)initResumeLastPlaylistHeader
{
    if (!self.displayLastPlaylist) {
        return;
    }
    
    if (![[BLYNetworkStore sharedStore] networkIsReachableViaWifi]
        && [[BLYAppSettingsStore sharedStore] boolForSetting:BLYAppSettingsStoreForbidUcachedSongsListeningSetting]) {
        
        if (![_playlistToReload hasCachedSong]) {
            self.onloadHeaderView.resumePlaylistButton.enabled = NO;
            self.onloadHeaderView.resumePlaylistButton.layer.opacity = 0.4;
        } else {
            _songToReload = [_playlistToReload firstCachedSong];
        }
    } else {
        NSDictionary *playedPlaylistSongs = [self playedPlaylistSongs];
        
        _songToReload = playedPlaylistSongs[@"currentSong"];
        
        self.onloadHeaderView.resumePlaylistButton.enabled = YES;
        self.onloadHeaderView.resumePlaylistButton.layer.opacity = 1.0;
    }
    
    if ([self.songToReload.playedPlaylistSong.isLoadedFromAlbum boolValue]) {
        self.onloadHeaderView.songTitle.text = self.songToReload.album.name;
        self.onloadHeaderView.songArtist.text = self.songToReload.artist.name;
    } else {
        self.onloadHeaderView.songTitle.text = self.songToReload.title;
        self.onloadHeaderView.songArtist.text = self.songToReload.artist.name;
        
        if ([self.songToReload.album.name length] > 0 && ![self.songToReload.album.isASingle boolValue]) {
            self.onloadHeaderView.songArtist.text = [self.onloadHeaderView.songArtist.text stringByAppendingString:[NSString stringWithFormat:@" - %@", self.songToReload.album.name]];
        }
    }
    
    self.onloadHeaderView.songThumbnail.image = [self.songToReload.album smallThumbnailAsImg];
    
    [self.onloadHeaderView.resumePlaylistButton addTarget:self
                                                   action:@selector(handlePlaylistResume:)
                                         forControlEvents:UIControlEventTouchUpInside];
    
    [self extendedNavigationBar];
}

- (void)initUI
{
    [self.onloadHeaderView removeFromSuperview];
    self.onloadHeaderView = nil;
    
    self.songsListTopConstraint.constant = 0;
    self.albumsListTopConstraint.constant = 0;
    
    if (self.displayLastPlaylist) {
        self.displayLastPlaylist = NO;
        
        [self.songsList reloadData];
    }
    
    self.tabBarItem.enabled = YES;
    
    [self updateEditButton];
    
    [self normalNavigationBar];
    
    [self updateNavTitleView];
    [self updateAlbumsHeaderView];
}

- (void)playedSongTypeChanged:(UISegmentedControl *)seg
{
    [self saveSongsListContentOffset];
    
    if (seg.selectedSegmentIndex == 0) {
        [self displayPlayedSong];
    } else {
        [self displayCachedSongs];
    }
}

- (void)displayPlayedSong
{
    _cachedSongsDisplayed = NO;
    
    self.playlist = [self playedSongs];
    self.albums = [self playedAlbums];
    
    [self updateAlbumsHeaderView];
    
    [self.songsList reloadData];
    [self.albumResults reloadData];
    
    [self resetContentOffset];
}

- (void)displayCachedSongs
{
    _cachedSongsDisplayed = YES;
    
    self.playlist = [self cachedSongs];
    self.albums = [self cachedAlbums];
    
    [self updateAlbumsHeaderView];
    
    [self.songsList reloadData];
    [self.albumResults reloadData];
    
    [self resetContentOffset];
}

- (void)handlePlaylistResume:(UIButton *)playlistResumeButton
{
    self.playlistResumed = YES;
    
    if (self.onloadHeaderView != nil) {
        ((BLYPlayedSongOnLoadHeaderView *)self.onloadHeaderView).loadingView.hidden = NO;
    }
    
    [self.playerVC loadPlaylist:self.playlistToReload
               andStartWithSong:self.songToReload
                    askedByUser:YES];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)updateEditButton
{
    return;
    
    if (([self.playlist nbOfSongs] <= 1
        && self.playerStatusForLastNotification != BLYPlayerViewControllerPlayerStatusError)) {
        self.navigationItem.leftBarButtonItem = nil;
    } else {
        self.navigationItem.leftBarButtonItem = self.editButtonItem;
    }
}

- (void)updateNavTitleView
{
    if (![[self playedAlbums] count]) {
    //if (![self hasCachedSongsOrAlbums] || YES) {
        self.navigationItem.titleView = nil;
        self.navigationItem.title = NSLocalizedString(@"history_navigation_item_title", nil);
        self.historyTypeChoiceView.hidden = YES;
        
        return;
    }
    
    UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:@[NSLocalizedString(@"history_segment_0_type", nil), NSLocalizedString(@"history_segment_1_type", nil)]];
    
    if ([self.navigationItem.titleView isKindOfClass:[UISegmentedControl class]]) {
        seg = (UISegmentedControl *)self.navigationItem.titleView;
    }
    
    if ([[self playedSongs] nbOfSongs] > 0) {
        [seg setEnabled:YES forSegmentAtIndex:0];
    } else {
        [seg setEnabled:NO forSegmentAtIndex:0];
    }
    
    [seg setEnabled:YES forSegmentAtIndex:1];
    
    if (self.navigationItem.titleView) {
        return;
    }
    
    if ([[self playedSongs] nbOfSongs] > 0) {
        seg.selectedSegmentIndex = 0;
    } else {
        seg.selectedSegmentIndex = 1;
    }
    
    seg.tintColor = [UIColor whiteColor];
    
    [seg sizeToFit];
    
    [seg addTarget:self
            action:@selector(changeHistoryType:)
  forControlEvents:UIControlEventValueChanged];
    
    UIFont *font = [UIFont boldSystemFontOfSize:16.0f];
    
    [seg setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor blackColor], NSFontAttributeName: font}
                                 forState:UIControlStateSelected];
    
    [seg setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor colorWithWhite:0.4 alpha:1.0]}
                       forState:UIControlStateNormal];
    
    [seg setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor colorWithWhite:0.2 alpha:1.0]}
                       forState:UIControlStateDisabled];
    
    self.navigationItem.titleView = seg;
}

//- (void)setEditing:(BOOL)editing animated:(BOOL)animated
//{
//    [super setEditing:editing animated:animated];
//    
//    [self.songsList setEditing:editing animated:YES];
//}

//- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
//           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
//{
//    BLYSong *song = [self.playlist songAtIndex:indexPath.row];
//    BLYPlayerViewController *playerVC = self.playerVC;
//    
//    BOOL itsCurrentSong = [playerVC isCurrentSong:song];
//    
//    if (itsCurrentSong
//        && self.playerStatusForLastNotification != BLYPlayerViewControllerPlayerStatusError) {
//        return UITableViewCellEditingStyleNone;
//    }
//    
//    return UITableViewCellEditingStyleDelete;
//}

//- (void)tableView:(UITableView *)tableView
//commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
//forRowAtIndexPath:(NSIndexPath *)indexPath
//{
//    // If row is deleted, remove it from the list.
//    if (editingStyle == UITableViewCellEditingStyleDelete) {
//        BLYSong *s = [self.playlist songAtIndex:indexPath.row];
//
//        BLYPlayerViewController *playerVC = self.playerVC;
//        BOOL itsCurrentSong = [playerVC isCurrentSong:s];
//
//        if (_cachedSongsDisplayed) {
//            [self.playlist removeSongAtIndex:indexPath.row];
//
//            if (self.reorderedCachedSongsPlaylist) {
//                [self.reorderedCachedSongsPlaylist removeSongAtIndex:indexPath.row];
//            }
//
//            // Needs to be called after song is removed
//            // from playlist but before songslist reload data
//            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
//                             withRowAnimation:UITableViewRowAnimationLeft];
//
//            // Needs to be called after row was deleted
//            // because this method post notification when song was uncached
//            // which reload data for songslist
//            [self.songCachingStore uncacheSong:s];
//        } else if (!itsCurrentSong) {
//            [[BLYPlayedSongStore sharedStore] deletePlayedSong:s.playedSong];
//
//            [self.playlist removeSongAtIndex:indexPath.row];
//
//            if (self.reorderedPlayedSongsPlaylist) {
//                [self.reorderedPlayedSongsPlaylist removeSongAtIndex:indexPath.row];
//            }
//
//            // Needs to be called after song is removed
//            // from playlist but before songslist reload data
//            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
//                             withRowAnimation:UITableViewRowAnimationLeft];
//
////            if (s.isCached) {
////                [self.songCachingStore uncacheSong:s];
////            }
//        }
//
//        [self updateEditButton];
//
//        [NSTimer scheduledTimerWithTimeInterval:0.5
//                                         target:self
//                                       selector:@selector(handleRowDeletion:)
//                                       userInfo:nil
//                                        repeats:NO];
//    }
//}
//
//- (void)handleRowDeletion:(NSTimer *)t
//{
//    // Empty history ? Back to top of the charts
//    if ([[self playedSongs] nbOfSongs] == 0 && ![self hasCachedSongsOrAlbums]) {
//        [self disableTabBarItem];
//    } else {
//        [self.songsList reloadData];
//    }
//}

- (void)disableTabBarItem
{
    self.tabBarItem.enabled = NO;
    self.tabBarController.selectedIndex = BLYBaseTabBarControllerExternalTopIndex;
    
    _cachedSongsDisplayed = NO;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [super tableView:tableView numberOfRowsInSection:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 0.0;
    
    if (self.headerView != nil
        && [self.headerView isKindOfClass:[BLYAlbumsListHeaderView class]]
        && section == 0) {
        
        CGFloat w = self.headerView.frame.size.width;
        
        return (w / self.nbOfAlbumsDisplayedPerPage) + 2;
    }
    
    return 0.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    return nil;
    
    if (self.headerView == nil || section == 1) {
        return nil;
    }
    
    return self.headerView;
}

- (void)handlePlayerHasPlayedASongNotification:(NSNotification *)n
{
    NSDictionary *userInfo = [n userInfo];
    BLYSong *loadedSong = [userInfo objectForKey:@"playedSong"];
    BLYPlayedSong *playedSong = [[BLYPlayedSongStore sharedStore] playedSongWithSong:loadedSong];
    
    if (_songToDelete && ![loadedSong.sid isEqualToString:_songToDelete.sid]) {
        [[BLYPlayedSongStore sharedStore] deleteLastPlayedSong];
        
//        self.playlist = [self playedSongs];
//        
//        [self.songsList reloadData];
        
        _songToDelete = nil;
        
        // Remove cache for song in case last played song was cached
        // during partial play
        [[BLYCachedSongStore sharedStore] removeUnusedCachedSongs];
    }
    
    if (playedSong) {
        NSIndexPath *songIndexPath = [NSIndexPath indexPathForRow:[self.playlist indexOfSong:loadedSong] inSection:0];
        
        BLYPlaylistSongCell *songCell = [self.songsList cellForRowAtIndexPath:songIndexPath];
        
        [[BLYPlayedSongStore sharedStore] updatePlayedAtForPlayedSong:playedSong];
        
        if ([self.songsList.visibleCells containsObject:songCell]
            && [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
            
            BLYSong *song = [playedSong song];
            BLYPlaylist *reorderedPlaylist = nil;
            
            if (_cachedSongsDisplayed) {
                reorderedPlaylist = self.reorderedCachedSongsPlaylist;
                
                if (!reorderedPlaylist) {
                    reorderedPlaylist = [self cachedSongs];
                }
            } else {
                reorderedPlaylist = self.reorderedPlayedSongsPlaylist;
                
                if (!reorderedPlaylist) {
                    reorderedPlaylist = [self playedSongs];
                }
            }
            
            NSInteger songIndex = [reorderedPlaylist indexOfSong:song];
            
            if (songIndex != NSNotFound) {
                [reorderedPlaylist removeSongAtIndex:songIndex];
            }
            
            [reorderedPlaylist insertSong:song atIndex:0];
            
            if (_cachedSongsDisplayed) {
                self.reorderedCachedSongsPlaylist = reorderedPlaylist;
            } else {
                self.reorderedPlayedSongsPlaylist = reorderedPlaylist;
            }
        } else {
            if (!_cachedSongsDisplayed) {
                self.playlist = [self playedSongs];
                self.reorderedPlayedSongsPlaylist = nil;
            } else {
                self.playlist = [self cachedSongs];
                self.reorderedCachedSongsPlaylist = nil;
            }
            
            [self.songsList reloadData];
        }
    } else {
        [[BLYPlayedSongStore sharedStore] insertPlayedSong:loadedSong];
        
        _songToDelete = loadedSong;
        
        if (!_cachedSongsDisplayed) {
            self.playlist = [self playedSongs];
            self.reorderedPlayedSongsPlaylist = nil;
        } else {
            self.playlist = [self cachedSongs];
            self.reorderedCachedSongsPlaylist = nil;
        }
        
        [self.songsList reloadData];
    }
    
    if (self.songIsLoadedFromAlbum) {
        BLYPlayedAlbum *playedAlbum = [[BLYPlayedAlbumStore sharedStore] playedAlbumWithAlbum:loadedSong.album];
        
        if (playedAlbum) {
            [[BLYPlayedAlbumStore sharedStore] updatePlayedAtForPlayedAlbum:playedAlbum];
            
            NSInteger albumIndex = [self.albums indexOfObject:loadedSong.album];
            
            if (albumIndex != NSNotFound && !_cachedSongsDisplayed) {
                [self.albums removeObjectAtIndex:albumIndex];
            }
        } else {
            [[BLYPlayedAlbumStore sharedStore] insertPlayedAlbum:loadedSong.album];
            
            NSMutableArray *albums = [self albums];
            
            if ([albums count] == BLYPlayedAlbumStoreMaxAlbums && !_cachedSongsDisplayed) {
                [albums removeObjectAtIndex:BLYPlayedAlbumStoreMaxAlbums - 1];
            }
        }
        
        if (!_cachedSongsDisplayed) {
            [self.albums insertObject:loadedSong.album atIndex:0];
            
            [self.albumResults reloadData];
        }
    }
    
    if (!self.playlistResumed) {
        if (self.loadedPlaylist) {
            [[BLYPlayedPlaylistSongStore sharedStore] cleanPlayedPlaylistSongs];
            
            int rank = 0;
            
            for (BLYSong *song in self.loadedPlaylist.songs) {
                [[BLYPlayedPlaylistSongStore sharedStore] insertPlayedPlaylistSongWithRank:rank
                                                                                   current:[song isEqual:loadedSong]
                                                                           loadedFromAlbum:self.songIsLoadedFromAlbum
                                                                                   forSong:song];
                
                rank++;
            }
            
            self.loadedPlaylist = nil;
        } else {
            [[BLYPlayedPlaylistSongStore sharedStore] updateIsCurrent:YES
                                                forPlayedPlaylistSong:loadedSong.playedPlaylistSong];
        }
    } else {
        self.playlistResumed = NO;
    }
    
    // Make sure to set this after insertplayedplaylistsong...
    self.songIsLoadedFromAlbum = NO;
    
    [self initUI];
    
    // Reload the songslist's data
    [super handlePlayerHasPlayedASongNotification:n];
}

- (void)handlePlayerAddedToPersonalTop:(NSNotification *)n
{
    _songToDelete = nil;
    
    [[BLYPlayedSongStore sharedStore] deleteFirstPlayedSongIfNecessary];
}

- (void)saveSongsListContentOffset
{
    NSValue *contentOffsetValue = [NSValue valueWithCGPoint:self.songsList.contentOffset];
    
    [self.playlistScrolls setObject:contentOffsetValue
                             forKey:_cachedSongsDisplayed ? @"cached" : @"played"];
}

- (void)resetContentOffset
{
    NSValue *contentOffsetValue = [self.playlistScrolls objectForKey:_cachedSongsDisplayed ? @"cached" : @"played"];
    CGPoint contentOffset = contentOffsetValue.CGPointValue;
    
    self.songsList.contentOffset = contentOffset;
}

- (void)handlePlayerHasLoadedASongNotification:(NSNotification *)n
{
    [self updateEditButton];
    
    [super handlePlayerHasLoadedASongNotification:n];
}

- (void)handlePlayerHasLoadedASongWithErrorNotification:(NSNotification *)n
{
    [self updateEditButton];
    
    if (self.onloadHeaderView != nil) {
        ((BLYPlayedSongOnLoadHeaderView *)self.onloadHeaderView).loadingView.hidden = YES;
    }
    
    [super handlePlayerHasLoadedASongWithErrorNotification:n];
}

- (void)handlePlayerHasLoadedPlaylist:(NSNotification *)n
{
    NSDictionary *userInfo = n.userInfo;
    BLYPlaylist *loadedPlaylist = userInfo[@"loadedPlaylist"];
    
    // Base view controller force player to send this notification
    // So check that notification is for player
    if ([userInfo[@"forPlayer"] boolValue]) {
        if (!self.playlistResumed) {
            self.loadedPlaylist = loadedPlaylist;
            self.songIsLoadedFromAlbum = loadedPlaylist.isAnAlbumPlaylist;
        } else {
            self.loadedPlaylist = nil;
        }
    }
    
    [super handlePlayerHasLoadedPlaylist:n];
}

- (void)handleSongHasBeenDownloadedNotification:(NSNotification *)n
{
    [super handleSongHasBeenDownloadedNotification:n];
    
    return;
    
    [self updateNavTitleView];
    
    // Update playlist
    if (_cachedSongsDisplayed) {
        [self displayCachedSongs];
    } else if (!self.tabBarItem.enabled) {
        [self initUI];
        [self displayCachedSongs];
    }
}

- (void)handleSongHasBeenUncachedNotification:(NSNotification *)n
{
    // Notification can be from "album has been uncached" notification, see below
    
    [super handleSongHasBeenUncachedNotification:n];
    
    return;
    
    [self updateNavTitleView];
    
    if ([[self playedSongs] nbOfSongs] == 0 && ![self hasCachedSongsOrAlbums]) {
        [self disableTabBarItem];
        
        return;
    }
    
    // Update playlist
    if (![self hasCachedSongsOrAlbums]) {
        [self displayPlayedSong];
    } else if (_cachedSongsDisplayed) {
        [self displayCachedSongs];
    }
}

- (void)handleAlbumHasBeenUncached:(NSNotification *)n
{
    [self handleSongHasBeenUncachedNotification:n];
}

- (void)changeHistoryType:(id)sender
{
    NSInteger selectedSegment = [sender selectedSegmentIndex];
    
    if (selectedSegment == 0) {
        self.albumResults.hidden = YES;
        self.songsList.hidden = NO;
    } else {
        self.songsList.hidden = YES;
        self.albumResults.hidden = NO;
    }
    
    [self updateEditButton];
}

- (void)displayPersonalTopSongNavButton
{
    UIImage *personalTopSongNavIcon = [UIImage imageNamed:@"MyTopNav"];
    UIBarButtonItem *leftBarButton = [[UIBarButtonItem alloc] initWithImage:personalTopSongNavIcon
                                                                      style:UIBarButtonItemStylePlain
                                                                     target:self
                                                                     action:@selector(showMyTop:)];
    
    self.navigationItem.leftBarButtonItem = leftBarButton;
}

- (void)showMyTop:(UIBarButtonItem *)leftBarButtonItem
{
    BLYBaseNavigationController *navigationController = [[BLYBaseNavigationController alloc] init];
    BLYPersonalTopSongViewController *personalTopVC = [[BLYPersonalTopSongViewController alloc] init];
    BLYPlayerViewController *playerVC = self.playerVC;
    
    NSArray *personalTopSongs = [[BLYPersonalTopSongStore sharedStore] fetchPersonalTopSong];
    NSMutableArray *songsForPlaylist = [[NSMutableArray alloc] init];
    
    BLYPlaylist *playlist = [[BLYPlaylist alloc] init];
    
    for (BLYPersonalTopSong *personalTopSong in personalTopSongs) {
        [songsForPlaylist addObject:personalTopSong.song];
    }
    
    playlist.songs = songsForPlaylist;
    
    personalTopVC.playlist = playlist;
    personalTopVC.playerVC = playerVC;
    
    [navigationController addChildViewController:personalTopVC];
    
    personalTopVC.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    
    [self presentViewController:navigationController
                       animated:YES
                     completion:nil];
}

- (void)showAppSettings:(UIBarButtonItem *)leftBarButtonItem
{
    BLYBaseNavigationController *navigationController = [[BLYBaseNavigationController alloc] init];
    BLYAppSettingsViewController *appSettingsVC = [[BLYAppSettingsViewController alloc] init];
    
    [navigationController addChildViewController:appSettingsVC];
    
    appSettingsVC.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    
    [self presentViewController:navigationController
                       animated:YES
                     completion:nil];
}

- (void)handleSongAddedToPersonalTop:(NSNotification *)n
{
    [self displayPersonalTopSongNavButtonIfNecessary];
}

- (void)displayPersonalTopSongNavButtonIfNecessary
{
    NSUInteger count = [[BLYPersonalTopSongStore sharedStore] countDisplayedPersonalTopSong];
    
    if (count == 0) {
        return;
    }
    
    [self displayPersonalTopSongNavButton];
}

- (BLYPlaylist *)playlistToRunOnShake
{
    BLYPlaylist *playlist = [super playlistToRunOnShake];
    
    if (_cachedSongsDisplayed) {
        NSArray *cachedAlbums = [self cachedAlbums];
        
        for (BLYAlbum *album in cachedAlbums) {
            for (BLYSong *song in album.songs) {
                if ([playlist containsSong:song]) {
                    continue;
                }
                
                [playlist addSong:song];
            }
        }
    }
    
    return playlist;
}

- (void)handleNetworkReachable:(NSNotification *)n
{
    [super handleNetworkReachable:n];
    
    [self initResumeLastPlaylistHeader];
}

- (void)handleNetworkNotReachable:(NSNotification *)n
{
    [super handleNetworkNotReachable:n];
    
    [self initResumeLastPlaylistHeader];
}

- (void)handleNetworkTypeChange:(NSNotification *)n
{
    [super handleNetworkTypeChange:n];
    
    [self initResumeLastPlaylistHeader];
}

- (void)handleSettingHasChangedNotification:(NSNotification *)n
{
    NSDictionary *userInfo = n.userInfo;
    
    if ([userInfo[@"setting"] intValue] != BLYAppSettingsStoreForbidUcachedSongsListeningSetting) {
        return;
    }
    
    [self.songsList reloadData];
}

@end
