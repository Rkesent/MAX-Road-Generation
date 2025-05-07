/**
// UTF-8 BOM
xEFxBBxBF/*
 * RoadLineGenerator.h - 3ds Max车道标线生成插件头文件
 * 
 * 定义插件的类结构和常量
 */

#pragma once

#include <max.h>
#include <iparamb2.h>
#include <iparamm2.h>
#include <maxtypes.h>
#include <utilapi.h>
#include <shape.h>
#include <spline3d.h>
#include <splshape.h>
#include <vector>
#include <random>
#include <set>
#include <cmath>

// 资源ID
#define IDD_PANEL               101
#define IDC_BTN_GENERATE        1001
#define IDC_CMB_LINE_TYPE       1002
#define IDC_EDIT_WIDTH          1003
#define IDC_EDIT_SPACING        1004
#define IDC_CHK_PREVIEW         1005
#define IDC_CLR_LINE            1006

// 类ID
#define ROADLINEGENERATOR_CLASS_ID Class_ID(0x12345678, 0x87654321)

// 前向声明
class RoadLineGenerator;

// 对话框处理函数
INT_PTR CALLBACK RoadLineGeneratorDlgProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);

// 全局变量
extern HINSTANCE hInstance;

// 点结构体（用于RANSAC算法）
struct Point {
    double x;
    double y;
};

/**
 * 车道标线生成器类
 * 实现基于样条线生成车道标线的功能
 */
class RoadLineGenerator : public UtilityObj {
public:
    // 构造函数和析构函数
    RoadLineGenerator();
    ~RoadLineGenerator();
    
    // UtilityObj接口实现
    void BeginEditParams(Interface* ip, IUtil* iu) override;
    void EndEditParams(Interface* ip, IUtil* iu) override;
    void DeleteThis() override;
    
    // 生成道路标线
    void GenerateRoadLines(int lineType = 0, float width = 0.15f, float spacing = 0.3f, 
                          int iterations = 100, float threshold = 0.1f, bool preview = false, 
                          Color lineColor = Color(1.0f, 1.0f, 1.0f));
    
    // RANSAC算法实现
    int RansacLineFitting(const std::vector<Point>& points, int maxiter, int consensus_thres, double dis_thres,
                          std::vector<Point>& inlier_cloud, std::vector<Point>& outlier_cloud);
    
    // 交叉路口识别
    bool DetectIntersection(INode* splineNode);
    
private:
    // 获取选中的样条线
    INode* GetSelectedSpline();
    
    // 从样条线获取点集
    std::vector<Point> GetPointsFromSpline(INode* splineNode);
    
    // 生成不同类型的标线
    void GenerateLaneLine(INode* splineNode, float width, float spacing, bool isDashed);
    void GenerateCrosswalk(INode* splineNode, float width, float spacing);
    void GenerateGuideLine(INode* splineNode, float width);
    
    // 成员变量
    Interface* ip;
    IUtil* iu;
    IParamBlock2* pblock;
    HWND roadLineGeneratorRollup;
};