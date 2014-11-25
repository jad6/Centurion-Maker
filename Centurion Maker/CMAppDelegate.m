//
//  CMAppDelegate.m
//  Centurion Maker
//
//  Created by Jad Osseiran on 14/12/12.
//  Copyright (c) 2012 Jad. All rights reserved.
//

#import "CMAppDelegate.h"

#import "CMMainViewController.h"

#import "CMCoreDataManager.h"
#import "CMExpiryManager.h"

@interface CMAppDelegate ()

@property (strong, nonatomic) CMMainViewController *mainViewController;

@end

@implementation CMAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Insert code here to initialize your application.
	self.mainViewController = [[CMMainViewController alloc] initWithNibName:@"CMMainViewController" bundle:nil];

	[self.window setContentView:self.mainViewController.view];
	[self.window setDelegate:self.mainViewController];
    
//    self.mainVC.pathToAppSupport = [self applicationFilesDirectory];

//    [[CMExpiryManager sharedManager] handleExpiryAlertingInWindow:self.window];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag {
	[self.window makeKeyAndOrderFront:self];

	return YES;
}

#pragma mark - Menu

- (IBAction)feedback:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"mailto:jad6@icloud.com"]];
}

- (IBAction)resetFirstSteps:(id)sender {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	[defaults setValue:@(YES) forKey:FIRST_RUN_KEY];
	[defaults setValue:@(YES) forKey:FIRST_PLAY_KEY];

	[defaults synchronize];

	[self.mainViewController handleFirstRunOnLaunch];
}

- (IBAction)deleteSelectedTracks:(id)sender {
	[self.mainViewController deleteSelectedtracks];
}

#pragma mark - CoreData

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	// Save changes in the application's managed object context before the application terminates.
    DataStore *dataStore = [CMCoreDataManager sharedManager].dataStore;
    NSManagedObjectContext *context = dataStore.mainManagedObjectContext;

	if (context == nil) {
		return NSTerminateNow;
	}

	if ([context commitEditing] == NO) {
		NSLog(@"%@:%@ unable to commit editing to terminate", [self class], NSStringFromSelector(_cmd));
		return NSTerminateCancel;
	}

	if (context.hasChanges == NO) {
		return NSTerminateNow;
	}

	NSError *error = nil;
	if ([dataStore saveAndWait:&error] == NO) {
		// Customize this code block to include application-specific recovery steps.
		BOOL result = [sender presentError:error];
		if (result) {
			return NSTerminateCancel;
		}

		NSString *question = NSLocalizedString(@"Could not save changes while quitting. Quit anyway?", @"Quit without saves error question message");
		NSString *info = NSLocalizedString(@"Quitting now will lose any changes you have made since the last successful save", @"Quit without saves error question info");
		NSString *quitButton = NSLocalizedString(@"Quit anyway", @"Quit anyway button title");
		NSString *cancelButton = NSLocalizedString(@"Cancel", @"Cancel button title");
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = question;
        alert.informativeText = info;
		[alert addButtonWithTitle:quitButton];
		[alert addButtonWithTitle:cancelButton];

		NSInteger answer = [alert runModal];

		if (answer == NSAlertFirstButtonReturn) {
			return NSTerminateCancel;
		}
	}

	return NSTerminateNow;
}

@end
