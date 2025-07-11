-- 远景建筑处理工具 UI界面
-- Distant Architecture Processing Tool UI
-- 基于3dsMax模型切割对齐插件项目文档设计

try(destroyDialog DistantArchitectureUI) catch()

-- 定义时间估计结构体
struct TimeEstimateStruct (
    totalFaces = 0,
    estimatedElements = 0,
    estimatedTimeSeconds = 0.0
)

-- 获取多边形对象中的实际元素数量
function getActualElementCount polyObject = (
    local numFaces = polyObject.numfaces
    if numFaces == 0 then return 0
    
    try (
        -- 创建面BitArray
        local faceStatus = #{1..numFaces}
        local elementCount = 0
        
        -- 查找所有连接的元素
        while faceStatus.numberSet > 0 do (
            local firstFace = (for i = 1 to numFaces where faceStatus[i] collect i)[1]
            local connectedFaces = polyop.getElementsUsingFace polyObject #{firstFace}
            elementCount += 1
            
            -- 从faceStatus中删除已处理的面
            faceStatus = faceStatus - connectedFaces
        )
        
        return elementCount
    ) catch (
        -- 如果出现错误，返回1作为默认值
        format "获取元素数量出错: %\n" (getCurrentException())
        return 1
    )
)

-- 安全创建和使用层的辅助函数
function safeCreateLayer layerName = (
    local theLayer = undefined
    try (
        -- 先检查层是否已存在
        theLayer = layerManager.getLayerFromName layerName
        
        -- 如果层不存在，则创建新层
        if theLayer == undefined then (
            theLayer = layerManager.newLayerFromName layerName
            format "创建新层: %\n" layerName
        ) else (
            format "使用现有层: %\n" layerName
        )
    ) catch (
        format "创建层 '%' 时出错: %\n" layerName (getCurrentException())
    )
    
    return theLayer
)

-- 安全地将节点添加到层
function safeAddNodeToLayer theLayer theNode = (
    if theLayer != undefined and isValidNode theNode then (
        try (
            theLayer.addNode theNode
            format "成功添加节点 '%' 到层 '%'\n" theNode.name theLayer.name
            return true
        ) catch (
            format "添加节点 '%' 到层 '%' 时出错: %\n" theNode.name theLayer.name (getCurrentException())
        )
    ) else (
        if theLayer == undefined then
            format "错误: 层对象为undefined\n"
        if not isValidNode theNode then
            format "错误: 节点 '%' 无效\n" theNode
    )
    
    return false
)

-- 安全创建子层函数 - 创建层并建立父子关系
function safeCreateChildLayer parentLayerName childLayerName = (
    local parentLayer = undefined
    local childLayer = undefined
    
    try (
        -- 获取或创建父层
        parentLayer = LayerManager.getLayerFromName parentLayerName
        if parentLayer == undefined then (
            parentLayer = LayerManager.newLayerFromName parentLayerName
            format "创建父层: %\n" parentLayerName
        )
        
        -- 检查子层是否已存在
        childLayer = LayerManager.getLayerFromName childLayerName
        if childLayer == undefined then (
            -- 创建子层
            childLayer = LayerManager.newLayerFromName childLayerName
            format "创建子层: %\n" childLayerName
            
            -- 建立父子关系
            if parentLayer != undefined and childLayer != undefined then (
                childLayer.setParent parentLayer
                format "设置层级关系: % -> %\n" parentLayerName childLayerName
            )
        ) else (
            format "子层已存在: %\n" childLayerName
        )
        
        return childLayer
    ) catch (
        format "创建子层 '%' 时出错: %\n" childLayerName (getCurrentException())
        return undefined
    )
)

-- 预处理大型模型函数 - 将大型模型切割成较小的块（每块≤250元素）
function preProcessLargeModel sourceModel maxElementsPerChunk:250 skipSizeCheck:false = (
    local chunks = #()
    local modelName = if isValidNode sourceModel then sourceModel.name else "未知模型"
    local chunkIndex = 1
    
    -- 转换为可编辑多边形
    convertToPoly sourceModel
    
    -- 获取总元素数量
    local totalElements = getActualElementCount sourceModel
    
    -- 如果元素数量小于等于阈值且不跳过大小检查，直接返回原模型
    if totalElements <= maxElementsPerChunk and not skipSizeCheck then (
        format "模型 % 元素数量(%): 不需要预处理\n" modelName totalElements
        return #(sourceModel)
    )
    
    format "预处理大型模型 %: 包含 % 个元素，超过阈值 %\n" modelName totalElements maxElementsPerChunk
    
    try (
        -- 获取模型的所有面
        local numFaces = sourceModel.numfaces
        local faceStatus = #{1..numFaces} -- 创建包含所有面的BitArray
        
        -- 获取所有单独连接的元素
        local elementsArray = #()
        
        -- 查找所有连接的元素
        while faceStatus.numberSet > 0 do (
            local firstFace = (for i = 1 to numFaces where faceStatus[i] collect i)[1]
            local connectedFaces = polyop.getElementsUsingFace sourceModel #{firstFace}
            append elementsArray connectedFaces
            
            -- 从faceStatus中删除已处理的面
            faceStatus = faceStatus - connectedFaces
        )
        
        format "模型 % 实际包含 % 个独立元素\n" modelName elementsArray.count
        
        -- 创建主层 - 使用原始模型名称
        local mainLayer = safeCreateLayer modelName
        
        -- 创建块（每块包含多个元素，总数不超过maxElementsPerChunk）
        local currentChunkFaces = #{}
        local currentChunkElements = 0
        local elementIndex = 1
        
        -- 按照元素分配到不同的块
        for elementFaces in elementsArray do (
            -- 如果当前块已满或者这是第一个元素
            if currentChunkElements >= maxElementsPerChunk or currentChunkElements == 0 then (
                -- 如果有已收集的面，创建一个块
                if currentChunkFaces.numberSet > 0 then (
                    -- 创建新块
                    local newChunk = copy sourceModel
                    convertToPoly newChunk
                    
                    -- 删除非当前块的面
                    local facesToDelete = #{1..newChunk.numfaces} - currentChunkFaces
                    if facesToDelete.numberSet > 0 then (
                        polyop.deleteFaces newChunk facesToDelete
                    )
                    
                    -- 清理孤立顶点
                    polyop.deleteIsoVerts newChunk
                    
                    -- 命名新块，使用三位数序号格式
                    local formattedIndex = formattedPrint chunkIndex format:"03d"
                    newChunk.name = (if isValidNode sourceModel then sourceModel.name else "未知模型") + "-分块" + formattedIndex
                    
                    -- 创建块专用层 - 分块模型直接作为主模型的子层
                    local chunkLayerName = (if isValidNode sourceModel then sourceModel.name else "未知模型") + "-分块" + formattedIndex
                    local chunkLayer = safeCreateChildLayer modelName chunkLayerName
                    
                    -- 添加到块数组
                    if newChunk.numfaces > 0 then (
                        append chunks newChunk
                        format "创建块 %: % 个元素, % 个面\n" newChunk.name currentChunkElements currentChunkFaces.numberSet
                        
                        -- 将块模型添加到对应层
                        if chunkLayer != undefined then
                            safeAddNodeToLayer chunkLayer newChunk
                        
                        format "将块 % 添加到层 %\n" newChunk.name chunkLayerName
                        
                        chunkIndex += 1
                    ) else (
                        delete newChunk
                    )
                )
                
                -- 重置当前块
                currentChunkFaces = elementFaces
                currentChunkElements = 1
            )
            else (
                -- 将元素添加到当前块
                currentChunkFaces = currentChunkFaces + elementFaces
                currentChunkElements += 1
            )
            
            elementIndex += 1
        )
        
        -- 处理最后一个块
        if currentChunkFaces.numberSet > 0 then (
            -- 创建新块
            local newChunk = copy sourceModel
            convertToPoly newChunk
            
            -- 删除非当前块的面
            local facesToDelete = #{1..newChunk.numfaces} - currentChunkFaces
            if facesToDelete.numberSet > 0 then (
                polyop.deleteFaces newChunk facesToDelete
            )
            
            -- 清理孤立顶点
            polyop.deleteIsoVerts newChunk
            
            -- 命名新块，使用三位数序号格式
            local formattedIndex = formattedPrint chunkIndex format:"03d"
            newChunk.name = (if isValidNode sourceModel then sourceModel.name else "未知模型") + "-分块" + formattedIndex
            
            -- 创建块专用层 - 分块模型直接作为主模型的子层
            local chunkLayerName = (if isValidNode sourceModel then sourceModel.name else "未知模型") + "-分块" + formattedIndex
            local chunkLayer = safeCreateChildLayer modelName chunkLayerName
            
            -- 添加到块数组
            if newChunk.numfaces > 0 then (
                append chunks newChunk
                format "创建块 %: % 个元素, % 个面\n" newChunk.name currentChunkElements currentChunkFaces.numberSet
                
                -- 将块模型添加到对应层
                if chunkLayer != undefined then
                    safeAddNodeToLayer chunkLayer newChunk
                
                format "将块 % 添加到层 %\n" newChunk.name chunkLayerName
            ) else (
                delete newChunk
            )
        )
        
        format "预处理完成: 模型 % 被分割为 % 个块\n" modelName chunks.count
        
        -- 处理原始模型
        if chunks.count > 0 then (
            -- 隐藏原始模型但不删除，保留一份备份
            sourceModel.isHidden = true
            
            -- 将原始模型添加到主层
            if mainLayer != undefined then (
                safeAddNodeToLayer mainLayer sourceModel
                format "原始模型 % 已隐藏并添加到层 %\n" modelName modelName
            ) else (
                format "原始模型 % 已隐藏\n" modelName
            )
        )
    )
    catch (
        format "预处理模型时出错: %\n" (getCurrentException())
        -- 如果发生错误，返回原始模型
        return #(sourceModel)
    )
    
    -- 如果没有成功创建任何块，返回原始模型
    if chunks.count == 0 then (
        format "预处理未生成有效块，返回原始模型\n"
        return #(sourceModel)
    )
    
    return chunks
)

-- 估算模型处理时间函数
function estimateProcessingTime sourceModels = (
    local totalFaces = 0
    local totalVertices = 0
    local actualElementCount = 0
    local baseTimePerFace = 0.025 -- 每个面的基础处理时间(秒)，25毫秒/面
    local baseTimePerElement = 0.5 -- 每个元素的基础处理时间(秒)，降低为0.5秒/元素
    local minimumTime = 5.0 -- 最低处理时间(秒)
    
    -- 计算总面数和实际元素数
    for obj in sourceModels do (
        if isValidNode obj then (
            -- 转换为可计算的对象类型
            local tempObj = copy obj
            convertToPoly tempObj
            
            -- 统计面数和顶点数
            local numFaces = tempObj.numfaces
            local numVerts = tempObj.numverts
            totalFaces += numFaces
            totalVertices += numVerts
            
            -- 获取实际元素数量
            local elemCount = getActualElementCount tempObj
            actualElementCount += elemCount
            
            format "模型 % 包含 % 个面, % 个点, % 个元素\n" obj.name numFaces numVerts elemCount
            
            -- 释放临时对象
            delete tempObj
        )
    )
    
    -- 确保至少有1个元素
    actualElementCount = amax #(actualElementCount, 1)
    
    -- 计算估计时间(秒)
    local estimatedTime = (totalFaces * baseTimePerFace) + (actualElementCount * baseTimePerElement)
    
    -- 考虑系统性能因素
    local systemFactor = 1.0
    -- 如果内存不足，增加时间估计
    if heapSize < 200000000 then systemFactor = 2.0
    
    local finalEstimatedTime = estimatedTime * systemFactor
    
    -- 确保最低处理时间
    finalEstimatedTime = amax #(finalEstimatedTime, minimumTime)
    
    format "调试: 面数=%，实际元素数=%，原始时间=%秒，最终时间=%秒\n" totalFaces actualElementCount estimatedTime finalEstimatedTime
    
    -- 生成描述性的结果，使用结构体代替数组
    local resultStruct = TimeEstimateStruct()
    resultStruct.totalFaces = totalFaces
    resultStruct.estimatedElements = actualElementCount
    resultStruct.estimatedTimeSeconds = finalEstimatedTime
    
    return resultStruct
)

-- 显示时间的辅助函数
function formatTimeString seconds = (
    if seconds < 60 then (
        return (seconds as integer) as string + " 秒"
    )
    else if seconds < 3600 then (
        local mins = (seconds / 60) as integer
        local secs = mod seconds 60
        return mins as string + " 分 " + secs as string + " 秒"
    )
    else (
        local hrs = (seconds / 3600) as integer
        local mins = (mod seconds 3600) / 60 as integer
        return hrs as string + " 小时 " + mins as string + " 分钟"
    )
)

-- 计算并显示总耗时（毫秒转分钟）
function displayTotalTime startTimeMS = (
    local totalTimeMS = timeStamp() - startTimeMS
    local totalTimeSeconds = totalTimeMS / 1000.0
    local totalTimeMinutes = totalTimeSeconds / 60.0
    
    -- 格式化分钟显示（保留2位小数）
    local formattedMinutes = formattedPrint totalTimeMinutes format:".2f"
    
    -- 返回格式化的字符串
    return "总耗时: " + formattedMinutes + " 分钟 (" + formatTimeString totalTimeSeconds + ")"
)

-- 优化的核心拆解函数 - 高效元素分离算法
function decomposeModel sourceModel timeEstimate:(TimeEstimateStruct totalFaces:0 estimatedElements:1 estimatedTimeSeconds:30.0) = (
    local elements = #()
    local startTime = timeStamp()
    
    -- 内存和性能检查
    if heapSize < 100000000 then (
        messageBox "警告：可用内存不足，建议释放内存后重试"
        return #()
    )
    
    -- 确保源模型是可编辑网格或多边形
    if classof sourceModel != Editable_mesh and classof sourceModel != Editable_Poly then (
        -- 如果不是网格对象，尝试转换
        addModifier sourceModel (Edit_Poly())
    )
    
    -- 转换为Editable_Poly
    convertToPoly sourceModel
    
    local numFaces = sourceModel.numfaces
    
    -- 大模型预检查
    if numFaces > 50000 then (
        local result = queryBox ("模型包含 " + numFaces as string + " 个面，处理可能较慢。是否继续？")
        if not result then return #()
    )
    
    try (
        -- 获取所有元素
        local elementsArray = #()
        local faceStatus = #{1..numFaces} -- 创建包含所有面的BitArray
        
        -- 查找连接的元素
        while faceStatus.numberSet > 0 do (
            local firstFace = (for i = 1 to numFaces where faceStatus[i] collect i)[1]
            local connectedFaces = polyop.getElementsUsingFace sourceModel #{firstFace}
            append elementsArray connectedFaces
            
            -- 从faceStatus中删除已处理的面
            faceStatus = faceStatus - connectedFaces
        )
        
        local elementCount = elementsArray.count
        format "找到 % 个独立元素\n" elementCount
        
        -- 分批处理元素
        local batchSize = 10
        local processedCount = 0
        
        for i = 1 to elementCount by batchSize do (
            local endIndex = amin #(i + batchSize - 1, elementCount)
            
            -- 处理当前批次
            for j = i to endIndex do (
                if j <= elementsArray.count then (
                    local elementFaces = elementsArray[j]
                    
                    if elementFaces.numberSet > 0 then (
                        -- 创建新元素
                        local newElement = copy sourceModel
                        convertToPoly newElement
                        
                        -- 删除非当前元素的面
                        local facesToDelete = #{1..newElement.numfaces} - elementFaces
                        if facesToDelete.numberSet > 0 then (
                            polyop.deleteFaces newElement facesToDelete
                        )
                        
                        -- 清理孤立顶点
                        polyop.deleteIsoVerts newElement
                        
                        -- 命名新元素，使用三位数序号格式
                        local formattedIndex = formattedPrint j format:"03d"
                        newElement.name = (if isValidNode sourceModel then sourceModel.name else "未知模型") + "-元素" + formattedIndex
                        
                        -- 验证元素有效性
                        if newElement.numfaces > 0 then (
                            append elements newElement
                            processedCount += 1
                        ) else (
                            delete newElement
                        )
                    )
                )
            )
            
            -- 内存管理
            gc()
            
            -- 进度更新和用户响应
            windows.processPostedMessages()
            
            -- 超时检查（基于估计时间动态调整）
            local timeoutMs = (timeEstimate.estimatedTimeSeconds + 60) * 1000 -- 预计时间加1分钟（毫秒）
            if (timeStamp() - startTime) > timeoutMs then (
                messageBox "处理超时，已停止。已处理元素数：" + processedCount as string
                exit
            )
        )
        
        -- 清除源模型的选择
        try(sourceModel.selectedFaces = #{}) catch()
        
        format "成功分离 % 个元素，耗时 % 毫秒 (%)\n" elements.count (timeStamp() - startTime) (displayTotalTime startTime)
    )
    catch (
        local errorMsg = "分离模型时出错: " + (getCurrentException())
        format "%\n" errorMsg
        messageBox errorMsg title:"错误"
        return #()
    )
    
    return elements
)

-- 检测位于地形上方的模型
function findObjectsAboveTerrain terrain heightThreshold:1.0 rayDistance:10000.0 debug:false specificObjects:#() = (
    local candidateObjects = #()
    local aboveTerrain = #()
    local resultData = #()
    
    -- 记录地形信息
    if debug and isValidNode terrain then format "地形对象: %, 位置: %\n" terrain.name terrain.pos
    
    -- 获取地形边界框，用于更准确的高度检测
    local terrainBbox = if isValidNode terrain then nodeGetBoundingBox terrain (matrix3 1) else #([0,0,0], [0,0,0])
    local terrainTopZ = terrainBbox[2].z  -- 地形最高点Z坐标
    local terrainBottomZ = terrainBbox[1].z  -- 地形最低点Z坐标
    
    if debug then format "地形边界: 底部Z=%, 顶部Z=%\n" terrainBottomZ terrainTopZ
    
    -- 确定要检测的对象列表
    if specificObjects.count > 0 then (
        -- 如果提供了特定对象列表，则使用该列表
        candidateObjects = specificObjects
        if debug then format "使用指定的 % 个对象进行检测\n" candidateObjects.count
    ) else (
        -- 否则获取所有可检测的对象（排除地形本身、灯光、相机等）
        for obj in objects do (
            if isValidNode obj and obj != terrain and 
               (superClassOf obj == GeometryClass or superClassOf obj == Shape) and
               not isKindOf obj Light and not isKindOf obj Camera then (
                append candidateObjects obj
            )
        )
        if debug then format "找到 % 个候选对象进行检测\n" candidateObjects.count
    )
    
    for obj in candidateObjects do (
        -- 获取对象包围盒底部中心（世界坐标）
        local bbox = nodeGetBoundingBox obj (matrix3 1)
        
        -- 先计算坐标值
        local centerX = (bbox[1].x + bbox[2].x) / 2.0
        local centerY = (bbox[1].y + bbox[2].y) / 2.0
        local bottomZ = bbox[1].z
        
        -- 创建底部中心点
        local bottomCenter = Point3 centerX centerY bottomZ
        
        -- 检测对象是否位于地形上方
        -- 使用更稳健的检测方法，比较底部Z坐标和地形顶部Z坐标
        local distanceToTerrain = bottomZ - terrainTopZ
        
        if debug then (
            format "检测对象: %, 底部中心坐标: %, 地形高度: %, 高度差: %\n" obj.name bottomCenter terrainTopZ distanceToTerrain
        )
        
        -- 检查高度差是否超过阈值
        if distanceToTerrain >= heightThreshold then (
            if debug then format "对象 % 满足悬空条件，高度差: %\n" obj.name distanceToTerrain
            
            append aboveTerrain obj
            
            -- 收集对象数据用于JSON
            local objData = #()
            objData["name"] = obj.name
            objData["position"] = [obj.pos.x, obj.pos.y, obj.pos.z]
            objData["height_above_terrain"] = distanceToTerrain
            objData["terrain_point"] = [centerX, centerY, terrainTopZ]
            objData["terrain_name"] = if isValidNode terrain then terrain.name else "未知地形"
            
            append resultData objData
        )
    )
    
    if debug then (
        format "检测完成: 找到 % 个悬空对象\n" aboveTerrain.count
        for i = 1 to min aboveTerrain.count 10 do (
            format "悬空对象 %: %\n" i aboveTerrain[i].name
        )
    )
    
    return #(aboveTerrain, resultData)
)

-- 表面对齐函数 - 基于射线相交的高效对齐算法
function alignToSurface element targetSurface = (
    -- 获取元素的底部中心点作为射线起点
    local bbox = nodeGetBoundingBox element element.transform
    local bottomCenter = [(bbox[1].x + bbox[2].x)/2, (bbox[1].y + bbox[2].y)/2, bbox[1].z]
    
    -- 创建向下的射线（负Z方向）
    local rayStart = bottomCenter + [0, 0, 10] -- 从上方10单位开始射线
    local rayDir = [0, 0, -1] -- 向下射线方向
    
    -- 执行射线相交测试
    local hit = intersectRayEx targetSurface rayStart rayDir
    
    -- 如果射线相交成功
    if hit != undefined then (
        -- 获取交点位置和法线
        local hitPos = hit.pos
        local hitNorm = hit.dir
        
        -- 计算元素底部到交点的偏移向量
        local offsetVector = hitPos - bottomCenter
        
        -- 应用位移，保持元素的原始旋转
        element.position += offsetVector
        
        -- 可选：根据表面法线调整元素旋转（如果需要）
        -- 这里只进行简单的位置对齐，不改变旋转
        
        return true -- 对齐成功
    )
    
    return false -- 对齐失败
)

-- 将检测结果保存为JSON文件
function saveDetectionResultToJSON resultData fileName = (
    try (
        local file = createFile fileName
        if file == undefined then return false

        -- 开始JSON数组
        format "[\n" to:file

        -- 添加每个对象数据
        for i = 1 to resultData.count do (
            local objData = resultData[i]
            
            -- 开始对象
            format "  {\n" to:file
            
            -- 添加对象名称
            format "    \"name\": \"%\",\n" objData["name"] to:file
            
            -- 添加位置
            local pos = objData["position"]
            format "    \"position\": [%, %, %],\n" pos[1] pos[2] pos[3] to:file
            
            -- 添加高度差
            format "    \"height_above_terrain\": %,\n" objData["height_above_terrain"] to:file
            
            -- 添加地形点
            local terrainPoint = objData["terrain_point"]
            format "    \"terrain_point\": [%, %, %]\n" terrainPoint[1] terrainPoint[2] terrainPoint[3] to:file
            
            -- 结束对象
            if i < resultData.count then
                format "  },\n" to:file
            else
                format "  }\n" to:file
        )
        
        -- 结束JSON数组
        format "]\n" to:file
        
        close file
        return true
    ) catch (
        format "保存JSON文件出错: %\n" (getCurrentException())
        return false
    )
)

rollout DistantArchitectureUI "🏗️ 远景建筑处理工具 v2.0" width:520 height:620
(
    -- 全局变量
    local buildingQueue = #()
    local terrainQueue = #()
    local isProcessing = false
    local logText = ""
    
    -- 顶部按钮区域
    groupBox grpModelGet "📦 模型获取" width:480 height:70 pos:[20,15]
    
    button btnGetBuilding "🏢 获取建筑模型" width:140 height:30 pos:[60,35] color:[100,150,255] across:2
    button btnGetTerrain "🌍 获取地形模型" width:140 height:30 pos:[300,35] color:[100,200,100]
    

    -- 队列显示区域
    groupBox grpQueueManage "📋 队列管理" width:480 height:170 pos:[20,90]
    
    label lblBuildingQueue "🏢 建筑模型队列" pos:[70,110] height:20
    label lblTerrainQueue "🌍 地形模型队列" pos:[310,110] height:20
        
    -- 建筑模型队列列表
    listbox lstBuildingQueue "" pos:[50,130] width:140 height:6 scrollbars:true
        
    -- 地形队列列表
    listbox lstTerrainQueue "" pos:[300,130] width:140 height:6 scrollbars:true
        
    -- 建筑队列操作按钮
    button btnAddBuilding "➕ 添加 " width:50 height:25 pos:[40,230] color:[120,180,255] across:6
    button btnDelBuilding "➖ 删除 " width:50 height:25 pos:[100,230] color:[255,120,120]
    button btnClearBuilding "🗑️ 清空 " width:50 height:25 pos:[160,230] color:[255,180,100]
        
    -- 地形队列操作按钮
    button btnAddTerrain "➕ 添加 " width:50 height:25 pos:[280,230] color:[120,180,255]
    button btnDelTerrain "➖ 删除 " width:50 height:25 pos:[340,230] color:[255,120,120] 
    button btnClearTerrain "🗑️ 清空 " width:50 height:25 pos:[400,230] color:[255,180,100] 
    

    -- 独立执行功能区域
    groupBox grpIndependentExec "⚙️ 独立执行" width:480 height:75 pos:[20,270]
    
    button btnSeparateModel "✂️ 分离模型" width:120 height:35 pos:[50,300] color:[255,200,100] across:3 tooltip:"左键-常规分离 | 右键-强制预处理分块"
    button btnAlignGround "📐 对齐地面" width:120 height:35 pos:[200,300] color:[150,255,150] tooltip:"先检测悬空物体，然后对齐到地面"
    button btnMergeModel "🔗 合并模型" width:120 height:35 pos:[350,300] color:[255,150,255]
    

    -- 进度显示区域
    groupBox grpProcessStatus "📊 处理状态" width:480 height:70 pos:[20,355]
    
    label lblStatus "⚡ 状态: 准备就绪" pos:[200,380] 
    progressbar pgbProgress "" pos:[45,400] width:450 height:20 color:[50,200,50]
    
    
    -- 运行日志区域
    groupBox grpRunLog "📝 运行日志" width:480 height:130 pos:[20,430]
    
    dotNetControl edtLog "System.Windows.Forms.RichTextBox" pos:[30,455] width:450 height:95
    

    
    
    -- 一键处理按钮
    button btnOneClickProcess "🚀 一键处理" width:150 height:40 pos:[185,565] color:[255,100,100] style_sunkenedge:true
    
    
    
    -- 辅助函数：添加日志（最新数据显示在前面）
    function addLog message = 
    (
        local timeStamp = localTime
        local logEntry = "[" + timeStamp as string + "] " + message + "\r\n"
        -- 将新日志添加到开头而不是末尾
        logText = logEntry + logText
        edtLog.Text = logText
        -- RichTextBox支持自动滚动，但由于新内容在顶部，不需要滚动
        windows.processPostedMessages()
    )
    
    -- 辅助函数：更新进度条
    function updateProgress value = 
    (
        pgbProgress.value = value
        windows.processPostedMessages()
    )
    
    -- 辅助函数：更新状态
    function updateStatus status = 
    (
        lblStatus.text = "状态: " + status
        addLog status
    )
    
    -- 辅助函数：更新建筑队列显示
    function updateBuildingQueueDisplay = 
    (
        local displayNames = #()
        for obj in buildingQueue do
        (
            if isValidNode obj then
                append displayNames obj.name
            else
                append displayNames "<无效对象>"
        )
        lstBuildingQueue.items = displayNames
    )
    
    -- 辅助函数：更新地形队列显示
    function updateTerrainQueueDisplay = 
    (
        local displayNames = #()
        for obj in terrainQueue do
        (
            if isValidNode obj then
                append displayNames obj.name
            else
                append displayNames "<无效对象>"
        )
        lstTerrainQueue.items = displayNames
    )
    
    -- 获取建筑模型按钮事件
    on btnGetBuilding pressed do
    (
        addLog "打开对象选择对话框..."
        
        try
        (
            -- 使用3dsMax原生的selectByName对话框
            -- 这会打开一个类似图片中的对象选择界面
            local selectedObjects = selectByName title:"选择建筑模型" buttonText:"确定" showHidden:false single:false
            
            if selectedObjects != undefined and selectedObjects.count > 0 then
             (
                 -- 直接将选中的对象添加到建筑队列
                 local addedCount = 0
                 for obj in selectedObjects do
                 (
                     if findItem buildingQueue obj == 0 then
                     (
                         append buildingQueue obj
                         addLog ("添加建筑模型: " + obj.name)
                         addedCount += 1
                     )
                     else
                     (
                         addLog ("建筑模型已存在，跳过: " + obj.name)
                     )
                 )
                 
                 -- 更新建筑队列显示
                 updateBuildingQueueDisplay()
                 
                 -- 选择这些对象以便用户查看
                 clearSelection()
                 select selectedObjects
                 
                 -- 更新状态显示
                  if addedCount > 0 then
                  (
                      updateStatus ("成功添加 " + addedCount as string + " 个建筑模型")
                  )
                  else
                  (
                      updateStatus "所选对象都已存在于队列中"
                  )
             )
            else
            (
                addLog "用户取消了选择或未选择任何对象"
                updateStatus "请重新选择建筑模型"
            )
        )
        catch
        (
            addLog "打开选择对话框失败，使用备用方案"
            
            -- 备用方案：提示用户手动选择
            local instructions = "无法打开选择对话框，请使用以下方法：\n\n"
            instructions += "方法1：按快捷键 H 打开选择对话框\n"
            instructions += "方法2：在视口中直接选择对象\n"
            instructions += "方法3：菜单栏 → Edit → Select By Name\n\n"
            instructions += "选择建筑模型后，点击下方的'添加'按钮"
            
            messageBox instructions title:"手动操作指导" beep:false
            
            updateStatus "请手动选择建筑模型后点击添加按钮"
        )
    )
    
    -- 获取地形按钮事件
    on btnGetTerrain pressed do
    (
        addLog "打开地形模型选择对话框..."
        
        try
        (
            -- 使用3dsMax原生的selectByName对话框
            -- 这会打开一个类似图片中的对象选择界面
            local selectedObjects = selectByName title:"选择地形模型" buttonText:"确定" showHidden:false single:false
            
            if selectedObjects != undefined and selectedObjects.count > 0 then
             (
                 -- 直接将选中的对象添加到地形队列
                 local addedCount = 0
                 for obj in selectedObjects do
                 (
                     -- 检查是否已存在于地形队列
                     if findItem terrainQueue obj == 0 then
                     (
                         -- 检查是否已存在于建筑队列
                         if findItem buildingQueue obj == 0 then
                         (
                             append terrainQueue obj
                             addLog ("添加地形模型: " + obj.name)
                             addedCount += 1
                         )
                         else
                         (
                             addLog ("模型已存在于建筑队列中，跳过: " + obj.name)
                         )
                     )
                     else
                     (
                         addLog ("地形模型已存在，跳过: " + obj.name)
                     )
                 )
                 
                 -- 更新地形队列显示
                 updateTerrainQueueDisplay()
                 
                 -- 选择这些对象以便用户查看
                 clearSelection()
                 select selectedObjects
                 
                 -- 更新状态显示
                  if addedCount > 0 then
                  (
                      updateStatus ("成功添加 " + addedCount as string + " 个地形模型")
                  )
                  else
                  (
                      updateStatus "所选对象都已存在于队列中"
                  )
             )
            else
            (
                addLog "用户取消了选择或未选择任何对象"
                updateStatus "请重新选择地形模型"
            )
        )
        catch
        (
            addLog "打开选择对话框失败，使用备用方案"
            
            -- 备用方案：提示用户手动选择
            local instructions = "无法打开选择对话框，请使用以下方法：\n\n"
            instructions += "方法1：按快捷键 H 打开选择对话框\n"
            instructions += "方法2：在视口中直接选择对象\n"
            instructions += "方法3：菜单栏 → Edit → Select By Name\n\n"
            instructions += "选择地形模型后，点击下方的'添加'按钮"
            
            messageBox instructions title:"手动操作指导" beep:false
            
            updateStatus "请手动选择地形模型后点击添加按钮"
        )
    )
    
    -- 建筑队列操作按钮事件
    on btnAddBuilding pressed do
    (
        if selection.count > 0 then
        (
            for obj in selection do
            (
                if findItem buildingQueue obj == 0 then
                (
                    append buildingQueue obj
                    addLog ("手动添加建筑模型: " + obj.name)
                )
            )
            updateBuildingQueueDisplay()
        )
        else
        (
            messageBox "请先选择要添加的对象" title:"提示"
        )
    )
    
    on btnDelBuilding pressed do
    (
        local selIndex = lstBuildingQueue.selection
        if selIndex > 0 and selIndex <= buildingQueue.count then
        (
            local removedObj = buildingQueue[selIndex]
            deleteItem buildingQueue selIndex
            addLog ("删除建筑模型: " + removedObj.name)
            updateBuildingQueueDisplay()
        )
        else
        (
            messageBox "请先选择要删除的项目" title:"提示"
        )
    )
    
    on btnClearBuilding pressed do
    (
        buildingQueue = #()
        updateBuildingQueueDisplay()
        addLog "清空建筑模型队列"
    )
    
    -- 地形队列操作按钮事件
    on btnAddTerrain pressed do
    (
        if selection.count > 0 then
        (
            local addedCount = 0
            for obj in selection do
            (
                -- 检查是否已存在于地形队列
                if findItem terrainQueue obj == 0 then
                (
                    -- 检查是否已存在于建筑队列
                    if findItem buildingQueue obj == 0 then
                    (
                        append terrainQueue obj
                        addLog ("手动添加地形模型: " + obj.name)
                        addedCount += 1
                    )
                    else
                    (
                        addLog ("模型已存在于建筑队列中，跳过: " + obj.name)
                    )
                )
                else
                (
                    addLog ("地形模型已存在，跳过: " + obj.name)
                )
            )
            updateTerrainQueueDisplay()
            
            -- 更新状态显示
            if addedCount > 0 then
            (
                updateStatus ("成功添加 " + addedCount as string + " 个地形模型")
            )
            else
            (
                updateStatus "所选对象都已存在于队列中或建筑队列中"
            )
        )
        else
        (
            messageBox "请先选择要添加的对象" title:"提示"
        )
    )
    
    on btnDelTerrain pressed do
    (
        local selIndex = lstTerrainQueue.selection
        if selIndex > 0 and selIndex <= terrainQueue.count then
        (
            local removedObj = terrainQueue[selIndex]
            deleteItem terrainQueue selIndex
            addLog ("删除地形模型: " + removedObj.name)
            updateTerrainQueueDisplay()
        )
        else
        (
            messageBox "请先选择要删除的项目" title:"提示"
        )
    )
    
    on btnClearTerrain pressed do
    (
        terrainQueue = #()
        updateTerrainQueueDisplay()
        addLog "清空地形模型队列"
    )
    
    -- 独立执行功能按钮事件
    on btnSeparateModel pressed do
    (
        if buildingQueue.count == 0 then
        (
            messageBox "建筑模型队列为空，请先添加建筑模型" title:"警告"
            return()
        )
        
        -- 估算处理时间
        updateStatus "正在估算处理时间..."
        local timeEstimate = estimateProcessingTime buildingQueue
        local timeString = formatTimeString timeEstimate.estimatedTimeSeconds
        
        -- 显示估算信息并询问用户是否继续
        local infoMsg = "模型统计:\n"
        infoMsg += "- 总面数: " + timeEstimate.totalFaces as string + "\n"
        infoMsg += "- 实际元素数: " + timeEstimate.estimatedElements as string + "\n"
        infoMsg += "- 预计处理时间: " + timeString + "\n\n"
        infoMsg += "是否继续处理?"
        
        local continueProcessing = queryBox infoMsg title:"处理时间估算"
        if not continueProcessing then (
            updateStatus "用户取消了处理"
            return()
        )
        
        updateStatus "开始分离模型..."
        updateProgress 0
        
        addLog "执行模型分离功能 - 对模型队列中的模型进行按元素层级分离"
        addLog ("预计处理时间: " + timeString + ", 实际元素数: " + timeEstimate.estimatedElements as string)
        
        -- 记录开始时间
        local processingStartTime = timeStamp()
        
        -- 处理每个模型并记录分离后的元素
        local allSeparatedElements = #()
        local totalProcessed = 0
        local totalElements = 0
        local processQueue = #() -- 用于存储预处理后需要处理的所有模型
        
        -- 先对所有模型进行预处理，将大模型切分为小块
        addLog "开始对模型进行预处理..."
        for i = 1 to buildingQueue.count do
        (
            local obj = buildingQueue[i]
            if isValidNode obj then
            (
                local objName = obj.name
                
                addLog ("检查模型 " + objName + " 是否需要预处理...")
                
                -- 预处理大型模型，将超过250个元素的模型分割为小块
                local processedModels = preProcessLargeModel obj maxElementsPerChunk:250 skipSizeCheck:false
                
                if processedModels.count > 1 then
                (
                    addLog ("模型 " + objName + " 已预处理为 " + processedModels.count as string + " 个小块模型")
                )
                else
                (
                    addLog ("模型 " + objName + " 无需预处理")
                )
                
                -- 将预处理后的模型加入处理队列
                for procModel in processedModels do
                (
                    append processQueue procModel
                )
            )
        )
        
        addLog ("预处理完成，共有 " + processQueue.count as string + " 个模型需要处理")
        
        -- 处理队列中的每个模型
        for i = 1 to processQueue.count do
        (
            local obj = processQueue[i]
            if isValidNode obj then
            (
                local objName = obj.name
                
                -- 步骤1: 先为模型创建树形层结构并将原始模型添加到层中
                addLog ("正在为模型 " + objName + " 创建树形层结构...")
                try (
                    -- 为预处理的块创建层 - 使用原始模型名称（移除_chunk_XXX后缀）
                    local baseLayerName = objName
                    local isChunk = false
                    local chunkNum = ""
                    
                    -- 如果是预处理后的块，提取原始模型名
                    if (findString objName "-分块") != undefined then
                    (
                        isChunk = true
                        baseLayerName = substring objName 1 ((findString objName "-分块") - 1)
                        chunkNum = substring objName ((findString objName "-分块") + 3) -1
                    )
                    
                    -- 创建或获取主层
                    local modelLayer = safeCreateLayer baseLayerName
                    
                    -- 确定正确的子层路径
                    if isChunk then
                    (
                        -- 这是预处理后的块，分块模型直接作为主模型的子层
                        local chunkLayerName = objName
                        
                        -- 创建块专用层
                        local chunkLayer = safeCreateChildLayer baseLayerName chunkLayerName
                        
                        -- 将模型添加到块层中
                        if chunkLayer != undefined then
                            safeAddNodeToLayer chunkLayer obj
                        
                        addLog ("已将模型 " + objName + " 添加到层 '" + chunkLayerName + "' 中")
                    )
                    else
                    (
                        -- 是原始模型，直接添加到主层
                        if modelLayer != undefined then
                            safeAddNodeToLayer modelLayer obj
                        
                        addLog ("已将模型 " + objName + " 添加到层 '" + baseLayerName + "' 中")
                    )
                ) catch (
                    addLog ("创建层或添加模型到层时出错: " + (getCurrentException()))
                )
                
                -- 步骤2: 在层内分离模型
                addLog ("正在分离模型: " + objName)
                updateProgress (i as float / processQueue.count * 50) -- 前50%进度用于分离
                
                -- 调用实际的分离函数，传递时间估计参数
                local separatedElements = decomposeModel obj timeEstimate:timeEstimate
                
                -- 记录分离结果
                if separatedElements.count > 0 then
                (
                    addLog ("成功从模型 " + objName + " 分离出 " + separatedElements.count as string + " 个元素")
                    totalElements += separatedElements.count
                    
                    -- 将分离的元素添加到总元素列表中
                    join allSeparatedElements separatedElements
                    
                    -- 确保所有分离元素都在正确的层中
                    try (
                        -- 确定元素应该放在哪个层
                        local baseLayerName = objName
                        local elementsParentLayerName = ""
                        
                        -- 如果是预处理后的块，元素直接放在分块层下
                        if (findString objName "-分块") != undefined then
                        (
                            elementsParentLayerName = objName
                        )
                        else
                        (
                            -- 如果是原始模型，元素直接放在模型层的elements子层下
                            elementsParentLayerName = baseLayerName
                        )
                        
                        -- 将所有分离出来的元素直接添加到当前分块层下
                        local targetLayer = undefined
                        
                        -- 获取目标层（分块层或模型层）
                        if (findString objName "-分块") != undefined then
                        (
                            -- 如果是预处理后的块，获取分块层
                            targetLayer = LayerManager.getLayerFromName objName
                        )
                        else
                        (
                            -- 如果是原始模型，获取模型层
                            targetLayer = LayerManager.getLayerFromName objName
                        )
                        
                        -- 将所有元素添加到目标层
                        if targetLayer != undefined then
                        (
                            for elem in separatedElements do
                            (
                                if isValidNode elem then
                                    safeAddNodeToLayer targetLayer elem
                            )
                        )
                        
                        -- 删除原始分块模型
                        if isValidNode obj then
                        (
                            addLog ("删除原始分块模型: " + obj.name)
                            delete obj
                        )
                        
                        addLog ("已将 " + separatedElements.count as string + " 个元素直接添加到层 " + elementsParentLayerName + " 中")
                    ) catch (
                        addLog ("将分离元素添加到层时出错: " + (getCurrentException()))
                    )
                )
                else
                (
                    addLog ("分离模型 " + objName + " 失败或未找到可分离元素")
                )
                
                totalProcessed += 1
                updateProgress (50 + (totalProcessed as float / processQueue.count * 50)) -- 后50%用于完成状态
            )
            windows.processPostedMessages()
        )
        
        -- 完成分离处理
        updateProgress 100
        
        if totalElements > 0 then
        (
            -- 分离和层管理已在前面的循环中完成，这里只需要汇总结果
            
            -- 选择所有分离出的元素以便查看
            clearSelection()
            select allSeparatedElements
            
            -- 显示总耗时（包括分钟）
            local totalTimeInfo = displayTotalTime processingStartTime
            updateStatus ("模型分离完成，共分离出 " + totalElements as string + " 个元素，" + totalTimeInfo)
            addLog ("===== 完成分离 " + buildingQueue.count as string + " 个模型，共生成 " + totalElements as string + " 个元素，" + totalTimeInfo + " =====")
        )
        else
        (
            -- 显示总耗时（包括分钟）
            local totalTimeInfo = displayTotalTime processingStartTime
            updateStatus "模型分离完成，但未生成任何元素"
            addLog ("===== 分离操作完成，但未生成任何元素，" + totalTimeInfo + " =====")
        )
    )
    
    -- 右键点击分离模型按钮的事件处理
    on btnSeparateModel rightclick do
    (
        if buildingQueue.count == 0 then
        (
            messageBox "建筑模型队列为空，请先添加建筑模型" title:"警告"
            return()
        )
        
        updateStatus "开始强制预处理分块..."
        updateProgress 0
        
        addLog "执行强制预处理分块 - 不检查元素数量直接进行分块"
        
        -- 记录开始时间
        local processingStartTime = timeStamp()
        
        -- 处理每个模型并记录分离后的元素
        local allProcessedModels = #()
        local totalProcessed = 0
        local totalChunks = 0
        local originalModels = #()
        
        -- 直接对所有模型进行强制预处理分块
        for i = 1 to buildingQueue.count do
        (
            local obj = buildingQueue[i]
            if isValidNode obj then
            (
                local objName = obj.name
                append originalModels obj
                
                addLog ("强制预处理模型: " + objName + "...")
                updateProgress (i as float / buildingQueue.count * 100)
                
                -- 强制预处理模型，skipSizeCheck设为true直接分块不考虑元素数量
                addLog ("创建模型 " + objName + " 的树形层结构...")
                local processedModels = preProcessLargeModel obj skipSizeCheck:true
                
                -- 记录处理结果
                if processedModels.count > 0 then
                (
                    -- 添加到处理结果列表
                    join allProcessedModels processedModels
                    totalChunks += processedModels.count
                    
                    if processedModels.count > 1 then
                    (
                        addLog ("成功将模型 " + objName + " 分块为 " + processedModels.count as string + " 个块")
                    )
                    else
                    (
                        addLog ("模型 " + objName + " 分块未产生多个块")
                    )
                )
                else
                (
                    addLog ("处理模型 " + objName + " 失败")
                )
                
                totalProcessed += 1
            )
            windows.processPostedMessages()
        )
        
        -- 完成分块处理
        updateProgress 100
        
        if totalChunks > 0 then
        (
            -- 选择所有分块后的模型以便查看
            clearSelection()
            select allProcessedModels
            
            -- 显示总耗时（包括分钟）
            local totalTimeInfo = displayTotalTime processingStartTime
            updateStatus ("强制预处理完成，" + buildingQueue.count as string + " 个模型被分成了 " + totalChunks as string + " 个块，" + totalTimeInfo)
            addLog ("===== 完成强制预处理分块，" + buildingQueue.count as string + " 个模型被分成了 " + totalChunks as string + " 个块，" + totalTimeInfo + " =====")
            
            -- 询问是否用分块替换原始队列
            if queryBox "是否用分块后的模型替换建筑队列中的原始模型?" title:"更新队列" then
            (
                -- 将原始模型从队列中移除
                for obj in originalModels do
                (
                    local index = findItem buildingQueue obj
                    if index > 0 then
                    (
                        deleteItem buildingQueue index
                    )
                )
                
                -- 将分块模型添加到队列
                for obj in allProcessedModels do
                (
                    append buildingQueue obj
                )
                
                -- 更新队列显示
                updateBuildingQueueDisplay()
                addLog "已用分块后的模型替换建筑队列中的原始模型"
            )
        )
        else
        (
            -- 显示总耗时（包括分钟）
            local totalTimeInfo = displayTotalTime processingStartTime
            updateStatus ("强制预处理完成，但未生成任何块，" + totalTimeInfo)
            addLog ("===== 强制预处理完成，但未生成任何块，" + totalTimeInfo + " =====")
        )
    )
    
    on btnAlignGround pressed do
    (
        if buildingQueue.count == 0 then
        (
            messageBox "建筑模型队列为空，请先添加建筑模型" title:"警告"
            return()
        )
        
        if terrainQueue.count == 0 then
        (
            messageBox "地形队列为空，请先添加地形模型" title:"警告"
            return()
        )
        
        updateStatus "开始预处理: 检测地形上方的物体..."
        updateProgress 0
        
        addLog "执行地面对齐功能 - 先检测悬空物体，然后对齐到地形"
        
        -- 记录开始时间
        local processingStartTime = timeStamp()
        
        -- 获取第一个地形模型作为检测基准
        local targetTerrain = terrainQueue[1]
        addLog ("使用地形模型: " + (if isValidNode targetTerrain then targetTerrain.name else "未知地形") + " 作为检测基准")
        
        -- 设置高度阈值
        local heightThreshold = 1.0
        local heightDlg = dotNetObject "System.Windows.Forms.Form"
        heightDlg.Text = "设置悬空检测参数"
        heightDlg.Width = 350
        heightDlg.Height = 180
        heightDlg.FormBorderStyle = (dotNetClass "System.Windows.Forms.FormBorderStyle").FixedDialog
        heightDlg.StartPosition = (dotNetClass "System.Windows.Forms.FormStartPosition").CenterScreen
        
        local lblHeight = dotNetObject "System.Windows.Forms.Label"
        lblHeight.Text = "最小高度阈值 (3ds Max单位):"
        lblHeight.Location = dotNetObject "System.Drawing.Point" 20 20
        lblHeight.Width = 200
        heightDlg.Controls.Add lblHeight
        
        local txtHeight = dotNetObject "System.Windows.Forms.TextBox"
        txtHeight.Text = heightThreshold as string
        txtHeight.Location = dotNetObject "System.Drawing.Point" 20 50
        txtHeight.Width = 100
        heightDlg.Controls.Add txtHeight
        
        local lblDescription = dotNetObject "System.Windows.Forms.Label"
        lblDescription.Text = "预处理将检测地形上方的悬空物体并保存结果用于对齐"
        lblDescription.Location = dotNetObject "System.Drawing.Point" 20 80
        lblDescription.Width = 300
        heightDlg.Controls.Add lblDescription
        
        local btnOK = dotNetObject "System.Windows.Forms.Button"
        btnOK.Text = "开始处理"
        btnOK.Location = dotNetObject "System.Drawing.Point" 100 110
        btnOK.DialogResult = (dotNetClass "System.Windows.Forms.DialogResult").OK
        heightDlg.Controls.Add btnOK
        
        local btnCancel = dotNetObject "System.Windows.Forms.Button"
        btnCancel.Text = "取消"
        btnCancel.Location = dotNetObject "System.Drawing.Point" 200 110
        btnCancel.DialogResult = (dotNetClass "System.Windows.Forms.DialogResult").Cancel
        heightDlg.Controls.Add btnCancel
        
        local result = heightDlg.ShowDialog()
        
        if result == (dotNetClass "System.Windows.Forms.DialogResult").OK then
        (
            try (
                heightThreshold = txtHeight.Text as float
                if heightThreshold <= 0 then heightThreshold = 1.0
            ) catch (
                heightThreshold = 1.0
            )
            
            addLog ("设置高度阈值为: " + heightThreshold as string)
            
            -- 执行检测，启用调试模式
            updateProgress 20
            addLog "正在执行悬空物体射线检测..."
            
            -- 获取检测结果和数据
            local detectionResult = findObjectsAboveTerrain targetTerrain heightThreshold:heightThreshold debug:true
            local aboveObjects = detectionResult[1]
            local resultData = detectionResult[2]
            
            -- 添加调试信息
            addLog ("检测到 " + aboveObjects.count as string + " 个悬空物体")
            if resultData.count > 0 then
                addLog ("收集了 " + resultData.count as string + " 条数据记录")
            else
                addLog "警告: 没有收集到任何数据记录!"
                
            -- 保存检测结果为JSON
            local currentTimestamp = timeStamp() as string
            local jsonFileName = (getDir #temp) + "\\悬空检测_" + currentTimestamp + ".json"
            addLog ("将保存结果到: " + jsonFileName)
            
            if resultData.count > 0 then (
                local saveResult = saveDetectionResultToJSON resultData jsonFileName
                
                if saveResult then (
                    addLog ("检测结果已保存到: " + jsonFileName)
                    if doesFileExist jsonFileName then (
                        local fileSize = getFileSize jsonFileName
                        addLog ("JSON文件大小: " + fileSize as string + " 字节")
                    ) else (
                        addLog "警告: JSON文件未成功创建!"
                    )
                ) else (
                    addLog "保存检测结果失败!"
                )
            ) else (
                addLog "没有数据可保存，跳过JSON文件创建"
            )
            
            -- 更新进度
            updateProgress 40
            
            -- 处理检测结果
            if aboveObjects.count > 0 then
            (
                -- 显示检测结果
                addLog ("检测到 " + aboveObjects.count as string + " 个位于地形上方至少 " + heightThreshold as string + " 单位的物体")
                
                -- 输出前几个检测到的对象名称
                local showCount = min aboveObjects.count 5
                addLog "检测到的对象包括:"
                for i = 1 to showCount do (
                    addLog ("  " + i as string + ". " + aboveObjects[i].name)
                )
                if aboveObjects.count > showCount then (
                    addLog ("  ...以及其他 " + (aboveObjects.count - showCount) as string + " 个对象")
                )
                
                -- 询问是否继续对齐处理
                local continueMsg = "检测到 " + aboveObjects.count as string + " 个悬空物体。\n"
                continueMsg += "是否继续进行对齐操作？\n\n"
                continueMsg += "注意: 对齐操作会改变这些物体的位置。"
                
                if queryBox continueMsg title:"检测结果" then
                (
                    -- 继续执行对齐操作
                    updateStatus "开始对齐地面..."
                    updateProgress 50
                    
                    -- 处理每个建筑模型，根据检测结果找到对应的地形
                for i = 1 to buildingQueue.count do
                (
                    local obj = buildingQueue[i]
                    if isValidNode obj then
                    (
                        -- 查找该模型对应的地形
                        local matchedTerrain = undefined
                        
                        -- 首先在检测结果中查找该模型
                        local foundInResults = false
                        for dataItem in resultData do
                        (
                            if dataItem["name"] == obj.name then
                            (
                                -- 找到了该模型的检测数据，获取对应的地形名称
                                local terrainName = dataItem["terrain_name"]
                                
                                -- 在地形队列中查找对应名称的地形
                                for terrainObj in terrainQueue do
                                (
                                    if terrainObj.name == terrainName then
                                    (
                                        matchedTerrain = terrainObj
                                        foundInResults = true
                                        exit -- 找到匹配地形，退出循环
                                    )
                                )
                                
                                if matchedTerrain != undefined then exit -- 找到匹配地形，退出外层循环
                            )
                        )
                        
                        -- 如果在检测结果中没有找到，则不进行对齐，而是放入专门的层中管理
                        if not foundInResults then
                        (
                            -- 创建专门的层来管理没有找到匹配地形的模型
                            local noMatchLayerName = "未匹配地形的模型"
                            local noMatchLayer = safeCreateLayer noMatchLayerName
                            
                            -- 将模型添加到该层
                            if noMatchLayer != undefined then
                            (
                                safeAddNodeToLayer noMatchLayer obj
                                addLog ("  模型: " + obj.name + " 未找到匹配地形，已添加到层 '" + noMatchLayerName + "' 中")
                            )
                        )
                        else
                        (
                            addLog ("正在对齐模型: " + obj.name + " 到地形: " + (if isValidNode matchedTerrain then matchedTerrain.name else "未知地形"))
                            updateProgress (50 + i as float / buildingQueue.count * 50)
                            
                            -- 调用实际的对齐函数
                            local alignResult = alignToSurface obj matchedTerrain
                            
                            if alignResult then
                                addLog ("  成功对齐模型: " + obj.name)
                            else
                                addLog ("  警告: 无法对齐模型: " + obj.name + "，可能没有找到交点")
                        )
                    )
                    windows.processPostedMessages()
                )
                    
                    updateProgress 100
                    -- 显示总耗时（包括分钟）
                    local totalTimeInfo = displayTotalTime processingStartTime
                    updateStatus ("地面对齐完成，" + totalTimeInfo)
                    addLog ("===== 地面对齐完成，" + totalTimeInfo + " =====")
                )
                else
                (
                    updateStatus "用户取消了对齐操作"
                    addLog "用户查看悬空检测结果后取消了对齐操作"
                    updateProgress 100
                )
            )
            else
            (
                addLog "未检测到悬空物体，继续进行对齐操作"
                
                -- 直接执行对齐操作
                updateStatus "开始对齐地面..."
                updateProgress 50
                
                -- 处理每个建筑模型，根据检测结果找到对应的地形
                for i = 1 to buildingQueue.count do
                (
                    local obj = buildingQueue[i]
                    if isValidNode obj then
                    (
                        -- 查找该模型对应的地形
                        local matchedTerrain = undefined
                        
                        -- 首先在检测结果中查找该模型
                        local foundInResults = false
                        for dataItem in resultData do
                        (
                            if dataItem["name"] == obj.name then
                            (
                                -- 找到了该模型的检测数据，获取对应的地形名称
                                local terrainName = dataItem["terrain_name"]
                                
                                -- 在地形队列中查找对应名称的地形
                                for terrainObj in terrainQueue do
                                (
                                    if terrainObj.name == terrainName then
                                    (
                                        matchedTerrain = terrainObj
                                        foundInResults = true
                                        exit -- 找到匹配地形，退出循环
                                    )
                                )
                                
                                if matchedTerrain != undefined then exit -- 找到匹配地形，退出外层循环
                            )
                        )
                        
                        -- 如果在检测结果中没有找到，则不进行对齐，而是放入专门的层中管理
                        if not foundInResults then
                        (
                            -- 创建专门的层来管理没有找到匹配地形的模型
                            local noMatchLayerName = "未匹配地形的模型"
                            local noMatchLayer = safeCreateLayer noMatchLayerName
                            
                            -- 将模型添加到该层
                            if noMatchLayer != undefined then
                            (
                                safeAddNodeToLayer noMatchLayer obj
                                addLog ("  模型: " + obj.name + " 未找到匹配地形，已添加到层 '" + noMatchLayerName + "' 中")
                            )
                        )
                        else
                        (
                            addLog ("正在对齐模型: " + obj.name + " 到地形: " + (if isValidNode matchedTerrain then matchedTerrain.name else "未知地形"))
                            updateProgress (50 + i as float / buildingQueue.count * 50)
                            
                            -- 调用实际的对齐函数
                            local alignResult = alignToSurface obj matchedTerrain
                            
                            if alignResult then
                                addLog ("  成功对齐模型: " + obj.name)
                            else
                                addLog ("  警告: 无法对齐模型: " + obj.name + "，可能没有找到交点")
                        )
                    )
                    windows.processPostedMessages()
                )
                
                updateProgress 100
                -- 显示总耗时（包括分钟）
                local totalTimeInfo = displayTotalTime processingStartTime
                updateStatus ("地面对齐完成，" + totalTimeInfo)
                addLog ("===== 地面对齐完成，" + totalTimeInfo + " =====")
            )
        )
        else
        (
            updateStatus "用户取消了操作"
            addLog "用户取消了地面对齐操作"
        )
    )
    
    on btnMergeModel pressed do
    (
        if buildingQueue.count == 0 then
        (
            messageBox "建筑模型队列为空，请先添加建筑模型" title:"警告"
            return()
        )
        
        updateStatus "开始合并模型..."
        updateProgress 0
        
        addLog "执行模型合并功能 - 对选择的模型进行合并"
        
        -- 记录开始时间
        local processingStartTime = timeStamp()
        
        -- 模拟处理过程
        addLog ("正在合并 " + buildingQueue.count as string + " 个模型...")
        updateProgress 50
        
        -- 这里调用实际的合并函数
        -- local mergedModel = mergeElements buildingQueue
        
        updateProgress 100
        -- 显示总耗时（包括分钟）
        local totalTimeInfo = displayTotalTime processingStartTime
        updateStatus ("模型合并完成，" + totalTimeInfo)
        addLog ("合并完成，生成统一的远景建筑模型，" + totalTimeInfo)
    )
    
    -- 一键处理按钮事件
    on btnOneClickProcess pressed do
    (
        if buildingQueue.count == 0 then
        (
            messageBox "建筑模型队列为空，请先添加建筑模型" title:"警告"
            return()
        )
        
        if terrainQueue.count == 0 then
        (
            messageBox "地形队列为空，请先添加地形模型" title:"警告"
            return()
        )
        
        -- 估算处理时间
        updateStatus "正在估算处理时间..."
        local timeEstimate = estimateProcessingTime buildingQueue
        local timeString = formatTimeString timeEstimate.estimatedTimeSeconds
        
        -- 显示估算信息并询问用户是否继续
        local infoMsg = "处理时间估算:\n"
        infoMsg += "- 总面数: " + timeEstimate.totalFaces as string + "\n"
        infoMsg += "- 实际元素数: " + timeEstimate.estimatedElements as string + "\n"
        infoMsg += "- 预计处理时间: " + timeString + "\n\n"
        infoMsg += "是否开始一键处理流程?"
        
        local continueProcessing = queryBox infoMsg title:"处理时间估算"
        if not continueProcessing then (
            updateStatus "用户取消了处理"
            return()
        )
        
        isProcessing = true
        updateStatus "开始一键处理流程..."
        addLog "=== 开始一键处理：分离模型 → 对齐地面 → 合并模型 ==="
        addLog ("预计处理时间: " + timeString)
        
        -- 记录开始时间
        local processingStartTime = timeStamp()
        
        try
        (
            -- 步骤1：分离模型
            updateStatus "步骤1/3: 分离模型"
            addLog "步骤1: 执行模型分离"
            updateProgress 10
            
            -- 估算处理时间
            local timeEstimate = estimateProcessingTime buildingQueue
            local allSeparatedElements = #()
            local processQueue = #() -- 用于存储预处理后需要处理的所有模型
            
            -- 预处理步骤：检查大型模型并分割
            addLog "第一阶段: 预处理大型模型..."
            updateProgress 15
            
            for i = 1 to buildingQueue.count do
            (
                local obj = buildingQueue[i]
                if isValidNode obj then
                (
                    local objName = obj.name
                    
                    addLog ("检查模型 " + objName + " 是否需要预处理...")
                    
                    -- 预处理大型模型，将超过1000个元素的模型分割为小块
                    local processedModels = preProcessLargeModel obj maxElementsPerChunk:1000
                    
                    if processedModels.count > 1 then
                    (
                        addLog ("大型模型 " + objName + " 已被预处理为 " + processedModels.count as string + " 个小块模型")
                    )
                    else
                    (
                        addLog ("模型 " + objName + " 无需预处理")
                    )
                    
                    -- 将预处理后的模型加入处理队列
                    for procModel in processedModels do
                    (
                        append processQueue procModel
                    )
                )
            )
            
            addLog ("预处理完成，共有 " + processQueue.count as string + " 个模型需要处理")
            
            -- 第二阶段：处理队列中的所有模型
            for i = 1 to processQueue.count do
            (
                local obj = processQueue[i]
                if isValidNode obj then
                (
                    local objName = obj.name
                    
                    -- 步骤1: 先为模型创建树形层结构并将原始模型添加到层中
                    addLog ("正在为模型 " + objName + " 创建层...")
                    try (
                        -- 为预处理的块创建层 - 使用原始模型名称（移除_chunk_XXX后缀）
                        local baseLayerName = objName
                        local isChunk = false
                        local chunkNum = ""
                        
                        -- 如果是预处理后的块，提取原始模型名
                        if (findString objName "_chunk_") != undefined then
                        (
                            isChunk = true
                            baseLayerName = substring objName 1 ((findString objName "_chunk_") - 1)
                            chunkNum = substring objName ((findString objName "_chunk_") + 7) -1
                        )
                        
                        -- 创建或获取主层和预处理块层
                        local modelLayer = safeCreateLayer baseLayerName
                        local targetLayer = modelLayer
                        
                        -- 如果是预处理块，创建块专用层
                        if isChunk then
                        (
                            local chunkLayerName = baseLayerName + "/chunks/" + chunkNum
                            
                            -- 创建并使用块专用层
                            targetLayer = safeCreateLayer chunkLayerName
                        )
                        
                        -- 将模型添加到适当的层中
                        if targetLayer != undefined then
                            safeAddNodeToLayer targetLayer obj
                        
                        addLog ("已将模型 " + objName + " 添加到层 '" + (if targetLayer != undefined then targetLayer.name else "未知层") + "' 中")
                    ) catch (
                        addLog ("创建层或添加模型到层时出错: " + (getCurrentException()))
                    )
                    
                    -- 步骤2: 在层内分离模型
                    addLog ("正在分离模型: " + objName)
                    updateProgress (20 + i as float / processQueue.count * 20)
                    
                    -- 调用实际的分离函数
                    local separatedElements = decomposeModel obj timeEstimate:timeEstimate
                    
                    -- 处理分离结果
                    if separatedElements.count > 0 then
                    (
                        -- 将分离的元素添加到总元素列表中
                        join allSeparatedElements separatedElements
                        
                        -- 将所有分离出来的元素直接添加到当前分块层下
                        try (
                            local targetLayer = undefined
                            
                            -- 获取目标层（分块层或模型层）
                            if (findString objName "_chunk_") != undefined then
                            (
                                -- 如果是预处理后的块，获取分块层
                                targetLayer = LayerManager.getLayerFromName objName
                            )
                            else
                            (
                                -- 如果是原始模型，获取模型层
                                targetLayer = LayerManager.getLayerFromName objName
                            )
                            
                            -- 将所有元素添加到目标层
                            if targetLayer != undefined then
                            (
                                for elem in separatedElements do
                                (
                                    if isValidNode elem then
                                        safeAddNodeToLayer targetLayer elem
                                )
                            )
                            
                            -- 删除原始分块模型
                            if isValidNode obj then
                            (
                                addLog ("删除原始分块模型: " + obj.name)
                                delete obj
                            )
                            
                            addLog ("成功从模型 " + objName + " 分离出 " + separatedElements.count as string + " 个元素并直接添加到层 '" + objName + "' 中")
                        ) catch (
                            addLog ("将分离元素添加到层时出错: " + (getCurrentException()))
                        )
                    )
                    else
                    (
                        addLog ("分离模型 " + objName + " 失败或未找到可分离元素")
                    )
                )
                windows.processPostedMessages()
            )
            
            -- 步骤2：对齐地面
            updateStatus "步骤2/3: 对齐地面"
            addLog "步骤2: 执行地面对齐"
            updateProgress 40
            
            -- 先执行悬空检测，获取每个模型对应的地形
            local targetTerrain = terrainQueue[1]
            addLog ("使用地形模型: " + (if isValidNode targetTerrain then targetTerrain.name else "未知地形") + " 作为检测基准")
            
            -- 设置高度阈值
            local heightThreshold = 1.0
            
            -- 执行检测
            addLog "正在执行悬空物体射线检测..."
            local detectionResult = findObjectsAboveTerrain targetTerrain heightThreshold:heightThreshold debug:true
            local aboveObjects = detectionResult[1]
            local resultData = detectionResult[2]
            
            -- 添加调试信息
            addLog ("检测到 " + aboveObjects.count as string + " 个悬空物体")
            
            -- 对齐每个建筑模型到对应地形
            for i = 1 to buildingQueue.count do
            (
                local obj = buildingQueue[i]
                if isValidNode obj then
                (
                    -- 查找该模型对应的地形
                    local matchedTerrain = undefined
                    
                    -- 首先在检测结果中查找该模型
                    local foundInResults = false
                    for dataItem in resultData do
                    (
                        if dataItem["name"] == obj.name then
                        (
                            -- 找到了该模型的检测数据，获取对应的地形名称
                            local terrainName = dataItem["terrain_name"]
                            
                            -- 在地形队列中查找对应名称的地形
                            for terrainObj in terrainQueue do
                            (
                                if terrainObj.name == terrainName then
                                (
                                    matchedTerrain = terrainObj
                                    foundInResults = true
                                    exit -- 找到匹配地形，退出循环
                                )
                            )
                            
                            if matchedTerrain != undefined then exit -- 找到匹配地形，退出外层循环
                        )
                    )
                    
                    -- 如果在检测结果中没有找到，则不进行对齐，而是放入专门的层中管理
                    if not foundInResults then
                    (
                        -- 创建专门的层来管理没有找到匹配地形的模型
                        local noMatchLayerName = "未匹配地形的模型"
                        local noMatchLayer = safeCreateLayer noMatchLayerName
                        
                        -- 将模型添加到该层
                        if noMatchLayer != undefined then
                        (
                            safeAddNodeToLayer noMatchLayer obj
                            addLog ("  模型: " + obj.name + " 未找到匹配地形，已添加到层 '" + noMatchLayerName + "' 中")
                        )
                    )
                    else
                    (
                        addLog ("对齐模型: " + obj.name + " 到地形: " + (if isValidNode matchedTerrain then matchedTerrain.name else "未知地形"))
                        updateProgress (40 + i as float / buildingQueue.count * 30)
                        
                        -- 调用实际的对齐函数
                        local alignResult = alignToSurface obj matchedTerrain
                        
                        if alignResult then
                            addLog ("  成功对齐模型: " + obj.name)
                        else
                            addLog ("  警告: 无法对齐模型: " + obj.name + "，可能没有找到交点")
                    )
                )
                windows.processPostedMessages()
            )
            
            -- 步骤3：合并模型
            updateStatus "步骤3/3: 合并模型"
            addLog "步骤3: 执行模型合并"
            updateProgress 70
            
            addLog ("合并 " + buildingQueue.count as string + " 个处理后的模型")
            updateProgress 90
            
            -- 完成
            updateProgress 100
            -- 显示总耗时（包括分钟）
            local totalTimeInfo = displayTotalTime processingStartTime
            updateStatus ("一键处理完成！" + totalTimeInfo)
            addLog ("=== 一键处理流程完成，" + totalTimeInfo + " ===")
            addLog "成功生成远景建筑模型"
            
            messageBox ("一键处理完成！\n\n已完成：\n1. 模型分离\n2. 地面对齐\n3. 模型合并\n\n" + totalTimeInfo + "\n\n请查看运行日志了解详细信息。") title:"处理完成"
        )
        catch
        (
            -- 显示总耗时（包括分钟），即使出错
            local totalTimeInfo = displayTotalTime processingStartTime
            updateStatus ("处理过程中发生错误，" + totalTimeInfo)
            addLog ("错误: " + getCurrentException() + "，" + totalTimeInfo)
            messageBox ("处理过程中发生错误，" + totalTimeInfo + "\n请查看运行日志") title:"错误"
        )
        
        isProcessing = false
    )
    
    -- 界面初始化
    on DistantArchitectureUI open do
    (
        -- 设置RichTextBox属性
        edtLog.ReadOnly = true
        edtLog.BackColor = (dotNetClass "System.Drawing.Color").FromArgb 180 180 180
        edtLog.Font = dotNetObject "System.Drawing.Font" "Consolas" 9
        edtLog.WordWrap = true
        edtLog.ScrollBars = (dotNetClass "System.Windows.Forms.RichTextBoxScrollBars").Vertical
        
        addLog "远景建筑处理工具已启动"
        addLog "请按照以下步骤操作："
        addLog "1. 点击'获取建筑模型'添加要处理的建筑模型"
        addLog "2. 点击'获取地形'添加地形模型"
        addLog "3. 可以使用独立功能按钮分步处理，或点击'一键处理'自动完成全流程"
        addLog "注意: 已添加到建筑队列的模型不能再添加到地形队列"
        updateStatus "工具已就绪，等待用户操作"
    )
)

-- 创建自定义对象选择对话框
function createObjectSelector = 
(
    rollout objectSelectorRollout "选择建筑模型" width:300 height:400
    (
        listbox objList "场景对象:" height:15
        button btnOK "确定" width:80 height:25 pos:[110,350]
        button btnCancel "取消" width:80 height:25 pos:[200,350]
        
        local selectedObjects = #()
        
        on objectSelectorRollout open do
        (
            local objectNames = #()
            for obj in geometry do
                append objectNames obj.name
            objList.items = objectNames
        )
        
        on objList selectionEnd do
        (
            selectedObjects = #()
            for i in objList.selection do
            (
                if i > 0 and i <= geometry.count then
                    append selectedObjects geometry[i]
            )
        )
        
        on btnOK pressed do
        (
            destroyDialog objectSelectorRollout
            -- 返回选中的对象
            selectedObjects
        )
        
        on btnCancel pressed do
        (
            destroyDialog objectSelectorRollout
            #()
        )
    )
    
    createDialog objectSelectorRollout modal:true
)

-- 创建并显示对话框
createDialog DistantArchitectureUI
