//
//  CMCoreDataManager.h
//  Centurion Maker
//
//  Created by Jad Osseiran on 24/11/2014.
//  Copyright (c) 2014 Jad. All rights reserved.
//

@import DataStore;
@import CoreData;
@import Foundation;

@interface CMCoreDataManager : NSObject

+ (instancetype)sharedManager;

@property (nonatomic, strong, readonly) DataStore *dataStore;

@end
