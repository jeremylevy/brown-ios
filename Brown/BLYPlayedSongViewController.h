//
//  BLYPlayedSongsHistoryViewController.h
//  Brown
//
//  Created by Jeremy Levy on 19/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BLYAlbumListViewController.h"
#import "BLYPlayedSongOnLoadHeaderView.h"

@interface BLYPlayedSongViewController : BLYAlbumListViewController <UICollectionViewDelegate, UICollectionViewDataSource, UITableViewDelegate>

@property (weak, nonatomic) IBOutlet UISegmentedControl *historyTypeChoiceSegmentedControl;
@property (weak, nonatomic) IBOutlet ExtendedNavBarView *historyTypeChoiceView;
@property (weak, nonatomic) IBOutlet BLYPlayedSongOnLoadHeaderView *onloadHeaderView;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *songsListTopConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *albumsListTopConstraint;

@end
