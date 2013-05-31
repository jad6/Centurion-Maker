//
//  CMTrackTableView.h
//  Centurion Maker
//
//  Created by Jad Osseiran on 31/05/13.
//  Copyright (c) 2013 Jad. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol CMTrackTableViewDelegate <NSObject, NSTableViewDelegate>

- (void)tableView:(NSTableView *)tableView didPressDeleteKeyForRowIndexes:(NSIndexSet *)indexSet;

@end

@interface CMTrackTableView : NSTableView

@property (weak, nonatomic) IBOutlet id<CMTrackTableViewDelegate> delegate;

@end
