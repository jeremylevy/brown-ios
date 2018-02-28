//
//  BLYNavSearchBarView.m
//  Brown
//
//  Created by Jeremy Levy on 13/02/2018.
//  Copyright © 2018 Jeremy Levy. All rights reserved.
//

#import "BLYNavSearchBarContainerView.h"

@interface BLYNavSearchBarContainerView ()

@property (strong, nonatomic) UISearchBar *searchBar;

@end

@implementation BLYNavSearchBarContainerView

- (id)initWithSearchBar:(UISearchBar *)searchBar
{
    self = [super initWithFrame:CGRectZero];
    
    if (self) {
        // Initialization code
        [self addSubview:searchBar];
        
        _searchBar = searchBar;
    }
    
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    _searchBar.frame = self.bounds;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
