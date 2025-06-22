-- 远景建筑处理工具 UI界面
-- Distant Architecture Processing Tool UI
-- 基于3dsMax模型切割对齐插件项目文档设计

try(destroyDialog DistantArchitectureUI) catch()

rollout DistantArchitectureUI "远景建筑处理工具" width:480 height:550
(
    -- 全局变量
    local buildingQueue = #()
    local terrainQueue = #()
    local isProcessing = false
    local logText = ""
    
    -- 顶部按钮区域
    group "模型获取"
    (
        button btnGetBuilding "获取建筑模型" width:120 height:25 pos:[15,20]
        button btnGetTerrain "获取地形" width:120 height:25 pos:[145,20]
    )
    
    -- 队列显示区域
    group "队列管理"
    (
        label lblBuildingQueue "建筑队列" pos:[15,70]
        label lblTerrainQueue "地形队列" pos:[250,70]
        
        -- 建筑模型队列列表
        listbox lstBuildingQueue "" pos:[15,85] width:200 height:6
        
        -- 地形队列列表
        listbox lstTerrainQueue "" pos:[250,85] width:200 height:6
        
        -- 建筑队列操作按钮
        button btnAddBuilding "添加" width:40 height:20 pos:[15,185]
        button btnDelBuilding "删除" width:40 height:20 pos:[60,185]
        button btnClearBuilding "清空" width:40 height:20 pos:[105,185]
        
        -- 地形队列操作按钮
        button btnAddTerrain "添加" width:40 height:20 pos:[250,185]
        button btnDelTerrain "删除" width:40 height:20 pos:[295,185]
        button btnClearTerrain "清空" width:40 height:20 pos:[340,185]
    )
    
    -- 独立执行功能区域
    group "独立执行"
    (
        button btnSeparateModel "分离模型" width:100 height:28 pos:[50,220]
        button btnAlignGround "对齐地面" width:100 height:28 pos:[190,220]
        button btnMergeModel "合并模型" width:100 height:28 pos:[330,220]
    )
    
    -- 进度显示区域
    group "处理状态"
    (
        label lblStatus "状态: 准备就绪" pos:[15,260]
        progressbar pgbProgress "" pos:[15,275] width:430 height:18 color:green
    )
    
    -- 运行日志区域
    group "运行日志"
    (
        edittext edtLog "" pos:[15,310] width:430 height:90 readonly:true text:"" 
    )
    
    -- 一键处理按钮
    button btnOneClickProcess "一键处理" width:120 height:35 pos:[180,420]
    
    -- 辅助函数：添加日志
    function addLog message = 
    (
        local timeStamp = localTime
        local logEntry = "[" + timeStamp as string + "] " + message + "\r\n"
        logText += logEntry
        edtLog.text = logText
        -- 注意：EditTextControl不支持自动滚动到底部
        -- 可以通过UI更新来实现视觉上的更新
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
        addLog "打开建筑模型选择对话框..."
        
        -- 获取场景中所有几何体对象
        local sceneObjects = #()
        for obj in geometry do
        (
            append sceneObjects obj
        )
        
        if sceneObjects.count > 0 then
        (
            -- 创建选择对话框
            local objectNames = for obj in sceneObjects collect obj.name
            local selectedIndices = #()
            
            -- 这里应该创建一个多选对话框，简化处理直接选择当前选中的对象
            if selection.count > 0 then
            (
                for obj in selection do
                (
                    if findItem buildingQueue obj == 0 then
                    (
                        append buildingQueue obj
                        addLog ("添加建筑模型: " + obj.name)
                    )
                )
                updateBuildingQueueDisplay()
                updateStatus "建筑模型获取完成"
            )
            else
            (
                addLog "请先选择要添加的建筑模型对象"
                messageBox "请先选择要添加的建筑模型对象" title:"提示"
            )
        )
        else
        (
            addLog "场景中没有找到几何体对象"
            messageBox "场景中没有找到几何体对象" title:"警告"
        )
    )
    
    -- 获取地形按钮事件
    on btnGetTerrain pressed do
    (
        addLog "打开地形模型选择对话框..."
        
        if selection.count > 0 then
        (
            for obj in selection do
            (
                if findItem terrainQueue obj == 0 then
                (
                    append terrainQueue obj
                    addLog ("添加地形模型: " + obj.name)
                )
            )
            updateTerrainQueueDisplay()
            updateStatus "地形模型获取完成"
        )
        else
        (
            addLog "请先选择要添加的地形模型对象"
            messageBox "请先选择要添加的地形模型对象" title:"提示"
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
            for obj in selection do
            (
                if findItem terrainQueue obj == 0 then
                (
                    append terrainQueue obj
                    addLog ("手动添加地形模型: " + obj.name)
                )
            )
            updateTerrainQueueDisplay()
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
        
        updateStatus "开始分离模型..."
        updateProgress 0
        
        -- 这里应该调用实际的模型分离函数
        addLog "执行模型分离功能 - 对模型队列中的模型进行按元素层级分离"
        
        -- 模拟处理过程
        for i = 1 to buildingQueue.count do
        (
            local obj = buildingQueue[i]
            if isValidNode obj then
            (
                addLog ("正在分离模型: " + obj.name)
                updateProgress (i as float / buildingQueue.count * 100)
                -- 这里调用实际的分离函数
                -- decomposeModel obj
            )
            windows.processPostedMessages()
        )
        
        updateProgress 100
        updateStatus "模型分离完成"
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
        
        isProcessing = true
        updateStatus "开始一键处理流程..."
        addLog "=== 开始一键处理：分离模型 → 对齐地面 → 合并模型 ==="
        
        try
        (
            -- 步骤1：分离模型
            updateStatus "步骤1/3: 分离模型"
            addLog "步骤1: 执行模型分离"
            updateProgress 10
            
            for i = 1 to buildingQueue.count do
            (
                local obj = buildingQueue[i]
                if isValidNode obj then
                (
                    addLog ("分离模型: " + obj.name)
                    updateProgress (10 + i as float / buildingQueue.count * 30)
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
        addLog "远景建筑处理工具已启动"
        addLog "请按照以下步骤操作："
        addLog "1. 点击'获取建筑模型'添加要处理的建筑模型"
        addLog "2. 点击'获取地形'添加地形模型"
        addLog "3. 可以使用独立功能按钮分步处理，或点击'一键处理'自动完成全流程"
        updateStatus "工具已就绪，等待用户操作"
    )
)

-- 创建并显示对话框
createdialog DistantArchitectureUI

-- 输出提示信息
print "远景建筑处理工具UI已加载"
print "使用说明："
print "1. 选择建筑模型后点击'获取建筑模型'按钮"
print "2. 选择地形模型后点击'获取地形'按钮"
print "3. 使用独立功能按钮或一键处理完成操作"