//
//  BLYAppSettingsViewController.h
//  Brown
//
//  Created by Jeremy Levy on 30/10/2016.
//  Copyright © 2016 Jeremy Levy. All rights reserved.
//

#import "BLYBaseViewController.h"

@interface BLYAppSettingsViewController : BLYBaseViewController <UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *settings;

@end
