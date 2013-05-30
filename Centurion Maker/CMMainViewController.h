//
//  CMMainViewController.h
//  Centurion Maker
//
//  Created by Jad Osseiran on 12/03/13.
//  Copyright (c) 2013 Jad. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class NSManagedObjectContext;

@interface CMMainViewController : NSViewController

@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@end
