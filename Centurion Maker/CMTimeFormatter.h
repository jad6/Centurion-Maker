//
//  CMTimeFormatter.h
//  Centurion Maker
//
//  Created by Jad Osseiran on 2/06/13.
//  Copyright (c) 2013 Jad. All rights reserved.
//

@import Foundation;

@class CMTimeFormatter;

@protocol CMTimeFormatterDelegate <NSObject>

- (void) timeFormatter:(CMTimeFormatter *)timeFormatter
    enteredInvalidData:(NSUInteger)numInvalidTries;

@end

@interface CMTimeFormatter : NSFormatter

@property (weak, nonatomic) id <CMTimeFormatterDelegate> delegate;

@property (nonatomic) NSInteger maxSecondsValue;

- (id)initWithDelegate:(id <CMTimeFormatterDelegate> )delegate;

@end
