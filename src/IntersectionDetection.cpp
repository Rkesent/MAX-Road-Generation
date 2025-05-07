/**
 * IntersectionDetection.cpp - 交叉路口识别实现
 * 
 * 实现基于几何分析的交叉路口识别功能
 */

#include "RoadLineGenerator.h"

/**
 * 检测交叉路口
 * 
 * @param splineNode 样条线节点
 * @return 是否为交叉路口
 */
bool RoadLineGenerator::DetectIntersection(INode* splineNode) {
    if (!splineNode) return false;
    
    // 获取当前场景中的所有节点
    Interface* ip = GetCOREInterface();
    INode* rootNode = ip->GetRootNode();
    int numChildren = rootNode->NumChildren();
    
    // 获取当前样条线的点集
    std::vector<Point> currentPoints = GetPointsFromSpline(splineNode);
    if (currentPoints.empty()) return false;
    
    // 获取当前样条线的宽度（可以从参数面板获取或使用默认值）
    float roadWidth = 10.0f; // 默认道路宽度为10米
    
    // 遍历场景中的所有节点，查找其他样条线
    int intersectionCount = 0;
    for (int i = 0; i < numChildren; i++) {
        INode* childNode = rootNode->GetChildNode(i);
        
        // 跳过当前样条线
        if (childNode == splineNode) continue;
        
        // 检查是否为样条线
        Object* obj = childNode->GetObjectRef();
        if (!obj || !obj->IsSubClassOf(SPLINE_SHAPE_CLASS_ID)) continue;
        
        // 获取其他样条线的点集
        std::vector<Point> otherPoints = GetPointsFromSpline(childNode);
        if (otherPoints.empty()) continue;
        
        // 检查两条样条线是否相交
        bool hasIntersection = false;
        for (const auto& p1 : currentPoints) {
            if (hasIntersection) break;
            
            for (const auto& p2 : otherPoints) {
                // 计算两点之间的距离
                double distance = sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2));
                
                // 如果距离小于道路宽度的平均值，则认为存在交叉
                if (distance < roadWidth) {
                    hasIntersection = true;
                    intersectionCount++;
                    break;
                }
            }
        }
    }
    
    // 如果交叉数量大于0，则认为是交叉路口
    return intersectionCount > 0;
}

/**
 * 分析交叉路口类型
 * 
 * @param splineNode 样条线节点
 * @param intersectingNodes 与之相交的样条线节点列表
 * @return 交叉路口类型（0=未知，1=十字路口，2=T型路口，3=Y型路口，4=环形路口）
 */
int AnalyzeIntersectionType(INode* splineNode, const std::vector<INode*>& intersectingNodes) {
    if (intersectingNodes.empty()) return 0;
    
    // 根据相交样条线的数量和夹角判断路口类型
    int numIntersections = intersectingNodes.size();
    
    // 如果只有一条相交线，可能是T型或Y型
    if (numIntersections == 1) {
        // 计算夹角（这里需要获取样条线的切线方向）
        // 简化示例，实际实现需要计算样条线在交点处的切线方向
        double angle = 90.0; // 假设夹角为90度
        
        // 根据夹角判断类型
        if (angle > 80.0 && angle < 100.0) {
            return 2; // T型路口（接近90度）
        } else {
            return 3; // Y型路口（非90度）
        }
    }
    // 如果有多条相交线，可能是十字路口或环形路口
    else if (numIntersections >= 2) {
        // 这里可以添加更复杂的逻辑来区分十字路口和环形路口
        // 例如，检查样条线是否形成闭环
        return 1; // 默认为十字路口
    }
    
    return 0; // 未知类型
}

/**
 * 计算两条线段之间的夹角
 * 
 * @param v1 第一条线段的方向向量
 * @param v2 第二条线段的方向向量
 * @return 夹角（度）
 */
double CalculateAngle(const Point3& v1, const Point3& v2) {
    // 计算点积
    double dotProduct = v1.x * v2.x + v1.y * v2.y + v1.z * v2.z;
    
    // 计算向量长度
    double length1 = sqrt(v1.x * v1.x + v1.y * v1.y + v1.z * v1.z);
    double length2 = sqrt(v2.x * v2.x + v2.y * v2.y + v2.z * v2.z);
    
    // 计算夹角（弧度）
    double angle = acos(dotProduct / (length1 * length2));
    
    // 转换为度
    return angle * 180.0 / M_PI;
}