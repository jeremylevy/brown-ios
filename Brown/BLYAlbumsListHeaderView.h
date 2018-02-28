//
//  BLYAlbumsListHeaderView.h
//  Brown
//
//  Created by Jeremy Levy on 28/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ExtendedNavBarView.h"

@interface BLYAlbumsListHeaderView : UIView

@property (weak, nonatomic) IBOutlet UICollectionView *albums;
@property (weak, nonatomic) IBOutlet UILabel *albumsLoadingLabel;

@end
