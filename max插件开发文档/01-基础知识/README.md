# 3ds Max 插件开发基础知识

## 目录

- [开发环境搭建](#开发环境搭建)
- [插件类型概述](#插件类型概述)
- [MAXScript 基础](#maxscript-基础)
- [SDK 结构](#sdk-结构)
- [插件生命周期](#插件生命周期)

## 开发环境搭建

### 所需工具

- **3ds Max**: 最新版本或目标版本
- **Visual Studio**: 推荐使用 Visual Studio 2019 或更高版本
- **3ds Max SDK**: 与您的 3ds Max 版本匹配的 SDK
- **MAXScript 编辑器**: 内置于 3ds Max 中

### 环境配置步骤

1. 安装 3ds Max
2. 安装 Visual Studio
3. 安装 3ds Max SDK
4. 配置项目属性和依赖项
5. 设置调试环境

## 插件类型概述

3ds Max 支持多种类型的插件，每种类型适用于不同的功能扩展：

- **实用工具 (Utility)**: 简单的工具面板插件
- **命令 (Command)**: 执行特定操作的命令
- **修改器 (Modifier)**: 修改对象几何形状或属性
- **材质 (Material)**: 自定义材质和着色器
- **渲染器 (Renderer)**: 自定义渲染引擎
- **几何对象 (Geometric Object)**: 自定义几何体类型
- **控制器 (Controller)**: 动画控制器
- **着色器 (Shader)**: 自定义着色算法

## MAXScript 基础

### MAXScript 简介

MAXScript 是 3ds Max 的内置脚本语言，可用于：

- 自动化重复任务
- 创建自定义工具和界面
- 扩展 3ds Max 功能
- 作为插件开发的快速原型工具

### 基本语法

```maxscript
-- 这是注释
fn myFunction param1 param2 = 
(
    -- 函数体
    return param1 + param2
)

-- 变量声明
myVar = 10

-- 条件语句
if myVar > 5 then
(
    print "大于5"
)
else
(
    print "小于或等于5"
)

-- 循环
for i = 1 to 10 do
(
    print i
)
```

## SDK 结构

3ds Max SDK 包含以下主要组件：

- **头文件**: 定义 API 接口
- **库文件**: 提供 API 实现
- **示例代码**: 演示各种插件类型的实现
- **文档**: API 参考和开发指南

### 主要目录

- `maxsdk/include`: 头文件
- `maxsdk/lib`: 库文件
- `maxsdk/samples`: 示例代码
- `maxsdk/help`: 文档

## 插件生命周期

### 初始化

插件在 3ds Max 启动时加载，通过 `DllMain` 和 `LibInitialize` 函数进行初始化。

### 注册

插件通过 `LibNumberClasses` 和 `LibClassDesc` 函数向 3ds Max 注册自身。

### 实例化

用户激活插件时，3ds Max 通过 `CreateInstance` 函数创建插件实例。

### 销毁

插件实例在不再需要时通过 `DeleteThis` 函数销毁。

### 卸载

3ds Max 关闭时，通过 `LibShutdown` 函数卸载插件。