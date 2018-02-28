//
//  BLYVideoListViewController.m
//  Brown
//
//  Created by Jeremy Levy on 26/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import "BLYPlayerContainerChildVideoListViewController.h"
#import "BLYSong.h"
#import "BLYAlbum.h"
#import "BLYAlbum+Thumbnail.h"
#import "BLYArtist.h"
#import "BLYArtistSong.h"
#import "BLYVideoSong.h"
#import "BLYVideo.h"
#import "BLYVideoCell.h"
#import "BLYAppDelegate.h"
#import "BLYCurrentSongVideoChoiceViewController.h"
#import "BLYVideoStore.h"

@interface BLYPlayerContainerChildVideoListViewController ()

@property (nonatomic) int nbOfVideosDisplayedPerPage;

@end

@implementation BLYPlayerContainerChildVideoListViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self) {
        // Custom initialization
        _timeManager = [[BLYTimeManager alloc] init];
        _videos = [[BLYPlaylist alloc] init];
        
        _videoHighLighted = NO;
        _videoHighLightedWhenDataWasReloaded = NO;
        
        _playerStatusForLastNotification = BLYPlayerViewControllerPlayerStatusUnknown;
        _nbOfVideosDisplayedPerPage = 3;
        
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
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UINib *nib = [UINib nibWithNibName:@"BLYVideoCell" bundle:nil];
    
    // Register this NIB which contains the cell
    [self.videosList registerNib:nib
      forCellWithReuseIdentifier:@"BLYVideoCell"];
}

- (BOOL)isCurrentSongForVideoChoice:(BLYSong *)s
{
    BLYSong *currentSong = self.playerVC.currentSong;
    NSOrderedSet *videos = currentSong.videos;
    
    if ([videos count] == 0) {
        return NO;
    }
    
    BLYVideoSong *videoSong = [videos objectAtIndex:0];
    
    return [videoSong.video.sid isEqualToString:s.sid];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section
{
    return [self.videos nbOfSongs];
}

- (void)collectionView:(UICollectionView *)collectionView didHighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    // WTF ?
    if (!indexPath) {
        return;
    }
    
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    
    self.videoHighLighted = YES;
    
    cell.alpha = 0.6;
}

- (void)collectionView:(UICollectionView *)collectionView didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    // WTF ?
    if (!indexPath) {
        return;
    }
    
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    
    self.videoHighLighted = NO;
    
    cell.alpha = 1.0;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    BLYVideoCell *cell = [self.videosList dequeueReusableCellWithReuseIdentifier:@"BLYVideoCell"
                                                                    forIndexPath:indexPath];
    BLYSong *song = [self.videos songAtIndex:indexPath.row];
    
    // Don't use [playerVC playerStatus] here ! Player status is updated before player VC post corresponding notification...
    BLYPlayerViewControllerPlayerStatus playerStatus = self.playerStatusForLastNotification;
    
    BOOL itsCurrentSong = [self isKindOfClass:[BLYCurrentSongVideoChoiceViewController class]]
        ? [self isCurrentSongForVideoChoice:song]
        : [self.playerVC isCurrentSong:song];
    
    cell.videoTitle.text = song.title;
    
    cell.videoThumbnail.image = [song.album smallThumbnailAsImg];
    
    CGFloat w = ([UIScreen mainScreen].nativeBounds.size.width / [UIScreen mainScreen].nativeScale) - (4 * 21.0);
    
    // For performance with corner radius
    // See https://stackoverflow.com/questions/12236184/tableview-scrolling-lack-of-performance-using-cornerradius-whats-alternatives
    [cell.contentView setOpaque:YES];
    [cell.backgroundView setOpaque:YES];
    
    cell.videoThumbnail.layer.cornerRadius = (w / _nbOfVideosDisplayedPerPage) / 2.0;;
    cell.videoThumbnail.layer.masksToBounds = YES;
    // Performance improvement here depends on the size of your view
    cell.videoThumbnail.layer.shouldRasterize = YES;
    cell.videoThumbnail.layer.rasterizationScale = [UIScreen mainScreen].scale;
    
    cell.videoThumbnail.layer.borderColor = [[UIColor colorWithWhite:0.1 alpha:1.0] CGColor];
    cell.videoThumbnail.layer.borderWidth = 1.0;
    
    cell.duration.text = [self.timeManager durationAsString:[song.duration floatValue]];
    cell.duration.hidden = NO;
    
    cell.loadIndicator.hidden = YES;
    cell.playIndicator.hidden = YES;
    
    if (itsCurrentSong && playerStatus != BLYPlayerViewControllerPlayerStatusError) {
        if (playerStatus == BLYPlayerViewControllerPlayerStatusLoading) {
            cell.loadIndicator.hidden = NO;
            cell.duration.hidden = true;
            
            [cell.loadIndicator startAnimating];
            
            cell.videoThumbnail.layer.borderWidth = 2.0;
            cell.videoThumbnail.layer.borderColor = [[UIColor lightGrayColor] CGColor];
        } else if (playerStatus == BLYPlayerViewControllerPlayerStatusPlaying) {
//            cell.playIndicator.hidden = NO;
//            cell.playIndicator.currentPageIndicatorTintColor = [UIColor colorWithRed:0.0 green:128.0 / 255.0 blue:1.0 alpha:0.79];
            cell.videoThumbnail.layer.borderWidth = 2.0;
            cell.videoThumbnail.layer.borderColor = [[UIColor whiteColor] CGColor];
        } else if (playerStatus == BLYPlayerViewControllerPlayerStatusPaused) {
//            cell.playIndicator.hidden = NO;
//            cell.playIndicator.currentPageIndicatorTintColor = [UIColor colorWithRed:1.0 green:102.0 / 255.0 blue:102.0 / 255.0 alpha:1.0];
            
            cell.videoThumbnail.layer.borderWidth = 2.0;
            cell.videoThumbnail.layer.borderColor = [[UIColor lightGrayColor] CGColor];
        }
        
        return cell;
    }
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    BLYSong *song = [self.videos songAtIndex:indexPath.row];
    BLYPlayerViewController *playerVC = self.playerVC;
    BOOL isCurrentSong = ![self isKindOfClass:[BLYCurrentSongVideoChoiceViewController class]]
                         && [playerVC isCurrentSong:song];
    
    if (!self.playerVC) {
        return;
    }
    
    if ([self isKindOfClass:[BLYCurrentSongVideoChoiceViewController class]]) {
        isCurrentSong = [self isCurrentSongForVideoChoice:song];
    }
    
    if (self.videoHighLightedWhenDataWasReloaded) {
        self.videoHighLightedWhenDataWasReloaded = NO;
        
        [self.videosList reloadData];
    }
    
    BLYAppDelegate *appDelegate = (BLYAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    if (isCurrentSong
        && playerVC.playerStatus != BLYPlayerViewControllerPlayerStatusError) {
        
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
    
    if (![self isKindOfClass:[BLYCurrentSongVideoChoiceViewController class]]) {
        [playerVC loadPlaylist:self.videos
              andStartWithSong:song
                   askedByUser:YES];
    }
    
//    [appDelegate trackEventWithCategory:@"playlist_ui"
//                                 action:@"select_song"
//                                  label:NSStringFromClass([self class])
//                                  value:nil];
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    //    return CGSizeMake(80.0, 115.0);
    //
    //    if ([self isKindOfClass:[BLYSearchSongResultsViewController class]]) {
    //        return CGSizeMake(80.0, 115.0);
    //    }
    
    // Remove space between cells
    // This rectangle is based on the device in a portrait-up orientation.
    // This value does not change as the device rotates.
    CGFloat w = ([UIScreen mainScreen].nativeBounds.size.width / [UIScreen mainScreen].nativeScale) - (4 * 21.0);
    CGFloat width = (w / _nbOfVideosDisplayedPerPage);
    CGFloat height = 125.0;
    
    if (width > 80.0) {
        float ratio = (width / 80.0);
        
        height = (80.0 * ratio) + (125.0 - 80.0);
    } else {
        return CGSizeMake(80.0, 125.0);
    }
    
    return CGSizeMake(width, height);
}

- (void)handlePlayerHasLoadedASongNotification:(NSNotification *)n
{
    [self setPlayerStatusForLastNotification:BLYPlayerViewControllerPlayerStatusLoading];
    
    [self.videosList reloadData];
}

- (void)handlePlayerHasLoadedASongWithErrorNotification:(NSNotification *)n
{
    [self setPlayerStatusForLastNotification:BLYPlayerViewControllerPlayerStatusError];
    
    [self.videosList reloadData];
}

- (void)handlePlayerHasPausedASongNotification:(NSNotification *)n
{
    [self setPlayerStatusForLastNotification:BLYPlayerViewControllerPlayerStatusPaused];
    
    [self.videosList reloadData];
}

- (void)handlePlayerHasPlayedASongNotification:(NSNotification *)n
{
    [self setPlayerStatusForLastNotification:BLYPlayerViewControllerPlayerStatusPlaying];
    
    [self.videosList reloadData];
}

- (void)handleSearchSongsStoreDidUpdateSongsDurationNotification:(NSNotification *)n
{
    [self.videosList reloadData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // Avoid err_bad_access
    self.videosList.delegate = nil;
    self.videosList.dataSource = nil;
}

@end
