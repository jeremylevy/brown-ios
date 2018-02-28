//
//  BLYAlbumHeaderInfoView.h
//  Brown
//
//  Created by Jeremy Levy on 06/10/2016.
//  Copyright © 2016 Jeremy Levy. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ExtendedNavBarView.h"

@interface BLYAlbumHeaderInfoView : ExtendedNavBarView

@property (weak, nonatomic) IBOutlet UISwitch *cacheSwitch;
@property (weak, nonatomic) IBOutlet UILabel *downloadLabel;
@property (weak, nonatomic) IBOutlet UILabel *trackNbLabel;
@property (strong, nonatomic) BLYAlbumHeaderInfoView *realView;


@end
