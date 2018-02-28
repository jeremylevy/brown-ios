//
//  BLYAlbumViewController.h
//  Brown
//
//  Created by Jeremy Levy on 02/10/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BLYPlaylistViewController.h"

@class BLYAlbumHeaderInfoView, BLYSearchSongResultsViewController, BLYSearchSongViewController;

@interface BLYAlbumViewController : BLYPlaylistViewController

@property (weak, nonatomic) IBOutlet UIView *songsListContainer;
@property (weak, nonatomic) IBOutlet BLYAlbumHeaderInfoView *headerView;

@property (strong, nonatomic) NSNumber *loadedAlbumSid;
@property (weak, nonatomic) BLYSearchSongViewController *searchSongVC;

@property (weak, nonatomic) BLYSearchSongResultsViewController *searchSongResultsVC;
@property (nonatomic) NSInteger searchSongResultsLastSelectedAlbum;

@property (weak, nonatomic) IBOutlet UIView *errorView;
@property (weak, nonatomic) IBOutlet UILabel *errorViewLabel;
@property (weak, nonatomic) IBOutlet UIButton *errorRetryButton;

@property (weak, nonatomic) IBOutlet UILabel *loadingTextLabel;

@end
