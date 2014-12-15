//
//  WBFaceView.h
//  WBTextKitTools
//
//  Created by mc on 14/12/11.
//  Copyright (c) 2014年 WB. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol WBFaceDelegate <NSObject>
@optional
- (void)insertFaceWithKey:(NSString *)faceKey;
- (void)deleteFace;
@end


@interface WBFaceView : UIView<UIScrollViewDelegate>

@property (weak, nonatomic) IBOutlet UIScrollView *faceScroll;
@property (weak, nonatomic) IBOutlet UIPageControl *pageController;
@property (weak, nonatomic) IBOutlet UIButton *historyButton;
@property (weak, nonatomic) IBOutlet UIButton *classicButton;
@property (weak, nonatomic) id<WBFaceDelegate> faceDelegate;

- (IBAction)historyButtonClick:(UIButton *)sender;
- (IBAction)classicButtonClick:(UIButton *)sender;

@end
