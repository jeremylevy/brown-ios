//
//  BLYPersonalTopSongViewController.m
//  Brown
//
//  Created by Jeremy Levy on 26/10/2013.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import "BLYPersonalTopSongViewController.h"
#import "BLYPersonalTopSongStore.h"
#import "BLYPlaylist.h"
#import "BLYPersonalTopSong.h"

@interface BLYPersonalTopSongViewController ()

@end

@implementation BLYPersonalTopSongViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self) {
        // Custom initialization
        self.navigationItem.title = NSLocalizedString(@"my_top_navigation_item_title", nil);
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleSongAddedToPersonalTop:)
                                                     name:BLYPersonalTopSongStoreDidAddSong
                                                   object:nil];
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Do any additional setup after loading the view from its nib.
    //[self reloadData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)handleSongAddedToPersonalTop:(NSNotification *)n
{
    [self reloadData];
}

- (void)reloadData
{
    NSArray *personalTopSongs = [[BLYPersonalTopSongStore sharedStore] fetchPersonalTopSong];
    NSMutableArray *songsForPlaylist = [[NSMutableArray alloc] init];
    
    BLYPlaylist *playlist = [[BLYPlaylist alloc] init];
    
    for (BLYPersonalTopSong *personalTopSong in personalTopSongs) {
        [songsForPlaylist addObject:[personalTopSong song]];
    }
    
    [playlist setSongs:songsForPlaylist];
    
    [self setPlaylist:playlist];
    
    [[self songsList] reloadData];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
