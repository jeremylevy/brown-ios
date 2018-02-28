//
//  BLYSearchSongResultsViewController.m
//  Brown
//
//  Created by Jeremy Levy on 01/10/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import "BLYSearchSongResultsViewController.h"
#import "BLYSearchSongResultsStore.h"
#import "BLYAlbumCell.h"
#import "BLYAlbum.h"
#import "BLYPlaylist.h"
#import "BLYSong.h"
#import "BLYArtist.h"
#import "BLYArtistSong.h"
#import "BLYAlbumViewController.h"
#import "BLYSearchSongsStore.h"
#import "BLYSearchSong.h"
#import "NSString+Escaping.h"
#import "BLYNetworkStore.h"
#import "BLYPlayerViewController.h"
#import "BLYErrorStore.h"
#import "BLYBaseNavigationController.h"
#import "BLYStore.h"
#import "BLYSearchSongViewController.h"
#import "BLYPlayerViewController.h"
#import "BLYAppDelegate.h"
#import "BLYVideoStore.h"
#import "BLYAlbumThumbnail.h"
#import "BLYAlbumsListHeaderView.h"

float BLYSearchSongResultsViewControllerDisabledAlbumCellsOpacity = 0.55;
const int BLYSearchSongResultsViewControllerTracksSegment = 0;
const int BLYSearchSongResultsViewControllerAlbumsSegment = 1;
const int BLYSearchSongResultsViewControllerVideosSegment = 2;

@interface BLYSearchSongResultsViewController ()

@property (strong, nonatomic) BLYSearchSong *currentSearchSong;
@property (strong, nonatomic) void (^viewDidAppearCallback)(void);

@property (nonatomic) BOOL songsAreLoaded;
@property (nonatomic) BOOL songsAreLoadedWithError;
@property (strong, nonatomic) NSError *songsLoadingErr;

@property (nonatomic) BOOL albumsAreLoading;
@property (nonatomic) BOOL albumsAreLoaded;
@property (nonatomic) BOOL albumsAreLoadedWithError;
@property (strong, nonatomic) NSError *albumsLoadingErr;

@property (nonatomic) BOOL videosAreLoading;
@property (nonatomic) BOOL videosAreLoaded;
@property (nonatomic) BOOL videosAreLoadedWithError;
@property (strong, nonatomic) NSError *videosLoadingErr;

@property (nonatomic, getter = isLoaded) BOOL loaded;
@property (nonatomic) CGFloat baseTopHeight;

@property (strong, nonatomic) NSMutableDictionary *playlists;
@property (strong, nonatomic) NSMutableDictionary *playlistScrolls;

@property (strong, nonatomic) UIRefreshControl *refreshControlForSongsAndVideos;
@property (strong, nonatomic) UIRefreshControl *refreshControlForAlbums;

@property (nonatomic) int tracksSegment;
@property (nonatomic) int albumsSegment;
@property (nonatomic) int videosSegment;

@end

@implementation BLYSearchSongResultsViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self) {
        // Custom initialization
        _loaded = NO;
        _playlists = [[NSMutableDictionary alloc] init];
        _playlistScrolls = [[NSMutableDictionary alloc] init];
        
        _songsAreLoaded = NO;
        
        _tracksSegment = BLYSearchSongResultsViewControllerTracksSegment;
        _albumsSegment = BLYSearchSongResultsViewControllerAlbumsSegment;
        _videosSegment = BLYSearchSongResultsViewControllerVideosSegment;
    }
    
    return self;
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    if ([self.playlistScrolls count] >= 2) {
        return;
    }
    
    NSValue *contentOffsetValue = [NSValue valueWithCGPoint:CGPointMake(0.0, 0.0)];
    
    [self.playlistScrolls setObject:contentOffsetValue
                             forKey:[NSNumber numberWithInteger:0]];
    
    [self.playlistScrolls setObject:contentOffsetValue
                             forKey:[NSNumber numberWithInteger:1]];
    
}

- (void)scrollSongsListToTop
{    
    if ([self.playlist nbOfSongs] > 0) {
        // Don't use scroll to row here because
        // we want header view to be displayed
        self.songsList.contentOffset = CGPointMake(0.0, 0.0);
    }
}

- (void)saveSongsListContentOffset
{
    NSValue *contentOffsetValue = [NSValue valueWithCGPoint:self.songsList.contentOffset];
    NSInteger selectedSegment = self.resultsTypeSegmentedControl.selectedSegmentIndex;
    
    [self.playlistScrolls setObject:contentOffsetValue
                             forKey:[NSNumber numberWithInteger:selectedSegment]];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self saveSongsListContentOffset];
}

- (void)updateSongsListContentOffset
{
    NSInteger selectedSegment = self.resultsTypeSegmentedControl.selectedSegmentIndex;
    NSValue *contentOffsetValue = [self.playlistScrolls objectForKey:[NSNumber numberWithInteger:selectedSegment]];
    CGPoint contentOffset = contentOffsetValue.CGPointValue;
    
    self.songsList.contentOffset = contentOffset;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.loadingTextLabel.text = NSLocalizedString(@"view_controller_main_loading_text", nil);
    self.noResultsTextLabel.text = NSLocalizedString(@"view_controller_main_no_results_text", nil);
    
    
    [self.errorRetryButton setTitle:NSLocalizedString(@"error_retry_button", nil)
                           forState:UIControlStateNormal];
    
    self.errorRetryButton.layer.borderWidth = 0.0;
    self.errorRetryButton.layer.cornerRadius = 14.5;
    
    self.errorRetryButton.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.errorRetryButton.tintColor = [UIColor lightGrayColor];
    
    [_errorRetryButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_errorRetryButton setBackgroundColor:[UIColor colorWithWhite:0.8 alpha:1.0]];
    
    [self.errorRetryButton addTarget:self
                              action:@selector(retryLoading:)
                    forControlEvents:UIControlEventTouchUpInside];
    
    [self.resultsTypeSegmentedControl setTitle:NSLocalizedString(@"search_results_segment_0_type", nil)
                             forSegmentAtIndex:_tracksSegment];
    [self.resultsTypeSegmentedControl setTitle:NSLocalizedString(@"search_results_segment_1_type", nil)
                             forSegmentAtIndex:_albumsSegment];
    [self.resultsTypeSegmentedControl setTitle:NSLocalizedString(@"search_results_segment_2_type", nil)
                             forSegmentAtIndex:_videosSegment];
    
    UIFont *font = [UIFont boldSystemFontOfSize:16.0f];
    
    [self.resultsTypeSegmentedControl setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor blackColor], NSFontAttributeName: font}
                                 forState:UIControlStateSelected];
    
    [self.resultsTypeSegmentedControl setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor colorWithWhite:0.4 alpha:1.0]}
                                 forState:UIControlStateNormal];
    
    [self.resultsTypeSegmentedControl setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor colorWithWhite:0.2 alpha:1.0]}
                                 forState:UIControlStateDisabled];
    
    [self.resultsContainer addObserver:self forKeyPath:@"hidden" options:0 context:NULL];
    
    self.baseTopHeight = 0.0;
    
    if (!self.currentSearch && !self.currentSearchedArtist) {
        [NSException raise:@"BLYSearchSongResultsViewController didn't load"
                    format:@"Reason: self.currentSearch or self.currentSearchedArtist must be set."];
    }
    
    BLYArtistSong *searchedArtistSong = self.currentSearchedArtist;
    BLYArtist *searchedArtist = searchedArtistSong.ref;
    
    // Loaded from artist link in player VC
    if (searchedArtistSong) {
        BLYSongStore *songStore = [BLYSongStore sharedStore];
        NSString *artistName = [songStore realNameForArtist:searchedArtist];
        
        if (!artistName) {
            artistName = searchedArtistSong.name;
            artistName = [artistName bly_artistNameByRemovingRightPartOfComposedArtist];
        }
        
        self.navigationItem.title = artistName;
    } else {
        self.navigationItem.title = [self.currentSearch capitalizedString];
    }
    
    self.resultsTypeSegmentedControl.superview.hidden = YES;
    
    [self loadSongsForCurrentSearchForce:NO byPullToRefresh:NO];
    
    [self extendedNavigationBar];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (self.playlists[@"songs"] != nil) {
        [self extendedNavigationBar];
    } else {
        [self normalNavigationBar];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if (self.searchSongVC && [self isMovingFromParentViewController]) {
        self.searchSongVC.displayedByPopingSearchResultsVC = true;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    self.loaded = YES;
    
    if (self.viewDidAppearCallback) {
        self.viewDidAppearCallback();
        self.viewDidAppearCallback = nil;
    }
}

- (void)retryLoading:(UIButton *)button
{
    NSInteger selectedSegment = self.resultsTypeSegmentedControl.selectedSegmentIndex;
    
    _errorView.hidden = YES;
    self.songsList.hidden = YES;
    self.resultsContainer.hidden = YES;
    
    if (!self.resultsTypeSegmentedControl || selectedSegment == _videosSegment) {
        [self loadVideosForCurrentSearchForce:YES byPullToRefresh:NO];
    } else if (selectedSegment == _tracksSegment) {
        [self loadSongsForCurrentSearchForce:YES byPullToRefresh:NO];
    } else if (selectedSegment == _albumsSegment) {
        [self loadAlbumsForCurrentSearchForce:YES byPullToRefresh:NO];
    }
}

- (void)loadSongsForCurrentSearchForce:(BOOL)force byPullToRefresh:(BOOL)byPullToRefresh
{
    BLYArtistSong *searchedArtistSong = self.currentSearchedArtist;
    BLYArtist *searchedArtist = searchedArtistSong.ref;
    BOOL loadYoutubeChannel = searchedArtistSong && [searchedArtist.isYoutubeChannel boolValue];
    
    __weak BLYSearchSongResultsViewController *weakSelf = self;
    
    void (^endRefreshingBlock)(NSError *err) = ^(NSError *err) {
        if (!err) {
            [weakSelf.songsList reloadData];
        }
        
        [[weakSelf refreshControlForSongsAndVideos] endRefreshing];
    };
    
    void (^completionBlock)(NSMutableDictionary *results, NSError *err) = ^(NSMutableDictionary *results, NSError *err) {
        weakSelf.songsAreLoadedWithError = !!err;
        weakSelf.songsLoadingErr = err;
        
        if (err) {
            if (byPullToRefresh) {
                endRefreshingBlock(err);
            }
            
            weakSelf.errorViewLabel.text = err.localizedDescription;
            weakSelf.errorView.hidden = NO;
            
            return;
        }
        
        BLYPlaylist *playlist = results[@"playlist"];
        
        playlist = [playlist playlistByRemovingDuplicatedSongs];
        
        // Playlist is empty
        if ([playlist nbOfSongs] == 0) {
            return [weakSelf handleNoResults:@"songs"];
        }
        
        _songsAreLoaded = YES;
        
        weakSelf.playlist = playlist;
        
        if (!loadYoutubeChannel) {
            weakSelf.playlists[@"songs"] = playlist;
        } else {
            weakSelf.playlists[@"videos"] = playlist;
        }
        
        // If current search song was not in cache
        if (!weakSelf.currentSearchSong || force) {
            BLYSearchSong *searchSong = weakSelf.currentSearchSong;
//            if (weakSelf.currentSearchSong && force) {
//                [[BLYSearchSongsStore sharedStore] deleteSearchSong:weakSelf.currentSearchSong];
//            }
            
            if (!searchSong) {
                searchSong = [[BLYSearchSongsStore sharedStore] insertSongsSearchWithSearch:weakSelf.currentSearch
                                                                          andSearchedArtist:searchedArtist
                                                                                   withType:searchedArtist ? @"artist" : nil
                                                                                  butHideIt:YES]; // Wait before user play track to display it in search history
            }
            
            [[BLYSearchSongsStore sharedStore] insertSongSearch:searchSong
                                                       forSongs:weakSelf.playlist.songs];
            
//            if (force && weakSelf.currentSearchSong) {
//                [[BLYSearchSongsStore sharedStore] insertSongSearch:searchSong
//                                                           forAlbums:[[weakSelf.currentSearchSong.albums array] mutableCopy]];
//
//                [[BLYSearchSongsStore sharedStore] insertSongSearch:searchSong
//                                                          forVideos:[[weakSelf.currentSearchSong.videos array] mutableCopy]];
//            }
            
            weakSelf.currentSearchSong = searchSong;
        }
        
        if (!loadYoutubeChannel) {
            weakSelf.resultsTypeSegmentedControl.superview.hidden = NO;
        } else {
            [weakSelf.resultsTypeSegmentedControl.superview removeFromSuperview];
            weakSelf.resultsTypeSegmentedControl = nil;
            
            weakSelf.resultsContainerTopConstraint.constant = 0.0;
        }
        
        if (byPullToRefresh) {
            endRefreshingBlock(nil);
        } else {
            [weakSelf.songsList reloadData];
            
            [weakSelf scrollSongsListToTop];
            
            [weakSelf addRefreshControlTo:@"songs"];
        }
        
        BLYSearchSong *searchSong = weakSelf.currentSearchSong;
        
        // Select the last specified segment if any
        if ([searchSong.lastSelectedSegment intValue] == _videosSegment) {
            [weakSelf loadVideosForCurrentSearchForce:NO byPullToRefresh:NO];
        } else {
            weakSelf.resultsContainer.hidden = NO;
            weakSelf.songsList.hidden = NO;
            weakSelf.albumResults.hidden = YES;
            weakSelf.errorView.hidden = YES;
        }
    };
    
    void (^completionForImg)(BOOL hasDownloaded, BLYSong *song) = ^(BOOL hasDownloaded, BLYSong *song){
        if (!hasDownloaded) {
            return;
        }
        
        NSInteger indexOfSong = [weakSelf.playlist indexOfSong:song];
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:indexOfSong
                                                    inSection:0];
        
        // Race condition called after user changed results type
        if (weakSelf.playlist != weakSelf.playlists[@"songs"]) {
            return;
        }
        
        if ([weakSelf.songsList.indexPathsForVisibleRows containsObject:indexPath]) {
            [weakSelf.songsList beginUpdates];
            [weakSelf.songsList reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
            [weakSelf.songsList endUpdates];
        }
    };
    
    BLYSearchSongsStore *searchSongsStore = [BLYSearchSongsStore sharedStore];
    BLYSearchSong *searchSong = nil;
    
    // Called from artist link in player VC
    if (searchedArtistSong) {
        searchSong = [searchSongsStore fetchSearchSongWithArtist:searchedArtist];
        
        //[searchSongsStore clearHiddenSongSearchsExcept:searchSong];
    } else  {
        searchSong = [searchSongsStore fetchSearchSongWithSearch:self.currentSearch];
    }
    
    if (searchSong && !force) {
        NSMutableDictionary *results = [[NSMutableDictionary alloc] init];
        BLYPlaylist *playlist = [[BLYPlaylist alloc] init];
        
        weakSelf.currentSearchSong = searchSong;
        
        for (BLYSong *song in [searchSong songs]) {
            [playlist addSong:song];
        }
        
//        if (!searchedArtistSong) {
//            [searchSongsStore updateSearchedAtDateOfSearchSong:searchSong];
//        }
        
        results[@"playlist"] = playlist;
        
        if ([searchSong.type isEqualToString:@"artist"]) {
            results[@"searchedArtist"] = searchSong.artist;
        }
        
        if ([searchSong.type isEqualToString:@"album"]) {
            results[@"searchedAlbum"] = [searchSong.albums objectAtIndex:0];
        }
        
        if (searchSong.type) {
            results[@"searchType"] = searchSong.type;
        }
        
        completionBlock(results, nil);
    } else {
        BLYSearchSongResultsStore *resultsStore = [BLYSearchSongResultsStore sharedStore];
        BLYAppDelegate *appDelegate = (BLYAppDelegate *)[[UIApplication sharedApplication] delegate];
        
        resultsStore.searchSongResultsVC = self;
        
        // Load YouTube Channel for current played video
        if (loadYoutubeChannel) {
            BLYAppDelegate *appDelegate = (BLYAppDelegate *)[[UIApplication sharedApplication] delegate];
            NSString *country = [appDelegate countryCodeForCurrentLocale];
            
            [[BLYVideoStore sharedStore] fetchVideosForQuery:nil
                                                   orChannel:searchedArtist.sid
                                                  andCountry:country
                                              withCompletion:completionBlock
                                         andCompletionForImg:completionForImg];
            
            return;
        }
        
        [resultsStore fetchSearchResultsForCountry:[appDelegate countryCodeForCurrentLocale]
                                         withQuery:self.currentSearch
                                          orArtist:searchedArtist
                                     andCompletion:completionBlock
                               andCompletionForImg:completionForImg];
    }
}

- (void)loadAlbumsForCurrentSearchForce:(BOOL)force byPullToRefresh:(BOOL)byPullToRefresh
{
    __weak BLYSearchSongResultsViewController *weakSelf = self;
    
    self.albumsAreLoading = YES;
    
    void (^endRefreshingBlock)(NSError *err) = ^(NSError *err) {
        if (!err) {
            [weakSelf.albumResults reloadData];
        }
        
        [[NSOperationQueue currentQueue] addOperationWithBlock:^{
            [[self refreshControlForAlbums] endRefreshing];
        }];
    };
    
    void (^completionForAlbums)(NSMutableArray *albums, NSError *err) = ^(NSMutableArray *albums, NSError *err) {
        weakSelf.albumsAreLoading = NO;
        weakSelf.albumsAreLoaded = YES;
        
        weakSelf.albumsAreLoadedWithError = !!err;
        weakSelf.albumsLoadingErr = err;
        
        if (err) {
            if (byPullToRefresh) {
                endRefreshingBlock(err);
            }
            
            weakSelf.errorViewLabel.text = err.localizedDescription;
            weakSelf.errorView.hidden = NO;
            
            return;
        }
        
        weakSelf.albums = albums;
        
        if ([albums count] == 0) {
            return [weakSelf handleNoResults:@"albums"];
        }
        
        if (![weakSelf.currentSearchSong.albums count] || force) {
            [[BLYSearchSongsStore sharedStore] insertSongSearch:weakSelf.currentSearchSong
                                                      forAlbums:albums];
        }
        
        weakSelf.resultsTypeSegmentedControl.selectedSegmentIndex = _albumsSegment;
        weakSelf.resultsTypeSegmentedControl.superview.hidden = NO;
        
        if (byPullToRefresh) {
            endRefreshingBlock(nil);
        } else {
            [weakSelf.albumResults reloadData];
            
            [weakSelf scrollSongsListToTop];
        }
        
        weakSelf.resultsContainer.hidden = NO;
        weakSelf.songsList.hidden = YES;
        weakSelf.errorView.hidden = YES;
        
        [weakSelf addRefreshControlTo:@"albums"];
    };
    
    void (^completionForImg)(BOOL hasDownloaded, BLYAlbum *album) = ^(BOOL hasDownloaded, BLYAlbum *album){
        NSInteger indexOfSong = [weakSelf.albums indexOfObject:album];
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:indexOfSong
                                                    inSection:0];
        
        if (weakSelf.albumHighLighted) {
            weakSelf.albumHighLightedWhenDataWasReloaded = YES;
            
            return;
        }
        
        if (!hasDownloaded) {
            return;
        }
        
        if ([weakSelf.albumResults.indexPathsForVisibleItems containsObject:indexPath]) {
            [weakSelf.albumResults reloadItemsAtIndexPaths:@[indexPath]];
        }
    };
    
    if ([self.currentSearchSong.albums count] > 0 && !force) {
        NSOrderedSet *albumsAsSet = self.currentSearchSong.albums;
        NSMutableArray *albums = [[NSMutableArray alloc] init];
        
        for (BLYAlbum *album in albumsAsSet) {
            [albums addObject:album];
            
//            // Retry to load missing thumbnail
//            if (!album.thumbnail
//                // URL was addded in version 1.1
//                && album.privateThumbnail.url) {
//                NSURL *url = [NSURL URLWithString:album.privateThumbnail.url];
//                
//                [[BLYSongStore sharedStore] loadThumbnailWithURL:url
//                                                        forAlbum:album
//                                             withCompletionBlock:^{
//                                                 completionForImg();
//                                             }];
//            }
        }
        
        completionForAlbums(albums, nil);
    } else {
        BLYArtist *artist = self.currentSearchSong.artist;
        int artistID = [artist.sid intValue];
        
        NSString *country = artist.country;
        NSString *search = self.currentSearchSong.search;
        
        BLYAppDelegate *appDelegate = (BLYAppDelegate *)[[UIApplication sharedApplication] delegate];
        
        if (!country) {
            country = [appDelegate countryCodeForCurrentLocale];
        }
        
        // User search a track ? search album of the track
        if ([self.playlist nbOfSongs] == 1) {
            BLYSong *s = [self.playlist songAtIndex:0];
            
            search = [NSString stringWithFormat:@"%@ %@", s.artist.name, s.album.name];
        }
        
        self.launchedConnection = [[BLYSearchSongResultsStore sharedStore] fetchAlbumsForArtist:artistID
                                                                                       orSearch:search
                                                                                     andCountry:country
                                                                                 withCompletion:completionForAlbums
                                                                            andCompletionForImg:completionForImg];
    }
}

- (void)loadVideosForCurrentSearchForce:(BOOL)force byPullToRefresh:(BOOL)byPullToRefresh
{
    __weak BLYSearchSongResultsViewController *weakSelf = self;
    BLYSearchSong *searchSong = self.currentSearchSong;
    
    self.videosAreLoading = YES;
    
    void (^endRefreshingBlock)(NSError *err) = ^(NSError *err) {
        if (!err) {
            [weakSelf.songsList reloadData];
        }
        
        [[weakSelf refreshControlForSongsAndVideos] endRefreshing];
    };
    
    void (^completionBlock)(NSMutableDictionary *results, NSError *err) = ^(NSMutableDictionary *results, NSError *err) {
        weakSelf.videosAreLoading = NO;
        weakSelf.videosAreLoaded = YES;
        weakSelf.videosAreLoadedWithError = !!err;
        weakSelf.videosLoadingErr = err;
        
        if (err) {
            if (byPullToRefresh) {
                endRefreshingBlock(err);
            }
            
            weakSelf.errorViewLabel.text = err.localizedDescription;
            weakSelf.errorView.hidden = NO;
            
            return;
        }
        
        BLYPlaylist *playlist = results[@"playlist"];
        
        // Playlist is empty
        if ([playlist nbOfSongs] == 0) {
            return [weakSelf handleNoResults:@"videos"];
        }
        
        weakSelf.playlists[@"videos"] = playlist;
        weakSelf.playlist = playlist;
        
        BLYSearchSong *searchSong = weakSelf.currentSearchSong;
        
        // Empty playlist for tracks = not loaded from player VC
        if (!searchSong) {
            searchSong = [[BLYSearchSongsStore sharedStore] insertSongsSearchWithSearch:weakSelf.currentSearch
                                                                      andSearchedArtist:nil
                                                                               withType:nil
                                                                              butHideIt:YES];
        
            weakSelf.currentSearchSong = searchSong;
        }
        
        if ([searchSong.videos count] == 0 || force) {
            [[BLYSearchSongsStore sharedStore] insertSongSearch:searchSong
                                                      forVideos:weakSelf.playlist.songs];
        }
        
        weakSelf.resultsTypeSegmentedControl.selectedSegmentIndex = _videosSegment;
        weakSelf.resultsTypeSegmentedControl.superview.hidden = NO;
        
        if (byPullToRefresh) {
            endRefreshingBlock(nil);
        } else {
            [weakSelf.songsList reloadData];
            
            [weakSelf scrollSongsListToTop];
            
            [weakSelf addRefreshControlTo:@"videos"];
        }
        
        weakSelf.resultsContainer.hidden = NO;
        weakSelf.songsList.hidden = NO;
        
        weakSelf.errorView.hidden = YES;
        weakSelf.albumResults.hidden = YES;
    };
    
    void (^completionForImg)(BOOL hasDownloaded, BLYSong *song) = ^(BOOL hasDownloaded, BLYSong *song){
        if (!hasDownloaded) {
            return;
        }
        
        NSInteger indexOfSong = [weakSelf.playlist indexOfSong:song];
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:indexOfSong
                                                    inSection:0];
        
        // Race condition called after user changed results type
        if (weakSelf.playlist != weakSelf.playlists[@"videos"]) {
            return;
        }
        
        if ([weakSelf.songsList.indexPathsForVisibleRows containsObject:indexPath]) {
            [weakSelf.songsList beginUpdates];
            [weakSelf.songsList reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
            [weakSelf.songsList endUpdates];
        }
    };
    
    if ([searchSong.videos count] > 0 && !force) {
        NSMutableDictionary *results = [[NSMutableDictionary alloc] init];
        BLYPlaylist *playlist = [[BLYPlaylist alloc] init];
        
        for (BLYSong *song in [searchSong videos]) {
            [playlist addSong:song];
        }
        
        results[@"playlist"] = playlist;
        
        completionBlock(results, nil);
    } else {
        BLYAppDelegate *appDelegate = (BLYAppDelegate *)[[UIApplication sharedApplication] delegate];
        NSString *country = [appDelegate countryCodeForCurrentLocale];
        NSString *search = searchSong.search;
        
        // Empty playlist for tracks
        if (!search) {
            search = self.currentSearch;
        }
        
        self.launchedConnection = [[BLYVideoStore sharedStore] fetchVideosForQuery:search
                                                                         orChannel:nil
                                                                        andCountry:country
                                                                    withCompletion:completionBlock
                                                               andCompletionForImg:completionForImg];
    }
}


- (void)handleNoResults:(NSString *)type
{
    if ([type isEqualToString:@"songs"]) {
        return [self loadVideosForCurrentSearchForce:NO byPullToRefresh:NO];
    } else if ([type isEqualToString:@"videos"]) {
        self.noResultsView.hidden = NO;
    } else if ([type isEqualToString:@"albums"]) {
        self.noResultsView.hidden = NO;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)setCurrentSearch:(NSString *)currentSearch
{
    _currentSearch = [[currentSearch lowercaseString] bly_stringByRemovingAccents];
    
    //[[self navigationItem] setTitle:currentSearch];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    BLYSong *song = [self.playlist songAtIndex:indexPath.row];
    
    [self handleSongHasBeenChosen:song andItsCurrentSong:NO];
    
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (void)handleSongHasBeenChosen:(BLYSong *)song andItsCurrentSong:(BOOL)itsCurrentSong
{
    BLYPlayerViewController *playerVC = self.playerVC;
    
    // Dismiss search bar when user play a song
    if (self.searchSongVC && ![self.searchSongVC searchBarIsEmpty]) {
        [self.searchSongVC dismissSearchBar:nil];
        
        self.searchSongVC.searchBarEmptiedBySearchResultsVC = true;
    }
    
    // Update last selected segment if controller is not loaded from player
    // And if song is not currently played (toggle play/pause)
    if (!self.currentSearchedArtist
        && ((!itsCurrentSong && ![playerVC isCurrentSong:song])
            || (itsCurrentSong && [playerVC isCurrentSong:song]))) {
        
        [self updateSearchSongLastSelectedSegmentAndSelectedAlbumIndex:NSNotFound];
    }
    
    if (self.searchSongVC) {
        [[BLYSearchSongsStore sharedStore] setHidden:NO forSearchSong:self.currentSearchSong];
        [[BLYSearchSongsStore sharedStore] updateSearchedAtDateOfSearchSong:self.currentSearchSong];
        
        self.searchSongVC.songSelectedInSearchResultsVC = true;
    }
}

- (void)updateSearchSongLastSelectedSegmentAndSelectedAlbumIndex:(NSInteger)index
{
    NSInteger selectedSegment = self.resultsTypeSegmentedControl.selectedSegmentIndex;
    
    [[BLYSearchSongsStore sharedStore] setLastSelectedSegment:selectedSegment
                                                forSearchSong:self.currentSearchSong];
    
    [[BLYSearchSongsStore sharedStore] setLastSelectedAlbum:index
                                              forSearchSong:self.currentSearchSong];
}

- (IBAction)changeResultsType:(id)sender
{
    UISegmentedControl *segmentedControl = sender;
    NSInteger selectedIndex = segmentedControl.selectedSegmentIndex;
    
    self.errorView.hidden = YES;
    
    // Titles
    if (selectedIndex == _tracksSegment) {
        if (self.songsAreLoadedWithError) {
            self.errorViewLabel.text = self.songsLoadingErr.localizedDescription;
            self.errorView.hidden = NO;
        } else {
            self.playlist = self.playlists[@"songs"];
            [self.songsList reloadData];
            
            [self updateSongsListContentOffset];
            
            self.resultsContainer.hidden = NO;
            self.songsList.hidden = NO;
            
            self.noResultsView.hidden = YES;
        }
    } else if (selectedIndex == _albumsSegment) {
        self.resultsContainer.hidden = NO;
        
        if (!self.albumsAreLoaded) {
            self.resultsContainer.hidden = YES;
            
            if (!self.albumsAreLoading) {
                [self loadAlbumsForCurrentSearchForce:NO byPullToRefresh:NO];
            }
        } else {
            if (self.albumsAreLoadedWithError) {
                self.errorView.hidden = NO;
                self.errorViewLabel.text = self.albumsLoadingErr.localizedDescription;
            } else {
                self.noResultsView.hidden = [self.albums count] > 0;
                
                [self updateSongsListContentOffset];
            }
        }
        
        self.albumResults.hidden = NO;
        self.songsList.hidden = YES;
    } else if (selectedIndex == _videosSegment) { // Videos
        self.resultsContainer.hidden = NO;
        
        if (!self.videosAreLoaded) {
            self.resultsContainer.hidden = YES;
            
            if (!self.videosAreLoading) {
                [self loadVideosForCurrentSearchForce:NO byPullToRefresh:NO];
            }
        } else {
            if (_videosAreLoadedWithError) {
                self.errorView.hidden = NO;
                self.errorViewLabel.text = self.videosLoadingErr.localizedDescription;
            } else {
                self.noResultsView.hidden = [(BLYPlaylist *)self.playlists[@"videos"] nbOfSongs] > 0;
                
                self.playlist = self.playlists[@"videos"];
                
                [self.songsList reloadData];
                
                [self updateSongsListContentOffset];
            }
        }
        
        self.albumResults.hidden = YES;
        self.songsList.hidden = NO;
        self.noResultsView.hidden = YES;
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [super tableView:tableView numberOfRowsInSection:section];
}

- (void)handleRefresh:(UIRefreshControl *)refreshControl {
    UISegmentedControl *segmentedControl = self.resultsTypeSegmentedControl;
    NSInteger selectedIndex = segmentedControl.selectedSegmentIndex;
    
    if (!segmentedControl || selectedIndex == _videosSegment) {
        [self loadVideosForCurrentSearchForce:YES byPullToRefresh:YES];
    } else if (selectedIndex == _tracksSegment) {
        [self loadSongsForCurrentSearchForce:YES byPullToRefresh:YES];
    } else {
        [self loadAlbumsForCurrentSearchForce:YES byPullToRefresh:YES];
    }
}

- (void)addRefreshControlTo:(NSString *)to
{
    UIRefreshControl *rc = [[UIRefreshControl alloc] init];
    
    [rc addTarget:self
           action:@selector(handleRefresh:)
 forControlEvents:UIControlEventValueChanged];
    
    rc.tintColor = [UIColor blackColor];
    
    if ([to isEqualToString:@"videos"] || [to isEqualToString:@"songs"]) {
        if (self.refreshControlForSongsAndVideos) {
            return;
        }
        
        [self.songsList addSubview:rc];
        [self.songsList sendSubviewToBack:rc];
        
        self.refreshControlForSongsAndVideos = rc;
    } else {
        if (self.refreshControlForAlbums) {
            return;
        }
        
        [self.albumResults addSubview:rc];
        [self.albumResults sendSubviewToBack:rc];
        
        // Make sure activity indicator is displayed even if
        // the collection view does not fill up the height of its parent container.
        // https://stackoverflow.com/questions/14678727/uirefreshcontrol-on-uicollectionview-only-works-if-the-collection-fills-the-heig
        self.albumResults.alwaysBounceVertical = YES;
        
        self.refreshControlForAlbums = rc;
    }
}

- (void)observeValueForKeyPath:(NSString*)keyPath
                      ofObject:(id)object
                        change:(NSDictionary*)change
                       context:(void*)context
{
    UIView* viewToObserve = self.resultsContainer;
    
    // When results container is displayed
    if (object == viewToObserve) {
        if ([keyPath isEqualToString:@"hidden"]
            && !viewToObserve.hidden) {
            
            // Only videos
            if (self.playlists[@"songs"] == nil
                && self.playlists[@"videos"] != nil) {
                
                self.resultsTypeSegmentedControl.superview.hidden = YES;
                self.resultsContainerTopConstraint.constant = 0.0;
                
                [self normalNavigationBar];
            } else { // Tracks albums videos
                if ([self.playlists[@"songs"] nbOfSongs] == 1 && _albumsSegment != -1) {
                    NSInteger selectedSegment = self.resultsTypeSegmentedControl.selectedSegmentIndex;
                    
                    // Remove current selection before removing segment to enable selecting segment afterwards
                    // iOS bug ?!
                    self.resultsTypeSegmentedControl.selectedSegmentIndex = UISegmentedControlNoSegment;
                    
                    [self.resultsTypeSegmentedControl removeSegmentAtIndex:_albumsSegment animated:NO];
                    
                    _videosSegment = _albumsSegment;
                    _albumsSegment = -1;
                    
                    if (selectedSegment == _tracksSegment) {
                        self.resultsTypeSegmentedControl.selectedSegmentIndex = _tracksSegment;
                    } else {
                        self.resultsTypeSegmentedControl.selectedSegmentIndex = _videosSegment;
                    }
                }
                
                self.resultsTypeSegmentedControl.superview.hidden = NO;
                self.resultsContainerTopConstraint.constant = 38.0;
                
                [self extendedNavigationBar];
            }
        }
    }
}

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    [super motionEnded:motion withEvent:event];
}

- (BLYSong *)handleLoadRandomPlaylistOnShake
{
    BLYSong *loadedSong = [super handleLoadRandomPlaylistOnShake];
    
    if (!loadedSong) {
        return loadedSong;
    }
    
    // Song was loaded by super class so its current song
    [self handleSongHasBeenChosen:loadedSong
                andItsCurrentSong:YES];
    
    return loadedSong;
}

- (void)dealloc
{
    UIView* viewToObserve = self.resultsContainer;
    
    [viewToObserve removeObserver:self forKeyPath:@"hidden"];
}

@end
