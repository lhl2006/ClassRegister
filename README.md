# ClassRegister

一个面向 iOS 17+ 的极简课堂图片登记 App，支持拍照、导入、按天归档浏览与全屏预览。

## 项目简介

ClassRegister 聚焦最小可用闭环：

- 拍照后自动保存到 App 内部存储。
- 支持从系统相册导入图片并按拍摄日期归档。
- 以用户本地时区自然日进行分组浏览。
- 提供全屏预览、保存到系统相册与 App 内删除能力。

## 功能清单

- 首页按本地自然日分组展示照片（例如 `2026-03-02`）。
- 拍照后自动保存到 App 内部（不自动写入系统相册）。
- 支持从系统相册多选导入。
- 导入时间解析规则：优先 `PHAsset.creationDate`，其次 EXIF；缺失时间时统一手动选择日期。
- 当天详情页使用网格展示所有照片。
- 预览页支持左右滑动浏览同一天照片。
- 预览页支持单张保存到系统相册。
- 详情页与预览页都支持删除（仅 App 内删除，更新索引）。

## 技术栈

- `SwiftUI`
- `SwiftData`
- `UIImagePickerController`（拍照）
- `PHPickerViewController`（相册导入）
- `PhotoKit`（保存到系统相册）
- 文件系统存储：`Application Support/ClassRegisterPhotos`

## 环境要求

- iOS 17.0+
- Xcode 15+（建议使用可构建 iOS 17 目标的版本）
- 设备范围：iPhone / iPad

## 快速开始

1. 克隆仓库并进入目录：

```bash
git clone <your-repo-url>
cd ClassRegister
```

2. 用 Xcode 打开工程：

```bash
open ClassRegister.xcodeproj
```

3. 选择 `ClassRegister` scheme 并运行：
- 真机：可完整测试拍照 + 导入 + 保存到系统相册。
- 模拟器：通常无法测试拍照，建议测试导入与浏览流程。

4. 命令行构建示例：

```bash
xcodebuild -scheme ClassRegister -destination 'generic/platform=iOS Simulator' build
```

## 权限说明

项目会使用以下权限：

- 相机权限：用于拍照。
- 相册读取权限：用于从系统相册导入图片。
- 相册写入权限：用于将当前预览图片保存到系统相册。

用户拒绝权限后，应用会提示失败原因，并提供跳转系统设置入口。

## 数据模型与存储

### SwiftData 模型

`PhotoRecord` 字段：

- `id: UUID`（唯一标识）
- `createdAt: Date`（用于按天分组）
- `fileName: String`（本地文件名）

### 图片存储

- 格式：`JPEG`
- 压缩质量：`0.9`
- 文件名：`UUID.jpg`
- 存储位置：`Application Support/ClassRegisterPhotos`

### 分组规则

- 按用户本地时区自然日分组（`00:00 ~ 23:59`）。
- 首页按日期倒序展示分组。

## 目录结构

```text
ClassRegister/
├── ClassRegisterApp.swift        # App 入口与 SwiftData 容器注入
├── Models/                       # 数据模型与视图快照模型
├── Services/                     # 文件存储、导入、权限、系统相册保存
├── Views/                        # 页面视图
│   └── Pickers/                  # 相机/相册选择器包装
├── ViewModels/                   # 页面状态管理
└── Utils/                        # 错误定义、日期分组工具
```

主要类/结构体：

- `PhotoImportService`
- `PhotoFileStore`
- `PhotoPermissionService`
- `SystemAlbumService`
- `HomeView`
- `DayDetailView`
- `PhotoPreviewPagerView`

## 主要流程

### 拍照流程

权限检查 -> 打开系统相机 -> 拍照 -> 写入沙盒文件 -> 写入 `PhotoRecord` -> 首页刷新。

### 导入流程

多选导入 -> 解析创建时间（`PHAsset` / EXIF）-> 对缺失时间项统一补日期 -> 写入沙盒与索引 -> 首页刷新。

### 删除流程

删除图片文件 -> 删除 SwiftData 记录。

- 若文件已不存在：仍删除索引，并提示“已仅删除本地索引”。

## 已知限制

- 当前不做重复图片去重。
- 当前不支持 iCloud 同步或云端上传。
- 当前没有自动化测试（仅手工验证流程）。
- 当前 UI 文案为中文硬编码，未接入本地化资源文件。

## 后续可扩展方向

- 增加缩略图磁盘缓存与预加载策略。
- 增加批量操作（批量删除、批量导出/保存）。
- 补齐本地化与自动化测试（单测/UI 测试）。

