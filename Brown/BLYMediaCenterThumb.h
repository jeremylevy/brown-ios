//
//  BLYMediaCenterThumb.h
//  Brown
//
//  Created by Jeremy Levy on 30/01/2018.
//  Copyright © 2018 Jeremy Levy. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "THLabel.h"

@interface BLYMediaCenterThumb : UIView

@property (weak, nonatomic) IBOutlet UIImageView *thumb;
@property (weak, nonatomic) IBOutlet THLabel *rankLabel;

@end
