//
//  Track.h
//  Centurion Maker
//
//  Created by Jad Osseiran on 3/06/13.
//  Copyright (c) 2013 Jad. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Track : NSManagedObject

@property (nonatomic, retain) NSString *artist;
@property (nonatomic, retain) NSString *filePath;
@property (nonatomic, retain) NSString *identifier;
@property (nonatomic, retain) NSNumber *invalid;
@property (nonatomic, retain) NSNumber *length;
@property (nonatomic, retain) NSNumber *mixStartTime;
@property (nonatomic, retain) NSNumber *order;
@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSNumber *playing;

@end
