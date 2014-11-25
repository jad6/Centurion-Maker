//
//  CMCoreDataManager.m
//  Centurion Maker
//
//  Created by Jad Osseiran on 24/11/2014.
//  Copyright (c) 2014 Jad. All rights reserved.
//

#import "CMCoreDataManager.h"

@interface CMCoreDataManager ()

@property (nonatomic, strong) DataStore *dataStore;

@end

@implementation CMCoreDataManager

+ (instancetype)sharedManager {
    static __DISPATCH_ONCE__ CMCoreDataManager *singletonObject = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singletonObject = [[self alloc] init];
        
        NSArray *directories = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *storePath = [[directories lastObject] stringByAppendingPathComponent:@"centurionmaker.sqlite3"];
        
        NSManagedObjectModel *model = [DataStore modelForResource:@"Centurion_Maker" bundle:[NSBundle mainBundle]];
        
        singletonObject.dataStore = [[DataStore alloc] initWithModel:model storePath:storePath];
    });
    
    return singletonObject;
}

@end
