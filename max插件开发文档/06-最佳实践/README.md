# 3ds Max 插件开发最佳实践

## 目录

- [性能优化](#性能优化)
- [调试技巧](#调试技巧)
- [内存管理](#内存管理)
- [兼容性考虑](#兼容性考虑)
- [安全性](#安全性)
- [版本迁移](#版本迁移)
- [测试策略](#测试策略)

## 性能优化

### 几何处理优化

#### 网格简化

在处理大型网格时，考虑使用简化技术：

```cpp
// 使用 MNMesh 进行网格简化
MNMesh mnMesh;
mnMesh.SetFromTri(mesh);

// 设置简化参数
MNMeshUtilities meshUtil;
meshUtil.SetMesh(&mnMesh);
meshUtil.CollapseEdges(percentage);

// 转换回 Mesh
mnMesh.OutToTri(simplifiedMesh);
```

#### 使用空间分区

对于复杂场景中的碰撞检测和选择操作，使用空间分区结构：

```cpp
// 使用八叉树进行空间分区
class SpatialPartition {
private:
    struct OctreeNode {
        Box3 bounds;
        std::vector<int> objectIndices;
        OctreeNode* children[8];
    };
    
    OctreeNode* root;
    
    // 实现细节...
};
```

### 绘制优化

#### 视图更新控制

```cpp
// 批量操作时暂停视图更新
Interface* ip = GetCOREInterface();
ip->DisableSceneRedraw();

// 执行多个操作
// ...

// 完成后恢复视图更新
ip->EnableSceneRedraw();
ip->RedrawViews(ip->GetTime());
```

#### 使用显示回调

对于临时视觉反馈，使用显示回调而不是创建实际对象：

```cpp
class MyDisplayCallback : public DisplayCallbackEx {
public:
    int Display(TimeValue t, ViewExp *vpt, int flags) override {
        // 绘制临时几何体
        gw->setColor(LINE_COLOR, Color(1.0f, 0.0f, 0.0f));
        gw->startSegments();
        // 绘制线段
        gw->segment(Point3(0,0,0), Point3(10,10,10));
        gw->endSegments();
        return 1;
    }
};
```

### 计算优化

#### 使用多线程

对于耗时计算，利用多线程处理：

```cpp
// 使用 MaxSDK 的任务系统
class MyComputeTask : public MaxSDK::TaskBase {
public:
    virtual void Run() override {
        // 执行计算
    }
};

// 创建并执行任务
MaxSDK::TaskScheduler::GetInstance().CreateAndExecuteTask(new MyComputeTask());
```

#### 避免频繁内存分配

```cpp
// 预分配内存
std::vector<Point3> vertices;
vertices.reserve(expectedSize);

// 使用对象池
class VertexPool {
private:
    std::vector<Point3*> pool;
    size_t currentIndex = 0;
    
public:
    Point3* GetVertex() {
        if (currentIndex < pool.size()) {
            return pool[currentIndex++];
        }
        
        Point3* newVertex = new Point3();
        pool.push_back(newVertex);
        currentIndex++;
        return newVertex;
    }
    
    void Reset() {
        currentIndex = 0;
    }
};
```

## 调试技巧

### 日志记录

#### 使用 DebugPrint

```cpp
// 在 3ds Max 的 MAXScript 监听器中输出调试信息
void DebugOutput(const TCHAR* format, ...) {
    TCHAR buffer[1024];
    va_list args;
    va_start(args, format);
    _vstprintf_s(buffer, 1024, format, args);
    va_end(args);
    
    GetCOREInterface()->Log()->LogEntry(SYSLOG_DEBUG, NO_DIALOG, _T("MyPlugin"), buffer);
}

// 使用示例
DebugOutput(_T("处理对象: %s, 顶点数: %d"), nodeName, vertexCount);
```

#### 使用外部日志文件

```cpp
class Logger {
private:
    static std::ofstream logFile;
    
public:
    static void Init(const TCHAR* filename) {
        logFile.open(filename);
    }
    
    static void Log(const TCHAR* format, ...) {
        TCHAR buffer[1024];
        va_list args;
        va_start(args, format);
        _vstprintf_s(buffer, 1024, format, args);
        va_end(args);
        
        logFile << buffer << std::endl;
    }
    
    static void Close() {
        logFile.close();
    }
};

// 初始化
std::ofstream Logger::logFile;
```

### 可视化调试

#### 绘制调试图形

```cpp
void DrawDebugLine(ViewExp* vpt, Point3 start, Point3 end, Color color) {
    GraphicsWindow* gw = vpt->getGW();
    gw->setColor(LINE_COLOR, color);
    gw->startSegments();
    gw->segment(start, end);
    gw->endSegments();
}

void DrawDebugPoint(ViewExp* vpt, Point3 point, Color color, float size = 5.0f) {
    GraphicsWindow* gw = vpt->getGW();
    gw->setColor(POINT_COLOR, color);
    gw->startMarkers();
    gw->marker(&point, POINT_MRKR);
    gw->endMarkers();
}
```

#### 使用 MAXScript 进行调试

```cpp
// 在 C++ 代码中执行 MAXScript 进行调试
void ExecuteMAXScriptForDebug(const TCHAR* script) {
    BOOL result;
    GetCOREInterface()->ExecuteMAXScriptScript(script, FALSE, &result);
}

// 使用示例
ExecuteMAXScriptForDebug(_T("print (\"当前选中对象: \" + selection[1].name)"));
```

### 断点和异常处理

#### 自定义断言

```cpp
#define MY_ASSERT(condition, message) \
    if (!(condition)) { \
        TCHAR buffer[1024]; \
        _stprintf_s(buffer, _T("断言失败: %s\nFile: %s\nLine: %d"), _T(message), _T(__FILE__), __LINE__); \
        MessageBox(NULL, buffer, _T("插件错误"), MB_OK | MB_ICONERROR); \
        DebugBreak(); \
    }

// 使用示例
MY_ASSERT(node != nullptr, "节点不能为空");
```

## 内存管理

### 引用计数

3ds Max 使用引用计数系统管理对象生命周期：

```cpp
// 增加引用计数
node->IncRef();

// 减少引用计数
node->DecRef();

// 使用智能指针管理引用计数
class NodePtr {
private:
    INode* node;
    
public:
    NodePtr(INode* n) : node(n) {
        if (node) node->IncRef();
    }
    
    ~NodePtr() {
        if (node) node->DecRef();
    }
    
    // 其他智能指针功能...
};
```

### 避免内存泄漏

#### 使用 RAII 原则

```cpp
class MeshDataHolder {
private:
    Mesh* mesh;
    
public:
    MeshDataHolder(Object* obj) {
        mesh = nullptr;
        if (obj && obj->CanConvertToType(Class_ID(TRIOBJ_CLASS_ID, 0))) {
            TriObject* tri = static_cast<TriObject*>(obj->ConvertToType(0, Class_ID(TRIOBJ_CLASS_ID, 0)));
            mesh = &tri->GetMesh();
        }
    }
    
    ~MeshDataHolder() {
        // 清理转换的对象
    }
    
    Mesh* GetMesh() { return mesh; }
};
```

## 兼容性考虑

### 版本兼容性

#### 检查 3ds Max 版本

```cpp
BOOL CheckMaxVersion() {
    // 获取当前 3ds Max 版本
    DWORD version = GetCOREInterface()->GetMaxVersion();
    DWORD majorVersion = GET_MAX_MAJOR_VERSION(version);
    DWORD minorVersion = GET_MAX_MINOR_VERSION(version);
    
    // 检查版本兼容性
    if (majorVersion < 20) { // 3ds Max 2018 之前的版本
        MessageBox(NULL, _T("此插件需要 3ds Max 2018 或更高版本"), _T("版本不兼容"), MB_OK | MB_ICONERROR);
        return FALSE;
    }
    
    return TRUE;
}
```

#### 使用条件编译

```cpp
#if MAX_VERSION_MAJOR >= 20
    // 3ds Max 2018 及更高版本的代码
    MaxSDK::Graphics::IViewportShadingMgr* shadingMgr = GetCOREInterface()->GetViewportShadingMgr();
#else
    // 早期版本的替代代码
    IViewportManager* viewportMgr = GetCOREInterface()->GetViewportManager();
#endif
```

### 插件兼容性

#### 使用唯一的类 ID

```cpp
#define MY_PLUGIN_CLASS_ID Class_ID(0x12345678, 0x87654321)

class MyPlugin : public UtilityObj {
    // 插件实现
};

// 确保类 ID 唯一
class MyPluginClassDesc : public ClassDesc2 {
public:
    int IsPublic() override { return TRUE; }
    void* Create(BOOL loading = FALSE) override { return new MyPlugin(); }
    const TCHAR* ClassName() override { return _T("我的插件"); }
    SClass_ID SuperClassID() override { return UTILITY_CLASS_ID; }
    Class_ID ClassID() override { return MY_PLUGIN_CLASS_ID; }
    const TCHAR* Category() override { return _T("我的类别"); }
};
```

## 版本迁移

### 数据迁移

#### 保存和加载版本信息

```cpp
// 在保存数据时包含版本信息
IOResult SaveData(ISave* isave) {
    // 保存版本号
    ULONG version = 100; // 版本 1.00
    isave->BeginChunk(VERSION_CHUNK);
    isave->Write(&version, sizeof(ULONG), &written);
    isave->EndChunk();
    
    // 保存其他数据
    // ...
    
    return IO_OK;
}

// 在加载数据时处理不同版本
IOResult LoadData(ILoad* iload) {
    ULONG version = 0;
    
    while (iload->OpenChunk() == IO_OK) {
        switch (iload->CurChunkID()) {
            case VERSION_CHUNK:
                iload->Read(&version, sizeof(ULONG), &read);
                break;
                
            // 处理其他数据块
            // ...
        }
        
        iload->CloseChunk();
    }
    
    // 根据版本执行迁移
    if (version < 100) {
        // 处理旧版本数据
    }
    
    return IO_OK;
}
```

## 测试策略

### 单元测试

```cpp
// 使用简单的测试框架
class TestFramework {
private:
    int passedTests = 0;
    int failedTests = 0;
    
public:
    void Assert(bool condition, const TCHAR* message) {
        if (condition) {
            passedTests++;
        } else {
            failedTests++;
            DebugOutput(_T("测试失败: %s"), message);
        }
    }
    
    void PrintResults() {
        DebugOutput(_T("测试结果: %d 通过, %d 失败"), passedTests, failedTests);
    }
};

// 使用示例
void RunTests() {
    TestFramework test;
    
    // 测试向量归一化
    Point3 vec(3, 4, 0);
    Point3 normalized = Normalize(vec);
    test.Assert(fabs(Length(normalized) - 1.0f) < 0.0001f, _T("向量归一化"));
    
    // 测试矩阵变换
    Matrix3 mat;
    mat.IdentityMatrix();
    test.Assert(mat.GetRow(0).Equals(Point3(1,0,0)), _T("单位矩阵行向量"));
    
    test.PrintResults();
}
```

### 集成测试

```cpp
// 使用 MAXScript 进行集成测试
const TCHAR* integrationTest = _T("\
    fn testPluginFunctionality = (\
        -- 创建测试场景\
        delete objects\
        box length:10 width:10 height:10\
        \
        -- 运行插件功能\
        myPlugin.processSelectedObjects()\
        \
        -- 验证结果\
        if selection.count == 1 and selection[1].width == 20 then (\
            format \"测试通过\\n\"\
        ) else (\
            format \"测试失败\\n\"\
        )\
    )\
    \
    testPluginFunctionality()\
");

void RunIntegrationTests() {
    BOOL result;
    GetCOREInterface()->ExecuteMAXScriptScript(integrationTest, FALSE, &result);
}
```

### 性能测试

```cpp
class PerformanceTest {
private:
    DWORD startTime;
    
public:
    void Start() {
        startTime = GetTickCount();
    }
    
    DWORD End(const TCHAR* testName) {
        DWORD endTime = GetTickCount();
        DWORD duration = endTime - startTime;
        DebugOutput(_T("性能测试 '%s': %d 毫秒"), testName, duration);
        return duration;
    }
};

// 使用示例
void TestPerformance() {
    PerformanceTest test;
    
    // 测试网格处理性能
    test.Start();
    // 执行网格处理操作
    ProcessLargeMesh();
    test.End(_T("网格处理"));
    
    // 测试场景遍历性能
    test.Start();
    // 遍历场景
    TraverseScene();
    test.End(_T("场景遍历"));
}
```

---

通过遵循这些最佳实践，您可以开发出高效、稳定且易于维护的 3ds Max 插件。记住，性能优化应该是一个持续的过程，随着项目的发展不断进行测试和改进。调试工具和技巧将帮助您快速定位和解决问题，而兼容性考虑则确保您的插件能够在不同版本的 3ds Max 中正常工作。