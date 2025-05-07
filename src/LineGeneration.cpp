/**
 * LineGeneration.cpp - 标线生成实现
 * 
 * 实现不同类型标线的生成逻辑
 */

#include "RoadLineGenerator.h"

/**
 * 生成车道线
 * 
 * @param splineNode 样条线节点
 * @param width 标线宽度
 * @param spacing 标线间距
 * @param isDashed 是否为虚线
 */
void RoadLineGenerator::GenerateLaneLine(INode* splineNode, float width, float spacing, bool isDashed) {
    if (!splineNode) return;
    
    // 获取当前时间
    TimeValue t = ip->GetTime();
    
    // 获取对象引用
    Object* obj = splineNode->GetObjectRef();
    if (!obj || !obj->IsSubClassOf(SPLINE_SHAPE_CLASS_ID)) return;
    
    // 转换为样条线形状
    ShapeObject* shapeObj = (ShapeObject*)obj;
    
    // 创建标线几何体
    // 方法1：使用扫描修改器
    // 创建一个矩形截面
    GenRectObject* rectObj = (GenRectObject*)CreateInstance(GEOMOBJECT_CLASS_ID, Class_ID(RECTANGLE_CLASS_ID, 0));
    if (!rectObj) return;
    
    // 设置矩形参数
    rectObj->SetParams(width, 0.02f, 1, 1, 0, 0); // 宽度、高度、长度分段、宽度分段、生成映射坐标、实体
    
    // 创建节点
    INode* lineNode = ip->CreateObjectNode(rectObj);
    if (!lineNode) {
        rectObj->DeleteThis();
        return;
    }
    
    // 设置节点名称
    TSTR nodeName = isDashed ? _T("虚线标线") : _T("实线标线");
    lineNode->SetName(nodeName);
    
    // 创建扫描修改器
    Modifier* sweepMod = (Modifier*)CreateInstance(OSM_CLASS_ID, Class_ID(SWEEP_CLASS_ID, 0));
    if (!sweepMod) return;
    
    // 应用修改器
    lineNode->AddModifier(sweepMod);
    
    // 设置扫描修改器参数
    // 注意：实际实现需要使用IParamBlock2接口设置参数
    // 这里简化处理，实际开发中需要查阅SDK文档获取正确的参数ID
    
    // 设置路径为样条线
    // 注意：实际实现需要使用控制器和引用系统
    // 这里简化处理，实际开发中需要查阅SDK文档获取正确的方法
    
    // 如果是虚线，需要设置分段参数
    if (isDashed) {
        // 设置分段参数
        // 注意：实际实现需要使用IParamBlock2接口设置参数
    }
    
    // 设置材质
    StdMat* lineMat = NewDefaultStdMat();
    lineMat->SetName(_T("标线材质"));
    
    // 设置材质颜色（默认为白色）
    lineMat->SetDiffuse(Color(1.0f, 1.0f, 1.0f), t);
    lineMat->SetAmbient(Color(1.0f, 1.0f, 1.0f), t);
    lineMat->SetShininess(0.9f, t);
    lineMat->SetShinStr(0.75f, t);
    
    // 应用材质
    lineNode->SetMtl(lineMat);
    
    // 刷新视图
    ip->RedrawViews(t);
}

/**
 * 生成斑马线
 * 
 * @param splineNode 样条线节点
 * @param width 标线宽度
 * @param spacing 标线间距
 */
void RoadLineGenerator::GenerateCrosswalk(INode* splineNode, float width, float spacing) {
    if (!splineNode) return;
    
    // 获取当前时间
    TimeValue t = ip->GetTime();
    
    // 获取对象引用
    Object* obj = splineNode->GetObjectRef();
    if (!obj || !obj->IsSubClassOf(SPLINE_SHAPE_CLASS_ID)) return;
    
    // 转换为样条线形状
    ShapeObject* shapeObj = (ShapeObject*)obj;
    
    // 获取样条线的点集
    std::vector<Point> points = GetPointsFromSpline(splineNode);
    if (points.size() < 2) return;
    
    // 计算样条线的方向向量
    Point startPoint = points.front();
    Point endPoint = points.back();
    Point direction;
    direction.x = endPoint.x - startPoint.x;
    direction.y = endPoint.y - startPoint.y;
    
    // 计算垂直于方向的向量
    Point perpendicular;
    perpendicular.x = -direction.y;
    perpendicular.y = direction.x;
    
    // 归一化垂直向量
    double length = sqrt(perpendicular.x * perpendicular.x + perpendicular.y * perpendicular.y);
    if (length > 0) {
        perpendicular.x /= length;
        perpendicular.y /= length;
    }
    
    // 计算斑马线的长度（样条线长度）
    double splineLength = sqrt(direction.x * direction.x + direction.y * direction.y);
    
    // 计算斑马线的条数
    int numStripes = (int)(splineLength / (width + spacing));
    if (numStripes < 1) numStripes = 1;
    
    // 创建斑马线几何体
    for (int i = 0; i < numStripes; i++) {
        // 计算当前条纹的位置
        double position = i * (width + spacing);
        if (position > splineLength) break;
        
        // 计算条纹的中心点
        Point center;
        center.x = startPoint.x + (direction.x * position / splineLength);
        center.y = startPoint.y + (direction.y * position / splineLength);
        
        // 创建一个矩形对象表示条纹
        GenRectObject* rectObj = (GenRectObject*)CreateInstance(GEOMOBJECT_CLASS_ID, Class_ID(RECTANGLE_CLASS_ID, 0));
        if (!rectObj) continue;
        
        // 设置矩形参数（宽度为条纹宽度，长度为道路宽度）
        rectObj->SetParams(width, 20.0f, 1, 1, 0, 0); // 宽度、高度、长度分段、宽度分段、生成映射坐标、实体
        
        // 创建节点
        INode* stripeNode = ip->CreateObjectNode(rectObj);
        if (!stripeNode) {
            rectObj->DeleteThis();
            continue;
        }
        
        // 设置节点名称
        TSTR nodeName = _T("斑马线条纹");
        stripeNode->SetName(nodeName);
        
        // 设置节点位置和旋转
        Matrix3 tm;
        tm.IdentityMatrix();
        
        // 设置位置
        tm.SetTrans(Point3(center.x, 0.0f, center.y)); // 注意：y和z轴交换
        
        // 设置旋转（使条纹垂直于样条线方向）
        // 注意：实际实现需要计算正确的旋转矩阵
        
        // 应用变换
        stripeNode->SetNodeTM(t, tm);
        
        // 设置材质
        StdMat* stripeMat = NewDefaultStdMat();
        stripeMat->SetName(_T("斑马线材质"));
        
        // 设置材质颜色（默认为白色）
        stripeMat->SetDiffuse(Color(1.0f, 1.0f, 1.0f), t);
        stripeMat->SetAmbient(Color(1.0f, 1.0f, 1.0f), t);
        
        // 应用材质
        stripeNode->SetMtl(stripeMat);
    }
    
    // 刷新视图
    ip->RedrawViews(t);
}

/**
 * 生成导流线
 * 
 * @param splineNode 样条线节点
 * @param width 标线宽度
 */
void RoadLineGenerator::GenerateGuideLine(INode* splineNode, float width) {
    if (!splineNode) return;
    
    // 获取当前时间
    TimeValue t = ip->GetTime();
    
    // 获取对象引用
    Object* obj = splineNode->GetObjectRef();
    if (!obj || !obj->IsSubClassOf(SPLINE_SHAPE_CLASS_ID)) return;
    
    // 转换为样条线形状
    ShapeObject* shapeObj = (ShapeObject*)obj;
    
    // 检测是否为交叉路口
    bool isIntersection = DetectIntersection(splineNode);
    
    // 根据是否为交叉路口选择不同的生成策略
    if (isIntersection) {
        // 交叉路口导流线（箭头形状）
        // 创建箭头几何体
        // 注意：实际实现需要创建箭头形状或使用预定义的箭头模型
        // 这里简化处理，使用一个简单的锥体表示箭头
        GenCylObject* coneObj = (GenCylObject*)CreateInstance(GEOMOBJECT_CLASS_ID, Class_ID(CONE_CLASS_ID, 0));
        if (!coneObj) return;
        
        // 设置锥体参数
        coneObj->SetParams(width * 2.0f, 0.0f, 5.0f, 12, 1, 0, 0); // 底部半径、顶部半径、高度、分段、生成映射坐标、实体
        
        // 创建节点
        INode* arrowNode = ip->CreateObjectNode(coneObj);
        if (!arrowNode) {
            coneObj->DeleteThis();
            return;
        }
        
        // 设置节点名称
        arrowNode->SetName(_T("导流箭头"));
        
        // 获取样条线的点集
        std::vector<Point> points = GetPointsFromSpline(splineNode);
        if (points.size() < 2) return;
        
        // 计算箭头位置（样条线的末端）
        Point endPoint = points.back();
        
        // 计算方向向量（使用最后两个点）
        Point direction;
        if (points.size() >= 2) {
            Point secondLastPoint = points[points.size() - 2];
            direction.x = endPoint.x - secondLastPoint.x;
            direction.y = endPoint.y - secondLastPoint.y;
        } else {
            direction.x = 1.0;
            direction.y = 0.0;
        }
        
        // 归一化方向向量
        double length = sqrt(direction.x * direction.x + direction.y * direction.y);
        if (length > 0) {
            direction.x /= length;
            direction.y /= length;
        }
        
        // 设置箭头位置和旋转
        Matrix3 tm;
        tm.IdentityMatrix();
        
        // 设置位置
        tm.SetTrans(Point3(endPoint.x, 0.0f, endPoint.y)); // 注意：y和z轴交换
        
        // 设置旋转（使箭头指向样条线方向）
        // 注意：实际实现需要计算正确的旋转矩阵
        
        // 应用变换
        arrowNode->SetNodeTM(t, tm);
        
        // 设置材质
        StdMat* arrowMat = NewDefaultStdMat();
        arrowMat->SetName(_T("导流箭头材质"));
        
        // 设置材质颜色（默认为黄色）
        arrowMat->SetDiffuse(Color(1.0f, 1.0f, 0.0f), t);
        arrowMat->SetAmbient(Color(1.0f, 1.0f, 0.0f), t);
        
        // 应用材质
        arrowNode->SetMtl(arrowMat);
    } else {
        // 普通导流线（虚线）
        GenerateLaneLine(splineNode, width, width * 2.0f, true);
    }
    
    // 刷新视图
    ip->RedrawViews(t);
}