//
//  BLYCurrentSongVideoChoiceViewController.h
//  Brown
//
//  Created by Jeremy Levy on 26/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import "BLYPlayerContainerChildVideoListViewController.h"

@interface BLYCurrentSongVideoChoiceViewController : BLYPlayerContainerChildVideoListViewController

@property (weak, nonatomic) IBOutlet UILabel *loadingTextLabel;
@property (weak, nonatomic) IBOutlet UIView *errorView;
@property (weak, nonatomic) IBOutlet UILabel *errorViewLabel;
@property (weak, nonatomic) IBOutlet UIButton *errorRetryButton;

@property (strong, nonatomic) BLYSong *songForLoadedVideos;

@end
