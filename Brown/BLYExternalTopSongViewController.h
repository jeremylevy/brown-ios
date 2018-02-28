//
//  BLYTopSongsViewController.h
//  Brown
//
//  Created by Jeremy Levy on 19/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BLYTopSongViewController.h"

@interface BLYExternalTopSongViewController : BLYTopSongViewController

@property (strong, nonatomic) NSMutableDictionary *playlists;
@property (strong, nonatomic) NSMutableDictionary *playlistScrolls;
@property (weak, nonatomic) IBOutlet UISegmentedControl *songsCountryChoice;
@property (strong, nonatomic) NSString *currentCountry;
@property (weak, nonatomic) IBOutlet UIView *countryChoiceContainer;

- (IBAction)changeCountry:(id)sender;

@end
