# 3ds Max 插件打包发布指南

## 目录

- [打包准备](#打包准备)
- [创建安装程序](#创建安装程序)
- [依赖项管理](#依赖项管理)
- [版本兼容性](#版本兼容性)
- [许可证管理](#许可证管理)
- [发布渠道](#发布渠道)
- [更新机制](#更新机制)
- [用户文档](#用户文档)
- [最佳实践](#最佳实践)

## 打包准备

在开始打包3ds Max插件之前，需要确保以下内容已准备就绪：

### 文件清单

1. **主要插件文件**
   - 插件DLL文件（`.dlr`, `.dlo`, `.dlu`等）
   - 插件描述文件（`.ini`, `.xml`等）
   - 资源文件（图标、图像、UI定义等）

2. **辅助文件**
   - 配置文件
   - 预设文件
   - 示例场景
   - 材质库或其他资源

3. **文档**
   - 安装指南
   - 用户手册
   - 版本说明
   - 许可协议

### 版本信息

确保在打包前设置正确的版本信息：

```cpp
// 在插件源代码中定义版本信息
#define PLUGIN_VERSION_MAJOR 1
#define PLUGIN_VERSION_MINOR 0
#define PLUGIN_VERSION_PATCH 0
#define PLUGIN_VERSION_STRING "1.0.0"
```

在插件界面和关于对话框中显示版本信息：

```cpp
MSTR GetVersionString()
{
    return MSTR(_T("版本 ") PLUGIN_VERSION_STRING);
}
```

### 测试清单

在打包前，确保完成以下测试：

1. 在目标3ds Max版本中的安装和加载测试
2. 功能测试（所有功能按预期工作）
3. 性能测试（无明显性能问题）
4. 兼容性测试（与其他常用插件兼容）
5. 卸载测试（确保卸载干净）

## 创建安装程序

### 安装程序选项

以下是几种常用的安装程序创建工具：

1. **Inno Setup**
   - 免费、开源
   - 易于使用，功能强大
   - 支持脚本定制
   - 示例脚本：

```inno
[Setup]
AppName=我的3ds Max插件
AppVersion=1.0.0
DefaultDirName={param:MaxDir|{pf}\Autodesk\3ds Max 2022}\Plugins\MyPlugin
DisableDirPage=no

[Files]
Source: "bin\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "resources\*"; DestDir: "{app}\resources"; Flags: ignoreversion recursesubdirs
Source: "docs\*"; DestDir: "{app}\docs"; Flags: ignoreversion

[Run]
Filename: "{app}\docs\readme.pdf"; Description: "查看说明文档"; Flags: postinstall shellexec
```

2. **NSIS (Nullsoft Scriptable Install System)**
   - 免费、开源
   - 高度可定制
   - 支持复杂安装逻辑
   - 示例脚本：

```nsis
OutFile "MyPlugin_Setup.exe"
InstallDir "$PROGRAMFILES64\Autodesk\3ds Max 2022\Plugins\MyPlugin"

Section "安装"
  SetOutPath "$INSTDIR"
  File /r "bin\*.*"
  File /r "resources\*.*"
  File /r "docs\*.*"
  
  # 创建卸载程序
  WriteUninstaller "$INSTDIR\uninstall.exe"
SectionEnd

Section "Uninstall"
  Delete "$INSTDIR\uninstall.exe"
  RMDir /r "$INSTDIR"
SectionEnd
```

3. **WiX Toolset**
   - 专业级MSI安装包创建工具
   - 适合企业级应用
   - 支持Windows Installer的所有功能

### 安装程序功能

一个好的安装程序应包含以下功能：

1. **检测3ds Max安装**
   - 自动检测已安装的3ds Max版本
   - 允许用户选择目标版本

2. **自定义安装选项**
   - 允许选择安装组件
   - 提供示例和文档的可选安装

3. **权限检查**
   - 检查并请求管理员权限（如需要）
   - 验证目标目录的写入权限

4. **安装后操作**
   - 创建快捷方式
   - 显示说明文档
   - 提供启动3ds Max的选项

5. **卸载功能**
   - 完全卸载所有组件
   - 提供保留用户设置的选项

## 依赖项管理

### 依赖项类型

1. **运行时库**
   - Visual C++ Redistributable
   - .NET Framework
   - 其他第三方运行时

2. **第三方库**
   - 图形库（如OpenGL, DirectX）
   - 数学库
   - 物理引擎
   - UI框架

3. **插件依赖**
   - 依赖其他3ds Max插件
   - 共享组件

### 依赖项处理策略

1. **静态链接**
   - 将依赖库直接编译到插件中
   - 优点：减少外部依赖
   - 缺点：增加文件大小，更新困难

2. **动态链接**
   - 使用DLL方式加载依赖
   - 优点：模块化，易于更新
   - 缺点：需要确保DLL可用

3. **运行时检测**
   - 在插件加载时检查依赖项
   - 提供友好的错误信息和解决方案

```cpp
BOOL CheckDependencies()
{
    // 检查Visual C++运行时
    HMODULE hModule = LoadLibrary(_T("msvcp140.dll"));
    if (!hModule)
    {
        MessageBox(NULL, 
            _T("缺少Visual C++ Redistributable 2015-2019。请安装后再试。"),
            _T("依赖项缺失"), MB_OK | MB_ICONERROR);
        return FALSE;
    }
    FreeLibrary(hModule);
    
    // 检查其他依赖项...
    
    return TRUE;
}
```

### 依赖项打包选项

1. **包含在安装程序中**
   - 将所有依赖项打包到安装程序中
   - 提供一键安装体验

2. **单独安装**
   - 提供依赖项的下载链接
   - 在安装前检查并提示安装缺失依赖

3. **混合策略**
   - 关键依赖项包含在安装程序中
   - 可选或大型依赖项提供单独下载

## 版本兼容性

### 多版本支持

支持多个3ds Max版本的策略：

1. **单一安装包，多版本支持**
   - 在安装时检测并选择适当的文件
   - 使用条件编译构建不同版本的DLL

```inno
[Files]
Source: "bin\2020\*.dll"; DestDir: "{app}"; Check: IsMax2020; Flags: ignoreversion
Source: "bin\2021\*.dll"; DestDir: "{app}"; Check: IsMax2021; Flags: ignoreversion
Source: "bin\2022\*.dll"; DestDir: "{app}"; Check: IsMax2022; Flags: ignoreversion

[Code]
function IsMax2020(): Boolean;
begin
  Result := FileExists(ExpandConstant('{param:MaxDir|{pf}\Autodesk\3ds Max 2020}\3dsmax.exe'));
end;

function IsMax2021(): Boolean;
begin
  Result := FileExists(ExpandConstant('{param:MaxDir|{pf}\Autodesk\3ds Max 2021}\3dsmax.exe'));
end;

function IsMax2022(): Boolean;
begin
  Result := FileExists(ExpandConstant('{param:MaxDir|{pf}\Autodesk\3ds Max 2022}\3dsmax.exe'));
end;
```

2. **版本特定安装包**
   - 为每个支持的3ds Max版本创建单独的安装包
   - 简化安装逻辑，但维护多个安装包

### 向后兼容性

确保插件数据向后兼容的策略：

1. **版本标记**
   - 在保存的数据中包含版本信息
   - 根据版本信息正确加载数据

```cpp
// 保存数据时包含版本信息
void SaveData(ISave* isave)
{
    // 保存版本号
    isave->BeginChunk(CHUNK_VERSION);
    DWORD version = PLUGIN_VERSION_MAJOR * 10000 + PLUGIN_VERSION_MINOR * 100 + PLUGIN_VERSION_PATCH;
    isave->Write(&version, sizeof(DWORD), NULL);
    isave->EndChunk();
    
    // 保存其他数据...
}

// 加载数据时处理不同版本
IOResult LoadData(ILoad* iload)
{
    IOResult res;
    DWORD version = 0;
    
    while (IO_OK == (res = iload->OpenChunk()))
    {
        switch (iload->CurChunkID())
        {
        case CHUNK_VERSION:
            res = iload->Read(&version, sizeof(DWORD), NULL);
            break;
            
        // 根据版本处理其他数据...
        }
        
        iload->CloseChunk();
    }
    
    return IO_OK;
}
```

2. **数据迁移**
   - 提供旧版数据到新版数据的转换功能
   - 在安装新版本时自动迁移用户数据

## 许可证管理

### 许可证类型

1. **免费/开源**
   - 无需许可证验证
   - 考虑使用开源许可证（MIT, GPL等）

2. **商业许可**
   - 单机许可
   - 网络浮动许可
   - 订阅模式

3. **试用/演示**
   - 功能限制版本
   - 时间限制试用

### 许可证实现

1. **基于文件的许可**
   - 使用加密的许可证文件
   - 验证许可证文件的有效性

```cpp
BOOL ValidateLicense(const TCHAR* licensePath)
{
    // 读取许可证文件
    std::ifstream licenseFile(licensePath, std::ios::binary);
    if (!licenseFile.is_open())
        return FALSE;
    
    // 读取并验证许可证数据
    // ...
    
    return isValid;
}
```

2. **基于硬件的许可**
   - 绑定到特定硬件标识（如MAC地址、硬盘序列号）
   - 生成和验证硬件锁

```cpp
MSTR GetHardwareID()
{
    // 获取MAC地址
    IP_ADAPTER_INFO adapterInfo[16];
    DWORD bufferSize = sizeof(adapterInfo);
    DWORD result = GetAdaptersInfo(adapterInfo, &bufferSize);
    
    if (result == ERROR_SUCCESS)
    {
        PIP_ADAPTER_INFO adapter = adapterInfo;
        TCHAR macAddress[18];
        _stprintf_s(macAddress, _T("%02X-%02X-%02X-%02X-%02X-%02X"),
            adapter->Address[0], adapter->Address[1], adapter->Address[2],
            adapter->Address[3], adapter->Address[4], adapter->Address[5]);
        return MSTR(macAddress);
    }
    
    return MSTR(_T(""));
}
```

3. **在线激活**
   - 通过在线服务验证许可证
   - 支持许可证转移和管理

### 许可证保护

1. **代码混淆**
   - 使用代码混淆工具保护关键代码
   - 隐藏许可证验证逻辑

2. **反调试技术**
   - 检测调试器
   - 防止内存修改

3. **时间限制**
   - 定期在线验证
   - 许可证到期检查

## 发布渠道

### 官方渠道

1. **Autodesk App Store**
   - 官方应用商店，可获得更多曝光
   - 需符合Autodesk的审核要求
   - 支持付费和免费应用

2. **个人/公司网站**
   - 完全控制分发和销售流程
   - 需自行处理支付和下载
   - 可使用现成的电子商务解决方案

### 第三方市场

1. **3D模型市场**
   - Turbosquid, CGTrader等平台的插件区
   - 接触大量3D艺术家

2. **开发者社区**
   - GitHub, GitLab等代码托管平台（开源插件）
   - 开发者论坛和社区

### 发布清单

发布前的最终检查清单：

1. 所有文件已包含在安装包中
2. 版本号和版本信息正确
3. 许可证文件和条款已更新
4. 安装程序在所有目标系统上测试通过
5. 用户文档完整且最新
6. 营销材料（截图、视频、描述）已准备就绪

## 更新机制

### 更新检测

1. **手动检查**
   - 在插件界面中提供"检查更新"功能
   - 与更新服务器通信检查新版本

```cpp
void CheckForUpdates()
{
    // 创建HTTP请求
    HINTERNET hInternet = InternetOpen(_T("MyPlugin/1.0"), INTERNET_OPEN_TYPE_PRECONFIG, NULL, NULL, 0);
    if (!hInternet)
        return;
    
    // 连接到更新服务器
    HINTERNET hConnect = InternetConnect(hInternet, _T("example.com"), INTERNET_DEFAULT_HTTPS_PORT,
        NULL, NULL, INTERNET_SERVICE_HTTP, 0, 0);
    if (!hConnect)
    {
        InternetCloseHandle(hInternet);
        return;
    }
    
    // 请求版本信息
    HINTERNET hRequest = HttpOpenRequest(hConnect, _T("GET"), _T("/api/version"),
        NULL, NULL, NULL, INTERNET_FLAG_SECURE, 0);
    if (!hRequest)
    {
        InternetCloseHandle(hConnect);
        InternetCloseHandle(hInternet);
        return;
    }
    
    // 发送请求并处理响应
    // ...
    
    // 关闭句柄
    InternetCloseHandle(hRequest);
    InternetCloseHandle(hConnect);
    InternetCloseHandle(hInternet);
}
```

2. **自动检查**
   - 在插件启动时自动检查更新
   - 定期检查（如每周一次）

### 更新分发

1. **完整安装包**
   - 提供完整的新版本安装程序
   - 简单但下载量大

2. **增量更新包**
   - 只包含变更的文件
   - 减少下载大小，但实现复杂

3. **自动更新**
   - 插件自行下载并安装更新
   - 提供无缝体验，但需要权限管理

### 版本控制

1. **语义化版本**
   - 使用主版本.次版本.补丁版本格式（如1.2.3）
   - 主版本：不兼容的API变更
   - 次版本：向后兼容的功能新增
   - 补丁版本：向后兼容的问题修复

2. **更新日志**
   - 详细记录每个版本的变更
   - 分类为新功能、改进和修复
   - 提供给用户查看

## 用户文档

### 文档类型

1. **安装指南**
   - 系统要求
   - 安装步骤
   - 激活过程

2. **用户手册**
   - 功能概述
   - 详细使用说明
   - 快捷键和工作流程

3. **教程**
   - 入门教程
   - 高级技巧
   - 视频教程

4. **API文档**
   - 如果插件提供API，提供详细文档
   - 示例代码和用例

### 文档格式

1. **PDF文档**
   - 专业排版
   - 可打印
   - 支持书签和链接

2. **HTML帮助**
   - 集成到3ds Max帮助系统
   - 交互式导航
   - 搜索功能

3. **在线文档**
   - 易于更新
   - 可包含多媒体内容
   - 支持用户评论和反馈

### 本地化

1. **多语言支持**
   - 翻译关键文档到主要语言
   - 使用资源文件分离UI文本

2. **区域设置**
   - 适应不同区域的日期、时间格式
   - 考虑不同文化的UI设计

## 最佳实践

### 质量保证

1. **全面测试**
   - 功能测试
   - 兼容性测试
   - 性能测试
   - 安装/卸载测试

2. **Beta测试**
   - 在发布前进行封闭或公开Beta测试
   - 收集用户反馈并修复问题

3. **持续集成**
   - 使用CI/CD流程自动构建和测试
   - 确保每个版本的质量

### 用户支持

1. **支持渠道**
   - 电子邮件支持
   - 论坛或社区
   - 问题跟踪系统

2. **常见问题解答**
   - 整理常见问题和解答
   - 定期更新

3. **反馈机制**
   - 在插件中提供反馈功能
   - 鼓励用户报告问题和建议

### 营销策略

1. **演示视频**
   - 展示插件核心功能
   - 突出与竞品的差异

2. **案例研究**
   - 展示实际项目中的应用
   - 邀请用户分享成功案例

3. **社交媒体**
   - 维护社交媒体账号
   - 分享更新、技巧和用户作品

---

通过遵循本指南中的最佳实践，您可以确保3ds Max插件的专业打包、发布和分发，提高用户满意度并减少支持问题。记住，良好的用户体验不仅仅来自于插件的功能，还来自于安装过程、文档质量和持续支持。