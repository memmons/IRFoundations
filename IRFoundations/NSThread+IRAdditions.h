//
//  NSThread+IRAdditions.h
//  IRFoundations
//
//  Created by Evadne Wu on 2/17/12.
//  Copyright (c) 2012 Iridia Productions. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSThread (IRAdditions)

+ (void) irLogCallStackSymbols;

@end

extern void IRLogExceptionAndContinue (void(^)(void));
