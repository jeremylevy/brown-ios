//
//  BLYPlayerContainerChildViewController.h
//  Brown
//
//  Created by Jeremy Levy on 23/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import "BLYBaseViewController.h"
#import "BLYPlayerContainerViewController.h"

@interface BLYPlayerContainerChildViewController : BLYBaseViewController

@property (weak, nonatomic) BLYPlayerContainerViewController *containerVC;
@property (strong, nonatomic) NSString *navItemTitle;
@property (nonatomic) NSInteger currentPage;

- (void)synchronizePageControlCurrentPage;

@end
