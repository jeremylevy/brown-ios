//
//  BLYCurrentSongVideoChoiceViewController.m
//  Brown
//
//  Created by Jeremy Levy on 26/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import "BLYCurrentSongVideoChoiceViewController.h"
#import "BLYAppDelegate.h"
#import "BLYVideoStore.h"
#import "BLYSong.h"
#import "BLYSongStore.h"
#import "BLYCurrentSongVideoChoiceFooterView.h"

@interface BLYCurrentSongVideoChoiceViewController ()

@property (strong, nonatomic) BLYPlaylist *reorderedVideosPlaylist;

@end

@implementation BLYCurrentSongVideoChoiceViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self) {
        // Custom initialization
        self.navItemTitle = NSLocalizedString(@"current_song_video_choice_navigation_item_title", nil);
        self.currentPage = 0;
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Do any additional setup after loading the view from its nib.
    self.loadingTextLabel.text = NSLocalizedString(@"view_controller_main_loading_text", nil);
    
    [self.errorRetryButton setTitle:NSLocalizedString(@"error_retry_button", nil)
                           forState:UIControlStateNormal];
    
    self.errorRetryButton.layer.borderWidth = 0.0;
    self.errorRetryButton.layer.cornerRadius = 14.5;
    
    self.errorRetryButton.layer.borderColor = [UIColor grayColor].CGColor;
    self.errorRetryButton.tintColor = [UIColor grayColor];
    
    [_errorRetryButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_errorRetryButton setBackgroundColor:[UIColor colorWithWhite:0.4 alpha:1.0]];
    
    [self.errorRetryButton addTarget:self
                              action:@selector(retryLoading:)
                    forControlEvents:UIControlEventTouchUpInside];
    
    UINib *footerNib = [UINib nibWithNibName:@"BLYCurrentSongVideoChoiceFooter" bundle:nil];
    
    [self.videosList registerNib:footerNib forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"footer"];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (!self.songForLoadedVideos
        || ![self.playerVC isCurrentSong:self.songForLoadedVideos]) {
        
        [self loadVideosForCurrentSong];
    }
}

- (void)retryLoading:(UIButton *)button
{
    _errorView.hidden = YES;
    
    [self loadVideosForCurrentSong];
}

- (void)loadVideosForCurrentSong
{
    self.videosList.hidden = YES;
    self.errorView.hidden = YES;
    
    BLYAppDelegate *appDelegate = (BLYAppDelegate *)(BLYAppDelegate *)[[UIApplication sharedApplication] delegate];
    NSString *country = [appDelegate countryCodeForCurrentLocale];
    __weak BLYCurrentSongVideoChoiceViewController *weakSelf = self;
    
    void(^completion)(BLYPlaylist *, NSError *) = ^(BLYPlaylist *playlist, NSError *err){
        if (err) {
            weakSelf.songForLoadedVideos = nil;
            
            weakSelf.errorViewLabel.text = err.localizedDescription;
            weakSelf.errorView.hidden = NO;
            
            return;
        }
        
        weakSelf.videos = playlist;
        
        [weakSelf.videosList reloadData];
        
        // Scroll to top
        [weakSelf.videosList setContentOffset:CGPointZero
                                     animated:NO];
        
        // Make sure to hide error view in case it was displayed before
        weakSelf.errorView.hidden = YES;
        weakSelf.videosList.hidden = NO;
    };
    void (^completionForImg)(BOOL hasDownloaded, BLYSong *song) = ^(BOOL hasDownloaded, BLYSong *song){
        if (weakSelf.videoHighLighted) {
            weakSelf.videoHighLightedWhenDataWasReloaded = YES;
            
            return;
        }
        
        if (!hasDownloaded) {
            return;
        }
        
        [weakSelf.videosList reloadData];
    };
    
    // Make sure to set this before store call in order to prevent completion to be called before
    self.songForLoadedVideos = self.playerVC.currentSong;
    
    NSOrderedSet *videos = self.playerVC.currentSong.videos;
    
    [[BLYVideoStore sharedStore] lookupVideosWithIDs:[videos array]
                                          forCountry:country
                                      withCompletion:completion
                                 andCompletionForImg:completionForImg];
}

- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    // Call super before update song videos
    [super collectionView:collectionView
 didSelectItemAtIndexPath:indexPath];
    
    NSMutableOrderedSet *videos = [self.playerVC.currentSong.videos mutableCopy];
    
    BLYVideoSong *videoSongToSetInFirst = [videos objectAtIndex:indexPath.row];
    BLYVideoSong *videoSongToSetInLast = [videos objectAtIndex:0];
    
    BLYSong *songToReplaceCurrentSongBy = [self.videos songAtIndex:indexPath.row];
    BLYSong *currentSong = [self.videos songAtIndex:0];
    
    // Current song selected
    if (songToReplaceCurrentSongBy == currentSong) {
        
        // Try to reload song
        if (self.playerVC.playerStatus == BLYPlayerViewControllerPlayerStatusError) {
            [self.playerVC loadPlaylist:self.playerVC.playlist
                       andStartWithSong:self.playerVC.currentSong
                            askedByUser:YES];
        }
        
        return;
    }
    
    [videos removeObjectAtIndex:indexPath.row];
    
    [videos replaceObjectAtIndex:0
                      withObject:videoSongToSetInFirst];
    
    [videos addObject:videoSongToSetInLast];
    
    self.reorderedVideosPlaylist = [self.videos copy];
    
    [self.reorderedVideosPlaylist replaceSongAtIndex:0
                                      withSong:songToReplaceCurrentSongBy];
    [self.reorderedVideosPlaylist removeSongAtIndex:indexPath.row];
    
    [self.reorderedVideosPlaylist addSong:currentSong];
    
    [[BLYVideoStore sharedStore] removeVideosForSong:self.playerVC.currentSong];
    
    [[BLYVideoStore sharedStore] setVideos:[videos copy]
                                   forSong:self.playerVC.currentSong];
    
    [[BLYSongStore sharedStore] setVideosReordered:YES
                                           forSong:self.playerVC.currentSong];
    
    [[BLYVideoStore sharedStore] removeRelatedSongsOfSong:self.playerVC.currentSong];
    
    self.videos = self.reorderedVideosPlaylist;
    self.reorderedVideosPlaylist = nil;
    
    [self.playerVC loadPlaylist:self.playerVC.playlist
               andStartWithSong:self.playerVC.currentSong
                    askedByUser:YES];
    
    [self.videosList reloadData];
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    BLYCurrentSongVideoChoiceFooterView *footerView = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"footer" forIndexPath:indexPath];
    
    footerView.mainLabel.text = NSLocalizedString(@"current_song_video_choice_footer_text", nil);
    
    return footerView;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section {
    
    return CGSizeMake(collectionView.bounds.size.width, 60.0);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
