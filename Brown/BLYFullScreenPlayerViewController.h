//
//  BLYFullScreenPlayerViewController.h
//  Brown
//
//  Created by Jeremy Levy on 05/10/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>

extern NSString * const BLYFullScreenPlayerViewControllerWillEnterFullScreenNotification;

@class BLYPlayerViewController;

@interface BLYFullScreenPlayerViewController : UIViewController <NSLayoutManagerDelegate, UITextViewDelegate>

@property (strong, nonatomic) UIViewController *rootVC;
@property (weak, nonatomic) BLYPlayerViewController *playerVC;
@property (weak, nonatomic) IBOutlet UIView *playerTopControlsContainer;
@property (weak, nonatomic) IBOutlet UIView *playerBottomControlsContainer;
//@property (weak, nonatomic) IBOutlet MPVolumeView *volumeSlider;
@property (weak, nonatomic) IBOutlet UISlider *playbackSlider;
@property (weak, nonatomic) IBOutlet UILabel *playbackCurrentTimeLabel;
@property (weak, nonatomic) IBOutlet UILabel *playbackDurationLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *bufferingBar;
@property (weak, nonatomic) IBOutlet UISlider *bufferingBarBG;
@property (weak, nonatomic) IBOutlet UIButton *playPauseButton;
@property (weak, nonatomic) IBOutlet UIButton *nextSongButton;
@property (weak, nonatomic) IBOutlet UIButton *previousSongButton;
@property (weak, nonatomic) IBOutlet UILabel *songTitle;
@property (weak, nonatomic) IBOutlet UIView *loadingView;
@property (weak, nonatomic) IBOutlet UIView *nextSongView;
@property (nonatomic) BOOL aViewControllerIsPresentingOtherVC;
@property (weak, nonatomic) IBOutlet UIImageView *nextSongThumbnail;
@property (weak, nonatomic) IBOutlet UILabel *nextSongTitle;
@property (weak, nonatomic) IBOutlet UILabel *nextSongArtistName;
@property (weak, nonatomic) IBOutlet UIView *previousSongView;
@property (weak, nonatomic) IBOutlet UIImageView *previousSongThumbnail;
@property (weak, nonatomic) IBOutlet UILabel *previousSongTitle;
@property (weak, nonatomic) IBOutlet UILabel *previousSongArtistName;

@property (weak, nonatomic) IBOutlet UIView *commentContainer;
@property (weak, nonatomic) IBOutlet UILabel *commentAuthor;
@property (weak, nonatomic) IBOutlet UITextView *commentText;
@property (weak, nonatomic) IBOutlet UIImageView *playerCoverBackground;
@property (weak, nonatomic) IBOutlet UIImageView *playerSeekToTimeFrameImg;
@property (weak, nonatomic) IBOutlet UILabel *loadingTextLabel;
@property (strong, nonatomic) UIWindow *fullScreenWindow;

+ (BLYFullScreenPlayerViewController *)sharedVC;
- (IBAction)seekToTimeEnd:(id)sender;
- (IBAction)seekToTime:(id)sender;
- (IBAction)togglePlayPause:(id)sender;
- (IBAction)playNextPlayableSongInPlaylist:(id)sender;
- (IBAction)playPreviousPlayableSongInPlaylist:(id)sender;
- (void)setSongTitleValueFor:(NSString *)songTitle andArtistName:(NSString *)artistName;
- (void)updateNextSongView;
- (void)showPlayerControlsForSongLoading;
- (void)preload;
- (void)loadPlayerLayer;

- (IBAction)playNextSongButtonSelected:(id)sender;
- (IBAction)playNextSongButtonReleased:(id)sender;
- (void)hidePlayerControlsForSongLoading;

@end
