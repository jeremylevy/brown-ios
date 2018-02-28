//
//  BLYAlbum+Thumbnail.m
//  Brown
//
//  Created by Jeremy Levy on 25/11/2013.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <objc/runtime.h>
#import "BLYAlbum+Thumbnail.h"
#import "BLYSongStore.h"
#import "BLYAlbumThumbnail.h"
#import "BLYSongStore.h"

NSString * const BLYAlbumThumbnailDidRedownloadNotification = @"BLYAlbumThumbnailDidRedownloadNotification";

@implementation BLYAlbum (Thumbnail)

- (NSNumber *)thumbnailIsDownloading
{
    return objc_getAssociatedObject(self, @selector(thumbnailIsDownloading));
}

- (void)setThumbnailIsDownloading:(NSNumber *)thumbnailIsDownloading
{
    objc_setAssociatedObject(self, @selector(thumbnailIsDownloading), thumbnailIsDownloading, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BLYAlbumThumbnail *)smallThumbnail
{
    for (BLYAlbumThumbnail *thumb in self.thumbnails) {
        if ([thumb.size isEqualToString:@"225x225"]) {
            return thumb;
        }
    }
    
    return nil;
}

- (UIImage *)smallThumbnailAsImg
{
    BLYAlbumThumbnail *smallThumb = [self smallThumbnail];
    __weak BLYAlbum *weakSelf = self;
    
    if (!smallThumb) {
        return nil;
    }
    
    if (!smallThumb.data && ![self.thumbnailIsDownloading boolValue]) {
        [[BLYSongStore sharedStore] loadThumbnail:smallThumb withCompletionBlock:^(BOOL completed) {
            if (!completed) {
                return;
            }
            
            [[NSNotificationCenter defaultCenter] postNotificationName:BLYAlbumThumbnailDidRedownloadNotification object:weakSelf];
        }];
    }
    
    return [UIImage imageWithData:smallThumb.data];
}

- (UIImage *)largeThumbnailAsImg
{
    BLYAlbumThumbnail *largeThumb = [self largeThumbnail];
    
    if (!largeThumb) {
        return nil;
    }
    
    return [UIImage imageWithData:largeThumb.data];
}

- (BLYAlbumThumbnail *)largeThumbnail
{
    for (BLYAlbumThumbnail *thumb in self.thumbnails) {
        if ([thumb.size isEqualToString:@"600x600"] && thumb.data) {
            return thumb;
        }
    }
    
    return nil;
}

//- (UIImage *)thumbnail
//{
//    __weak BLYAlbum *weakSelf = self;
//    
////    if (!self.privateThumbnail.data && ![self.thumbnailIsDownloading boolValue]) {
////        self.thumbnailIsDownloading = [NSNumber numberWithBool:YES];
////        
////        [[BLYSongStore sharedStore] loadThumbnailWithURL:[NSURL URLWithString: self.privateThumbnail.url]
////                                                forAlbum:self
////                                     withCompletionBlock:^{
////            
////                                         weakSelf.thumbnailIsDownloading = [NSNumber numberWithBool:NO];
////        }];
////    }
//    
//    return [UIImage imageWithData:self.privateThumbnail.data];
//}

@end
