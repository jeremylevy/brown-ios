//
//  BLYPlayerContainerViewController.m
//  Brown
//
//  Created by Jeremy Levy on 23/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import "BLYPlayerContainerViewController.h"
#import "BLYPlayerViewController.h"
#import "BLYDiscoveryViewController.h"
#import "BLYCurrentSongVideoChoiceViewController.h"
#import "BLYPlayerNavItemTitleView.h"
#import "BLYSong.h"
#import "BLYAppDelegate.h"

NSString * const BLYPlayerContainerViewControllerDidChangeViewController = @"BLYPlayerContainerViewControllerDidChangeViewController";

@interface BLYPlayerContainerViewController ()

@property (nonatomic) BOOL pageVCIsLoaded;
@property (strong, nonatomic) BLYDiscoveryViewController *discoveryVC;
@property (strong, nonatomic) BLYCurrentSongVideoChoiceViewController *currentSongVideosVC;

@end

@implementation BLYPlayerContainerViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self) {
        UIImage *playerTabBarIcon = [UIImage imageNamed:@"PlayerTabBarIcon"];
        UIImage *playerSelectedTabBarIcon = [UIImage imageNamed:@"PlayerSelectedTabBarIcon"];
        
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@""
                                                        image:playerTabBarIcon
                                                selectedImage:playerSelectedTabBarIcon];
        
        self.tabBarItem.tag = 1;
        
        // Custom initialization
        _pageVCIsLoaded = NO;
        _loadedSongIsAVideo = YES;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handlePlayerHasLoadedASongNotification:)
                                                     name:BLYPlayerViewControllerDidLoadSongNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handlePlayerHasPlayedASongNotification:)
                                                     name:BLYPlayerViewControllerDidPlaySongNotification
                                                   object:nil];
    }
    
    return self;
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    NSDictionary *options = @{UIPageViewControllerOptionInterPageSpacingKey: [NSNumber numberWithFloat:1.0]};
    
    self.pageController = [[UIPageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
                                                          navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                                                                        options:options];
    
    self.pageController.dataSource = self;
    self.pageController.delegate = self;
    
    self.view.backgroundColor = [UIColor blackColor];
    
    self.discoveryVC = [[BLYDiscoveryViewController alloc] init];
    
    self.discoveryVC.playerVC = self.playerVC;
    self.discoveryVC.containerVC = self;
    
    self.currentSongVideosVC = [[BLYCurrentSongVideoChoiceViewController alloc] init];
    
    self.currentSongVideosVC.playerVC = self.playerVC;
    self.currentSongVideosVC.containerVC = self;
}

- (void)loadInPageVCVC:(UIViewController *)vc
              animated:(BOOL)animated
            completion:(void (^)(BOOL finished))completion
{
    NSArray *viewControllers = [NSArray arrayWithObject:vc];
    
    [self.pageController setViewControllers:viewControllers
                                  direction:UIPageViewControllerNavigationDirectionForward
                                   animated:animated
                                 completion:completion];

}

- (void)viewDidLayoutSubviews
{
    // Make sure to call super before return !
    // Update layout for iAD...
    [super viewDidLayoutSubviews];
    
    [self normalNavigationBar];
    
    if (self.pageVCIsLoaded) {
        return;
    }
    
    self.pageController.view.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height);
    
    [self loadInPageVCVC:self.playerVC animated:NO completion:nil];
    
    [self addChildViewController:self.pageController];
    
    [self.view addSubview:self.pageController.view];
    
    [self.pageController didMoveToParentViewController:self];
    
    // Set delay content touches in scroll view to handle uislider
    for (UIScrollView *view in self.pageController.view.subviews) {
        if ([view isKindOfClass:[UIScrollView class]]) {
            UIScrollView *scrollView = (UIScrollView *)view;
            
            scrollView.delaysContentTouches = NO;
        }
    }
    
    BLYPlayerNavItemTitleView *backView = [[[NSBundle mainBundle] loadNibNamed:@"BLYPlayerNavItemTitleView" owner:nil options:nil] objectAtIndex:0];
    
    backView.pageControl.userInteractionEnabled = NO;
    
    self.navigationItem.titleView = backView;
    self.navItemTitleView = backView;
    
    self.pageVCIsLoaded = YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
      viewControllerBeforeViewController:(UIViewController *)viewController
{
    if ([viewController isKindOfClass:[self.playerVC class]]) {
        if (self.loadedSongIsAVideo) {
            return nil;
        }
        
        // We need current video to display other videos for this song...
        if (!self.playerVC.currentVideo) {
            return nil;
        }
        
        return self.currentSongVideosVC;
    } else if ([viewController isKindOfClass:[self.currentSongVideosVC class]]) {
        return nil;
    }
    
    return self.playerVC;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
       viewControllerAfterViewController:(UIViewController *)viewController
{
    if ([viewController isKindOfClass:[self.discoveryVC class]]) {
        return nil;
    } else if ([viewController isKindOfClass:[self.currentSongVideosVC class]]) {
        return self.playerVC;
    }
    
    // We need current video to display videos related to it...
    if (!self.playerVC.currentVideo) {
        return nil;
    }
    
    return self.discoveryVC;
}

- (void)pageViewController:(UIPageViewController *)pageViewController
        didFinishAnimating:(BOOL)finished
   previousViewControllers:(NSArray *)previousViewControllers
       transitionCompleted:(BOOL)completed
{
    if (!completed) {
        return;
    }
    
    NSDictionary *userInfo = @{@"previousViewController": [previousViewControllers objectAtIndex:0]};
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BLYPlayerContainerViewControllerDidChangeViewController
                                                        object:self
                                                      userInfo:userInfo];
}

//- (NSInteger)presentationCountForPageViewController:(UIPageViewController *)pageViewController
//{
//    // The number of items reflected in the page indicator.
//    return 3;
//}
//
//- (NSInteger)presentationIndexForPageViewController:(UIPageViewController *)pageViewController
//{
//    // The selected item reflected in the page indicator.
//    return 0;
//}

- (void)handlePlayerHasLoadedASongNotification:(NSNotification *)n
{
    NSDictionary *userInfo = n.userInfo;
    BLYSong *loadedSong = userInfo[@"loadedSong"];
    
    // If song is loaded when player VC is not displayed
    if (self.tabBarController.selectedIndex != BLYBaseTabBarControllerPlayerIndex) {
        // Display player VC in page view controller
        [self loadInPageVCVC:self.playerVC animated:NO completion:nil];
    } else {
        // Previous song video choice VC is displayed ?
        // Back to player
        if ([self.selectedChildVC isKindOfClass:[self.currentSongVideosVC class]]
            && ![self.playerVC isCurrentSong:self.currentSongVideosVC.songForLoadedVideos]) {
            
            [self loadInPageVCVC:self.playerVC animated:NO completion:nil];
        }
    }
    
    if (self.loadedSongIsAVideo == [loadedSong.isVideo boolValue]) {
        return;
    }
    
    self.loadedSongIsAVideo = [loadedSong.isVideo boolValue];
    
    if (self.loadedSongIsAVideo) {
        self.navItemTitleView.pageControl.numberOfPages = 2;
        
        self.playerVC.currentPage = 0;
        self.discoveryVC.currentPage = 1;
    } else {
        self.navItemTitleView.pageControl.numberOfPages = 3;
        
        self.playerVC.currentPage = 1;
        self.discoveryVC.currentPage = 2;
    }
    
    [self.selectedChildVC synchronizePageControlCurrentPage];
    
    if (![self.selectedChildVC isKindOfClass:[self.currentSongVideosVC class]]
        || !self.loadedSongIsAVideo) {
        [self loadInPageVCVC:self.selectedChildVC animated:NO completion:nil];
    } else {
        // Song loaded is a video and previous song video choice VC is displayed
        // so go back to player VC
        [self loadInPageVCVC:self.playerVC animated:NO completion:nil];
    }
}

- (void)handlePlayerHasPlayedASongNotification:(NSNotification *)n
{
    // Reload page controller VCs
    self.pageController.dataSource = nil;
    self.pageController.dataSource = self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
