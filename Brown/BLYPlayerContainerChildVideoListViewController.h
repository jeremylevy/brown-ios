//
//  BLYVideoListViewController.h
//  Brown
//
//  Created by Jeremy Levy on 26/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BLYTimeManager.h"
#import "BLYPlaylist.h"
#import "BLYPlayerViewController.h"
#import "BLYPlayerContainerChildViewController.h"

@interface BLYPlayerContainerChildVideoListViewController : BLYPlayerContainerChildViewController <UICollectionViewDataSource, UICollectionViewDelegate>

@property (weak, nonatomic) IBOutlet UICollectionView *videosList;
@property (weak, nonatomic) BLYPlayerViewController *playerVC;
@property (strong, nonatomic) BLYPlaylist *videos;
@property (nonatomic) BOOL videoHighLighted;
@property (nonatomic) BOOL videoHighLightedWhenDataWasReloaded;
@property (strong, nonatomic) BLYTimeManager *timeManager;
@property (nonatomic) BLYPlayerViewControllerPlayerStatus playerStatusForLastNotification;

- (void)handlePlayerHasLoadedASongNotification:(NSNotification *)n;
- (void)handlePlayerHasPlayedASongNotification:(NSNotification *)n;
- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)isCurrentSongForVideoChoice:(BLYSong *)s;

@end
