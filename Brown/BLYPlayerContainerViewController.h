//
//  BLYPlayerContainerViewController.h
//  Brown
//
//  Created by Jeremy Levy on 23/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BLYBaseViewController.h"
#import "BLYPlayerNavItemTitleView.h"

extern NSString * const BLYPlayerContainerViewControllerDidChangeViewController;

@class BLYPlayerViewController, BLYPlayerContainerChildViewController;

@interface BLYPlayerContainerViewController : BLYBaseViewController <UIPageViewControllerDataSource, UIPageViewControllerDelegate>

@property (strong, nonatomic) UIPageViewController *pageController;

@property (weak, nonatomic) BLYPlayerViewController *playerVC;
@property (weak, nonatomic) BLYPlayerNavItemTitleView *navItemTitleView;
@property (weak, nonatomic) BLYPlayerContainerChildViewController *selectedChildVC;
@property (nonatomic) BOOL loadedSongIsAVideo;

- (void)loadInPageVCVC:(UIViewController *)vc
              animated:(BOOL)animated
            completion:(void (^)(BOOL finished))completion;

@end
