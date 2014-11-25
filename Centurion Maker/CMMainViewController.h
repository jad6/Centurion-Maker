//
//  CMMainViewController.h
//  Centurion Maker
//
//  Created by Jad Osseiran on 12/03/13.
//  Copyright (c) 2013 Jad. All rights reserved.
//

@import Cocoa;

@class NSManagedObjectContext;

@interface CMMainViewController : NSViewController <NSWindowDelegate>

- (void)handleFirstRunOnLaunch;
- (void)deleteSelectedtracks;

@end
