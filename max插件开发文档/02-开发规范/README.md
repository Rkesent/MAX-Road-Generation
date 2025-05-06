# 3ds Max 插件开发规范

## 目录

- [代码风格](#代码风格)
- [命名约定](#命名约定)
- [文件组织](#文件组织)
- [注释规范](#注释规范)
- [版本控制](#版本控制)
- [错误处理](#错误处理)
- [性能考量](#性能考量)
- [国际化](#国际化)

## 代码风格

### C++ 代码风格

#### 缩进和格式

- 使用4个空格进行缩进，不使用制表符
- 大括号放在新行上
- 每行代码不超过80个字符
- 运算符两侧添加空格
- 逗号后面添加空格

```cpp
// 正确示例
void MyFunction(int param1, float param2)
{
    if (param1 > 0)
    {
        // 代码
    }
    else
    {
        // 代码
    }
}

// 错误示例
void MyFunction(int param1,float param2){
    if(param1>0){
        // 代码
    }else{
        // 代码
    }
}
```

#### 变量声明

- 每行只声明一个变量
- 变量初始化时使用大括号初始化语法
- 指针和引用符号靠近类型名

```cpp
// 正确示例
int* pointer = nullptr;
float value{0.0f};

// 错误示例
int *pointer1, *pointer2;
float value = 0.0f;
```

### MAXScript 代码风格

- 使用4个空格进行缩进
- 使用小括号包围代码块
- 运算符两侧添加空格
- 使用 `--` 添加单行注释，使用 `/**/` 添加多行注释

```maxscript
-- 正确示例
fn calculateArea width height =
(
    local area = width * height
    return area
)

-- 错误示例
fn calculateArea width height = (
local area=width*height
return area)
```

## 命名约定

### 通用规则

- 名称应当清晰表达其用途
- 避免使用缩写，除非是广泛接受的缩写
- 避免使用单字母变量名，除非是临时循环变量

### C++ 命名约定

| 元素 | 规则 | 示例 |
|------|------|------|
| 类名 | 帕斯卡命名法 | `MyClass`, `VertexModifier` |
| 函数名 | 帕斯卡命名法 | `CalculateNormal`, `GetMeshData` |
| 变量名 | 驼峰命名法 | `vertexCount`, `materialIndex` |
| 常量 | 全大写，下划线分隔 | `MAX_VERTICES`, `DEFAULT_COLOR` |
| 成员变量 | 前缀 m_ 加驼峰命名法 | `m_vertexBuffer`, `m_sceneNodes` |
| 静态变量 | 前缀 s_ 加驼峰命名法 | `s_instanceCount`, `s_pluginManager` |
| 枚举类型 | 帕斯卡命名法 | `RenderQuality`, `MeshType` |
| 枚举值 | 帕斯卡命名法 | `High`, `Medium`, `Low` |

### MAXScript 命名约定

| 元素 | 规则 | 示例 |
|------|------|------|
| 函数名 | 驼峰命名法 | `calculateArea`, `createMaterial` |
| 变量名 | 驼峰命名法 | `vertexCount`, `selectedObjects` |
| 全局变量 | 前缀 g_ 加驼峰命名法 | `g_defaultSettings`, `g_materialLibrary` |
| 常量 | 全大写，下划线分隔 | `MAX_OBJECTS`, `DEFAULT_COLOR` |
| 结构体 | 帕斯卡命名法 | `MaterialData`, `RenderSettings` |

## 文件组织

### 项目结构

```
MyPlugin/
├── src/                  # 源代码
│   ├── core/             # 核心功能
│   ├── ui/               # 用户界面
│   ├── utils/            # 实用工具
│   └── resources/        # 资源文件
├── include/              # 头文件
├── lib/                  # 第三方库
├── docs/                 # 文档
├── tests/                # 测试
└── build/                # 构建输出
```

### 文件命名

- 源文件使用 `.cpp` 扩展名
- 头文件使用 `.h` 扩展名
- MAXScript 文件使用 `.ms` 扩展名
- 文件名应反映其内容，使用帕斯卡命名法
- 相关的头文件和源文件应使用相同的基本名称

### 头文件组织

```cpp
// 1. 版权和许可信息
// Copyright (c) 2023 Your Company. All rights reserved.

// 2. 包含保护
#ifndef MY_PLUGIN_MESH_MODIFIER_H
#define MY_PLUGIN_MESH_MODIFIER_H

// 3. 标准库包含
#include <vector>
#include <string>

// 4. 第三方库包含
#include <max.h>
#include <iparamb2.h>

// 5. 项目包含
#include "core/MeshData.h"

// 6. 前向声明
class MaterialManager;

// 7. 类定义
class MeshModifier
{
    // 类实现
};

#endif // MY_PLUGIN_MESH_MODIFIER_H
```

## 注释规范

### 文件头注释

每个源文件应包含以下信息：

```cpp
/**
 * @file MeshModifier.cpp
 * @brief 实现网格修改功能
 * @author 开发者姓名
 * @date 2023-06-15
 */
```

### 类注释

```cpp
/**
 * @class MeshModifier
 * @brief 提供网格修改功能
 *
 * 该类实现了各种网格修改操作，包括平滑、细分和优化等。
 */
```

### 函数注释

```cpp
/**
 * @brief 计算网格平滑法线
 * @param mesh 输入网格
 * @param angle 平滑角度阈值
 * @return 是否成功计算法线
 */
bool CalculateNormals(Mesh& mesh, float angle);
```

### 变量注释

```cpp
// 存储顶点缓冲区
std::vector<Point3> m_vertices;

// 最大迭代次数
const int MAX_ITERATIONS = 10;
```

### MAXScript 注释

```maxscript
/*
 * 函数: processSelection
 * 描述: 处理当前选中的对象
 * 参数: 
 *   - mode: 处理模式 (1=移动, 2=旋转, 3=缩放)
 *   - value: 操作值
 * 返回: 处理的对象数量
 */
fn processSelection mode value = 
(
    -- 获取选中对象
    local selection = getCurrentSelection()
    
    -- 处理每个对象
    local count = 0
    for obj in selection do
    (
        -- 处理代码
        count += 1
    )
    
    return count
)
```

## 版本控制

### 分支策略

- `main`: 稳定版本分支
- `develop`: 开发分支
- `feature/*`: 新功能分支
- `bugfix/*`: 错误修复分支
- `release/*`: 发布准备分支

### 提交信息

提交信息应遵循以下格式：

```
<类型>: <简短描述>

<详细描述>

<引用问题>
```

类型可以是：
- `feat`: 新功能
- `fix`: 错误修复
- `docs`: 文档更改
- `style`: 代码风格更改
- `refactor`: 代码重构
- `perf`: 性能改进
- `test`: 测试相关
- `build`: 构建系统相关
- `ci`: CI配置相关

示例：

```
feat: 添加网格平滑功能

实现了基于角度的网格平滑算法，支持选择性平滑和权重控制。

Resolves #123
```

## 错误处理

### 异常处理

- 使用异常处理不可恢复的错误
- 使用返回值处理可预期的错误情况
- 避免在析构函数中抛出异常
- 捕获特定异常，而不是捕获所有异常

```cpp
try
{
    // 可能抛出异常的代码
    ProcessMesh(mesh);
}
catch (const std::invalid_argument& e)
{
    // 处理参数错误
    ReportError("参数错误: %s", e.what());
}
catch (const std::runtime_error& e)
{
    // 处理运行时错误
    ReportError("运行时错误: %s", e.what());
}
catch (...)
{
    // 处理未知错误
    ReportError("未知错误");
}
```

### 错误日志

- 使用统一的日志系统记录错误
- 包含足够的上下文信息
- 区分不同级别的错误（调试、信息、警告、错误、严重错误）

```cpp
// 错误日志示例
Logger::Error("MeshModifier", "无法加载网格 '%s': %s", meshName.c_str(), errorMsg.c_str());
```

### 用户反馈

- 提供有意义的错误消息
- 避免技术术语
- 提供可能的解决方案
- 使用统一的对话框样式

## 性能考量

### 资源管理

- 使用智能指针管理动态分配的资源
- 避免频繁的内存分配和释放
- 使用对象池管理频繁创建和销毁的对象
- 及时释放不再需要的资源

### 算法优化

- 选择适合问题规模的算法
- 避免不必要的计算
- 利用空间换时间的策略
- 考虑并行计算

### 数据结构

- 选择适合操作特性的数据结构
- 避免过度使用继承
- 使用组合优于继承
- 考虑数据局部性

## 国际化

### 文本资源

- 将所有用户可见的文本存储在资源文件中
- 避免在代码中硬编码字符串
- 使用资源ID引用字符串

### 字符编码

- 使用UTF-8编码处理文本
- 考虑不同语言的字符宽度
- 支持非拉丁字符

### 本地化考虑

- 考虑文本长度在翻译后可能的变化
- 考虑日期、时间、数字和货币的格式差异
- 考虑阅读方向（从左到右或从右到左）
- 提供足够的上下文信息给翻译人员