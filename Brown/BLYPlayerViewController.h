//
//  BLYPlayerViewController.h
//  Brown
//
//  Created by Jeremy Levy on 20/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import "BLYPlayerContainerChildViewController.h"

@class BLYPlaylist;
@class BLYSong;
@class BLYPlayerView;
@class BLYVideo;
@class BLYPlayerContainerViewController;

typedef enum {
    BLYPlayerViewControllerRepeatModeNone,
    BLYPlayerViewControllerRepeatModeOne
} BLYPlayerViewControllerRepeatMode;

typedef enum {
    BLYPlayerViewControllerPlayerStatusPlaying,
    BLYPlayerViewControllerPlayerStatusPaused,
    BLYPlayerViewControllerPlayerStatusLoading,
    BLYPlayerViewControllerPlayerStatusUnknown,
    BLYPlayerViewControllerPlayerStatusError
} BLYPlayerViewControllerPlayerStatus;

extern NSString * const BLYPlayerViewControllerDidLoadSongNotification;
extern NSString * const BLYPlayerViewControllerDidPauseSongNotification;
extern NSString * const BLYPlayerViewControllerDidPlaySongNotification;
extern NSString * const BLYPlayerViewControllerDidTerminateBGWorkNotification;
extern NSString * const BLYPlayerViewControllerDidLoadSongWithErrorNotification;
extern NSString * const BLYPlayerViewControllerDidLoadPlaylistNotification;
extern NSString * const BLYPlayerViewControllerDidCompleteVideoBuffering;
extern NSString * const BLYPlayerViewControllerDidAddToPersonalTop;

extern const int BLYPlayerViewControllerSongNotFoundErrorCode;
extern const float BLYPlayerViewControllerRewindOrPreviousSongTime;
extern const double BLYPlayerViewControllerMinElapsedTimeForRateObserverToSendPlayNotification;

@interface BLYPlayerViewController : BLYPlayerContainerChildViewController <AVAudioPlayerDelegate, AVAssetResourceLoaderDelegate>

@property (strong, nonatomic) AVPlayer *player;
@property (strong, nonatomic) AVPlayer *backgroundPlayer;
// Used to distinguish when player is unloaded during song loading
// but current item still to old song until load finish
@property (strong, nonatomic) AVPlayerItem *playerItem;
@property (nonatomic) BLYPlayerViewControllerPlayerStatus playerStatus;
@property (strong, nonatomic) AVPlayerLayer *playerLayer;
@property (strong, nonatomic) BLYPlaylist *playlist;
@property (strong, nonatomic) NSMutableDictionary *playerStateBeforeBadNetworkHappen;
@property (strong, nonatomic) BLYSong *currentSong;
@property (weak, nonatomic) IBOutlet UIView *playerPlaybackContainer;
@property (weak, nonatomic) IBOutlet UIView *playerViewContainer;
@property (weak, nonatomic) IBOutlet UIImageView *playerSeekToTimeFrameImg;
@property (strong, nonatomic) IBOutlet UITapGestureRecognizer *playerViewContainerTapGR;
@property (weak, nonatomic) IBOutlet UIView *playerContainer;
@property (weak, nonatomic) IBOutlet UIImageView *playerCoverBackground;
@property (nonatomic, getter = isPlaying) BOOL playing;
@property (weak, nonatomic) IBOutlet MPVolumeView *volumeSlider;
@property (weak, nonatomic) IBOutlet UISlider *playbackSlider;
@property (weak, nonatomic) IBOutlet UILabel *playbackCurrentTimeLabel;
@property (weak, nonatomic) IBOutlet UILabel *playbackDurationLabel;
@property (nonatomic, getter = isPausedByPlaybackSlide) BOOL pausedByPlaybackSlide;
@property (weak, nonatomic) IBOutlet UIButton *playPauseButton;
@property (weak, nonatomic) IBOutlet UIButton *nextSongButton;
@property (weak, nonatomic) IBOutlet UIButton *previousSongButton;
@property (weak, nonatomic) IBOutlet UIButton *repeatButton;
@property (weak, nonatomic) IBOutlet UIButton *showAlbumButton;
@property (weak, nonatomic) IBOutlet UIButton *showAlbumLabelButton;
@property (nonatomic) BLYPlayerViewControllerRepeatMode repeatMode;
@property (nonatomic) UIBackgroundTaskIdentifier backgroundTask;
@property (nonatomic) BOOL songWasPausedBecauseEmptyBuffer;
@property (weak, nonatomic) IBOutlet UIProgressView *bufferingBar;
@property (weak, nonatomic) IBOutlet UISlider *bufferingBarBG;
@property (weak, nonatomic) IBOutlet UIButton *youtubeLogoButton;
@property (weak, nonatomic) IBOutlet UIButton *vevoLogoButton;
@property (nonatomic, getter = isFullscreen) BOOL fullscreen;
@property (weak, nonatomic) IBOutlet UIView *loadingView;
@property (weak, nonatomic) IBOutlet UILabel *albumNameLabel;
@property (weak, nonatomic) IBOutlet UIView *nextSongContainer;
@property (weak, nonatomic) IBOutlet UILabel *nextSongTitleLabel;
@property (weak, nonatomic) IBOutlet UILabel *nextSongArtistNameLabel;
@property (weak, nonatomic) IBOutlet UIView *previousSongContainer;
@property (weak, nonatomic) IBOutlet UILabel *previousSongTitleLabel;
@property (weak, nonatomic) IBOutlet UILabel *previousSongArtistNameLabel;
@property (strong, nonatomic) BLYVideo *currentVideo;
@property (nonatomic) BOOL completeBufferCallbackCalled;
@property (weak, nonatomic) IBOutlet UILabel *loadingTextLabel;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *repeatExplainLabelBottomConstraint;

- (AVPlayerLayer *)layerForPlayerWithFrame:(CGRect)frame forceNew:(BOOL)force;
- (void)loadPlaylist:(BLYPlaylist *)playlist andStartWithSong:(BLYSong *)song askedByUser:(BOOL)askedByUser forceRefresh:(BOOL)forceRefresh;
- (void)loadPlaylist:(BLYPlaylist *)playlist andStartWithSong:(BLYSong *)song askedByUser:(BOOL)askedByUser;
- (void)loadSong:(BLYSong *)song askedByUser:(BOOL)askedByUser;
- (void)play;
- (void)pause:(BOOL)initiatedByUser;
- (IBAction)playNextPlayableSongInPlaylist:(id)sender;
- (IBAction)playPreviousPlayableSongInPlaylist:(id)sender;
- (IBAction)togglePlayPause:(id)sender;
- (IBAction)seekToTime:(id)sender;
- (IBAction)seekToTimeEnd:(id)sender;
- (IBAction)repeat:(id)sender;
- (IBAction)openVideoSongInYoutube:(id)sender;
- (IBAction)showAlbum:(id)sender;
- (BOOL)hasNextSongs;
- (BOOL)hasPreviousSongs;
- (void)disableNextIcon;
- (void)disablePreviousIcon;
- (void)enableNextIcon;
- (void)enablePreviousIcon;
- (void)loadPlayerLayerAndForceNew:(BOOL)force;
- (void)setBufferingBarProgress:(float)progress animated:(BOOL)animated;
- (void)showPlaylist:(id)sender;
- (BOOL)isCurrentSong:(BLYSong *)song;
- (void)showPlayIcon;
- (void)showPauseIcon;
- (BLYSong *)firstPlayableNextSongForSong:(BLYSong *)song;
- (BLYSong *)firstPlayablePreviousSongForSong:(BLYSong *)song;
- (void)updateNavLeftButtonTitleForSong:(BLYSong *)song
                                orTitle:(NSString *)title;

- (IBAction)showAlbumButtonSelected:(id)sender;
- (IBAction)showAlbumButtonReleased:(id)sender;

- (IBAction)playNextSongButtonSelected:(id)sender;
- (IBAction)playNextSongButtonReleased:(id)sender;

- (IBAction)playPreviousSongButtonSelected:(id)sender;
- (IBAction)playPreviousSongButtonReleased:(id)sender;

@end
