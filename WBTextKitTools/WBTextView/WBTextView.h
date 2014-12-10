//
//  WBTextView.h
//  WBTextKitTools
//
//  Created by mc on 14/11/24.
//  Copyright (c) 2014年 WB. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "WBTextStorage.h"

@interface WBTextView : UITextView

@property (nonatomic, copy) void (^detectionBlock)(WBTextKeyWord keyWord, NSString *string, NSString *protocol, NSRange range);

@end
