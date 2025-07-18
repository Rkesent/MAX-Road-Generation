# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

这是一个为3ds Max设计的远景建筑处理自动化工具，用于处理建筑模型和地形模型的智能化操作。工具的核心功能是将复杂建筑模型按元素层级进行拆解，然后精确对齐到地形表面，最后合并为统一的远景建筑模型。

## 技术架构

### 开发环境
- **语言**: MAXScript (3ds Max原生脚本语言)
- **平台**: 3ds Max 2018及以上版本
- **操作系统**: Windows 10/11
- **UI框架**: MAXScript UI系统

### 核心文件结构
- `DistantArchitectureProcessingUI.ms` - 主要的UI界面和核心处理逻辑
- `对齐到物体表面.ms` - 独立的表面对齐工具
- `3dsMax模型切割对齐插件项目文档.md` - 详细的技术文档和架构说明

## 核心算法架构

### 三层架构设计
1. **用户界面层**: 负责用户交互、队列管理、进度显示
2. **核心处理层**: 包含模型拆解引擎、表面对齐引擎、模型合并引擎
3. **内存管理层**: 处理内存监控、垃圾回收、分块处理

### 关键算法
- **元素分离算法**: 使用`polyop.getElementsUsingFace`进行高效元素检测
- **射线相交算法**: 基于`intersectRayEx`的精确表面对齐
- **分批处理机制**: 防止大型模型导致内存溢出
- **预处理系统**: 将大型模型(>250元素)自动分割为小块

## 常用开发任务

### 调试和测试
由于是MAXScript项目，没有传统的单元测试框架。调试主要通过：
- `format` 语句输出调试信息
- MAXScript编辑器的错误报告
- 在3ds Max中直接运行脚本进行测试

### 运行脚本
```maxscript
-- 在3ds Max脚本编辑器中运行主界面
fileIn "DistantArchitectureProcessingUI.ms"

-- 或者运行优化的独立表面对齐工具
fileIn "对齐到物体表面.ms"
```

### 批量表面对齐工具 (v2.0)
优化后的`对齐到物体表面.ms`支持以下功能：
- **批量处理**: 同时对齐多个对象到多个表面
- **多射线检测**: 从对象的5个点发射射线提高成功率
- **智能表面匹配**: 自动尝试多个目标表面直到成功
- **参数控制**: Z轴偏移量调整和检测模式选择
- **进度反馈**: 实时显示处理进度和结果统计
- **预览功能**: 在实际执行前预览对齐参数
- **撤销支持**: 支持撤销最后一次对齐操作

### 性能优化策略
- 使用`gc()`进行手动垃圾回收
- 通过`windows.processPostedMessages()`保持界面响应
- 实现分批处理避免处理大量对象时卡死
- 使用时间估算系统预测处理时间

## 重要技术限制

### MAXScript限制
- 不支持真正的多线程操作
- 场景操作必须在主线程执行
- 大型模型处理需要分批策略
- 内存管理需要手动优化

### 错误处理
项目使用`try-catch`结构处理错误，常见错误包括：
- 内存不足导致的处理失败
- 无效节点引用
- 射线相交失败
- 层级创建错误

## 代码约定

### 函数命名
- 核心功能函数使用驼峰命名：`decomposeModel`, `alignToSurface`
- UI事件处理函数使用描述性命名：`btnSeparateModel pressed`
- 辅助函数使用前缀：`safe...` (如`safeCreateLayer`)

### 层级管理
项目实现了复杂的层级管理系统：
- 主模型层：使用原始模型名称
- 分块层：对于预处理的大型模型创建子层
- 元素层：分离后的元素直接放在对应层下

### 内存管理模式
- 定期调用`gc()`
- 及时删除临时对象
- 使用分批处理大量数据
- 实现多种合并策略应对不同规模

## 特殊功能

### 时间估算系统
基于面数和元素数量预测处理时间：
```maxscript
local timeEstimate = estimateProcessingTime buildingQueue
local timeString = formatTimeString timeEstimate.estimatedTimeSeconds
```

### 预处理系统
自动检测大型模型并分割：
```maxscript
local processedModels = preProcessLargeModel obj maxElementsPerChunk:250
```

### 悬空物体检测
使用射线检测找到位于地形上方的物体：
```maxscript
local detectionResult = findObjectsAboveTerrain terrain heightThreshold:1.0
```

## 开发注意事项

- MAXScript对大型数据集处理能力有限，需要合理分批
- UI更新需要配合`windows.processPostedMessages()`
- 层级操作容易出错，使用安全包装函数
- 射线相交算法对复杂几何体可能失效，需要多点检测
- 内存泄漏是常见问题，需要主动管理对象生命周期