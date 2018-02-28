//
//  BLYPlayerPlaylistViewController.m
//  Brown
//
//  Created by Jeremy Levy on 24/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import "BLYPlayerPlaylistViewController.h"
#import "BLYPlaylist.h"
#import "BLYPlaylistSongCell.h"
#import "BLYSong.h"
#import "BLYPlayerViewController.h"

@interface BLYPlayerPlaylistViewController ()

@end

@implementation BLYPlayerPlaylistViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self) {
        // Custom initialization
        [[self navigationItem] setTitle:NSLocalizedString(@"playlist_navigation_item_title", nil)];
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    BLYPlayerViewController *playerVC = [self playerVC];
    
    if (![self playlist]) {
        [self setPlaylist:[[BLYPlaylist alloc] init]];
    }

    if (![playerVC currentSong]
        || [playerVC playerStatus] == BLYPlayerViewControllerPlayerStatusError) {
        return;
    }
}

// https://stackoverflow.com/questions/22406045/scrolltorowatindexpath-doesnt-handle-the-last-row-properly
- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    BLYPlayerViewController *playerVC = [self playerVC];
    
    if (![playerVC currentSong]
        || [playerVC playerStatus] == BLYPlayerViewControllerPlayerStatusError) {
        return;
    }
    
    [self scrollToSetPlayedSongInTheTopOfTheVisibleArea:NO];
}

- (void)scrollToSetPlayedSongInTheTopOfTheVisibleArea:(BOOL)animate
{
    BLYPlayerViewController *playerVC = [self playerVC];
    BLYSong *loadedSong = [playerVC currentSong];
    
    if (!loadedSong) {
        return;
    }
    
    NSInteger indexOfSong = [[self playlist] indexOfSong:loadedSong];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:indexOfSong inSection:0];
    
    [[self songsList] scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:animate];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[self playlist] nbOfSongs];
}

@end
