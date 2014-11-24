//
//  CMTrackOrderTransformer.m
//  Centurion Maker
//
//  Created by Jad Osseiran on 1/06/13.
//  Copyright (c) 2013 Jad. All rights reserved.
//

#import "CMTrackOrderTransformer.h"

@implementation CMTrackOrderTransformer

+ (Class)transformedValueClass {
	return [NSNumber class];
}

- (id)transformedValue:(id)value {
	if (!value) {
		return nil;
	} else {
		return @([value integerValue] + 1);
	}
}

@end
