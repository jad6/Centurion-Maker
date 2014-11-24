//
//  CMExpiryHelper.h
//  Centurion Maker
//
//  Created by Jad Osseiran on 9/09/13.
//  Copyright (c) 2013 Jad. All rights reserved.
//

@import Foundation;

@interface CMExpiryManager : NSObject

+ (instancetype)sharedManager;

- (void)handleExpiryAlertingInWindow:(NSWindow *)window;

@end
