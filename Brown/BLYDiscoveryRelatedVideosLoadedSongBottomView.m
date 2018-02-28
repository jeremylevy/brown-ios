//
//  BLYDiscoveryRelatedVideosLoadedSongBottomView.m
//  Brown
//
//  Created by Jeremy Levy on 26/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import "BLYDiscoveryRelatedVideosLoadedSongBottomView.h"

@implementation BLYDiscoveryRelatedVideosLoadedSongBottomView

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
    
    self.thumbnail.layer.masksToBounds = YES;
    self.thumbnail.layer.cornerRadius = 25.0;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
