//
//  BLYPlayerNavItemTitleView.m
//  Brown
//
//  Created by Jeremy Levy on 23/05/2014.
//  Copyright (c) 2014 Jeremy Levy. All rights reserved.
//

#import "BLYPlayerNavItemTitleView.h"

@implementation BLYPlayerNavItemTitleView

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

@end
