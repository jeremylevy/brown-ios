//
//  BLYTopSongsViewController.m
//  Brown
//
//  Created by Jeremy Levy on 19/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import "BLYExternalTopSongViewController.h"
#import "BLYPlaylistSongCell.h"
#import "BLYSong.h"
#import "BLYPlaylist.h"
#import "BLYExternalTopSongStore.h"
#import "BLYExternalTopSong.h"
#import "BLYExternalTopSongCountry.h"
#import "BLYPlayerViewController.h"
#import "BLYErrorStore.h"
#import "BLYAppDelegate.h"
#import "BLYPlayedSongStore.h"
#import "BLYCachedSongStore.h"
#import "BLYAppDelegate.h"
#import "BLYStore.h"
#import "BLYNetworkStore.h"

@interface BLYExternalTopSongViewController ()

@property (strong, nonatomic) NSString *firstCountry;
@property (strong, nonatomic) NSString *secondCountry;
@property (strong, nonatomic) UIRefreshControl *refreshControl;

@end

@implementation BLYExternalTopSongViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self) {
        UIImage *externalTopSongsTabBarIcon = [UIImage imageNamed:@"ExternalTopSongsTabBarIcon"];
        UIImage *externalTopSongsSelectedTabBarIcon = [UIImage imageNamed:@"ExternalTopSongsSelectedTabBarIcon"];
        
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@""
                                                        image:externalTopSongsTabBarIcon
                                                selectedImage:externalTopSongsSelectedTabBarIcon];
        
        self.tabBarItem.tag = 2;
        
        self.navigationItem.title = NSLocalizedString(@"external_top_songs_navigation_item_title", nil);
        
        BLYAppDelegate *appDelegate = (BLYAppDelegate *)[[UIApplication sharedApplication] delegate];
        
        _currentCountry = [appDelegate countryCodeForCurrentLocale];
        _firstCountry = [_currentCountry copy];
        _secondCountry = @"us";
        
        if ([_firstCountry isEqualToString:@"us"]) {
            _secondCountry = @"gb";
        }
        
        _playlists = [[NSMutableDictionary alloc] init];
        _playlistScrolls = [[NSMutableDictionary alloc] init];
        
        _playlistScrolls[_firstCountry] = [NSValue valueWithCGPoint:CGPointZero];
        _playlistScrolls[_secondCountry] = [NSValue valueWithCGPoint:CGPointZero];
        _playlistScrolls[@"youtube"] = [NSValue valueWithCGPoint:CGPointZero];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(playerDidTerminateBGWork:)
                                                     name:BLYPlayerViewControllerDidTerminateBGWorkNotification
                                                   object:nil];
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    BLYAppDelegate *appDelegate = (BLYAppDelegate *)[[UIApplication sharedApplication] delegate];
    UISegmentedControl *countryChoice = self.songsCountryChoice;
    
    UIFont *font = [UIFont boldSystemFontOfSize:16.0f];
    
    [countryChoice setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor blackColor], NSFontAttributeName: font}
                       forState:UIControlStateSelected];
    
    [countryChoice setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor colorWithWhite:0.4 alpha:1.0]}
                       forState:UIControlStateNormal];
    
    [countryChoice setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor colorWithWhite:0.2 alpha:1.0]}
                       forState:UIControlStateDisabled];
    
    NSString *firstSegmentTitle = [appDelegate countryNameForCountryCode:self.firstCountry];
    NSString *secondSegmentTitle = [appDelegate countryNameForCountryCode:self.secondCountry];
    
    [countryChoice setTitle:firstSegmentTitle
        forSegmentAtIndex:0];
    
    [countryChoice setTitle:secondSegmentTitle
          forSegmentAtIndex:1];
    
    [countryChoice setTitle:NSLocalizedString(@"external_top_songs_youtube_country_name", nil)
          forSegmentAtIndex:2];
    
    NSArray *playedSongs = [[BLYPlayedSongStore sharedStore] fetchPlayedSongs];
    NSArray *cachedSongs = [[BLYCachedSongStore sharedStore] fetchCachedSongs];
    
    if ([playedSongs count] > 0 || [cachedSongs count] > 0) {
        self.tabBarController.selectedIndex = BLYBaseTabBarControllerPlayedSongsIndex;
    }
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    
    [self.refreshControl addTarget:self
                            action:@selector(handleRefresh:)
                  forControlEvents:UIControlEventValueChanged];
    
    self.refreshControl.tintColor = [UIColor blackColor];
    
    [self.songsList addSubview:self.refreshControl];
    [self.songsList sendSubviewToBack:self.refreshControl];
    
    [self extendedNavigationBar];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    if ([self.playlistScrolls count] > 0) {
        return;
    }
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    [self.view layoutSubviews];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Maybe updated in bg
    [self reloadData:NO];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self saveSongsListContentOffset];
}

- (void)playerDidTerminateBGWork:(NSNotification *)notification
{
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
        [self reloadData:NO];
    }
}

- (void)pullToRefreshAction
{
    [self reloadData:YES];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BLYPlaylist *)playlist
{
    return self.playlists[self.currentCountry];
}

- (void)handleRefresh:(UIRefreshControl *)refreshControl {
    [self reloadData:YES];
}

- (void)reloadData:(BOOL)forceRefresh
{
    BOOL loadedFromBackground = NO;
    NSString *country = self.currentCountry;
    NSMutableDictionary *playlists = self.playlists;
    __weak BLYExternalTopSongViewController *weakSelf = self;
    
    __block BOOL endRefreshingIsTerminated = NO;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL firstLoad = [defaults boolForKey:BLYStoreFirstLoadUserDefaultsKey];
    
    // Update "updated at" for all countries at first app launch
    if (firstLoad) {
        NSArray *countries = [[BLYExternalTopSongStore sharedStore] externalTopSongCountries];
        
        for (BLYExternalTopSongCountry *externalTopSongCountry in countries) {
            externalTopSongCountry.updatedAt = [NSDate date];
        }
        
        [[BLYStore sharedStore] saveChanges];
        
        [defaults setBool:NO forKey:BLYStoreFirstLoadUserDefaultsKey];
    }
    
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
        if (![[BLYNetworkStore sharedStore] networkIsReachable]) {
            return;
        }
        
        for (NSString *countryDisplayed in @[self.firstCountry, self.secondCountry, @"youtube"]) {
            BLYExternalTopSongCountry *topSongCountry = [[BLYExternalTopSongStore sharedStore] externalTopSongsForCountry:countryDisplayed];
            
            NSTimeInterval cacheAge = [topSongCountry.updatedAt timeIntervalSinceNow];
            
            if (cacheAge <= - BLYExternalTopSongsStoreCacheDuration) {
                forceRefresh = true;
                country = countryDisplayed;
                loadedFromBackground = true;
                
                break;
            }
        }
        
        if (!forceRefresh) {
            return;
        }
    }
    
    if (!playlists[country] || forceRefresh) {
        void (^completionBlock)(BLYPlaylist *playlist, NSError *err) = ^(BLYPlaylist *playlist, NSError *err) {
            if (loadedFromBackground) {
                return;
            }
            
            // Race condition called after user changed country
            if (![country isEqualToString:weakSelf.currentCountry]) {
                return;
            }
            
            if (err) {
                // [weakSelf.refreshControl endRefreshing];
                
                [[BLYErrorStore sharedStore] manageError:err forViewController:self withCompletionAfterAlertViewWasDismissed:^{
                    [weakSelf.refreshControl endRefreshing];
                }];
                
                return;
            }
            
            if ([playlist nbOfSongs] == 0) {
                return;
            }
            
            playlists[country] = playlist;
            
            [weakSelf.songsList reloadData];
            [[NSOperationQueue currentQueue] addOperationWithBlock:^{
                [[weakSelf refreshControl] endRefreshing];
            }];
            
//            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
//                [CATransaction begin];
//                [CATransaction setCompletionBlock:^{
//                    endRefreshingIsTerminated = YES;
//
//                    [weakSelf.songsList reloadData];
//                }];
//
//                [[weakSelf refreshControl] endRefreshing];
//
//                [CATransaction commit];
//            }];
            
            if (!forceRefresh) {
                [weakSelf resetContentOffset];
            }
        };
        void (^completionForImg)(BOOL hasDownloaded, BLYSong *song) = ^(BOOL hasDownloaded, BLYSong *song){
            if (loadedFromBackground) {
                return;
            }
            
            if (!hasDownloaded) {
                return;
            }
            
            NSInteger indexOfSong = [weakSelf.playlist indexOfSong:song];
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:indexOfSong
                                                        inSection:0];
            
            // Race condition called after user changed country (so self.playlist is not the same)
            if (![country isEqualToString:weakSelf.currentCountry]) {
                return;
            }
            
            if ([weakSelf.songsList.indexPathsForVisibleRows containsObject:indexPath]) {
                [weakSelf.songsList beginUpdates];
                [weakSelf.songsList reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
                [weakSelf.songsList endUpdates];
            }
        };
        
        [[BLYExternalTopSongStore sharedStore] fetchTopSongsForCountry:country
                                                                 limit:50
                                                                 force:forceRefresh
                                                        withCompletion:completionBlock
                                                   andCompletionForImg:completionForImg];
    } else {
        [self.songsList reloadData];
        
        [self resetContentOffset];
    }
}

- (void)saveSongsListContentOffset
{
    NSValue *contentOffsetValue = [NSValue valueWithCGPoint:self.songsList.contentOffset];
    
    [self.playlistScrolls setObject:contentOffsetValue
                             forKey:self.currentCountry];
}

- (void)resetContentOffset
{
    NSValue *contentOffsetValue = [self.playlistScrolls objectForKey:self.currentCountry];
    CGPoint contentOffset = contentOffsetValue.CGPointValue;
    
    self.songsList.contentOffset = contentOffset;
}

- (IBAction)changeCountry:(id)sender
{
    NSInteger selectedSegment = [sender selectedSegmentIndex];
    
    [self saveSongsListContentOffset];
    
    if (selectedSegment == 0) {
        self.currentCountry = self.firstCountry;
    } else if (selectedSegment == 1) {
        self.currentCountry = self.secondCountry;
    } else {
        self.currentCountry = @"youtube";
    }
    
    [self reloadData:NO];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
