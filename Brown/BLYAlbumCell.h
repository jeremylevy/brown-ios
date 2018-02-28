//
//  BLYSearchSongResultsAlbumCell.h
//  Brown
//
//  Created by Jeremy Levy on 02/10/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BLYAlbumCell : UICollectionViewCell

@property (weak, nonatomic) IBOutlet UIImageView *albumThumbnail;
@property (weak, nonatomic) IBOutlet UILabel *albumName;
@property (weak, nonatomic) IBOutlet UILabel *albumReleaseDate;

@end
