//
//  BLYFullScreenPlayerViewController.m
//  Brown
//
//  Created by Jeremy Levy on 05/10/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import "BLYFullScreenPlayerViewController.h"
#import "BLYPlayerViewController.h"
#import "BLYPlaylist.h"
#import "BLYSong.h"
#import "BLYArtist.h"
#import "BLYArtistSong.h"
#import "BLYAlbum.h"
#import "BLYAlbum+Thumbnail.h"
#import "NSString+Sizing.h"
#import "BLYVideoStore.h"
#import "BLYVideoSong.h"
#import "BLYVideo.h"
#import "BLYVideoComment.h"
#import "BLYYoutubeUser.h"
#import "NSMutableArray+Shuffling.h"

NSString * const BLYFullScreenPlayerViewControllerWillEnterFullScreenNotification = @"BLYFullScreenPlayerViewControllerWillEnterFullScreenNotification";

@interface BLYFullScreenPlayerViewController ()

@property (nonatomic) BOOL playerControlsDisplayedBySongLoading;
@property (weak, nonatomic) NSTimer *displayCommentsTimer;
@property (strong, nonatomic) NSMutableArray *comments;
@property (nonatomic) BOOL hidePlayerControlsOnPlay;
@property (nonatomic) BOOL hasPreloaded;

@end

@implementation BLYFullScreenPlayerViewController

+ (BLYFullScreenPlayerViewController *)sharedVC
{
    static BLYFullScreenPlayerViewController *sharedVC = nil;
    
    if (!sharedVC) {
        sharedVC = [[BLYFullScreenPlayerViewController alloc] initWithNibName:nil
                                                                       bundle:nil];
    }
    
    return sharedVC;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self) {
        _aViewControllerIsPresentingOtherVC = NO;
        _playerControlsDisplayedBySongLoading = NO;
        
        _hidePlayerControlsOnPlay = NO;
        _hasPreloaded = NO;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handlePlayerHasLoadedASongNotification:)
                                                     name:BLYPlayerViewControllerDidLoadSongNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handlePlayerHasPlayedASong:)
                                                     name:BLYPlayerViewControllerDidPlaySongNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handlePlayerHasCompletedVideoBuffering:)
                                                     name:BLYPlayerViewControllerDidCompleteVideoBuffering
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleDeviceOrientationChanged:)
                                                     name:UIDeviceOrientationDidChangeNotification
                                                   object:nil];
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.loadingTextLabel.text = NSLocalizedString(@"full_screen_loading_text", nil);
    
//    [self.volumeSlider setVolumeThumbImage:[UIImage imageNamed:@"PlayerSliderThumb"]
//                                  forState:UIControlStateNormal];
    
    [self.playbackSlider setThumbImage:[UIImage imageNamed:@"PlayerSliderThumb"]
                              forState:UIControlStateNormal];
    
    self.playbackSlider.continuous = YES;
    self.playbackSlider.maximumTrackTintColor = [UIColor clearColor];
    
    UITapGestureRecognizer *tapGR = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                            action:@selector(handleTapOnPlayer:)];
    
    UITapGestureRecognizer *menuTopTapGR = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                   action:@selector(handleTapOnPlayerMenu:)];
    
    UITapGestureRecognizer *menuBottomTapGR = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                      action:@selector(handleTapOnPlayerMenu:)];
    
    [tapGR requireGestureRecognizerToFail:menuBottomTapGR];
    [tapGR requireGestureRecognizerToFail:menuTopTapGR];
    
    [self.view addGestureRecognizer:tapGR];
    
    [self.playerBottomControlsContainer addGestureRecognizer:menuBottomTapGR];
    [self.playerTopControlsContainer addGestureRecognizer:menuTopTapGR];
    
    self.commentText.layoutManager.delegate = self;
    self.commentText.delegate = self;
    
    if (!UIAccessibilityIsReduceTransparencyEnabled()) {
        self.playerTopControlsContainer.backgroundColor = [UIColor clearColor];
        self.playerBottomControlsContainer.backgroundColor = [UIColor clearColor];
        
        UIBlurEffect *blurEffectTop = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        UIVisualEffectView *blurEffectViewTop = [[UIVisualEffectView alloc] initWithEffect:blurEffectTop];
        
        UIBlurEffect *blurEffectBottom = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        UIVisualEffectView *blurEffectViewBottom = [[UIVisualEffectView alloc] initWithEffect:blurEffectBottom];
        
        //always fill the view
        blurEffectViewTop.frame = self.playerTopControlsContainer.bounds;
        blurEffectViewTop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        blurEffectViewBottom.frame = self.playerBottomControlsContainer.bounds;
        blurEffectViewBottom.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        [self.playerTopControlsContainer insertSubview:blurEffectViewTop atIndex:0];
        [self.playerBottomControlsContainer insertSubview:blurEffectViewBottom atIndex:0]; //if you have more UIViews, use an insertSubview API to place it where needed
    } else {
        self.playerBottomControlsContainer.backgroundColor = [UIColor blackColor];
        self.playerTopControlsContainer.backgroundColor = [UIColor blackColor];
    }
}

// Avoid weird rotate animation first 
- (void)preload
{
    if (_hasPreloaded) {
        return;
    }
    
    CGRect viewBounds = [[UIScreen mainScreen] bounds];
    UIWindow *w = [[UIWindow alloc] initWithFrame: CGRectMake(0.0, 0.0, viewBounds.size.height, viewBounds.size.width)];
    
    w.rootViewController = self;
    
    [w makeKeyAndVisible];
    
    _hasPreloaded = true;
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    if (!self.playerVC) {
        return;
    }
    
    if (self.playerVC.fullscreen
        // Fix bug when rotating device to
        // portrait while touching screen at the same time
        || UIDeviceOrientationIsPortrait([UIDevice currentDevice].orientation)) {
        
        return;
    }
    
    [self loadPlayerLayer];
    
    self.playerVC.fullscreen = YES;
    
    // Update player fullscreen UI
    if ([self.playerVC isPlaying]) {
        [self.playerVC showPauseIcon];
    } else {
        [self.playerVC showPlayIcon];
    }
    
    self.playPauseButton.alpha = self.playerVC.playPauseButton.alpha;
    self.playPauseButton.enabled = self.playerVC.playPauseButton.alpha;
    
    if (![self.playerVC hasNextSongs]) {
        [self.playerVC disableNextIcon];
    } else {
        [self.playerVC enableNextIcon];
    }
    
    if (![self.playerVC hasPreviousSongs]) {
        [self.playerVC disablePreviousIcon];
    } else {
        [self.playerVC enablePreviousIcon];
    }
    
    self.playerCoverBackground.image = self.playerVC.playerCoverBackground.image;
    
    self.playbackCurrentTimeLabel.text = self.playerVC.playbackCurrentTimeLabel.text;
    self.playbackDurationLabel.text = self.playerVC.playbackDurationLabel.text;
    
    [self.bufferingBarBG setThumbImage:[[UIImage alloc] init]
                              forState:UIControlStateNormal];
    
    self.bufferingBarBG.userInteractionEnabled = NO;
    self.bufferingBarBG.maximumTrackTintColor = [UIColor clearColor];
    
    self.playbackSlider.value = self.playerVC.playbackSlider.value;
    self.playbackSlider.userInteractionEnabled = self.playerVC.playbackSlider.userInteractionEnabled;
    
    // Will update fullscreen buffering bar
    [self.playerVC setBufferingBarProgress:self.playerVC.bufferingBar.progress
                                  animated:NO];
    
    BLYSong *currentSong = self.playerVC.currentSong;
    
    [self setSongTitleValueFor:currentSong.title
                 andArtistName:currentSong.artist.name];
    
    if ([self.playerVC isPlaying]) {
        [self hidePlayerControls];
    } else {
        [self showPlayerControls];
    }
    
    [self updateNextSongView];
    [self updatePreviousSongView];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BLYFullScreenPlayerViewControllerWillEnterFullScreenNotification
                                                        object:self];
    
    [self loadVideoComments];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    [self updateNextSongView];
    [self updatePreviousSongView];
}

- (void)loadPlayerLayer
{
    UIView *v = self.view;
    
    AVPlayerLayer *playerLayer = [self.playerVC layerForPlayerWithFrame:v.frame
                                                               forceNew:NO];
    
    [playerLayer removeFromSuperlayer];
    
    playerLayer.hidden = NO;
    
    [v.layer insertSublayer:playerLayer below:self.playerSeekToTimeFrameImg.layer];
}

- (void)handleTapOnPlayer:(UIGestureRecognizer *)gr
{
    self.playerControlsDisplayedBySongLoading = NO;
    
    if ([self.playerBottomControlsContainer isHidden]) {
        [self showPlayerControls];
    } else {
        [self hidePlayerControls];
    }
}

- (BOOL)playerControlsAreDisplayed
{
    return !self.playerBottomControlsContainer.hidden && !self.playerTopControlsContainer.hidden;
}

- (void)hidePlayerControls
{
    [self.view sendSubviewToBack:self.playerTopControlsContainer];
    [self.view sendSubviewToBack:self.playerBottomControlsContainer];
    
    self.playerBottomControlsContainer.hidden = YES;
    self.playerTopControlsContainer.hidden = YES;
    
    [self startDisplayCommentsTimer];
}

- (void)showPlayerControlsForSongLoading
{
    if ([self playerControlsAreDisplayed]) {
        return;
    }
    
    self.playerControlsDisplayedBySongLoading = YES;
    
    [self showPlayerControls];
}

- (void)hidePlayerControlsForSongLoading
{
    if (![self playerControlsAreDisplayed]
        || !self.playerControlsDisplayedBySongLoading) {
        return;
    }
    
    self.playerControlsDisplayedBySongLoading = NO;
    
    [self hidePlayerControls];
}

- (void)showPlayerControls
{
    [self.view bringSubviewToFront:self.playerTopControlsContainer];
    [self.view bringSubviewToFront:self.playerBottomControlsContainer];
    
    self.playerBottomControlsContainer.hidden = NO;
    self.playerTopControlsContainer.hidden = NO;
    
    [self invalidateDisplayCommentsTimer];
}

- (void)handleTapOnPlayerMenu:(UIGestureRecognizer *)gr
{
    self.hidePlayerControlsOnPlay = NO;
    
    // Required to fail by handleTapOnPlayer:
    return;
}

- (void)setRootVC:(id)rootVC
{
    _rootVC = rootVC;
    
    if (!rootVC) {
        self.playerVC.playerLayer.hidden = YES;
        // Make sure this is set before calling loadPlayerLayer
        self.playerVC.fullscreen = NO;
        
        [self.playerVC loadPlayerLayerAndForceNew:NO];
        [self invalidateDisplayCommentsTimer];
        
        _fullScreenWindow = nil;
        
        if (@available(iOS 11.0, *)) {
            [self setNeedsUpdateOfHomeIndicatorAutoHidden];
        }
    } else {
        CGRect viewBounds = [[UIScreen mainScreen] bounds];
        
        _fullScreenWindow = [[UIWindow alloc] initWithFrame: CGRectMake(0.0, 0.0, viewBounds.size.height, viewBounds.size.width)];
    }
}

- (void)setSongTitleValueFor:(NSString *)songTitle andArtistName:(NSString *)artistName
{
    BLYPlayerViewController *playerVC = self.playerVC;
    UIFont *titleFont = [UIFont systemFontOfSize:13.0];
    
    UILabel *songTitleLabel = self.songTitle;
    CGFloat songTitleLabelWidth = CGRectGetWidth(songTitleLabel.frame);
    
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:titleFont, NSFontAttributeName, nil];
    
    CGFloat(^getSizeOfString)(NSString *s) = ^CGFloat(NSString *s){
        return [s bly_widthForStringWithAttributes:attributes];
    };
    
    NSString*(^cleanCuttedString)(NSString *) = ^NSString*(NSString *s){
        s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        s = [s stringByTrimmingCharactersInSet:[NSCharacterSet punctuationCharacterSet]];
        s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        return s;
    };
    
    NSString *originalSongTitle = songTitle;
    NSString *originalArtistName = artistName;
    
    CGFloat titleWidth = getSizeOfString(songTitle);
    CGFloat artistWidth = getSizeOfString(artistName);
    CGFloat dotsWidth = getSizeOfString(@"...");
    CGFloat dashWidth = getSizeOfString(@" - ");
    
    if (titleWidth + artistWidth > songTitleLabelWidth) {
        NSString *longest = nil;
        NSString *shortest = nil;
        
        longest = [songTitle length] > [artistName length] ? songTitle : artistName;
        
        shortest = longest == artistName ? songTitle : artistName;
        
        for (NSUInteger i = [longest length]; YES; i--) {
            if ([longest length] == [shortest length]
                || (getSizeOfString(longest)
                    + getSizeOfString(shortest)
                    + dotsWidth
                    + dashWidth) <= songTitleLabelWidth) {
                break;
            }
            
            longest = [longest substringToIndex:i];
        }
        
        if (shortest == artistName) {
            songTitle = longest;
        } else {
            artistName = longest;
        }
        
        if ((getSizeOfString(songTitle) + getSizeOfString(artistName)) > songTitleLabelWidth) {
            NSString *last = @"songTitle";
            int y = 0;
            
            // [songTitle length] == [artistName length]
            for (NSUInteger i = [songTitle length]; YES; i--) {
                if ([last isEqualToString:@"songTitle"]) {
                    artistName = [artistName substringToIndex:i];
                    last = @"artistName";
                } else {
                    songTitle = [songTitle substringToIndex:i];
                    last = @"songTitle";
                }
                
                y++;
                
                if ((getSizeOfString(songTitle)
                     + getSizeOfString(artistName)
                     + (dotsWidth * MIN(2, y))
                     + dashWidth) <= songTitleLabelWidth) {
                    break;
                }
            }
        }
        
        if (![artistName isEqualToString:originalArtistName]) {
            artistName = cleanCuttedString(artistName);
            artistName = [artistName stringByAppendingString:@"..."];
        }
        
        if (![songTitle isEqualToString:originalSongTitle]) {
            songTitle = cleanCuttedString(songTitle);
            songTitle = [songTitle stringByAppendingString:@"..."];
        }
    }
    
    songTitleLabel.text = [NSString stringWithFormat:@"%@ - %@", artistName, songTitle];
    
//  songTitleLabel.text = [NSString stringWithFormat:@"%d. %@ - %@", [playerVC.playlist indexOfSong:playerVC.currentSong] + 1, artistName, songTitle];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size
          withTransitionCoordinator:coordinator];
    
    // Rotating from portrait to landscape
    if (self.playerCoverBackground.hidden) {
        return;
    }
    
    // Avoid ugly bottom border when rotating
    self.playerCoverBackground.hidden = true;
    
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
         self.playerCoverBackground.hidden = NO;
    }];
}

- (void)updateNextSongView
{
    BLYPlayerViewController *playerVC = self.playerVC;
    BLYSong *currentSong = playerVC.currentSong;
    
    if (!currentSong) {
        return;
    }
    
    BLYSong *nextSong = [playerVC firstPlayableNextSongForSong:currentSong];
    
    BLYSong *_firstPlayablePreviousSong = self.playerVC.currentSong;
    BLYSong *firstPlayablePreviousSong = nil;
    
    if (!nextSong) {
        while ((_firstPlayablePreviousSong = [self.playerVC firstPlayablePreviousSongForSong:_firstPlayablePreviousSong])) {
            firstPlayablePreviousSong = _firstPlayablePreviousSong;
        }
        
        nextSong = firstPlayablePreviousSong;
    }
    
    if (!nextSong) {
        self.nextSongView.hidden = YES;
        
        return;
    }
    
    self.nextSongThumbnail.image = [nextSong.album smallThumbnailAsImg];
    self.nextSongThumbnail.layer.cornerRadius = self.nextSongThumbnail.frame.size.height / 2.0;
    self.nextSongThumbnail.layer.masksToBounds = YES;
    // Performance improvement here depends on the size of your view
    self.nextSongThumbnail.layer.shouldRasterize = YES;
    self.nextSongThumbnail.layer.rasterizationScale = [UIScreen mainScreen].scale;
    
    self.nextSongTitle.text = nextSong.title;
//  self.nextSongTitle.text = [NSString stringWithFormat:@"%d. %@", [playerVC.playlist indexOfSong:nextSong] + 1, nextSong.title];
    
    self.nextSongArtistName.text = nextSong.artist.name;
    
    self.loadingView.hidden = YES;
    self.nextSongView.hidden = NO;
}

- (void)updatePreviousSongView
{
    BLYPlayerViewController *playerVC = self.playerVC;
    BLYSong *currentSong = playerVC.currentSong;
    
    if (!currentSong) {
        return;
    }
    
    BLYSong *previousSong = [playerVC firstPlayablePreviousSongForSong:currentSong];
    
    BLYSong *_lastPlayableNextSong = playerVC.currentSong;
    BLYSong *lastPlayableNextSong = nil;
    
    if (!previousSong && [playerVC.playlist nbOfSongs] > 1) {
        while ((_lastPlayableNextSong = [playerVC firstPlayableNextSongForSong:_lastPlayableNextSong])) {
            lastPlayableNextSong = _lastPlayableNextSong;
        }
        
        previousSong = lastPlayableNextSong;
    }
    
    if (!previousSong) {
        self.previousSongView.hidden = YES;
        
        return;
    }
    
    double elapsedTime = CMTimeGetSeconds([self.playerVC.player currentTime]);
    BOOL displayPreviousSongInfos = previousSong && (elapsedTime < BLYPlayerViewControllerRewindOrPreviousSongTime || self.playerVC.playerStatus == BLYPlayerViewControllerPlayerStatusError);
    
    self.previousSongThumbnail.image = [previousSong.album smallThumbnailAsImg];
    self.previousSongThumbnail.layer.cornerRadius = self.previousSongThumbnail.frame.size.height / 2.0;
    self.previousSongThumbnail.layer.masksToBounds = YES;
    // Performance improvement here depends on the size of your view
    self.previousSongThumbnail.layer.shouldRasterize = YES;
    self.previousSongThumbnail.layer.rasterizationScale = [UIScreen mainScreen].scale;

    self.previousSongTitle.text = previousSong.title;
//  self.previousSongTitle.text = [NSString stringWithFormat:@"%d. %@", [playerVC.playlist indexOfSong:previousSong] + 1, previousSong.title];
    
    self.previousSongArtistName.text = previousSong.artist.name;
    
    self.previousSongView.hidden = !displayPreviousSongInfos;
    self.previousSongButton.hidden = displayPreviousSongInfos;
}


- (IBAction)seekToTimeEnd:(id)sender
{
    [self.playerVC seekToTimeEnd:sender];
}

- (IBAction)seekToTime:(id)sender
{
    [self.playerVC seekToTime:sender];
}

- (IBAction)togglePlayPause:(id)sender
{
    [self.playerVC togglePlayPause:sender];
}

- (IBAction)playNextPlayableSongInPlaylist:(id)sender
{
    self.hidePlayerControlsOnPlay = YES;
    
    [self.playerVC playNextPlayableSongInPlaylist:sender];
}

- (IBAction)playPreviousPlayableSongInPlaylist:(id)sender
{
    [self.playerVC playPreviousPlayableSongInPlaylist:sender];
}

- (IBAction)playNextSongButtonSelected:(id)sender
{
    self.nextSongThumbnail.alpha = 0.3;
    self.nextSongTitle.alpha = 0.3;
    self.nextSongArtistName.alpha = 0.3;
}

- (IBAction)playNextSongButtonReleased:(id)sender
{
    self.nextSongThumbnail.alpha = 1.0;
    self.nextSongTitle.alpha = 1.0;
    self.nextSongArtistName.alpha = 1.0;
}

- (IBAction)playPreviousSongButtonSelected:(id)sender
{
    self.previousSongThumbnail.alpha = 0.3;
    self.previousSongTitle.alpha = 0.3;
    self.previousSongArtistName.alpha = 0.3;
}

- (IBAction)playPreviousSongButtonReleased:(id)sender
{
    self.previousSongThumbnail.alpha = 1.0;
    self.previousSongTitle.alpha = 1.0;
    self.previousSongArtistName.alpha = 1.0;
}

- (void)handlePlayerHasLoadedASongNotification:(NSNotification *)n
{
//    self.comments = nil;
//    
//    [self invalidateDisplayCommentsTimer];
    
    //[self preload];
}

- (void)handleDeviceOrientationChanged:(NSNotification *)n
{
    
}

- (void)handlePlayerHasPlayedASong:(NSNotification *)n
{
    if (self.hidePlayerControlsOnPlay) {
        [self hidePlayerControls];
        
        self.hidePlayerControlsOnPlay = NO;
    }
    
    [self updateNextSongView];
    [self updatePreviousSongView];
}

- (void)handlePlayerHasCompletedVideoBuffering:(NSNotification *)n
{
    BOOL isFullScreen = [self.playerVC isFullscreen];
    
    if (!isFullScreen) {
        return;
    }
    
    [self loadVideoComments];
}

- (void)loadVideoComments
{
    [self loadVideoCommentsAndStartImediatly:NO];
}

- (void)loadVideoCommentsAndStartImediatly:(BOOL)startImediatly
{
    // Can be nil !
    BLYVideo *video = self.playerVC.currentVideo;
    NSArray *comments = [[BLYVideoStore sharedStore] fetchUndisplayedCommentsForVideo:video];
    
    BOOL fullBuffer = self.playerVC.completeBufferCallbackCalled;
    __weak BLYFullScreenPlayerViewController *weakSelf = self;
    
    void (^completionBlock)(NSArray *, NSError *) = ^(NSArray * comments, NSError *err) {
        if (err) {
            return;
        }
        
        NSMutableDictionary *coms = [[NSMutableDictionary alloc] init];
        
        coms[@"displayed"] = [[NSMutableArray alloc] init];
        coms[@"undisplayed"] = [[NSMutableArray alloc] init];
        
        for (BLYVideoComment *comment in comments) {
            if ([comment.isDisplayed boolValue]) {
                [coms[@"displayed"] addObject:comment];
            } else {
                [coms[@"undisplayed"] addObject:comment];
            }
        }
        
        [coms[@"displayed"] bly_shuffle];
        
        // If we have undisplayed comments and displayed comments
        // Set undisplayed comments on top of the stack
        comments = [[NSArray alloc] init];
        
        comments = [comments arrayByAddingObjectsFromArray:coms[@"undisplayed"]];
        comments = [comments arrayByAddingObjectsFromArray:coms[@"displayed"]];
        
        weakSelf.comments = [comments mutableCopy];
        
        if (!startImediatly) {
            [weakSelf startDisplayCommentsTimer];
        } else {
            [weakSelf handleDisplayCommentsTimerFire:nil];
        }
    };
    
    // TODO: Thinking of a better way to display comments
    return;
    
    if ((!fullBuffer && [comments count] == 0) || self.comments) {
        return;
    }
    
    [[BLYVideoStore sharedStore] fetchCommentsForVideo:video
                                        withCompletion:completionBlock];
}

- (void)startDisplayCommentsTimer
{
    [self.displayCommentsTimer invalidate];
    
    self.displayCommentsTimer = [NSTimer scheduledTimerWithTimeInterval:8.0
                                                                 target:self
                                                               selector:@selector(handleDisplayCommentsTimerFire:)
                                                               userInfo:nil
                                                                repeats:NO];
}

- (void)invalidateDisplayCommentsTimer
{
    [self.displayCommentsTimer invalidate];
    [self hideCommentsImmediately];
}

- (void)handleDisplayCommentsTimerFire:(NSTimer *)t
{
    if (!self.displayCommentsTimer
        || [self playerControlsAreDisplayed]) {
        
        return;
    }
    
    if (!self.comments) {
        return [self loadVideoCommentsAndStartImediatly:YES];
    }
    
    if (self.commentContainer.hidden && [self.comments count] > 0) {
        [self displayComments];
    } else {
        [self hideComments];
    }
    
    [self startDisplayCommentsTimer];
}

- (void)displayComments
{
    __weak BLYFullScreenPlayerViewController *weakSelf = self;
    
    // Don't display comments when video is paused
    if (!self.playerVC.isPlaying) {
        return;
    }
    
    self.commentContainer.alpha = 0.0;
    self.commentContainer.hidden = NO;
    
    BLYVideoComment *comment = [self.comments objectAtIndex:0];
    
    [self.comments removeObjectAtIndex:0];
    
    NSMutableAttributedString *authorAttString=[[NSMutableAttributedString alloc] initWithString:[comment.author.name capitalizedString]];
    NSMutableAttributedString *contentAttString=[[NSMutableAttributedString alloc] initWithString:comment.content];
    
    [authorAttString addAttribute:NSStrokeColorAttributeName
                            value:[UIColor grayColor]
                            range:[comment.author.name bly_fullRange]];
    [authorAttString addAttribute:NSStrokeWidthAttributeName
                            value:[NSNumber numberWithFloat:-2.5]
                            range:[comment.author.name bly_fullRange]];
    
    [contentAttString addAttribute:NSForegroundColorAttributeName
                             value:[UIColor whiteColor]
                             range:[comment.content bly_fullRange]];
    [contentAttString addAttribute:NSStrokeColorAttributeName
                             value:[UIColor grayColor]
                             range:[comment.content bly_fullRange]];
    [contentAttString addAttribute:NSStrokeWidthAttributeName
                             value:[NSNumber numberWithFloat:-2.5]
                             range:[comment.content bly_fullRange]];
    
    self.commentAuthor.attributedText = authorAttString;
    self.commentText.attributedText = contentAttString;
    
    [self.view bringSubviewToFront:self.commentContainer];
    
    [[BLYVideoStore sharedStore] updateIsDisplayedFlag:YES
                                            forComment:comment];
    
    [UIView animateWithDuration:0.5
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         weakSelf.commentContainer.alpha = 1.0;
                     }
                     completion:nil];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self.displayCommentsTimer invalidate];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self startDisplayCommentsTimer];
}

// Returns comment content line-height
- (CGFloat)layoutManager:(NSLayoutManager *)layoutManager
lineSpacingAfterGlyphAtIndex:(NSUInteger)glyphIndex
withProposedLineFragmentRect:(CGRect)rect
{
    return 4.0; // For really wide spacing; pick your own value
}

- (void)hideComments
{
    __weak BLYFullScreenPlayerViewController *weakSelf = self;
    
    self.commentContainer.alpha = 1.0;
    
    [UIView animateWithDuration:0.5
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         weakSelf.commentContainer.alpha = 0.0;
                     }
                     completion:^(BOOL finished){
                         [weakSelf hideCommentsImmediately];
                     }];
}

- (void)hideCommentsImmediately
{
    self.commentContainer.hidden = YES;
    
    [self.view sendSubviewToBack:self.commentContainer];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskLandscape;
}

- (BOOL)shouldAutorotate
{
    // We want UIAlertController to block all rotations until dismissed
    return (self.presentedViewController == nil);
}

- (BOOL)prefersHomeIndicatorAutoHidden
{
    return _rootVC ? true : NO;
}

- (BOOL)prefersStatusBarHidden
{
    return true;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
