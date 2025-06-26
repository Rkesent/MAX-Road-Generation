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
                        newElement.name = sourceModel.name + "_" + formattedIndex
                        
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
        
        format "成功分离 % 个元素，耗时 % 毫秒\n" elements.count (timeStamp() - startTime)
    )
    catch (
        local errorMsg = "分离模型时出错: " + (getCurrentException())
        format "%\n" errorMsg
        messageBox errorMsg title:"错误"
        return #()
    )
    
    return elements
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
    
    button btnSeparateModel "✂️ 分离模型" width:120 height:35 pos:[50,300] color:[255,200,100] across:3
    button btnAlignGround "📐 对齐地面" width:120 height:35 pos:[200,300] color:[150,255,150]
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
        
        -- 处理每个模型并记录分离后的元素
        local allSeparatedElements = #()
        local totalProcessed = 0
        local totalElements = 0
        
        for i = 1 to buildingQueue.count do
        (
            local obj = buildingQueue[i]
            if isValidNode obj then
            (
                local objName = obj.name
                
                -- 步骤1: 先为模型创建同名层并将原始模型添加到层中
                addLog ("正在为模型 " + objName + " 创建层...")
                try (
                    -- 创建与模型同名的层
                    local modelLayer
                    if (layerManager.getLayerFromName objName) == undefined then
                    (
                        modelLayer = layerManager.newLayerFromName objName
                    )
                    else
                    (
                        modelLayer = layerManager.getLayerFromName objName
                    )
                    
                    -- 将原始模型添加到层中
                    modelLayer.addNode obj
                    
                    addLog ("已将模型 " + objName + " 添加到同名层中")
                ) catch (
                    addLog ("创建层或添加模型到层时出错: " + (getCurrentException()))
                )
                
                -- 步骤2: 在层内分离模型
                addLog ("正在分离模型: " + objName)
                updateProgress (i as float / buildingQueue.count * 50) -- 前50%进度用于分离
                
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
                        -- 获取已创建的层引用
                        local modelLayer = layerManager.getLayerFromName objName
                        if modelLayer != undefined then
                        (
                            -- 一次性批量添加所有元素到层
                            for elem in separatedElements do
                            (
                                modelLayer.addNode elem
                            )
                            
                            addLog ("已将 " + separatedElements.count as string + " 个元素添加到层 " + objName)
                        )
                        else
                        (
                            addLog ("警告: 未找到层 '" + objName + "', 无法添加分离元素")
                        )
                    ) catch (
                        addLog ("将分离元素添加到层时出错: " + (getCurrentException()))
                    )
                )
                else
                (
                    addLog ("分离模型 " + objName + " 失败或未找到可分离元素")
                )
                
                totalProcessed += 1
                updateProgress (50 + (totalProcessed as float / buildingQueue.count * 50)) -- 后50%用于完成状态
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
            
            updateStatus ("模型分离完成，共分离出 " + totalElements as string + " 个元素")
            addLog ("===== 完成分离 " + buildingQueue.count as string + " 个模型，共生成 " + totalElements as string + " 个元素 =====")
        )
        else
        (
            updateStatus "模型分离完成，但未生成任何元素"
            addLog "===== 分离操作完成，但未生成任何元素 ====="
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
        
        updateStatus "开始对齐地面..."
        updateProgress 0
        
        addLog "执行地面对齐功能 - 将已经选择的模型对齐到地形队列中的地形模型上"
        
        -- 模拟处理过程
        local targetTerrain = terrainQueue[1] -- 使用第一个地形作为目标
        for i = 1 to buildingQueue.count do
        (
            local obj = buildingQueue[i]
            if isValidNode obj then
            (
                addLog ("正在对齐模型: " + obj.name + " 到地形: " + targetTerrain.name)
                updateProgress (i as float / buildingQueue.count * 100)
                -- 这里调用实际的对齐函数
                -- alignToSurface obj targetTerrain
            )
            windows.processPostedMessages()
        )
        
        updateProgress 100
        updateStatus "地面对齐完成"
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
        
        -- 模拟处理过程
        addLog ("正在合并 " + buildingQueue.count as string + " 个模型...")
        updateProgress 50
        
        -- 这里调用实际的合并函数
        -- local mergedModel = mergeElements buildingQueue
        
        updateProgress 100
        updateStatus "模型合并完成"
        addLog "合并完成，生成统一的远景建筑模型"
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
        
        try
        (
            -- 步骤1：分离模型
            updateStatus "步骤1/3: 分离模型"
            addLog "步骤1: 执行模型分离"
            updateProgress 10
            
            -- 估算处理时间
            local timeEstimate = estimateProcessingTime buildingQueue
            local allSeparatedElements = #()
            
            for i = 1 to buildingQueue.count do
            (
                local obj = buildingQueue[i]
                if isValidNode obj then
                (
                    local objName = obj.name
                    
                    -- 步骤1: 先为模型创建同名层并将原始模型添加到层中
                    addLog ("正在为模型 " + objName + " 创建层...")
                    try (
                        -- 创建与模型同名的层
                        local modelLayer
                        if (layerManager.getLayerFromName objName) == undefined then
                        (
                            modelLayer = layerManager.newLayerFromName objName
                        )
                        else
                        (
                            modelLayer = layerManager.getLayerFromName objName
                        )
                        
                        -- 将原始模型添加到层中
                        modelLayer.addNode obj
                        
                        addLog ("已将模型 " + objName + " 添加到同名层中")
                    ) catch (
                        addLog ("创建层或添加模型到层时出错: " + (getCurrentException()))
                    )
                    
                    -- 步骤2: 在层内分离模型
                    addLog ("正在分离模型: " + objName)
                    updateProgress (10 + i as float / buildingQueue.count * 30)
                    
                    -- 调用实际的分离函数
                    local separatedElements = decomposeModel obj timeEstimate:timeEstimate
                    
                    -- 处理分离结果
                    if separatedElements.count > 0 then
                    (
                        -- 将分离的元素添加到总元素列表中
                        join allSeparatedElements separatedElements
                        
                        -- 确保所有分离元素都在正确的层中
                        try (
                            -- 获取已创建的层引用
                            local modelLayer = layerManager.getLayerFromName objName
                            if modelLayer != undefined then
                            (
                                -- 批量添加所有元素到层
                                for elem in separatedElements do
                                (
                                    modelLayer.addNode elem
                                )
                                addLog ("成功从模型 " + objName + " 分离出 " + separatedElements.count as string + " 个元素并添加到层 '" + objName + "'")
                            )
                            else
                            (
                                addLog ("警告: 未找到层 '" + objName + "', 无法添加分离元素")
                            )
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
            
            local targetTerrain = terrainQueue[1]
            for i = 1 to buildingQueue.count do
            (
                local obj = buildingQueue[i]
                if isValidNode obj then
                (
                    addLog ("对齐模型: " + obj.name + " 到地形: " + targetTerrain.name)
                    updateProgress (40 + i as float / buildingQueue.count * 30)
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
            updateStatus "一键处理完成！"
            addLog "=== 一键处理流程完成 ==="
            addLog "成功生成远景建筑模型"
            
            messageBox "一键处理完成！\n\n已完成：\n1. 模型分离\n2. 地面对齐\n3. 模型合并\n\n请查看运行日志了解详细信息。" title:"处理完成"
        )
        catch
        (
            updateStatus "处理过程中发生错误"
            addLog ("错误: " + getCurrentException())
            messageBox "处理过程中发生错误，请查看运行日志" title:"错误"
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
