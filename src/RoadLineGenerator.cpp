/**
// UTF-8 BOM
xEFxBBxBF/*
 * RoadLineGenerator.cpp - 3ds Max车道标线生成插件
 * 
 * 基于样条线生成车道特殊符号标线的3ds Max插件
 * 支持RANSAC算法进行车道线拟合和交叉路口识别
 */

#include "RoadLineGenerator.h"

// 插件DLL入口点
BOOL WINAPI DllMain(HINSTANCE hinstDLL, ULONG fdwReason, LPVOID lpvReserved) {
    if (fdwReason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(hinstDLL);
        InitCustomControls(hinstDLL);
        InitCommonControls();
    }
    return TRUE;
}

// 插件描述类实现
class RoadLineGeneratorClassDesc : public ClassDesc2 {
 public:
    int IsPublic() override { return TRUE; }
    void* Create(BOOL loading = FALSE) override { return new RoadLineGenerator; }
    const TCHAR* ClassName() override { return _T("RoadLineGenerator"); }
    SClass_ID SuperClassID() override { return UTILITY_CLASS_ID; }
    Class_ID ClassID() override { return ROADLINEGENERATOR_CLASS_ID; }
    const TCHAR* Category() override { return _T("道路工具"); }
    const TCHAR* InternalName() override { return _T("RoadLineGenerator"); }
    HINSTANCE HInstance() override { return hInstance; }
};

// 全局变量
static RoadLineGeneratorClassDesc RoadLineGeneratorDesc;
HINSTANCE hInstance;

// 返回插件数量
__declspec(dllexport) int LibNumberClasses() {
    return 1;
}

// 返回插件描述
__declspec(dllexport) ClassDesc* LibClassDesc(int i) {
    switch (i) {
        case 0: return &RoadLineGeneratorDesc;
        default: return nullptr;
    }
}

// 插件版本信息
__declspec(dllexport) const TCHAR* LibDescription() {
    return _T("车道标线生成插件");
}

// 插件初始化
__declspec(dllexport) ULONG LibVersion() {
    return VERSION_3DSMAX;
}

// 插件启动函数
__declspec(dllexport) int LibInitialize() {
    hInstance = hInstDLL;
    return TRUE;
}

// 插件关闭函数
__declspec(dllexport) int LibShutdown() {
    return TRUE;
}

// RoadLineGenerator实现
RoadLineGenerator::RoadLineGenerator() {
    iu = nullptr;
    ip = nullptr;
    pblock = nullptr;
}

RoadLineGenerator::~RoadLineGenerator() {
}

void RoadLineGenerator::BeginEditParams(Interface* ip, IUtil* iu) {
    this->iu = iu;
    this->ip = ip;
    
    // 创建参数面板
    roadLineGeneratorRollup = ip->AddRollupPage(
        hInstance,
        MAKEINTRESOURCE(IDD_PANEL),
        RoadLineGeneratorDlgProc,
        _T("车道标线生成器"),
        (LPARAM)this
    );
}

void RoadLineGenerator::EndEditParams(Interface* ip, IUtil* iu) {
    this->iu = nullptr;
    this->ip = nullptr;
    
    // 移除参数面板
    ip->DeleteRollupPage(roadLineGeneratorRollup);
    roadLineGeneratorRollup = nullptr;
}

void RoadLineGenerator::DeleteThis() {
    delete this;
}

// 对话框处理函数在DialogHandler.cpp中实现
extern INT_PTR CALLBACK RoadLineGeneratorDlgProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);


// 生成道路标线
void RoadLineGenerator::GenerateRoadLines(int lineType, float width, float spacing, 
                                        int iterations, float threshold, bool preview, 
                                        Color lineColor) {
    // 获取选中的样条线
    INode* selectedNode = GetSelectedSpline();
    if (!selectedNode) {
        MessageBox(nullptr, _T("请先选择一条样条线！"), _T("错误"), MB_OK | MB_ICONERROR);
        return;
    }
    
    // 如果是预览模式，先清除之前的预览对象
    if (preview) {
        // TODO: 实现预览对象的清除逻辑
    }
    
    // 获取样条线点集
    std::vector<Point> points = GetPointsFromSpline(selectedNode);
    if (points.empty()) {
        MessageBox(nullptr, _T("无法获取样条线数据！"), _T("错误"), MB_OK | MB_ICONERROR);
        return;
    }
    
    // 使用RANSAC算法进行样条线拟合
    std::vector<Point> inliers, outliers;
    int result = RansacLineFitting(points, iterations, 10, threshold, inliers, outliers);
    
    if (result != 0 || inliers.empty()) {
        MessageBox(nullptr, _T("RANSAC拟合失败，请调整参数或检查样条线！"), _T("警告"), MB_OK | MB_ICONWARNING);
        // 继续使用原始点集
        inliers = points;
    }
    
    // 检测是否为交叉路口
    bool isIntersection = DetectIntersection(selectedNode);
    
    // 根据标线类型和参数生成标线
    switch (lineType) {
        case 0: // 实线
            GenerateLaneLine(selectedNode, width, spacing, false);
            break;
            
        case 1: // 虚线
            GenerateLaneLine(selectedNode, width, spacing, true);
            break;
            
        case 2: // 斑马线
            GenerateCrosswalk(selectedNode, width, spacing);
            break;
            
        case 3: // 导流线
            GenerateGuideLine(selectedNode, width);
            break;
            
        default:
            GenerateLaneLine(selectedNode, width, spacing, false);
            break;
    }
    
    // 刷新视图
    ip->RedrawViews(ip->GetTime());
    
    // 如果不是预览模式，显示成功消息
    if (!preview) {
        MessageBox(nullptr, _T("标线生成成功！"), _T("信息"), MB_OK | MB_ICONINFORMATION);
    }
}

// 获取选中的样条线
INode* RoadLineGenerator::GetSelectedSpline() {
    // 获取当前选择
    Interface* ip = GetCOREInterface();
    int numSelected = ip->GetSelNodeCount();
    
    // 遍历选中的节点，查找样条线
    for (int i = 0; i < numSelected; i++) {
        INode* node = ip->GetSelNode(i);
        Object* obj = node->GetObjectRef();
        
        // 检查是否为样条线对象
        if (obj && obj->IsSubClassOf(SPLINE_SHAPE_CLASS_ID)) {
            return node;
        }
    }
    
    return nullptr;
}