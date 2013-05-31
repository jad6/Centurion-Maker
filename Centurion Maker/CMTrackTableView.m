//
//  CMTrackTableView.m
//  Centurion Maker
//
//  Created by Jad Osseiran on 31/05/13.
//  Copyright (c) 2013 Jad. All rights reserved.
//

#import "CMTrackTableView.h"

@implementation CMTrackTableView

@dynamic delegate;

- (void)keyDown:(NSEvent *)theEvent
{
    unichar key = [[theEvent charactersIgnoringModifiers] characterAtIndex:0];
    if (key == NSDeleteCharacter) {
        if ([self.delegate respondsToSelector:@selector(tableView:shouldRespondToDeleteKeyForRowIndexes:)]
            && [self.delegate tableView:self shouldRespondToDeleteKeyForRowIndexes:[self selectedRowIndexes]]
            && [self.delegate respondsToSelector:@selector(tableView:didPressDeleteKeyForRowIndexes:)]) {
            [self.delegate tableView:self didPressDeleteKeyForRowIndexes:[self selectedRowIndexes]];
        }
        return;
    }
    
    [super keyDown:theEvent];
}

@end
