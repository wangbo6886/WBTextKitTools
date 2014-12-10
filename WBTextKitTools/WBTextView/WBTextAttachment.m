//
//  WBTextAttachment.m
//  WBTextKitTools
//
//  Created by mc on 14/12/8.
//  Copyright (c) 2014年 WB. All rights reserved.
//

#import "WBTextAttachment.h"

@implementation WBTextAttachment

#pragma mark -----------------------------------根据文字大小自己转换附本大小
-(CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)textContainer proposedLineFragment:(CGRect)lineFrag glyphPosition:(CGPoint)position characterIndex:(NSUInteger)charIndex
{
    return CGRectMake(0 , -2 , self.size , self.size );
}

@end
