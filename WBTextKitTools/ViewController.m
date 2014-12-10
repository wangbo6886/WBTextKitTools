//
//  ViewController.m
//  WBTextKitTools
//
//  Created by mc on 14/11/20.
//  Copyright (c) 2014年 WB. All rights reserved.
//

#import "ViewController.h"
#import "WBTextStorage.h"
#import "WBTextView.h"

@interface ViewController (){
    WBTextStorage *_wbTextStorage;
    WBTextView *_textView;
}

@end

@implementation ViewController


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    UIBarButtonItem *rightItem = [[UIBarButtonItem alloc] initWithTitle:@"表情"
                                                                  style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(faceKeyboardShow)];
    self.navigationItem.rightBarButtonItem = rightItem;
    
    _textView = [[WBTextView alloc]initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 200) textContainer:nil];                                                                                             ;
    _textView.backgroundColor = [UIColor yellowColor];
    _textView.editable = NO;
    _textView.font = [UIFont fontWithName:@"HelveticaNeue" size:16.0];
    _textView.delegate = self;
    //注意先后关系，文本必须在最后设置
    _textView.text = @"[001][亲一口][熊猫][002]@123@456#789 https://www.baidu.com 爱 [熊猫][001]@001#002 abcdefg http://www.qq.com [拜拜][拳头][haha][书呆子][orz]";
    [self.view addSubview:_textView];
    
    //这里是点击特殊字符后要做的事情
    [_textView setDetectionBlock:^(WBTextKeyWord hotWord, NSString *string, NSString *protocol, NSRange range) {
        NSArray *hotWords = @[@"WBTextKeyWordAt", @"WBTextKeyWordPound"];
        NSString *myString = [NSString stringWithFormat:@"%@ [%d,%d]: %@%@", hotWords[hotWord], (int)range.location, (int)range.length, string, (protocol != nil) ? [NSString stringWithFormat:@" *%@*", protocol] : @""];
        NSLog(@"%@",myString);
    }];
    
    UITextView *view = [[UITextView alloc]initWithFrame:CGRectMake(0, 210 - 64, self.view.frame.size.width, 100)];
    view.text = _textView.text;
    view.backgroundColor = [UIColor grayColor];
    [self.view addSubview:view];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)faceKeyboardShow
{
    [_textView resignFirstResponder];
    [_textView insertText:@"[001]"];
}
@end
