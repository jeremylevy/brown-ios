//
//  BLYAlbumNavItemTitleView.m
//  Brown
//
//  Created by Jeremy Levy on 22/10/2016.
//  Copyright © 2016 Jeremy Levy. All rights reserved.
//

#import "BLYAlbumNavItemTitleView.h"

@implementation BLYAlbumNavItemTitleView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self) {
        
    }
    
    return self;
}

- (void)willMoveToSuperview:(UIView *)newSuperview
{
    self.frame = newSuperview.bounds;
}

// Fix https://stackoverflow.com/questions/46578752/ios-11-navigation-titleview-misplaced
- (CGSize)intrinsicContentSize
{
    return UILayoutFittingExpandedSize;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
