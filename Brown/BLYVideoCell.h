//
//  BLYDiscoveryRelatedVideoCell.h
//  Brown
//
//  Created by Jeremy Levy on 22/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BLYVideoCell : UICollectionViewCell

@property (weak, nonatomic) IBOutlet UIImageView *videoThumbnail;
@property (weak, nonatomic) IBOutlet UILabel *videoTitle;
@property (weak, nonatomic) IBOutlet UILabel *duration;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *loadIndicator;
@property (weak, nonatomic) IBOutlet UIPageControl *playIndicator;

@end
