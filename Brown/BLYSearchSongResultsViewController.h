//
//  BLYSearchSongResultsViewController.h
//  Brown
//
//  Created by Jeremy Levy on 01/10/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BLYAlbumListViewController.h"

@class BLYArtistSong, BLYSearchSongViewController;

extern float BLYSearchSongResultsViewControllerDisabledAlbumCellsOpacity;
extern const int BLYSearchSongResultsViewControllerTracksSegment;
extern const int BLYSearchSongResultsViewControllerAlbumsSegment;
extern const int BLYSearchSongResultsViewControllerVideosSegment;

@interface BLYSearchSongResultsViewController : BLYAlbumListViewController

@property (strong, nonatomic) NSString *currentSearch;
@property (strong, nonatomic) BLYArtistSong *currentSearchedArtist;
@property (weak, nonatomic) BLYSearchSongViewController *searchSongVC;
@property (weak, nonatomic) IBOutlet UIView *resultsContainer;
@property (weak, nonatomic) IBOutlet UIView *noResultsView;
@property (weak, nonatomic) IBOutlet UIView *errorView;
@property (weak, nonatomic) IBOutlet UILabel *errorViewLabel;
@property (weak, nonatomic) IBOutlet UIButton *errorRetryButton;
@property (weak, nonatomic) IBOutlet UISegmentedControl *resultsTypeSegmentedControl;
@property (strong, nonatomic) NSMutableArray *videos;
@property (weak, nonatomic) IBOutlet UILabel *loadingTextLabel;
@property (weak, nonatomic) IBOutlet UILabel *noResultsTextLabel;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *resultsContainerTopConstraint;

- (IBAction)changeResultsType:(id)sender;
- (void)updateSearchSongLastSelectedSegmentAndSelectedAlbumIndex:(NSInteger)index;
- (void)handleSongHasBeenChosen:(BLYSong *)song andItsCurrentSong:(BOOL)itsCurrentSong;

@end
