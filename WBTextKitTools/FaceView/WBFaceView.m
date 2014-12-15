//
//  WBFaceView.m
//  WBTextKitTools
//
//  Created by mc on 14/12/11.
//  Copyright (c) 2014年 WB. All rights reserved.
//

#import "WBFaceView.h"
#define RGBColor(r, g, b) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:1.0]
#define HistoryFace @"historyFace"
#define HistoryFaces [[NSUserDefaults standardUserDefaults]objectForKey:HistoryFace]
#define FaceLeftSign @"["
#define FaceRightSign @"]"

#define RowMaxFaceCount 7
#define PageMaxFaceConut 20
#define Item 15.5
#define FaceWidth 28.0
#define FaceHeight 28.0

@implementation WBFaceView{
    NSMutableArray *_faces;
    NSMutableDictionary *_faceDictionary;
    NSInteger _numberOfPages;
}

#pragma mark -----------------------------------初始化
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // 初始化加载xib文件
        NSArray *arrayOfViews = [[NSBundle mainBundle] loadNibNamed:@"WBFaceView" owner:self options:nil];
        
        // 如果路径不存在，return nil
        if (arrayOfViews.count < 1)
        {
            return nil;
        }
        // 加载nib
        CGRect myRect = CGRectZero;
        myRect.origin = self.frame.origin;
        self = [arrayOfViews objectAtIndex:0];
        myRect.size = self.frame.size;
        self.frame = myRect;
        
        [self initScorll];
        [self initTabBar];
        [self setPageController];
    }
    
    return self;
}

#pragma mark -----------------------------------初始化Scorll
- (void)initScorll
{
    //表情集合
    NSString *emojiFilePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"emotionGifImage.plist"];
    _faceDictionary = [[NSMutableDictionary alloc] initWithContentsOfFile:emojiFilePath];
    _faces = [[NSMutableArray alloc]init];
    
    //不设置为NO的话，会导致BUTTON延迟高亮
    _faceScroll.delaysContentTouches = NO;
    _faceScroll.delegate = self;
}

#pragma mark -----------------------------------初始化TabBar
- (void)initTabBar
{
    [self historyButtonClick:_historyButton];
}

#pragma mark -----------------------------------设置页数
- (void)setnumberOfPages
{
    NSInteger faceCount = _faces.count;
    _numberOfPages = faceCount / PageMaxFaceConut;
    if (faceCount % PageMaxFaceConut != 0) {
        _numberOfPages++;
    }
    //计算ScroollView需要的大小
    _faceScroll.contentSize = CGSizeMake(self.frame.size.width * _numberOfPages, _faceScroll.bounds.size.height);
}

#pragma mark -----------------------------------设置PageController
- (void)setPageController
{
    [self setnumberOfPages];
    _pageController.numberOfPages = _numberOfPages; //设置页数
    _pageController.currentPage = 0; //初始页码为 0
}

#pragma mark -----------------------------------重载FaceScroll
- (void)resetFaceScroll
{
    //清空原有的视图
    for (UIView *view in _faceScroll.subviews) {
        if ([view isKindOfClass:[UIImageView class]] || [view isKindOfClass:[UIButton class]]) {
            [view removeFromSuperview];
        }
    }
    
    [self setPageController];
    [self loadFace];
}

#pragma mark -----------------------------------加载表情
- (void)loadFace
{
    int row = 1;//行
    int column = 1;//列
    int page = 0;//页
    int i = 1;//循环临时变量
    int count = 0;//当前循环的次数
    
    if (_classicButton.selected) {
        [self sortedFaceArray];
    }
    
    for (NSString *faceKey in _faces) {
        NSString *faceValue = [_faceDictionary objectForKey:faceKey];
        UIImageView *faceImageView = [[UIImageView alloc]initWithFrame:CGRectMake(self.frame.size.width * page + FaceWidth * (column - 1) + Item * column, FaceHeight * (row - 1) + Item * row, FaceWidth, FaceHeight)];
        faceImageView.userInteractionEnabled = YES;
        faceImageView.accessibilityIdentifier = faceKey;
        faceImageView.image = [UIImage imageNamed:faceValue];
        [_faceScroll addSubview:faceImageView];
        
        UITapGestureRecognizer *singeTap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(insertFace:)];
        singeTap.numberOfTapsRequired = 1;
        [faceImageView addGestureRecognizer:singeTap];
        
        //计算行列
        if (column % RowMaxFaceCount == 0) {
            row++;
            column = 1;
        }else{
            column++;
        }
        
        if (page == _numberOfPages - 1 && count == _faces.count - 1 && i % PageMaxFaceConut != 0) {
            UIButton *delbutton = [UIButton buttonWithType:UIButtonTypeCustom];
            [delbutton addTarget:self action:@selector(deleteFace:) forControlEvents:UIControlEventTouchUpInside];
            [delbutton setImage:[UIImage imageNamed:@"face_delete"] forState:UIControlStateNormal];
            [delbutton setImage:[UIImage imageNamed:@"face_delete_pressed"] forState:UIControlStateHighlighted];

            if (column == 1) {
                delbutton.frame = CGRectMake(self.frame.size.width * page + FaceWidth * (column - 1) + Item * column, FaceHeight * (row - 1) + Item * row, FaceWidth, FaceHeight);
            }else{
                delbutton.frame = CGRectMake(faceImageView.frame.origin.x + FaceWidth + Item, faceImageView.frame.origin.y, FaceWidth, FaceHeight);
            }
            [_faceScroll addSubview:delbutton];
        }else if (i % PageMaxFaceConut == 0){
            //计算页
            UIButton *delbutton = [UIButton buttonWithType:UIButtonTypeCustom];
            [delbutton addTarget:self action:@selector(deleteFace:) forControlEvents:UIControlEventTouchUpInside];
            [delbutton setImage:[UIImage imageNamed:@"face_delete"] forState:UIControlStateNormal];
            [delbutton setImage:[UIImage imageNamed:@"face_delete_pressed"] forState:UIControlStateHighlighted];
            delbutton.frame = CGRectMake(faceImageView.frame.origin.x + FaceWidth + Item, faceImageView.frame.origin.y, FaceWidth, FaceHeight);
            [_faceScroll addSubview:delbutton];
            
            row = 1;
            column = 1;
            i = 1;
            page++;
        }else{
            i++;
        }
        count++;
    }
}

#pragma mark -----------------------------------点击表情
- (void)insertFace:(UIGestureRecognizer *)gesture
{
    UIImageView *myFaceView = (UIImageView *)gesture.view;
    NSString *faceKey = myFaceView.accessibilityIdentifier;
    if ([_faceDelegate respondsToSelector:@selector(insertFaceWithKey:)] && ![faceKey isEqual:@""] && faceKey != nil) {
        [_faceDelegate insertFaceWithKey:faceKey];
        [self insertFaceInHistoryFace:faceKey];
    }
}

#pragma mark -----------------------------------添加历史表情
- (void)insertFaceInHistoryFace:(NSString *)faceKey
{
    if (_historyButton.selected) {
        return;
    }
    
    NSMutableArray *historys = [[NSMutableArray alloc]initWithArray:HistoryFaces];
    for (NSString *historyFaceKey in historys) {
        if ([historyFaceKey isEqualToString:faceKey]) {
            [historys removeObject:faceKey];
            break;
        }
    }
    
    [historys insertObject:faceKey atIndex:0];
    [[NSUserDefaults standardUserDefaults]setObject:historys forKey:HistoryFace];
    [[NSUserDefaults standardUserDefaults]synchronize];
}

#pragma mark -----------------------------------滑动响应
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if(scrollView == _faceScroll){
        CGPoint offset = scrollView.contentOffset;
        _pageController.currentPage = offset.x / (self.bounds.size.width); //计算当前的页码
        [_faceScroll setContentOffset:CGPointMake(self.bounds.size.width * (_pageController.currentPage),_faceScroll.contentOffset.y) animated:YES]; //设置scrollview的显示为当前滑动到的页面
    }
}

#pragma mark -----------------------------------点击历史表情
- (IBAction)historyButtonClick:(UIButton *)sender
{
    _historyButton.selected = YES;
    _historyButton.backgroundColor = RGBColor(212, 230, 246);
    
    _classicButton.selected = NO;
    _classicButton.backgroundColor = [UIColor whiteColor];
    
    [_faces removeAllObjects];
    [_faces addObjectsFromArray:HistoryFaces];
    [self resetFaceScroll];
}

#pragma mark -----------------------------------点击经典表情
- (IBAction)classicButtonClick:(UIButton *)sender
{
    _classicButton.selected = YES;
    _classicButton.backgroundColor = RGBColor(212, 230, 246);
    
    _historyButton.selected = NO;
    _historyButton.backgroundColor = [UIColor whiteColor];
    
    [_faces removeAllObjects];
    [_faces addObjectsFromArray:_faceDictionary.allKeys];
    [self resetFaceScroll];
}

#pragma mark -----------------------------------删除表情
- (void)deleteFace:(UIButton *)sender
{
    if ([_faceDelegate respondsToSelector:@selector(deleteFace)]) {
        [_faceDelegate deleteFace];
    }
}

#pragma mark -----------------------------------表情数组排序
- (void)sortedFaceArray
{
    NSComparator cmptr = ^(NSString *obj1, NSString *obj2){
        obj1 = [self numberFaceKey:obj1];
        obj2 = [self numberFaceKey:obj2];
        
        if ([obj1 integerValue] > [obj2 integerValue]) {
            return (NSComparisonResult)NSOrderedDescending;
        }
        
        if ([obj1 integerValue] < [obj2 integerValue]) {
            return (NSComparisonResult)NSOrderedAscending;
        }
        return (NSComparisonResult)NSOrderedSame;
    };
    NSArray *sortedArray = [_faces sortedArrayUsingComparator:cmptr];
    [_faces removeAllObjects];
    [_faces addObjectsFromArray:sortedArray];
}

#pragma mark -----------------------------------去掉表情KEY的左右特殊符号
- (NSString *)numberFaceKey:(NSString *)faceKey
{
    NSRange obj1LeftSignRange = [faceKey rangeOfString:FaceLeftSign];
    if (obj1LeftSignRange.location != NSNotFound) {
        faceKey = [faceKey substringFromIndex:obj1LeftSignRange.location + 1];
    }
    
    NSRange obj1RightSignRange = [faceKey rangeOfString:FaceRightSign];
    if (obj1RightSignRange.location != NSNotFound) {
        faceKey = [faceKey substringToIndex:obj1RightSignRange.location];
    }
    
    return faceKey;
}
@end
