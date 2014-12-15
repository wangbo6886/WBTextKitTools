//
//  WBTextStorage.m
//  WBTextKitTools
//
//  Created by mc on 14/11/24.
//  Copyright (c) 2014年 WB. All rights reserved.
//

#import "WBTextStorage.h"
#import "WBTextAttachment.h"

#define URLRegex @"(?i)\\b((?:[a-z][\\w-]+:(?:/{1,3}|[a-z0-9%])|www\\d{0,3}[.]|[a-z0-9.\\-]+[.][a-z]{2,4}/)(?:[^\\s()<>]+|\\(([^\\s()<>]+|(\\([^\\s()<>]+\\)))*\\))+(?:\\(([^\\s()<>]+|(\\([^\\s()<>]+\\)))*\\)|[^\\s`!()\\[\\]{};:'\".,<>?«»“”‘’]))"
#define EmojiRegex @"\\[[a-zA-Z0-9\\u4e00-\\u9fa5]+\\]"
#define RemoveStringName @"NSRemoveString"
#define RGBColor(r, g, b) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:1.0]
#define TextColor RGBColor(0 , 0, 0)
#define AtColor RGBColor(255 , 0 , 0)
#define PoundColor RGBColor(128, 138 , 135)

@implementation WBTextStorage
{
    NSMutableAttributedString *_backingStore;
    UIFont *_attributesFont;
    NSDictionary *_attributesText;
    NSDictionary *_attributesAt;
    NSDictionary *_attributesPound;
    NSDictionary *_attributesLink;
    NSArray *_validProtocols;
    NSDictionary *_emojiDictionary;
}

#pragma mark **************************************************************************************************************************
#pragma mark -----------------------------------重写一些方法-----------------------------------
#pragma mark **************************************************************************************************************************
#pragma mark -----------------------------------初始化
- (id)init
{
    self = [super init];
    
    if (self) {
        if (_attributesFont == nil) {
            _attributesFont = [UIFont fontWithName:@"HelveticaNeue" size:12.0];
            [self reSetTextAttributesFont];
        }
        
        _backingStore = [[NSMutableAttributedString alloc] init];
        _rangesOfKeyWords = [[NSMutableArray alloc] init];//存储特殊文本的RANGE
        _validProtocols = @[@"http", @"https"];//链接协议开头
        //表情集合
        NSString *emojiFilePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"emotionGifImage.plist"];
        _emojiDictionary = [[NSDictionary alloc] initWithContentsOfFile:emojiFilePath];
        _attachmentRangeArray = [[NSMutableArray alloc]init];//存储附本的RANGE
        _attachmentDictionary = [[NSMutableDictionary alloc]init];//存储附本的文字内容
    }
    
    return self;
}

#pragma mark -----------------------------------重写设置文本大小方法
- (void)setFont:(UIFont *)font
{
    _attributesFont = font;
    [self reSetTextAttributesFont];
}

#pragma mark -----------------------------------返回当前存储的字符串
- (NSString *)string
{
    return [_backingStore string];
}

#pragma mark -----------------------------------获取指定范围内的文字属性
- (NSDictionary *)attributesAtIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range
{
    return [_backingStore attributesAtIndex:location effectiveRange:range];
}

#pragma mark -----------------------------------返回当前可变字符串
- (NSAttributedString *)attributedString
{
    return _backingStore;
}

#pragma mark -----------------------------------设置指定范围内的文字属性
- (void)setAttributes:(NSDictionary *)attrs range:(NSRange)range
{
    [_backingStore setAttributes:attrs range:range];
    [self edited:NSTextStorageEditedAttributes range:range changeInLength:0];
}

#pragma mark -----------------------------------为指定范围内的文字增加属性
- (void)addAttributes:(NSDictionary *)attrs range:(NSRange)range
{
    [_backingStore addAttributes:attrs range:range];
    [self edited:NSTextStorageEditedAttributes range:range changeInLength:0];
}

#pragma mark -----------------------------------移除指定范围内的文字的属性
- (void)removeAttribute:(NSString *)name range:(NSRange)range
{
    [_backingStore removeAttribute:name range:range];
    [self edited:NSTextStorageEditedAttributes range:range changeInLength:0];
}

#pragma mark -----------------------------------修改指定范围内的文字
- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)string
{
    if (range.length != 0) {
        //删除或替换
        [self removeAttachmentDictionaryInRange:range];
        
        NSAttributedString *attributedString = [self attributedSubstringFromRange:range];
        if (string.length > 0 && ![self isEmoji:[attributedString string]]) {
            [self addInRange:range andText:string];
            
            NSLog(@"替换后：");
            NSLog(@"数组：%@",_attachmentRangeArray);
            NSLog(@"字典：%@",_attachmentDictionary);
        }
    }else{
        if (_backingStore.length > 0) {
            [self addInRange:range andText:string];
        }
    }

    [_backingStore replaceCharactersInRange:range withString:string];
    [self edited:(NSTextStorageEditedCharacters|NSTextStorageEditedAttributes) range:range changeInLength:string.length - range.length];
}

#pragma mark -----------------------------------每次文本存储有修改时,这个方法都自动被调用。每次编辑后,NSTextStorage会用这个方法来清理字符串.所以在这个方法中来做一些文本属性刷新的特殊处理
-(void)processEditing
{
    [self analyzeSpecialCharacter];
    [self analyzeLink];
    [self updateText];
    [self analyzeImage];
    
    //别忘记了要继承一下这个方法做系统本身的操作
    [super processEditing];
    
    //这里使用自己的通知，系统自带的NSTextStorageDidProcessEditingNotification通知会触发多次，不好控制
    [[NSNotificationCenter defaultCenter]postNotificationName:DidProcessEditingNotification object:nil];
}

#pragma mark **************************************************************************************************************************
#pragma mark -----------------------------------私有方法-----------------------------------
#pragma mark **************************************************************************************************************************
#pragma mark -----------------------------------解析特殊字符的文本
- (void)analyzeSpecialCharacter
{
    NSMutableString *tmpText = [[NSMutableString alloc] initWithString:self.string];
    
    //需要解析的字符 (@ at, # pound)
    NSString *keyCharacters = @"@#";
    NSCharacterSet *keyCharactersSet = [NSCharacterSet characterSetWithCharactersInString:keyCharacters];
    
    //特殊文本以哪些字符结尾
    NSMutableCharacterSet *validCharactersSet = [NSMutableCharacterSet alphanumericCharacterSet];//字符集
    [validCharactersSet removeCharactersInString:@"!@#$%^&*()-={[]}|;:',<>.?/"];//这里传入结尾字符
    [validCharactersSet addCharactersInString:@"_"];//可以单独添加特殊的连接字符
    
    //这里需要先清理一下原先存储的特殊文本内容
    [_rangesOfKeyWords removeAllObjects];
    
    //如果字符串中包含特殊字符的位置小于字符串长度，则进入循环
    while ([tmpText rangeOfCharacterFromSet:keyCharactersSet].location < tmpText.length) {
        NSRange range = [tmpText rangeOfCharacterFromSet:keyCharactersSet];//得到特殊字符的Range
        
        WBTextKeyWord keyWord;
        
        //得到特殊字符的类型
        switch ([tmpText characterAtIndex:range.location]) {
            case '@':
                keyWord = WBTextKeyWordAt;
                break;
            case '#':
                keyWord = WBTextKeyWordPound;
                break;
            default:
                keyWord = -1;
                break;
        }
        
        //替换掉已经找到的特殊字符
        [tmpText replaceCharactersInRange:range withString:@"%"];
        
        int length = (int)range.length;//拿到特殊字符的长度
        
        //从特殊字符之后的位置开始循环找结尾字符
        while (range.location + length < tmpText.length) {
            //判断当前结尾字符是否为验证集的子集，如果是的话，length加一，继续循环，直到找到不是子集的为止
            BOOL charIsMember = [validCharactersSet characterIsMember:[tmpText characterAtIndex:range.location + length]];
            
            if (charIsMember)
                length++;
            else
                break;
        }
        
        //区分@情况下，为邮箱的字符串
        if (keyWord == WBTextKeyWordAt && tmpText.length - range.location - length > 3) {
            NSString *emailStr = [tmpText substringWithRange:NSMakeRange(range.location, length + 4)];
            [tmpText rangeOfString:@".com"];
            NSString *comStr = [emailStr substringFromIndex:emailStr.length - 4];
            if (range.location > 0 && [validCharactersSet characterIsMember:[tmpText characterAtIndex:range.location - 1]] && [comStr isEqual:@".com"])
                continue;//进行下一次循环
        }
        
        //把找到的特殊字符串,存入数组中用于以后的操作
        if (length > 1)
            [_rangesOfKeyWords addObject:@{KeyWord: @(keyWord), KeyRange: [NSValue valueWithRange:NSMakeRange(range.location, length)]}];
    }
}

#pragma mark -----------------------------------解析URL
- (void)analyzeLink
{
    NSMutableString *tmpText = [[NSMutableString alloc] initWithString:self.string];
    
    NSError *regexError = nil;
    //正则表达式匹配链接
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:URLRegex options:0 error:&regexError];
    
    [regex enumerateMatchesInString:tmpText options:0 range:NSMakeRange(0, tmpText.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        NSString *protocol = @"http";
        NSString *link = [tmpText substringWithRange:result.range];
        NSRange protocolRange = [link rangeOfString:@"://"];
        if (protocolRange.location != NSNotFound) {
            protocol = [link substringToIndex:protocolRange.location];
        }
        
        if ([_validProtocols containsObject:protocol.lowercaseString]) {
            NSMutableDictionary *attributesLink = [[NSMutableDictionary alloc]initWithDictionary:_attributesLink];
            [attributesLink setValue:[NSURL URLWithString:link] forKey:NSLinkAttributeName];
            [_rangesOfKeyWords addObject:@{KeyWord: @(WBTextKeyWordLink), UrlProtocol: protocol, KeyRange: [NSValue valueWithRange:result.range],UrlAttributes: attributesLink}];
        }
    }];
}

#pragma mark -----------------------------------解析表情
- (void)analyzeImage
{
    NSMutableString *tmpText = [[NSMutableString alloc] initWithString:self.string];
    
    NSRegularExpression *exp_emoji =
    [[NSRegularExpression alloc] initWithPattern:EmojiRegex
                                         options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
                                           error:nil];
    NSArray *emojis = [exp_emoji matchesInString:tmpText
                                         options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
                                           range:NSMakeRange(0, tmpText.length)];
    NSMutableArray *emojiRanges = [[NSMutableArray alloc]init];
    for (NSTextCheckingResult *result in emojis) {
        [emojiRanges addObject:NSStringFromRange(result.range)];
    }
    
    for (int i = 0; i < emojiRanges.count; i++) {
        NSRange range = NSRangeFromString([emojiRanges objectAtIndex:i]);
        NSString *emojiKey = [self.string substringWithRange:range];
        NSString *imageName = [_emojiDictionary objectForKey:emojiKey];
        
        if (imageName) {
            NSInteger decrement = emojiKey.length - 1;
            NSArray *updateEmojiArray = [emojiRanges subarrayWithRange:NSMakeRange(i + 1, emojiRanges.count - i - 1)];
            int index = 0;
            for (NSString *updateEmojiRangeStr in updateEmojiArray) {
                NSRange updateEmojiRange = NSRangeFromString(updateEmojiRangeStr);
                NSRange newEmojiRange = NSMakeRange(updateEmojiRange.location - decrement, updateEmojiRange.length);
                [emojiRanges replaceObjectAtIndex:i + 1 + index withObject:NSStringFromRange(newEmojiRange)];
                index++;
            }
            
            //取得.的位置
            NSRange imageSuffixRange = [imageName rangeOfString:@"."];
            NSString *imageSuffixStr = @"";
            if (imageSuffixRange.location != NSNotFound) {
                imageSuffixStr = [imageName substringFromIndex:imageSuffixRange.location + 1];
            }
            /*
             如果是GIF并且为不可编辑的情况下，就镶嵌一个透明的图。
             以大部分需求来看，GIF图只是在纯显示的情况下才能显示，如果是编辑状态下，还是只显示静态图就行了。
             */
            UIImage *image;
            if ([imageSuffixStr isEqualToString:@"gif"] && !self.editable) {
                image = [UIImage imageNamed:@"transparent"];
            }else{
                image = [UIImage imageNamed:imageName];
            }
            
            WBTextAttachment *attachment = [[WBTextAttachment alloc] initWithData:nil ofType:nil];
            attachment.size = _attributesFont.pointSize;
            attachment.image = image;
            NSAttributedString *attachmentStr = [NSAttributedString attributedStringWithAttachment:attachment];
            [self replaceCharactersInRange:range withAttributedString:attachmentStr];
            
            NSRange attachmentRange = NSMakeRange(range.location, 1);
            NSString *attachmentRangeStr = NSStringFromRange(attachmentRange);
            [_attachmentRangeArray addObject:attachmentRangeStr];
            [self sortedAttachmentRangeArray];
            [_attachmentDictionary setObject:emojiKey forKey:attachmentRangeStr];
            
            //先排序再处理
            [self sortedRangesOfKeyWords];
            int updateIndex = 0;
            NSMutableArray *updateArray = [[NSMutableArray alloc]init];
            for (NSDictionary *dictionary in _rangesOfKeyWords) {
                NSRange keyWordsRange = [[dictionary objectForKey:KeyRange] rangeValue];
                if (keyWordsRange.location > range.location) {
                    NSInteger decrement = emojiKey.length;
                    NSRange updateRange = NSMakeRange(keyWordsRange.location - decrement + 1, keyWordsRange.length);
                    NSMutableDictionary *updateDic = [[NSMutableDictionary alloc]initWithDictionary:dictionary];
                    [updateDic setObject:[NSValue valueWithRange:updateRange] forKey:KeyRange];
                    [updateArray addObject:updateDic];
                }else{
                    updateIndex++;
                }
            }
            
            //更新需要更新的对象
            [_rangesOfKeyWords removeObjectsInRange:NSMakeRange(updateIndex, _rangesOfKeyWords.count - updateIndex)];
            [_rangesOfKeyWords addObjectsFromArray:updateArray];
            
        }
    }
}

#pragma mark -----------------------------------AttachmentRangeArray排序
- (void)sortedAttachmentRangeArray
{
    NSComparator cmptr = ^(id obj1, id obj2){
        if (NSRangeFromString(obj1).location > NSRangeFromString(obj2).location) {
            return (NSComparisonResult)NSOrderedDescending;
        }
        
        if (NSRangeFromString(obj1).location < NSRangeFromString(obj2).location) {
            return (NSComparisonResult)NSOrderedAscending;
        }
        return (NSComparisonResult)NSOrderedSame;
    };
    NSArray *sortedArray = [_attachmentRangeArray sortedArrayUsingComparator:cmptr];
    [_attachmentRangeArray removeAllObjects];
    [_attachmentRangeArray addObjectsFromArray:sortedArray];
}

#pragma mark -----------------------------------RangesOfKeyWords排序
- (void)sortedRangesOfKeyWords
{
    NSComparator cmptr = ^(id obj1, id obj2){
        if ([[obj1 objectForKey:KeyRange] rangeValue].location > [[obj2 objectForKey:KeyRange] rangeValue].location) {
            return (NSComparisonResult)NSOrderedDescending;
        }
        
        if ([[obj1 objectForKey:KeyRange] rangeValue].location < [[obj2 objectForKey:KeyRange] rangeValue].location) {
            return (NSComparisonResult)NSOrderedAscending;
        }
        return (NSComparisonResult)NSOrderedSame;
    };
    NSArray *sortedArray = [_rangesOfKeyWords sortedArrayUsingComparator:cmptr];
    [_rangesOfKeyWords removeAllObjects];
    [_rangesOfKeyWords addObjectsFromArray:sortedArray];
}

#pragma mark -----------------------------------刷新
- (void)updateText
{
    //设置一下普通文本
    NSAttributedString *attributedString = [self attributedSubstringFromRange:NSMakeRange(0, self.string.length)];
    [attributedString enumerateAttributesInRange:NSMakeRange(0, attributedString.length) options:0 usingBlock:^(NSDictionary *attrs, NSRange range, BOOL *stop) {
        if (![attrs objectForKey:NSAttachmentAttributeName]) {
            [self setAttributes:_attributesText range:range];
        }
    }];

    //设置特殊文本
    for (NSDictionary *dictionary in _rangesOfKeyWords)  {
        NSRange range = [[dictionary objectForKey:KeyRange] rangeValue];
        WBTextKeyWord keyWord = (WBTextKeyWord)[[dictionary objectForKey:KeyWord] intValue];
        
        if (keyWord == WBTextKeyWordLink) {
            [self setAttributes:[dictionary objectForKey:UrlAttributes] range:range];
        }else{
            [self setAttributes:[self attributesForKeyWord:keyWord] range:range];
        }
    }
}

#pragma mark -----------------------------------文本属性
- (NSDictionary *)attributesForKeyWord:(WBTextKeyWord)keyWord {
    switch (keyWord) {
        case WBTextKeyWordAt:
            return _attributesAt;
            break;
        case WBTextKeyWordPound:
            return _attributesPound;
            break;
        default:
            return _attributesText;
            break;
    }
}

#pragma mark -----------------------------------增加处理
- (void)addInRange:(NSRange)range andText:(NSString *)string
{
    NSLog(@"增加的内容：%@",string);
    NSLog(@"增加的范围：%@",NSStringFromRange(range));
    
    //总共增加的字符串长度
    NSInteger addLength = string.length;
    NSRegularExpression *exp_emoji =
    [[NSRegularExpression alloc] initWithPattern:EmojiRegex
                                         options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
                                           error:nil];
    NSArray *emojis = [exp_emoji matchesInString:string
                                         options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
                                           range:NSMakeRange(0, string.length)];
    //如果字符串中有表情，需要换算成表情的长度
    for (NSTextCheckingResult *emojiResult in emojis) {
        NSRange range = emojiResult.range;
        NSString *emojiKey = [string substringWithRange:range];
        
        addLength = addLength - emojiKey.length + 1;
    }
    _selectedRangeLocation = 0;
    NSLog(@"增加的长度为：%ld",(long)addLength);
    _selectedRangeLocation = range.location + addLength;
    NSLog(@"光标起始位置为：%ld",(long)_selectedRangeLocation);
    
    NSLog(@"增加前：");
    NSLog(@"数组：%@",_attachmentRangeArray);
    NSLog(@"字典：%@",_attachmentDictionary);
    NSInteger updateAttributeInArrayIndex = 0;
    
    for (NSString *updateRangeStr in _attachmentRangeArray) {
        NSRange updateRange = NSRangeFromString(updateRangeStr);
        if(range.location < updateRange.location || range.location == updateRange.location){
            break;
        }
        updateAttributeInArrayIndex++;
    }
    NSLog(@"需要修改的对象下标：%li",(long)updateAttributeInArrayIndex);
    
    //如果为最后一个对象则直接删除，不需要处理
    if (updateAttributeInArrayIndex < _attachmentRangeArray.count) {
        //取得必须要改变的附件对象的范围
        NSRange mustChangeAttributesInArrayRange = NSMakeRange(updateAttributeInArrayIndex, _attachmentRangeArray.count - updateAttributeInArrayIndex);
        NSLog(@"需要修改的对象范围：%@",NSStringFromRange(mustChangeAttributesInArrayRange));
        //取得必须要改变的附件对象的集合
        NSArray *updateAttributesInArray = [_attachmentRangeArray subarrayWithRange:mustChangeAttributesInArrayRange];
        NSLog(@"需要修改的对象集合：%@",updateAttributesInArray);
        //取得所有对象对应的值集合
        NSMutableArray *updateDicValue = [[NSMutableArray alloc]init];
        for (NSString *updateRangeStr in _attachmentRangeArray) {
            [updateDicValue addObject:[_attachmentDictionary objectForKey:updateRangeStr]];
        }
        NSLog(@"所有对象对应的值集合：%@",updateAttributesInArray);
        
        //移除需要改变的对象
        [_attachmentRangeArray removeObjectsInArray:updateAttributesInArray];
        
        //重新增加改变后的对象
        for (NSString *updateRangeStr in updateAttributesInArray) {
            NSRange updateRange = NSRangeFromString(updateRangeStr);
            NSRange newRange = NSMakeRange(updateRange.location + addLength, updateRange.length);
            //为数组增加
            [_attachmentRangeArray addObject:NSStringFromRange(newRange)];
        }
        
        //重新排列字典
        [_attachmentDictionary removeAllObjects];
        for (int i = 0; i < _attachmentRangeArray.count; i++) {
            [_attachmentDictionary setObject:[updateDicValue objectAtIndex:i] forKey:[_attachmentRangeArray objectAtIndex:i]];
        }
    }
    
    NSLog(@"增加后：");
    NSLog(@"数组：%@",_attachmentRangeArray);
    NSLog(@"字典：%@",_attachmentDictionary);
}

#pragma mark -----------------------------------删除处理
- (void)removeAttachmentDictionaryInRange:(NSRange)range
{
    NSAttributedString *attributedString = [self attributedSubstringFromRange:range];
    if ([self isEmoji:[attributedString string]]) {
        return;
    }
    NSMutableArray *removeAttachmentRangeArray = [[NSMutableArray alloc]init];
    NSMutableArray *removeTextRangeArray = [[NSMutableArray alloc]init];
    
    [attributedString enumerateAttributesInRange:NSMakeRange(0, attributedString.length) options:0 usingBlock:^(NSDictionary *attrs, NSRange attributedRange, BOOL *stop) {
        
        if ([attrs objectForKey:NSAttachmentAttributeName]) {
            [removeAttachmentRangeArray addObject:NSStringFromRange(attributedRange)];
        }else{
            [removeTextRangeArray addObject:NSStringFromRange(attributedRange)];
        }
    }];
    
    NSLog(@"删除前：");
    NSLog(@"数组：%@",_attachmentRangeArray);
    NSLog(@"字典：%@",_attachmentDictionary);
    
    //附本处理
    NSMutableArray *removeAttachmentRanges = [[NSMutableArray alloc]init];
    
    int i = 0;
    for (NSString *removeRangeStr in removeAttachmentRangeArray) {
        NSLog(@"附本处理:%@",removeRangeStr);
        
        NSRange removeRange = NSRangeFromString(removeRangeStr);
        //计算出需要移除的附件在全文中的范围
        NSRange removeAttachmentRange = NSMakeRange(range.location + removeRange.location, removeRange.length);
        [removeAttachmentRanges addObject:NSStringFromRange(removeAttachmentRange)];
        
        //得到需要更新的附本下标起始位置
        NSInteger updateAttributeInArrayIndex = [self moveAttachments:removeAttachmentRange];
        
        NSString *removeRangeString = [[_attachmentRangeArray subarrayWithRange:NSMakeRange(updateAttributeInArrayIndex - 1, 1)] objectAtIndex:0];
        if (_attachmentRangeArray.count == _attachmentDictionary.count) {
            [_attachmentDictionary removeObjectForKey:removeRangeString];
        }
        [_attachmentRangeArray removeObjectsInRange:NSMakeRange(updateAttributeInArrayIndex - 1, 1)];
        i++;
    }
    
    NSLog(@"附本处理后：");
    NSLog(@"数组：%@",_attachmentRangeArray);
    NSLog(@"字典：%@",_attachmentDictionary);
    
    //普通文字处理
    for (NSString *removeRangeStr in removeTextRangeArray) {
        NSLog(@"文字处理:%@",removeRangeStr);
        NSRange removeRange = NSRangeFromString(removeRangeStr);
        
        //计算出需要移除的附件在全文中的范围
        NSRange removeTextRange = NSMakeRange(range.location + removeRange.location, removeRange.length);
        
        //移动附本位置
        [self moveAttachments:removeTextRange];
    }
    
    NSLog(@"文字处理后：");
    NSLog(@"数组：%@",_attachmentRangeArray);
    NSLog(@"字典：%@",_attachmentDictionary);
}

#pragma mark -----------------------------------根据需要删除的对象的位置来移动附本对象在容器中的位置
- (NSInteger)moveAttachments:(NSRange)removeRange
{
    NSInteger updateAttributeInArrayIndex = 0;
    
    for (NSString *updateRangeStr in _attachmentRangeArray) {
        NSRange updateRange = NSRangeFromString(updateRangeStr);
        if(removeRange.location < updateRange.location){
            break;
        }
        updateAttributeInArrayIndex++;
    }
    
    NSLog(@"需要修改的对象下标：%li",(long)updateAttributeInArrayIndex);
    
    //如果为最后一个对象则直接删除，不需要处理附本对象
    if (updateAttributeInArrayIndex < _attachmentRangeArray.count) {
        
        //因为移除的附件如果在另外的附件前面，后面的附件的为范围Location也需要更新，所以在这里取得必须要改变的附件对象的范围
        NSRange mustChangeAttributesInArrayRange = NSMakeRange(updateAttributeInArrayIndex, _attachmentRangeArray.count - updateAttributeInArrayIndex);
        
        NSLog(@"需要修改的对象范围：%@",NSStringFromRange(mustChangeAttributesInArrayRange));
        //取得必须要改变的附件对象的集合
        NSArray *updateAttributesInArray = [_attachmentRangeArray subarrayWithRange:mustChangeAttributesInArrayRange];
        NSLog(@"需要修改的对象集合：%@",updateAttributesInArray);
        
        //移除需要改变的对象
        [_attachmentRangeArray removeObjectsInArray:updateAttributesInArray];
        
        //重新增加改变后的对象
        for (NSString *updateRangeStr in updateAttributesInArray) {
            NSRange updateRange = NSRangeFromString(updateRangeStr);
            NSRange newRange = NSMakeRange(updateRange.location - removeRange.length, updateRange.length);
            //为数组增加
            [_attachmentRangeArray addObject:NSStringFromRange(newRange)];
            
            //为字典增加
            NSString *attachmentKey = [_attachmentDictionary objectForKey:updateRangeStr];
            [_attachmentDictionary removeObjectForKey:updateRangeStr];
            [_attachmentDictionary setObject:attachmentKey forKey:NSStringFromRange(newRange)];
        }
    }
    return updateAttributeInArrayIndex;
}

#pragma mark **************************************************************************************************************************
#pragma mark -----------------------------------供其他控件使用的方法-----------------------------------
#pragma mark **************************************************************************************************************************
#pragma mark -----------------------------------是否为表情标示
- (BOOL)isEmoji:(NSString *)text
{
    if (text.length == 0) {
        return NO;
    }
    
    NSRegularExpression *exp_emoji =
    [[NSRegularExpression alloc] initWithPattern:EmojiRegex
                                         options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
                                           error:nil];
    
    NSInteger count = [exp_emoji numberOfMatchesInString:text options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators range:NSMakeRange(0, text.length)];
    
    if (count > 0) {
        return YES;
    }else{
        return NO;
    }
}

#pragma mark -----------------------------------是否为GIF表情
- (NSString *)isGifEmoji:(NSString *)text
{
    if (text.length == 0) {
        return nil;
    }
    NSString *imageName = [_emojiDictionary objectForKey:text];
    
    //取得.的位置
    NSRange imageSuffixRange = [imageName rangeOfString:@"."];
    NSString *imageSuffixStr = @"";
    if (imageSuffixRange.location != NSNotFound) {
        imageSuffixStr = [imageName substringFromIndex:imageSuffixRange.location + 1];
    }
    
    if ([imageSuffixStr isEqualToString:@"gif"]) {
        return imageName;
    }else{
        return nil;
    }
}

#pragma mark -----------------------------------重新设置文本大小
- (void)reSetTextAttributesFont
{
    _attributesText = @{NSForegroundColorAttributeName: TextColor, NSFontAttributeName: _attributesFont};//普通文本属性
    _attributesAt = @{NSForegroundColorAttributeName: AtColor, NSFontAttributeName: _attributesFont};//@文本属性
    _attributesPound = @{NSForegroundColorAttributeName: PoundColor, NSFontAttributeName: _attributesFont};//#文本属性
    _attributesLink = @{NSFontAttributeName: _attributesFont};//HTTP链接文本属性
}

#pragma mark -----------------------------------得到纯文本内容
- (NSString *)getPlainText
{
    NSMutableString *text = [[NSMutableString alloc]initWithString:[self string]];
    NSLog(@"没有还原的纯文本为：%@",text);
    NSLog(@"当前附本数组：%@",_attachmentDictionary);
    NSLog(@"当前附本字典：%@",_attachmentRangeArray);
    
    //先排序，防止顺序不对的情况
    [self sortedAttachmentRangeArray];
    
    NSInteger addLength = 0;
    for (NSString *attachmentRangeStr in _attachmentRangeArray) {
        NSRange attachmentRange = NSRangeFromString(attachmentRangeStr);
        NSString *attachmentValue = [_attachmentDictionary objectForKey:attachmentRangeStr];
        NSRange newAttachmentRange = NSMakeRange(attachmentRange.location + addLength, attachmentValue.length);
        [text insertString:attachmentValue atIndex:newAttachmentRange.location];
        addLength += attachmentValue.length;
    }
    
    NSLog(@"还原后的纯文本为：%@",text);
    return text;
}
@end
