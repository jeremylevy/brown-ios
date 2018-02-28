//
//  BLYPlayedSongOnLoadHeaderView.m
//  Brown
//
//  Created by Jeremy Levy on 28/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import "BLYPlayedSongOnLoadHeaderView.h"

@implementation BLYPlayedSongOnLoadHeaderView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self) {
        // Initialization code
    }
    
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    [self.resumePlaylistButton setTitle:NSLocalizedString(@"played_song_resume_playlist_header_view_button", nil)
                                   forState:UIControlStateNormal];
    
    self.resumePlaylistButton.layer.borderWidth = 0.0;
    self.resumePlaylistButton.layer.cornerRadius = 14.0;
    
    self.resumePlaylistButton.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.resumePlaylistButton.tintColor = [UIColor lightGrayColor];
    
    [self.resumePlaylistButton addTarget:self
                                  action:@selector(highlightBorder)
                        forControlEvents:UIControlEventTouchDown];
    
    [self.resumePlaylistButton addTarget:self
                                  action:@selector(unhighlightBorder)
                        forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchDragExit];
    
    self.songThumbnail.layer.cornerRadius = 25.0;
    self.songThumbnail.layer.masksToBounds = YES;
}

- (void)highlightBorder
{
    self.resumePlaylistButton.layer.borderColor = [UIColor colorWithWhite:0.667 alpha:0.2].CGColor;
}

- (void)unhighlightBorder
{
    self.resumePlaylistButton.layer.borderColor = [UIColor lightGrayColor].CGColor;
}

@end
