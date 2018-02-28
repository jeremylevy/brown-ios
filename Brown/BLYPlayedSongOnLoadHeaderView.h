//
//  BLYPlayedSongOnLoadHeaderView.h
//  Brown
//
//  Created by Jeremy Levy on 28/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ExtendedNavBarView.h"

@interface BLYPlayedSongOnLoadHeaderView : ExtendedNavBarView

@property (weak, nonatomic) IBOutlet UIImageView *songThumbnail;
@property (weak, nonatomic) IBOutlet UILabel *songTitle;
@property (weak, nonatomic) IBOutlet UILabel *songArtist;
@property (weak, nonatomic) IBOutlet UIButton *resumePlaylistButton;
@property (weak, nonatomic) IBOutlet UIView *loadingView;

@end
