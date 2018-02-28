//
//  BLYPlayerContainerChildViewController.m
//  Brown
//
//  Created by Jeremy Levy on 23/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import "BLYPlayerContainerChildViewController.h"
#import "NSString+Sizing.h"
#import "BLYPlayerViewController.h"

@interface BLYPlayerContainerChildViewController ()

@end

@implementation BLYPlayerContainerChildViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self) {
        
    }
    
    return self;
}

- (void)setNavItemTitle:(NSString *)navItemTitle
{
    _navItemTitle = navItemTitle;
    
    if (self.containerVC.selectedChildVC == self) {
        self.containerVC.navItemTitleView.title.text = navItemTitle;
    }
}

- (void)synchronizePageControlCurrentPage
{
    self.containerVC.navItemTitleView.pageControl.currentPage = self.currentPage;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.containerVC.navItemTitleView.title.text = self.navItemTitle;
    
    [self synchronizePageControlCurrentPage];
    
    self.containerVC.selectedChildVC = self;
    
    if (!self.containerVC.playerVC.currentSong) {
        return;
    }
    
    BOOL isPlayerVC = [self isKindOfClass:[BLYPlayerViewController class]];
    
    [self.containerVC.playerVC updateNavLeftButtonTitleForSong:self.containerVC.playerVC.currentSong
                                                       orTitle:isPlayerVC ? nil : self.navItemTitle];
    
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    
    // We want system volume HUD to be displayed
    // when player volume slider not displayed
    if (isPlayerVC) {
        self.containerVC.playerVC.volumeSlider.hidden = NO;
    }
    
    // self.containerVC.playerVC.volumeSlider.hidden = !isPlayerVC;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    BOOL isPlayerVC = [self isKindOfClass:[BLYPlayerViewController class]];
    
    // We want system volume HUD to be displayed
    // when player volume slider not displayed
    self.containerVC.playerVC.volumeSlider.hidden = !isPlayerVC;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

@end
