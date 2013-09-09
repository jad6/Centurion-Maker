//
//  CMExpiryHelper.m
//  Centurion Maker
//
//  Created by Jad Osseiran on 9/09/13.
//  Copyright (c) 2013 Jad. All rights reserved.
//

#import "CMExpiryManager.h"

#define DEFAULTS_EXPIRY @"CMExpiryReached"

@implementation CMExpiryManager

+ (instancetype)sharedManager
{
    static __DISPATCH_ONCE__ id singletonObject = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singletonObject = [[self alloc] init];
    });
    
    return singletonObject;
}

+ (NSDate *)expiryDate
{
    NSDateComponents *comps = [[NSDateComponents alloc] init];
    comps.day = 1;
    comps.month = 11;
    comps.year = 2013;
    comps.hour = 12;

    return [[NSCalendar currentCalendar] dateFromComponents:comps];
}

- (void)alertUserWithMessage:(NSString *)message inWindow:(NSWindow *)window
{
    NSAlert *expiryAlert = [NSAlert alertWithMessageText:@"App Expired"
                                           defaultButton:@"Bummer"
                                         alternateButton:nil
                                             otherButton:nil
                               informativeTextWithFormat:@"%@", message];
    
    [expiryAlert beginSheetModalForWindow:window
                            modalDelegate:self
                           didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:)
                              contextInfo:nil];
}

- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [NSApp terminate:self];
}

- (void)handleExpiryAlertingInWindow:(NSWindow *)window
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults valueForKey:DEFAULTS_EXPIRY]) {
        [defaults setBool:NO forKey:DEFAULTS_EXPIRY];
    }
    
    if ([[NSDate date] compare:[self.class expiryDate]] == NSOrderedDescending) {
        [defaults setBool:YES forKey:DEFAULTS_EXPIRY];
        [self alertUserWithMessage:@"This build of Centurion Maker has expired." inWindow:window];
    } else if ([defaults boolForKey:DEFAULTS_EXPIRY]) {
            [self alertUserWithMessage:@"Still expired, nice try setting you system clock back. Revert it to normal time, it's not great for your computer." inWindow:window];
    }
}

@end
