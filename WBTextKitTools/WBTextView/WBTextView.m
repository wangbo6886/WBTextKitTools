//
//  WBTextView.m
//  WBTextKitTools
//
//  Created by mc on 14/11/24.
//  Copyright (c) 2014年 WB. All rights reserved.
//

#import "WBTextView.h"
#import "YLGIFImage.h"
#import "YLImageView.h"
#import "WBFaceView.h"

@implementation WBTextView{
    WBTextStorage *_wbTextStorage;
    NSLayoutManager *_wbLayoutManager;
    NSTextContainer *_wbTextContainer;
    NSMutableString *_copyStr;
    NSMutableArray *_gifs;
}

#pragma mark **************************************************************************************************************************
#pragma mark -----------------------------------初始化方法-----------------------------------
#pragma mark **************************************************************************************************************************
#pragma mark -----------------------------------初始化
- (instancetype)initWithFrame:(CGRect)frame textContainer:(NSTextContainer *)textContainer
{
    //文本存储，用来存放String
    _wbTextStorage = [[WBTextStorage alloc]init];
    
    //布局管理器
    _wbLayoutManager = [NSLayoutManager new];
    [_wbTextStorage addLayoutManager:_wbLayoutManager];
    
    //文本容器
    _wbTextContainer = [[NSTextContainer alloc]initWithSize:CGSizeMake(frame.size.width, frame.size.height)];
    [_wbLayoutManager addTextContainer:_wbTextContainer];
    
    _wbTextStorage.layouManager = _wbLayoutManager;
    _wbTextStorage.textContainer = _wbTextContainer;
    self = [super initWithFrame:frame textContainer:_wbTextContainer];
    
    _copyStr = [[NSMutableString alloc]init];
    _gifs = [[NSMutableArray alloc]init];
    
    if (self) {
        [self setup];
    }
    
    return self;
}

#pragma mark -----------------------------------属性调整
- (void)setup
{
    self.editable = YES;
    self.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.backgroundColor = [UIColor clearColor];
    self.textContainer.lineFragmentPadding = 0;
    self.textContainerInset = UIEdgeInsetsZero;
    
    [self addNotification];
}

#pragma mark **************************************************************************************************************************
#pragma mark -----------------------------------通知相关-----------------------------------
#pragma mark **************************************************************************************************************************
#pragma mark -----------------------------------增加通知
- (void)addNotification
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillChangeFrame:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didProcessEditingNotification:) name:DidProcessEditingNotification object:nil];
}

#pragma mark -----------------------------------键盘位置大小改变事件
- (void)keyboardWillChangeFrame:(NSNotification *)notification
{
    NSLog(@"%@",notification.userInfo);
}

#pragma mark -----------------------------------ProcessEditing结束，检查GIF
- (void)didProcessEditingNotification:(NSNotification *)notification
{
    if (!self.editable) {
        //需要把之前加载视图上的GIF全部移除掉
        for (YLImageView *gifImageView in _gifs) {
            [gifImageView removeFromSuperview];
        }
        //清空数组
        [_gifs removeAllObjects];
        
        //开始加入GIF
        for (NSString *rangeStr in _wbTextStorage.attachmentDictionary.allKeys) {
            NSString *value = [_wbTextStorage.attachmentDictionary objectForKey:rangeStr];
            NSString *gifName = [_wbTextStorage isGifEmoji:value];
            
            if (gifName) {
                /*
                 GIF存在效率问题，GIF多的情况下会存在卡顿的现象。
                 */
                YLImageView *gifImageView = [[YLImageView alloc]initWithFrame:CGRectZero];
                CGRect gifImageRect = [_wbLayoutManager boundingRectForGlyphRange:NSRangeFromString(rangeStr) inTextContainer:_wbTextContainer];
                gifImageRect.size.height = gifImageRect.size.width;
                gifImageView.frame = gifImageRect;
                gifImageView.image = [YLGIFImage imageNamed:gifName];;
                [self addSubview:gifImageView];
                
                [_gifs addObject:gifImageView];
            }
        }
    }
}

#pragma mark -----------------------------------移除通知
- (void)removeNotification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DidProcessEditingNotification object:nil];
}

#pragma mark **************************************************************************************************************************
#pragma mark -----------------------------------重写一些方法-----------------------------------
#pragma mark **************************************************************************************************************************
#pragma mark -----------------------------------重写设置编辑状态
- (void)setEditable:(BOOL)editable
{
    [super setEditable:editable];
    [_wbTextStorage setEditable:editable];
}

#pragma mark -----------------------------------重写获得文本的方法
- (NSString *)text
{
    NSString *text = [_wbTextStorage getPlainText];
    return text;
}

#pragma mark -----------------------------------重写文字大小的方法
- (void)setFont:(UIFont *)font
{
    [super setFont:font];
    _wbTextStorage.font = font;
}

#pragma mark -----------------------------------重写detectionBlock设置方法
- (void)setDetectionBlock:(void (^)(WBTextKeyWord, NSString *, NSString *, NSRange))detectionBlock
{
    if (detectionBlock) {
        _detectionBlock = [detectionBlock copy];
        self.userInteractionEnabled = YES;
    } else {
        _detectionBlock = nil;
        self.userInteractionEnabled = NO;
    }
}

#pragma mark -----------------------------------重写插入方法
- (void)insertText:(NSString *)text
{
    NSMutableString *inserStr = [[NSMutableString alloc]initWithString:text];
    
    //如果是在URL链接后面插入表情，需要加入一个空格隔开，不然会发生某些异常
    for (NSDictionary *dictionary in _wbTextStorage.rangesOfKeyWords)  {
        NSRange range = [[dictionary objectForKey:KeyRange] rangeValue];
        NSInteger insertLocation = NSMaxRange(range);
        WBTextKeyWord keyWord = (WBTextKeyWord)[[dictionary objectForKey:KeyWord] intValue];
        
        if (keyWord == WBTextKeyWordLink && insertLocation == self.selectedRange.location && [_wbTextStorage isEmoji:text] ) {
            [inserStr insertString:@" " atIndex:0];
        }
    }
    
    [super insertText:inserStr];
    //由于在插入表情时，光标位置异常，需要手动调整
    [self setSelectedRange:NSMakeRange(_wbTextStorage.selectedRangeLocation, 0)];
}

#pragma mark **************************************************************************************************************************
#pragma mark -----------------------------------委托响应-----------------------------------
#pragma mark **************************************************************************************************************************
#pragma mark -----------------------------------插入表情
- (void)insertFaceWithKey:(NSString *)faceKey
{
    [self insertText:faceKey];
}

#pragma mark -----------------------------------删除表情
- (void)deleteFace
{
    [_wbTextStorage replaceCharactersInRange:NSMakeRange(self.selectedRange.location - 1, 1) withString:@""];
    if ([_wbDelegate respondsToSelector:@selector(WBTextViewDidDeleteFace)]) {
        [_wbDelegate WBTextViewDidDeleteFace];
    }
}

#pragma mark **************************************************************************************************************************
#pragma mark -----------------------------------点击特殊字符响应-----------------------------------
#pragma mark **************************************************************************************************************************
#pragma mark -----------------------------------点击开始
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.editable) {
        return;
    }
    
    id touchedKeyWord = [self getTouchedKeyWord:touches];
    WBTextKeyWord keyWord = (WBTextKeyWord)[[touchedKeyWord objectForKey:KeyWord] intValue];
    if(touchedKeyWord == nil || keyWord == WBTextKeyWordLink) {
        [super touchesBegan:touches withEvent:event];
    }
}

#pragma mark -----------------------------------点击结束
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    CGPoint touchLocation = [[touches anyObject] locationInView:self];
    
    CGRect myRect = self.frame;
    myRect.origin.x = 0;
    myRect.origin.y = 0;
    
    if (!CGRectContainsPoint(myRect, touchLocation))
        return;
    
    id touchedKeyWord = [self getTouchedKeyWord:touches];
    WBTextKeyWord keyWord = (WBTextKeyWord)[[touchedKeyWord objectForKey:KeyWord] intValue];
    if(touchedKeyWord != nil && keyWord != WBTextKeyWordLink) {
        NSRange range = [[touchedKeyWord objectForKey:KeyRange] rangeValue];
        
        _detectionBlock((WBTextKeyWord)[[touchedKeyWord objectForKey:KeyWord] intValue], [[_wbTextStorage string] substringWithRange:range], [touchedKeyWord objectForKey:UrlProtocol], range);
    } else {
        [super touchesEnded:touches withEvent:event];
    }
}

#pragma mark -----------------------------------找到字符在文本中的位置
- (NSUInteger)charIndexAtLocation:(CGPoint)touchLocation {
    NSUInteger glyphIndex = [_wbLayoutManager glyphIndexForPoint:touchLocation inTextContainer:_wbTextContainer];
    CGRect boundingRect = [_wbLayoutManager boundingRectForGlyphRange:NSMakeRange(glyphIndex, 1) inTextContainer:_wbTextContainer];
    
    if (CGRectContainsPoint(boundingRect, touchLocation))
        return [_wbLayoutManager characterIndexForGlyphAtIndex:glyphIndex];
    else
        return -1;
}

#pragma mark -----------------------------------从存储关键字的数组中取出对象
- (id)getTouchedKeyWord:(NSSet *)touches {
    NSUInteger charIndex = [self charIndexAtLocation:[[touches anyObject] locationInView:self]];
    
    for (id obj in _wbTextStorage.rangesOfKeyWords) {
        NSRange range = [[obj objectForKey:KeyRange] rangeValue];
        
        if (charIndex >= range.location && charIndex < range.location + range.length) {
            return obj;
        }
    }
    
    return nil;
}

#pragma mark **************************************************************************************************************************
#pragma mark -----------------------------------复制粘贴-----------------------------------
#pragma mark **************************************************************************************************************************
#pragma mark -----------------------------------获得第一响应
- (BOOL)canBecomeFirstResponder
{
    return YES;
}

#pragma mark -----------------------------------弹出菜单支持哪些操作
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    if (action==@selector(copy:)) {
        return YES;
    }else if(action == @selector(select:)){
        return YES;
    }else if(action == @selector(selectAll:)){
        return YES;
    }else if(action == @selector(paste:)){
        if (self.editable) {
            return YES;
        }else{
            return NO;
        }
    }else{
        return NO;
    }
    
    return [super canPerformAction:action withSender:sender];
}

#pragma mark -----------------------------------重写复制方法
- (void)copy:(id)sender
{
    [self copyToPasteboard];
}

#pragma mark -----------------------------------复制内容到粘贴板
/*
 普通复制时，附本类是复制不了的；
 此方法用于对表情（附本）的复制；
 比较重要的系统调用都是使用的NSAttributedStringSDK中的方法；
 */
- (void)copyToPasteboard
{
    NSLog(@"%@",_wbTextStorage.attachmentRangeArray);
    NSLog(@"%@",NSStringFromRange(self.selectedRange));
    
    NSMutableArray *textArray = [[NSMutableArray alloc]init];
    //获得被选取部分的属性字符串
    NSMutableAttributedString *selectedAttributedString = [[NSMutableAttributedString alloc]initWithAttributedString:[_wbTextStorage attributedSubstringFromRange:self.selectedRange]];
    
    [selectedAttributedString enumerateAttributesInRange:NSMakeRange(0, selectedAttributedString.length) options:0 usingBlock:^(NSDictionary *attrs, NSRange range, BOOL *stop) {
        //从选取的属性字符串中分别找到文字部分的范围
        [textArray addObject:NSStringFromRange(range)];
    }];
    
    //生成文字部分的字典，记录每个范围内的文字
    NSMutableDictionary *textDictionary = [[NSMutableDictionary alloc]init];
    for (NSString *textRangeStr in textArray) {
        NSRange textRange = NSRangeFromString(textRangeStr);
        NSAttributedString *textAttributedString = [selectedAttributedString attributedSubstringFromRange:textRange];
        [textAttributedString enumerateAttributesInRange:NSMakeRange(0, textAttributedString.length) options:0 usingBlock:^(NSDictionary *attrs, NSRange range, BOOL *stop) {
            if ([attrs objectForKey:NSAttachmentAttributeName]) {
                [textDictionary setObject:NSAttachmentAttributeName forKey:textRangeStr];
            }else{
                NSString *textStr = [textAttributedString string];
                [textDictionary setObject:textStr forKey:textRangeStr];
            }
        }];
    }
    NSLog(@"%@",textDictionary);
    
    [_copyStr setString:@""];

    //以下为区分复制的表情（附本）和普通文字的核心循环
    for (NSString *textRangeStr in textArray) {
        NSString *text = [textDictionary objectForKey:textRangeStr];
        if (text != NSAttachmentAttributeName) {
            [_copyStr appendString:text];
        }else{
            for (NSString *attachmentRangeStr in _wbTextStorage.attachmentRangeArray) {
                NSRange attachmentRange = NSRangeFromString(attachmentRangeStr);
                NSRange textRange = NSRangeFromString(textRangeStr);
                NSInteger copyAttachmentLocation = self.selectedRange.location + textRange.location;
                
                if(NSLocationInRange(attachmentRange.location, self.selectedRange) && copyAttachmentLocation == attachmentRange.location){
                    NSString *emojiKey = [_wbTextStorage.attachmentDictionary objectForKey:attachmentRangeStr];
                    [_copyStr appendString:emojiKey];
                    break;
                }
            }
        }
    }
    NSLog(@"%@",_copyStr);
    
    //复制到剪贴板
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = _copyStr;
}

#pragma mark -----------------------------------重写粘贴方法
- (void)paste:(id)sender
{
    [super paste:sender];
    //由于在插入表情时，光标位置异常，需要手动调整
    [self setSelectedRange:NSMakeRange(_wbTextStorage.selectedRangeLocation, 0)];
}


@end
