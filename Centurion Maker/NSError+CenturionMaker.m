//
//  NSError+CenturionMaker.m
//  Centurion Maker
//
//  Created by Jad Osseiran on 25/11/2014.
//  Copyright (c) 2014 Jad. All rights reserved.
//

#import "NSError+CenturionMaker.h"

@implementation NSError (CenturionMaker)

- (void)handle {
    NSLog(@"Error detected! {\n\tDescripton: %@\n\tReason: %@\n\tSuggestion: %@\n}", self.localizedDescription, self.localizedFailureReason, self.localizedRecoverySuggestion);
}

@end
