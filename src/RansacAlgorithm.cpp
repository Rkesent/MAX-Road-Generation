/**
 * RansacAlgorithm.cpp - RANSAC算法实现
 * 
 * 实现基于RANSAC的车道线拟合算法
 */

#include "RoadLineGenerator.h"

/**
 * RANSAC车道线拟合算法
 * 
 * @param points 输入点集
 * @param maxiter 最大迭代次数
 * @param consensus_thres 一致性阈值
 * @param dis_thres 距离阈值
 * @param inlier_cloud 输出内点集
 * @param outlier_cloud 输出外点集
 * @return 0表示成功找到模型，1表示失败
 */
int RoadLineGenerator::RansacLineFitting(const std::vector<Point>& points, int maxiter, int consensus_thres, double dis_thres,
                                         std::vector<Point>& inlier_cloud, std::vector<Point>& outlier_cloud) {
    int point_num = points.size();
    if (point_num < 2) {
        return 1; // 点数不足，无法拟合
    }
    
    // 初始化随机数生成器
    std::default_random_engine rng;
    rng.seed(10);
    std::uniform_int_distribution<unsigned> uniform(0, point_num - 1);
    
    // 初始化变量
    std::set<int> selectIndexs, consensusIndexs, bestConsensusIndexs;
    std::vector<Point> selectPoints;
    int isNonFind = 1;
    int bestconsensus_num = 0;
    int iter = 0;
    double best_A = 0, best_B = 0, best_C = 0;
    double tmp_A, tmp_B, tmp_C;
    
    // RANSAC主循环
    while (iter < maxiter) {
        selectIndexs.clear();
        selectPoints.clear();
        
        // 随机选择两个点
        while (1) {
            int index = uniform(rng);
            selectIndexs.insert(index);
            if (selectIndexs.size() == 2) { // 2个样本点
                break;
            }
        }
        
        // 获取样本点
        for (auto selectiter = selectIndexs.begin(); selectiter != selectIndexs.end(); ++selectiter) {
            int index = *selectiter;
            selectPoints.push_back(points[index]);
        }
        
        // 计算直线参数 Ax + By + C = 0
        double deltaY = selectPoints[1].y - selectPoints[0].y;
        double deltaX = selectPoints[1].x - selectPoints[0].x;
        tmp_A = deltaY;
        tmp_B = -deltaX;
        tmp_C = -deltaY * selectPoints[1].x + deltaX * selectPoints[1].y;
        
        // 计算内点
        consensusIndexs.clear();
        for (int dataiter = 0; dataiter < point_num; ++dataiter) {
            // 计算点到直线的距离
            double dist = (tmp_A * points[dataiter].x + tmp_B * points[dataiter].y + tmp_C) /
                          sqrt(tmp_A * tmp_A + tmp_B * tmp_B);
            dist = dist > 0 ? dist : -dist; // 取绝对值
            
            // 如果距离小于阈值，则为内点
            if (dist < dis_thres) {
                consensusIndexs.insert(dataiter);
            }
        }
        
        // 更新最佳模型
        int currentconsensus_num = consensusIndexs.size();
        if (currentconsensus_num > bestconsensus_num) {
            bestconsensus_num = currentconsensus_num;
            bestConsensusIndexs = consensusIndexs;
            best_A = tmp_A;
            best_B = tmp_B;
            best_C = tmp_C;
            
            // 如果内点数量超过阈值，则认为找到了好的模型
            if (currentconsensus_num >= consensus_thres) {
                isNonFind = 0;
                break;
            }
        }
        
        iter++;
    }
    
    // 分离内点和外点
    inlier_cloud.clear();
    outlier_cloud.clear();
    for (int i = 0; i < point_num; ++i) {
        if (bestConsensusIndexs.find(i) != bestConsensusIndexs.end()) {
            inlier_cloud.push_back(points[i]);
        } else {
            outlier_cloud.push_back(points[i]);
        }
    }
    
    // 使用所有内点重新拟合模型（可选）
    if (!isNonFind && inlier_cloud.size() >= 2) {
        // 这里可以实现基于所有内点的最小二乘拟合，提高模型精度
        // 为简化示例，此处省略
    }
    
    return isNonFind;
}

/**
 * 从样条线获取点集
 * 
 * @param splineNode 样条线节点
 * @return 点集
 */
std::vector<Point> RoadLineGenerator::GetPointsFromSpline(INode* splineNode) {
    std::vector<Point> points;
    
    if (!splineNode) return points;
    
    // 获取对象引用
    Object* obj = splineNode->GetObjectRef();
    if (!obj || !obj->IsSubClassOf(SPLINE_SHAPE_CLASS_ID)) return points;
    
    // 转换为样条线形状
    ShapeObject* shapeObj = (ShapeObject*)obj;
    
    // 获取样条线
    BezierShape* bezShape = nullptr;
    PolyShape* polyShape = nullptr;
    
    // 检查是否为贝塞尔样条线
    if (shapeObj->IsSubClassOf(BEZIER_SHAPE_CLASS_ID)) {
        bezShape = &((BezierShape*)shapeObj)->shape;
    }
    // 检查是否为多段线样条线
    else if (shapeObj->IsSubClassOf(POLYSHAPE_CLASS_ID)) {
        polyShape = &((PolyShape*)shapeObj)->shape;
    }
    
    // 处理贝塞尔样条线
    if (bezShape) {
        // 获取样条线数量
        int numSplines = bezShape->SplineCount();
        
        // 遍历每条样条线
        for (int i = 0; i < numSplines; i++) {
            Spline3D* spline = bezShape->GetSpline(i);
            int numKnots = spline->KnotCount();
            
            // 遍历每个节点
            for (int j = 0; j < numKnots; j++) {
                Point3 knotPoint = spline->GetKnotPoint(j);
                
                // 转换为2D点（忽略Y轴，使用XZ平面）
                Point point;
                point.x = knotPoint.x;
                point.y = knotPoint.z; // 使用z作为y坐标
                
                points.push_back(point);
            }
        }
    }
    // 处理多段线样条线
    else if (polyShape) {
        // 获取样条线数量
        int numSplines = polyShape->numLines;
        
        // 遍历每条样条线
        for (int i = 0; i < numSplines; i++) {
            PolyLine* polyLine = polyShape->lines + i;
            int numVerts = polyLine->numPts;
            
            // 遍历每个顶点
            for (int j = 0; j < numVerts; j++) {
                Point3 vertPoint = polyLine->pts[j].p;
                
                // 转换为2D点（忽略Y轴，使用XZ平面）
                Point point;
                point.x = vertPoint.x;
                point.y = vertPoint.z; // 使用z作为y坐标
                
                points.push_back(point);
            }
        }
    }
    
    return points;
}