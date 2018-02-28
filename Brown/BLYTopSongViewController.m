//
//  BLYTopSongViewController.m
//  Brown
//
//  Created by Jeremy Levy on 26/10/2013.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import "BLYTopSongViewController.h"
#import "BLYPlaylistSongCell.h"

@interface BLYTopSongViewController ()

@end

@implementation BLYTopSongViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self) {
        // Custom initialization
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    
    [[(BLYPlaylistSongCell *)cell rank] setText:[NSString stringWithFormat:@"%d.", (int)[indexPath row] + 1]];
    
    return cell;
}

@end
