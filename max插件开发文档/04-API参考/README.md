# 3ds Max 插件开发 API 参考

## 目录

- [核心 API 概述](#核心-api-概述)
- [场景操作](#场景操作)
- [几何操作](#几何操作)
- [材质系统](#材质系统)
- [动画系统](#动画系统)
- [渲染系统](#渲染系统)
- [用户界面](#用户界面)
- [实用工具](#实用工具)
- [插件开发](#插件开发)

## 核心 API 概述

3ds Max SDK 提供了丰富的 API，用于访问和操作 3ds Max 的各个方面。以下是主要的 API 模块：

### 核心对象

| 类名 | 描述 | 头文件 |
|------|------|--------|
| `Interface` | 主应用程序接口，提供对 3ds Max 核心功能的访问 | `max.h` |
| `INode` | 场景节点接口，表示场景中的对象 | `inode.h` |
| `Object` | 基础对象类，所有几何对象的基类 | `object.h` |
| `Animatable` | 可动画对象基类，支持动画属性 | `animtbl.h` |
| `ReferenceTarget` | 引用目标基类，支持引用系统 | `ref.h` |

### 主要命名空间

- `MaxSDK`: 包含 SDK 核心功能
- `MaxSDK::Graphics`: 图形相关功能
- `MaxSDK::AssetManagement`: 资产管理功能

## 场景操作

### 场景访问

```cpp
// 获取当前场景接口
Interface* ip = GetCOREInterface();

// 获取根节点
INode* rootNode = ip->GetRootNode();

// 遍历场景节点
for (int i = 0; i < rootNode->NumChildren(); i++)
{
    INode* childNode = rootNode->GetChildNode(i);
    // 处理节点
}
```

### 对象选择

```cpp
// 获取当前选择
Interface* ip = GetCOREInterface();
INodeTab selectedNodes;
ip->GetSelNodeTab(selectedNodes);

// 处理选中对象
for (int i = 0; i < selectedNodes.Count(); i++)
{
    INode* node = selectedNodes[i];
    // 处理节点
}

// 选择对象
ip->SelectNode(node);

// 清除选择
ip->ClearNodeSelection();
```

### 场景时间

```cpp
// 获取当前时间
TimeValue t = ip->GetTime();

// 设置当前时间
ip->SetTime(TimeValue(4800)); // 设置到第 160 帧 (30fps * 160)

// 获取动画长度
Interval animRange = ip->GetAnimRange();
TimeValue start = animRange.Start();
TimeValue end = animRange.End();
```

## 几何操作

### 访问几何数据

```cpp
// 获取对象的几何数据
Object* obj = node->GetObjectRef();
Mesh* mesh = nullptr;

// 确保对象是网格
if (obj->CanConvertToType(Class_ID(TRIOBJ_CLASS_ID, 0)))
{
    TriObject* triObj = static_cast<TriObject*>(obj->ConvertToType(0, Class_ID(TRIOBJ_CLASS_ID, 0)));
    mesh = &triObj->GetMesh();
    
    // 访问顶点
    for (int i = 0; i < mesh->getNumVerts(); i++)
    {
        Point3 vertex = mesh->getVert(i);
        // 处理顶点
    }
    
    // 访问面
    for (int i = 0; i < mesh->getNumFaces(); i++)
    {
        Face face = mesh->faces[i];
        // 处理面
    }
    
    // 如果转换了对象，需要释放
    if (triObj != obj)
    {
        triObj->DeleteThis();
    }
}
```

### 创建几何对象

```cpp
// 创建一个球体
INode* CreateSphere(Interface* ip, Point3 center, float radius)
{
    // 创建球体对象
    SphereObject* sphere = new SphereObject();
    sphere->SetParams(radius, 32);
    
    // 创建节点
    INode* node = ip->CreateObjectNode(sphere);
    
    // 设置位置
    Matrix3 tm;
    tm.IdentityMatrix();
    tm.SetTrans(center);
    node->SetNodeTM(0, tm);
    
    return node;
}
```

### 修改几何

```cpp
// 应用噪波修改器
void ApplyNoiseModifier(INode* node, float strength)
{
    Interface* ip = GetCOREInterface();
    
    // 创建噪波修改器
    Modifier* noiseMod = (Modifier*)ip->CreateInstance(OSM_CLASS_ID, Class_ID(NOISEOSMMOD_CLASS_ID, 0));
    
    // 设置参数
    IParamBlock2* pb = noiseMod->GetParamBlockByID(0);
    pb->SetValue(0, 0, strength); // 强度参数
    
    // 应用修改器
    IDerivedObject* derivedObj = CreateDerivedObject(node->GetObjectRef());
    derivedObj->AddModifier(noiseMod);
    node->SetObjectRef(derivedObj);
}
```

## 材质系统

### 访问材质

```cpp
// 获取对象的材质
Mtl* GetObjectMaterial(INode* node)
{
    return node->GetMtl();
}

// 遍历材质库
void ListMaterialLibrary()
{
    Interface* ip = GetCOREInterface();
    MtlBaseLib* mtlLib = ip->GetSceneMtls();
    
    for (int i = 0; i < mtlLib->Count(); i++)
    {
        MtlBase* mtl = (*mtlLib)[i];
        TSTR name = mtl->GetName();
        // 处理材质
    }
}
```

### 创建材质

```cpp
// 创建标准材质
StdMat2* CreateStandardMaterial(Interface* ip, Color diffuse, float glossiness)
{
    StdMat2* mtl = NewDefaultStdMat();
    mtl->SetDiffuse(diffuse, 0);
    mtl->SetShininess(glossiness, 0);
    
    // 添加到材质库
    ip->PutMtlToMtlEditor(mtl, 0);
    
    return mtl;
}

// 应用材质到对象
void ApplyMaterial(INode* node, Mtl* mtl)
{
    node->SetMtl(mtl);
}
```

### 纹理贴图

```cpp
// 创建位图纹理
BitmapTex* CreateBitmapTexture(const TCHAR* filename)
{
    BitmapTex* bmt = NewDefaultBitmapTex();
    bmt->SetMapName(const_cast<TCHAR*>(filename));
    bmt->LoadMapFiles(0);
    return bmt;
}

// 将纹理应用到材质的漫反射通道
void SetDiffuseTexture(StdMat2* mtl, Texmap* tex)
{
    mtl->SetSubTexmap(ID_DI, tex);
    mtl->EnableMap(ID_DI, TRUE);
}
```

## 动画系统

### 关键帧动画

```cpp
// 创建位置动画
void AnimatePosition(INode* node, TimeValue startTime, TimeValue endTime, Point3 startPos, Point3 endPos)
{
    // 获取位置控制器
    Control* posControl = node->GetTMController()->GetPositionController();
    
    // 设置起始关键帧
    posControl->SetValue(startTime, &startPos);
    
    // 设置结束关键帧
    posControl->SetValue(endTime, &endPos);
}

// 创建旋转动画
void AnimateRotation(INode* node, TimeValue startTime, TimeValue endTime, Quat startRot, Quat endRot)
{
    // 获取旋转控制器
    Control* rotControl = node->GetTMController()->GetRotationController();
    
    // 设置起始关键帧
    rotControl->SetValue(startTime, &startRot);
    
    // 设置结束关键帧
    rotControl->SetValue(endTime, &endRot);
}
```

### 控制器

```cpp
// 应用贝塞尔位置控制器
void ApplyBezierPositionController(INode* node)
{
    // 创建贝塞尔位置控制器
    Control* bezierControl = (Control*)CreateInstance(CTRL_POSITION_CLASS_ID, Class_ID(LININTERP_POSITION_CLASS_ID, 0));
    
    // 获取当前位置值
    Point3 currentPos;
    node->GetTMController()->GetPositionController()->GetValue(0, &currentPos);
    
    // 设置控制器
    node->GetTMController()->SetPositionController(bezierControl);
    
    // 设置初始值
    bezierControl->SetValue(0, &currentPos);
}
```

## 渲染系统

### 渲染设置

```cpp
// 设置渲染输出尺寸
void SetRenderSize(int width, int height)
{
    Interface* ip = GetCOREInterface();
    ip->SetRendWidth(width);
    ip->SetRendHeight(height);
}

// 设置渲染输出文件
void SetRenderOutputFile(const TCHAR* filename)
{
    Interface* ip = GetCOREInterface();
    ip->SetRendSaveFile(TRUE);
    ip->SetRendOutputFilename(const_cast<TCHAR*>(filename));
}
```

### 执行渲染

```cpp
// 渲染当前视图
void RenderActiveView()
{
    Interface* ip = GetCOREInterface();
    ip->SetQuietMode(TRUE);
    ip->RendererCommand(ID_RENDER_PRODUCTION, NULL);
}

// 渲染指定帧范围
void RenderFrameRange(int startFrame, int endFrame)
{
    Interface* ip = GetCOREInterface();
    
    // 设置渲染范围
    TimeValue start = startFrame * GetTicksPerFrame();
    TimeValue end = endFrame * GetTicksPerFrame();
    ip->SetAnimRange(Interval(start, end));
    
    // 执行渲染
    ip->SetQuietMode(TRUE);
    ip->RendererCommand(ID_RENDER_PRODUCTION, NULL);
}
```

## 用户界面

### 对话框创建

```cpp
// 创建自定义对话框
class MyDialog : public RollupWindow
{
public:
    MyDialog(HINSTANCE hInstance, HWND hParent)
    {
        // 创建对话框
        hDlg = CreateDialogParam(hInstance, MAKEINTRESOURCE(IDD_MY_DIALOG), hParent, DialogProc, (LPARAM)this);
        ShowWindow(hDlg, SW_SHOW);
    }
    
    static INT_PTR CALLBACK DialogProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam)
    {
        // 处理对话框消息
        switch (message)
        {
            case WM_INITDIALOG:
                // 初始化对话框
                return TRUE;
                
            case WM_COMMAND:
                // 处理命令消息
                return TRUE;
        }
        return FALSE;
    }
    
private:
    HWND hDlg;
};
```

### 工具栏集成

```cpp
// 创建工具栏按钮
void CreateToolbarButton(Interface* ip, const TCHAR* name, const TCHAR* category, const TCHAR* description, HBITMAP hBitmap, DWORD cmdId)
{
    ActionTable* at = ip->GetActionManager()->FindTable(0x3943ed01);
    if (at)
    {
        ActionItem* ai = new ActionItem(name, category, description, cmdId);
        at->AppendOperation(ai);
        
        // 设置图标
        ICustButton* btn = GetICustButton(GetDlgItem(ip->GetMAXHWnd(), cmdId));
        if (btn)
        {
            btn->SetImage(hBitmap, 0, 0);
            ReleaseICustButton(btn);
        }
    }
}
```

### 自定义视口绘制

```cpp
// 自定义视口绘制类
class MyViewportCallback : public ViewportDisplayCallback
{
public:
    void Display(TimeValue t, ViewExp* vpt, int flags) override
    {
        // 获取图形窗口
        GraphicsWindow* gw = vpt->getGW();
        
        // 设置渲染模式
        gw->setRndLimits(GW_WIREFRAME | GW_Z_BUFFER);
        
        // 设置颜色
        gw->setColor(LINE_COLOR, Color(1.0f, 0.0f, 0.0f));
        
        // 绘制线段
        Point3 p1(0.0f, 0.0f, 0.0f);
        Point3 p2(100.0f, 100.0f, 100.0f);
        gw->polyline(2, &p1, NULL, NULL, FALSE, NULL);
    }
};

// 注册视口回调
void RegisterViewportCallback()
{
    Interface* ip = GetCOREInterface();
    ViewportDisplayCallback* cb = new MyViewportCallback();
    ip->RegisterViewportDisplayCallback(TRUE, cb);
}
```

## 实用工具

### 文件操作

```cpp
// 保存场景
void SaveScene(const TCHAR* filename)
{
    Interface* ip = GetCOREInterface();
    ip->FileSave();
}

// 导出场景
void ExportScene(const TCHAR* filename, const TCHAR* exporterClassName)
{
    Interface* ip = GetCOREInterface();
    ip->ExportToFile(filename, TRUE, exporterClassName);
}
```

### 通知系统

```cpp
// 自定义通知回调
class MyNotifyCallback : public NotifyCallback
{
public:
    void NotifyRefChanged(const Interval& changeInt, RefTargetHandle hTarget, PartID& partID, RefMessage message, BOOL propagate) override
    {
        switch (message)
        {
            case REFMSG_CHANGE:
                // 处理对象变化
                break;
                
            case REFMSG_TARGET_DELETED:
                // 处理对象删除
                break;
        }
    }
};

// 注册通知回调
void RegisterNotifyCallback()
{
    Interface* ip = GetCOREInterface();
    NotifyCallback* cb = new MyNotifyCallback();
    ip->RegisterNotifyCallback(cb);
}
```

### 日志和调试

```cpp
// 输出到 MAXScript 监听器
void LogToListener(const TCHAR* message)
{
    TCHAR buffer[1024];
    _stprintf_s(buffer, 1024, _T("%s\n"), message);
    MAXScript_interface->listener_message(buffer);
}

// 输出到调试控制台
void DebugPrint(const char* format, ...)
{
    char buffer[1024];
    va_list args;
    va_start(args, format);
    vsprintf_s(buffer, 1024, format, args);
    va_end(args);
    
    OutputDebugStringA(buffer);
}
```

## 插件开发

### 插件类定义

```cpp
// 定义插件类
class MyPlugin : public UtilityObj
{
public:
    // 构造函数和析构函数
    MyPlugin() {}
    ~MyPlugin() {}
    
    // 实用工具方法
    void BeginEditParams(Interface* ip, IUtil* iu) override;
    void EndEditParams(Interface* ip, IUtil* iu) override;
    void DeleteThis() override;
    
    // 对话框处理
    static INT_PTR CALLBACK DialogProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam);
    
private:
    IUtil* m_interface;
    HWND m_hPanel;
};

// 插件描述类
class MyPluginClassDesc : public ClassDesc2
{
public:
    int IsPublic() override { return TRUE; }
    void* Create(BOOL loading = FALSE) override { return new MyPlugin(); }
    const TCHAR* ClassName() override { return _T("My Plugin"); }
    SClass_ID SuperClassID() override { return UTILITY_CLASS_ID; }
    Class_ID ClassID() override { return Class_ID(0x12345678, 0x87654321); }
    const TCHAR* Category() override { return _T("My Category"); }
    
    // 版本信息
    ULONG GetVersion() override { return 100; }
    ULONG GetClassVersion() override { return 1; }
};

// 获取类描述符
ClassDesc2* GetMyPluginDesc()
{
    static MyPluginClassDesc theDesc;
    return &theDesc;
}
```

### 插件导出函数

```cpp
// 导出函数
__declspec(dllexport) const TCHAR* LibDescription()
{
    return _T("My Plugin Library");
}

__declspec(dllexport) int LibNumberClasses()
{
    return 1;
}

__declspec(dllexport) ClassDesc* LibClassDesc(int i)
{
    switch (i)
    {
        case 0: return GetMyPluginDesc();
        default: return nullptr;
    }
}

__declspec(dllexport) ULONG LibVersion()
{
    return VERSION_3DSMAX;
}

__declspec(dllexport) BOOL LibInitialize()
{
    // 初始化代码
    return TRUE;
}

__declspec(dllexport) BOOL LibShutdown()
{
    // 清理代码
    return TRUE;
}
```

### 插件实现

```cpp
// 实现 BeginEditParams
void MyPlugin::BeginEditParams(Interface* ip, IUtil* iu)
{
    m_interface = iu;
    m_hPanel = ip->AddRollupPage(hInstance, MAKEINTRESOURCE(IDD_PANEL), DialogProc, _T("My Plugin"), (LPARAM)this);
}

// 实现 EndEditParams
void MyPlugin::EndEditParams(Interface* ip, IUtil* iu)
{
    ip->DeleteRollupPage(m_hPanel);
    m_hPanel = nullptr;
    m_interface = nullptr;
}

// 实现 DeleteThis
void MyPlugin::DeleteThis()
{
    delete this;
}

// 实现对话框处理函数
INT_PTR CALLBACK MyPlugin::DialogProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam)
{
    MyPlugin* plugin = nullptr;
    
    if (message == WM_INITDIALOG)
    {
        plugin = (MyPlugin*)lParam;
        SetWindowLongPtr(hWnd, GWLP_USERDATA, (LONG_PTR)plugin);
    }
    else
    {
        plugin = (MyPlugin*)GetWindowLongPtr(hWnd, GWLP_USERDATA);
    }
    
    switch (message)
    {
        case WM_INITDIALOG:
            // 初始化对话框
            return TRUE;
            
        case WM_COMMAND:
            switch (LOWORD(wParam))
            {
                case IDC_BUTTON:
                    // 处理按钮点击
                    return TRUE;
            }
            break;
    }
    
    return FALSE;
}
```

### MAXScript 集成

```cpp
// 定义 MAXScript 函数
def_visible_primitive(myFunction, "MyFunction");
Value* myFunction_cf(Value** arg_list, int count)
{
    check_arg_count(myFunction, 1, count);
    
    // 获取参数
    int param = arg_list[0]->to_int();
    
    // 执行操作
    // ...
    
    // 返回结果
    return Integer::intern(result);
}

// 注册 MAXScript 接口
void RegisterMAXScriptInterface()
{
    // 注册函数
    define_function("MyFunction", myFunction_cf, "MyFunction <int>");
    
    // 注册结构体
    // ...
}
```