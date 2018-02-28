//
//  BLYAlbumListViewController.m
//  Brown
//
//  Created by Jeremy Levy on 28/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import "BLYAlbumListViewController.h"
#import "BLYAlbum.h"
#import "BLYAlbum+Thumbnail.h"
#import "BLYAlbumViewController.h"
#import "BLYAlbumCell.h"
#import "BLYPlayedAlbumCell.h"
#import "BLYSearchSongResultsViewController.h"
#import "BLYCachedSongStore.h"

@interface BLYAlbumListViewController ()

@end

@implementation BLYAlbumListViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self) {
        // Custom initialization
        _albums = [[NSMutableArray alloc] init];
        
        _albumHighLighted = NO;
        _albumHighLightedWhenDataWasReloaded = NO;
        
        _nbOfAlbumsDisplayedPerPage = 3;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleAlbumWasCached:)
                                                     name:BLYCachedSongStoreDidCacheAlbum
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleAlbumWasUncached:)
                                                     name:BLYCachedSongStoreDidUncacheAlbum
                                                   object:nil];
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Do any additional setup after loading the view from its nib.
    UINib *nib = [UINib nibWithNibName:@"BLYAlbumCell" bundle:nil];
    
    // Register this NIB which contains the cell
    [self.albumResults registerNib:nib
        forCellWithReuseIdentifier:@"BLYAlbumCell"];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section
{
    return [self.albums count];
    
    if ([self isKindOfClass:[BLYSearchSongResultsViewController class]]) {
        return [self.albums count];
    }
    
    return MAX(_nbOfAlbumsDisplayedPerPage, [self.albums count]);
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [self.albumResults dequeueReusableCellWithReuseIdentifier:@"BLYAlbumCell"
                                                                              forIndexPath:indexPath];
    CGFloat w = ([UIScreen mainScreen].nativeBounds.size.width / [UIScreen mainScreen].nativeScale) - (4 * 14.0);
    if (indexPath.row < [self.albums count]) {
        BLYAlbum *album = [self.albums objectAtIndex:indexPath.row];
        NSString *releaseDateString = [NSDateFormatter localizedStringFromDate:album.releaseDate
                                                                     dateStyle:NSDateFormatterMediumStyle
                                                                     timeStyle:NSDateFormatterNoStyle];
        
        if ([cell isKindOfClass:[BLYAlbumCell class]]) {
            ((BLYAlbumCell *)cell).albumName.text = album.name;
            ((BLYAlbumCell *)cell).albumReleaseDate.text = releaseDateString;
            ((BLYAlbumCell *)cell).albumThumbnail.layer.cornerRadius = (w / _nbOfAlbumsDisplayedPerPage) / 2.0;
            ((BLYAlbumCell *)cell).albumThumbnail.layer.masksToBounds = YES;
            ((BLYAlbumCell *)cell).albumThumbnail.image = [album smallThumbnailAsImg];
        }
        
        if ([cell isKindOfClass:[BLYPlayedAlbumCell class]]) {
            ((BLYPlayedAlbumCell *)cell).backgroundColor = [UIColor whiteColor];
            ((BLYPlayedAlbumCell *)cell).albumThumbnail.image = [album smallThumbnailAsImg];
            ((BLYPlayedAlbumCell *)cell).albumThumbnail.layer.cornerRadius = (w / _nbOfAlbumsDisplayedPerPage) / 2;
            ((BLYPlayedAlbumCell *)cell).albumThumbnail.layer.masksToBounds = YES;
            ((BLYPlayedAlbumCell *)cell).cachedIndicator.hidden = ![album.isCached boolValue];
        }
        
        cell.alpha = 1.0;
        
        return cell;
    }
    
    ((BLYPlayedAlbumCell *)cell).albumThumbnail.image = nil;
    ((BLYPlayedAlbumCell *)cell).cachedIndicator.hidden = YES;
    ((BLYPlayedAlbumCell *)cell).layer.cornerRadius = (w / _nbOfAlbumsDisplayedPerPage) / 2;
    ((BLYPlayedAlbumCell *)cell).layer.masksToBounds = YES;
    ((BLYPlayedAlbumCell *)cell).backgroundColor = [UIColor colorWithWhite:0.97 alpha:1.0];
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didHighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    
    self.albumHighLighted = YES;
    
    cell.alpha = 0.6;
}

- (void)collectionView:(UICollectionView *)collectionView didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    
    self.albumHighLighted = NO;
    
    cell.alpha = 1.0;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row >= [self.albums count]) {
        return;
    }
    
    BLYAlbum *selectedAlbum = [self.albums objectAtIndex:indexPath.row];
    BLYAlbumViewController *albumVC = [[BLYAlbumViewController alloc] init];
    
    if (self.albumHighLightedWhenDataWasReloaded) {
        self.albumHighLightedWhenDataWasReloaded = NO;
        
        [self.albumResults reloadData];
    }
    
    albumVC.loadedAlbumSid = selectedAlbum.sid;
    albumVC.playerVC = self.playerVC;
    
    if ([self isKindOfClass:[BLYSearchSongResultsViewController class]]) {
        albumVC.searchSongVC = ((BLYSearchSongResultsViewController *)self).searchSongVC;
        albumVC.searchSongResultsVC = (BLYSearchSongResultsViewController *)self;
    }
    
    albumVC.searchSongResultsLastSelectedAlbum = indexPath.row;
    
    [self.navigationController pushViewController:albumVC animated:YES];
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
//    return CGSizeMake(80.0, 115.0);
//
//    if ([self isKindOfClass:[BLYSearchSongResultsViewController class]]) {
//        return CGSizeMake(80.0, 115.0);
//    }
    
    // Remove space between cells
    // This rectangle is based on the device in a portrait-up orientation.
    // This value does not change as the device rotates.
    CGFloat w = ([UIScreen mainScreen].nativeBounds.size.width / [UIScreen mainScreen].nativeScale) - (4 * 14.0);
    CGFloat width = (w / _nbOfAlbumsDisplayedPerPage);
    CGFloat height = 115.0;
    
    if (width > 80.0) {
        float ratio = (width / 80.0);
        
        height = (80.0 * ratio) + (115.0 - 80.0);
    } else {
        return CGSizeMake(80.0, 115.0);
    }
    
    return CGSizeMake(width, height);
}

- (void)handleAlbumWasCached:(NSNotification *)n
{
    [self.albumResults reloadData];
}

- (void)handleAlbumWasUncached:(NSNotification *)n
{
    [self.albumResults reloadData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)dealloc
{
    // Avoid err_bad_excess when pop this view controller
    self.albumResults.delegate = nil;
    self.albumResults.dataSource = nil;
}

@end
