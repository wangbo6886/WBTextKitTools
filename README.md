WBTextKitTools
==============
###  简介：
	一个基于TextKit的自定义UITextView控件，支持自定义静态和GIF动态表情，支持选择复制粘贴表情，支持输入时直接显示表情。

###  使用：
	请下载后，参照例子使用。

###  注意：
	1、IOS7以上才能使用；
	2、GIF的显示是使用的YLGIFImage，请git自行查找；
	3、在开发的过程中借鉴过一些微博的文章以及STTweetLabel、CoreTextDemo_iOS7-master。
	
###  已发现的问题：
	1、GIF表情显示存在效率问题，多个GIF表情的情况下，会出现卡顿；
	2、URL的识别依然存在缺陷，正则表达式是在STTweetLabel截取的；
	3、附本表情，删除时内存并没有释放？（不知道是否是没有及时释放）
	4、表情选择器存在IPHONE6的适配问题。
