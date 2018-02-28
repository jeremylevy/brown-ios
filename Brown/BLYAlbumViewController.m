//
//  BLYAlbumViewController.m
//  Brown
//
//  Created by Jeremy Levy on 02/10/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import "BLYAlbumViewController.h"
#import "BLYAlbum.h"
#import "BLYAlbumStore.h"
#import "BLYArtist.h"
#import "BLYArtistSong.h"
#import "BLYPlaylist.h"
#import "BLYSong.h"
#import "BLYPlaylistSongCell.h"
#import "BLYErrorStore.h"
#import "BLYSearchSongViewController.h"
#import "BLYSearchSongResultsViewController.h"
#import "BLYSearchSongsStore.h"
#import "NSString+Escaping.h"
#import "BLYAlbumHeaderInfoView.h"
#import "BLYAlbumNavItemTitleView.h"
#import "BLYSongCachingStore.h"
#import "BLYCachedSongStore.h"

@interface BLYAlbumViewController ()

@property (strong, nonatomic) UIColor *albumSongsListBGColor;
@property (nonatomic) CGPoint baseContentOffset;

@end

@implementation BLYAlbumViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self) {
        _albumSongsListBGColor = [UIColor colorWithRed:248 / 255.f
                                                 green:248 / 255.f
                                                  blue:248 / 255.f
                                                 alpha:1.0];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleAlbumWasCached:)
                                                     name:BLYCachedSongStoreDidCacheAlbum
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleAlbumWasUncached:)
                                                     name:BLYCachedSongStoreDidUncacheAlbum
                                                   object:nil];
    }
    
    return self;
}

- (CGPoint)baseContentOffset
{
    return CGPointMake(0.0, 0.0);
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.songsList.backgroundColor = [UIColor whiteColor];
    self.loadingTextLabel.text = NSLocalizedString(@"view_controller_main_loading_text", nil);
    
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
    
//    [self.headerView.realView.cacheSwitch addTarget:self
//                                             action:@selector(handleCacheSwitchChange:)
//                                   forControlEvents:UIControlEventValueChanged];
    
    if (!self.loadedAlbumSid) {
        [NSException raise:@"BLYAlbumViewController didn't load"
                    format:@"Reason: self.loadedAlbumSid is not set."];
    }
    
    [self loadAlbum];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    // Fix nav bar bottom border wrong offset
    // when returning from full screen
    [self normalNavigationBar];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self normalNavigationBar];
    
    if ([self.playlist nbOfSongs] > 0) {
        //[self extendedNavigationBar];
    }
}

- (void)retryLoading:(UIButton *)button
{
    _errorView.hidden = YES;
    
    [self loadAlbum];
}

- (void)loadAlbum
{
    __weak BLYAlbumViewController *weakSelf = self;
    
    BLYAlbumNavItemTitleView *titleView = [[[NSBundle mainBundle] loadNibNamed:@"BLYAlbumNavItemTitleView" owner:nil options:nil] objectAtIndex:0];
    
    void (^completionBlock)(BLYAlbum *album, NSError *err) = ^(BLYAlbum *album, NSError *err) {
        if (err) {
            weakSelf.errorViewLabel.text = err.localizedDescription;
            weakSelf.errorView.hidden = NO;
            
            return;
        }
        
        if (!album) {
            weakSelf.errorViewLabel.text = NSLocalizedString(@"album_not_found_error", nil);
            weakSelf.errorView.hidden = NO;
            
            return;
        }
        
        BLYPlaylist *playlist = [[BLYPlaylist alloc] init];
        NSString *releaseDateString = [NSDateFormatter localizedStringFromDate:album.releaseDate
                                                                     dateStyle:NSDateFormatterMediumStyle
                                                                     timeStyle:NSDateFormatterNoStyle];
        
        //        NSString *nbOfSongs = [NSString stringWithFormat:NSLocalizedString(@"album_nb_of_tracks", nil), (int)[album.songs count]];
        NSString *releaseDate = [NSString stringWithFormat:NSLocalizedString(@"album_release_date", nil), releaseDateString];
        
        titleView.albumName.text = album.name;
        titleView.albumInfos.text = releaseDate;
        
        weakSelf.navigationItem.titleView = titleView;
        
//        weakSelf.headerView.realView.trackNbLabel.text = [NSString stringWithFormat:NSLocalizedString(@"album_nb_of_tracks", nil), [album.songs count]];
        
        BLYSearchSong *searchSong = [[BLYSearchSongsStore sharedStore] fetchSearchSongWithAlbum:album];
        
        if (!searchSong) {
            NSString *search = [NSString stringWithFormat:@"%@ %@", album.artist.name, album.name];
            
            search = [search bly_stringByRemovingParenthesisAndBracketsContent];
            search = [search bly_stringByRemovingAccents];
            search = [search bly_stringByRemovingNonAlphanumericCharacters];
            search = [search lowercaseString];
            
            BLYSearchSong *searchSong = [[BLYSearchSongsStore sharedStore] insertSongsSearchWithSearch:search
                                                                                     andSearchedArtist:nil
                                                                                              withType:@"album"
                                                                                             butHideIt:YES];
            NSMutableArray *albums = [NSMutableArray arrayWithObject:album];
            
            [[BLYSearchSongsStore sharedStore] insertSongSearch:searchSong
                                                      forAlbums:albums];
        }
        
        NSMutableArray *songs = [[album.songs allObjects] mutableCopy];
        NSSortDescriptor *sortDescriptior = [NSSortDescriptor sortDescriptorWithKey:@"rankInAlbum" ascending:YES];
        
        [songs sortUsingDescriptors:@[sortDescriptior]];
        
        playlist.isAnAlbumPlaylist = YES;
        playlist.songs = songs;
        
        weakSelf.playlist = playlist;
        
        // [weakSelf updateHeaderViewCacheSwitch];
        
        [weakSelf.songsList reloadData];
        
        weakSelf.songsListContainer.hidden = NO;
        
        //[weakSelf extendedNavigationBar];
        
        if (!weakSelf.presentingViewController) {
            return [weakSelf.songsList setContentOffset:weakSelf.baseContentOffset];
        }
        
        // We need to scroll after view was diplayed for it to work
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [weakSelf scrollToSetPlayedSongInTheTopOfTheVisibleArea];
        }];
    };
    
    void (^completionForImg)(BOOL hasDownloaded, BLYAlbum *album) = ^(BOOL hasDownloaded, BLYAlbum *album){
        if (!hasDownloaded) {
            return;
        }
        
        [weakSelf.songsList reloadData];
    };
    
    int albumSid = [self.loadedAlbumSid intValue];
    
    BLYAlbum *album = [[BLYAlbumStore sharedStore] albumWithSid:albumSid];
    
    weakSelf.navigationItem.title = album.name;
    
    if ([album.isFullyLoaded boolValue]) {
        completionBlock(album, nil);
        completionForImg(NO, album);
    } else {
        self.launchedConnection = [[BLYAlbumStore sharedStore] fetchAlbum:albumSid
                                                               forCountry:album.country
                                                           withCompletion:completionBlock
                                                      andCompletionForImg:completionForImg];
    }
}

//- (void)updateHeaderViewCacheSwitch
//{
//    BLYAlbumHeaderInfoView *v = self.headerView;
//    BLYPlaylist *playlist = self.playlist;
//
//    int albumSid = [self.loadedAlbumSid intValue];
//
//    BLYAlbum *album = [[BLYAlbumStore sharedStore] albumWithSid:albumSid];
//
//    [v.realView.cacheSwitch setOn:([album.isCached boolValue] || [self.songCachingStore isPlaylistDownloading:playlist])
//                         animated:NO];
//}

- (void)handleCacheSwitchChange:(UISwitch *)_switch
{
    if ([_switch isOn]) {
        [self.songCachingStore cacheEntirePlaylist:self.playlist askedByUser:YES withCompletion:^(NSError *err) {
            if (err) {
                return [[BLYErrorStore sharedStore] manageError:err forViewController:self];
            }
        }];
    } else {
        [self.songCachingStore uncacheEntirePlaylist:self.playlist];
    }
}

- (void)scrollToSetPlayedSongInTheTopOfTheVisibleArea
{
    BLYPlayerViewController *playerVC = self.playerVC;
    BLYSong *loadedSong = playerVC.currentSong;
    
    NSInteger indexOfSong = [self.playlist indexOfSong:loadedSong];
    
    if (loadedSong
        && [self.playlist nbOfSongs] > 0
        && indexOfSong != NSNotFound) {
        
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:indexOfSong
                                                    inSection:0];
        
        [self.songsList scrollToRowAtIndexPath:indexPath
                              atScrollPosition:UITableViewScrollPositionTop
                                      animated:NO];
        
        return;
    }
    
    self.songsList.contentOffset = self.baseContentOffset;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    BLYPlaylistSongCell *cell = (BLYPlaylistSongCell *)[super tableView:tableView cellForRowAtIndexPath:indexPath];
    
    if (!cell.containsCurrentSong) {
        cell.backgroundColor = [UIColor clearColor];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    BLYSong *song = [self.playlist songAtIndex:indexPath.row];
    BLYPlayerViewController *playerVC = self.playerVC;
    
    // It's the wanted result so dismiss search bar...
    if (self.searchSongResultsVC) {
        [self.searchSongResultsVC handleSongHasBeenChosen:song andItsCurrentSong:true];
    }
    
    // Update last selected segment if controller is not loaded from player
    // And if song is not currently played (toggle play/pause)
    if (self.searchSongResultsVC
        && !self.searchSongResultsVC.currentSearchedArtist
        && ![playerVC isCurrentSong:song]) {
        
        [self.searchSongResultsVC updateSearchSongLastSelectedSegmentAndSelectedAlbumIndex:self.searchSongResultsLastSelectedAlbum];
    }
    
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (void)handleSongHasBeenDownloadedWithErrorNotification:(NSNotification *)n
{
    [super handleSongHasBeenDownloadedWithErrorNotification:n];
    
    // [self updateHeaderViewCacheSwitch];
}

- (void)handleAlbumWasCached:(NSNotification *)n
{
    // [self updateHeaderViewCacheSwitch];
}

- (void)handleAlbumWasUncached:(NSNotification *)n
{
    // [self updateHeaderViewCacheSwitch];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
