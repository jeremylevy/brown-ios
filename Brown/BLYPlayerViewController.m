 //
//  BLYPlayerViewController.m
//  Brown
//
//  Created by Jeremy Levy on 20/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MPNowPlayingInfoCenter.h>
#import <MediaPlayer/MPMediaItem.h>
#import <QuartzCore/QuartzCore.h>
#import "NSString+Sizing.h"
#import "BLYPlayerViewController.h"
#import "BLYPlaylist.h"
#import "BLYPlaylistViewController.h"
#import "BLYSong.h"
#import "BLYSong+Caching.h"
#import "BLYCachedSong+CoreDataProperties.h"
#import "BLYHTTPConnection.h"
#import "BLYVideoStore.h"
#import "BLYTimeManager.h"
#import "BLYAppDelegate.h"
#import "BLYPlayerPlaylistViewController.h"
#import "BLYVideo.h"
#import "BLYVideoSong.h"
#import "BLYAlbum.h"
#import "BLYAlbum+Thumbnail.h"
#import "BLYAlbumStore.h"
#import "BLYAlbumThumbnail.h"
#import "BLYArtist.h"
#import "BLYArtistSong.h"
#import "BLYVideoURL.h"
#import "BLYBaseNavigationController.h"
#import "BLYBaseViewController.h"
#import "BLYFullScreenPlayerViewController.h"
#import "BLYNetworkStore.h"
#import "BLYSearchSongResultsViewController.h"
#import "BLYErrorStore.h"
#import "BLYAlbumViewController.h"
#import "NSString+Escaping.h"
#import "NSString+Sizing.h"
#import "NSString+Matching.h"
#import "NSMutableArray+Shuffling.h"
#import "BLYPersonalTopSongStore.h"
#import "BLYPlayedSongStore.h"
#import "BLYSongStore.h"
#import "BLYSearchSongsStore.h"
#import "BLYAppDelegate.h"
#import "BLYPlayerContainerViewController.h"
#import "BLYStore.h"
#import "BLYAppSettingsStore.h"
#import "BLYSongCachingStore.h"
#import "BLYCachedSongStore.h"
#import "BLYVideoURLType.h"
#import "BLYPersonalTopSong.h"
#import "BLYMediaCenterThumb.h"

static void * BLYPlayerViewControllerBGPlayerContext = &BLYPlayerViewControllerBGPlayerContext;

NSString * const BLYPlayerViewControllerDidLoadSongNotification = @"BLYPlayerViewControllerDidLoadSongNotification";
NSString * const BLYPlayerViewControllerDidPauseSongNotification = @"BLYPlayerViewControllerDidPauseSongNotification";
NSString * const BLYPlayerViewControllerDidPlaySongNotification = @"BLYPlayerViewControllerDidPlaySongNotification";
NSString * const BLYPlayerViewControllerDidTerminateBGWorkNotification = @"BLYPlayerViewControllerDidTerminateBGWorkNotification";
NSString * const BLYPlayerViewControllerDidLoadPlaylistNotification = @"BLYPlayerViewControllerDidLoadPlaylistNotification";
NSString * const BLYPlayerViewControllerDidLoadSongWithErrorNotification = @"BLYPlayerViewControllerDidLoadSongWithErrorNotification";
NSString * const BLYPlayerViewControllerDidCompleteVideoBuffering = @"BLYPlayerViewControllerDidCompleteVideoBuffering";
NSString * const BLYPlayerViewControllerDidAddToPersonalTop = @"BLYPlayerViewControllerDidAddToPersonalTop";

const int BLYPlayerViewControllerSongNotFoundErrorCode = 0;
const int BLYPlayerViewControllerUnknownErrorCode = -1;
const float BLYPlayerViewControllerRewindOrPreviousSongTime = 20.0;
const float BLYPlayerViewControllerLastTimeHeadphonesWereRemovedTimeToPlay = 60.0;
const double BLYPlayerViewControllerMinElapsedTimeForRateObserverToSendPlayNotification = 1.0;

@interface BLYPlayerViewController ()

@property (nonatomic) BOOL userWantsPlay;
@property (nonatomic) BOOL forceSongRefreshing;
@property (nonatomic) BOOL audioSessionWasInterrupted;
@property (nonatomic) UIApplicationState appStateWhenAudioSessionWasInterrupted;
@property (nonatomic) CGRect playerContainerDefaultFrame;
@property (nonatomic) UIBackgroundTaskIdentifier bgTaskId;
@property (strong, nonatomic) id periodicTimeObserverForPlayer;
@property (nonatomic) BOOL observerForCurrentItemIsSet;
@property (nonatomic) CMTime seekToTimeFuturTime;
@property (strong, nonatomic) NSMutableDictionary *lastPreviousSongPlayed;

// Use weak here, because run loops maintain strong references to their timers
@property (weak, nonatomic) NSTimer *songPlayingTimerForPersonalTop;
@property (weak, nonatomic) NSTimer *emptyBufferTimer;
@property (weak, nonatomic) NSTimer *timeToLoadSong;

@property (nonatomic) NSTimeInterval timeSpentAtPlaying;
@property (strong, nonatomic) NSDate *songPlayedAt;
@property (nonatomic) NSTimeInterval timeSpentAtPlayingForPersonalTop;

@property (strong, nonatomic) BLYSong *songCaching;

@property (nonatomic) int rewindCurrentSongDueToBadNetworkAttempts;

@property (strong, nonatomic) void(^bgPlayerHasSufficientBuffer)(void);
@property (strong, nonatomic) void(^bgPlayerWasSuccessfullyLoadedWithNextSong)(void);
@property (strong, nonatomic) void(^loadBgPlayerWhenAppEnterBackgroundModeCallback)(void);
@property (strong, nonatomic) NSMutableArray *bgPlayerKvoCalls;
@property (strong, nonatomic) BLYSong *songLoadedInBgPlayer;

@property (nonatomic) BOOL playNotificationSendedForCurrentSong;
@property (weak, nonatomic) IBOutlet UILabel *repeatExplainLabel;

@property (nonatomic) NSDate *currentVideoURLExpiresAt;
@property (nonatomic) double loadCurrentSongAtTime;

@property (nonatomic) BOOL currentSongIsInRepeatModeDueToBadNetwork;
@property (strong, nonatomic) NSString *currentVideoQuality;
@property (strong, nonatomic) NSString *videoQualityLoadedInBgPlayer;
@property (nonatomic) BOOL userKnowThatOnlyCachedSongsWillBePlayedGivenThatNetworkIsNotReachable;

@end

@implementation BLYPlayerViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleAudioSessionInterruption:)
                                                     name:AVAudioSessionInterruptionNotification
                                                   object:nil];
        
//        [[NSNotificationCenter defaultCenter] addObserver:self
//                                                 selector:@selector(handleAudioSessionReseted:)
//                                                     name:AVAudioSessionMediaServicesWereLostNotification
//                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleRemoteControlReceivedInAppDelegate:)
                                                     name:BLYAppDelegateDidReceiveRemoteControlNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handlePlaylistWillLoad:)
                                                     name:BLYPlaylistViewControllerWillLoadPlaylistNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleViewControllerDidLoad:)
                                                     name:BLYBaseViewControllerDidLoadNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handlePlaylistHasUpdatedASongNotification:)
                                                     name:BLYPlaylistDidUpdateSongNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleAppSettingHasChangedNotification:)
                                                     name:BLYAppSettingsStoreSettingHasChanged
                                                   object:nil];
        
//        [[NSNotificationCenter defaultCenter] addObserver:self
//                                                 selector:@selector(handleTouchOnAd:)
//                                                     name:BannerViewActionWillBegin
//                                                   object:nil];
//        
//        [[NSNotificationCenter defaultCenter] addObserver:self
//                                                 selector:@selector(handleAdResignAfterTouch:)
//                                                     name:BannerViewActionDidFinish
//                                                   object:nil];
        
        [self enableAllRemoteCommands];
        
        _audioSessionWasInterrupted = NO;
        _appStateWhenAudioSessionWasInterrupted = UIApplicationStateActive;
        _playing = NO;
        _pausedByPlaybackSlide = NO;
        _repeatMode = BLYPlayerViewControllerRepeatModeNone;
        _playerStatus = BLYPlayerViewControllerPlayerStatusUnknown;
        _songWasPausedBecauseEmptyBuffer = NO;
        _fullscreen = NO;
        _userWantsPlay = NO;
        _bgTaskId = UIBackgroundTaskInvalid;
        _observerForCurrentItemIsSet = NO;
        _timeSpentAtPlaying = 0.0;
        _timeSpentAtPlayingForPersonalTop = 0.0;
        _completeBufferCallbackCalled = NO;
        _rewindCurrentSongDueToBadNetworkAttempts = 0;
        _playerStateBeforeBadNetworkHappen = [[NSMutableDictionary alloc] init];
        _bgPlayerKvoCalls = [[NSMutableArray alloc] init];
        _playNotificationSendedForCurrentSong = NO;
        _loadBgPlayerWhenAppEnterBackgroundModeCallback = nil;
        _currentSongIsInRepeatModeDueToBadNetwork = NO;
        _seekToTimeFuturTime = CMTimeMake(-1.0, 1.0);
        _forceSongRefreshing = NO;
        _lastPreviousSongPlayed = nil;
        _currentVideoQuality = nil;
        _videoQualityLoadedInBgPlayer = nil;
        _userKnowThatOnlyCachedSongsWillBePlayedGivenThatNetworkIsNotReachable = NO;
        
        self.currentPage = 0;
        self.navItemTitle = NSLocalizedString(@"player_navigation_item_title", nil);
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.loadingTextLabel.text = NSLocalizedString(@"view_controller_main_loading_text", nil);
    
    [self loadPlayerLayerAndForceNew:NO];

    [self.volumeSlider setVolumeThumbImage:[UIImage imageNamed:@"PlayerSliderThumb"]
                                  forState:UIControlStateNormal];
    
    [self.playbackSlider setThumbImage:[UIImage imageNamed:@"PlayerSliderThumb"]
                              forState:UIControlStateNormal];
    
    self.playbackSlider.maximumTrackTintColor = [UIColor clearColor];
    
    self.playbackSlider.continuous = YES;
    
    [self disableRepeatIcon];
    [self disableShowAlbumIcon];
    [self disableNextIcon];
    [self disablePreviousIcon];
    [self disablePlayIcon];
    [self disablePlaybackSlider];
    
    self.playerContainerDefaultFrame = self.playerContainer.frame;
    
    self.containerVC.tabBarItem.enabled = NO;
    
    // Select Tops tab at launch
    self.containerVC.tabBarController.selectedIndex = BLYBaseTabBarControllerExternalTopIndex;
    
    [self.bufferingBarBG setThumbImage:[[UIImage alloc] init]
                              forState:UIControlStateNormal];
    
    self.bufferingBarBG.maximumTrackTintColor = [UIColor clearColor];
    
    self.bufferingBarBG.userInteractionEnabled = NO;
    
    self.repeatExplainLabel.text = NSLocalizedString(@"player_repeat_explain_label", nil);
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self updatePlayerLayerFrame];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    //self.playerLayer.hidden = YES;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    [self updatePlayerLayerFrame];
}

- (void)updatePlayerLayerFrame
{
    // Avoid update player layer frame when video is in fullscreen mode
    // Ads showing or whatever
    if (self.isFullscreen) {
        return;
    }
    
    CGRect playerContainerBounds = self.playerContainer.bounds;
    CGRect playerLayerBounds = CGRectMake(0, 0, playerContainerBounds.size.width, playerContainerBounds.size.height);
    
    self.playerLayer.bounds = playerLayerBounds;
    self.playerLayer.frame = playerLayerBounds;
    self.playerLayer.hidden = NO;
    
    [self.playerLayer setNeedsDisplay];
    [self.playerLayer displayIfNeeded];
    
    [self.playerLayer setNeedsLayout];
    [self.playerLayer layoutIfNeeded];
}

- (void)setBufferingBarProgress:(float)progress animated:(BOOL)animated
{
    BOOL _animated = animated;
    
    if (![self isVisible]) {
        _animated = NO;
    }
    
    [self.bufferingBar setProgress:MIN(progress, 1.0)
                          animated:_animated && progress < 1.0];
    
    // Only way to get a right rounded corner
    // for buferring bar
    if (progress >= 1.0) {
        [self.bufferingBarBG setMaximumTrackTintColor:[UIColor colorWithRed:170.0 / 255.0 green:170.0 / 255.0 blue:170.0 / 255.0 alpha:1.0]];
    } else {
        [self.bufferingBarBG setMaximumTrackTintColor:[UIColor colorWithRed:88.0 / 255.0 green:88.0 / 255.0 blue:88.0 / 255.0 alpha:1.0]];
    }
    
    if (self.isFullscreen) {
        BLYFullScreenPlayerViewController *fullScreenVC = [BLYFullScreenPlayerViewController sharedVC];
        
        [fullScreenVC.bufferingBar setProgress:MIN(progress, 1.0)
                                      animated:animated];
        
        // Only way to get a right rounded corner
        // for buferring bar
        if (progress >= 1.0) {
            [fullScreenVC.bufferingBarBG setMaximumTrackTintColor:[UIColor colorWithRed:170.0 / 255.0 green:170.0 / 255.0 blue:170.0 / 255.0 alpha:1.0]];
        } else {
            [fullScreenVC.bufferingBarBG setMaximumTrackTintColor:[UIColor colorWithRed:88.0 / 255.0 green:88.0 / 255.0 blue:88.0 / 255.0 alpha:1.0]];
        }
    }
}

- (void)hideRepeatExplainLabelImmediately:(BOOL)immediately
{
    UILabel *label = self.repeatExplainLabel;
    NSLayoutConstraint *bottomConstraint = self.repeatExplainLabelBottomConstraint;
    UIView *view = self.view;
    
    void (^frameChange)(void) = ^{
        bottomConstraint.constant = -CGRectGetHeight(label.superview.frame);
        [view layoutIfNeeded];
    };
    
    if (immediately) {
        return frameChange();
    }
    
    [UIView animateWithDuration:0.3 animations:^{
        frameChange();
    }];
}

- (void)showRepeatExplainLabelImmediately:(BOOL)immediately
{
    NSLayoutConstraint *bottomConstraint = self.repeatExplainLabelBottomConstraint;
    UIView *view = self.view;
    
    void (^frameChange)(void) = ^{
        bottomConstraint.constant = 12.0;
        [view layoutIfNeeded];
    };
    
    if (immediately) {
        return frameChange();
    }
    
    [UIView animateWithDuration:0.3 animations:^{
        frameChange();
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setPlaylist:(BLYPlaylist *)playlist
{
    _playlist = [playlist copy];
    
    [self postLoadPlaylistNotification];
}

- (void)postLoadPlaylistNotification
{
    [self postLoadPlaylistNotificationForPlayer:YES];
}

- (void)postLoadPlaylistNotificationForPlayer:(BOOL)forPlayer
{
    if (!self.playlist || [self.playlist nbOfSongs] == 0) {
        return;
    }
    
    NSDictionary *userInfo = @{@"loadedPlaylist": self.playlist,
                               @"forPlayer": [NSNumber numberWithBool:forPlayer]};
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BLYPlayerViewControllerDidLoadPlaylistNotification
                                                        object:self
                                                      userInfo:userInfo];
    
    if (!forPlayer) {
        return;
    }
}

- (void)loadPlaylist:(BLYPlaylist *)playlist
    andStartWithSong:(BLYSong *)song
         askedByUser:(BOOL)askedByUser
        forceRefresh:(BOOL)forceRefresh
{
    self.playlist = playlist;
    self.forceSongRefreshing = forceRefresh;
    
    if (askedByUser
        && [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive
        && ![[BLYNetworkStore sharedStore] networkIsReachable]) {
        
        _userKnowThatOnlyCachedSongsWillBePlayedGivenThatNetworkIsNotReachable = true;
    } else {
        _userKnowThatOnlyCachedSongsWillBePlayedGivenThatNetworkIsNotReachable = NO;
    }
    
    [self loadSong:song askedByUser:askedByUser];
    
    if ([playlist nbOfSongs] <= 1
        || playlist.firstLoadedSongMustBeSetInRepeatMode) {
        self.repeatMode = BLYPlayerViewControllerRepeatModeOne;
    } else {
        self.repeatMode = BLYPlayerViewControllerRepeatModeNone;
    }
    
    if (!askedByUser) {
        return;
    }
    
    self.playerStateBeforeBadNetworkHappen = [[NSMutableDictionary alloc] init];
    self.userWantsPlay = YES;
}

- (void)loadPlaylist:(BLYPlaylist *)playlist
    andStartWithSong:(BLYSong *)song
         askedByUser:(BOOL)askedByUser
{
    [self loadPlaylist:playlist
      andStartWithSong:song
           askedByUser:askedByUser
          forceRefresh:NO];
    
}

- (void)setCurrentSong:(BLYSong *)currentSong
           askedByUser:(BOOL)askedByUser
{
    _currentSong = currentSong;
    
    _currentVideo = nil;
    
    _currentSong.loadedByUser = [NSNumber numberWithBool:askedByUser];
    
    [self loadPlayingInfoAtSongLoad:YES];
    //[self enableShowAlbumIcon];
}

- (double)currentDurationAsSecond
{
    return [self currentDurationAsSecondForPlayer:self.player];
}

- (double)currentDurationAsSecondForPlayer:(AVPlayer *)player
{
    AVPlayerItem *currentItem = player.currentItem;
    double currentItemDuration = CMTimeGetSeconds(currentItem.duration);
    
    if (isnan(currentItemDuration)) {
        return 0.0;
    }
    
//    if (currentItemDuration <= 0.0 || isnan(currentItemDuration)) {
//        // TODO: find the bug who make this shit
//        if ([self.currentSong.videos count] == 0) {
//            return 1.0;
//        }
//        
//        BLYVideoSong *videoSong = [self.currentSong.videos objectAtIndex:0];
//        BLYVideo *video = videoSong.video;
//        
//        currentItemDuration = [video.duration doubleValue];
//        
//        NSLog(@"%@", video.duration);
//    }
    
    return currentItemDuration;
}

- (BOOL)isPlayingOnBluetoothDevice
{
    NSArray *outputs = [[[AVAudioSession sharedInstance] currentRoute] outputs];
    
    for (AVAudioSessionPortDescription *output in outputs) {
        if (output.portType == AVAudioSessionPortBluetoothLE
            || output.portType == AVAudioSessionPortBluetoothHFP
            || output.portType == AVAudioSessionPortBluetoothA2DP) {
            
            return true;
        }
    }
    
    return NO;
}

- (UIImage *)getMediaCenterThumbWithText:(NSString *)text forSong:(BLYSong *)s
{
    NSArray *subviewArray = [[NSBundle mainBundle] loadNibNamed:@"BLYMediaCenterThumb" owner:self options:nil];
    
    BLYMediaCenterThumb *view = [subviewArray objectAtIndex:0];
    UIImage *thumb = [s.album largeThumbnailAsImg] ? [s.album largeThumbnailAsImg] : [s.album smallThumbnailAsImg];
    
    if (@available(iOS 11.0, *)) {
        return thumb;
    }
    
    if ([self isPlayingOnBluetoothDevice]) {
        return thumb;
    }
    
    view.thumb.image = thumb;
    
    view.rankLabel.text = text;
    view.rankLabel.shadowBlur = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 10.0 : 4.0);
    view.rankLabel.shadowColor = [UIColor colorWithWhite:0.4 alpha:1.0];
    view.rankLabel.shadowOffset = CGSizeMake(0.0, 0.0);
    view.rankLabel.textInsets = UIEdgeInsetsMake(0.0, 0.0, 0.0, 2.0);
    view.rankLabel.automaticallyAdjustTextInsets = NO;
    
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.opaque, 0.0);
    
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    
    UIImage * img = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return img;
}

- (void)loadPlaybackInfoForPlayerError:(NSError *)error
{
    BLYSong *currentSong = self.currentSong;
    MPMediaItemArtwork *albumArt = nil;
    NSMutableDictionary *songInfo = [self loadPlayingInfoAtSongLoad:NO];
    
    [songInfo setObject:[NSNumber numberWithDouble:0.0]
                 forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
    
    [songInfo setObject:[NSNumber numberWithDouble:0.0]
                 forKey:MPMediaItemPropertyPlaybackDuration];
    
    // [songInfo removeObjectForKey:MPMediaItemPropertyArtist];
    
    [songInfo setObject:[NSString stringWithFormat:@"%@", error.localizedDescription]
                 forKey:MPMediaItemPropertyTitle];
    
    [songInfo removeObjectForKey:MPMediaItemPropertyArtist];
    [songInfo removeObjectForKey:MPMediaItemPropertyAlbumTitle];
    
    // [songInfo removeObjectForKey:MPMediaItemPropertyAlbumTitle];
    
    [songInfo setObject:[NSNumber numberWithDouble:0.0]
                 forKey:MPNowPlayingInfoPropertyPlaybackRate];
    
    UIImage *albumThumb = [self getMediaCenterThumbWithText:NSLocalizedString(@"error", nil) forSong:currentSong];
    
    albumArt = [[MPMediaItemArtwork  alloc] initWithBoundsSize:albumThumb.size requestHandler:^UIImage * _Nonnull(CGSize size) {
        return albumThumb;
    }];
    
    [songInfo setObject:albumArt
                 forKey:MPMediaItemPropertyArtwork];
    
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:songInfo];
    
    // Disabled by loading playing info at song load
    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
    
    // Play command reload song in case of error
    [commandCenter.playCommand setEnabled:true];
    [commandCenter.pauseCommand setEnabled:true];
    
    [commandCenter.togglePlayPauseCommand setEnabled:true];
}

- (NSMutableDictionary *)loadPlayingInfoAtSongLoad:(BOOL)atSongLoad
{
    BLYSong *currentSong = self.currentSong;
    NSMutableDictionary *songInfo = [[[MPNowPlayingInfoCenter defaultCenter] nowPlayingInfo] mutableCopy];
    MPMediaItemArtwork *albumArt = nil;
    
    if (!songInfo) {
        songInfo = [[NSMutableDictionary alloc] init];
    }
    
//    if (currentSong.album.thumbnail) {
//        NSArray *subviewArray = [[NSBundle mainBundle] loadNibNamed:@"BLYMediaCenterThumb" owner:self options:nil];
//
//        BLYMediaCenterThumb *view = [subviewArray objectAtIndex:0];
//
//        view.thumb.image = currentSong.album.thumbnail;
//        view.rankLabel.text = [NSString stringWithFormat:@"%ld.", (long)[self.playlist indexOfSong:currentSong] + 1];
//
//        UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.opaque, 0.0);
//
//        [view.layer renderInContext:UIGraphicsGetCurrentContext()];
//
//        UIImage * img = UIGraphicsGetImageFromCurrentImageContext();
//
//        UIGraphicsEndImageContext();
//
//        albumArt = [[MPMediaItemArtwork  alloc] initWithBoundsSize:img.size requestHandler:^UIImage * _Nonnull(CGSize size) {
//            return img;
//        }];
//    }
    
    UIImage *albumThumb = [currentSong.album smallThumbnailAsImg];
    
    if ([currentSong.album largeThumbnailAsImg]) {
        albumThumb = [currentSong.album largeThumbnailAsImg];
    }
    
    if (albumThumb) {
        albumArt = [[MPMediaItemArtwork  alloc] initWithBoundsSize:albumThumb.size requestHandler:^UIImage * _Nonnull(CGSize size) {
//            if (self.currentSongIsInRepeatModeDueToBadNetwork
//                || [self.playerStateBeforeBadNetworkHappen count] > 0) {
//
//                return [self getMediaCenterThumbWithText:NSLocalizedString(@"player_bad_network_playlist_error_title", nil) forSong: currentSong];
//            }
//
//            if (_repeatMode == BLYPlayerViewControllerRepeatModeOne) {
//                return [self getMediaCenterThumbWithText:NSLocalizedString(@"repeated", nil) forSong: currentSong];
//            }
//
            return albumThumb;
        }];
    }
    
    [songInfo setObject:[NSNumber numberWithInt:MPNowPlayingInfoMediaTypeVideo]
                 forKey:MPNowPlayingInfoPropertyMediaType];
    
    if ([self.playlist nbOfSongs] > 1 && NO) {
        // Index starts at 0 so display accordingly
        [songInfo setObject:[NSString stringWithFormat:@"%ld. %@", (long)[self.playlist indexOfSong:currentSong] + 1, currentSong.title]
                     forKey:MPMediaItemPropertyTitle];
    } else {
        [songInfo setObject:[NSString stringWithFormat:@"%@", currentSong.title]
                     forKey:MPMediaItemPropertyTitle];
    }
    
    [songInfo setObject:currentSong.artist.name
                 forKey:MPMediaItemPropertyArtist];
    
    if (![currentSong.album.isASingle boolValue]) {
        [songInfo setObject:currentSong.album.name
                     forKey:MPMediaItemPropertyAlbumTitle];
    } else {
        // Make sure to overwrite possible previous album name
        [songInfo setObject:@""
                     forKey:MPMediaItemPropertyAlbumTitle];
    }
    
    if ([currentSong.rankInAlbum intValue] > 0) {
        [songInfo setObject:currentSong.rankInAlbum
                     forKey:MPMediaItemPropertyAlbumTrackNumber];
    }
    
    if ([currentSong.album.isFullyLoaded boolValue]) {
        [songInfo setObject:[NSNumber numberWithInteger:[currentSong.album.songs count]]
                     forKey:MPMediaItemPropertyAlbumTrackCount];
    }
    
    if (albumArt) {
        [songInfo setObject:albumArt
                     forKey:MPMediaItemPropertyArtwork];
    }
    
    NSUInteger nbOfSongs = [self.playlist nbOfSongs];
    NSUInteger indexOfSong = [self.playlist indexOfSong:currentSong];
    
    [songInfo setObject:[NSNumber numberWithUnsignedInteger:nbOfSongs]
                 forKey:MPNowPlayingInfoPropertyPlaybackQueueCount];
    
    // The playback queue uses zero-based indexing.
    // If you want the first item in the queue to be displayed as “item 1 of 10,”
    // for example, set the item’s index to 0
    [songInfo setObject:[NSNumber numberWithUnsignedInteger:indexOfSong]
                 forKey:MPNowPlayingInfoPropertyPlaybackQueueIndex];
    
    [songInfo setObject:_currentSong.sid
                 forKey:MPNowPlayingInfoCollectionIdentifier];
    
    if (atSongLoad) {
        [songInfo setObject:[NSNumber numberWithDouble:[self.currentSong.duration doubleValue]]
                     forKey:MPMediaItemPropertyPlaybackDuration];
        
        [songInfo setObject:[NSNumber numberWithDouble:0.0]
                     forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
        
//        MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
//
//        if (!self.currentSong.isCached) {
//            [commandCenter.playCommand setEnabled:NO];
//            [commandCenter.pauseCommand setEnabled:NO];
//
//            [commandCenter.togglePlayPauseCommand setEnabled:NO];
//
//            [songInfo setObject:[NSNumber numberWithDouble:0.0]
//                         forKey:MPNowPlayingInfoPropertyPlaybackRate];
//        } else {
//            [songInfo setObject:[NSNumber numberWithDouble:1.0]
//                         forKey:MPNowPlayingInfoPropertyPlaybackRate];
//
//            [commandCenter.playCommand setEnabled:true];
//            [commandCenter.pauseCommand setEnabled:true];
//
//            [commandCenter.togglePlayPauseCommand setEnabled:true];
//        }
    }
    
    if (atSongLoad) {
        [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:songInfo];
    }
    
    return songInfo;
}

- (double)elapsedTimeRatio
{
    AVPlayerItem *currentItem = self.player.currentItem;
    CMTime currentTime = [currentItem currentTime];
    
    double durationAsSeconds = [self currentDurationAsSecond];
    double currentTimeAsSeconds = CMTimeGetSeconds(currentTime);
    
    if (durationAsSeconds <= 0) {
        return 0.0;
    }
    
    double elapsedTimeRatio = fmin(1.0, currentTimeAsSeconds / durationAsSeconds);

    return elapsedTimeRatio;
}

- (void)loadPlaybackInfo
{
    if (![self playerIsLoaded] || self.loadCurrentSongAtTime > 0.0) {
        return;
    }
    
    BLYSong *currentSong = self.currentSong;
    __weak BLYPlayerViewController *weakSelf = self;
    
    CMTime currentTime = [self.player.currentItem currentTime];
    
    if (CMTimeGetSeconds(self.seekToTimeFuturTime) >= 0.0) {
        currentTime = self.seekToTimeFuturTime;
    }
    
    double durationAsSeconds = round(fabs([self currentDurationAsSecond]));
    double currentTimeAsSeconds = round(fabs(CMTimeGetSeconds(currentTime)));
    double elapsedTimeRatio = [self elapsedTimeRatio];
    
    [self updatePlaybackInfo:CMTimeMake(currentTimeAsSeconds, 1.0)];
    
    BOOL animated = [self isVisible];
    
    [self.playbackSlider setValue:elapsedTimeRatio
                         animated:animated];
    
    if ([self isFullscreen]) {
        [[[BLYFullScreenPlayerViewController sharedVC] playbackSlider] setValue:elapsedTimeRatio
                                                                       animated:YES];
    }
    
    NSMutableDictionary *songInfo = [[[MPNowPlayingInfoCenter defaultCenter] nowPlayingInfo] mutableCopy];
    
    if (![[songInfo objectForKey:MPNowPlayingInfoCollectionIdentifier] isEqualToString:_currentSong.sid]) {
        songInfo = [self loadPlayingInfoAtSongLoad:NO];
    }
    
    NSNumber *newRate = [NSNumber numberWithFloat:self.player.rate];
    
    [songInfo setObject:[NSNumber numberWithDouble:durationAsSeconds]
                 forKey:MPMediaItemPropertyPlaybackDuration];
    
    [songInfo setObject:newRate
                 forKey:MPNowPlayingInfoPropertyPlaybackRate];
    
    [songInfo setObject:[NSNumber numberWithDouble:currentTimeAsSeconds]
                 forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
    
    MPMediaItemArtwork *albumArt = nil;
    
    UIImage *albumThumb = [currentSong.album smallThumbnailAsImg];
    
    if ([currentSong.album largeThumbnailAsImg]) {
        albumThumb = [currentSong.album largeThumbnailAsImg];
    }
    
    if (albumThumb) {
        albumArt = [[MPMediaItemArtwork  alloc] initWithBoundsSize:albumThumb.size requestHandler:^UIImage * _Nonnull(CGSize size) {
            if (weakSelf.currentSongIsInRepeatModeDueToBadNetwork
                || [weakSelf.playerStateBeforeBadNetworkHappen count] > 0) {
                
                return [weakSelf getMediaCenterThumbWithText:NSLocalizedString(@"player_bad_network_playlist_error_title", nil) forSong: currentSong];
            }
            
            if (_repeatMode == BLYPlayerViewControllerRepeatModeOne) {
                return [weakSelf getMediaCenterThumbWithText:NSLocalizedString(@"repeated", nil) forSong: currentSong];
            }
            
            return albumThumb;
        }];
    }
    
    if (albumArt) {
        [songInfo setObject:albumArt
                     forKey:MPMediaItemPropertyArtwork];
    }
    
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:songInfo];
    
//    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
//
//    if (self.playerStatus == BLYPlayerViewControllerPlayerStatusLoading && [newRate doubleValue] == 0.0 && !self.currentSong.isCached) {
//        [commandCenter.playCommand setEnabled:NO];
//        [commandCenter.pauseCommand setEnabled:NO];
//
//        [commandCenter.togglePlayPauseCommand setEnabled:NO];
//    } else {
//        [commandCenter.playCommand setEnabled:true];
//        [commandCenter.pauseCommand setEnabled:true];
//
//        [commandCenter.togglePlayPauseCommand setEnabled:true];
//    }
}

- (void)updatePlaybackInfo:(CMTime)currentTime
{
    BLYTimeManager *timeManager = [[BLYTimeManager alloc] init];
    double durationAsSeconds = [self currentDurationAsSecond];
    double currentTimeAsSeconds = round(fabs(CMTimeGetSeconds(currentTime)));
    
    // Call this to update previous song button status
    [self managePlaylistPlayControlsForSong:self.currentSong];
    
    if (currentTimeAsSeconds > durationAsSeconds || self.loadCurrentSongAtTime > 0.0) {
        return;
    }
    
    NSString *stringWithFormatForDuration = [timeManager durationAsString:durationAsSeconds];
    NSString *stringWithFormatForCurrentTime = [timeManager durationAsString:currentTimeAsSeconds];
    NSString *stringWithFormatForRemainingTime = [NSString stringWithFormat:@"-%@", [timeManager durationAsString:durationAsSeconds - currentTimeAsSeconds]];
    
//    if (self.isPlaying
//        && currentTimeAsSeconds > 0.0
//        && (!self.playNotificationSendedForCurrentSong
//            || currentTimeAsSeconds <= BLYPlayerViewControllerMinElapsedTimeForRateObserverToSendPlayNotification)) {
//        [self postPlayNotification];
//    }
    
    if (currentTimeAsSeconds >= 0 && durationAsSeconds > 0.0) {
        [self.playbackDurationLabel setText:stringWithFormatForRemainingTime];
        [self.playbackCurrentTimeLabel setText:stringWithFormatForCurrentTime];
    }
    
    if (self.isFullscreen) {
        if (durationAsSeconds > 0) {
            if (currentTimeAsSeconds >= 0 && durationAsSeconds > 0.0) {
                [[[BLYFullScreenPlayerViewController sharedVC] playbackDurationLabel] setText:stringWithFormatForRemainingTime];
                [[[BLYFullScreenPlayerViewController sharedVC] playbackCurrentTimeLabel] setText:stringWithFormatForCurrentTime];
            }
        }
        
       // if (currentTimeAsSeconds > 0) {
            //[[[BLYFullScreenPlayerViewController sharedVC] playbackCurrentTimeLabel] setText:stringWithFormatForCurrentTime];
       // }
    }
    
    NSMutableDictionary *playerState = self.playerStateBeforeBadNetworkHappen;
    
    // Bad network playlist is loaded, check to see if we can go back to last played playlist
    int remainingTimeBeforeEnd = durationAsSeconds - currentTimeAsSeconds;
    
    if (remainingTimeBeforeEnd <= 11.0
        && [[BLYNetworkStore sharedStore] networkIsDataNetwork]
        && [playerState count] > 0
        && !self.bgPlayerHasSufficientBuffer
        && !self.bgPlayerWasSuccessfullyLoadedWithNextSong
        && (self.repeatMode != BLYPlayerViewControllerRepeatModeOne
            || [self.playlist nbOfSongs] == 1)) {
        
        BLYSong *currentSong = self.currentSong;
        BLYSong *songPlayedBeforeBadNetworkHappen = [playerState objectForKey:@"currentSong"];
        BLYPlaylist *playlistPlayedBeforeBadNetworkHappen = [playerState objectForKey:@"playlist"];
        
        __weak BLYPlayerViewController *weakSelf = self;
        
        void(^videoLoaded)(BLYSong *) = ^(BLYSong *song){
            if (![weakSelf.currentSong isEqual:currentSong]) {
                return;
            }
            
            [weakSelf loadBackgroundPlayerWithSong:songPlayedBeforeBadNetworkHappen];
        };
        
        self.bgPlayerHasSufficientBuffer = ^{
            if (![weakSelf.currentSong isEqual:currentSong]) {
                return;
            }
            
            weakSelf.bgPlayerWasSuccessfullyLoadedWithNextSong = ^{
                weakSelf.playerStateBeforeBadNetworkHappen = [[NSMutableDictionary alloc] init];
                
                [weakSelf loadPlaylist:playlistPlayedBeforeBadNetworkHappen
                      andStartWithSong:songPlayedBeforeBadNetworkHappen
                           askedByUser:[songPlayedBeforeBadNetworkHappen.loadedByUser boolValue]];
            };
        };
        
        BOOL loadVideo = [self loadVideoForSong:songPlayedBeforeBadNetworkHappen
                                   inBackground:YES
                                 withCompletion:videoLoaded];
        
        // Ok video is already available
        if (!loadVideo) {
            videoLoaded(nil);
        }
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    __weak BLYPlayerViewController *weakSelf = self;
    void (^readyToPlayComplete)(void) = ^{
        // Play at user wanted when video URL has expired
        if (weakSelf.loadCurrentSongAtTime > 0.0) {
            weakSelf.playbackSlider.value = weakSelf.loadCurrentSongAtTime / [weakSelf currentDurationAsSecond];
            
            [weakSelf seekToTimeEnd:weakSelf.playbackSlider
         afterUrlForSongWasRefreshed:YES];
        } else {
            weakSelf.playing = true;
            weakSelf.playerStatus = BLYPlayerViewControllerPlayerStatusPlaying;
            
            [weakSelf postPlayNotification];
            
            if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive
                && !self.isVisible) {
                // Wait until UI was updated for play
                // Looks way better for songs which start sound at 00:00
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf play];
                    [weakSelf enablePlaybackSlider];
                });
            } else {
                [weakSelf play];
                [weakSelf enablePlaybackSlider];
            }
        }
    };
    
    if (object == self.backgroundPlayer
        || object == self.backgroundPlayer.currentItem) {
        NSMutableArray *kvoCalls = [self bgPlayerKvoCalls];
        
        [kvoCalls addObject:@{@"keyPath": keyPath,
                              @"object": object,
                              @"change": change}];
        
        if (object == self.backgroundPlayer
            && [keyPath isEqualToString:@"status"]) {
            
            AVPlayerStatus newStatus = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
            
            // BG player has thrown an error, try to reload
            if (newStatus == AVPlayerStatusFailed) {
                return [self loadBackgroundPlayerWithNextSong];
            }
        }
        
        if (![keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
            return;
        }
    }
    
    if ([object isKindOfClass:[AVPlayer class]]) {
        AVPlayer *player = object;
        
        if ([keyPath isEqualToString:@"status"]) {
            AVPlayerStatus newStatus = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
            
            switch (newStatus) {
                case AVPlayerStatusUnknown:
                {
                    // Indicates that the status of the player is not yet known because it has not tried to load new media resources for playback.
                    NSLog(@"AVPlayerStatusUnknown");
                    
                    break;
                }
                
                case AVPlayerStatusReadyToPlay:
                {
                    //Indicates that the player is ready to play AVPlayerItem instances.
                    //readyToPlayComplete();
                    
                    break;
                }
                    
                case AVPlayerStatusFailed:
                {
                    [self handlePlayerError];
                    
                    [self loadPlaybackInfoForPlayerError:player.error];
                    
                    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
                        [[BLYErrorStore sharedStore] manageError:player.error forViewController:self.isFullscreen ? [BLYFullScreenPlayerViewController sharedVC] : self];
                    }
                    
                    break;
                }
            }
        } else if ([keyPath isEqualToString:@"currentItem"]) {
            //readyToPlayComplete();
        } else if ([keyPath isEqualToString:@"rate"]) {
            float newRate = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
            BOOL isPlaying = newRate != 0.0;
            
            self.playing = isPlaying;
            
            if (isPlaying) {
                self.playerSeekToTimeFrameImg.hidden = true;
                [[BLYFullScreenPlayerViewController sharedVC] playerSeekToTimeFrameImg].hidden = true;
            }
            
            if ((!isPlaying && self.playerStatus == BLYPlayerViewControllerPlayerStatusPaused)
                || (isPlaying && self.playerStatus == BLYPlayerViewControllerPlayerStatusPlaying)) {
                
                return;
            }
            
            self.playerStatus = isPlaying
                ? BLYPlayerViewControllerPlayerStatusPlaying
                : BLYPlayerViewControllerPlayerStatusPaused;
            
            double currentTime = CMTimeGetSeconds([self.player.currentItem currentTime]);
            
            if (self.isPlaying) {
//                if (currentTime > BLYPlayerViewControllerMinElapsedTimeForRateObserverToSendPlayNotification) {
//                    [self postPlayNotification];
//                }
                
                [self postPlayNotification];
                
                [self stopBackgroundTask];
            } else {
//                if (currentTime > 0.0) {
//                    [self postPauseNotification];
//                }
                [self postPauseNotification];
            }
        }
    } else if ([object isKindOfClass:[AVPlayerItem class]]) {
        AVPlayerItem *item = (AVPlayerItem *)object;
        
        if ([keyPath isEqualToString:@"status"]) {
            AVPlayerItemStatus newStatus = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
            
            switch (newStatus) {
                case AVPlayerItemStatusUnknown:
                {
                    NSLog(@"AVPlayerItemStatusUnknown");
                }
                    
                case AVPlayerItemStatusReadyToPlay:
                {
                    // [self stopTimeToLoadSongTimer];
                    
                    readyToPlayComplete();
                    
                    break;
                }
                    
                case AVPlayerItemStatusFailed:
                {
                    [self handlePlayerError];
                    
                    //[[BLYVideoStore sharedStore] removeVideosForSong:self.currentSong];
                    
                    [self loadPlaybackInfoForPlayerError:item.error];
                    
                    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
                        [[BLYErrorStore sharedStore] manageError:item.error forViewController:self.isFullscreen ? [BLYFullScreenPlayerViewController sharedVC] : self];
                    }
                    
                    break;
                }
            }
        } else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
            if ([item isPlaybackBufferEmpty] && self.userWantsPlay) {
                [self startBackgroundTask];
                
                // Before pause !
                self.songWasPausedBecauseEmptyBuffer = YES;
                
                [self handleSongIsLoading];
                [self pause:NO];
                
                [self postLoadNotification];
                
                self.playerStatus = BLYPlayerViewControllerPlayerStatusLoading;
                
                // Video URL has expired
                if ([self.currentVideoURLExpiresAt timeIntervalSinceNow] <= 0) {
                    CMTime currentTime = [self.player.currentItem currentTime];
                    double currentTimeAsSeconds = round(fabs(floor(CMTimeGetSeconds(currentTime))));
                    
                    [self loadSong:self.currentSong
                                at:currentTimeAsSeconds
                       askedByUser:[self.currentSong.loadedByUser boolValue]];
                    
                    return;
                }
                
//                if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive
//                    && [[BLYNetworkStore sharedStore] networkIsReachable]) {
//
//                    return;
//                }
                
                [self handleBufferIsEmptyDuringMaxTime:nil];
                
//                if (![[BLYNetworkStore sharedStore] networkIsReachable]) {
//                    [self handleBufferIsEmptyDuringMaxTime:nil];
//
//                    return;
//                }
//
//                [self setEmptyBufferTimer:[NSTimer scheduledTimerWithTimeInterval:5.0
//                                                                           target:self
//                                                                         selector:@selector(handleBufferIsEmptyDuringMaxTime:)
//                                                                         userInfo:nil
//                                                                          repeats:NO]];
            }
        } else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
            if (self.backgroundPlayer.currentItem
                && item == self.backgroundPlayer.currentItem) {
                
                if (self.bgPlayerWasSuccessfullyLoadedWithNextSong) {
                    return;
                }
                
                if (self.bgPlayerHasSufficientBuffer) {
                    self.bgPlayerHasSufficientBuffer();
                    self.bgPlayerHasSufficientBuffer = nil;
                }
                
                return;
            }
            
            if (item.isPlaybackLikelyToKeepUp && self.songWasPausedBecauseEmptyBuffer) {
                [self play];
                
                self.songWasPausedBecauseEmptyBuffer = NO;
                
                //[self stopBackgroundTask];
            }
            
            [self clearBufferIsEmptyTimer];
            //[self handleSongIsLoaded];
        } else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
            NSArray *loadedTimeRanges = [change objectForKey:NSKeyValueChangeNewKey];
            CMTimeRange timeRange = [[loadedTimeRanges lastObject] CMTimeRangeValue];
            
            float startSeconds = CMTimeGetSeconds(timeRange.start);
            float durationSeconds = CMTimeGetSeconds(timeRange.duration);
            
            // Add startSeconds in case of user seek to specified time
            float loadedPercent = MIN(1.0, (startSeconds + durationSeconds) / [self currentDurationAsSecond]);
            
//            // Called by background player change current duration
//            if (self.backgroundPlayer.currentItem
//                && item == self.backgroundPlayer.currentItem) {
//                
//                loadedPercent = MIN(1.0, (startSeconds + durationSeconds) / [self currentDurationAsSecondForPlayer:self.backgroundPlayer]);
//            }
            
            if (loadedPercent > 0.99) {
                loadedPercent = 1.0;
            }
            
//            if (self.backgroundPlayer.currentItem
//                && item == self.backgroundPlayer.currentItem) {
//                
//                if (self.bgPlayerWasSuccessfullyLoadedWithNextSong) {
//                    return;
//                }
//                
//                if (self.bgPlayerHasSufficientBuffer && loadedPercent == 1.0) {
//                    self.bgPlayerHasSufficientBuffer();
//                }
//                
//                return;
//            }
            
//            if (CMTimeGetSeconds([self.player.currentItem currentTime]) <= 1.0
//                && loadedPercent == 1.0
//                && context != BLYPlayerViewControllerBGPlayerContext
//                && !_currentVideo.path) {
//                
//                return;
//            }
            
            [self setBufferingBarProgress:loadedPercent
                                 animated:YES];
            
            // loaded time ranges is called after play/pause... so check if handlecompletebuffer was called only once
            if (loadedPercent == 1.0 && !self.completeBufferCallbackCalled) {
                [self handleCompleteBuffer];
                
                self.completeBufferCallbackCalled = YES;
                
                // Post after complete buffer flag was set
                [[NSNotificationCenter defaultCenter] postNotificationName:BLYPlayerViewControllerDidCompleteVideoBuffering
                                                                    object:self];
            }
            
            //[[self playerContainer] sendSubviewToBack:[self playerCoverBackground]];
            //[[self playerLayer] setOpacity:1.0];
        } else if ([keyPath isEqualToString:@"duration"]) {
            [[BLYSongStore sharedStore] updateSongDuration:lroundf(CMTimeGetSeconds([item duration]))
                                        forSongWithID:self.currentSong.sid];
            
            [[BLYStore sharedStore] saveChanges];
            
            // We need current item duration for interval
            [self startSongPlayingTimerForPersonalTop];
        }
    }
}

- (void)clearBufferIsEmptyTimer
{
    [self.emptyBufferTimer invalidate];
    
    self.emptyBufferTimer = nil;
}

- (void)handleBufferIsEmptyDuringMaxTime:(NSTimer *)timer
{
    int attempts = self.rewindCurrentSongDueToBadNetworkAttempts;
    __weak BLYPlayerViewController *weakSelf = self;
    
    self.rewindCurrentSongDueToBadNetworkAttempts = attempts + 1;
    
    if (attempts >= 2 && [[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
        if ([self loadBadNetworkPlaylistAtEnd:NO]) {
            return;
        }
    }
    
    _currentSongIsInRepeatModeDueToBadNetwork = true;
    
    [self rewindAtEnd:NO withCompletion:^{
        weakSelf.playNotificationSendedForCurrentSong = NO;

        [weakSelf play];
    }];
    
//    if ((attempts < 2
//         && ([[BLYNetworkStore sharedStore] networkIsReachable]
//             || self.repeatMode == BLYPlayerViewControllerRepeatModeOne))
//        || ![self loadBadNetworkPlaylistAtEnd:NO]) {
//
//        [self rewindAtEnd:NO withCompletion:^{
//            weakSelf.playNotificationSendedForCurrentSong = NO;
//
//            [weakSelf play];
//        }];
//    }
}

- (BOOL)loadBadNetworkPlaylistAtEnd:(BOOL)atEnd
{
    BLYSong *currentSong = nil;
    
    if (atEnd) {
        currentSong = [self songPlayedAfterSong:_currentSong];
        
        if (!currentSong) {
            currentSong = [self.playlist songAtIndex:0];
        }
    }
    
    if (!currentSong) {
        currentSong = self.currentSong;
    }
    
    NSMutableDictionary *playerState = [[NSMutableDictionary alloc] init];
    
    [playerState setObject:self.playlist
                    forKey:@"playlist"];
    
    [playerState setObject:currentSong
                    forKey:@"currentSong"];
    
    [playerState setObject:[NSNumber numberWithBool:NO]
                    forKey:@"badNetworkPlaylistNotificationWasDisplayed"];
    
    /* Try to load cached songs in current playlist */
    
    BLYSong *song = self.currentSong;
    BLYSong *firstCachedNextSong = [self firstCachedNextSongForSong:song];
    BLYSong *songToLoad = nil;
    
    BLYSong *_firstCachedPreviousSong = song;
    BLYSong *firstCachedPreviousSong = nil;
    
    while ((_firstCachedPreviousSong = [self firstCachedPreviousSongForSong:_firstCachedPreviousSong])) {
        firstCachedPreviousSong = _firstCachedPreviousSong;
    }
    
    if (firstCachedNextSong) {
        songToLoad = firstCachedNextSong;
    } else if (firstCachedPreviousSong) {
        songToLoad = firstCachedPreviousSong;
    }
    
    if (songToLoad) {
        self.playerStateBeforeBadNetworkHappen = playerState;
        
        [self loadSong:songToLoad askedByUser:NO];
        
        [self showBadNetworkPlaylistNotificationIfNecessary];
        
        return true;
    }
    
    /* Load cached songs not in current playlist if current playlist not playable */
    
    BLYPlaylist *playlist = [[BLYPlaylist alloc] init];
    NSMutableArray *topSongs = [[BLYPersonalTopSongStore sharedStore] fetchPersonalTopSongWithCachedVideos];
    NSMutableArray *playedSongs = [[BLYPlayedSongStore sharedStore] fetchPlayedSongsWithCachedVideos];
    
    // Randomize the order of the first five top songs
    if ([topSongs count] > 1) {
        NSMutableArray *bestTopSongs = [[topSongs subarrayWithRange:NSMakeRange(0, MIN(5, [topSongs count]))] mutableCopy];
        
        [bestTopSongs bly_shuffle];
        
        if ([bestTopSongs count] < [topSongs count]) {
            NSArray *otherTopSongs = [topSongs subarrayWithRange:NSMakeRange([bestTopSongs count], [topSongs count] - [bestTopSongs count])];
            
            [bestTopSongs addObjectsFromArray:otherTopSongs];
        }
        
        topSongs = bestTopSongs;
    }
    
    for (BLYSong *song in topSongs) {
        [playlist addSong:song];
    }

    [playedSongs sortUsingComparator:^NSComparisonResult(id obj1, id obj2){
        BLYSong *song1 = obj1;
        BLYSong *song2 = obj2;

        if (song1.lastPlayPlayedPercent > song2.lastPlayPlayedPercent) {
            return NSOrderedAscending;
        } else if (song1.lastPlayPlayedPercent < song2.lastPlayPlayedPercent) {
            return NSOrderedDescending;
        }

        return NSOrderedSame;
    }];
    
    for (BLYSong *song in playedSongs) {
        if ([topSongs containsObject:song]) {
            continue;
        }

        [playlist addSong:song];
    }
    
    if ([playlist nbOfSongs] == 0) {
        return NO;
    }

    // Playlist will start with the song that just be played
    if ([playlist nbOfSongs] > 1 && [playlist indexOfSong:self.currentSong] == 0) {
        NSMutableArray *songs = [playlist.songs mutableCopy];
        BLYSong *nextSong = [songs objectAtIndex:1];

        // Replace current song with song played after it
        [songs removeObjectAtIndex:1];
        [songs replaceObjectAtIndex:0
                         withObject:nextSong];

        // Add current song to end of array
        [songs addObject:self.currentSong];

        playlist.songs = songs;
    }
    
    self.playerStateBeforeBadNetworkHappen = playerState;
    
    [self loadPlaylist:playlist
      andStartWithSong:[playlist songAtIndex:0]
           askedByUser:NO];
    
    [self showBadNetworkPlaylistNotificationIfNecessary];
    
    return YES;
}

- (void)showBadNetworkPlaylistNotificationIfNecessary
{
    NSMutableDictionary *playerState = self.playerStateBeforeBadNetworkHappen;
    
    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive
        || [playerState count] == 0
        || [playerState[@"badNetworkPlaylistNotificationWasDisplayed"] boolValue]) {
        
        return;
    }
    
    UIAlertController * alert = [UIAlertController
                                 alertControllerWithTitle:NSLocalizedString(@"player_bad_network_playlist_error_title", nil)
                                 message:NSLocalizedString(@"player_bad_network_playlist_error_content", nil)
                                 preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelButton = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"OK", nil)
                                   style:UIAlertActionStyleCancel
                                   handler:nil];
    
    [alert addAction:cancelButton];
    
    [self presentViewController:alert animated:YES completion:nil];
    
//    OLGhostAlertView *ghastly = [[OLGhostAlertView alloc] initWithTitle:NSLocalizedString(@"player_bad_network_playlist_error_title", nil)
//                                                                message: NSLocalizedString(@"player_bad_network_playlist_error_content", nil)
//                                                                timeout:8.0
//                                                            dismissible:YES];
//
//    [ghastly setStyle:OLGhostAlertViewStyleLight];
//    [ghastly setPosition:OLGhostAlertViewPositionCenter];
//
//    [ghastly show];
    
    playerState[@"badNetworkPlaylistNotificationWasDisplayed"] = [NSNumber numberWithBool:YES];
    
    self.playerStateBeforeBadNetworkHappen = playerState;
}

- (void)workAfterBGWorkTerminatedRecursive:(BOOL)recursive
{
    BLYSong *song = self.currentSong;
    __weak BLYPlayerViewController *weakSelf = self;
    
    if ([[BLYNetworkStore sharedStore] networkIsReachableViaWifi] && !_songCaching) {
        NSArray *cachedSongsIn3gp = [[BLYCachedSongStore sharedStore] fetchCachedSongsIn3GP];
        
        if ([cachedSongsIn3gp count] > 0) {
            BLYSong *songToRecache = ((BLYCachedSong *)[cachedSongsIn3gp objectAtIndex:0]).song;
            
            [[BLYSongCachingStore sharedStore] cacheSong:songToRecache askedByUser:NO withCompletion:^(NSError *err) {
                if (!_songCaching) {
                    return;
                }
                
                _songCaching = nil;
                
                if (err || [cachedSongsIn3gp count] == 1) {
                    return;
                }
                
                [weakSelf workAfterBGWorkTerminatedRecursive:true];
            }];
            
            _songCaching = songToRecache;
        }
    }
    
    if (recursive) {
        return;
    }
    
    if ([song.album largeThumbnail]) {
        return;
    }
    
    NSMutableString *largeAlbumThumbnailURL = [[song.album smallThumbnail].url mutableCopy];
    
    if ([song.isVideo boolValue]) {
        [largeAlbumThumbnailURL replaceOccurrencesOfString:@"hqdefault"
                                                withString:@"maxresdefault"
                                                   options:NSCaseInsensitiveSearch
                                                     range:[largeAlbumThumbnailURL bly_fullRange]];
    } else {
        [largeAlbumThumbnailURL replaceOccurrencesOfString:@"225x225"
                                                withString:@"600x600"
                                                   options:NSCaseInsensitiveSearch
                                                     range:[largeAlbumThumbnailURL bly_fullRange]];
    }
    
    BLYAlbumThumbnail *largeAlbumThumbnail = [[BLYAlbumStore sharedStore] insertThumbnailWithData:nil size:@"600x600" andURL:largeAlbumThumbnailURL forAlbum:song.album];
    
    [[BLYSongStore sharedStore] loadThumbnail:largeAlbumThumbnail withCompletionBlock:^(BOOL completed) {
        if (!completed) {
            // Many videos don't have `maxresdefault` thumb...
            // Revert to `hqdefaault`
            if ([song.isVideo boolValue]) {
                [largeAlbumThumbnailURL replaceOccurrencesOfString:@"maxresdefault"
                                                        withString:@"hqdefault"
                                                           options:NSCaseInsensitiveSearch
                                                             range:[largeAlbumThumbnailURL bly_fullRange]];
                
                BLYAlbumThumbnail *largeAlbumThumbnail = [[BLYAlbumStore sharedStore] insertThumbnailWithData:nil size:@"600x600" andURL:largeAlbumThumbnailURL forAlbum:song.album];
                
                [[BLYSongStore sharedStore] loadThumbnail:largeAlbumThumbnail withCompletionBlock:^(BOOL completed) {
                    if (!completed) {
                        return;
                    }
                    
                    [weakSelf updatePlayerCoverBgForCurrentSong];
                }];
            }
            
            return;
        }
        
        [weakSelf updatePlayerCoverBgForCurrentSong];
    }];
}

- (void)postBGWorkTerminatedNotification
{
    BLYSong *song = self.currentSong;
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:song
                                                         forKey:@"currentSong"];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BLYPlayerViewControllerDidTerminateBGWorkNotification
                                                        object:self
                                                      userInfo:userInfo];
    
    
    [self workAfterBGWorkTerminatedRecursive:NO];
}

- (void)handleCompleteBuffer
{
    __weak BLYPlayerViewController *weakSelf = self;
    NSMutableDictionary *playerState = self.playerStateBeforeBadNetworkHappen;
    
    // Keep ref in case song change during video export
    BLYSong *currentSong = self.currentSong;
    NSString *currentVideoQuality = _currentVideoQuality;
    
    BLYAppDelegate *appDelegate = (BLYAppDelegate *)[[UIApplication sharedApplication] delegate];
    NSString *currentCountryCode = [appDelegate countryCodeForCurrentLocale];
    
    if (![currentSong isCached] && [currentCountryCode isEqualToString:@"fr"]) {
        BLYVideoSong *currentVideoSong = nil;
        BLYVideo *currentVideo = nil;
        
        currentVideoSong = [currentSong.videos objectAtIndex:0];
        currentVideo = currentVideoSong.video;
        
        AVAsset *currentPlayerAsset = self.player.currentItem.asset;
        
        AVAssetExportSession *exporter = [AVAssetExportSession exportSessionWithAsset:currentPlayerAsset presetName:AVAssetExportPresetHighestQuality];
        
        NSString *cacheDirectory = [[BLYStore sharedStore] cacheDirectory];
        
        NSString *videoName = [[NSProcessInfo processInfo] globallyUniqueString];
        NSString *videoPath = [cacheDirectory stringByAppendingPathComponent:videoName];
        
        exporter.outputURL = [NSURL fileURLWithPath:videoPath];
        exporter.outputFileType = AVFileTypeMPEG4; // [self.currentVideoType isEqualToString:@"mp4"] ? AVFileTypeMPEG4 : AVFileType3GPP;
        
        [exporter exportAsynchronouslyWithCompletionHandler:^{
            if (exporter.error) {
                NSLog(@"%ld", (long)exporter.status);
                NSLog(@"%@", exporter.error);
                
                return;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                // User has chosen another video for current song
                // between `exportAsynchronouslyWithCompletionHandler`
                // and here.
                // Make sure downloaded video will not be attached to wrong first video for song
                if (currentSong == weakSelf.currentSong
                    && currentVideo != _currentVideo) {
                    
                    NSError *error = nil;
                    
                    [[NSFileManager defaultManager] removeItemAtPath:videoPath error:&error];
                    
                    if (error) {
                        NSLog(@"Error during attempt to remove downloaded video: %@", error.localizedDescription);
                    }
                    
                    return;
                }
                
                [[BLYCachedSongStore sharedStore] moveDownloadedSong:currentSong
                                                                from:videoPath
                                                        videoQuality:currentVideoQuality
                                                         askedByUser:NO
                                                      withCompletion:^(NSError *error) {
                                                          
                                                      }];
            });
        }];
    }
    
    if (![[BLYNetworkStore sharedStore] networkIsReachable]
        || [playerState count] > 0) {
        
        return;
    }
    
    if (![[BLYNetworkStore sharedStore] networkIsReachableViaWifi]
        && [[BLYAppSettingsStore sharedStore] boolForSetting:BLYAppSettingsStoreForbidUcachedSongsListeningSetting]) {
        
        return;
    }
    
    __block BLYSong *songToPlayAfter = [self.playlist songAtIndex:0];
    
    void(^cacheCompletion)(NSError *err) = ^(NSError *err){
        if (![currentSong isEqual:weakSelf.currentSong]) {
            return;
        }
        
        weakSelf.songCaching = nil;
        
        if (err) {
//            if (err.code != BLYPlayedSongStoreExpiredURLErrorCode) {
//                return;
//            }
//            
//            NSDictionary *userInfo = [err userInfo];
//            BLYSong *loadedSong = [userInfo objectForKey:@"loadedSong"];
//            
//            [weakSelf loadVideoForSong:loadedSong
//                          inBackground:YES
//                        withCompletion:^(BLYSong *song){
//                if (![currentSong isEqual:weakSelf.currentSong]) {
//                    return;
//                }
//                
//                [weakSelf handleCompleteBuffer];
//            }];
            
            return;
        }
        
        [weakSelf handleCompleteBuffer];
    };
    
//    if ([[BLYNetworkStore sharedStore] networkIsDataNetwork]
//        && ([[BLYNetworkStore sharedStore] networkIsReachableViaWifi]
//            || [self.currentSong.loadedByUser boolValue])) {
//
//        if ([self cachePlayedSongWithCompletion:cacheCompletion]) {
//            return;
//        }
//    }
    
    void(^videoUrlsAreLoaded)(BLYSong *) = ^(BLYSong *song){
        if (![weakSelf.currentSong isEqual:currentSong]) {
            return;
        }
        
        if (!songToPlayAfter) {
            [weakSelf postBGWorkTerminatedNotification];
            
            return;
        }
        
//        [weakSelf loadBackgroundPlayerWithSong:songToPlayAfter];
//
//        return;
        
        if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
            [weakSelf loadBackgroundPlayerWithSong:songToPlayAfter];
        } else {
            weakSelf.loadBgPlayerWhenAppEnterBackgroundModeCallback = ^{
                [weakSelf loadBackgroundPlayerWithSong:songToPlayAfter];
            };
            
            [weakSelf postBGWorkTerminatedNotification];
        }
    };
    
    self.bgPlayerHasSufficientBuffer = ^{
        if (![weakSelf.currentSong isEqual:currentSong]) {
            return;
        }
        
        weakSelf.bgPlayerWasSuccessfullyLoadedWithNextSong = ^{
            [weakSelf loadSong:songToPlayAfter
                   askedByUser:NO];
        };
        
        [weakSelf postBGWorkTerminatedNotification];
    };
    
    /* Cache URL for uncached next song */
    
    BLYSong *nextSong = [self songPlayedAfterSong:currentSong];
    
    if (nextSong) {
        songToPlayAfter = nextSong;
    }
    
    if (![self loadVideoForSong:songToPlayAfter
                   inBackground:YES
                 withCompletion:videoUrlsAreLoaded]) {
        
        videoUrlsAreLoaded(nil);
    }
    
    return;

    while (nextSong && ![self loadVideoForSong:nextSong
                                  inBackground:YES
                                withCompletion:videoUrlsAreLoaded]) {
        
        nextSong = [self songPlayedAfterSong:nextSong];
    }
    
    BLYSong *previousSong = nil;
    
    if (!nextSong && [self.playlist nbOfSongs] > 1) {
        int i = 0;
        previousSong = [self.playlist songAtIndex:i];
        
        while (previousSong && ![self loadVideoForSong:previousSong
                                          inBackground:YES
                                        withCompletion:videoUrlsAreLoaded]) {
            i++;
            
            previousSong = nil;
            
            if (i < [self.playlist nbOfSongs]) {
                previousSong = [self.playlist songAtIndex:i];
            }
        }
    }
    
    // Ok all video URLs are cached
    if (!nextSong && !previousSong && [self.playlist nbOfSongs] > 1) {
        videoUrlsAreLoaded(nil);
    }
}

- (BOOL)cachePlayedSongWithCompletion:(void(^)(NSError *))cacheCompletion
{
    if (![[BLYAppSettingsStore sharedStore] boolForSetting:BLYAppSettingsStoreAutoDownloadTracksSetting]
        || ![[BLYNetworkStore sharedStore] networkIsReachableViaWifi]) {
        
        return false;
    }
    
    if ([[BLYSongCachingStore sharedStore] hasSongsCaching]
        || ![[BLYNetworkStore sharedStore] networkIsDataNetwork]) {
        
        return false;
    }
    
    if (!self.currentSong) {
        return false;
    }
    
    BLYSong *songToCache = [[BLYCachedSongStore sharedStore] songThatMustBeCachedButWhichAreNot];
    
    if (!songToCache) {
        return false;
    }

    [[BLYSongCachingStore sharedStore] cacheSong:songToCache askedByUser:NO withCompletion:cacheCompletion];
    
    _songCaching = songToCache;
    
    return true;
}

- (void)startBackgroundTask
{
    BLYAppDelegate *appDelegate = (BLYAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    [self stopBackgroundTask];
    
    self.bgTaskId = [appDelegate requestExtraBackgroundTime];
}

- (void)stopBackgroundTask
{
    if (self.bgTaskId == UIBackgroundTaskInvalid) {
        return;
    }
    
    BLYAppDelegate *appDelegate = (BLYAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    [appDelegate resignExtraBackgroundTime];
    
    self.bgTaskId = UIBackgroundTaskInvalid;
}

- (void)unloadPlayer
{
    NSError *error = self.player.error
        ? self.player.error
        : self.player.currentItem.error;
    
    if (!self.player) {
        return;
    }
    
    _playing = NO;
    
    if (!error) {
        [self pause:NO];
    } else {
        [self showPlayIcon];
        [self enablePlayPauseIcon];
    }
    
    [self.player removeTimeObserver:self.periodicTimeObserverForPlayer];
    // If unload player method is called many times
    // without calling load player between
    // (ie. during track not found error for instance)
    // removing already removed time observer cause exception,
    // so make sure to set observer to nil.
    self.periodicTimeObserverForPlayer = nil;
    
    [self removeObserverforPlayerItem:self.player.currentItem forBackground:NO];
    
    self.playerItem = nil;
    
    // Replace current item not freezing UI if player was paused before ???
    // [self.player pause];
    
    if (error) {
        [self removeObserverForPlayer:self.player];
        
        [self removePlayerFromNotificationObserver];
        
        self.player = nil;
        
//        self.playbackDurationLabel.text = @"--:--";
//
//        if (self.isFullscreen) {
//            [[[BLYFullScreenPlayerViewController sharedVC] playbackDurationLabel] setText:@"--:--"];
//        }
        
        [self unloadPlayerLayer:YES];
    }
    
    if (self.loadCurrentSongAtTime == 0.0) {
        if (!error) {
            self.playbackDurationLabel.text = @"--:--";
            self.playbackCurrentTimeLabel.text = @"--:--";
        } else {
            self.playbackCurrentTimeLabel.text = @"00:00";
        }
        
        [self.playbackSlider setValue:0.0 animated:[self isVisible]];
    }
    
    [self setBufferingBarProgress:0.0 animated:NO];
    
    if (!error) {
        self.playerCoverBackground.image = nil;
    } else {
        [self.playerContainer bringSubviewToFront:self.playerCoverBackground];
    }
    
    self.playerLayer.opacity = 0.0;
    
    if (self.isFullscreen) {
        if (self.loadCurrentSongAtTime == 0.0) {
            if (!error) {
                [[[BLYFullScreenPlayerViewController sharedVC] playbackDurationLabel] setText:@"--:--"];
                [[[BLYFullScreenPlayerViewController sharedVC] playbackCurrentTimeLabel] setText:@"--:--"];
            } else {
                [[[BLYFullScreenPlayerViewController sharedVC] playbackCurrentTimeLabel] setText:@"00:00"];
            }
            
            [[[BLYFullScreenPlayerViewController sharedVC] playbackSlider] setValue:0.0 animated:YES];
        }
        
        if (!error) {
            [[[BLYFullScreenPlayerViewController sharedVC] playerCoverBackground] setImage:nil];
        }
    }
    
    // Play method will reload entire song when player has crashed
    if (!error) {
        [self disablePlayIcon];
    }
    
    [self disablePlaybackSlider];
}

- (void)removePlayerFromNotificationObserver
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidEnterBackgroundNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillEnterForegroundNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:nil];
}

- (void)unloadPlayerLayer:(BOOL)force
{
    if (!self.playerViewContainer.layer) {
        return;
    }
    
    NSMutableArray *layers = [self.playerViewContainer.layer.sublayers mutableCopy];
    
    for (CALayer *layer in layers) {
        if ([layer isKindOfClass:[AVPlayerLayer class]]) {
            [layer removeFromSuperlayer];
        }
    }
    
    if (force) {
        self.playerLayer = nil;
    }
}

- (void)enablePlayerTrackItem:(BOOL)enable
{
    NSArray *tracks = self.player.currentItem.tracks;
    
    for (AVPlayerItemTrack *playerItemTrack in tracks) {
        if ([playerItemTrack.assetTrack hasMediaCharacteristic:AVMediaCharacteristicVisual]) {
            playerItemTrack.enabled = enable;
        }
    }
}

- (AVPlayerLayer *)layerForPlayerWithFrame:(CGRect)frame forceNew:(BOOL)force
{
    AVPlayerLayer *playerLayer = self.playerLayer;
    
    if (!playerLayer || force) {
        playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
        
        playerLayer.videoGravity = AVLayerVideoGravityResize;
        playerLayer.needsDisplayOnBoundsChange = YES;
        playerLayer.backgroundColor = [[UIColor blackColor] CGColor];
        
        //playerLayer.borderColor = [[UIColor blackColor] CGColor];
        //playerLayer.borderWidth = 0.0;
    }
    
    playerLayer.frame = frame;
    
    return playerLayer;
}

- (void)loadPlayerLayerAndForceNew:(BOOL)force
{
    if (!self.player) {
        return;
    }
    
    [self unloadPlayerLayer:force];
    
    self.playerLayer = [self layerForPlayerWithFrame:self.playerViewContainer.bounds
                                            forceNew:force];
    
    [self.playerViewContainer.layer addSublayer:self.playerLayer];
    
    // Set hidden to no if player is the displayed VC
    if ([self.tabBarController.selectedViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navVC = (UINavigationController *)self.tabBarController.selectedViewController;
        UIViewController *firstVC = [navVC.childViewControllers objectAtIndex:0];
        
        if (firstVC == self.containerVC
            && self.containerVC.selectedChildVC == self) {
            self.playerLayer.hidden = NO;
        }
    }
    
    if ([self isFullscreen]) {
        [[BLYFullScreenPlayerViewController sharedVC] loadPlayerLayer];
    }
}

- (void)loadBackgroundPlayerWithNextSong
{
    BLYSong *nextSong = [self songPlayedAfterSong:self.currentSong];
    
    if ([self.playlist nbOfSongs] <= 1) {
        return;
    }
    
    if (!nextSong) {
        nextSong = [self.playlist songAtIndex:0];
    }
    
    [self loadBackgroundPlayerWithSong:nextSong];
}

- (void)loadBackgroundPlayerWithSong:(BLYSong *)song
{
    AVPlayer *bgPlayer = self.backgroundPlayer;
    static BLYSong *songLoaded = nil;
    
    songLoaded = song;
    
    void (^loadBackgroundPlayer)(BLYSong *) = ^(BLYSong *song) {
        BLYVideoSong *videoSong = [song.videos objectAtIndex:0];
        BLYVideo *video = videoSong.video;
        BLYVideoURL *videoUrl = [[BLYVideoStore sharedStore] bestURLForCurrentNetworkAndVideo:video];
        NSURL *url = [NSURL URLWithString:videoUrl.value];
        
        if (bgPlayer && [_songLoadedInBgPlayer.sid isEqualToString:song.sid]) {
            return;
        }
        
        if (video.path) {
            NSString *cacheDirectory = [[BLYStore sharedStore] cacheDirectory];
            NSString *videoPath = [cacheDirectory stringByAppendingPathComponent:video.path];
            
            url = [NSURL fileURLWithPath:videoPath];
        }
        
        [self unloadBackgroundPlayer];
        
        AVURLAsset *asset = [AVURLAsset assetWithURL:url];
        
        [asset.resourceLoader setDelegate:self queue:dispatch_get_main_queue()];
        
        AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:asset];
        AVPlayer *backgroundPlayer = [AVPlayer playerWithPlayerItem:playerItem];
        
        self.backgroundPlayer = backgroundPlayer;
        
        _songLoadedInBgPlayer = song;
        _videoQualityLoadedInBgPlayer = videoUrl.type.defaultContainer;
        
        [self addObserverForPlayer:backgroundPlayer];
        [self addObserverForPlayerItem:playerItem];
        
        self.bgPlayerKvoCalls = [[NSMutableArray alloc] init];
    };
    
    if (![song.videos count]) {
        [self loadVideoForSong:song inBackground:true withCompletion:^(BLYSong *song) {
            if (songLoaded != song) {
                return;
            }
            
            loadBackgroundPlayer(song);
        }];
    } else {
        BLYVideoSong *videoSong = [song.videos objectAtIndex:0];
        BLYVideo *video = videoSong.video;
        BLYVideoURL *videoUrl = [[BLYVideoStore sharedStore] bestURLForCurrentNetworkAndVideo:video];
        NSTimeInterval URLExpiresAt = [videoUrl.expiresAt timeIntervalSinceNow];
        
        if (video.path || URLExpiresAt > 0) {
            return loadBackgroundPlayer(song);
        }
        
        [self loadVideoForSong:song inBackground:true withCompletion:^(BLYSong *song) {
            if (songLoaded != song) {
                return;
            }
            
            loadBackgroundPlayer(song);
        }];
    }
}

- (void)unloadBackgroundPlayer
{
    AVPlayer *backgroundPlayer = self.backgroundPlayer;
    
    if (!backgroundPlayer) {
        return;
    }
    
    AVPlayerItem *backgroundPlayerItem = backgroundPlayer.currentItem;
    
    [self removeObserverForPlayer:backgroundPlayer];
    [self removeObserverforPlayerItem:backgroundPlayerItem forBackground:NO];
    
    self.backgroundPlayer = nil;
    _songLoadedInBgPlayer = nil;
}

- (NSURL *)urlOfCurrentItemForPlayer:(AVPlayer *)player
{
    if (!player) {
        return nil;
    }
    
    AVAsset *currentPlayerAsset = player.currentItem.asset;
    
    if (![currentPlayerAsset isKindOfClass:AVURLAsset.class]) {
        return nil;
    }
    
    // return the NSURL
    return [(AVURLAsset *)currentPlayerAsset URL];
}

- (void)addObserverForPlayer:(AVPlayer *)player
{
    [player addObserver:self
             forKeyPath:@"status"
                options:NSKeyValueObservingOptionNew
                context:NULL];
    
    [player addObserver:self
             forKeyPath:@"currentItem"
                options:NSKeyValueObservingOptionNew
                context:NULL];
    
    [player addObserver:self
             forKeyPath:@"rate"
                options:NSKeyValueObservingOptionNew
                context:NULL];
}

- (void)addObserverForPlayerItem:(AVPlayerItem *)playerItem
{
    BOOL isBackgroundPlayer = self.backgroundPlayer && self.backgroundPlayer.currentItem == playerItem;
    
    if (self.observerForCurrentItemIsSet && !isBackgroundPlayer) {
        return;
    }
    
    [playerItem addObserver:self
                 forKeyPath:@"playbackBufferEmpty"
                    options:NSKeyValueObservingOptionNew
                    context:NULL];
    
    [playerItem addObserver:self
                 forKeyPath:@"playbackLikelyToKeepUp"
                    options:NSKeyValueObservingOptionNew
                    context:NULL];
    
    [playerItem addObserver:self
                 forKeyPath:@"loadedTimeRanges"
                    options:NSKeyValueObservingOptionNew
                    context:NULL];
    
    [playerItem addObserver:self
                 forKeyPath:@"duration"
                    options:NSKeyValueObservingOptionNew
                    context:NULL];
    
    [playerItem addObserver:self
                 forKeyPath:@"status"
                    options:NSKeyValueObservingOptionNew
                    context:NULL];
    
    if (isBackgroundPlayer) {
        return;
    }
    
    self.observerForCurrentItemIsSet = YES;
}

- (void)removeObserverForPlayer:(AVPlayer *)player
{
    @try {
        [player removeObserver:self forKeyPath:@"status"];
        [player removeObserver:self forKeyPath:@"currentItem"];
        [player removeObserver:self forKeyPath:@"rate"];
    } @catch (id anException) {
        // do nothing, obviously it wasn't attached because an exception was thrown
    }
}

- (void)removeObserverforPlayerItem:(AVPlayerItem *)playerItem forBackground:(BOOL)forBackground
{
    BOOL isBackgroundPlayer = self.backgroundPlayer && self.backgroundPlayer.currentItem == playerItem;
    
    if (!self.observerForCurrentItemIsSet && !isBackgroundPlayer) {
        return;
    }
    
    @try {
        [playerItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
        [playerItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
        [playerItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
        [playerItem removeObserver:self forKeyPath:@"duration"];
        [playerItem removeObserver:self forKeyPath:@"status"];
    } @catch (id anException) {
        //do nothing, obviously it wasn't attached because an exception was thrown
    }
    
    if (isBackgroundPlayer) {
        return;
    }
    
    self.observerForCurrentItemIsSet = NO;
}

- (void)stopTimeToLoadSongTimer
{
    [self.timeToLoadSong invalidate];
    
    self.timeToLoadSong = nil;
}

- (void)startTimeToLoadSongTimer
{
    self.timeToLoadSong = [NSTimer scheduledTimerWithTimeInterval:4.0
                                                           target:self
                                                         selector:@selector(songTakesTooManyTimesToLoad)
                                                         userInfo:nil
                                                          repeats:NO];
}

- (void)loadPlayerWithSong:(BLYSong *)song andUrl:(BLYVideoURL *)videoUrl
{
    BLYVideoSong *videoSong = [song.videos objectAtIndex:0];
    BLYVideo *video = videoSong.video;
    
    if (!videoUrl) {
        videoUrl = [[BLYVideoStore sharedStore] bestURLForCurrentNetworkAndVideo:video];
    }
    
    NSURL *url = [NSURL URLWithString:videoUrl.value];
    
    self.currentVideo = video;
    
    // Keep ref to reload it when expired
    self.currentVideoURLExpiresAt = videoUrl.expiresAt;
    
    AVPlayer *avPlayer = self.player;
    AVPlayer *bgPlayer = self.backgroundPlayer;
    
    AVPlayerItem *playerItem = nil;
    BOOL forceNewLayer = NO;
    NSMutableArray *kvoCalls = nil;
    BOOL isVevo = [video.isVevo boolValue];
    
    self.vevoLogoButton.hidden = !isVevo;
    self.youtubeLogoButton.hidden = isVevo;
    
    // !video.path
    if (bgPlayer
        && [_songLoadedInBgPlayer.sid isEqualToString:song.sid]) {
        
        [self removeObserverForPlayer:avPlayer];
        
        avPlayer = bgPlayer;
        
        // Force player to reload
        self.player = nil;
        
        forceNewLayer = YES;
        
        playerItem = self.backgroundPlayer.currentItem;
        
        kvoCalls = self.bgPlayerKvoCalls;
        
        [self unloadBackgroundPlayer];
        
        _currentVideoQuality = _videoQualityLoadedInBgPlayer;
    }
    
    self.bgPlayerWasSuccessfullyLoadedWithNextSong = nil;
    
    if (!playerItem) {
        if (video.path) {
            NSString *cacheDirectory = [[BLYStore sharedStore] cacheDirectory];
            NSString *videoPath = [cacheDirectory stringByAppendingPathComponent:video.path];
            
            url = [NSURL fileURLWithPath:videoPath];
        }
        
        AVURLAsset *asset = [AVURLAsset assetWithURL:url];
        
        [asset.resourceLoader setDelegate:self queue:dispatch_get_main_queue()];
        
        playerItem = [AVPlayerItem playerItemWithAsset:asset];
        
        if (!video.path) {
            _currentVideoQuality = videoUrl.type.defaultContainer;
        } else {
            _currentVideoQuality = nil;
        }
    }
    
    if ([[(AVURLAsset *)playerItem.asset URL] isFileURL]) {
        self.currentVideoURLExpiresAt = [NSDate distantFuture];
    }
    
    self.playerItem = playerItem;
    
    [self addObserverForPlayerItem:playerItem];
    
    if (!avPlayer) {
        avPlayer = [AVPlayer playerWithPlayerItem:playerItem];
    }
    
    __weak BLYPlayerViewController *weakSelf = self;
    
    self.periodicTimeObserverForPlayer = [avPlayer addPeriodicTimeObserverForInterval:CMTimeMake(1.0, 1.0)
                                                                                queue:NULL
                                                                           usingBlock:^(CMTime time){
                                                                               [weakSelf heartbeat];
                                                                           }];
    
    [self startTimeToLoadSongTimer];

    if (self.player) {
        //[self unloadPlayer];
        
        [avPlayer replaceCurrentItemWithPlayerItem:playerItem];
        
        if (video.path) {
            //[self setBufferingBarProgress:1.0 animated:NO];
            
            //[self handleCompleteBuffer];
            
            //self.completeBufferCallbackCalled = YES;
        }
        
        return;
    }
    
    avPlayer.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    
    self.player = avPlayer;
    
    [self loadPlayerLayerAndForceNew:forceNewLayer];
    
    [self addObserverForPlayer:avPlayer];
    
    if (avPlayer != bgPlayer) {
        // Make sure to remove notification before in case player was unloaded in case of error
        [self removePlayerFromNotificationObserver];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillEnterForeground:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handlePlayerItemDidReachEnd:)
                                                     name:AVPlayerItemDidPlayToEndTimeNotification
                                                   object:nil];
    }
    
    if (avPlayer == bgPlayer) {
        for (NSDictionary *call in kvoCalls) {
            [self observeValueForKeyPath:call[@"keyPath"]
                                ofObject:call[@"object"]
                                  change:call[@"change"]
                                 context:BLYPlayerViewControllerBGPlayerContext];
        }
    }
    
    if (video.path) {
        //[self setBufferingBarProgress:1.0 animated:NO];
        
        //[self handleCompleteBuffer];
        
        //self.completeBufferCallbackCalled = YES;
    }
}

- (BOOL)songTakesTooManyTimesToLoad
{
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive
        || [self.currentSong.loadedByUser boolValue]) {
        
        return NO;
    }
    
//    if (self.playerStatus != BLYPlayerViewControllerPlayerStatusLoading) {
//        return NO;
//    }
    
    if ([self loadBadNetworkPlaylistAtEnd:NO]) {
        return true;
    }
    
    return NO;
}

- (void)heartbeat
{
    [self loadPlaybackInfo];
}

- (void)managePlaylistPlayControlsForSong:(BLYSong *)song
{
    if (!song) {
        return;
    }
    
    AVPlayer *player = self.player;
    BLYSong *previousSong = [self firstPlayablePreviousSongForSong:self.currentSong];
    BLYSong *_lastPlayableNextSong = self.currentSong;
    BLYSong *lastPlayableNextSong = nil;
    
    if (!previousSong && [self.playlist nbOfSongs] > 1) {
        while ((_lastPlayableNextSong = [self firstPlayableNextSongForSong:_lastPlayableNextSong])) {
            lastPlayableNextSong = _lastPlayableNextSong;
        }
        
        previousSong = lastPlayableNextSong;
    }
    
    if (!previousSong
        && (![self playerIsLoaded]
            || CMTimeGetSeconds([player currentTime]) < BLYPlayerViewControllerRewindOrPreviousSongTime
            || self.playerStatus == BLYPlayerViewControllerPlayerStatusError)) {
        [self disablePreviousIcon];
    } else {
        [self enablePreviousIcon];
    }
    
    BLYSong *nextSong = [self firstPlayableNextSongForSong:self.currentSong];
    
    BLYSong *_firstPlayablePreviousSong = self.currentSong;
    BLYSong *firstPlayablePreviousSong = nil;
    
    if (!nextSong) {
        while ((_firstPlayablePreviousSong = [self firstPlayablePreviousSongForSong:_firstPlayablePreviousSong])) {
            firstPlayablePreviousSong = _firstPlayablePreviousSong;
        }
        
        nextSong = firstPlayablePreviousSong;
    }
    
    if (!nextSong) {
        [self disableNextIcon];
    } else {
        [self enableNextIcon];
    }
}

- (void)handleSongIsLoading
{
    self.albumNameLabel.hidden = YES;
    self.repeatExplainLabel.hidden = YES;
    self.loadingView.hidden = NO;
    
    if (self.isFullscreen) {
        [[[BLYFullScreenPlayerViewController sharedVC] nextSongView] setHidden:YES];
        [[[BLYFullScreenPlayerViewController sharedVC] loadingView] setHidden:NO];
        [[BLYFullScreenPlayerViewController sharedVC] showPlayerControlsForSongLoading];
    }
}

- (void)handleSongIsLoaded
{
    self.loadingView.hidden = YES;
    self.albumNameLabel.hidden = NO;
    self.repeatExplainLabel.hidden = NO;
    
    if (self.isFullscreen) {
        [[[BLYFullScreenPlayerViewController sharedVC] loadingView] setHidden:YES];
        [[BLYFullScreenPlayerViewController sharedVC] updateNextSongView];
        [[BLYFullScreenPlayerViewController sharedVC] hidePlayerControlsForSongLoading];
    }
    
    [self stopTimeToLoadSongTimer];
}

- (BOOL)isCurrentSong:(BLYSong *)song
{
    return self.currentSong && [self.currentSong isEqual:song];
}

- (BOOL)canPlaySong:(BLYSong *)song
{
    if (!song) {
        return NO;
    }
    
    BOOL itsCurrentSong = [self isCurrentSong:song];
    
    return ([[BLYNetworkStore sharedStore] networkIsReachable] || itsCurrentSong || [song isCached])
        && ([[BLYNetworkStore sharedStore] networkIsReachableViaWifi]
            || ![[BLYAppSettingsStore sharedStore] boolForSetting:BLYAppSettingsStoreForbidUcachedSongsListeningSetting]
            || [song isCached]);
}

- (BLYSong *)firstPlayableNextSongForSong:(BLYSong *)song
{
    if (!song) {
        return nil;
    }
    
    while ((song = [self songPlayedAfterSong:song])) {
        if ([self canPlaySong:song]) {
            return song;
        }
    }
    
    return nil;
}

- (BLYSong *)firstCachedNextSongForSong:(BLYSong *)song
{
    if (!song) {
        return nil;
    }
    
    while ((song = [self songPlayedAfterSong:song])) {
        if ([song isCached]) {
            return song;
        }
    }
    
    return nil;
}

- (BLYSong *)firstPlayablePreviousSongForSong:(BLYSong *)song
{
    if (!song) {
        return nil;
    }
    
    while ((song = [self songPlayedBeforeSong:song])) {
        if ([self canPlaySong:song]) {
            return song;
        }
    }
    
    return nil;
}

- (BLYSong *)firstCachedPreviousSongForSong:(BLYSong *)song
{
    if (!song) {
        return nil;
    }
    
    while ((song = [self songPlayedBeforeSong:song])) {
        if ([song isCached]) {
            return song;
        }
    }
    
    return nil;
}

- (void)loadSong:(BLYSong *)song askedByUser:(BOOL)askedByUser
{
    [self loadSong:song at:0.0 askedByUser:askedByUser];
}

- (void)updateNavLeftButtonTitleForSong:(BLYSong *)song
{
    [self updateNavLeftButtonTitleForSong:song
                                  orTitle:nil];
}

- (void)updateNavLeftButtonTitleForSong:(BLYSong *)song
                                orTitle:(NSString *)title
{
    NSString *originalSongTitle = [self.playlist nbOfSongs] > 1 && NO ? [NSString stringWithFormat:@"%d. %@", [self.playlist indexOfSong:self.currentSong] + 1, title ? title : song.title] : song.title;
    NSString *originalArtistName = song.artist.name;
    
    NSString *songTitle = originalSongTitle;
    
    NSString *featPattern = @"((?:\\(|\\[)(?:feat|ft)\\..+(?:\\)|\\]))";
    
    BOOL songTitleHasFeat = [originalSongTitle bly_match:featPattern];
    
    NSRegularExpression *featInArtistNameReg = [[NSRegularExpression alloc] initWithPattern:@"\\s*((?:,|&).+)$"
                                                                                    options:NSRegularExpressionCaseInsensitive
                                                                                      error:nil];
    
    NSArray *featMatches = [featInArtistNameReg matchesInString:originalArtistName
                                                        options:0
                                                          range:[originalArtistName bly_fullRange]];
    
    NSString *featInArtistName = nil;
    NSString *realArtistName = [[BLYSongStore sharedStore] realNameForArtist:song.artist.ref];
    
    if ([featMatches count] > 0) {
        NSTextCheckingResult *result = [featMatches objectAtIndex:0];
        
        if ([result numberOfRanges] >= 2) {
            NSRange r = [result rangeAtIndex:1];
            
            featInArtistName = [originalArtistName substringWithRange:r];
            
            featInArtistName = [featInArtistName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            featInArtistName = [featInArtistName stringByTrimmingCharactersInSet:[NSCharacterSet punctuationCharacterSet]];
            featInArtistName = [featInArtistName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            
            if (!realArtistName) {
                originalArtistName = [originalArtistName substringWithRange:NSMakeRange(0, r.location)];
            }
        }
    }
    
    if (realArtistName) {
        originalArtistName = [originalArtistName substringToIndex:MIN([realArtistName length] * 1.0, [originalArtistName length] * 1.0)];
        
        originalArtistName = [originalArtistName stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@",& "]];
    }
    
    if (!songTitleHasFeat && featInArtistName) {
        originalSongTitle = [originalSongTitle stringByAppendingString:[NSString stringWithFormat:@" (feat. %@)", featInArtistName]];
    }
    
    songTitle = [songTitle stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    songTitle = [songTitle bly_stringByRemovingParenthesisAndBracketsContent];
    
    NSString *cuttedArtistName = originalArtistName;
    
    UIFont *navButtonItemFont = [UIFont fontWithName:@"HelveticaNeue-Light" size:34.0];
    UIFont *navItemTitleFont = [UIFont fontWithName:@"HelveticaNeue-Medium" size:34.0];
    
    NSDictionary *songTitleFontAttributes = [NSDictionary dictionaryWithObjectsAndKeys:navItemTitleFont, NSFontAttributeName, nil];
    CGFloat songTitleWidth = [originalSongTitle bly_widthForStringWithAttributes:songTitleFontAttributes];
    
    NSDictionary *artistNameFontAttributes = [NSDictionary dictionaryWithObjectsAndKeys:navButtonItemFont, NSFontAttributeName, nil];
    CGFloat artistNameWidth = [originalArtistName bly_widthForStringWithAttributes:artistNameFontAttributes];
    
    int minArtistNameLength = 6;
    float maxCombinedTitleWidth = 466.0;
    //float index = MIN([originalArtistName length] * 1.0, MAX(minArtistNameLength, 26.0 - [songTitle length]));
    
    if ((songTitleWidth + artistNameWidth) > maxCombinedTitleWidth) {
        CGFloat songTitleWidth = [songTitle bly_widthForStringWithAttributes:songTitleFontAttributes];
        CGFloat artistNameWidth = [cuttedArtistName bly_widthForStringWithAttributes:artistNameFontAttributes];
        
        if ((songTitleWidth + artistNameWidth) > maxCombinedTitleWidth) {
            for (NSUInteger i = [cuttedArtistName length];
                 
                 [cuttedArtistName length] > minArtistNameLength && (songTitleWidth + artistNameWidth) > maxCombinedTitleWidth;
                 
                 i--) {
                
                cuttedArtistName = [cuttedArtistName substringToIndex:i - 1];
                
                artistNameWidth = [cuttedArtistName bly_widthForStringWithAttributes:artistNameFontAttributes];
            }
        }
        
        self.navItemTitle = songTitle;
    } else {
        self.navItemTitle = originalSongTitle;
    }
    
    //cuttedArtistName = [originalArtistName substringToIndex:MIN([originalArtistName length] * 1.0, (index + 3) * 1.0)];
    
    if (![cuttedArtistName isEqualToString:originalArtistName]) {
        cuttedArtistName = [cuttedArtistName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        cuttedArtistName = [cuttedArtistName stringByTrimmingCharactersInSet:[NSCharacterSet punctuationCharacterSet]];
        cuttedArtistName = [cuttedArtistName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        if ([cuttedArtistName length] + 3 >= [originalArtistName length]) {
            cuttedArtistName = originalArtistName;
        } else {
            cuttedArtistName = [cuttedArtistName stringByAppendingString:@"..."];
        }
    }
    
    UIBarButtonItem *leftBarButton = [[UIBarButtonItem alloc] initWithTitle:cuttedArtistName
                                                                      style:UIBarButtonItemStylePlain
                                                                     target:self
                                                                     action:@selector(showArtistSongs:)];
    
    self.containerVC.navigationItem.leftBarButtonItem = leftBarButton;
}

- (void)updatePlayerCoverBgForCurrentSong
{
    BLYSong *song = self.currentSong;
    
    self.playerCoverBackground.image = [song.album largeThumbnailAsImg] ? [song.album largeThumbnailAsImg] : [song.album smallThumbnailAsImg];
    
    if (self.isFullscreen) {
        [[[BLYFullScreenPlayerViewController sharedVC] playerCoverBackground] setImage:[song.album largeThumbnailAsImg] ? [song.album largeThumbnailAsImg] : [song.album smallThumbnailAsImg]];
    }
}

- (void)loadSong:(BLYSong *)song
              at:(double)time
     askedByUser:(BOOL)askedByUser
{
    static BLYPlaylist *lastLoadedPlaylist = nil;
    static NSTimer *lastLoadSongtimer = nil;
    
    BLYVideoSong *videoSong = nil;
    BLYVideo *video = nil;
    
    BLYPlayerViewControllerPlayerStatus oldStatus = self.playerStatus;
    
    if (song.videos && [song.videos count] > 0) {
        videoSong = [song.videos objectAtIndex:0];
        video = videoSong.video;
    }
    
    self.loadCurrentSongAtTime = time;
    
    [self startBackgroundTask];
    
    // Make sure this code was called before unloadPlayer call pause method
    [self saveTimeSpentAtPlaying];
    
    if (self.player) {
        [self unloadPlayer];
    }
    
    [self stopTimeToLoadSongTimer];
    
    self.songWasPausedBecauseEmptyBuffer = NO;
    
    [self stopSongPlayingTimerForPersonalTop];
    
    self.completeBufferCallbackCalled = NO;
    
    [self clearBufferIsEmptyTimer];
    
    self.rewindCurrentSongDueToBadNetworkAttempts = 0;
    self.playNotificationSendedForCurrentSong = NO;
    
    self.currentSongIsInRepeatModeDueToBadNetwork = NO;
    self.bgPlayerHasSufficientBuffer = nil;
    self.loadBgPlayerWhenAppEnterBackgroundModeCallback = nil;
    
    if (self.repeatMode == BLYPlayerViewControllerRepeatModeOne
        && [self.playlist nbOfSongs] > 1) {
        self.repeatMode = BLYPlayerViewControllerRepeatModeNone;
    }
    
    [self setCurrentSong:song
             askedByUser:askedByUser];
    
    // Make sure this call was after setCurrentSong...
    [self managePlaylistPlayControlsForSong:song];
    
    [self updatePlayerCoverBgForCurrentSong];
    
    [self.playerContainer bringSubviewToFront:self.playerCoverBackground];
    
    [self handleSongIsLoading];
    
    if (self.containerVC.selectedChildVC == self) {
        [self updateNavLeftButtonTitleForSong:song];
    } else {
        [self updateNavLeftButtonTitleForSong:song
                                      orTitle:self.containerVC.selectedChildVC.navItemTitle];
    }
    
    if ([song.isVideo boolValue]) {
        self.albumNameLabel.text = NSLocalizedString(@"player_album_is_a_video", nil);
        
        [self disableShowAlbumIcon];
    } else {
        if (![song.album.isASingle boolValue]) {
            NSString *albumNameVersionRegPattern = @"((?:\\(|\\[|\\{)(?!.*(version|edition|mix|remix|acoustic|acoustique)).+(?:\\)|\\]|\\}))+";
            NSRegularExpression *albumNameVersionReg = [[NSRegularExpression alloc] initWithPattern:albumNameVersionRegPattern                                                                                                              options:NSRegularExpressionCaseInsensitive
                                                                                              error:nil];
            
            NSMutableString *displayedAlbumName = [song.album.name mutableCopy];
            
            [albumNameVersionReg replaceMatchesInString:displayedAlbumName
                                                options:0
                                                  range:[displayedAlbumName bly_fullRange]
                                           withTemplate:@""];
            
            displayedAlbumName = [[displayedAlbumName bly_stringByReplacingMultipleConsecutiveSpacesToOne] mutableCopy];
            
            self.albumNameLabel.text = displayedAlbumName;
            
            [self enableShowAlbumIcon];
        } else {
            self.albumNameLabel.text = NSLocalizedString(@"player_album_is_a_single", nil);
            
            [self disableShowAlbumIcon];
        }
    }
    
    if (self.isFullscreen) {
        [[BLYFullScreenPlayerViewController sharedVC] setSongTitleValueFor:song.title
                                                             andArtistName:song.artist.name];
    }
    
    [self postLoadNotification];
    
    self.playerStatus = BLYPlayerViewControllerPlayerStatusLoading;
    
    BOOL userHasLoadedSongByTouchingSongCell = (!lastLoadedPlaylist || (self.playlist != lastLoadedPlaylist));
    BOOL songIsImmediatlyAvailable = [song isCached] || (_songLoadedInBgPlayer == song);
    
    if ((songIsImmediatlyAvailable && [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive)
        || userHasLoadedSongByTouchingSongCell
        || ![[song loadedByUser] boolValue]
        || [self.playlist isCached]
        || oldStatus != BLYPlayerViewControllerPlayerStatusLoading) {
        
        if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive
            && !self.isVisible) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (_currentSong != song) {
                    return;
                }
                
                [self loadVideoForSong:song
                          inBackground:NO
                        withCompletion:nil];
            });
        } else {
            [self loadVideoForSong:song
                      inBackground:NO
                    withCompletion:nil];
        }
    } else {
        if (lastLoadSongtimer) {
            [lastLoadSongtimer invalidate];
            lastLoadSongtimer = nil;
        }
        
        // Prevent DDoS on Youtube API when user try to find a
        // song using previous or next commands
        lastLoadSongtimer = [NSTimer scheduledTimerWithTimeInterval:0.8 repeats:NO block:^(NSTimer * _Nonnull timer) {
            if (_currentSong != song) {
                return;
            }
            
            [self loadVideoForSong:song
                      inBackground:NO
                    withCompletion:nil];
        }];
    }
    
    lastLoadedPlaylist = self.playlist;
}

- (BOOL)isBadNetworkError:(NSError *)error
{
    NSString *domain = error.domain;
    NSInteger errCode = error.code;
    
    return  ([domain isEqualToString:NSURLErrorDomain]
             && (errCode == NSURLErrorTimedOut
                 || errCode == NSURLErrorNetworkConnectionLost
                 || errCode == NSURLErrorNotConnectedToInternet))
            || ([domain isEqualToString:@"com.brown.blystore"]
                && errCode == BLYStoreExpiredRequestErrorCode);
}

- (BOOL)loadVideoForSong:(BLYSong *)song
            inBackground:(BOOL)inBackground
          withCompletion:(void(^)(BLYSong *song))completion
{
    return [self loadVideoForSong:song
                     inBackground:inBackground
                         andRetry:NO
                   withCompletion:completion];
}

- (BOOL)loadVideoForSong:(BLYSong *)song
            inBackground:(BOOL)inBackground
                andRetry:(BOOL)retry
          withCompletion:(void(^)(BLYSong *song))completion
{
    static NSMutableDictionary *loadingSong = nil;
    
    BLYVideoSong *videoSong = nil;
    BLYVideo *video = nil;
    
    if (song.videos && [song.videos count] > 0) {
        videoSong = [song.videos objectAtIndex:0];
        video = videoSong.video;
    }
    
    // Many concurrent requests
    if (loadingSong) {
        if (inBackground) {
            return YES;
        }
        
        if ([loadingSong[@"loadedSong"] isEqual:song]) {
            loadingSong[@"inBackground"] = [NSNumber numberWithBool:NO];
            
            // User load song with other videos
            if (video && loadingSong[@"loadedVideo"] != [NSNull null] && [video.sid isEqualToString:((BLYVideo *)loadingSong[@"loadedVideo"]).sid]) {
                
                return YES;
            }
        }
    }
                
    if (inBackground && video.path) {
        return NO;
    }
    
    loadingSong = [@{@"loadedSong": song,
                     @"loadedVideo": video ? video : [NSNull null],
                     @"inBackground": [NSNumber numberWithBool:inBackground]} mutableCopy];
    
    __weak BLYPlayerViewController *weakSelf = self;
    
    void (^handleError)(NSError *err) = ^(NSError *err){
        if ([loadingSong[@"inBackground"] boolValue]) {
            loadingSong = nil;
            
            return;
        }
        
        if (![song isEqual:loadingSong[@"loadedSong"]]
            // User load song with other videos
            || (video && loadingSong[@"loadedVideo"] != [NSNull null] && ![video.sid isEqualToString:((BLYVideo *)loadingSong[@"loadedVideo"]).sid])) {
            
            return;
        }
        
        loadingSong = nil;
        
        // Retry one more time
        if (!retry && ![self isBadNetworkError:err]) {
            [weakSelf loadVideoForSong:song
                          inBackground:inBackground
                              andRetry:YES
                        withCompletion:completion];
            
            return;
        }
        
        if ([self isBadNetworkError:err]
            && [self songTakesTooManyTimesToLoad]) {
            
            return;
        }
        
        [self loadPlaybackInfoForPlayerError:err];
        
        if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
            [[BLYErrorStore sharedStore] manageError:err forViewController:self.isFullscreen ? [BLYFullScreenPlayerViewController sharedVC] : self];
        }
        
        [weakSelf handlePlayerError];
    };
    
    void (^handleTrackNotFound)(void) = ^{
        if ([loadingSong[@"inBackground"] boolValue]) {
            loadingSong = nil;
            
            return;
        }
        
        if (![song isEqual:loadingSong[@"loadedSong"]]
            // User load song with other videos
            || (video && loadingSong[@"loadedVideo"] != [NSNull null] && ![video.sid isEqualToString:((BLYVideo *)loadingSong[@"loadedVideo"]).sid])) {
            
            return;
        }
        
        loadingSong = nil;
        
        NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
        
        [userInfo setValue:NSLocalizedString(@"player_track_not_found", nil)
                    forKey:NSLocalizedDescriptionKey];
        
        NSError *err = [NSError errorWithDomain:@"com.brown.blyplayerviewcontroller"
                                           code:BLYPlayerViewControllerSongNotFoundErrorCode
                                       userInfo:userInfo];
        
        [self loadPlaybackInfoForPlayerError:err];
        
        if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
            [[BLYErrorStore sharedStore] manageError:err forViewController:self.isFullscreen ? [BLYFullScreenPlayerViewController sharedVC] : self];
        }
        
        [weakSelf handlePlayerError];
    };
    
    void (^fetchVideoURLForSong)(BLYSong *song) = ^(BLYSong *song){
        [[BLYVideoStore sharedStore] fetchVideoURLForVideoOfSong:song inBackground:[loadingSong[@"inBackground"] boolValue] withCompletion:^(NSURL *videoURL, NSError *err) {
            // Many concurrent requests
            if (![song isEqual:loadingSong[@"loadedSong"]]
                // User load song with other videos
                || (video && loadingSong[@"loadedVideo"] != [NSNull null] && ![video.sid isEqualToString:((BLYVideo *)loadingSong[@"loadedVideo"]).sid])) {
                
                return;
            }
            
            if (err) {
                return handleError(err);
            }
            
            if (!videoURL) {
                return handleTrackNotFound();
            }
            
            if ([loadingSong[@"inBackground"] boolValue]) {
                if (completion) {
                    completion(song);
                }
                
                loadingSong = nil;
                
                return;
            }
            
            loadingSong = nil;
            
            [weakSelf loadPlayerWithSong:song andUrl:nil];
        }];
        
    };
    
    void (^fetchVideoIDCompletion)(NSMutableArray *, NSError *) = ^(NSMutableArray *videos, NSError *err){
        // Many concurrent requests
        if (![song isEqual:loadingSong[@"loadedSong"]]
            // User load song with other videos
            || (video && loadingSong[@"loadedVideo"] != [NSNull null] && ![video.sid isEqualToString:((BLYVideo *)loadingSong[@"loadedVideo"]).sid])) {
            
            return;
        }
        
        if (err) {
            return handleError(err);
        }
        
        if ([videos count] == 0) {
            return handleTrackNotFound();
        }
        
        if (![loadingSong[@"inBackground"] boolValue]) {
            BLYVideo *video = [videos objectAtIndex:0];
            
            // Video is already cached (attached to another song)
            if (video.path) {
                loadingSong = nil;
                
                return [weakSelf loadPlayerWithSong:song andUrl:nil];
            }
            
            BLYVideoURL *videoURL = [[BLYVideoStore sharedStore] bestURLForCurrentNetworkAndVideo:video];
            NSTimeInterval URLExpiresAt = [videoURL.expiresAt timeIntervalSinceNow];
            
            // Video URL is already cached (attached to another song)
            if (videoURL && URLExpiresAt > 0) {
                loadingSong = nil;
                
                return [weakSelf loadPlayerWithSong:song andUrl:videoURL];
            }
        }
        
        fetchVideoURLForSong(song);
    };
    
    // Video in cache
    if (video.path) {
        if (self.forceSongRefreshing) {
            [[BLYSongCachingStore sharedStore] uncacheSong:song];
        } else {
            loadingSong = nil;
            
            [self loadPlayerWithSong:song andUrl:nil];
            
            return NO;
        }
    }
    
    // If song is begin downloaded, cancel it
    if (_songCaching) {
        [[BLYSongCachingStore sharedStore] stopCachingSong:_songCaching];
        
        _songCaching = nil;
    }
    
    if (!self.forceSongRefreshing) {
        if (video.sid
            && (![videoSong.possibleGarbage boolValue]
                || [song.videosReordered boolValue])) {
                
                BLYVideoURL *videoURL = [[BLYVideoStore sharedStore] bestURLForCurrentNetworkAndVideo:video];
                NSTimeInterval URLExpiresAt = [videoURL.expiresAt timeIntervalSinceNow];
                
                if (videoURL && URLExpiresAt > 0) {
                    loadingSong = nil;
                    
                    if (inBackground) {
                        return NO;
                    }
                    
                    [self loadPlayerWithSong:song andUrl:videoURL];
                    
                    return YES;
                } else {
                    // Video ID had ten percent luck to be updated in wifi
//                    if ((arc4random_uniform(1000) >= 100
//                         || ![[BLYNetworkStore sharedStore] networkIsReachableViaWifi])
//                        || [song.videosReordered boolValue]) {
//
//                        fetchVideoURLForSong(song);
//
//                        return YES;
//                    }
                    
                    fetchVideoURLForSong(song);
                    
                    return YES;
                }
            }
    }
    
    self.forceSongRefreshing = NO;
    
    BLYAppDelegate *appDelegate = (BLYAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    [[BLYVideoStore sharedStore] fetchVideoIDForSong:song
                                          andCountry:[appDelegate countryCodeForCurrentLocale]
                                        inBackground:inBackground
                                      withCompletion:fetchVideoIDCompletion];
    
    return YES;
}

- (void)handlePlayerError
{
    NSError *error = self.player.error ? self.player.error : self.player.currentItem.error;
    
    if (error) {
        NSLog(@"%@", [error localizedDescription]);
        
        [self unloadPlayer];
    } else {
        // Play icon was disabled when song is loaded
        // Make sure to reenable it in case an error was thrown during song loading
        [self enablePlayPauseIcon];
    }
    
    self.playerStatus = BLYPlayerViewControllerPlayerStatusError;
    
    // Set this AFTER player status was set
    if (!error) {
        [self managePlaylistPlayControlsForSong:self.currentSong];
    }
    
    [self postLoadWithErrorNotification];
    
    [self handleSongIsLoaded];
    
//    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
//        [self play];
//    }
}

- (void)postLoadWithErrorNotification
{
    [self postLoadWithErrorNotificationForPlayer:YES];
}

- (void)postLoadWithErrorNotificationForPlayer:(BOOL)forPlayer
{
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:self.currentSong
                                                         forKey:@"loadedSong"];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BLYPlayerViewControllerDidLoadSongWithErrorNotification
                                                        object:self
                                                      userInfo:userInfo];
    
    if (!forPlayer) {
        return;
    }
}

- (void)postLoadNotification
{
    [self postLoadNotificationForPlayer:YES];
}

- (void)postLoadNotificationForPlayer:(BOOL)forPlayer
{
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:self.currentSong
                                                         forKey:@"loadedSong"];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BLYPlayerViewControllerDidLoadSongNotification
                                                        object:self
                                                      userInfo:userInfo];

    
    if (!forPlayer) {
        return;
    }
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    // Reload player layer after background mode
    //[self loadPlayerLayerAndForceNew:YES];
    
    //[self updatePlayerLayerFrame];
    if (self.player) {
        self.playerLayer.player = self.player;
    }
    
    //[self stopBackgroundTask];
    [self postCorrespondingStatusNotification];
    
    //[self endAudioSessionInterruptionIfNecessary];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    [self enablePlayerTrackItem:YES];
    
    [self showBadNetworkPlaylistNotificationIfNecessary];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    if (self.loadBgPlayerWhenAppEnterBackgroundModeCallback) {
        self.loadBgPlayerWhenAppEnterBackgroundModeCallback();
        
        self.loadBgPlayerWhenAppEnterBackgroundModeCallback = nil;
    }
    
    if (!self.isPlaying) {
        // Prevent kvo notifications for player item when app enter background
        [self removeObserverforPlayerItem:self.player.currentItem forBackground:YES];
        
        return;
    }
    
    [self.playerLayer setPlayer:nil];
    
    //[_player performSelector:@selector(play) withObject:nil afterDelay:0.01];
}

- (void)handlePlayerItemDidReachEnd:(NSNotification *)notification
{
    BLYSong *song = self.currentSong;
    BLYSong *realNextSong = [self songPlayedAfterSong:song];
    BLYSong *firstPlayableNextSong = [self firstPlayableNextSongForSong:song];
    
    BLYSong *_firstPlayablePreviousSong = song;
    BLYSong *firstPlayablePreviousSong = nil;
    
    if (!realNextSong) {
        realNextSong = [self.playlist songAtIndex:0];
    }

    while ((_firstPlayablePreviousSong = [self firstPlayablePreviousSongForSong:_firstPlayablePreviousSong])) {
        firstPlayablePreviousSong = _firstPlayablePreviousSong;
    }
    
    BLYPlaylist *playlist = self.playlist;
    BOOL repeatSong = (self.repeatMode == BLYPlayerViewControllerRepeatModeOne
                       || [playlist nbOfSongs] == 1);
    
    if (self.bgPlayerWasSuccessfullyLoadedWithNextSong
        // Make sure song isn't repeated
        && !repeatSong) {
        
        self.bgPlayerWasSuccessfullyLoadedWithNextSong();
        
        self.bgPlayerWasSuccessfullyLoadedWithNextSong = nil;
        
        return;
    }
    
    if (!repeatSong && [_playerStateBeforeBadNetworkHappen count] == 0 && !_userKnowThatOnlyCachedSongsWillBePlayedGivenThatNetworkIsNotReachable) {
        
        if (firstPlayableNextSong && firstPlayableNextSong != realNextSong) {
            [self loadBadNetworkPlaylistAtEnd:true];
            
            return;
        }
        
        if (!firstPlayableNextSong && firstPlayablePreviousSong && firstPlayablePreviousSong != realNextSong) {
            [self loadBadNetworkPlaylistAtEnd:true];
            
            return;
        }
    }
    
    if (repeatSong
        
        // BG player not loaded, probably bad network
        //|| ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive
        //    && (![[BLYNetworkStore sharedStore] networkIsReachable] ||
        //        [[BLYNetworkStore sharedStore] networkIsReachableViaCellularNetwork]))
        
        || (!firstPlayableNextSong
            && !firstPlayablePreviousSong)) {
            //&& [[UIApplication sharedApplication] applicationState] != UIApplicationStateActive)) {
        
//        if (self.repeatMode != BLYPlayerViewControllerRepeatModeOne
//            && [playlist nbOfSongs] > 1
//            && [self loadBadNetworkPlaylistAtEnd:YES]) {
//
//            return;
//        }
            
            __weak BLYPlayerViewController *weakSelf = self;
            int attempts = _rewindCurrentSongDueToBadNetworkAttempts;
        
            if (!repeatSong) {
                _rewindCurrentSongDueToBadNetworkAttempts = attempts + 1;
                
                if (attempts >= 2 && [[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
                    if ([self loadBadNetworkPlaylistAtEnd:true]) {
                        return;
                    }
                }
            }
            
            if (!repeatSong) {
                self.currentSongIsInRepeatModeDueToBadNetwork = true;
            
                // Try to reload
                // [weakSelf loadBackgroundPlayerWithNextSong];
            }
        
            [self rewindAtEnd:true withCompletion:^{
                [weakSelf play];
            }];
            
            return;
    }
    
    return [self playNextPlayableSongInPlaylist:nil];
    
    if (firstPlayableNextSong) {
        return [self playNextPlayableSongInPlaylist:nil];
    }
    // else if (!firstPlayableNextSong
               // && !firstPlayablePreviousSong) { // Bad network when app is active
        // BLYSong *song = [self songPlayedAfterSong:self.currentSong];
        
        // if (!song) {
            // song = [self.playlist songAtIndex:0];
        // }
        
        // return [self loadSong:song askedByUser:NO];
    // }
    
    return [self loadPlaylist:playlist
             andStartWithSong:firstPlayablePreviousSong
                  askedByUser:NO];
}

- (void)unloadAudioSession
{
    NSError *err = nil;
    
    [[AVAudioSession sharedInstance] setActive:NO error:&err];
    
    if (err) {
        [self loadPlaybackInfoForPlayerError:err];
        
        if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
            [[BLYErrorStore sharedStore] manageError:err forViewController:self.isFullscreen ? [BLYFullScreenPlayerViewController sharedVC] : self];
        }
        
        return;
    }
    
    // Return to default category
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategorySoloAmbient error:&err];
    
    if (err) {
        [self loadPlaybackInfoForPlayerError:err];
        
        if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
            [[BLYErrorStore sharedStore] manageError:err forViewController:self.isFullscreen ? [BLYFullScreenPlayerViewController sharedVC] : self];
        }
        
        return;
    }
    
    [self endReceivingRemoteControlEvents];
}

- (NSError *)loadAudioSession
{
    NSError *err = nil;
    
    [[AVAudioSession sharedInstance] setActive:YES error:&err];
    
    if (err) {
        if (self.playerStatus == BLYPlayerViewControllerPlayerStatusPlaying) {
            [self pause:NO];
        }
        
        //[[BLYErrorStore sharedStore] manageError:err forViewController:self.isFullscreen ? [BLYFullScreenPlayerViewController sharedVC] : self];
        
        return err;
    }
    
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&err];
    
    if (err) {
        if (self.playerStatus == BLYPlayerViewControllerPlayerStatusPlaying) {
            [self pause:NO];
        }
        
        //[[BLYErrorStore sharedStore] manageError:err forViewController:self.isFullscreen ? [BLYFullScreenPlayerViewController sharedVC] : self];
        
        return err;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVAudioSessionRouteChangeNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAudioRouteChange:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:nil];
    
    //[[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    
    [self becomeFirstResponder];
    
    return nil;
}

- (void)handleAudioRouteChange:(NSNotification *)n
{
    // Run in avaudiosession notify thread !
    
    static double lastTimeHeadphonesWereRemoved = 0.0;
    double currentTimestamp = [[NSDate date] timeIntervalSince1970];
    
    NSDictionary *userInfo = n.userInfo;
    NSNumber *changeReason = userInfo[AVAudioSessionRouteChangeReasonKey];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Headsets were removed, pause song to follow Apple guidelines
        if ([changeReason isEqualToNumber:[NSNumber numberWithInteger:AVAudioSessionRouteChangeReasonOldDeviceUnavailable]]) {
            if (![self isPlaying]) {
                lastTimeHeadphonesWereRemoved = 0.0;
                
                return;
            }
            
            [self pause:YES];
            
            lastTimeHeadphonesWereRemoved = currentTimestamp;
        } else if ([changeReason isEqualToNumber:[NSNumber numberWithInteger:AVAudioSessionRouteChangeReasonNewDeviceAvailable]] && (currentTimestamp - lastTimeHeadphonesWereRemoved) <= BLYPlayerViewControllerLastTimeHeadphonesWereRemovedTimeToPlay) {
            
            [self play];
        }
    });
}

- (void)endReceivingRemoteControlEvents
{
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    
    [self resignFirstResponder];
}

- (void)disablePlaybackSlider
{
    self.playbackSlider.userInteractionEnabled = NO;
    
    if (self.isFullscreen) {
        [BLYFullScreenPlayerViewController sharedVC].playbackSlider.userInteractionEnabled = NO;
    }
}

- (void)enablePlaybackSlider
{
    self.playbackSlider.userInteractionEnabled = YES;
    
    if (self.isFullscreen) {
        [BLYFullScreenPlayerViewController sharedVC].playbackSlider.userInteractionEnabled = YES;
    }
}

- (void)disableShowAlbumIcon
{
    self.showAlbumButton.enabled = NO;
    self.showAlbumLabelButton.enabled = NO;
    
    self.showAlbumButton.layer.opacity = 0.1;
    self.albumNameLabel.layer.opacity = 0.3;
}

- (void)enableShowAlbumIcon
{
    if ([self.currentSong.album.isASingle boolValue]
        || [self.currentSong.isVideo boolValue]) {
        return;
    }
    
    self.showAlbumButton.enabled = YES;
    self.showAlbumLabelButton.enabled = YES;
    
    self.showAlbumButton.layer.opacity = 0.3;
    self.albumNameLabel.layer.opacity = 1.0;
}

- (void)disableRepeatIcon
{
    [self.repeatButton setImage:[UIImage imageNamed:@"PlayerRepeatIcon"]
                       forState:UIControlStateNormal];
    
    self.repeatButton.alpha = 0.2;
    
    self.repeatButton.enabled = [self.playlist nbOfSongs] > 1;
}

- (void)enableRepeatIcon
{
    [self.repeatButton setImage:[UIImage imageNamed:@"PlayerRepeatIcon"]
                       forState:UIControlStateNormal];
    
    self.repeatButton.alpha = 1.0;
    
    self.repeatButton.enabled = [self.playlist nbOfSongs] > 1;
}

- (void)disablePreviousIcon
{
    self.previousSongButton.alpha = 0.2;
    self.previousSongButton.enabled = NO;
    
    self.previousSongContainer.hidden = YES;
    self.previousSongButton.hidden = NO;
    
    if (self.isFullscreen) {
        [[[BLYFullScreenPlayerViewController sharedVC] previousSongView] setHidden:true];
        [[[BLYFullScreenPlayerViewController sharedVC] previousSongButton] setHidden:NO];
        [[[BLYFullScreenPlayerViewController sharedVC] previousSongButton] setAlpha:0.2];
        [[[BLYFullScreenPlayerViewController sharedVC] previousSongButton] setEnabled:NO];
    }
}

- (void)enablePreviousIcon
{
    BLYSong *previousSong = [self firstPlayablePreviousSongForSong:self.currentSong];
    BLYSong *_lastPlayableNextSong = self.currentSong;
    BLYSong *lastPlayableNextSong = nil;
    
    if (!previousSong && [self.playlist nbOfSongs] > 1) {
        while ((_lastPlayableNextSong = [self firstPlayableNextSongForSong:_lastPlayableNextSong])) {
            lastPlayableNextSong = _lastPlayableNextSong;
        }
        
        previousSong = lastPlayableNextSong;
    }
    
    AVPlayer *player = self.player;
    double elapsedTime = CMTimeGetSeconds([player currentTime]);
    BOOL displayPreviousSongInfos = previousSong && (elapsedTime < BLYPlayerViewControllerRewindOrPreviousSongTime || self.playerStatus == BLYPlayerViewControllerPlayerStatusError);
    
    self.previousSongButton.alpha = 1.0;
    self.previousSongButton.enabled = YES;
    self.previousSongButton.hidden = displayPreviousSongInfos;
    
    self.previousSongContainer.hidden = !displayPreviousSongInfos;
    
    //NSString *title = previousSong.title;
    
//    if ([previousSong.isVideo boolValue]) {
//        NSArray *titleAsArray = [previousSong.title componentsSeparatedByString:@"-"];
//        
//        if ([titleAsArray count] != 2) {
//            title = previousSong.title;
//        } else { // Display track name first
//            title = [NSString stringWithFormat:@"%@ - %@",
//                     [titleAsArray objectAtIndex:1],
//                     [titleAsArray objectAtIndex:0]];
//        }
//    }
    
    self.previousSongTitleLabel.text = previousSong.title;
//    self.previousSongTitleLabel.text = [NSString stringWithFormat:@"%d. %@", [self.playlist indexOfSong:previousSong] + 1, previousSong.title];
    
    self.previousSongArtistNameLabel.text = previousSong.artist.name;
    
//    if (!displayPreviousSongInfos) {
//        self.previousSongContainer.alpha = 0.2;
//        self.previousSongContainer.userInteractionEnabled = NO;
//        self.previousSongArtistNameLabel.textColor = [UIColor colorWithRed:120 / 255.f
//                                                                     green:120 / 255.f
//                                                                      blue:120 / 255.f
//                                                                     alpha:1.0];
//        //self.previousSongButton.alpha = 0.9;
//    } else {
//        self.previousSongContainer.alpha = 1.0;
//        self.previousSongContainer.userInteractionEnabled = YES;
//        self.previousSongArtistNameLabel.textColor = [UIColor darkGrayColor];
//    }
    
    if (self.isFullscreen) {
        [[[BLYFullScreenPlayerViewController sharedVC] previousSongButton] setHidden:displayPreviousSongInfos];
        [[[BLYFullScreenPlayerViewController sharedVC] previousSongView] setHidden:!displayPreviousSongInfos];
        [[[BLYFullScreenPlayerViewController sharedVC] previousSongButton] setAlpha:1.0];
        [[[BLYFullScreenPlayerViewController sharedVC] previousSongButton] setEnabled:YES];
    }
}

- (void)disableNextIcon
{
    self.nextSongButton.alpha = 0.2;
    self.nextSongButton.enabled = NO;
    
    self.nextSongContainer.hidden = YES;
    self.nextSongButton.hidden = NO;
    
    if (self.isFullscreen) {
        [[[BLYFullScreenPlayerViewController sharedVC] nextSongButton] setHidden:NO];
        [[[BLYFullScreenPlayerViewController sharedVC] nextSongButton] setAlpha:0.2];
        [[[BLYFullScreenPlayerViewController sharedVC] nextSongButton] setEnabled:NO];
    }
}

- (void)enableNextIcon
{
    BLYSong *nextSong = [self firstPlayableNextSongForSong:self.currentSong];
    BLYSong *_firstPlayablePreviousSong = self.currentSong;
    BLYSong *firstPlayablePreviousSong = nil;
    
    if (!nextSong) {
        while ((_firstPlayablePreviousSong = [self firstPlayablePreviousSongForSong:_firstPlayablePreviousSong])) {
            firstPlayablePreviousSong = _firstPlayablePreviousSong;
        }
        
        nextSong = firstPlayablePreviousSong;
    }
    
    self.nextSongButton.alpha = 1.0;
    self.nextSongButton.enabled = YES;
    
    self.nextSongButton.hidden = YES;
    self.nextSongContainer.hidden = NO;
    
    //NSString *title = nextSong.title;
    
//    if ([nextSong.isVideo boolValue]) {
//        NSArray *titleAsArray = [nextSong.title componentsSeparatedByString:@"-"];
//        
//        if ([titleAsArray count] != 2) {
//            title = nextSong.title;
//        } else { // Display track name first
//            title = [NSString stringWithFormat:@"%@ - %@",
//                     [titleAsArray objectAtIndex:1],
//                     [titleAsArray objectAtIndex:0]];
//        }
//    }
    
    self.nextSongTitleLabel.text = nextSong.title;
//    self.nextSongTitleLabel.text = [NSString stringWithFormat:@"%d. %@", [self.playlist indexOfSong:nextSong] + 1, nextSong.title];
    
    self.nextSongArtistNameLabel.text = nextSong.artist.name;
    
    if (self.isFullscreen) {
        BOOL hidden = [[[BLYFullScreenPlayerViewController sharedVC] loadingView] isHidden];
        
        [[[BLYFullScreenPlayerViewController sharedVC] nextSongButton] setHidden:hidden];
        
        if (!hidden) {
            [[[BLYFullScreenPlayerViewController sharedVC] nextSongButton] setHidden:NO];
            [[[BLYFullScreenPlayerViewController sharedVC] nextSongButton] setAlpha:1.0];
            [[[BLYFullScreenPlayerViewController sharedVC] nextSongButton] setEnabled:YES];
        }
    }
}

- (IBAction)playNextSongButtonSelected:(id)sender
{
    self.nextSongTitleLabel.alpha = 0.3;
    self.nextSongArtistNameLabel.alpha = 0.3;
}

- (IBAction)playNextSongButtonReleased:(id)sender
{
    self.nextSongTitleLabel.alpha = 1.0;
    self.nextSongArtistNameLabel.alpha = 1.0;
}

- (IBAction)playPreviousSongButtonSelected:(id)sender
{
    self.previousSongTitleLabel.alpha = 0.3;
    self.previousSongArtistNameLabel.alpha = 0.3;
}

- (IBAction)playPreviousSongButtonReleased:(id)sender
{
    self.previousSongTitleLabel.alpha = 1.0;
    self.previousSongArtistNameLabel.alpha = 1.0;
}

- (BOOL)hasNextSongs
{
    BLYSong *song = self.currentSong;
    NSInteger indexOfSongInPlaylist = [self.playlist indexOfSong:song];
    
    if (indexOfSongInPlaylist + 1 == [self.playlist nbOfSongs]) {
        return NO;
    }
    
    return YES;
}

- (BOOL)hasPreviousSongs
{
    BLYSong *song = self.currentSong;
    NSInteger indexOfSongInPlaylist = [self.playlist indexOfSong:song];
    
    if (indexOfSongInPlaylist == 0) {
        return NO;
    }
    
    return YES;
}

- (void)disablePlayIcon
{
    [self.playPauseButton setImage:[UIImage imageNamed:@"PlayerPlayIcon"]
                          forState:UIControlStateNormal];
    
    self.playPauseButton.alpha = 0.2;
    self.playPauseButton.enabled = NO;
    
    if (self.isFullscreen) {
        [[[BLYFullScreenPlayerViewController sharedVC] playPauseButton] setImage:[UIImage imageNamed:@"PlayerPlayIcon"]
                                                                        forState:UIControlStateNormal];
        
        [[[BLYFullScreenPlayerViewController sharedVC] playPauseButton] setAlpha:0.2];
        [[[BLYFullScreenPlayerViewController sharedVC] playPauseButton] setEnabled:NO];
    }
}

- (void)showPauseIcon
{
    [self.playPauseButton setImage:[UIImage imageNamed:@"PlayerPauseIcon"]
                          forState:UIControlStateNormal];
    
    if (self.isFullscreen) {
        [[[BLYFullScreenPlayerViewController sharedVC] playPauseButton] setImage:[UIImage imageNamed:@"PlayerPauseIcon"]
                                                                        forState:UIControlStateNormal];
    }
}

- (void)showPlayIcon
{
    [self.playPauseButton setImage:[UIImage imageNamed:@"PlayerPlayIcon"]
                          forState:UIControlStateNormal];
    
    if (self.isFullscreen) {
        [[[BLYFullScreenPlayerViewController sharedVC] playPauseButton] setImage:[UIImage imageNamed:@"PlayerPlayIcon"]
                                                                        forState:UIControlStateNormal];
    }
}

- (void)enablePlayPauseIcon
{
    self.playPauseButton.alpha = 1.0;
    self.playPauseButton.enabled = YES;
    
    if (self.isFullscreen) {
        [[[BLYFullScreenPlayerViewController sharedVC] playPauseButton] setAlpha:1.0];
        [[[BLYFullScreenPlayerViewController sharedVC] playPauseButton] setEnabled:YES];
    }
}

- (void)play
{
    // Avoid play when user view ad
//    if ([BannerViewManager sharedInstance].bannerView.bannerViewActionInProgress) {
//        return;
//    }
    
    // Retry to load in case of error
    if (self.playerStatus == BLYPlayerViewControllerPlayerStatusError) {
        [self disablePlayIcon];
        
        return [self loadPlaylist:self.playlist
                 andStartWithSong:self.currentSong
                      askedByUser:[self.currentSong.loadedByUser boolValue]
                     forceRefresh:YES];
    }
    
    if (![self playerIsLoaded]) {
        return;
    }
    
    // Observer was removed when app enters background, to avoid observalue method call
    [self addObserverForPlayerItem:self.player.currentItem];
    
    NSError *error = [self loadAudioSession];
    
    if (error != nil) {
        [self pause:NO];
        
        return;
    }
    
    [self.player play];
}

- (void)postPlayNotification
{
    [self postPlayNotificationForPlayer:YES];
}

- (void)postPlayNotificationForPlayer:(BOOL)forPlayer
{
    void (^sendNotification)(void) = ^{
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:self.currentSong
                                                             forKey:@"playedSong"];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:BLYPlayerViewControllerDidPlaySongNotification
                                                            object:self
                                                          userInfo:userInfo];
    };
    
    if (!forPlayer) {
        sendNotification();
        
        return;
    }
    
    if (!self.isVisible) {
        // Player not displayed
        // We want playlists to be updated as fast as possible
        sendNotification();
    } else {
        // Player displayed
        // We want player UI (code below) to be updated as fast as possible
        dispatch_async(dispatch_get_main_queue(), ^{
            // Sanity check
            if (![self isPlaying]) {
                return;
            }
            
            sendNotification();
        });
    }
    
    self.containerVC.tabBarItem.enabled = YES;
    
    [self handleSongIsLoaded];
    
    [self showPauseIcon];
    
    // Enable play icon after it was disabled when loading track
    [self enablePlayPauseIcon];
    
    self.userWantsPlay = YES;
    
    [self.playerContainer sendSubviewToBack:self.playerCoverBackground];
    [self.playerLayer setOpacity:1.0];
    
    [self updateTimeSpentAtPlayingAt:@"play"];
    
    [self startSongPlayingTimerForPersonalTop];
    [self clearBufferIsEmptyTimer];
    
    [self setPlayNotificationSendedForCurrentSong:YES];
    
//    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
//        BLYAppDelegate *appDelegate = (BLYAppDelegate *)[[UIApplication sharedApplication] delegate];
//
//        [appDelegate trackEventWithCategory:@"player_behavior"
//                                     action:@"play_bg"
//                                      label:nil
//                                      value:nil];
//    }
}

- (void)saveTimeSpentAtPlaying
{
    if (!self.songPlayedAt) {
        return;
    }
    
    double duration = [self currentDurationAsSecond];
    double playedRatio = 0.0;
    
    // User has paused a song and played another song just after
    if (self.timeSpentAtPlaying > 0.0) {
        [self updateTimeSpentAtPlayingAt:@"play"];
    }
    
    double timeSpentAtPlaying = ([self.songPlayedAt timeIntervalSinceNow] * -1.0) / duration;
    
    if (timeSpentAtPlaying > 0.99) {
        timeSpentAtPlaying = 1.0;
    }
    
    playedRatio = MIN(timeSpentAtPlaying, 1.0);
    
    [[BLYSongStore sharedStore] setLastPlayPlayedPercent:playedRatio
                                                 forSong:self.currentSong];
    
    self.songPlayedAt = nil;
}

- (void)updateTimeSpentAtPlayingAt:(NSString *)at
{
    if ([at isEqualToString:@"pause"]) {
        if (!self.songPlayedAt) {
            return;
        }
        
        self.timeSpentAtPlaying = [self.songPlayedAt timeIntervalSinceNow] * -1.0;
        
        return;
    }
    
    if (!self.songPlayedAt) {
        self.songPlayedAt = [NSDate date];
    } else {
        self.songPlayedAt = [NSDate dateWithTimeIntervalSinceNow:self.timeSpentAtPlaying * - 1.0];
    }
    
    self.timeSpentAtPlaying = 0.0;
}

- (void)startSongPlayingTimerForPersonalTop
{
    if (self.songPlayingTimerForPersonalTop) {
        return;
    }
    
    if (!self.isPlaying) {
        return;
    }
    
    float currentSongDuration = CMTimeGetSeconds(self.player.currentItem.duration);
    float ratio = 0.55;
    
    if (isnan(currentSongDuration) || currentSongDuration < 1.0) {
        return;
    }
    
    NSDate *startedAt = [NSDate date];
    
    if (self.timeSpentAtPlayingForPersonalTop > 0.0) {
        ratio = ratio - (self.timeSpentAtPlayingForPersonalTop / currentSongDuration);
        
        startedAt = [startedAt dateByAddingTimeInterval:self.timeSpentAtPlayingForPersonalTop * -1.0];
    }
    
    NSTimeInterval interval = ratio * currentSongDuration;
    
    self.songPlayingTimerForPersonalTop = [NSTimer scheduledTimerWithTimeInterval:interval
                                                                           target:self
                                                                         selector:@selector(handleSongPlayingTimerForPersonalTop:)
                                                                         userInfo:@{@"startedAt": startedAt}
                                                                          repeats:NO];
}

- (void)pauseSongPlayingTimerForPersonalTop
{
    if (!self.songPlayingTimerForPersonalTop) {
        return;
    }
    
    NSDictionary *userInfo = self.songPlayingTimerForPersonalTop.userInfo;
    NSDate *startedAt = userInfo[@"startedAt"];
    
    float timeSpentAtPlayingForPersonalTop = [startedAt timeIntervalSinceNow] * -1.0;
    
    self.timeSpentAtPlayingForPersonalTop = timeSpentAtPlayingForPersonalTop;
    
    [self invalidatePlayingTimerForPersonalTop];
}

- (void)invalidatePlayingTimerForPersonalTop
{
    [self.songPlayingTimerForPersonalTop invalidate];
    
    self.songPlayingTimerForPersonalTop = nil;
}

- (void)stopSongPlayingTimerForPersonalTop
{
    [self invalidatePlayingTimerForPersonalTop];
    
    self.timeSpentAtPlayingForPersonalTop = 0.0;
}

- (void)handleSongPlayingTimerForPersonalTop:(NSTimer *)timer
{
    static BLYSong *lastCurrentSong = nil;
    
    if (!self.currentSongIsInRepeatModeDueToBadNetwork) {
        if ([_currentSong.loadedByUser boolValue]
            // Repeat mode ? User has seeked to time...
            || lastCurrentSong == _currentSong
            || (_currentSong.personalTopSong && [_currentSong.personalTopSong.playCount doubleValue] > 1.0)) {
            
            [[BLYPersonalTopSongStore sharedStore] insertPersonalTopSongForSong:self.currentSong];
        }
    }
    
    [self stopSongPlayingTimerForPersonalTop];
    [self startSongPlayingTimerForPersonalTop];
    
//    BLYAppDelegate *appDelegate = (BLYAppDelegate *)[[UIApplication sharedApplication] delegate];
//    
//    [appDelegate trackEventWithCategory:@"player_behavior"
//                                 action:@"heartbeat"
//                                  label:nil
//                                  value:nil];
    
    lastCurrentSong = _currentSong;
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:self.currentSong
                                                         forKey:@"addedSong"];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BLYPlayerViewControllerDidAddToPersonalTop
                                                        object:self
                                                      userInfo:userInfo];
}

- (void)pause:(BOOL)initiatedByUser
{
    if (![self playerIsLoaded]) {
        return;
    }
    
    [self updateTimeSpentAtPlayingAt:@"pause"];
    [self pauseSongPlayingTimerForPersonalTop];
    
    [self.player pause];
    
    [self showPlayIcon];
    
    if (self.pausedByPlaybackSlide || self.songWasPausedBecauseEmptyBuffer) {
        [self disablePlayIcon];
    }
    
    if (initiatedByUser) {
        self.userWantsPlay = NO;
    }
    
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
        // if (initiatedByUser) {
            [self removeObserverforPlayerItem:self.player.currentItem forBackground:YES];
        // }
        
//        BLYAppDelegate *appDelegate = (BLYAppDelegate *)[[UIApplication sharedApplication] delegate];
//
        // [appDelegate endTrackingInBackground:YES];
    }
    
//    [self setPlaying:NO];
//    [self setPlayerStatus:BLYPlayerViewControllerPlayerStatusPaused];
//    
//    [self postPauseNotification];
}

- (void)postPauseNotification
{
    [self postPauseNotificationForPlayer:YES];
}

- (void)postPauseNotificationForPlayer:(BOOL)forPlayer
{
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:self.currentSong
                                                         forKey:@"pausedSong"];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BLYPlayerViewControllerDidPauseSongNotification
                                                        object:self
                                                      userInfo:userInfo];
    
    if (!forPlayer) {
        return;
    }
}

- (IBAction)togglePlayPause:(id)sender
{
    // Sender may be a UIButton, a GestureRecognizer or nil...
    if (self.isPlaying) {
        [self pause:YES];
    } else {
        [self play];
    }
}

- (BLYSong *)songPlayedAfterSong:(BLYSong *)song
{
    if (!song) {
        return nil;
    }
    
    NSInteger indexOfSongInPlaylist = [self.playlist indexOfSong:song];
    
    if (indexOfSongInPlaylist == NSNotFound) {
        NSLog(@"BLYPlayerViewController::songPlayedAfterSong: called with an unknown song !");
        
        return nil;
    }
    
    if (indexOfSongInPlaylist + 1 == [self.playlist nbOfSongs]) {
        return nil;
    }
    
    return [self.playlist songAtIndex:indexOfSongInPlaylist + 1];
}

- (IBAction)playNextPlayableSongInPlaylist:(id)sender
{
    if ([self.playlist nbOfSongs] <= 1) {
        return;
    }
    
    BLYSong *currentSong = [self currentSong];
    BLYSong *nextSong = [self firstPlayableNextSongForSong:currentSong];
    
    BLYSong *_firstPlayablePreviousSong = currentSong;
    BLYSong *firstPlayablePreviousSong = nil;
    
    if (!nextSong) {
        while ((_firstPlayablePreviousSong = [self firstPlayablePreviousSongForSong:_firstPlayablePreviousSong])) {
            firstPlayablePreviousSong = _firstPlayablePreviousSong;
        }
        
        nextSong = firstPlayablePreviousSong;
    }
    
    [self loadSong:nextSong askedByUser:!!sender];
}

- (BLYSong *)songPlayedBeforeSong:(BLYSong *)song
{
    if (!song) {
        return nil;
    }
    
    NSInteger indexOfSongInPlaylist = [self.playlist indexOfSong:song];
    
    if (indexOfSongInPlaylist == 0) {
        return nil;
    }
    
    if (indexOfSongInPlaylist == NSNotFound) {
        NSLog(@"BLYPlayerViewController::songPlayedBeforeSong: called with an unknown song !");
        
        return nil;
    }
    
    return [self.playlist songAtIndex:indexOfSongInPlaylist - 1];
}

- (IBAction)playPreviousPlayableSongInPlaylist:(id)sender
{
    BOOL rewindAtEnd = NO;
    
    if ([self.playlist nbOfSongs] == 0) {
        return;
    }
    
    BLYSong *currentSong = self.currentSong;
    BLYSong *previousSong = [self firstPlayablePreviousSongForSong:currentSong];
    AVPlayer *player = self.player;
    
    Float64 currentTime = CMTimeGetSeconds([player currentTime]);
    double currentDurationAsSecond = [self currentDurationAsSecond];
    double playedPercent = (currentTime / currentDurationAsSecond) * 100;
    
    if (currentTime >= BLYPlayerViewControllerRewindOrPreviousSongTime
        && self.playerStatus != BLYPlayerViewControllerPlayerStatusError) {
        __weak BLYPlayerViewController *weakSelf = self;
        
        [self rewindAtEnd:NO withCompletion:^{
            [weakSelf play];
        }];
        
        if (playedPercent < 80) {
            return;
        }
        
        rewindAtEnd = true;
        previousSong = self.currentSong;
    }
    
    BLYSong *_lastPlayableNextSong = currentSong;
    BLYSong *lastPlayableNextSong = nil;
    
    if (!previousSong) {
        if ([self.playlist nbOfSongs] == 1) {
            return;
        }
        
        while ((_lastPlayableNextSong = [self firstPlayableNextSongForSong:_lastPlayableNextSong])) {
            lastPlayableNextSong = _lastPlayableNextSong;
        }
        
        previousSong = lastPlayableNextSong;
    }
    
    if (previousSong) {
        if (!_lastPreviousSongPlayed) {
            _lastPreviousSongPlayed = [@{@"song": previousSong, @"count": [NSNumber numberWithInt:1]} mutableCopy];
        } else {
            if ([((BLYSong*)_lastPreviousSongPlayed[@"song"]).sid isEqualToString:previousSong.sid]) {
                _lastPreviousSongPlayed[@"count"] = [NSNumber numberWithInt:[_lastPreviousSongPlayed[@"count"] intValue] + 1];
            } else {
                _lastPreviousSongPlayed[@"song"] = previousSong;
                _lastPreviousSongPlayed[@"count"] =  [NSNumber numberWithInt:1];
            }
        }
    }
    
    if (!rewindAtEnd) {
        [self loadSong:previousSong askedByUser:!!sender];
    }
    
    if (_lastPreviousSongPlayed && [_lastPreviousSongPlayed[@"count"] intValue] >= 2) {
        [self setRepeatMode:BLYPlayerViewControllerRepeatModeOne];
    }
}

- (void)seekToTime:(id)sender
{
    CMTime time = CMTimeMake([(UISlider *)sender value] * [self currentDurationAsSecond], 1);
    
    if (self.isPlaying) {
        self.pausedByPlaybackSlide = YES;
        
        [self pause:YES];
    }
    
    [self updatePlaybackInfo:time];
    
    // Don't use `isCached` here given that song could be loaded with URL first
    // then cached while playing !!
    if (![[(AVURLAsset *)self.player.currentItem.asset URL] isFileURL]) {
        return;
    }
    
    [self.player seekToTime:time toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    
    //dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
//        AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:self.player.currentItem.asset];
//
//        imageGenerator.appliesPreferredTrackTransform = true;
//        imageGenerator.maximumSize = CGSizeZero;
//
////        imageGenerator.requestedTimeToleranceBefore = kCMTimeZero;
////        imageGenerator.requestedTimeToleranceAfter = kCMTimeZero;
//
//        UIImage *img = [UIImage imageWithCGImage:[imageGenerator copyCGImageAtTime:time actualTime:nil error:nil]];
//
//        //dispatch_async(dispatch_get_main_queue(), ^(void) {
//            if (self.isPlaying) {
//                return;
//            }
//
//            self.playerSeekToTimeFrameImg.contentMode = UIViewContentModeScaleToFill;
//
//            self.playerSeekToTimeFrameImg.image = img;
//            self.playerSeekToTimeFrameImg.hidden = NO;
//
//    if ([self isFullscreen]) {
//        [[BLYFullScreenPlayerViewController sharedVC] playerSeekToTimeFrameImg].contentMode = UIViewContentModeScaleToFill;
//        [[BLYFullScreenPlayerViewController sharedVC] playerSeekToTimeFrameImg].image = img;
//        [[BLYFullScreenPlayerViewController sharedVC] playerSeekToTimeFrameImg].hidden = NO;
//    }
        //});
    //});
    
//    [imageGenerator generateCGImagesAsynchronouslyForTimes:@[[NSValue valueWithCMTime:time]] completionHandler:^(CMTime requestedTime, CGImageRef  _Nullable image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError * _Nullable error) {
//
//        UIImage *img = [UIImage imageWithCGImage:[imageGenerator copyCGImageAtTime:time actualTime:nil error:nil]];
//
//        dispatch_async(dispatch_get_main_queue(), ^{
//            if (self.isPlaying) {
//                return;
//            }
//
//            self.playerSeekToTimeFrameImg.contentMode = UIViewContentModeScaleAspectFill;
//
//            self.playerSeekToTimeFrameImg.image = img;
//            self.playerSeekToTimeFrameImg.hidden = NO;
//        });
//    }];
}

- (IBAction)seekToTimeEnd:(id)sender
{
    [self seekToTimeEnd:sender afterUrlForSongWasRefreshed:NO];
}

- (void)seekToTimeEnd:(id)sender afterUrlForSongWasRefreshed:(BOOL)urlWasRefreshed
{
    double toTime = round(fabs([(UISlider *)sender value] * [self currentDurationAsSecond]));
    
    [self seekToSpecifiedTime:toTime afterUrlForSongWasRefreshed:urlWasRefreshed];
}

- (void)seekToSpecifiedTime:(double)toTime afterUrlForSongWasRefreshed:(BOOL)urlWasRefreshed
{
    if (![self playerIsLoaded]
        || self.player.currentItem.status != AVPlayerItemStatusReadyToPlay) {
        
        return;
    }
    
    if (toTime < 0.0) {
        toTime = 0.0;
    }
    
    CMTime time = CMTimeMake(toTime, 1);
    __weak BLYPlayerViewController *weakSelf = self;
    
    if (![[BLYNetworkStore sharedStore] networkIsReachable]) {
        BOOL needToSeek = NO;
        NSArray *bufferedTimeRanges = _player.currentItem.loadedTimeRanges;
        
        for (NSValue *timeRangeAsValue in bufferedTimeRanges) {
            CMTimeRange timeRange = [timeRangeAsValue CMTimeRangeValue];
            
            float startSeconds = CMTimeGetSeconds(timeRange.start);
            float durationSeconds = CMTimeGetSeconds(timeRange.duration);
            
            if (toTime < (startSeconds + durationSeconds)) {
                needToSeek = true;
            }
        }
        
        if (!needToSeek) {
            AVPlayerItem *currentItem = self.player.currentItem;
            CMTime currentTime = [currentItem currentTime];
            
            time = CMTimeMake(0.0, 1);
        }
    }
    
    self.seekToTimeFuturTime = time;
    
    [self handleSongIsLoading];
    [self postLoadNotification];
    
    self.playerStatus = BLYPlayerViewControllerPlayerStatusLoading;
    
    [self disablePlayIcon];
    [self disablePlaybackSlider];
    
    // Video URL has expired
    if ([self.currentVideoURLExpiresAt timeIntervalSinceNow] <= 0) {
        
        [self loadSong:self.currentSong
                    at:toTime
           askedByUser:[self.currentSong.loadedByUser boolValue]];
        
        return;
    }
    
    __block BOOL bufferingTooManyTimes = NO;
    
    [NSTimer scheduledTimerWithTimeInterval:4.0 repeats:NO block:^(NSTimer * _Nonnull timer) {
        if (bufferingTooManyTimes) {
            return;
        }
        
        bufferingTooManyTimes = true;
        
        [self rewindAtEnd:NO withCompletion:^{
            weakSelf.playNotificationSendedForCurrentSong = NO;
            
            [weakSelf play];
        }];
    }];
    
    [self.player seekToTime:time toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished){
        if (bufferingTooManyTimes) {
            weakSelf.pausedByPlaybackSlide = NO;
            
            return;
        }
        
        bufferingTooManyTimes = true;
        
        // If another seek request is already in progress when you call this method,
        // the completion handler for the in-progress seek request is executed immediately
        // with the finished parameter set to NO.
        if (!finished) {
            return;
        }
        
        if (urlWasRefreshed) {
            weakSelf.loadCurrentSongAtTime = 0.0;
        }
        
        [weakSelf handleSongIsLoaded];
        [weakSelf enablePlayPauseIcon];
        [weakSelf enablePlaybackSlider];
        
        weakSelf.playerSeekToTimeFrameImg.hidden = true;
        [[BLYFullScreenPlayerViewController sharedVC] playerSeekToTimeFrameImg].hidden = true;
        
        weakSelf.seekToTimeFuturTime = CMTimeMake(-1.0, 1.0);
        
        if (!weakSelf.isPausedByPlaybackSlide
            && !urlWasRefreshed
            && !weakSelf.userWantsPlay) {
            
            // Make sure player state not remaining to loading
            [weakSelf pause:NO];
            
            return;
        }
        
        [weakSelf play];
        
//        double seconds = CMTimeGetSeconds(time);
//
        // Player rate observer doesn't send play notification in this case
//        if (seconds <= BLYPlayerViewControllerMinElapsedTimeForRateObserverToSendPlayNotification) {
//            [weakSelf postPlayNotification];
//        }
        
        weakSelf.pausedByPlaybackSlide = NO;
    }];
}

- (void)rewindAtEnd:(BOOL)atEnd
     withCompletion:(void(^)(void))completion
{
    __weak BLYPlayerViewController *weakSelf = self;
    
    void(^completionHandler)(BOOL) = ^(BOOL finished){
        if (!finished || !completion) {
            return;
        }
        
        completion();
        
        [weakSelf loadPlayingInfoAtSongLoad:YES];
    };
    
    [self.player seekToTime:kCMTimeZero
            toleranceBefore:kCMTimeZero
             toleranceAfter:kCMTimeZero
          completionHandler:completionHandler];
    
    if (!atEnd) {
        return;
    }
    
    //[self handleCompleteBuffer];
    
    //[self unloadBackgroundPlayer];
    
    //self.bgPlayerWasSuccessfullyLoadedWithNextSong = nil;
}

- (void)setRepeatMode:(BLYPlayerViewControllerRepeatMode)repeatMode
{
    //NSMutableDictionary *songInfo = [self loadPlayingInfoAtSongLoad:NO];
    //UIImage * img = nil;
    
    _repeatMode = repeatMode;
    
    if (_repeatMode == BLYPlayerViewControllerRepeatModeNone) {
        [self disableRepeatIcon];
        [self hideRepeatExplainLabelImmediately:NO];
        
        //img = [self.currentSong.album largeThumbnailAsImg] ? [self.currentSong.album largeThumbnailAsImg] : [self.currentSong.album smallThumbnailAsImg];
    } else {
        [self enableRepeatIcon];
        [self showRepeatExplainLabelImmediately:NO];
        
        //img = [self getMediaCenterThumbWithText:@"🔂"];
    }
    
//    MPMediaItemArtwork *albumArt = [[MPMediaItemArtwork  alloc] initWithBoundsSize:img.size requestHandler:^UIImage * _Nonnull(CGSize size) {
//        return img;
//    }];
    
    //[songInfo setObject:albumArt
                 //forKey:MPMediaItemPropertyArtwork];
    
//    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:songInfo];
}

- (void)toggleRepeatMode
{
    if (self.repeatMode == BLYPlayerViewControllerRepeatModeNone) {
        self.repeatMode = BLYPlayerViewControllerRepeatModeOne;
    } else {
        self.repeatMode = BLYPlayerViewControllerRepeatModeNone;
    }
}

- (IBAction)repeat:(id)sender
{
    if (![self playerIsLoaded]
        || [self.playlist nbOfSongs] <= 1) {
        return;
    }
    
    [self toggleRepeatMode];
}

- (BOOL)playerIsLoaded
{
    return self.player
        && self.playerItem
        && self.player.status == AVPlayerStatusReadyToPlay
        && self.playerStatus != BLYPlayerViewControllerPlayerStatusUnknown;
}

- (void)handleRemoteControlReceivedInAppDelegate:(NSNotification *)n
{
    [self remoteControlReceivedWithEvent:[n.userInfo objectForKey:@"receivedEvent"]];
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)receivedEvent
{
    static NSTimer *seekingBTimer = nil;
    static NSTimer *seekingFFTimer = nil;
    
    if (receivedEvent.type == UIEventTypeRemoteControl) {
        
        switch (receivedEvent.subtype) {
            case UIEventSubtypeRemoteControlTogglePlayPause:
                if (self.playerStatus != BLYPlayerViewControllerPlayerStatusPaused
                    && self.playerStatus != BLYPlayerViewControllerPlayerStatusPlaying) {
                    break;
                }
                
                [self togglePlayPause:nil];
               
                break;
                
            case UIEventSubtypeRemoteControlPlay:
                if (self.playerStatus != BLYPlayerViewControllerPlayerStatusPaused) {
                    break;
                }
                
                [self play];
                
                break;
                
            case UIEventSubtypeRemoteControlPause:
            case UIEventSubtypeRemoteControlStop:
                if (self.playerStatus != BLYPlayerViewControllerPlayerStatusPlaying) {
                    break;
                }
                
                [self pause:YES];
                break;
                
            case UIEventSubtypeRemoteControlPreviousTrack:
                [self playPreviousPlayableSongInPlaylist:receivedEvent];
                break;
                
            case UIEventSubtypeRemoteControlNextTrack:
                [self playNextPlayableSongInPlaylist:receivedEvent];
                break;
                
            case UIEventSubtypeRemoteControlBeginSeekingBackward:
            {
                void (^action)(NSTimer *) = ^(NSTimer * timer) {
                    CMTime currentTime = [self.player.currentItem currentTime];
                    float newTimeInS = CMTimeGetSeconds(currentTime) - 5.0;
                    
                    newTimeInS = MAX(newTimeInS - 5.0, 0.0);
                    
                    [self seekToSpecifiedTime:newTimeInS
                       afterUrlForSongWasRefreshed:NO];
                };
                
                action(nil);
                
                seekingBTimer = [NSTimer scheduledTimerWithTimeInterval:0.6
                                                                repeats:YES
                                                                  block:action];
                break;
            }
                
            case UIEventSubtypeRemoteControlEndSeekingBackward:
                [seekingBTimer invalidate];
                
                seekingBTimer = nil;
                
                break;
            
            case UIEventSubtypeRemoteControlBeginSeekingForward:
            {
                void (^action)(NSTimer *) = ^(NSTimer * timer) {
                    CMTime currentTime = [self.player.currentItem currentTime];
                    float newTimeInS = CMTimeGetSeconds(currentTime) + 5.0;
                    
                    newTimeInS = MIN(newTimeInS + 5.0, [self currentDurationAsSecond]);
                    
                    [self seekToSpecifiedTime:newTimeInS
                       afterUrlForSongWasRefreshed:NO];
                };
                
                action(nil);
                
                seekingFFTimer = [NSTimer scheduledTimerWithTimeInterval:0.6
                                                                 repeats:YES
                                                                   block:action];

                break;
            }
            
            case UIEventSubtypeRemoteControlEndSeekingForward:
                [seekingFFTimer invalidate];
                
                seekingFFTimer = nil;
                
                break;
                
            default:
                break;
        }
    }
}

- (void)handleAudioSessionReseted:(NSNotification *)event
{
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
    
    [userInfo setValue:NSLocalizedString(@"unknown_error", nil)
                forKey:NSLocalizedDescriptionKey];
    
    NSError *err = [NSError errorWithDomain:@"com.brown.blyplayerviewcontroller"
                                       code:BLYPlayerViewControllerUnknownErrorCode
                                   userInfo:userInfo];
    
    [self handlePlayerError];
    
    [self loadPlaybackInfoForPlayerError:err];
    
    [self pause:NO];
}

- (void)handleAudioSessionInterruption:(NSNotification*)event
{
    NSUInteger type = [[[event userInfo] objectForKey:AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
//    NSUInteger interruptionOption = [[[event userInfo] objectForKey:AVAudioSessionInterruptionOptionKey] unsignedIntegerValue];
    
    switch (type) {
        case AVAudioSessionInterruptionTypeBegan:
        {
            self.audioSessionWasInterrupted = self.userWantsPlay;
            self.appStateWhenAudioSessionWasInterrupted = [[UIApplication sharedApplication] applicationState];
            
            [self pause:NO];
            
            break;
        }
            
        case AVAudioSessionInterruptionTypeEnded:
        {
            // if (interruptionOption == AVAudioSessionInterruptionOptionShouldResume) {
            if (self.audioSessionWasInterrupted) {
                [self endAudioSessionInterruptionIfNecessary];
            }
            
            self.audioSessionWasInterrupted = NO;
            
            break;
        }
    }
}

- (void)endAudioSessionInterruptionIfNecessary {
    
    UIApplicationState currentAppState = [[UIApplication sharedApplication] applicationState];
    
    if (!self.audioSessionWasInterrupted) {
        return;
    }
    
    if (_appStateWhenAudioSessionWasInterrupted == UIApplicationStateBackground
        && currentAppState == UIApplicationStateActive) {
        
        return;
    }
    
    [self play];
}

- (void)showPlaylist:(id)sender
{
    if (!self.playlist) {
        return;
    }
    
    BLYBaseNavigationController *navigationController = [[BLYBaseNavigationController alloc] init];
    BLYPlayerPlaylistViewController *playlistVC = [[BLYPlayerPlaylistViewController alloc] init];
    
    playlistVC.playlist = self.playlist;
    playlistVC.playerVC = self;
    
    [navigationController addChildViewController:playlistVC];
    
    [playlistVC setModalTransitionStyle:UIModalTransitionStyleCoverVertical];
    
    // Use root controller here to avoid "Warning :-Presenting view controllers on detached view controllers is discouraged"
    // when the method is called from others vc
    [self.tabBarController presentViewController:navigationController
                                        animated:YES
                                      completion:nil];
}

- (void)handlePlaylistWillLoad:(NSNotification *)n
{
    [self postCorrespondingStatusNotification];
}

- (void)postCorrespondingStatusNotification
{
    BLYPlayerViewControllerPlayerStatus playerStatus = self.playerStatus;
    
    if (playerStatus == BLYPlayerViewControllerPlayerStatusUnknown) {
        return;
    }
    
    switch (playerStatus) {
        case BLYPlayerViewControllerPlayerStatusLoading:
        {
            [self postLoadNotificationForPlayer:NO];
            
            break;
        }
            
        case BLYPlayerViewControllerPlayerStatusPlaying:
        {
            [self postPlayNotificationForPlayer:NO];
            
            break;
        }
            
        case BLYPlayerViewControllerPlayerStatusPaused:
        {
            [self postPauseNotificationForPlayer:NO];
            
            break;
        }
            
        case BLYPlayerViewControllerPlayerStatusError:
        {
            [self postLoadWithErrorNotificationForPlayer:NO];
            
            break;
        }
            
        default:
        {
            break;
        }
    }
}

- (void)handleViewControllerDidLoad:(NSNotification *)n
{
    [self postLoadPlaylistNotificationForPlayer:NO];
}

- (IBAction)openVideoSongInYoutube:(id)sender
{
    // TODO: find the bug who make this shit
    if (!self.currentSong || [self.currentSong.videos count] == 0) {
        return;
    }
    
    BLYVideoSong *videoSong = [self.currentSong.videos objectAtIndex:0];
    
    BLYVideo *video = videoSong.video;
    NSString *videoID = video.sid;
    
    NSString *stringURL = [NSString stringWithFormat:@"http://www.youtube.com/watch?v=%@", videoID];
    NSURL *url = [NSURL URLWithString:stringURL];
    
    [self pause:YES];
    
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
        
    }];
}

- (IBAction)showAlbumButtonSelected:(id)sender
{
    self.showAlbumButton.alpha = 0.1;
    self.albumNameLabel.alpha = 0.3;
}

- (IBAction)showAlbumButtonReleased:(id)sender
{
    self.showAlbumButton.alpha = 0.3;
    self.albumNameLabel.alpha = 1.0;
}

- (IBAction)showAlbum:(id)sender
{
    if (!self.currentSong) {
        return;
    }
    
    BLYBaseNavigationController *navVc = [[BLYBaseNavigationController alloc] init];
    BLYAlbumViewController *albumVC = [[BLYAlbumViewController alloc] init];
    BLYAlbum *album = self.currentSong.album;
    
    albumVC.loadedAlbumSid = album.sid;
    albumVC.playerVC = self;
    
    [navVc addChildViewController:albumVC];
    
    [self presentViewController:navVc
                       animated:YES
                     completion:nil];
    
//    BLYAppDelegate *appDelegate = (BLYAppDelegate *)[[UIApplication sharedApplication] delegate];
//
//    [appDelegate trackEventWithCategory:@"player_ui"
//                                 action:@"show_album"
//                                  label:nil
//                                  value:nil];
}

- (void)showArtistSongs:(id)sender
{
    if (!self.currentSong) {
        return;
    }
    
    BLYBaseNavigationController *navC = [[BLYBaseNavigationController alloc] init];
    BLYSearchSongResultsViewController *searchSongResultsVC = [[BLYSearchSongResultsViewController alloc] init];
    
    [navC addChildViewController:searchSongResultsVC];
    
    searchSongResultsVC.currentSearchedArtist = self.currentSong.artist;
    searchSongResultsVC.playerVC = self;
    
    [self presentViewController:navC
                       animated:YES
                     completion:nil];
    
//    BLYAppDelegate *appDelegate = (BLYAppDelegate *)[[UIApplication sharedApplication] delegate];
//
//    [appDelegate trackEventWithCategory:@"player_ui"
//                                 action:@"show_artist"
//                                  label:nil
//                                  value:nil];
}

- (void)handlePlaylistHasUpdatedASongNotification:(NSNotification *)n
{
    NSDictionary *userInfo = [n userInfo];
    BLYSong *song = [userInfo objectForKey:@"song"];
    
    if (![self.currentSong isEqual:song]
        || [n object] != self.playlist) {
        return;
    }
    
    self.currentSong = song;
}

- (void)handleTouchOnAd:(NSNotification *)n
{
    NSDictionary *userInfo = [n userInfo];
    BOOL willLeave = [userInfo[@"will_leave"] boolValue];
    
    // If the willLeave parameter is YES, then your app is going to be moved to the background after it returns from this delegate method.
    // If the willLeave parameter is NO, iAd covers the app’s user interface after it returns from this delegate method.
    if (!willLeave && self.isPlaying) {
        [self pause:NO];
    }
}

- (void)handleAdResignAfterTouch:(NSNotification *)n
{
    if (self.userWantsPlay && !self.isPlaying) {
        [self play];
    }
}

- (void)handleNetworkReachable:(NSNotification *)n
{
    [super handleNetworkReachable:n];
    
    // Try to reload background player when network is reachable once again
//    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive
//        && self.currentSongIsInRepeatModeDueToBadNetwork
//        && !self.bgPlayerWasSuccessfullyLoadedWithNextSong) {
//
//        [self loadBackgroundPlayerWithNextSong];
//    }
    
    [self managePlaylistPlayControlsForSong:self.currentSong];
}

- (void)handleNetworkNotReachable:(NSNotification *)n
{
    [super handleNetworkNotReachable:n];
    
    [self managePlaylistPlayControlsForSong:self.currentSong];
}

- (void)handleNetworkTypeChange:(NSNotification *)n
{
    [super handleNetworkTypeChange:n];
    
    [self managePlaylistPlayControlsForSong:self.currentSong];
}

- (void)handleAppSettingHasChangedNotification:(NSNotification *)n
{
    NSDictionary *userInfo = n.userInfo;
    
    if ([userInfo[@"setting"] intValue] != BLYAppSettingsStoreForbidUcachedSongsListeningSetting) {
        return;
    }
    
    [self managePlaylistPlayControlsForSong:self.currentSong];
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (void)enable:(BOOL)enable RemoteCommand:(MPRemoteCommand *)command
{
    [command setEnabled:enable];
    
    if (!enable) {
        [command removeTarget:self];
    } else {
        
    }
}

- (MPRemoteCommandHandlerStatus)remoteCommandPlay:(MPRemoteCommandEvent *)event
{
    //            if (self.playerStatus != BLYPlayerViewControllerPlayerStatusPaused) {
    //                return MPRemoteCommandHandlerStatusNoActionableNowPlayingItem;
    //            }
    
    [self play];
    
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)remoteCommandPause:(MPRemoteCommandEvent *)event
{
    //            if (self.playerStatus != BLYPlayerViewControllerPlayerStatusPlaying) {
    //                return MPRemoteCommandHandlerStatusNoActionableNowPlayingItem;
    //            }
    
    [self pause:YES];
    
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)remoteCommandTogglePlayPause:(MPRemoteCommandEvent *)event
{
    if (self.playerStatus != BLYPlayerViewControllerPlayerStatusPaused
        && self.playerStatus != BLYPlayerViewControllerPlayerStatusPlaying) {
        
        return MPRemoteCommandHandlerStatusNoActionableNowPlayingItem;
    }
    
    [self togglePlayPause:event];
    
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)remoteCommandPreviousTrack:(MPRemoteCommandEvent *)event
{
    [self playPreviousPlayableSongInPlaylist:event];
    
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)remoteCommandNextTrack:(MPRemoteCommandEvent *)event
{
    [self playNextPlayableSongInPlaylist:event];
    
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)remoteCommandSeekBackward:(MPSeekCommandEvent *)event
{
    static NSTimer *seekingBTimer = nil;
    
    if (event.type == MPSeekCommandEventTypeEndSeeking) {
        [seekingBTimer invalidate];
        
        seekingBTimer = nil;
        
        return MPRemoteCommandHandlerStatusSuccess;
    }
    
    void (^action)(NSTimer *) = ^(NSTimer * timer) {
        CMTime currentTime = [self.player.currentItem currentTime];
        float newTimeInS = CMTimeGetSeconds(currentTime) - 5.0;
        
        newTimeInS = MAX(newTimeInS - 5.0, 0.0);
        
        [self seekToSpecifiedTime:newTimeInS
           afterUrlForSongWasRefreshed:NO];
    };
    
    action(nil);
    
    seekingBTimer = [NSTimer scheduledTimerWithTimeInterval:0.4
                                                    repeats:YES
                                                      block:action];
    
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)remoteCommandSeekForward:(MPSeekCommandEvent *)event
{
    static NSTimer *seekingFFTimer = nil;
    
    if (event.type == MPSeekCommandEventTypeEndSeeking) {
        [seekingFFTimer invalidate];
        
        seekingFFTimer = nil;
        
        return MPRemoteCommandHandlerStatusSuccess;
    }
    
    void (^action)(NSTimer *) = ^(NSTimer * timer) {
        CMTime currentTime = [self.player.currentItem currentTime];
        float newTimeInS = CMTimeGetSeconds(currentTime) + 5.0;
        
        newTimeInS = MIN(newTimeInS + 5.0, [self currentDurationAsSecond]);
        
        [self seekToSpecifiedTime:newTimeInS
           afterUrlForSongWasRefreshed:NO];
    };
    
    action(nil);
    
    seekingFFTimer = [NSTimer scheduledTimerWithTimeInterval:0.4
                                                     repeats:YES
                                                       block:action];
    
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)remoteCommandChangeRepeatMode:(MPChangeRepeatModeCommandEvent *)event
{
    if (event.repeatType == MPRepeatTypeOne) {
        [self setRepeatMode:BLYPlayerViewControllerRepeatModeOne];
    } else {
        [self setRepeatMode:BLYPlayerViewControllerRepeatModeNone];
    }
    
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)remoteCommandChangePlaybackPosition:(MPChangePlaybackPositionCommandEvent *)event
{
    // change position
    if (self.isPlaying) {
        [self pause:YES];
        
        self.pausedByPlaybackSlide = YES;
    }
    
    [self seekToSpecifiedTime:lroundf(event.positionTime) afterUrlForSongWasRefreshed:NO];
    
    return MPRemoteCommandHandlerStatusSuccess;
}

- (void)enableAllRemoteCommands
{
    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
    
    [commandCenter.playCommand setEnabled:true];
    [commandCenter.playCommand addTarget:self action:@selector(remoteCommandPlay:)];
    
    [commandCenter.pauseCommand setEnabled:true];
    [commandCenter.pauseCommand addTarget:self action:@selector(remoteCommandPause:)];
    
    [commandCenter.togglePlayPauseCommand setEnabled:true];
    [commandCenter.togglePlayPauseCommand addTarget:self action:@selector(remoteCommandTogglePlayPause:)];
    
    [commandCenter.previousTrackCommand setEnabled:true];
    [commandCenter.previousTrackCommand addTarget:self action:@selector(remoteCommandPreviousTrack:)];
    
    [commandCenter.nextTrackCommand setEnabled:true];
    [commandCenter.nextTrackCommand addTarget:self action:@selector(remoteCommandNextTrack:)];
    
    [commandCenter.seekBackwardCommand setEnabled:true];
    [commandCenter.seekBackwardCommand addTarget:self action:@selector(remoteCommandSeekBackward:)];
    
    [commandCenter.seekForwardCommand setEnabled:true];
    [commandCenter.seekForwardCommand addTarget:self action:@selector(remoteCommandSeekForward:)];
    
    [commandCenter.changePlaybackPositionCommand setEnabled:true];
    [commandCenter.changePlaybackPositionCommand addTarget:self action:@selector(remoteCommandChangePlaybackPosition:)];
    
    [commandCenter.changeRepeatModeCommand setEnabled:true];
    [commandCenter.changeRepeatModeCommand addTarget:self action:@selector(remoteCommandChangeRepeatMode:)];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self removeObserverForPlayer:self.player];
    [self removeObserverforPlayerItem:self.player.currentItem forBackground:NO];
    
    [self removeObserverForPlayer:self.backgroundPlayer];
    [self removeObserverforPlayerItem:self.backgroundPlayer.currentItem forBackground:NO];
    
    [self unloadAudioSession];
}

@end
