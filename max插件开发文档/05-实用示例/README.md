# 3ds Max 插件开发实用示例

## 目录

- [基础功能示例](#基础功能示例)
- [UI界面示例](#UI界面示例)
- [几何处理示例](#几何处理示例)
- [场景操作示例](#场景操作示例)
- [自定义着色器示例](#自定义着色器示例)
- [脚本集成示例](#脚本集成示例)

## 基础功能示例

### 创建简单命令插件

以下是一个简单的命令插件示例，它在场景中创建一个基本几何体：

```cpp
// 简单命令插件示例
class SimpleCreateBoxCmd : public ActionItem
{
public:
    // 执行命令
    BOOL ExecuteAction() override
    {
        // 获取接口
        Interface* ip = GetCOREInterface();
        
        // 创建一个盒子对象
        Box* box = new Box();
        box->SetParams(Point3(0, 0, 0), Point3(10, 10, 10), 1, 1, 1, TRUE);
        
        // 创建节点并添加到场景
        INode* node = ip->CreateObjectNode(box);
        node->SetName(_T("SimpleBox"));
        
        // 更新视图
        ip->RedrawViews(ip->GetTime());
        
        return TRUE;
    }
    
    // 命令ID
    int GetId() override { return 0; }
    
    // 命令名称
    MCHAR* GetButtonText() override { return _T("创建盒子"); }
};

// 注册命令
class SimpleCommandClassDesc : public ClassDesc2
{
public:
    int IsPublic() override { return TRUE; }
    void* Create(BOOL loading = FALSE) override { return new SimpleCreateBoxCmd(); }
    const TCHAR* ClassName() override { return _T("简单盒子命令"); }
    SClass_ID SuperClassID() override { return ACTION_ITEM_CLASS_ID; }
    Class_ID ClassID() override { return Class_ID(0x12345678, 0x87654321); }
    const TCHAR* Category() override { return _T("示例命令"); }
};

// 导出类描述符
ClassDesc2* GetSimpleCommandDesc()
{
    static SimpleCommandClassDesc cmdDesc;
    return &cmdDesc;
}
```

### 插件入口点

```cpp
// 插件DLL入口点
BOOL WINAPI DllMain(HINSTANCE hinstDLL, ULONG fdwReason, LPVOID lpvReserved)
{
    if (fdwReason == DLL_PROCESS_ATTACH)
    {
        DisableThreadLibraryCalls(hinstDLL);
    }
    return TRUE;
}

// 导出函数
__declspec(dllexport) const TCHAR* LibDescription()
{
    return _T("示例插件库");
}

__declspec(dllexport) int LibNumberClasses()
{
    return 1; // 只有一个类
}

__declspec(dllexport) ClassDesc* LibClassDesc(int i)
{
    switch (i)
    {
    case 0:
        return GetSimpleCommandDesc();
    default:
        return nullptr;
    }
}

__declspec(dllexport) ULONG LibVersion()
{
    return VERSION_3DSMAX;
}
```

## UI界面示例

### 创建自定义工具栏

```cpp
// 创建自定义工具栏示例
void CreateCustomToolbar()
{
    // 获取主界面
    Interface* ip = GetCOREInterface();
    
    // 创建工具栏
    IToolbarClassDesc* tbClassDesc = static_cast<IToolbarClassDesc*>(GetCOREInterface(TOOLBAR_CLASSDESC_INTERFACE));
    if (!tbClassDesc) return;
    
    // 检查工具栏是否已存在
    MSTR toolbarName = _T("我的自定义工具栏");
    IToolbar* toolbar = tbClassDesc->FindToolbar(toolbarName);
    
    // 如果不存在，创建新工具栏
    if (!toolbar)
    {
        toolbar = tbClassDesc->CreateToolbar(MAIN_TOOLBAR, toolbarName);
        if (!toolbar) return;
        
        // 添加按钮
        ActionTable* actionTable = ip->GetActionManager()->FindTable(MAIN_MENU_CONTEXT);
        if (actionTable)
        {
            int cmdId = actionTable->GetActionCount(); // 获取命令ID
            toolbar->AddTool(cmdId);
        }
        
        // 显示工具栏
        toolbar->Show(TRUE);
    }
}
```

### 创建自定义对话框

```cpp
// 自定义对话框资源ID
#define IDD_CUSTOM_DIALOG 101
#define IDC_EDIT_VALUE 1001
#define IDC_BUTTON_APPLY 1002

// 对话框处理函数
INT_PTR CALLBACK CustomDialogProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam)
{
    switch (message)
    {
    case WM_INITDIALOG:
        // 初始化对话框
        CenterWindow(hWnd, GetParent(hWnd));
        return TRUE;
        
    case WM_COMMAND:
        switch (LOWORD(wParam))
        {
        case IDC_BUTTON_APPLY:
            // 获取编辑框中的值
            TCHAR value[256];
            GetDlgItemText(hWnd, IDC_EDIT_VALUE, value, 256);
            
            // 处理值
            MessageBox(hWnd, value, _T("输入的值"), MB_OK);
            return TRUE;
            
        case IDCANCEL:
            EndDialog(hWnd, 0);
            return TRUE;
        }
        break;
    }
    return FALSE;
}

// 显示对话框
void ShowCustomDialog(HINSTANCE hInstance)
{
    DialogBox(hInstance, MAKEINTRESOURCE(IDD_CUSTOM_DIALOG), GetCOREInterface()->GetMAXHWnd(), CustomDialogProc);
}
```

## 几何处理示例

### 网格修改器

```cpp
// 简单的网格修改器示例
class SimpleMeshModifier : public Modifier
{
private:
    // 修改器参数
    float m_strength;
    
public:
    // 构造函数
    SimpleMeshModifier() : m_strength(1.0f) {}
    
    // 类描述符
    Class_ID ClassID() override { return Class_ID(0x87654321, 0x12345678); }
    SClass_ID SuperClassID() override { return OSM_CLASS_ID; }
    
    // 创建参数块
    void BeginEditParams(IObjParam* ip, ULONG flags, Animatable* prev) override
    {
        // 创建UI面板
    }
    
    void EndEditParams(IObjParam* ip, ULONG flags, Animatable* next) override
    {
        // 清理UI面板
    }
    
    // 修改几何体
    void ModifyObject(TimeValue t, ModContext& mc, ObjectState* os, INode* node) override
    {
        if (!os->obj->IsSubClassOf(triObjectClassID))
            return;
        
        // 获取三角形对象
        TriObject* triObj = static_cast<TriObject*>(os->obj);
        Mesh& mesh = triObj->GetMesh();
        
        // 修改顶点位置 - 简单的噪声效果
        int numVerts = mesh.getNumVerts();
        for (int i = 0; i < numVerts; i++)
        {
            Point3& p = mesh.getVert(i);
            
            // 添加随机偏移
            float noise = m_strength * (float)rand() / RAND_MAX - m_strength * 0.5f;
            p += Point3(noise, noise, noise);
        }
        
        // 更新法线
        mesh.buildNormals();
    }
    
    // 克隆
    RefTargetHandle Clone(RemapDir& remap) override
    {
        SimpleMeshModifier* newMod = new SimpleMeshModifier();
        newMod->m_strength = m_strength;
        BaseClone(this, newMod, remap);
        return newMod;
    }
};
```

### 顶点颜色处理

```cpp
// 处理顶点颜色示例
void ProcessVertexColors(Mesh& mesh, Color color)
{
    // 确保网格有顶点颜色通道
    if (mesh.numCVerts <= 0)
    {
        mesh.setNumVColors(mesh.getNumVerts());
    }
    
    // 设置顶点颜色
    for (int i = 0; i < mesh.getNumVerts(); i++)
    {
        mesh.setVCFace(i, color);
    }
    
    // 标记为已修改
    mesh.setVCDisplayed(TRUE);
}
```

## 场景操作示例

### 场景遍历

```cpp
// 遍历场景中的所有对象
void TraverseScene()
{
    Interface* ip = GetCOREInterface();
    INode* rootNode = ip->GetRootNode();
    
    // 递归遍历函数
    std::function<void(INode*, int)> traverseNode = [&](INode* node, int depth)
    {
        if (!node) return;
        
        // 处理当前节点
        MSTR nodeName = node->GetName();
        
        // 输出节点信息
        TCHAR indent[100] = {0};
        for (int i = 0; i < depth; i++)
            _tcscat_s(indent, _T("  "));
        
        GetCOREInterface()->Log()->LogEntry(SYSLOG_INFO, NO_DIALOG, _T("场景遍历"),
            _T("%s节点: %s"), indent, nodeName.data());
        
        // 遍历子节点
        for (int i = 0; i < node->NumberOfChildren(); i++)
        {
            traverseNode(node->GetChildNode(i), depth + 1);
        }
    };
    
    // 从根节点开始遍历
    for (int i = 0; i < rootNode->NumberOfChildren(); i++)
    {
        traverseNode(rootNode->GetChildNode(i), 0);
    }
}
```

### 选择过滤器

```cpp
// 自定义选择过滤器示例
class CustomSelectFilter : public SelectFilter
{
public:
    BOOL Filter(INode* node) override
    {
        // 只选择几何对象
        Object* obj = node->GetObjectRef();
        if (!obj) return FALSE;
        
        // 检查是否为几何对象
        if (obj->SuperClassID() == GEOMOBJECT_CLASS_ID)
        {
            // 进一步过滤 - 例如只选择盒子
            if (obj->ClassID() == Class_ID(BOXOBJ_CLASS_ID, 0))
                return TRUE;
        }
        
        return FALSE;
    }
};

// 应用选择过滤器
void ApplyCustomFilter()
{
    Interface* ip = GetCOREInterface();
    CustomSelectFilter filter;
    
    // 设置过滤器
    ip->SetSelectFilter(&filter);
    
    // 提示用户选择对象
    ip->Log()->LogEntry(SYSLOG_INFO, NO_DIALOG, _T("选择过滤器"),
        _T("请选择场景中的盒子对象"));
}
```

## 自定义着色器示例

### 简单着色器

```cpp
// 简单自定义着色器示例
class SimpleShader : public Shader
{
private:
    Color m_diffuseColor;
    float m_specularLevel;
    float m_glossiness;
    
public:
    SimpleShader() : m_diffuseColor(Color(0.7f, 0.7f, 0.7f)), m_specularLevel(0.0f), m_glossiness(10.0f) {}
    
    // 着色方法
    void Illum(ShadeContext& sc, IllumParams& ip) override
    {
        // 基本漫反射计算
        ip.diffIllum = m_diffuseColor * sc.DotNormal(ip.L);
        
        // 镜面反射计算
        if (m_specularLevel > 0.0f)
        {
            Point3 R = 2.0f * (ip.L % ip.N) * ip.N - ip.L;
            R = Normalize(R);
            float VR = DotProd(sc.V(), R);
            if (VR > 0.0f)
            {
                ip.specIllum = m_specularLevel * pow(VR, m_glossiness);
            }
        }
    }
    
    // 设置参数
    void SetDiffuseColor(Color color) { m_diffuseColor = color; }
    void SetSpecularLevel(float level) { m_specularLevel = level; }
    void SetGlossiness(float gloss) { m_glossiness = gloss; }
};
```

## 脚本集成示例

### 导出MAXScript函数

```cpp
// 导出到MAXScript的函数示例
Value* ExportedFunction_cf(Value** arg_list, int count)
{
    // 检查参数数量
    check_arg_count(ExportedFunction, 1, count);
    
    // 获取参数
    int value = arg_list[0]->to_int();
    
    // 处理并返回结果
    return Integer::intern(value * 2);
}

// 注册MAXScript函数
void RegisterMAXScriptFunctions()
{
    // 定义函数
    def_visible_primitive(ExportedFunction, "MyExportedFunction");
}
```

### 执行MAXScript代码

```cpp
// 从C++执行MAXScript代码
void ExecuteMAXScriptCode()
{
    // 简单的MAXScript代码
    const MCHAR* script = _T("\
        fn myScriptFunction obj = (\
            format \"处理对象: %\" obj.name\
            obj.wirecolor = color 255 0 0\
            update obj\
        )\
        \
        -- 对选中对象执行函数\
        for obj in selection do (\
            myScriptFunction obj\
        )\
    ");
    
    // 执行脚本
    BOOL result;
    GetCOREInterface()->ExecuteMAXScriptScript(script, FALSE, &result);
}
```

---

这些示例展示了3ds Max插件开发中常见的功能实现方式。您可以根据自己的需求修改和扩展这些示例。在实际开发中，建议参考官方SDK文档和示例，以获取最新的API用法和最佳实践。

每个示例都提供了基本的功能框架，您可以将它们组合起来创建更复杂的插件。记住，良好的代码组织和错误处理对于创建稳定的插件至关重要。