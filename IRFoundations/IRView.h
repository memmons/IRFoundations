//
//  IRView.h
//  IRFoundations
//
//  Created by Evadne Wu on 1/6/11.
//  Copyright 2011 Iridia Productions. All rights reserved.
//

#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>


extern NSString * const kUIView_IRAdditions_onLayoutSubviews;
extern NSString * const kUIView_IRAdditions_onDrawRect;
extern NSString * const kUIView_IRAdditions_onDrawLayerInContext;

@interface UIView (IRAdditions)

//	These additions, when invoked, will attempt to dynamically create subclasses of the receiver’s class, and swizzle the receiver’s class to the dynmically created subclass.

//	If possible, directly use an IRView, since it will provide a very clean implementation without any dynamically created and injected class hierarchies

@property (nonatomic, readwrite, copy) void (^onLayoutSubviews)(UIView *self);
@property (nonatomic, readwrite, copy) void (^onDrawRect)(UIView *self, CGRect drawnRect);
@property (nonatomic, readwrite, copy) void (^onDrawLayerInContext)(UIView *self, CALayer *aLayer, CGContextRef aContext);

@end


@interface IRView : UIView

@property (nonatomic, readwrite, copy) void(^onDrawRect) (CGRect rect, CGContextRef context);

@end
