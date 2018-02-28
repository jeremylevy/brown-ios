//
//  BLYSearchSongsViewController.m
//  Brown
//
//  Created by Jeremy Levy on 19/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import "BLYSearchSongViewController.h"
#import "BLYSearchSongAutocompleteResult.h"
#import "BLYSearchSongAutocompleteResults.h"
#import "BLYSearchSongAutocompleteResultsStore.h"
#import "BLYSearchSongResultsViewController.h"
#import "BLYSearchSongsStore.h"
#import "BLYSearchSong.h"
#import "BLYTrendingSearchStore.h"
#import "BLYAlbumViewController.h"
#import "BLYAlbum.h"
#import "BLYErrorStore.h"
#import "BLYAppDelegate.h"
#import "BLYNavSearchBarContainerView.h"

@interface BLYSearchSongViewController ()

@property (nonatomic) float searchResultsListHeight;
@property (strong, nonatomic) UITapGestureRecognizer *searchResultsListTapGR;
@property (strong, nonatomic) NSNotification *keyboardAppearNotification;
@property (strong, nonatomic) NSString *currentSearch;
@property (nonatomic) BOOL historyDisplayed;
@property (nonatomic) BOOL trendingSearchesDisplayed;

@end

@implementation BLYSearchSongViewController

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil
                           bundle:nibBundleOrNil];
    
    if (self) {
        UIImage *externalTopSongsTabBarIcon = [UIImage imageNamed:@"SearchTabBarIcon"];
        UIImage *externalTopSongsSelectedTabBarIcon = [UIImage imageNamed:@"SearchSelectedTabBarIcon"];
        
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@""
                                                        image:externalTopSongsTabBarIcon
                                                selectedImage:externalTopSongsSelectedTabBarIcon];
        
        UISearchBar *searchBar = [[UISearchBar alloc] init];
        
        searchBar.placeholder = NSLocalizedString(@"search_song_search_bar_placeholder", nil);
        searchBar.delegate = self;
        
        searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
        searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
        
        searchBar.keyboardType = UIKeyboardTypeDefault;
        searchBar.returnKeyType = UIReturnKeySearch;
        
        self.navigationItem.title = NSLocalizedString(@"search_song_navigation_item_title", nil);
        self.navigationItem.titleView = searchBar;
        
        self.searchBar = searchBar;
        
        self.searchResults = [[BLYSearchSongAutocompleteResults alloc] init];
        self.searchResultsListTapGR = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                              action:@selector(dismissSearchBar:)];
        
        
        self.historyDisplayed = NO;
        self.trendingSearchesDisplayed = NO;
        
        self.searchBarEmptiedBySearchResultsVC = NO;
        self.songSelectedInSearchResultsVC = NO;
        self.displayedByPopingSearchResultsVC = NO;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleKeyboardAppear:)
                                                     name:UIKeyboardDidShowNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleKeyboardDisappear:)
                                                     name:UIKeyboardDidHideNotification
                                                   object:nil];
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.searchResultsList addGestureRecognizer:self.searchResultsListTapGR];
    
    self.searchResultsListHeight = self.searchResultsList.frame.size.height;
    
    [self loadSearchedSongsHistory];
    
    self.searchResultsList.rowHeight = 56;
    
    UITextField *txfSearchField = [self.searchBar valueForKey:@"_searchField"];
    
    txfSearchField.backgroundColor = [UIColor colorWithWhite:0.94 alpha:1.0];
    txfSearchField.textColor = [UIColor blackColor];
    
    txfSearchField.layer.cornerRadius = 13.0;
    txfSearchField.layer.masksToBounds = YES;
    
    [self.searchBar setTintColor:[UIColor blackColor]];
    
    if (@available(iOS 11.0, *)) {
        txfSearchField.font = [UIFont systemFontOfSize:14.4];
        //[self.searchBar.heightAnchor constraintEqualToConstant:44.0].active = true;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // Resize autocomplete results table view
//    if (![self searchBarIsEmpty] && self.keyboardAppearNotification) {
//        [self handleKeyboardAppear:self.keyboardAppearNotification];
//    }
    
    if (![self searchBarIsEmpty]) {
        [self.searchBar becomeFirstResponder];
        
        // Update search type after search load
        //[self.searchResultsList reloadData];
    } else if (self.searchBarEmptiedBySearchResultsVC) {
        self.searchBarEmptiedBySearchResultsVC = NO;
        
        [self.searchBar becomeFirstResponder];
    } else if (_trendingSearchesDisplayed && self.displayedByPopingSearchResultsVC) {
        [self.searchBar becomeFirstResponder];
    }
    
    self.displayedByPopingSearchResultsVC = NO;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Reorder search after user has selected
    // a song in search results VC
    if (self.songSelectedInSearchResultsVC) {
        self.songSelectedInSearchResultsVC = NO;
        
        if (!_trendingSearchesDisplayed && !self.searchBarEmptiedBySearchResultsVC) {
            [self loadSearchedSongsHistory];
        }
    }
    
    if (_searchBarEmptiedBySearchResultsVC) {
        [self loadTrendingSearches];
    }
    
//    if (![self searchBarIsEmpty]) {
//        [self.searchBar becomeFirstResponder];
//
//        // Update search type after search load
//        [self.searchResultsList reloadData];
//    }
    
    // Make sure to reset nav bar when coming from search results
    [self extendedNavigationBar];
    
    // Fix https://stackoverflow.com/a/47976999
    if (@available(iOS 11.0, *)) {
        [self.navigationController.view layoutSubviews];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // Fix https://stackoverflow.com/a/47976999
    if (@available(iOS 11.0, *)) {
        [self.navigationController.view layoutSubviews];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)searchBarIsEmpty
{
    NSString *searchBarContent = self.searchBar.text;
    
    return [searchBarContent isEqualToString:@""];
}

- (void)loadSearchedSongsHistory
{
    BLYSearchSongAutocompleteResults *results = [[BLYSearchSongsStore sharedStore] fetchSearchSongs];
    
    self.historyDisplayed = [results nbOfResults] > 0;
    
    if (!_historyDisplayed) {
        [self loadTrendingSearches];
        
        return;
    }
    
    [self setSearchResults:results];
    
    if (_historyDisplayed && _trendingSearchesDisplayed) {
        _trendingSearchesDisplayed = NO;
    }
    
    [self.searchResultsList reloadData];
    
    if ([self.searchResultsList numberOfRowsInSection:0] > 0) {
        [self.searchResultsList scrollToRowAtIndexPath:[NSIndexPath indexPathForItem:0
                                                                           inSection:0]
                                      atScrollPosition:UITableViewScrollPositionTop
                                              animated:NO];
    }
}

- (void)loadTrendingSearches
{
    __weak BLYSearchSongViewController *weakSelf = self;
    
    void (^loadTrendingSearchesInVC)(BLYSearchSongAutocompleteResults *results, NSError *err) = ^(BLYSearchSongAutocompleteResults *results, NSError *err){
        if (err) {
            return;
        }
        
        [weakSelf setSearchResults:results];
        
        weakSelf.trendingSearchesDisplayed = true;
        
        if (weakSelf.trendingSearchesDisplayed && weakSelf.historyDisplayed) {
            weakSelf.historyDisplayed = NO;
        }
        
        [weakSelf.searchResultsList reloadData];
    };
    
    BLYSearchSongAutocompleteResults *results = [[BLYTrendingSearchStore sharedStore] fetchTrendingSearchesAsAutocompleteResultsWithCompletionForUpdate:^(BLYSearchSongAutocompleteResults *results, NSError *err) {
        return;
        if (err) {
            return;
        }
        
        if (!weakSelf.trendingSearchesDisplayed) {
            return;
        }
        
        loadTrendingSearchesInVC(results, nil);
    }];
    
    loadTrendingSearchesInVC(results, nil);
    
    if ([weakSelf.searchResultsList numberOfRowsInSection:0] > 0) {
        [weakSelf.searchResultsList scrollToRowAtIndexPath:[NSIndexPath indexPathForItem:0
                                                                               inSection:0]
                                          atScrollPosition:UITableViewScrollPositionTop
                                                  animated:NO];
    }
}

- (void)cleanSearchedSongsList
{
    [self setSearchResults:[[BLYSearchSongAutocompleteResults alloc] init]];
    
    self.historyDisplayed = NO;
    
    [self.searchResultsList reloadData];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (_historyDisplayed) {
        return NSLocalizedString(@"last_searches", nil);
    } else {
        return NSLocalizedString(@"trending_searches", nil);
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return self.historyDisplayed || self.trendingSearchesDisplayed ? 40.0 : 0.0;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
    if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        UITableViewHeaderFooterView *tableViewHeaderFooterView = (UITableViewHeaderFooterView *) view;
        NSString *text = tableViewHeaderFooterView.textLabel.text;
        
        tableViewHeaderFooterView.contentView.backgroundColor = [UIColor whiteColor];
        tableViewHeaderFooterView.textLabel.text = [NSString stringWithFormat:@"%@%@",[[text substringToIndex:1] uppercaseString],[text substringFromIndex:1]];
        tableViewHeaderFooterView.textLabel.textColor = [UIColor grayColor];
        tableViewHeaderFooterView.textLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger nbOfResults = [self.searchResults nbOfResults];
    
    // If 0 results one tap to tableview dismiss keyboard
    self.searchResultsListTapGR.enabled = nbOfResults == 0;
    
    return nbOfResults;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    BLYSearchSongAutocompleteResult *result = (BLYSearchSongAutocompleteResult *)[self.searchResults resultsAtIndex:indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BLYSearchResultCell"];
    //BLYSearchSong *searchSong = [[BLYSearchSongsStore sharedStore] fetchSearchSongWithSearch:result.content];
    
    if (!cell) {
        // UITableViewCellStyleSubtitle
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:@"BLYSearchResultCell"];
    }
    
    UIColor *highlightedCellColor = [UIColor colorWithWhite:0.94 alpha:1.0];
    UIView *selectedView = [[UIView alloc] init];
    
    selectedView.backgroundColor = highlightedCellColor;
    
    cell.selectedBackgroundView = selectedView;
    cell.textLabel.text = result.content;
    cell.textLabel.font = [UIFont systemFontOfSize:16.0];
    cell.textLabel.textColor = [UIColor colorWithWhite:0.14 alpha:1.0];
    //cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    //NSString *detailTextLabel = @"";
    
//    if (searchSong.lastSelectedSegment) {
//        if ([searchSong.lastSelectedSegment intValue] == BLYSearchSongResultsViewControllerTracksSegment) {
//            detailTextLabel = NSLocalizedString(@"search_song_history_tracks_type", nil);
//        } else if ([searchSong.lastSelectedSegment intValue] == BLYSearchSongResultsViewControllerAlbumsSegment) {
//            detailTextLabel = NSLocalizedString(@"search_song_history_albums_type", nil);
//        } else if ([searchSong.lastSelectedSegment intValue] == BLYSearchSongResultsViewControllerVideosSegment) {
//            detailTextLabel = NSLocalizedString(@"search_song_history_videos_type", nil);
//        }
//    }
    
    //cell.detailTextLabel.text = detailTextLabel;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    NSString *search = cell.textLabel.text;
    
    [self search:search];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if ([search isEqualToString:@""]) {
        [self dismissSearchBar:nil];
    }
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    NSString *search = [searchBar text];
    
    [self search:search];
}

- (void)showCancelSearchBarButton:(BOOL)show
{
    UIBarButtonItem *cancelBtn = nil;
    
    if (show) {
        cancelBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                  target:self
                                                                  action:@selector(searchBarCancelButtonClicked:)];
    }
    
    [self.navigationItem setRightBarButtonItem:cancelBtn
                                      animated:!!cancelBtn];
}

- (void)search:(NSString *)search
{
    if (!search || [search isEqualToString:@""]) {
        return;
    }
    
    BLYSearchSong *searchSong = [[BLYSearchSongsStore sharedStore] fetchSearchSongWithSearch:search];
    BLYSearchSongResultsViewController *ssrVC = [[BLYSearchSongResultsViewController alloc] init];
    BLYAlbumViewController *albumVC = nil;
    
    // [self.searchBar resignFirstResponder];
    
//    if (searchSong
//        && [searchSong.lastSelectedSegment intValue] == BLYSearchSongResultsViewControllerAlbumsSegment
//        && [searchSong.lastSelectedAlbum integerValue] != NSNotFound) {
//
//        BLYAlbum *album = [searchSong.albums objectAtIndex:[searchSong.lastSelectedAlbum intValue]];
//
//        albumVC = [[BLYAlbumViewController alloc] init];
//
//        albumVC.loadedAlbumSid = album.sid;
//        albumVC.playerVC = self.playerVC;
//        albumVC.searchSongVC = self;
//        albumVC.searchSongResultsVC = ssrVC;
//        albumVC.searchSongResultsLastSelectedAlbum = [searchSong.lastSelectedAlbum integerValue];
//    }
    
    ssrVC.currentSearch = search;
    ssrVC.searchSongVC = self;
    ssrVC.playerVC = self.playerVC;
    
    if (!albumVC) {
        [self.navigationController pushViewController:ssrVC animated:YES];
    } else {
        NSArray *vcs = @[self, ssrVC, albumVC];
        
        [self.navigationController setViewControllers:vcs animated:YES];
    }
}

- (void)handleKeyboardAppear:(NSNotification *)n
{
    // Trigered by others apps during background play...
    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
        return;
    }
    
    NSDictionary *keyboardInfo = [n userInfo];
    CGRect keyboardFrame = [[keyboardInfo valueForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    
    // Fix https://stackoverflow.com/questions/45689664/ios-11-keyboard-height-is-returning-0-in-keyboard-notification
    if (@available(iOS 11.0, *)) {
        keyboardFrame = [[keyboardInfo valueForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    }
    
    CGRect searchResultsListFrame = self.searchResultsList.frame;
    CGRect searchResultsListBG = self.searchResultsListBackgroundView.frame;
    
    CGFloat tabBarHeight = self.tabBarController.tabBar.frame.size.height;
    CGFloat adHeight = 0.0;
    // ADBannerView *bannerView = [BannerViewManager sharedInstance].bannerView;
    
//    if (bannerView.bannerLoaded) {
//        adHeight = CGRectGetHeight(bannerView.bounds);
//    }
    
    _keyboardAppearNotification = n;
    
    self.keyboardIsDisplayed = YES;
    
    self.searchResultsList.frame = CGRectMake(searchResultsListFrame.origin.x,
                                              searchResultsListFrame.origin.y,
                                              searchResultsListFrame.size.width,
                                              (tabBarHeight + searchResultsListBG.size.height + adHeight) - keyboardFrame.size.height);
}

- (void)handleKeyboardDisappear:(NSNotification *)n
{
    //[self searchBarTextDidEndEditing:self.searchBar];
    
    self.keyboardIsDisplayed = NO;
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    if ([self searchBarIsEmpty]) {
        [self loadTrendingSearches];
    }
    
    [self showCancelSearchBarButton:YES];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
    CGRect searchResultsListFrame = self.searchResultsList.frame;
    CGRect searchResultsListBG = self.searchResultsListBackgroundView.frame;
    CGFloat adHeight = 0.0;
//    ADBannerView *bannerView = [BannerViewManager sharedInstance].bannerView;
//    
//    if (bannerView.bannerLoaded) {
//        adHeight = CGRectGetHeight(bannerView.bounds);
//    }
    
    self.searchResultsList.frame = CGRectMake(searchResultsListFrame.origin.x,
                                              searchResultsListFrame.origin.y,
                                              searchResultsListFrame.size.width,
                                              (searchResultsListBG.size.height) - adHeight);
    
    [self showCancelSearchBarButton:NO];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    BLYSearchSongAutocompleteResultsStore *store = [BLYSearchSongAutocompleteResultsStore sharedStore];
    __weak BLYSearchSongViewController *weakSelf = self;
    
    [self setCurrentSearch:searchText];
    
    if ([self searchBarIsEmpty]) {
        [self loadTrendingSearches];
        return;
    }
    
    // History displayed and search bar not empty ?
    // -> Hide history, wait for autocomplete results
    if (_historyDisplayed || _trendingSearchesDisplayed) {
        _searchResults = [[BLYSearchSongAutocompleteResults alloc] init];
        
        _historyDisplayed = NO;
        _trendingSearchesDisplayed = NO;
        
        [_searchResultsList reloadData];
    }
    
    BLYAppDelegate *appDelegate = (BLYAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    [store fetchSearchAutocompleteResultsForCountry:[appDelegate countryCodeForCurrentLocale]
                                          withQuery:searchText
                                      andCompletion:^(BLYSearchSongAutocompleteResults *results, NSError *err){
        // Many concurrent requests
        if (![searchText isEqualToString:weakSelf.currentSearch]
            && err) {
            return;
        }
                                          
        // View is not visible
        if (!weakSelf.view.window && err) {
            return;
        }
        
        // Don't alienate user with error in autocomplete
        //[[BLYErrorStore sharedStore] manageError:err forViewController:self];
                                          
        weakSelf.searchResults = results;
        weakSelf.historyDisplayed = NO;
                                          
        [weakSelf.searchResultsList reloadData];
        
        if ([weakSelf.searchResults nbOfResults] == 0) {
            return;
        }
        
        [weakSelf.searchResultsList scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0
                                                                              inSection:0]
                                          atScrollPosition:UITableViewScrollPositionTop
                                                  animated:NO];
    }];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [self dismissSearchBar:nil];
}

- (void)dismissSearchBar:(UIGestureRecognizer *)gr
{
    [self.searchBar setText:@""];
    [self.searchBar resignFirstResponder];
    
    [self loadSearchedSongsHistory];
    
    self.currentSearch = @"";
    
    [self.navigationItem setRightBarButtonItem:nil
                                      animated:YES];
}

// Overrided from base view controller to prevent playlist button to appear
- (void)handlePlayerHasLoadedPlaylist:(NSNotification *)n
{
    return;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
