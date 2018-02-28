//
//  BLYAppSettingsSettingCell.h
//  Brown
//
//  Created by Jeremy Levy on 01/11/2016.
//  Copyright © 2016 Jeremy Levy. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BLYAppSettingsSettingCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *settingDescriptionLabel;
@property (weak, nonatomic) IBOutlet UISwitch *settingSwitch;

@end
