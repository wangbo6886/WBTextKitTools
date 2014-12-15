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
#import "WBFaceView.h"

@interface ViewController (){
    WBTextStorage *_wbTextStorage;
    WBTextView *_textView;
    WBTextView *_noEditableTextView;
    WBFaceView *_faceView;
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
    
    //editable = YES
    UILabel *editableLabel = [[UILabel alloc]initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 20)];
    editableLabel.text = @"编辑用：";
    [self.view addSubview:editableLabel];
    
    _textView = [[WBTextView alloc]initWithFrame:CGRectMake(0, editableLabel.frame.size.height + 10, self.view.frame.size.width, 150) textContainer:nil];
    _textView.editable = YES;
    _textView.backgroundColor = [UIColor yellowColor];
    _textView.font = [UIFont fontWithName:@"HelveticaNeue" size:17.0];
    _textView.delegate = self;
    //注意先后关系，文本必须在最后设置
    _textView.text = @"可以写入@123#456 以及网址 http://www.baidu.com [001][002]等内容。。。";
    [self.view addSubview:_textView];
    
    //editable = NO
    UILabel *noEditableLabel = [[UILabel alloc]initWithFrame:CGRectMake(0, _textView.frame.origin.y + _textView.frame.size.height + 10 - 64, self.view.frame.size.width, 20)];
    noEditableLabel.text = @"显示用：";
    [self.view addSubview:noEditableLabel];
    
    _noEditableTextView = [[WBTextView alloc]initWithFrame:CGRectMake(0, noEditableLabel.frame.origin.y + noEditableLabel.frame.size.height + 10, self.view.frame.size.width, 150)];
    _noEditableTextView.editable = NO;
    _noEditableTextView.backgroundColor = [UIColor whiteColor];
    _noEditableTextView.font = [UIFont fontWithName:@"HelveticaNeue" size:17.0];
    _noEditableTextView.text = _textView.text;
    [self.view addSubview:_noEditableTextView];
    
    //这里是点击特殊字符后要做的事情
    [_noEditableTextView setDetectionBlock:^(WBTextKeyWord hotWord, NSString *string, NSString *protocol, NSRange range) {
        NSArray *hotWords = @[@"WBTextKeyWordAt", @"WBTextKeyWordPound"];
        NSString *myString = [NSString stringWithFormat:@"%@ [%d,%d]: %@%@", hotWords[hotWord], (int)range.location, (int)range.length, string, (protocol != nil) ? [NSString stringWithFormat:@" *%@*", protocol] : @""];
        NSLog(@"%@",myString);
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark -----------------------------------表情键盘
- (void)faceKeyboardShow
{
    [_textView resignFirstResponder];
    
    if (!_faceView) {
        _faceView = [[WBFaceView alloc]initWithFrame:CGRectMake(0, self.view.frame.size.height - 223, _faceView.frame.size.width, _faceView.frame.size.height)];
        _faceView.faceDelegate = _textView;
        [self.view addSubview:_faceView];
    }else{
        [_faceView removeFromSuperview];
        _faceView = nil;
    }
}

- (void)textViewDidChange:(UITextView *)textView
{
    _noEditableTextView.text = _textView.text;
}
@end
