//
//  BLYDiscoveryRelatedVideosRefreshHeaderView.m
//  Brown
//
//  Created by Jeremy Levy on 24/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import "BLYDiscoveryRelatedVideosRefreshHeaderView.h"

@implementation BLYDiscoveryRelatedVideosRefreshHeaderView

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
    
    [self.refreshButton setTitle:NSLocalizedString(@"discovery_vc_related_videos_refresh_button_text", nil)
                        forState:UIControlStateNormal];
    
    
    self.refreshButton.layer.cornerRadius = 15.0;
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
