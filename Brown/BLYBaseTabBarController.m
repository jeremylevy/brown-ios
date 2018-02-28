//
//  BLYBaseTabBarController.m
//  Brown
//
//  Created by Jeremy Levy on 04/10/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import "BLYBaseViewController.h"
#import "BLYBaseTabBarController.h"
#import "BLYSearchSongViewController.h"
#import "BLYBaseNavigationController.h"
#import "BLYFullScreenPlayerViewController.h"
#import "BLYPlayerViewController.h"

@interface BLYBaseTabBarController ()

@property (weak, nonatomic) BLYPlayerViewController *playerVC;
@property (nonatomic) BOOL playerIsLoadedAndAccessible;
@property (nonatomic) BOOL keyboardIsVisible;
@property (nonatomic) double tabbarInitialHeight;
@property (nonatomic) BOOL isLandscape;
@property (nonatomic) BOOL playerVolumeSliderHiddenByFullScreen;

@end

@implementation BLYBaseTabBarController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
//    if (self) {
//        self.delegate = self;
//    }
    
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handlePlayerHasLoadedPlaylist:)
                                                     name:BLYPlayerViewControllerDidLoadPlaylistNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handlePlayerHasPlayedSong:)
                                                     name:BLYPlayerViewControllerDidPlaySongNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleRotationChanged:)
                                                     name:UIDeviceOrientationDidChangeNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleKeyboardShown:)
                                                     name:UIKeyboardWillShowNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleKeyboardHidden:)
                                                     name:UIKeyboardDidHideNotification
                                                   object:nil];
        
        _playerIsLoadedAndAccessible = NO;
        _keyboardIsVisible = NO;
        
        _tabbarInitialHeight = 0.0;
        _isLandscape = NO;
        
        _playerVolumeSliderHiddenByFullScreen = NO;
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.tabBar.translucent = NO;
}

//- (void)updateLayout
//{
//    if (!self.selectedViewController) {
//        return;
//    }
//    
//    // Managed by BLYSearchSongViewController when keyboard show up etc.
//    if ([self.selectedViewController isKindOfClass:[BLYBaseNavigationController class]]) {
//        BLYBaseNavigationController *baseVC = (BLYBaseNavigationController *)self.selectedViewController;
//        NSArray *vcs = baseVC.viewControllers;
//        UIViewController *vc = [vcs objectAtIndex:0];
//        
//        if ([vc isKindOfClass:[BLYSearchSongViewController class]]
//            && [vcs count] == 1
//            && ((BLYSearchSongViewController *)vc).keyboardIsDisplayed) {
//            return;
//        }
//    }
//}

//- (void)handleBannerViewDidLoadAdNotification:(NSNotification *)notification
//{
//    [self updateLayout];
//}
//
//- (void)handleBannerViewDidFailToReceiveAdNotification:(NSNotification *)notification
//{
//    [self updateLayout];
//}

//- (void)tabBarController:(UITabBarController *)tabBarController
// didSelectViewController:(UIViewController *)viewController
//{
//    [self updateLayout];
//}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // [[BLYFullScreenPlayerViewController sharedVC] preload];
}

-(void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    [self.tabBar invalidateIntrinsicContentSize];
}

- (void)handleKeyboardShown:(NSNotification *)n
{
    _keyboardIsVisible = true;
}

- (void)handleKeyboardHidden:(NSNotification *)n
{
    _keyboardIsVisible = NO;
}

- (void)handleRotationChanged:(NSNotification *)n
{
    BLYFullScreenPlayerViewController *fullScreenPlayerVC = [BLYFullScreenPlayerViewController sharedVC];
    
    if (!_playerIsLoadedAndAccessible
        || _keyboardIsVisible) {
        
        return;
    }
    
    // Don't use `keyWindow` here because it could be replaced by `MPAVRoutingSheetSecureWindow`
    // when MPVolumeView's route list is opened when rotated
    // https://stackoverflow.com/questions/34347328/mpvolumeview-route-list-is-supporting-all-orientations-and-ignoring-underlying-v
    // https://stackoverflow.com/questions/21698482/diffrence-between-uiapplication-sharedapplication-delegate-window-and-u
    UIWindow *window = [[[UIApplication sharedApplication] delegate] window];
    UIViewController *topController = window.rootViewController;
    UIDeviceOrientation newOrientation = [(UIDevice *)[n object] orientation];
    
    if (!UIDeviceOrientationIsLandscape(newOrientation)
        && newOrientation != UIDeviceOrientationPortrait) {
        // UIDeviceOrientationFaceUp
        // UIDeviceOrientationFaceDown
        // UIDeviceOrientationPortraitUpsideDown
        return;
    }
    
    if (fullScreenPlayerVC.presentedViewController) {
        return;
    }
    
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    
    if (topController
        && [topController isKindOfClass:[UIAlertController class]]) {
        
        return;
    }
    
    if (newOrientation == UIDeviceOrientationPortrait && fullScreenPlayerVC.rootVC) {
        fullScreenPlayerVC.rootVC = nil;
        
        // Fix track cover flash when rotating device to
        // portrait while touching screen at the same time
        fullScreenPlayerVC.view.hidden = true;
        
        window.alpha = 0.0;
        window.hidden = NO;
        
        if (_playerVolumeSliderHiddenByFullScreen) {
            _playerVC.volumeSlider.hidden = NO;
            
            _playerVolumeSliderHiddenByFullScreen = NO;
        }
        
        [window makeKeyAndVisible];
        
        // Force view controllers to layout subviews
        // with portrait status bar
//        if (!self.presentedViewController) {
//            window.rootViewController = nil;
//            window.rootViewController = self;
//        } else {
//            [self.presentedViewController.view layoutSubviews];
//            [self.presentedViewController.view setNeedsLayout];
//            [self.presentedViewController.view layoutIfNeeded];
//        }
        
        [UIView animateWithDuration:0.5
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             [window setAlpha:1.0];
                         }
                         completion:^(BOOL finished){
                             UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
                             
                             if (!UIDeviceOrientationIsPortrait(orientation)) {
                                 return;
                             }
                             
                             fullScreenPlayerVC.view.hidden = NO;
                         }];
    } else if (UIDeviceOrientationIsLandscape(newOrientation)
               && !fullScreenPlayerVC.rootVC) {
        
        BLYFullScreenPlayerViewController *fullScreenPlayerVC = [BLYFullScreenPlayerViewController sharedVC];
        
        fullScreenPlayerVC.view.hidden = NO;
        fullScreenPlayerVC.playerVC = self.playerVC;
        fullScreenPlayerVC.rootVC = window.rootViewController;
        
        // Avoid weird animation
        if (self.playerVC.playerStatus == BLYPlayerViewControllerPlayerStatusPaused
            || self.playerVC.playerStatus == BLYPlayerViewControllerPlayerStatusPlaying) {
            
            fullScreenPlayerVC.playerCoverBackground.hidden = YES;
        }
        
        window.hidden = YES;
        
        fullScreenPlayerVC.fullScreenWindow.alpha = 0.0;
        fullScreenPlayerVC.fullScreenWindow.hidden = NO;
        
        //fullScreenPlayerVC.view = nil;
        
        fullScreenPlayerVC.fullScreenWindow.tintColor = window.tintColor;
        
        [UIViewController attemptRotationToDeviceOrientation];
        
        fullScreenPlayerVC.fullScreenWindow.rootViewController = fullScreenPlayerVC;
        
        [fullScreenPlayerVC.fullScreenWindow setBackgroundColor:[UIColor blackColor]];
        
        [fullScreenPlayerVC.fullScreenWindow makeKeyAndVisible];
        
        if (!_playerVC.volumeSlider.hidden) {
            _playerVC.volumeSlider.hidden = true;
            _playerVolumeSliderHiddenByFullScreen = true;
        }
        
        [UIView animateWithDuration:0.5
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             [fullScreenPlayerVC.fullScreenWindow setAlpha:1.0];
                         }
                         completion:^(BOOL finished){
                             UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
                             
                             if (!UIDeviceOrientationIsLandscape(orientation)) {
                                 return;
                             }
                             
                             fullScreenPlayerVC.playerCoverBackground.hidden = NO;
                         }];
    }
    
    _isLandscape = UIDeviceOrientationIsLandscape(newOrientation);
    
    //    _isLandscape = UIDeviceOrientationIsLandscape(newOrientation);
    [self setNeedsStatusBarAppearanceUpdate];
    
    // Fix https://stackoverflow.com/questions/35804693/navigation-bar-under-status-bar-after-video-playback-in-landscape-mode
}

- (void)handlePlayerHasPlayedSong:(NSNotification *)n
{
    _playerIsLoadedAndAccessible = YES;
}

- (void)handlePlayerHasLoadedPlaylist:(NSNotification *)n
{
    BLYPlayerViewController *playerVC = (BLYPlayerViewController *)[n object];
    
    self.playerVC = playerVC;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)shouldAutorotate
{
    return [self.selectedViewController shouldAutorotate];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return [self.selectedViewController supportedInterfaceOrientations];
}

- (BOOL)prefersStatusBarHidden
{
    return [self.selectedViewController prefersStatusBarHidden];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    if (_tabbarInitialHeight == 0.0) {
        _tabbarInitialHeight = self.tabBar.frame.size.height;
    }
    
    CGFloat kBarHeight = _tabbarInitialHeight * 0.897959184;
    
//    if (@available(iOS 11, *)) {
//        if (self.view.safeAreaInsets.bottom > 0) {
//            kBarHeight += self.view.safeAreaInsets.top;
//        }
//    }
    
    CGRect tabFrame = self.tabBar.frame;
    
    tabFrame.size.height = kBarHeight;
    
    tabFrame.origin.y = (self.view.frame.size.height - kBarHeight);
    
    self.tabBar.frame = tabFrame;
    
    CALayer *topBorder = [CALayer layer];
    topBorder.frame = CGRectMake(0.0f, 0.0f, self.view.frame.size.width, 0.5f);
    
    // Set the background colour of the new layer to the colour you wish to
    // use for the border.
    topBorder.backgroundColor = [[UIColor colorWithWhite:0.92 alpha:1.0] CGColor];
    
    // Add the later to the tab bar's existing layer
    [self.tabBar.layer addSublayer:topBorder];
    self.tabBar.clipsToBounds = YES;
    
    for (UIViewController *controller in self.viewControllers) {
        int offset = _tabbarInitialHeight * 0.136363636;
        UIEdgeInsets imageInset = UIEdgeInsetsMake(offset, 0, -offset, 0);
        
        controller.tabBarItem.imageInsets = imageInset;
    }
}

- (BOOL)prefersHomeIndicatorAutoHidden
{
    return [self.selectedViewController prefersHomeIndicatorAutoHidden];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
