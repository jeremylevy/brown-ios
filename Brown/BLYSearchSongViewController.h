//
//  BLYSearchSongsViewController.h
//  Brown
//
//  Created by Jeremy Levy on 19/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BLYBaseViewController.h"

@class BLYSearchSongAutocompleteResults;
@class BLYPlayerViewController;

@interface BLYSearchSongViewController : BLYBaseViewController <UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate>

@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;
@property (weak, nonatomic) IBOutlet UIView *searchResultsListBackgroundView;
@property (weak, nonatomic) IBOutlet UITableView *searchResultsList;
@property (strong, nonatomic) BLYSearchSongAutocompleteResults *searchResults;
@property (nonatomic) BOOL keyboardIsDisplayed;
@property (nonatomic) BOOL searchBarEmptiedBySearchResultsVC;
@property (nonatomic) BOOL songSelectedInSearchResultsVC;
@property (nonatomic) BOOL displayedByPopingSearchResultsVC;

// Player vc is set in App delegate
@property (strong, nonatomic) BLYPlayerViewController *playerVC;

- (BOOL)searchBarIsEmpty;
- (void)dismissSearchBar:(UIGestureRecognizer *)gr;

@end
