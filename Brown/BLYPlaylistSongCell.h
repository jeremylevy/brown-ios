//
//  BLYExternalTopSongCell.h
//  Brown
//
//  Created by Jeremy Levy on 20/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BLYPlaylistSongCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *rank;
@property (weak, nonatomic) IBOutlet UIImageView *thumbnail;
@property (weak, nonatomic) IBOutlet UIImageView *thumbnailOverlay;
@property (weak, nonatomic) IBOutlet UILabel *title;
@property (weak, nonatomic) IBOutlet UILabel *artist;
@property (weak, nonatomic) IBOutlet UILabel *duration;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *loader;
@property (weak, nonatomic) IBOutlet UIImageView *playIcon;
@property (weak, nonatomic) IBOutlet UIImageView *pauseIcon;
@property (nonatomic) BOOL containsCurrentSong;
@property (weak, nonatomic) IBOutlet UIPageControl *cachedIndicator;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *cachingActivityIndicator;
@property (weak, nonatomic) IBOutlet UIProgressView *cachingProgressView;

@end
