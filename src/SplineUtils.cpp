/**
 * SplineUtils.cpp - 样条线工具函数实现
 * 
 * 实现从样条线获取点集等辅助功能
 */

#include "RoadLineGenerator.h"

/**
 * 从样条线获取点集
 * 
 * @param splineNode 样条线节点
 * @return 点集
 */
std::vector<Point> RoadLineGenerator::GetPointsFromSpline(INode* splineNode) {
    std::vector<Point> points;
    
    if (!splineNode) return points;
    
    // 获取当前时间
    TimeValue t = ip->GetTime();
    
    // 获取对象引用
    Object* obj = splineNode->GetObjectRef();
    if (!obj || !obj->IsSubClassOf(SPLINE_SHAPE_CLASS_ID)) return points;
    
    // 转换为样条线形状
    ShapeObject* shapeObj = (ShapeObject*)obj;
    
    // 获取样条线的世界变换矩阵
    Matrix3 tm = splineNode->GetNodeTM(t);
    
    // 获取样条线的形状
    PolyShape shape;
    shapeObj->MakePolyShape(t, shape);
    
    // 遍历所有样条线段
    for (int i = 0; i < shape.numLines; i++) {
        PolyLine* polyline = shape.lines + i;
        
        // 遍历样条线段上的所有点
        for (int j = 0; j < polyline->numPts; j++) {
            // 获取点的世界坐标
            Point3 worldPt = polyline->pts[j].p * tm;
            
            // 添加到点集
            Point pt;
            pt.x = worldPt.x;
            pt.y = worldPt.y;
            points.push_back(pt);
        }
    }
    
    return points;
}