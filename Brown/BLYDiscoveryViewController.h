//
//  BLYDiscoveryViewController.h
//  Brown
//
//  Created by Jeremy Levy on 22/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BLYPlayerContainerChildVideoListViewController.h"

@class BLYPlayerViewController;

@interface BLYDiscoveryViewController : BLYPlayerContainerChildVideoListViewController

@property (weak, nonatomic) IBOutlet UILabel *loadingTextLabel;

@property (weak, nonatomic) IBOutlet UIView *errorView;
@property (weak, nonatomic) IBOutlet UILabel *errorViewLabel;
@property (weak, nonatomic) IBOutlet UIButton *errorRetryButton;

@property (weak, nonatomic) IBOutlet UIView *noResultsView;
@property (weak, nonatomic) IBOutlet UILabel *noResultsTextLabel;

@end
