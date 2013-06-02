//
//  CMTrackDurationTransformer.m
//  Centurion Maker
//
//  Created by Jad Osseiran on 1/06/13.
//  Copyright (c) 2013 Jad. All rights reserved.
//

#import "CMTrackDurationTransformer.h"

@implementation CMTrackDurationTransformer

+ (Class)transformedValueClass
{
    return [NSString class];
}

- (id)transformedValue:(id)value
{
    if (!value) {
        return nil;
    } else {
        NSInteger seconds = [value integerValue];
        
        NSInteger formattedSeconds = (seconds % 60);
        NSInteger formattedMinutes = (seconds / 60);
        
        // Make sure that the seconds are in order of 2 decimals
        NSString *extraZeroString = @"";
        if (formattedSeconds < 10) {
            formattedSeconds *= 10;
            
            if (formattedSeconds == 0) {
                extraZeroString = @"0";
            }
        }

        
        return [[NSString alloc] initWithFormat:@"%li:%li%@", formattedMinutes, formattedSeconds, extraZeroString];
    }
}

@end
