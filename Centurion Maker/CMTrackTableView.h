//
//  CMTrackTableView.h
//  Centurion Maker
//
//  Created by Jad Osseiran on 31/05/13.
//  Copyright (c) 2013 Jad. All rights reserved.
//

@import Cocoa;

@protocol CMTrackTableViewDelegate <NSObject, NSTableViewDelegate>

@optional
- (void)tableView:(NSTableView *)tableView didInputValidStartTime:(double)startTime atRowIndex:(NSUInteger *)row;

- (void)tableView:(NSTableView *)tableView didPressDeleteKeyForRowIndexes:(NSIndexSet *)indexSet;
- (BOOL)tableView:(NSTableView *)tableView shouldRespondToDeleteKeyForRowIndexes:(NSIndexSet *)indexSet;

@end

@interface CMTrackTableView : NSTableView

@property (weak, nonatomic) IBOutlet id <CMTrackTableViewDelegate> delegate;

@end
