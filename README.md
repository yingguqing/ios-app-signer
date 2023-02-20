# iOS App Signer
这是一个在MacOS上运行的重签名工具，个人定制了部分功能。

fork于[ios-app-signer](https://github.com/DanTheMan827/ios-app-signer)。

感谢原作者的分享。

## 定制功能

1. 删除了更新功能，有需要再更新。
2. 添加描述文件tips中关于包含证书的说明
3. 选择描述文件时，如果当前选择的证书不包含在描述文件中时，会自动选择本地有并包含在描述文件中的第一个证书
4. 取消勾选`No get-task-allow`
