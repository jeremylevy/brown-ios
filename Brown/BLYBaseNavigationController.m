//
//  BLYBaseNavigationController.m
//  Brown
//
//  Created by Jeremy Levy on 04/10/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import "BLYBaseNavigationController.h"
#import "BLYSearchSongViewController.h"

@interface BLYBaseNavigationController ()

@end

@implementation BLYBaseNavigationController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self) {
        // Custom initialization
        
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationBar.translucent = NO;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)shouldAutorotate
{
    return [self.visibleViewController shouldAutorotate];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return [self.visibleViewController supportedInterfaceOrientations];
}

- (BOOL)prefersStatusBarHidden
{
    return [self.visibleViewController prefersStatusBarHidden];
}

- (BOOL)prefersHomeIndicatorAutoHidden
{
    return [self.visibleViewController prefersHomeIndicatorAutoHidden];
}

@end
