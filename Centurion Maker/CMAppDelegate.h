//
//  CMAppDelegate.h
//  Centurion Maker
//
//  Created by Jad Osseiran on 14/12/12.
//  Copyright (c) 2012 Jad. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define FIRST_RUN_KEY @"CMFirstRun"
#define FIRST_PLAY_KEY @"CMFirstPlay"

@interface CMAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

- (IBAction)saveAction:(id)sender;

@end
