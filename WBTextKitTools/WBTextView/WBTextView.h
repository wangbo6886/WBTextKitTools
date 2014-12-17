//
//  WBTextView.h
//  WBTextKitTools
//
//  Created by mc on 14/11/24.
//  Copyright (c) 2014年 WB. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "WBTextStorage.h"
#import "WBFaceView.h"

@protocol WBTextDelegate <NSObject>
@optional
- (void)WBTextViewDidDeleteFace;
@end

@interface WBTextView : UITextView<WBFaceDelegate>

@property (nonatomic, copy) void (^detectionBlock)(WBTextKeyWord keyWord, NSString *string, NSString *protocol, NSRange range);
@property (nonatomic, weak) id<WBTextDelegate> wbDelegate;

@end
