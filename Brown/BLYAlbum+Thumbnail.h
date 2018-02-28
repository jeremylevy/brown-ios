//
//  BLYAlbum+Thumbnail.h
//  Brown
//
//  Created by Jeremy Levy on 25/11/2013.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import "BLYAlbum.h"

extern NSString * const BLYAlbumThumbnailDidRedownloadNotification;

@interface BLYAlbum (Thumbnail)

@property (strong, nonatomic) NSNumber * thumbnailIsDownloading;

- (BLYAlbumThumbnail *)largeThumbnail;
- (BLYAlbumThumbnail *)smallThumbnail;

- (UIImage *)smallThumbnailAsImg;
- (UIImage *)largeThumbnailAsImg;

@end
