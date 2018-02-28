//
//  BLYDiscoveryViewController.m
//  Brown
//
//  Created by Jeremy Levy on 22/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import "BLYDiscoveryViewController.h"
#import "BLYPlayerViewController.h"
#import "BLYVideoCell.h"
#import "BLYPlaylist.h"
#import "BLYVideoStore.h"
#import "BLYAppDelegate.h"
#import "BLYSong.h"
#import "BLYAlbum.h"
#import "BLYAlbum+Thumbnail.h"
#import "BLYTimeManager.h"
#import "BLYPlayerContainerViewController.h"
#import "BLYDiscoveryRelatedVideosRefreshHeaderView.h"
#import "BLYDiscoveryRelatedVideosLoadedSongBottomView.h"
#import "BLYArtist.h"
#import "BLYArtistSong.h"
#import "BLYAlbum.h"

const float BLYDiscoveryViewControllerCollectionHeaderHeight = 48.0;
const float BLYDiscoveryViewControllerCollectionFooterHeight = 65.0;

@interface BLYDiscoveryViewController ()

@property (strong, nonatomic) BLYSong *songForRelatedVideos;
@property (copy, nonatomic) BLYPlaylist *playlistForRelatedVideos;
@property (nonatomic) float lastFooterSize;
@property (nonatomic) float lastHeaderSize;

@end

@implementation BLYDiscoveryViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self) {
        _lastFooterSize = 0.0;
        _lastHeaderSize = 0.0;
        
        self.navItemTitle = NSLocalizedString(@"discovery_navigation_item_title", nil);
        self.currentPage = 1;
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UINib *headerNib = [UINib nibWithNibName:@"BLYDiscoveryRelatedVideosRefreshHeaderView" bundle:nil];
    UINib *footerNib = [UINib nibWithNibName:@"BLYDiscoveryRelatedVideosLoadedSongBottomView" bundle:nil];
    
    [self.videosList registerNib:headerNib
      forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
             withReuseIdentifier:@"BLYDiscoveryRelatedVideosRefreshHeaderView"];
    
    [self.videosList registerNib:footerNib
      forSupplementaryViewOfKind:UICollectionElementKindSectionFooter
             withReuseIdentifier:@"BLYDiscoveryRelatedVideosLoadedSongBottomView"];
    
    
    self.loadingTextLabel.text = NSLocalizedString(@"view_controller_main_loading_text", nil);
    
    self.noResultsTextLabel.text = NSLocalizedString(@"discovery_vc_no_results_text", nil);
    
    [self.errorRetryButton setTitle:NSLocalizedString(@"error_retry_button", nil)
                           forState:UIControlStateNormal];
    
    self.errorRetryButton.layer.borderWidth = 0.0;
    self.errorRetryButton.layer.cornerRadius = 14.5;
    
    self.errorRetryButton.layer.borderColor = [UIColor grayColor].CGColor;
    self.errorRetryButton.tintColor = [UIColor grayColor];
    
    [_errorRetryButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_errorRetryButton setBackgroundColor:[UIColor colorWithWhite:0.4 alpha:1.0]];
    
    [self.errorRetryButton addTarget:self
                              action:@selector(retryLoading:)
                    forControlEvents:UIControlEventTouchUpInside];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if ((![self.playerVC.playlist isEqual:self.videos]
        && ![self.playerVC isCurrentSong:self.songForRelatedVideos])
        // User has chosen other video for current song
         || (self.playerVC.currentSong.relatedSongs
             && [self.playerVC.currentSong.relatedSongs count] == 0
             && [self.playerVC.currentSong.videosReordered boolValue])) {
        
             self.videosList.hidden = YES;
             self.errorView.hidden = YES;
             self.noResultsView.hidden = YES;
             
             if (self.playerVC.currentSong.relatedSongs
                 && [self.playerVC.currentSong.relatedSongs count] > 0) {
                 
                 [self loadRelatedVideos];
             }
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if ((![self.playerVC.playlist isEqual:self.videos]
         && ![self.playerVC isCurrentSong:self.songForRelatedVideos])
        // User has chosen other video for current song
        || (self.playerVC.currentSong.relatedSongs
            && [self.playerVC.currentSong.relatedSongs count] == 0
            && [self.playerVC.currentSong.videosReordered boolValue])) {
            
            if (!self.playerVC.currentSong.relatedSongs
                || [self.playerVC.currentSong.relatedSongs count] == 0) {
                
                [self loadRelatedVideos];
            }
        }
}

- (void)retryLoading:(UIButton *)button
{
    _errorView.hidden = YES;
    
    [self loadRelatedVideos];
}

- (void)loadRelatedVideos
{
    BLYAppDelegate *appDelegate = (BLYAppDelegate *)[[UIApplication sharedApplication] delegate];
    NSString *country = [appDelegate countryCodeForCurrentLocale];
    __weak BLYDiscoveryViewController *weakSelf = self;
    
    void(^completion)(BLYPlaylist *, NSError *) = ^(BLYPlaylist *playlist, NSError *err){
        if (err) {
            weakSelf.songForRelatedVideos = nil;
            weakSelf.playlistForRelatedVideos = nil;
            
            weakSelf.errorViewLabel.text = err.localizedDescription;
            weakSelf.errorView.hidden = NO;
            
            return;
        }
        
        if ([playlist nbOfSongs] == 0) {
            weakSelf.noResultsView.hidden = NO;
        }
        
        weakSelf.videos = playlist;
        
        // Make sure to hide error view in case it was displayed before
        weakSelf.errorView.hidden = YES;
        weakSelf.videosList.hidden = NO;
        
        [weakSelf.videosList reloadData];
        
        // Scroll to top
        [weakSelf.videosList setContentOffset:CGPointZero
                                            animated:NO];
    };
    
    void (^completionForImg)(BOOL hasDownloaded, BLYSong *song) = ^(BOOL hasDownloaded, BLYSong *song){
//        weakSelf.errorView.hidden = YES;
//        weakSelf.videosList.hidden = NO;
        
        if (weakSelf.videoHighLighted) {
            weakSelf.videoHighLightedWhenDataWasReloaded = YES;
            
            return;
        }
        
        if (!hasDownloaded) {
            return;
        }
        
        [weakSelf.videosList reloadData];
    };
    
    if (!self.playerVC.currentVideo) {
        [self.containerVC loadInPageVCVC:self.playerVC animated:NO completion:nil];
        
        return;
    }
    
    // Make sure to set this before store call in order to prevent completion to be called before
    self.songForRelatedVideos = self.playerVC.currentSong;
    self.playlistForRelatedVideos = self.playerVC.playlist;
    
    [[BLYVideoStore sharedStore] fetchRelatedVideosForVideo:self.playerVC.currentVideo
                                                     ofSong:self.playerVC.currentSong
                                                 andCountry:country
                                             withCompletion:completion
                                        andCompletionForImg:completionForImg];
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout*)collectionViewLayout
referenceSizeForHeaderInSection:(NSInteger)section
{
    float headerSize = !self.songForRelatedVideos || [self.playerVC isCurrentSong:self.songForRelatedVideos]
    ? 0.0
    : BLYDiscoveryViewControllerCollectionHeaderHeight;
    
    if (self.lastHeaderSize == 0.0 && headerSize > 0.0) {
        CGPoint contentOffset = self.videosList.contentOffset;
        
        // Prevent header displaying to move collection view
        contentOffset.y += BLYDiscoveryViewControllerCollectionHeaderHeight;
        
        [self.videosList setContentOffset:contentOffset
                                        animated:NO];
    }
    
    self.lastHeaderSize = headerSize;
    
    return CGSizeMake(0.0, headerSize);
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout*)collectionViewLayout
referenceSizeForFooterInSection:(NSInteger)section
{
    float footerSize = !self.songForRelatedVideos || [self.playerVC isCurrentSong:self.songForRelatedVideos]
    ? 0.0
    : BLYDiscoveryViewControllerCollectionFooterHeight;
    
    self.lastFooterSize = footerSize;
    
    return CGSizeMake(0.0, footerSize);
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath
{
    if ([kind isEqualToString:UICollectionElementKindSectionHeader]) {
        BLYDiscoveryRelatedVideosRefreshHeaderView *cell = [collectionView dequeueReusableSupplementaryViewOfKind:kind
                                                                            withReuseIdentifier:@"BLYDiscoveryRelatedVideosRefreshHeaderView"
                                                                                   forIndexPath:indexPath];
        
        [cell.refreshButton removeTarget:self
                                  action:@selector(handleTouchOnRefreshButton:)
                        forControlEvents:UIControlEventTouchUpInside];
        
        [cell.refreshButton removeTarget:self
                                  action:@selector(handleTouchDownOnRefreshButton:)
                        forControlEvents:UIControlEventTouchDown];
        
        [cell.refreshButton removeTarget:self
                                  action:@selector(handleTouchUpOnRefreshButton:)
                        forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel];
        
        [cell.refreshButton addTarget:self
                               action:@selector(handleTouchOnRefreshButton:)
                     forControlEvents:UIControlEventTouchUpInside];
        
        [cell.refreshButton addTarget:self
                               action:@selector(handleTouchDownOnRefreshButton:)
                     forControlEvents:UIControlEventTouchDown];
        
        [cell.refreshButton addTarget:self
                               action:@selector(handleTouchUpOnRefreshButton:)
                     forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel];
        
        return cell;
    } else {
        BLYDiscoveryRelatedVideosLoadedSongBottomView *cell = [collectionView dequeueReusableSupplementaryViewOfKind:kind
                                                                withReuseIdentifier:@"BLYDiscoveryRelatedVideosLoadedSongBottomView"
                                                                                                     forIndexPath:indexPath];
        
        BLYSong *song = self.songForRelatedVideos;
        
        cell.title.text = song.title;
        cell.artist.text = [song.artist.name stringByAppendingString:[NSString stringWithFormat:@" - %@", song.album.name]];
        cell.thumbnail.image = [song.album smallThumbnailAsImg];
        
        if ([song.isVideo boolValue] && [song.duration intValue] > 0) {
            cell.duration.text = [self.timeManager durationAsString:[song.duration floatValue]];
            
            cell.duration.hidden = NO;
        } else {
            cell.duration.hidden = YES;
        }
        
        [cell.loadSongButton removeTarget:self
                                   action:@selector(handleTouchOnLoadSongButton:)
                         forControlEvents:UIControlEventTouchUpInside];
        
        [cell.loadSongButton removeTarget:self
                                   action:@selector(handleTouchDownOnLoadSongButton:)
                         forControlEvents:UIControlEventTouchDown];
        
        [cell.loadSongButton removeTarget:self
                                   action:@selector(handleTouchUpOnLoadSongButton:)
                         forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel];
        
        [cell.loadSongButton addTarget:self
                                action:@selector(handleTouchOnLoadSongButton:)
                      forControlEvents:UIControlEventTouchUpInside];
        
        [cell.loadSongButton addTarget:self
                                action:@selector(handleTouchDownOnLoadSongButton:)
                      forControlEvents:UIControlEventTouchDown];
        
        [cell.loadSongButton addTarget:self
                                action:@selector(handleTouchUpOnLoadSongButton:)
                      forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel];
        
        return cell;
    }
}

- (void)handleTouchOnRefreshButton:(id)sender
{
    [self loadRelatedVideos];
}

- (void)handleTouchDownOnRefreshButton:(id)sender
{
    UIButton *button = sender;
    UIColor *buttonBC = button.backgroundColor;
    CGColorRef color = [buttonBC CGColor];
    
    size_t numComponents = CGColorGetNumberOfComponents(color);
    
    if (numComponents == 4) {
        const CGFloat *components = CGColorGetComponents(color);
        CGFloat red = components[0];
        CGFloat green = components[1];
        CGFloat blue = components[2];
        CGFloat alpha = components[3];
        
        button.backgroundColor = [UIColor colorWithRed:red green:green blue:blue alpha:alpha / 2.0];
    }
}

- (void)handleTouchUpOnRefreshButton:(id)sender
{
    UIButton *button = sender;
    UIColor *buttonBC = button.backgroundColor;
    CGColorRef color = [buttonBC CGColor];
    
    size_t numComponents = CGColorGetNumberOfComponents(color);
    
    if (numComponents == 4) {
        const CGFloat *components = CGColorGetComponents(color);
        CGFloat red = components[0];
        CGFloat green = components[1];
        CGFloat blue = components[2];
        CGFloat alpha = components[3];
        
        button.backgroundColor = [UIColor colorWithRed:red green:green blue:blue alpha:alpha * 2.0];
    }
}

- (void)handleTouchOnLoadSongButton:(id)sender
{
    __weak BLYDiscoveryViewController *weakSelf = self;
    
    [self.playerVC loadPlaylist:self.playlistForRelatedVideos
               andStartWithSong:self.songForRelatedVideos
                    askedByUser:YES];
    
    // Display player
    [self.containerVC loadInPageVCVC:self.playerVC animated:YES completion:^(BOOL finised) {
        // Avoid weird animation
        // (ie: collection view scroll to the top during page change)
        dispatch_async(dispatch_get_main_queue(), ^{
            // Reload to hide header and footer
            [weakSelf.videosList reloadData];
        
            [weakSelf.videosList setContentOffset:CGPointZero
                                         animated:YES];
        });
    }];
}

- (void)handleTouchDownOnLoadSongButton:(id)sender
{
    UIButton *b = sender;
    BLYDiscoveryRelatedVideosLoadedSongBottomView *v = (BLYDiscoveryRelatedVideosLoadedSongBottomView *)b.superview;
    CGFloat alpha = 0.35;
    
    v.thumbnail.alpha = alpha;
    v.title.alpha = alpha;
    v.artist.alpha = alpha;
    v.duration.alpha = alpha;
}

- (void)handleTouchUpOnLoadSongButton:(id)sender
{
    UIButton *b = sender;
    BLYDiscoveryRelatedVideosLoadedSongBottomView *v = (BLYDiscoveryRelatedVideosLoadedSongBottomView *)b.superview;
    CGFloat alpha = 1.0;
    
    v.thumbnail.alpha = alpha;
    v.title.alpha = alpha;
    v.artist.alpha = alpha;
    v.duration.alpha = alpha;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
