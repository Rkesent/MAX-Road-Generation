

-- ========== 对齐到物体表面脚本 (简化版 - 已移除预览功能) ==========
-- 版本: 2.4 (双队列版)
-- 功能: 将选中的物体对齐到目标表面，支持单次对齐和双队列批量对齐
-- 新增: 物体队列管理，支持要对齐的物体和目标地面的双队列管理
-- 已移除: 所有预览相关功能、射线可视化、回调管理等

-- ========== 全局变量 ==========

-- 对齐系统相关变量
global isAlignmentActive = false      -- 对齐操作是否激活的标志
global alignDialogInstance = undefined -- 对话框实例引用

-- ========== 工具函数 ==========

-- 验证几何体有效性
function isValidGeometry obj =
(
	try (
		if obj == undefined then return false
		if not isValidNode obj then return false
		if obj.boundingBox == undefined then return false
		
		-- 检查是否为几何体类型
		local validTypes = #(Editable_mesh, Editable_Poly, Box, Sphere, Cylinder, Plane, Teapot)
		local objClass = classOf obj
		
		for validType in validTypes do
		(
			if objClass == validType then return true
		)
		
		-- 检查是否有mesh属性
		try (
			local testMesh = obj.mesh
			if testMesh != undefined then return true
		) catch ()
		
		return false
		
	) catch (
		return false
	)
)

-- 统一的对齐算法函数
function alignObjectToSurface obj surface =
(
	try (
		-- 验证输入参数
		if not isValidGeometry obj or not isValidGeometry surface then return false
		
		-- 获取物体边界框
		local pMin = obj.min
		local pMax = obj.max
		
		-- 计算射线起点（物体中心上方）
		local centerX = pMin.x + 0.5 * (pMax.x - pMin.x)
		local centerY = pMin.y + 0.5 * (pMax.y - pMin.y)
		local startHeight = surface.max.z + 100
		local rayStart = [centerX, centerY, startHeight]
		
		-- 创建向下的射线
		local rayC = ray rayStart [0, 0, -1]
		local pSurf = intersectRay surface rayC
		
		if pSurf != undefined then
		(
			-- 计算移动距离（将物体底部对齐到表面）
			local moveDistance = pSurf.position.z - pMin.z
			move obj [0, 0, moveDistance]
			return true
		)
		else
			return false
		
	) catch (
		return false
	)
)

-- 批量对齐到指定表面的函数
function alignToSpecificSurface surface =
(
	-- 获取当前选择的物体
	local obj = getCurrentSelection()
	local num_obj = obj.count
	
	if num_obj == 0 then
	(
		return false
	)
	
	-- 批量对齐当前选择的物体
	local processedCount = 0
	
	for i = 1 to num_obj do
	(
		-- 使用统一的对齐算法
		if alignObjectToSurface obj[i] surface then
		(
			-- 取消选择已对齐的物体
			deselect obj[i]
			processedCount += 1
		)
	)
	
	return true
)

-- ========== 主对话框 ==========

rollout 对齐到物体表面 "对齐到物体表面 (双队列版)" width:320 height:540
(
	-- 单次对齐区域
	groupBox grp1 "单次对齐" pos:[10,10] width:300 height:80
	button btn4 "对齐到物体表面" pos:[20,30] width:160 height:27
	label lbl1 "先选择要对齐的物体，然后点击按钮，再选择需要对齐到的物体表面" pos:[20,60] width:280 height:25
	
	-- 物体队列管理区域
	groupBox grp2 "物体队列管理" pos:[10,100] width:300 height:170
	listBox objectQueueList "要对齐的物体队列:" pos:[20,120] width:200 height:6
	button btnAddObjectToQueue "添加物体" pos:[230,120] width:70 height:25
	button btnRemoveObjectFromQueue "删除物体" pos:[230,150] width:70 height:25
	button btnClearObjectQueue "清空物体" pos:[230,180] width:70 height:25
	button btnAddFromLayerExplorer "从层资源管理器导入" pos:[230,210] width:70 height:40
	label lblObjectQueueCount "物体队列: 0 项" pos:[20,240] width:120 height:20
	
	-- 目标地面队列管理区域
	groupBox grp3 "目标地面队列管理" pos:[10,280] width:300 height:140
	listBox surfaceQueueList "目标地面队列:" pos:[20,300] width:200 height:6
	button btnAddSurfaceToQueue "添加地面" pos:[230,300] width:70 height:25
	button btnRemoveSurfaceFromQueue "删除地面" pos:[230,330] width:70 height:25
	button btnClearSurfaceQueue "清空地面" pos:[230,360] width:70 height:25
	label lblSurfaceQueueCount "地面队列: 0 项" pos:[20,390] width:120 height:20
	
	-- 队列对齐区域
	groupBox grp4 "队列批量对齐" pos:[10,430] width:300 height:50
	button btnQueueAlign "开始队列对齐" pos:[20,450] width:120 height:25
	label lbl3 "队列对齐：使用物体队列中的物体对齐到地面队列中的每个地面" pos:[150,450] width:150 height:25
	
	-- 状态显示区域
	groupBox grp5 "状态信息" pos:[10,490] width:300 height:40
	label lbl2 "状态：就绪" pos:[20,505] width:280 height:20
	
	-- 队列相关变量
	local objectQueue = #()          -- 要对齐的物体队列数组
	local objectQueueNames = #()     -- 物体队列显示名称数组
	local surfaceQueue = #()         -- 目标地面队列数组
	local surfaceQueueNames = #()    -- 地面队列显示名称数组
	local targetSurface = undefined  -- 单次对齐的目标表面
	
	-- 队列管理函数
	function updateObjectQueueDisplay =
	(
		objectQueueList.items = objectQueueNames
		lblObjectQueueCount.text = "物体队列: " + objectQueue.count as string + " 项"
	)
	
	function updateSurfaceQueueDisplay =
	(
		surfaceQueueList.items = surfaceQueueNames
		lblSurfaceQueueCount.text = "地面队列: " + surfaceQueue.count as string + " 项"
	)
	
	function updateAllQueueDisplays =
	(
		updateObjectQueueDisplay()
		updateSurfaceQueueDisplay()
	)
	
	-- 从图层导入物体到队列的函数
	function addObjectsFromLayer =
	(
		try (
			-- 获取所有图层信息
			global tempLayerData = #()
			for i = 0 to (LayerManager.count - 1) do
			(
				local layer = LayerManager.getLayer i
				if layer != undefined then
				(
					-- 获取图层中的节点
					local layerNodes = #()
					layer.nodes &layerNodes
					
					-- 统计图层中的有效几何体数量
					local validGeomCount = 0
					local totalNodeCount = layerNodes.count
					
					for j = 1 to totalNodeCount do
					(
						local node = layerNodes[j]
						if isValidGeometry node then
							validGeomCount += 1
					)
					
					-- 只显示包含有效几何体的图层
					if validGeomCount > 0 then
					(
						local layerInfo = layer.name + " (" + validGeomCount as string + " 个几何体)"
						append tempLayerData #(layerInfo, layer, validGeomCount, layerNodes)
					)
				)
			)
			
			if tempLayerData.count == 0 then
			(
				messageBox "场景中没有包含有效几何体的图层" title:"图层导入"
				tempLayerData = undefined
				return false
			)
			
			-- 创建图层选择对话框
			global tempSelectedLayer = undefined
			local layerDialog = rollout layerSelectionDialog "图层资源管理器" width:350 height:400
			(
				listbox lstLayers "选择要导入的图层:" items:(for item in tempLayerData collect item[1]) width:320 height:15 pos:[15,20]
				label lblLayerInfo "图层信息:" pos:[15,280] width:320 height:15
				label lblObjectCount "" pos:[15,300] width:320 height:15
				label lblValidGeomCount "" pos:[15,320] width:320 height:15
				button btnOK "确定导入" width:80 height:25 pos:[180,350]
				button btnCancel "取消" width:80 height:25 pos:[270,350]
				
				-- 更新图层信息显示
				function updateLayerInfo =
				(
					if lstLayers.selection > 0 and lstLayers.selection <= tempLayerData.count then
					(
						local selectedData = tempLayerData[lstLayers.selection]
						local layer = selectedData[2]
						local validCount = selectedData[3]
						local layerNodes = selectedData[4]
						
						lblLayerInfo.text = "图层名称: " + layer.name
						lblObjectCount.text = "总对象数: " + layerNodes.count as string
						lblValidGeomCount.text = "有效几何体: " + validCount as string
						btnOK.enabled = true
					)
					else
					(
						lblLayerInfo.text = "图层信息:"
						lblObjectCount.text = ""
						lblValidGeomCount.text = ""
						btnOK.enabled = false
					)
				)
				
				on lstLayers selected sel do updateLayerInfo()
				
				on layerSelectionDialog open do
				(
					updateLayerInfo()
					if tempLayerData.count > 0 then
						lstLayers.selection = 1
				)
				
				on btnOK pressed do
				(
					if lstLayers.selection > 0 then
						tempSelectedLayer = lstLayers.selection
					destroyDialog layerSelectionDialog
				)
				
				on btnCancel pressed do
					destroyDialog layerSelectionDialog
			)
			
			createdialog layerDialog modal:true
			
			local selectedIndex = tempSelectedLayer
			tempSelectedLayer = undefined
			local tempLayerDataCopy = tempLayerData
			tempLayerData = undefined
			
			if selectedIndex == undefined or selectedIndex <= 0 or selectedIndex > tempLayerDataCopy.count then
			(
				lbl2.text = "状态：用户取消了图层选择"
				return false
			)
			
			-- 获取选定图层的数据
			local selectedLayerData = tempLayerDataCopy[selectedIndex]
			local selectedLayer = selectedLayerData[2]
			local selectedLayerNodes = selectedLayerData[4]
			
			if selectedLayerNodes.count == 0 then
			(
				lbl2.text = "状态：选定图层中没有节点"
				return false
			)
			
			-- 从选定图层中获取所有有效几何体
			local addedCount = 0
			local skippedCount = 0
			local addedObjects = #()
			
			for i = 1 to selectedLayerNodes.count do
			(
				local obj = selectedLayerNodes[i]
				
				-- 检查是否为有效的几何体
				if not isValidGeometry obj then
				(
					skippedCount += 1
					continue
				)
				
				-- 检查是否已存在于队列中
				local existIndex = findItem objectQueue obj
				if existIndex > 0 then
				(
					skippedCount += 1
					continue
				)
				
				-- 添加到队列
				append objectQueue obj
				append objectQueueNames obj.name
				append addedObjects obj
				addedCount += 1
			)
			
			-- 更新物体队列显示
			updateObjectQueueDisplay()
			
			-- 选择导入的对象以便用户查看
			if addedObjects.count > 0 then
			(
				clearSelection()
				select addedObjects
			)
			
			-- 显示结果
			if addedCount > 0 then
			(
				lbl2.text = "状态：从图层 '" + selectedLayer.name + "' 导入了 " + addedCount as string + " 个物体"
				if skippedCount > 0 then
					lbl2.text += "（跳过 " + skippedCount as string + " 个）"
				return true
			)
			else
			(
				messageBox "选定图层中没有有效的几何体可添加" title:"图层导入"
				lbl2.text = "状态：图层导入失败"
				return false
			)
			
		) catch (
			messageBox ("图层导入过程中发生错误: " + getCurrentException()) title:"图层导入错误"
			lbl2.text = "状态：图层导入错误"
			-- 清理全局变量
			tempLayerData = undefined
			tempSelectedLayer = undefined
			return false
		)
	)
	

	function addObjectToQueue =
	(
		-- 获取当前选择的物体
		local selectedObjects = getCurrentSelection()
		
		if selectedObjects.count == 0 then
		(
			messageBox "请先选择要添加到物体队列的模型" title:"选择错误"
			return false
		)
		
		local addedCount = 0
		local skippedCount = 0
		local addedNames = #()
		
		-- 遍历所有选中的物体
		for obj in selectedObjects do
		(
			-- 检查是否为有效的几何体
			if not isValidGeometry obj then
			(
				skippedCount += 1
				continue
			)
			
			-- 检查是否已存在于队列中
			local existIndex = findItem objectQueue obj
			if existIndex > 0 then
			(
				skippedCount += 1
				continue
			)
			
			-- 添加到队列
			append objectQueue obj
			append objectQueueNames obj.name
			append addedNames obj.name
			addedCount += 1
		)
		
		updateObjectQueueDisplay()
		
		-- 显示添加结果
		if addedCount > 0 then
		(
			if addedCount == 1 then
				lbl2.text = "状态：已添加 " + addedNames[1] + " 到物体队列"
			else
				lbl2.text = "状态：已添加 " + addedCount as string + " 个物体到队列"
			
			if skippedCount > 0 then
				lbl2.text += "（跳过 " + skippedCount as string + " 个）"
			
			return true
		)
		else
		(
			if skippedCount > 0 then
				messageBox "所选模型都已在队列中或不是有效几何体" title:"添加失败"
			else
				messageBox "没有有效的几何体可添加" title:"添加失败"
			
			lbl2.text = "状态：添加失败"
			return false
		)
	)
	
	function addSurfaceToQueue =
	(
		-- 获取当前选择的物体
		local selectedObjects = getCurrentSelection()
		
		if selectedObjects.count == 0 then
		(
			messageBox "请先选择要添加到队列的地面模型" title:"选择错误"
			return false
		)
		
		local addedCount = 0
		local skippedCount = 0
		local addedNames = #()
		
		-- 遍历所有选中的物体
		for obj in selectedObjects do
		(
			-- 检查是否为有效的几何体
			if not isValidGeometry obj then
			(
				skippedCount += 1
				continue
			)
			
			-- 检查是否已存在于队列中
			local existIndex = findItem surfaceQueue obj
			if existIndex > 0 then
			(
				skippedCount += 1
				continue
			)
			
			-- 添加到队列
			append surfaceQueue obj
			append surfaceQueueNames obj.name
			append addedNames obj.name
			addedCount += 1
		)
		
		updateSurfaceQueueDisplay()
		
		-- 显示添加结果
		if addedCount > 0 then
		(
			if addedCount == 1 then
				lbl2.text = "状态：已添加 " + addedNames[1] + " 到地面队列"
			else
				lbl2.text = "状态：已添加 " + addedCount as string + " 个地面到队列"
			
			if skippedCount > 0 then
				lbl2.text += "（跳过 " + skippedCount as string + " 个）"
			
			return true
		)
		else
		(
			if skippedCount > 0 then
				messageBox "所选模型都已在队列中或不是有效几何体" title:"添加失败"
			else
				messageBox "没有有效的几何体可添加" title:"添加失败"
			
			lbl2.text = "状态：添加失败"
			return false
		)
	)
	
	function removeObjectFromQueue =
	(
		local selIndex = objectQueueList.selection
		if selIndex > 0 and selIndex <= objectQueue.count then
		(
			local removedName = objectQueueNames[selIndex]
			deleteItem objectQueue selIndex
			deleteItem objectQueueNames selIndex
			updateObjectQueueDisplay()
			lbl2.text = "状态：已从物体队列删除 " + removedName
		)
		else
		(
			messageBox "请先选择要删除的物体队列项" title:"删除错误"
		)
	)
	
	function removeSurfaceFromQueue =
	(
		local selIndex = surfaceQueueList.selection
		if selIndex > 0 and selIndex <= surfaceQueue.count then
		(
			local removedName = surfaceQueueNames[selIndex]
			deleteItem surfaceQueue selIndex
			deleteItem surfaceQueueNames selIndex
			updateSurfaceQueueDisplay()
			lbl2.text = "状态：已从地面队列删除 " + removedName
		)
		else
		(
			messageBox "请先选择要删除的地面队列项" title:"删除错误"
		)
	)
	
	function clearObjectQueue =
	(
		if objectQueue.count > 0 then
		(
			local result = queryBox "确定要清空整个物体队列吗？" title:"确认清空"
			if result then
			(
				objectQueue = #()
				objectQueueNames = #()
				updateObjectQueueDisplay()
				lbl2.text = "状态：物体队列已清空"
			)
		)
		else
		(
			messageBox "物体队列已经是空的" title:"清空物体队列"
		)
	)
	
	function clearSurfaceQueue =
	(
		if surfaceQueue.count > 0 then
		(
			local result = queryBox "确定要清空整个地面队列吗？" title:"确认清空"
			if result then
			(
				surfaceQueue = #()
				surfaceQueueNames = #()
				updateSurfaceQueueDisplay()
				lbl2.text = "状态：地面队列已清空"
			)
		)
		else
		(
			messageBox "地面队列已经是空的" title:"清空地面队列"
		)
	)
	
	-- 使用物体队列对齐到地面队列的函数
	function processQueueAlignment =
	(
		if objectQueue.count == 0 then
		(
			messageBox "物体队列为空，请先添加要对齐的物体" title:"队列对齐"
			return false
		)
		
		if surfaceQueue.count == 0 then
		(
			messageBox "地面队列为空，请先添加目标地面" title:"队列对齐"
			return false
		)
		
		lbl2.text = "状态：开始队列对齐，" + objectQueue.count as string + " 个物体到 " + surfaceQueue.count as string + " 个地面"
		windows.processPostedMessages()
		
		local totalProcessed = 0
		
		-- 逐个处理队列中的目标地面
		for i = 1 to surfaceQueue.count do
		(
			-- 检查物体队列是否还有物体
			if objectQueue.count == 0 then
			(
				lbl2.text = "状态：物体队列已空，对齐完成"
				exit
			)
			
			-- 对齐到当前地面
			lbl2.text = "状态：处理地面 " + i as string + "/" + surfaceQueue.count as string + " - " + surfaceQueueNames[i]
			windows.processPostedMessages()
			
			-- 将物体队列中的物体对齐到当前地面
			local processedThisRound = 0
			local j = 1
			while j <= objectQueue.count do
			(
				if alignObjectToSurface objectQueue[j] surfaceQueue[i] then
				(
					-- 对齐成功，从队列中移除
					deleteItem objectQueue j
					deleteItem objectQueueNames j
					processedThisRound += 1
					totalProcessed += 1
					-- 不增加j，因为数组元素已删除
				)
				else
				(
					-- 对齐失败，继续下一个
					j += 1
				)
			)
			
			updateObjectQueueDisplay()
			lbl2.text = "状态：地面 " + surfaceQueueNames[i] + " 完成，对齐了 " + processedThisRound as string + " 个物体"
			windows.processPostedMessages()
			
			-- 短暂延迟以便用户看到进度
			sleep 0.5
		)
		
		lbl2.text = "状态：队列对齐完成，共处理 " + totalProcessed as string + " 个物体"
		return true
	)
	

	
	function alignObjects =
	(
		-- 检查对齐是否仍然活动
		if not isAlignmentActive then
		(
			lbl2.text = "状态：对齐已停止"
			return false
		)
		
		-- 获取当前选择的物体
		local obj = getCurrentSelection()
		local num_obj = obj.count
		
		if num_obj == 0 then
		(
			lbl2.text = "状态：没有选中的物体，结束对齐"
			return false
		)
		
		-- 选择目标表面
		local validSelection = false
		while not validSelection and isAlignmentActive do
		(
			targetSurface = pickObject prompt:"选择要对齐到的地面表面（右键退出）" 
			
			-- 如果用户右键点击退出或对齐已停止
			if targetSurface == undefined or not isAlignmentActive then 
			(
				lbl2.text = "状态：用户取消选择"
				isAlignmentActive = false
				return false
			)
			
			-- 检查是否为有效的几何体
			if not isValidGeometry targetSurface then
			(
				messageBox "请选择有效的几何体" title:"选择错误"
			)
			else
			(
				validSelection = true
			)
		)
		
		-- 再次检查对齐状态
		if not isAlignmentActive then return false
		
		lbl2.text = "状态：正在对齐..."
		windows.processPostedMessages()
		
		-- 批量对齐当前选择的物体
		local processedCount = 0
		
		for i = 1 to num_obj do
		(
			-- 检查对齐是否仍然活动
			if not isAlignmentActive then exit
			
			-- 使用统一的对齐算法
			if alignObjectToSurface obj[i] targetSurface then
			(
				-- 取消选择已对齐的物体
				deselect obj[i]
				processedCount += 1
			)
			
			-- 每处理100个对象更新一次界面
			if (mod i 100) == 0 or i == num_obj then
			(
				lbl2.text = "状态：已对齐 " + processedCount as string + "/" + num_obj as string
				windows.processPostedMessages()
			)
		)
		
		lbl2.text = "状态：本批对齐完成（共处理 " + processedCount as string + " 个对象）"
		return true
	)
	
	-- 按钮事件处理器
	on btn4 pressed do
	(
		-- 设置对齐活动状态
		isAlignmentActive = true
		
		-- 循环执行对齐，直到没有选中的物体或用户停止
		while isAlignmentActive do
		(
			local result = alignObjects()
			if not result or not isAlignmentActive then exit
			
			-- 检查是否还有选中的物体
			local remainingObjs = getCurrentSelection()
			if remainingObjs.count == 0 then
			(
				lbl2.text = "状态：所有对齐完成"
				exit
			)
			
			-- 如果还有选中的物体，稍作延迟后继续
			lbl2.text = "状态：准备对齐剩余的 " + remainingObjs.count as string + " 个物体..."
			windows.processPostedMessages()
		)
		
		isAlignmentActive = false
	)
	
	on btnAddObjectToQueue pressed do addObjectToQueue()
	on btnRemoveObjectFromQueue pressed do removeObjectFromQueue()
	on btnClearObjectQueue pressed do clearObjectQueue()
	on btnAddFromLayerExplorer pressed do addObjectsFromLayer()
	on btnAddSurfaceToQueue pressed do addSurfaceToQueue()
	on btnRemoveSurfaceFromQueue pressed do removeSurfaceFromQueue()
	on btnClearSurfaceQueue pressed do clearSurfaceQueue()
	on btnQueueAlign pressed do processQueueAlignment()
	
	-- 对话框打开事件处理器
	on 对齐到物体表面 open do
	(
		try (
			alignDialogInstance = 对齐到物体表面
			updateAllQueueDisplays()
			lbl2.text = "状态：就绪"
		) catch (
			lbl2.text = "状态：初始化失败"
		)
	)
	
	-- 对话框关闭事件处理器
	on 对齐到物体表面 close do
	(
		try (
			isAlignmentActive = false
			alignDialogInstance = undefined
		) catch ()
	)
)

-- ========== 脚本初始化 ==========

-- 脚本初始化函数
function initializeAlignmentScript =
(
	try (
		format "=== 对齐到物体表面脚本 v2.4 (双队列版) 初始化 ===\n"
		
		-- 清理之前的实例
		try (destroyDialog 对齐到物体表面) catch ()
		
		-- 重置全局变量
		isAlignmentActive = false
		alignDialogInstance = undefined
		
		-- 创建并显示对话框
		createdialog 对齐到物体表面 style:#(#style_minimizebox, #style_titlebar, #style_sysmenu)
		
		if 对齐到物体表面 != undefined then
		(
			alignDialogInstance = 对齐到物体表面
			format "✓ 脚本初始化成功完成\n"
			format "=== 对齐到物体表面脚本 (双队列版) 已就绪 ===\n"
			return true
		)
		else
		(
			format "错误：对话框创建失败\n"
			return false
		)
		
	) catch (
		format "错误：脚本初始化过程发生异常: %\n" (getCurrentException())
		return false
	)
)

-- 清理函数
function cleanupAlignment =
(
	try (
		-- 清理对话框
		if alignDialogInstance != undefined then
		(
			try (destroyDialog alignDialogInstance) catch ()
			alignDialogInstance = undefined
		)
		
		-- 重置状态变量
		isAlignmentActive = false
		
		format "对齐脚本清理完成\n"
		return true
		
	) catch (
		format "对齐脚本清理失败\n"
		return false
	)
)

-- 执行脚本初始化
try (
	initializeAlignmentScript()
) catch (
	format "脚本启动失败: %\n" (getCurrentException())
)