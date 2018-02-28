//
//  BLYAlbumListViewController.h
//  Brown
//
//  Created by Jeremy Levy on 28/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import "BLYPlaylistViewController.h"

@interface BLYAlbumListViewController : BLYPlaylistViewController <UICollectionViewDataSource, UICollectionViewDelegate>

@property (weak, nonatomic) IBOutlet UICollectionView *albumResults;
@property (strong, nonatomic) NSMutableArray *albums;

@property (nonatomic) BOOL albumHighLighted;
@property (nonatomic) BOOL albumHighLightedWhenDataWasReloaded;

@property (nonatomic) int nbOfAlbumsDisplayedPerPage;

@end
