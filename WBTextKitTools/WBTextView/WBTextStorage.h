//
//  WBTextStorage.h
//  WBTextKitTools
//
//  Created by mc on 14/11/24.
//  Copyright (c) 2014年 WB. All rights reserved.
//

#import <UIKit/UIKit.h>

#define KeyWord @"keyWord"
#define KeyRange @"keyRange"
#define UrlProtocol @"urlProtocol"
#define UrlAttributes @"urlAttributes"
#define AttachmentDictionary @"attachmentDictionary"
#define DidProcessEditingNotification @"DidProcessEditing"

typedef enum {
    WBTextKeyWordAt = 0,
    WBTextKeyWordPound,
    WBTextKeyWordLink
} WBTextKeyWord;

@interface WBTextStorage : NSTextStorage

@property (nonatomic, strong) NSMutableArray *rangesOfKeyWords;
@property (nonatomic, strong) NSMutableArray *attachmentRangeArray;
@property (nonatomic, strong) NSMutableDictionary *attachmentDictionary;
@property (nonatomic, assign) NSInteger selectedRangeLocation;
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, strong) NSTextContainer *textContainer;
@property (nonatomic, strong) NSLayoutManager *layouManager;
@property (nonatomic, assign) BOOL editable;

- (NSString *)getPlainText;
- (BOOL)isEmoji:(NSString *)text;
- (NSString *)isGifEmoji:(NSString *)text;
@end
