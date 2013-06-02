//
//  CMTrackDurationTransformer.m
//  Centurion Maker
//
//  Created by Jad Osseiran on 1/06/13.
//  Copyright (c) 2013 Jad. All rights reserved.
//

#import "CMTrackDurationTransformer.h"

#import "DurationFormat.h"

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
        return [value stringTrackDuration];
    }
}

- (id)reverseTransformedValue:(id)value
{
    if (!value) {
        return @(0);
    } else {
        return [value numberTrackDuration];
    }
}

@end
