//
//  BLYBaseViewController.m
//  Brown
//
//  Created by Jeremy Levy on 04/10/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "BLYBaseViewController.h"
#import "BLYPlayerViewController.h"
#import "BLYAppDelegate.h"
#import "BLYFullScreenPlayerViewController.h"
#import "BLYNetworkStore.h"
#import "BLYFullScreenPlayerViewController.h"
#import "BLYHTTPConnection.h"
#import "BLYBaseTabBarController.h"
#import "BLYPlaylistViewController.h"
#import "BLYPlayedSongViewController.h"

NSString * const BLYBaseViewControllerDidLoadNotification = @"BLYBaseViewControllerDidLoadNotification";

@interface BLYBaseViewController ()

@property (weak, nonatomic) BLYPlayerViewController *playerVC;

@property (nonatomic) UIDeviceOrientation currentOrientation;
@property (nonatomic) BOOL firstLoad;

@property (nonatomic) BOOL playerIsLoadedAndAccessible;
@property (nonatomic) BOOL isLandscape;

@end

@implementation BLYBaseViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self) {
        // Custom initialization
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handlePlayerHasLoadedPlaylist:)
                                                     name:BLYPlayerViewControllerDidLoadPlaylistNotification
                                                   object:nil];
        
//        [[NSNotificationCenter defaultCenter] addObserver:self
//                                                 selector:@selector(handlePlayerHasPlayedSong:)
//                                                     name:BLYPlayerViewControllerDidPlaySongNotification
//                                                   object:nil];
        
//        [[NSNotificationCenter defaultCenter] addObserver:self
//                                                 selector:@selector(handleRotationChanged:)
//                                                     name:UIDeviceOrientationDidChangeNotification
//                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleNetworkNotReachable:)
                                                     name:BLYNetworkStoreDidDetectThatNetworkIsNotReachable
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleNetworkReachable:)
                                                     name:BLYNetworkStoreDidDetectThatNetworkIsReachable
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleNetworkTypeChange:)
                                                     name:BLYNetworkStoreDidDetectThatNetworkTypeHasChanged
                                                   object:nil];
        
        _playerIsLoadedAndAccessible = NO;
        _isLandscape = NO;
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (self.presentingViewController) {
        UIBarButtonItem *modalVCDismissButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                              target:self
                                                                                              action:@selector(dismissMe:)];
        
        self.navigationItem.rightBarButtonItem = modalVCDismissButton;
    }
    
    /* Player view controller listen to this and post load playlist notification 
     to display playlist button on this newly created view controller */
    [[NSNotificationCenter defaultCenter] postNotificationName:BLYBaseViewControllerDidLoadNotification
                                                        object:self];
    
    _firstLoad = YES;
    
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.extendedLayoutIncludesOpaqueBars = NO;
    self.automaticallyAdjustsScrollViewInsets = NO;
    
    [self normalNavigationBar];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
//    UIColor *tabBarTintColor = [UIColor colorWithRed:33.0 / 255.0 green:33.0 / 255.0 blue:33.0 / 255.0 alpha:1.0];
//    UIColor *tabTintColor = [UIColor whiteColor];
//    
//    if (![self isKindOfClass:[BLYPlayerContainerViewController class]]
//        && ![self isKindOfClass:[BLYPlayerViewController class]]
//        && ![self isKindOfClass:[BLYPlayerContainerChildViewController class]]) {
//        tabBarTintColor = [UIColor whiteColor];
//        tabTintColor = [UIColor blackColor];
//        
//        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
//    } else {
//        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];
//    }
//    
//    [self setNeedsStatusBarAppearanceUpdate];
//    
//    self.tabBarController.tabBar.barTintColor = tabBarTintColor;
//    self.tabBarController.tabBar.tintColor = tabTintColor;
//    self.tabBarController.tabBar.translucent = NO;
//    
//    self.navigationController.navigationBar.barTintColor = tabBarTintColor;
//    self.navigationController.navigationBar.tintColor = tabTintColor;
//    self.navigationController.navigationBar.translucent = NO;
    
    if (!self.firstLoad) {
        return;
    }
    
    if (![[BLYNetworkStore sharedStore] networkIsReachable]) {
        [self handleNetworkNotReachable:nil];
    } else {
        [self handleNetworkReachable:nil];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (!self.firstLoad) {
        return;
    }
    
    if (![[BLYNetworkStore sharedStore] networkIsReachable]) {
        [self handleNetworkNotReachable:nil];
    } else {
        [self handleNetworkReachable:nil];
    }
    
    self.firstLoad = NO;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    // Make sure iad was properly displayed after modal vc was presented
    // [self updateTabBarLayoutForiAd];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)extendedNavigationBar
{
    [self.lightBottomBorder removeFromSuperlayer];
    self.lightBottomBorder = nil;
    
    for (BLYBaseViewController *vc in self.navigationController.viewControllers) {
        [vc.lightBottomBorder removeFromSuperlayer];
        vc.lightBottomBorder = nil;
    }
}

- (void)normalNavigationBar
{
    [self.navigationController.navigationBar setTranslucent:NO];
    
    // The navigation bar's shadowImage is set to a transparent image.  In
    // conjunction with providing a custom background image, this removes
    // the grey hairline at the bottom of the navigation bar.  The
    // ExtendedNavBarView will draw its own hairline.
    [self.navigationController.navigationBar setShadowImage:[UIImage imageNamed:@"TransparentPixel"]];
    // "Pixel" is a solid white 1x1 image.
    [self.navigationController.navigationBar setBackgroundImage:[UIImage imageNamed:@"Pixel"] forBarMetrics:UIBarMetricsDefault];
    
    [self navigationBarLightBorder];
}

- (void)navigationBarLightBorder
{
    CALayer *bottomBorder = [CALayer layer];
    
    bottomBorder.frame = CGRectMake(0.0f, self.navigationController.navigationBar.frame.size.height - 0.5, self.view.frame.size.width, 0.5f);
    
    // Set the background colour of the new layer to the colour you wish to
    // use for the border.
    bottomBorder.backgroundColor = [[UIColor colorWithWhite:0.92 alpha:1.0] CGColor];
    
    for (BLYBaseViewController *vc in self.navigationController.viewControllers) {
        if (vc.lightBottomBorder) {
            [vc.lightBottomBorder removeFromSuperlayer];
            vc.lightBottomBorder = nil;
        }
        
        vc.lightBottomBorder = bottomBorder;
    }
    
    // Add the later to the tab bar's existing layer
    [self.navigationController.navigationBar.layer addSublayer:self.lightBottomBorder];
}

- (void)handlePlayerHasLoadedPlaylist:(NSNotification *)n
{
    // If VC was presented modally, return
    if (self.presentingViewController) {
        return;
    }
    
    BLYPlayerViewController *playerVC = (BLYPlayerViewController *)[n object];
    
    self.playerVC = playerVC;
    
    // App settings displayed on the right
//    if ([self isKindOfClass:[BLYPlayedSongViewController class]]) {
//        return;
//    }
    
    UIBarButtonItem *rightBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"PlaylistNav"]
                                                                       style:UIBarButtonItemStylePlain
                                                                      target:playerVC
                                                                      action:NSSelectorFromString(@"showPlaylist:")];
    
    self.navigationItem.rightBarButtonItem = rightBarButton;
}

- (void)handlePlayerHasPlayedSong:(NSNotification *)n
{
    _playerIsLoadedAndAccessible = YES;
}

//- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
//{
//    [[BLYFullScreenPlayerViewController sharedVC] preload];
//}

- (void)handleRotationChanged:(NSNotification *)n
{
    return;
    BLYFullScreenPlayerViewController *fullScreenPlayerVC = [BLYFullScreenPlayerViewController sharedVC];
    
    BOOL should = //self.playerVC
                  //&& self.playerVC.playerStatus != BLYPlayerViewControllerPlayerStatusUnknown
                  _playerIsLoadedAndAccessible
                  && !fullScreenPlayerVC.aViewControllerIsPresentingOtherVC;
    
    if (!_playerIsLoadedAndAccessible) {
        return;
    }
    
    // Don't use `keyWindow` here because it could be replaced by `MPAVRoutingSheetSecureWindow`
    // when MPVolumeView's route list is opened when rotated
    // https://stackoverflow.com/questions/34347328/mpvolumeview-route-list-is-supporting-all-orientations-and-ignoring-underlying-v
    // https://stackoverflow.com/questions/21698482/diffrence-between-uiapplication-sharedapplication-delegate-window-and-u
    UIWindow *window = [[[UIApplication sharedApplication] delegate] window];
    UIViewController *presentedVC = window.rootViewController.presentedViewController;
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
    
    if (presentedVC
        && [presentedVC isKindOfClass:[UIAlertController class]]) {
        
        return;
    }
    
    if (newOrientation == UIDeviceOrientationPortrait && fullScreenPlayerVC.rootVC && fullScreenPlayerVC.fullScreenWindow.alpha == 1.0) {
        fullScreenPlayerVC.rootVC = nil;
        
        window.alpha = 0.0;
        window.hidden = NO;
        _playerVC.volumeSlider.hidden = NO;
        
        [window makeKeyAndVisible];
        
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
                             
                         }];
    } else if (UIDeviceOrientationIsLandscape(newOrientation)
               && !fullScreenPlayerVC.rootVC
               && window.alpha == 1.0) {
        
        BLYFullScreenPlayerViewController *fullScreenPlayerVC = [BLYFullScreenPlayerViewController sharedVC];
        
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
        fullScreenPlayerVC.fullScreenWindow.rootViewController = fullScreenPlayerVC;
        
        [fullScreenPlayerVC.fullScreenWindow setBackgroundColor:[UIColor blackColor]];
        
        [fullScreenPlayerVC.fullScreenWindow makeKeyAndVisible];
        
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
                              _playerVC.volumeSlider.hidden = true;
                         }];
    }
    
//    _isLandscape = UIDeviceOrientationIsLandscape(newOrientation);
//    [self setNeedsStatusBarAppearanceUpdate];
    
    // Fix https://stackoverflow.com/questions/35804693/navigation-bar-under-status-bar-after-video-playback-in-landscape-mode
}

//- (void)updateTabBarLayoutForiAd
//{
//    BLYAppDelegate *delegate = (BLYAppDelegate *)[[UIApplication sharedApplication] delegate];
//    
//    // Update layout for ad
//    [delegate.tabBarVC updateLayout];
//}

- (BOOL)shouldAutorotate
{
    return true;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return UIInterfaceOrientationPortrait;
}

// Fix https://stackoverflow.com/questions/35804693/navigation-bar-under-status-bar-after-video-playback-in-landscape-mode/47572924
- (BOOL)prefersStatusBarHidden
{
    return UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]);
}

- (BOOL)prefersHomeIndicatorAutoHidden
{
    return NO;
}

- (void)handleNetworkNotReachable:(NSNotification *)n
{
    // To be overrided
}

- (void)handleNetworkReachable:(NSNotification *)n
{
    // To be overrided
}

- (void)handleNetworkTypeChange:(NSNotification *)n
{
    // To be overrided
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent
                     animated:(BOOL)flag
                   completion:(void (^)(void))completion
{
    BLYFullScreenPlayerViewController *fullScreenPlayerVC = [BLYFullScreenPlayerViewController sharedVC];
    
    fullScreenPlayerVC.aViewControllerIsPresentingOtherVC = YES;
    
    void (^hookedCompletion)(void) = ^{
        if (completion) {
            completion();
        }
        
        fullScreenPlayerVC.aViewControllerIsPresentingOtherVC = NO;
    };
    
    [super presentViewController:viewControllerToPresent
                        animated:flag
                      completion:hookedCompletion];
}

- (BOOL)isVisible
{
    return self.isViewLoaded && self.view.window;
}

- (void)dismissMe:(id)sender
{
    if ([self isKindOfClass:[BLYPlaylistViewController class]]) {
        ((BLYPlaylistViewController *)self).dismissOnPlay = NO;
    }
    
    [self.presentingViewController dismissViewControllerAnimated:YES
                                                      completion:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (self.launchedConnection) {
        [self.launchedConnection cancel];
    }
}

@end
