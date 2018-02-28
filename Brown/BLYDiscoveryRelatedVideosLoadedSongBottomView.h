//
//  BLYDiscoveryRelatedVideosLoadedSongBottomView.h
//  Brown
//
//  Created by Jeremy Levy on 26/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BLYDiscoveryRelatedVideosLoadedSongBottomView : UICollectionReusableView

@property (weak, nonatomic) IBOutlet UIImageView *thumbnail;
@property (weak, nonatomic) IBOutlet UILabel *title;
@property (weak, nonatomic) IBOutlet UILabel *artist;
@property (weak, nonatomic) IBOutlet UILabel *duration;
@property (weak, nonatomic) IBOutlet UIButton *loadSongButton;

@end
