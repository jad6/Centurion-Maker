//
//  CMCoreDataManager.h
//  Centurion Maker
//
//  Created by Jad Osseiran on 24/11/2014.
//  Copyright (c) 2014 Jad. All rights reserved.
//

@import CoreData;
@import Foundation;

@interface CMCoreDataManager : NSObject

@property (class, readonly, strong) CMCoreDataManager *defaultManager;

@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

- (BOOL)saveContext:(NSError **)error;

@end
