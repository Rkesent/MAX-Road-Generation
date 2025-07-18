/*
 * 3ds Max 物体对齐到表面脚本 - 增强版（参考山形细分脚本优化）
 * 
 * 功能描述：
 * - 将选中的物体对齐到目标表面
 * - 支持射线预览功能（参考山形细分脚本的GW绘制方法）
 * - 支持队列批量对齐
 * - 3ds Max 2022+ 兼容性优化
 * - 性能优化和错误处理改进
 * 
 * 特性：
 * - 统一的对齐算法
 * - 智能射线计算
 * - 可视化预览（采用山形细分脚本的回调注册机制）
 * - 批量处理支持（参考山形细分脚本的性能优化方法）
 * - 健壮的错误处理
 * 
 * 版本：2.1
 * 更新日期：2025-01-14
 * 
 * 主要改进：
 * 1. 修复了3ds Max 2022兼容性问题（特别是Graphics Window获取）
 * 2. 重构了对齐算法，提高了代码复用性
 * 3. 优化了预览性能，限制了预览数量
 * 4. 增强了错误处理和用户反馈
 * 5. 统一了输入验证和几何体检查
 * 6. 改进了脚本完整性检查
 * 7. 参考山形细分脚本改进了预览系统：
 *    - 采用更稳定的回调注册机制
 *    - 优化了GW绘制方法和线段批量处理
 *    - 改进了初始化和清理流程
 *    - 增强了兼容性和性能
 */

-- ========== 状态管理器 (State Manager) ==========

-- 预览状态结构
struct PreviewState (
	isActive,         -- Boolean: 预览是否活动
	rayCount,         -- Integer: 射线数量
	targetSurface,    -- Object: 目标表面
	lastError,        -- String: 最后的错误信息
	lastUpdateTime,   -- Integer: 最后更新时间戳
	renderStats       -- RenderStats: 最后的渲染统计
)

-- 全局状态管理器
global alignmentStateManager = undefined

-- 初始化状态管理器
function initializeStateManager =
(
	try (
		alignmentStateManager = PreviewState isActive:false rayCount:0 targetSurface:undefined lastError:"" lastUpdateTime:0 renderStats:undefined
		
		-- 初始化其他全局变量
		global alignPreviewCallback = undefined
		global previewRays = #()
		global isPreviewActive = false
		global alignDialogInstance = undefined
		global isAlignmentActive = false
		global alignmentPreviewColor = color 255 255 0 -- 黄色射线
		
		format "状态管理器：初始化完成\n"
		return true
		
	) catch (
		format "状态管理器：初始化失败: %\n" (getCurrentException())
		return false
	)
)

-- 设置预览状态
function setPreviewState enabled rayCount =
(
	try (
		if alignmentStateManager == undefined then
			initializeStateManager()
		
		local previousState = alignmentStateManager.isActive
		
		-- 更新状态
		alignmentStateManager.isActive = enabled
		alignmentStateManager.rayCount = if rayCount != undefined then rayCount else 0
		alignmentStateManager.lastUpdateTime = timestamp()
		alignmentStateManager.lastError = ""
		
		-- 同步旧的全局变量（向后兼容）
		isPreviewActive = enabled
		
		-- 状态变化日志
		if previousState != enabled then
		(
			if enabled then
				format "状态管理器：预览已启用，射线数量: %\n" alignmentStateManager.rayCount
			else
				format "状态管理器：预览已禁用\n"
		)
		
		return true
		
	) catch (
		format "状态管理器：设置预览状态失败: %\n" (getCurrentException())
		return false
	)
)

-- 更新目标表面
function setTargetSurface surface =
(
	try (
		if alignmentStateManager == undefined then
			initializeStateManager()
		
		alignmentStateManager.targetSurface = surface
		alignmentStateManager.lastUpdateTime = timestamp()
		
		if surface != undefined then
			format "状态管理器：目标表面已设置为 %\n" surface.name
		else
			format "状态管理器：目标表面已清除\n"
		
		return true
		
	) catch (
		format "状态管理器：设置目标表面失败: %\n" (getCurrentException())
		return false
	)
)

-- 记录错误状态
function setErrorState errorMsg =
(
	try (
		if alignmentStateManager == undefined then
			initializeStateManager()
		
		alignmentStateManager.lastError = if errorMsg != undefined then errorMsg else ""
		alignmentStateManager.lastUpdateTime = timestamp()
		
		if errorMsg != undefined and errorMsg != "" then
			format "状态管理器：错误状态 - %\n" errorMsg
		
		return true
		
	) catch (
		format "状态管理器：设置错误状态失败\n"
		return false
	)
)

-- 更新渲染统计
function setRenderStats stats =
(
	try (
		if alignmentStateManager == undefined then
			initializeStateManager()
		
		alignmentStateManager.renderStats = stats
		alignmentStateManager.lastUpdateTime = timestamp()
		
		return true
		
	) catch (
		format "状态管理器：设置渲染统计失败\n"
		return false
	)
)

-- 获取当前状态摘要
function getStateStatus =
(
	try (
		if alignmentStateManager == undefined then
		(
			return "状态管理器未初始化"
		)
		
		local statusMsg = "预览状态摘要：\n"
		statusMsg += "- 活动状态: " + (if alignmentStateManager.isActive then "启用" else "禁用") + "\n"
		statusMsg += "- 射线数量: " + alignmentStateManager.rayCount as string + "\n"
		statusMsg += "- 目标表面: " + (if alignmentStateManager.targetSurface != undefined then alignmentStateManager.targetSurface.name else "未设置") + "\n"
		
		if alignmentStateManager.lastError != "" then
			statusMsg += "- 最后错误: " + alignmentStateManager.lastError + "\n"
		
		if alignmentStateManager.renderStats != undefined then
		(
			local stats = alignmentStateManager.renderStats
			statusMsg += "- 渲染统计: " + stats.validRays as string + "/" + stats.totalRays as string + " 射线，" + stats.drawnLines as string + " 线段\n"
		)
		
		local elapsed = (timestamp() - alignmentStateManager.lastUpdateTime) / 1000.0
		statusMsg += "- 最后更新: " + elapsed as string + " 秒前\n"
		
		return statusMsg
		
	) catch (
		return "状态管理器：获取状态失败"
	)
)

-- 验证状态一致性
function validateStateConsistency =
(
	try (
		if alignmentStateManager == undefined then
		(
			format "状态管理器：状态管理器未初始化\n"
			return false
		)
		
		local issues = #()
		
		-- 检查预览状态一致性
		if alignmentStateManager.isActive != isPreviewActive then
			append issues "预览活动状态不一致"
		
		-- 检查射线数据一致性
		if alignmentStateManager.isActive and (previewRays == undefined or previewRays.count == 0) then
			append issues "预览启用但没有射线数据"
		
		if not alignmentStateManager.isActive and previewRays != undefined and previewRays.count > 0 then
			append issues "预览禁用但仍有射线数据"
		
		-- 检查回调状态一致性
		if alignmentStateManager.isActive and not alignCallbackState.isRegistered then
			append issues "预览启用但回调未注册"
		
		if not alignmentStateManager.isActive and alignCallbackState.isRegistered then
			append issues "预览禁用但回调仍注册"
		
		-- 报告问题
		if issues.count > 0 then
		(
			format "状态管理器：发现 % 个一致性问题：\n" issues.count
			for issue in issues do
				format "- %\n" issue
			return false
		)
		else
		(
			format "状态管理器：状态一致性检查通过\n"
			return true
		)
		
	) catch (
		format "状态管理器：一致性验证失败: %\n" (getCurrentException())
		return false
	)
)

-- 完全清理预览状态
function cleanupPreviewState =
(
	try (
		format "状态管理器：开始完全清理预览状态...\n"
		
		-- 清理状态管理器
		if alignmentStateManager != undefined then
		(
			alignmentStateManager.isActive = false
			alignmentStateManager.rayCount = 0
			alignmentStateManager.targetSurface = undefined
			alignmentStateManager.lastError = ""
			alignmentStateManager.renderStats = undefined
			alignmentStateManager.lastUpdateTime = timestamp()
		)
		
		-- 清理全局变量
		isPreviewActive = false
		previewRays = #()
		alignPreviewCallback = undefined
		
		-- 清理回调状态
		if alignCallbackState != undefined then
		(
			alignCallbackState.isRegistered = false
			alignCallbackState.callbackFunction = undefined
			alignCallbackState.errorCount = 0
		)
		
		format "状态管理器：预览状态清理完成\n"
		return true
		
	) catch (
		format "状态管理器：清理预览状态失败: %\n" (getCurrentException())
		return false
	)
)

-- 初始化状态管理器
initializeStateManager()

-- ========== 状态反馈系统 (Status Feedback System) ==========

-- 状态消息常量
struct StatusMessages (
	ready = "状态：就绪",
	calculating = "状态：正在计算射线...",
	rendering = "状态：正在渲染预览...",
	previewEnabled = "状态：射线预览已启用",
	previewDisabled = "状态：射线预览已关闭",
	previewCleared = "状态：射线预览已清除",
	previewRefreshed = "状态：射线预览已刷新",
	userCancelled = "状态：用户取消操作",
	error = "状态：操作失败",
	graphicsWindowError = "状态：图形窗口不可用，预览功能禁用",
	invalidGeometry = "状态：目标表面无效",
	calculationFailed = "状态：无法生成预览射线",
	callbackFailed = "状态：预览回调注册失败",
	refreshFailed = "状态：无法刷新预览射线"
)

-- 全局状态消息实例
global statusMsg = StatusMessages()

-- 进度跟踪结构
struct ProgressTracker (
	isActive,        -- Boolean: 是否正在显示进度
	startTime,       -- Integer: 开始时间戳
	lastUpdate,      -- Integer: 最后更新时间戳
	currentStep,     -- String: 当前步骤描述
	totalSteps,      -- Integer: 总步骤数
	currentStepNum   -- Integer: 当前步骤编号
)

-- 全局进度跟踪器
global progressTracker = ProgressTracker isActive:false startTime:0 lastUpdate:0 currentStep:"" totalSteps:0 currentStepNum:0

-- 更新预览状态显示
function updatePreviewStatus statusText =
(
	try (
		if statusText == undefined or statusText == "" then
			statusText = statusMsg.ready
		
		-- 更新UI标签（如果存在）
		if lbl2 != undefined then
			lbl2.text = statusText
		
		-- 记录到状态管理器
		if alignmentStateManager != undefined then
			alignmentStateManager.lastUpdateTime = timestamp()
		
		-- 输出到监听器窗口
		format "状态更新: %\n" statusText
		
		-- 处理待处理的Windows消息
		windows.processPostedMessages()
		
		return true
		
	) catch (
		format "状态反馈系统：更新状态显示失败\n"
		return false
	)
)

-- 显示带射线数量的预览状态
function updatePreviewStatusWithCount statusBase rayCount =
(
	try (
		local statusText = statusBase
		if rayCount != undefined and rayCount > 0 then
			statusText += "，显示 " + rayCount as string + " 条射线"
		
		return updatePreviewStatus statusText
		
	) catch (
		return updatePreviewStatus statusBase
	)
)

-- 显示错误状态
function updateErrorStatus errorMsg =
(
	try (
		local fullMsg = statusMsg.error
		if errorMsg != undefined and errorMsg != "" then
			fullMsg += "：" + errorMsg
		
		-- 记录错误到状态管理器
		setErrorState errorMsg
		
		return updatePreviewStatus fullMsg
		
	) catch (
		return updatePreviewStatus statusMsg.error
	)
)

-- 开始进度跟踪
function startProgress description totalSteps =
(
	try (
		progressTracker.isActive = true
		progressTracker.startTime = timestamp()
		progressTracker.lastUpdate = progressTracker.startTime
		progressTracker.currentStep = if description != undefined then description else "处理中"
		progressTracker.totalSteps = if totalSteps != undefined then totalSteps else 1
		progressTracker.currentStepNum = 0
		
		local statusText = "状态：" + progressTracker.currentStep + "..."
		updatePreviewStatus statusText
		
		return true
		
	) catch (
		format "状态反馈系统：开始进度跟踪失败\n"
		return false
	)
)

-- 更新进度
function updateProgress stepDescription stepNum =
(
	try (
		if not progressTracker.isActive then return false
		
		local currentTime = timestamp()
		local elapsed = (currentTime - progressTracker.lastUpdate) / 1000.0
		
		-- 只有超过1秒才更新进度（避免过于频繁的更新）
		if elapsed >= 1.0 or stepNum == progressTracker.totalSteps then
		(
			progressTracker.currentStep = if stepDescription != undefined then stepDescription else progressTracker.currentStep
			progressTracker.currentStepNum = if stepNum != undefined then stepNum else (progressTracker.currentStepNum + 1)
			progressTracker.lastUpdate = currentTime
			
			local statusText = "状态：" + progressTracker.currentStep
			
			if progressTracker.totalSteps > 1 then
				statusText += " (" + progressTracker.currentStepNum as string + "/" + progressTracker.totalSteps as string + ")"
			
			statusText += "..."
			
			updatePreviewStatus statusText
		)
		
		return true
		
	) catch (
		format "状态反馈系统：更新进度失败\n"
		return false
	)
)

-- 完成进度跟踪
function finishProgress finalMessage =
(
	try (
		if progressTracker.isActive then
		(
			local totalTime = (timestamp() - progressTracker.startTime) / 1000.0
			progressTracker.isActive = false
			
			local statusText = if finalMessage != undefined then finalMessage else "状态：操作完成"
			
			-- 如果操作时间超过2秒，显示耗时
			if totalTime >= 2.0 then
				statusText += "（耗时 " + (totalTime as string) + " 秒）"
			
			updatePreviewStatus statusText
		)
		
		return true
		
	) catch (
		format "状态反馈系统：完成进度跟踪失败\n"
		return false
	)
)

-- 取消进度跟踪
function cancelProgress cancelMessage =
(
	try (
		progressTracker.isActive = false
		
		local statusText = if cancelMessage != undefined then cancelMessage else statusMsg.userCancelled
		updatePreviewStatus statusText
		
		return true
		
	) catch (
		format "状态反馈系统：取消进度跟踪失败\n"
		return false
	)
)

-- 显示操作统计信息
function showOperationStats operation processedCount totalCount duration =
(
	try (
		local statusText = "状态：" + operation + "完成"
		
		if processedCount != undefined and totalCount != undefined then
		(
			statusText += "，处理 " + processedCount as string
			if totalCount != processedCount then
				statusText += "/" + totalCount as string
			statusText += " 个对象"
		)
		
		if duration != undefined and duration >= 1.0 then
			statusText += "，耗时 " + (duration as string) + " 秒"
		
		updatePreviewStatus statusText
		
		return true
		
	) catch (
		format "状态反馈系统：显示操作统计失败\n"
		return false
	)
)

-- 获取当前状态摘要（用于调试）
function getStatusSummary =
(
	try (
		local summary = "状态反馈系统摘要：\n"
		
		-- 当前状态
		if lbl2 != undefined then
			summary += "- 当前状态: " + lbl2.text + "\n"
		
		-- 进度跟踪状态
		if progressTracker.isActive then
		(
			local elapsed = (timestamp() - progressTracker.startTime) / 1000.0
			summary += "- 进度跟踪: 活动中，" + progressTracker.currentStep + "，已运行 " + elapsed as string + " 秒\n"
		)
		else
		(
			summary += "- 进度跟踪: 非活动\n"
		)
		
		-- 状态管理器状态
		if alignmentStateManager != undefined then
		(
			summary += "- 预览状态: " + (if alignmentStateManager.isActive then "启用" else "禁用") + "\n"
			if alignmentStateManager.lastError != "" then
				summary += "- 最后错误: " + alignmentStateManager.lastError + "\n"
		)
		
		return summary
		
	) catch (
		return "状态反馈系统：获取摘要失败"
	)
)

-- ========== 性能监控和优化系统 ==========

-- 性能指标结构
struct PerformanceMetrics (
	operationName,        -- String: 操作名称
	startTime,           -- Integer: 开始时间戳
	endTime,             -- Integer: 结束时间戳
	duration,            -- Float: 持续时间（秒）
	objectCount,         -- Integer: 处理的对象数量
	successCount,        -- Integer: 成功处理的数量
	errorCount,          -- Integer: 错误数量
	memoryUsage,         -- Integer: 内存使用量（如果可获取）
	throughput           -- Float: 吞吐量（对象/秒）
)

-- 全局性能跟踪器
global performanceTracker = #()

-- 开始性能监控
function startPerformanceMonitoring operationName objectCount =
(
	try (
		local metrics = PerformanceMetrics operationName:operationName startTime:(timestamp()) endTime:0 duration:0.0 objectCount:objectCount successCount:0 errorCount:0 memoryUsage:0 throughput:0.0
		
		append performanceTracker metrics
		
		format "性能监控：开始监控 '%' 操作，对象数量: %\n" operationName objectCount
		
		return (performanceTracker.count) -- 返回索引
		
	) catch (
		format "性能监控：开始监控失败\n"
		return 0
	)
)

-- 结束性能监控
function endPerformanceMonitoring monitorIndex successCount errorCount =
(
	try (
		if monitorIndex <= 0 or monitorIndex > performanceTracker.count then
		(
			format "性能监控：无效的监控索引\n"
			return undefined
		)
		
		local metrics = performanceTracker[monitorIndex]
		metrics.endTime = timestamp()
		metrics.duration = (metrics.endTime - metrics.startTime) / 1000.0
		metrics.successCount = if successCount != undefined then successCount else 0
		metrics.errorCount = if errorCount != undefined then errorCount else 0
		
		-- 计算吞吐量
		if metrics.duration > 0 then
			metrics.throughput = metrics.successCount / metrics.duration
		
		-- 尝试获取内存使用情况（如果可用）
		try (
			metrics.memoryUsage = heapSize
		) catch ()
		
		-- 输出性能报告
		format "性能监控：'%' 操作完成\n" metrics.operationName
		format "- 持续时间: %.3f 秒\n" metrics.duration
		format "- 处理对象: %/%\n" metrics.successCount metrics.objectCount
		if metrics.errorCount > 0 then
			format "- 错误数量: %\n" metrics.errorCount
		format "- 吞吐量: %.2f 对象/秒\n" metrics.throughput
		
		return metrics
		
	) catch (
		format "性能监控：结束监控失败\n"
		return undefined
	)
)

-- 性能基准测试
function performanceBenchmark operationFunc objectCounts =
(
	try (
		format "性能基准测试：开始测试...\n"
		local results = #()
		
		for count in objectCounts do
		(
			format "测试对象数量: %\n" count
			
			local startTime = timestamp()
			local result = operationFunc count
			local endTime = timestamp()
			
			local duration = (endTime - startTime) / 1000.0
			local throughput = if duration > 0 then count / duration else 0
			
			append results #(count, duration, throughput)
			
			format "- 耗时: %.3f 秒，吞吐量: %.2f 对象/秒\n" duration throughput
		)
		
		format "性能基准测试：完成\n"
		return results
		
	) catch (
		format "性能基准测试：失败\n"
		return #()
	)
)

-- 自动性能优化建议
function getPerformanceRecommendations =
(
	try (
		local recommendations = #()
		
		-- 分析最近的性能数据
		if performanceTracker.count > 0 then
		(
			local recentMetrics = performanceTracker[performanceTracker.count]
			
			-- 检查吞吐量
			if recentMetrics.throughput < 10 then
				append recommendations "建议：减少预览对象数量以提高性能"
			
			-- 检查错误率
			local errorRate = if recentMetrics.objectCount > 0 then (recentMetrics.errorCount as float / recentMetrics.objectCount) else 0
			if errorRate > 0.1 then
				append recommendations "建议：检查输入数据质量，错误率较高"
			
			-- 检查持续时间
			if recentMetrics.duration > 10 then
				append recommendations "建议：考虑分批处理大量对象"
		)
		
		-- 检查内存使用
		try (
			local currentMemory = heapSize
			if currentMemory > 100000000 then -- 100MB
				append recommendations "建议：执行内存清理，当前内存使用较高"
		) catch ()
		
		-- 检查预览射线数量
		if previewRays != undefined and previewRays.count > 200 then
			append recommendations "建议：减少预览射线数量以提高渲染性能"
		
		return recommendations
		
	) catch (
		format "性能优化建议：获取失败\n"
		return #()
	)
)

-- 性能优化执行
function applyPerformanceOptimizations =
(
	try (
		local optimizationsApplied = 0
		
		-- 优化1：清理旧的性能数据
		if performanceTracker.count > 50 then
		(
			local keepCount = 20
			local newTracker = #()
			for i = (performanceTracker.count - keepCount + 1) to performanceTracker.count do
				append newTracker performanceTracker[i]
			performanceTracker = newTracker
			optimizationsApplied += 1
			format "性能优化：清理了旧的性能数据\n"
		)
		
		-- 优化2：限制预览射线数量
		if previewRays != undefined and previewRays.count > 100 then
		(
			local newRays = #()
			for i = 1 to 100 do
				append newRays previewRays[i]
			previewRays = newRays
			optimizationsApplied += 1
			format "性能优化：限制了预览射线数量到100条\n"
		)
		
		-- 优化3：执行垃圾回收
		try (
			gc()
			optimizationsApplied += 1
			format "性能优化：执行了垃圾回收\n"
		) catch ()
		
		format "性能优化：应用了 % 项优化\n" optimizationsApplied
		return optimizationsApplied
		
	) catch (
		format "性能优化：执行失败\n"
		return 0
	)
)

-- 获取性能报告
function getPerformanceReport =
(
	try (
		local report = "性能监控报告：\n"
		
		if performanceTracker.count == 0 then
		(
			report += "- 暂无性能数据\n"
			return report
		)
		
		-- 统计信息
		local totalOperations = performanceTracker.count
		local totalDuration = 0.0
		local totalObjects = 0
		local totalErrors = 0
		
		for metrics in performanceTracker do
		(
			totalDuration += metrics.duration
			totalObjects += metrics.objectCount
			totalErrors += metrics.errorCount
		)
		
		local avgDuration = totalDuration / totalOperations
		local avgThroughput = if totalDuration > 0 then totalObjects / totalDuration else 0
		local errorRate = if totalObjects > 0 then (totalErrors as float / totalObjects) else 0
		
		report += "- 总操作数: " + totalOperations as string + "\n"
		report += "- 平均耗时: " + avgDuration as string + " 秒\n"
		report += "- 平均吞吐量: " + avgThroughput as string + " 对象/秒\n"
		report += "- 错误率: " + (errorRate * 100) as string + "%\n"
		
		-- 最近操作
		if totalOperations > 0 then
		(
			local lastMetrics = performanceTracker[totalOperations]
			report += "- 最近操作: " + lastMetrics.operationName + "\n"
			report += "- 最近耗时: " + lastMetrics.duration as string + " 秒\n"
		)
		
		-- 性能建议
		local recommendations = getPerformanceRecommendations()
		if recommendations.count > 0 then
		(
			report += "- 性能建议:\n"
			for rec in recommendations do
				report += "  * " + rec + "\n"
		)
		
		return report
		
	) catch (
		return "性能监控报告：获取失败"
	)
)

-- ========== 输入验证和几何体检查系统 ==========

-- 几何体验证结果结构
struct GeometryValidationResult (
	isValid,          -- Boolean: 是否有效
	errorMessage,     -- String: 错误信息
	warningMessage,   -- String: 警告信息
	geometryType,     -- String: 几何体类型
	hasValidBounds,   -- Boolean: 是否有有效边界
	faceCount,        -- Integer: 面数（如果适用）
	vertexCount       -- Integer: 顶点数（如果适用）
)

-- 增强的几何体验证函数
function isValidGeometry obj =
(
	local result = validateGeometryDetailed obj
	return result.isValid
)

-- 详细的几何体验证函数
function validateGeometryDetailed obj =
(
	local result = GeometryValidationResult isValid:false errorMessage:"" warningMessage:"" geometryType:"unknown" hasValidBounds:false faceCount:0 vertexCount:0
	
	try (
		-- 基本存在性检查
		if obj == undefined then
		(
			result.errorMessage = "对象为空"
			return result
		)
		
		-- 检查对象是否仍然存在于场景中
		if not isValidNode obj then
		(
			result.errorMessage = "对象不存在于场景中"
			return result
		)
		
		-- 获取对象类型信息
		result.geometryType = classOf obj as string
		
		-- 检查是否为几何体类型
		local isGeom = false
		try (
			isGeom = (findItem (geometry as array) obj) > 0
		) catch (
			-- 在某些版本中geometry as array可能失败，使用备用方法
			isGeom = (superClassOf obj == GeometryClass)
		)
		
		if not isGeom then
		(
			result.errorMessage = "对象不是几何体类型（类型：" + result.geometryType + "）"
			return result
		)
		
		-- 检查边界框
		local bbox = undefined
		try (
			bbox = obj.boundingBox
		) catch (
			result.errorMessage = "无法获取对象边界框"
			return result
		)
		
		if bbox == undefined then
		(
			result.errorMessage = "对象边界框为空"
			return result
		)
		
		-- 验证边界框的有效性
		local minPt = bbox[1]
		local maxPt = bbox[2]
		
		if minPt == undefined or maxPt == undefined then
		(
			result.errorMessage = "边界框数据无效"
			return result
		)
		
		-- 检查边界框是否为有效的数值
		if not (isValidFloat minPt.x and isValidFloat minPt.y and isValidFloat minPt.z and
		        isValidFloat maxPt.x and isValidFloat maxPt.y and isValidFloat maxPt.z) then
		(
			result.errorMessage = "边界框包含无效数值"
			return result
		)
		
		-- 检查边界框是否有有效的体积
		local size = maxPt - minPt
		if size.x <= 0 or size.y <= 0 or size.z <= 0 then
		(
			result.errorMessage = "对象边界框体积无效（尺寸：" + size as string + "）"
			return result
		)
		
		result.hasValidBounds = true
		
		-- 尝试获取网格信息（如果适用）
		try (
			local mesh = snapshotAsMesh obj
			if mesh != undefined then
			(
				result.faceCount = mesh.numfaces
				result.vertexCount = mesh.numverts
				
				-- 检查网格是否有效
				if result.faceCount == 0 then
					result.warningMessage = "对象没有面"
				else if result.vertexCount == 0 then
					result.warningMessage = "对象没有顶点"
			)
		) catch (
			result.warningMessage = "无法获取网格信息"
		)
		
		-- 检查对象是否被隐藏或冻结
		if obj.isHidden then
			result.warningMessage += (if result.warningMessage != "" then "；" else "") + "对象被隐藏"
		
		if obj.isFrozen then
			result.warningMessage += (if result.warningMessage != "" then "；" else "") + "对象被冻结"
		
		-- 所有检查通过
		result.isValid = true
		return result
		
	) catch (
		result.errorMessage = "几何体验证过程发生错误: " + (getCurrentException() as string)
		return result
	)
)

-- 验证预览输入参数
function validatePreviewInputs targetSurface selectedObjects =
(
	local validationResults = #()
	local isValid = true
	local errorMessages = #()
	local warningMessages = #()
	
	try (
		-- 验证目标表面
		if targetSurface == undefined then
		(
			append errorMessages "目标表面未指定"
			isValid = false
		)
		else
		(
			local targetResult = validateGeometryDetailed targetSurface
			append validationResults targetResult
			
			if not targetResult.isValid then
			(
				append errorMessages ("目标表面无效: " + targetResult.errorMessage)
				isValid = false
			)
			else if targetResult.warningMessage != "" then
			(
				append warningMessages ("目标表面警告: " + targetResult.warningMessage)
			)
		)
		
		-- 验证选中的对象
		if selectedObjects == undefined or selectedObjects.count == 0 then
		(
			append errorMessages "没有选中任何对象"
			isValid = false
		)
		else
		(
			local validObjectCount = 0
			local invalidObjectCount = 0
			
			for i = 1 to selectedObjects.count do
			(
				local obj = selectedObjects[i]
				local objResult = validateGeometryDetailed obj
				
				if objResult.isValid then
					validObjectCount += 1
				else
					invalidObjectCount += 1
			)
			
			if validObjectCount == 0 then
			(
				append errorMessages "所有选中的对象都无效"
				isValid = false
			)
			else if invalidObjectCount > 0 then
			(
				append warningMessages ("有 " + invalidObjectCount as string + " 个无效对象将被跳过")
			)
		)
		
		-- 性能限制检查
		if selectedObjects != undefined and selectedObjects.count > 1000 then
		(
			append warningMessages ("选中对象过多（" + selectedObjects.count as string + "），可能影响性能")
		)
		
		-- 输出验证结果
		if errorMessages.count > 0 then
		(
			format "输入验证错误：\n"
			for msg in errorMessages do
				format "- %\n" msg
		)
		
		if warningMessages.count > 0 then
		(
			format "输入验证警告：\n"
			for msg in warningMessages do
				format "- %\n" msg
		)
		
		return isValid
		
	) catch (
		format "输入验证过程发生错误: %\n" (getCurrentException())
		return false
	)
)

-- 对象计数验证和性能限制
function validateObjectCount objectCount operation =
(
	try (
		local maxCounts = #(
			#("preview", 100),      -- 预览最多100个对象
			#("alignment", 10000),  -- 对齐最多10000个对象
			#("calculation", 1000)  -- 计算最多1000个对象
		)
		
		local maxCount = 100 -- 默认限制
		
		-- 查找对应操作的限制
		for limitPair in maxCounts do
		(
			if limitPair[1] == operation then
			(
				maxCount = limitPair[2]
				exit
			)
		)
		
		if objectCount > maxCount then
		(
			format "性能限制：%操作最多支持 % 个对象，当前 % 个\n" operation maxCount objectCount
			return maxCount
		)
		
		return objectCount
		
	) catch (
		format "对象计数验证失败\n"
		return objectCount
	)
)

-- 几何体类型兼容性检查
function checkGeometryCompatibility obj1 obj2 =
(
	try (
		if obj1 == undefined or obj2 == undefined then return false
		
		local type1 = classOf obj1
		local type2 = classOf obj2
		
		-- 检查是否都是几何体
		if not (isValidGeometry obj1 and isValidGeometry obj2) then return false
		
		-- 特殊兼容性检查
		local incompatiblePairs = #(
			#(Plane, Sphere),      -- 平面和球体可能有问题
			#(Teapot, Box)         -- 茶壶和盒子的特殊情况
		)
		
		for pair in incompatiblePairs do
		(
			if (type1 == pair[1] and type2 == pair[2]) or (type1 == pair[2] and type2 == pair[1]) then
			(
				format "几何体兼容性警告：% 和 % 可能不完全兼容\n" type1 type2
				return true -- 警告但不阻止
			)
		)
		
		return true
		
	) catch (
		format "几何体兼容性检查失败\n"
		return false
	)
)

-- ========== 图形窗口管理器 (Graphics Window Manager) ==========

-- 图形窗口上下文结构
struct GraphicsContext (
	gw,           -- Graphics Window 对象
	isValid,      -- GW 有效性状态
	method        -- 使用的访问方法
)

-- 获取图形窗口的主函数（带回退机制）
function getGraphicsWindow =
(
	local context = GraphicsContext gw:undefined isValid:false method:"none"
	
	-- 方法1：使用 getViewport().getGW()（3ds Max 2022+ 推荐方法）
	try (
		local testGW = getViewport().getGW()
		if validateGraphicsWindow testGW then (
			context.gw = testGW
			context.isValid = true
			context.method = "getViewport().getGW()"
			return context
		)
	) catch (
		format "图形窗口管理器：getViewport().getGW() 方法失败\n"
	)
	
	-- 方法2：使用 viewport.activeViewport.getGW()（回退方法）
	try (
		local activeVP = viewport.activeViewport
		if activeVP != undefined then (
			local testGW = activeVP.getGW()
			if validateGraphicsWindow testGW then (
				context.gw = testGW
				context.isValid = true
				context.method = "viewport.activeViewport.getGW()"
				return context
			)
		)
	) catch (
		format "图形窗口管理器：viewport.activeViewport.getGW() 方法失败\n"
	)
	
	-- 方法3：尝试全局 gw 变量（最后的回退）
	try (
		if gw != undefined and validateGraphicsWindow gw then (
			context.gw = gw
			context.isValid = true
			context.method = "global gw variable"
			return context
		)
	) catch (
		format "图形窗口管理器：全局 gw 变量不可用\n"
	)
	
	-- 所有方法都失败
	format "错误：无法获取有效的 Graphics Window\n"
	return context
)

-- 验证图形窗口对象的有效性
function validateGraphicsWindow gwObj =
(
	try (
		-- 检查对象是否存在
		if gwObj == undefined then return false
		
		-- 检查是否有基本的绘制方法
		if not hasProperty gwObj #setColor then return false
		if not hasProperty gwObj #polyline then return false
		if not hasProperty gwObj #updateScreen then return false
		
		-- 尝试执行一个安全的测试操作
		try (
			gwObj.setColor #line (color 255 255 255)
			return true
		) catch (
			return false
		)
		
	) catch (
		return false
	)
)

-- 获取图形窗口的简化接口（向后兼容）
function getGW =
(
	local context = getGraphicsWindow()
	if context.isValid then
		return context.gw
	else
		return undefined
)

-- 脚本完整性检查函数（增强版）
function validateScriptIntegrity =
(
	try (
		format "开始图形窗口管理器完整性检查...\n"
		
		-- 测试图形窗口管理器
		local gwContext = getGraphicsWindow()
		if gwContext.isValid then
		(
			format "✓ 图形窗口管理器可用，使用方法: %\n" gwContext.method
		)
		else
		(
			format "✗ 图形窗口管理器不可用，预览功能将被禁用\n"
		)
		
		-- 检查全局变量
		if previewRays == undefined then previewRays = #()
		if isPreviewActive == undefined then isPreviewActive = false
		if isAlignmentActive == undefined then isAlignmentActive = false
		
		format "脚本完整性检查完成\n"
		return gwContext.isValid
	) catch (
		format "脚本完整性检查失败: %\n" (getCurrentException())
		return false
	)
)

-- 注意：脚本完整性检查将在所有函数定义完成后执行

-- 定义射线数据结构
struct rayInfo (startPoint, endPoint)

-- ========== 预览渲染器 (Preview Renderer) ==========

-- 渲染统计结构
struct RenderStats (
	totalRays,        -- Integer: 总射线数
	validRays,        -- Integer: 有效射线数
	drawnLines,       -- Integer: 成功绘制的线段数
	renderTime,       -- Float: 渲染耗时（秒）
	hasErrors         -- Boolean: 是否有错误
)

-- 创建箭头几何体
function createArrowGeometry startPoint endPoint arrowSize =
(
	local arrowLines = #()
	
	try (
		-- 验证输入
		if startPoint == undefined or endPoint == undefined then return arrowLines
		if classOf startPoint != Point3 or classOf endPoint != Point3 then return arrowLines
		if arrowSize == undefined or arrowSize <= 0 then arrowSize = 2.0
		
		-- 计算方向向量
		local dir = endPoint - startPoint
		local dirLength = length dir
		
		-- 避免零向量问题
		if dirLength <= 0.1 then return arrowLines
		
		local rayDir = normalize dir
		
		-- 改进的箭头计算，避免零向量问题
		local perpVec = [0,0,1]
		if abs(dot rayDir perpVec) > 0.9 then
			perpVec = [1,0,0] -- 如果射线接近垂直，使用X轴
		
		-- 计算垂直向量
		local crossVec = normalize (cross rayDir perpVec)
		
		-- 创建箭头点
		local arrowBase = endPoint - rayDir * arrowSize
		local arrowPt1 = arrowBase + crossVec * arrowSize * 0.3
		local arrowPt2 = arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
)

-- 批量渲染射线
function renderRayBatch rayArray graphicsWindow =
(
	local stats = RenderStats totalRays:0 validRays:0 drawnLines:0 renderTime:0.0 hasErrors:false
	local startTime = timestamp()
	
	try (
		-- 输入验证
		if rayArray == undefined or rayArray.count == 0 then
		(
			format "预览渲染器：没有射线数据\n"
			return stats
		)
		
		if graphicsWindow == undefined then
		(
			format "预览渲染器：图形窗口无效\n"
			stats.hasErrors = true
			return stats
		)
		
		stats.totalRays = rayArray.count
		
		-- 设置绘制颜色
		try (
			graphicsWindow.setColor #line alignmentPreviewColor
		) catch (
			format "预览渲染器：无法设置绘制颜色\n"
			stats.hasErrors = true
		)
		
		-- 性能限制
		local maxRays = 100
		local rayCount = amin #(rayArray.count, maxRays)
		
		-- 收集所有线段数据
		local allLines = #()
		local validRayCount = 0
		
		for i = 1 to rayCount do
		(
			local rayData = rayArray[i]
			if rayData != undefined then
			(
				try (
					local startPt = rayData.startPoint
					local endPt = rayData.endPoint
					
					-- 验证点的有效性
					if startPt != undefined and endPt != undefined and 
					   classOf startPt == Point3 and classOf endPt == Point3 then
					(
						-- 添加主射线
						append allLines #(startPt, endPt)
						validRayCount += 1
						
						-- 添加箭头几何体
						local arrowLines = createArrowGeometry startPt endPt 2.0
						for arrowLine in arrowLines do
						(
							append allLines arrowLine
						)
					)
				) catch (
					-- 单个射线处理失败时继续
					stats.hasErrors = true
					continue
				)
			)
		)
		
		stats.validRays = validRayCount
		
		-- 批量绘制所有线段
		local drawnCount = 0
		local batchSize = 50 -- 每批绘制50条线段
		
		for i = 1 to allLines.count by batchSize do
		(
			local endIndex = amin #(i + batchSize - 1, allLines.count)
			
			-- 绘制当前批次
			for j = i to endIndex do
			(
				try (
					graphicsWindow.polyline allLines[j] false
					drawnCount += 1
				) catch (
					-- 单条线段绘制失败时继续
					stats.hasErrors = true
					continue
				)
			)
			
			-- 每批次后短暂暂停，避免阻塞UI
			if endIndex < allLines.count then
				windows.processPostedMessages()
		)
		
		stats.drawnLines = drawnCount
		
		-- 更新显示
		try (
			graphicsWindow.enlargeUpdateRect #whole
			graphicsWindow.updateScreen()
		) catch (
			-- 更新失败时使用备用方法
			try (
				redrawViews()
			) catch (
				format "预览渲染器：无法更新显示\n"
				stats.hasErrors = true
			)
		)
		
		-- 计算渲染时间
		stats.renderTime = (timestamp() - startTime) / 1000.0
		
		-- 显示统计信息
		if validRayCount > 0 then
		(
			if rayArray.count > maxRays then
				format "预览渲染器：显示前 % 条射线（共 % 条），绘制 % 条线段，耗时 %.3f 秒\n" maxRays rayArray.count drawnCount stats.renderTime
			else
				format "预览渲染器：显示 % 条射线，绘制 % 条线段，耗时 %.3f 秒\n" validRayCount drawnCount stats.renderTime
		)
		
		return stats
		
	) catch (
		format "预览渲染器：批量渲染失败: %\n" (getCurrentException())
		stats.hasErrors = true
		stats.renderTime = (timestamp() - startTime) / 1000.0
		return stats
	)
)

-- 主绘制函数（重构版，使用新的预览渲染器）
function drawAlignmentRays =
(
	try (
		-- 检查预览数据是否存在
		if not isPreviewActive or previewRays == undefined or previewRays.count == 0 then 
		(
			return ok
		)
		
		-- 使用图形窗口管理器获取GW
		local gwContext = getGraphicsWindow()
		if not gwContext.isValid then
		(
			-- 使用回调错误处理
			handleCallbackError "无法获取Graphics Window"
			return ok
		)
		
		-- 使用新的批量渲染器
		local renderStats = renderRayBatch previewRays gwContext.gw
		
		-- 检查渲染结果
		if renderStats.hasErrors then
		(
			handleCallbackError "渲染过程中出现错误"
		)
		
		return ok
		
	) catch (
		local errorMsg = "射线预览绘制失败: " + (getCurrentException() as string)
		format "错误：%\n" errorMsg
		handleCallbackError errorMsg
		return ok
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
)

-- 批量渲染射线
function renderRayBatch rayArray graphicsWindow =
(
	local stats = RenderStats totalRays:0 validRays:0 drawnLines:0 renderTime:0.0 hasErrors:false
	local startTime = timestamp()
	
	try (
		-- 输入验证
		if rayArray == undefined or rayArray.count == 0 then
		(
			format "预览渲染器：没有射线数据\n"
			return stats
		)
		
		if graphicsWindow == undefined then
		(
			format "预览渲染器：图形窗口无效\n"
			stats.hasErrors = true
			return stats
		)
		
		stats.totalRays = rayArray.count
		
		-- 设置绘制颜色
		try (
			graphicsWindow.setColor #line alignmentPreviewColor
		) catch (
			format "预览渲染器：无法设置绘制颜色\n"
			stats.hasErrors = true
		)
		
		-- 性能限制
		local maxRays = 100
		local rayCount = amin #(rayArray.count, maxRays)
		
		-- 收集所有线段数据
		local allLines = #()
		local validRayCount = 0
		
		for i = 1 to rayCount do
		(
			local rayData = rayArray[i]
			if rayData != undefined then
			(
				try (
					local startPt = rayData.startPoint
					local endPt = rayData.endPoint
					
					-- 验证点的有效性
					if startPt != undefined and endPt != undefined and 
					   classOf startPt == Point3 and classOf endPt == Point3 then
					(
						-- 添加主射线
						append allLines #(startPt, endPt)
						validRayCount += 1
						
						-- 添加箭头几何体
						local arrowLines = createArrowGeometry startPt endPt 2.0
						for arrowLine in arrowLines do
						(
							append allLines arrowLine
						)
					)
				) catch (
					-- 单个射线处理失败时继续
					stats.hasErrors = true
					continue
				)
			)
		)
		
		stats.validRays = validRayCount
		
		-- 批量绘制所有线段
		local drawnCount = 0
		local batchSize = 50 -- 每批绘制50条线段
		
		for i = 1 to allLines.count by batchSize do
		(
			local endIndex = amin #(i + batchSize - 1, allLines.count)
			
			-- 绘制当前批次
			for j = i to endIndex do
			(
				try (
					graphicsWindow.polyline allLines[j] false
					drawnCount += 1
				) catch (
					-- 单条线段绘制失败时继续
					stats.hasErrors = true
					continue
				)
			)
			
			-- 每批次后短暂暂停，避免阻塞UI
			if endIndex < allLines.count then
				windows.processPostedMessages()
		)
		
		stats.drawnLines = drawnCount
		
		-- 更新显示
		try (
			graphicsWindow.enlargeUpdateRect #whole
			graphicsWindow.updateScreen()
		) catch (
			-- 更新失败时使用备用方法
			try (
				redrawViews()
			) catch (
				format "预览渲染器：无法更新显示\n"
				stats.hasErrors = true
			)
		)
		
		-- 计算渲染时间
		stats.renderTime = (timestamp() - startTime) / 1000.0
		
		-- 显示统计信息
		if validRayCount > 0 then
		(
			if rayArray.count > maxRays then
				format "预览渲染器：显示前 % 条射线（共 % 条），绘制 % 条线段，耗时 %.3f 秒\n" maxRays rayArray.count drawnCount stats.renderTime
			else
				format "预览渲染器：显示 % 条射线，绘制 % 条线段，耗时 %.3f 秒\n" validRayCount drawnCount stats.renderTime
		)
		
		return stats
		
	) catch (
		format "预览渲染器：批量渲染失败: %\n" (getCurrentException())
		stats.hasErrors = true
		stats.renderTime = (timestamp() - startTime) / 1000.0
		return stats
	)
)

-- 主绘制函数（重构版，使用新的预览渲染器）
function drawAlignmentRays =
(
	try (
		-- 检查预览数据是否存在
		if not isPreviewActive or previewRays == undefined or previewRays.count == 0 then 
		(
			return ok
		)
		
		-- 使用图形窗口管理器获取GW
		local gwContext = getGraphicsWindow()
		if not gwContext.isValid then
		(
			-- 使用回调错误处理
			handleCallbackError "无法获取Graphics Window"
			return ok
		)
		
		-- 使用新的批量渲染器
		local renderStats = renderRayBatch previewRays gwContext.gw
		
		-- 检查渲染结果
		if renderStats.hasErrors then
		(
			handleCallbackError "渲染过程中出现错误"
		)
		
		return ok
		
	) catch (
		local errorMsg = "射线预览绘制失败: " + (getCurrentException() as string)
		format "错误：%\n" errorMsg
		handleCallbackError errorMsg
		return ok
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
)

-- 批量渲染射线
function renderRayBatch rayArray graphicsWindow =
(
	local stats = RenderStats totalRays:0 validRays:0 drawnLines:0 renderTime:0.0 hasErrors:false
	local startTime = timestamp()
	
	try (
		-- 输入验证
		if rayArray == undefined or rayArray.count == 0 then
		(
			format "预览渲染器：没有射线数据\n"
			return stats
		)
		
		if graphicsWindow == undefined then
		(
			format "预览渲染器：图形窗口无效\n"
			stats.hasErrors = true
			return stats
		)
		
		stats.totalRays = rayArray.count
		
		-- 设置绘制颜色
		try (
			graphicsWindow.setColor #line alignmentPreviewColor
		) catch (
			format "预览渲染器：无法设置绘制颜色\n"
			stats.hasErrors = true
		)
		
		-- 性能限制
		local maxRays = 100
		local rayCount = amin #(rayArray.count, maxRays)
		
		-- 收集所有线段数据
		local allLines = #()
		local validRayCount = 0
		
		for i = 1 to rayCount do
		(
			local rayData = rayArray[i]
			if rayData != undefined then
			(
				try (
					local startPt = rayData.startPoint
					local endPt = rayData.endPoint
					
					-- 验证点的有效性
					if startPt != undefined and endPt != undefined and 
					   classOf startPt == Point3 and classOf endPt == Point3 then
					(
						-- 添加主射线
						append allLines #(startPt, endPt)
						validRayCount += 1
						
						-- 添加箭头几何体
						local arrowLines = createArrowGeometry startPt endPt 2.0
						for arrowLine in arrowLines do
						(
							append allLines arrowLine
						)
					)
				) catch (
					-- 单个射线处理失败时继续
					stats.hasErrors = true
					continue
				)
			)
		)
		
		stats.validRays = validRayCount
		
		-- 批量绘制所有线段
		local drawnCount = 0
		local batchSize = 50 -- 每批绘制50条线段
		
		for i = 1 to allLines.count by batchSize do
		(
			local endIndex = amin #(i + batchSize - 1, allLines.count)
			
			-- 绘制当前批次
			for j = i to endIndex do
			(
				try (
					graphicsWindow.polyline allLines[j] false
					drawnCount += 1
				) catch (
					-- 单条线段绘制失败时继续
					stats.hasErrors = true
					continue
				)
			)
			
			-- 每批次后短暂暂停，避免阻塞UI
			if endIndex < allLines.count then
				windows.processPostedMessages()
		)
		
		stats.drawnLines = drawnCount
		
		-- 更新显示
		try (
			graphicsWindow.enlargeUpdateRect #whole
			graphicsWindow.updateScreen()
		) catch (
			-- 更新失败时使用备用方法
			try (
				redrawViews()
			) catch (
				format "预览渲染器：无法更新显示\n"
				stats.hasErrors = true
			)
		)
		
		-- 计算渲染时间
		stats.renderTime = (timestamp() - startTime) / 1000.0
		
		-- 显示统计信息
		if validRayCount > 0 then
		(
			if rayArray.count > maxRays then
				format "预览渲染器：显示前 % 条射线（共 % 条），绘制 % 条线段，耗时 %.3f 秒\n" maxRays rayArray.count drawnCount stats.renderTime
			else
				format "预览渲染器：显示 % 条射线，绘制 % 条线段，耗时 %.3f 秒\n" validRayCount drawnCount stats.renderTime
		)
		
		return stats
		
	) catch (
		format "预览渲染器：批量渲染失败: %\n" (getCurrentException())
		stats.hasErrors = true
		stats.renderTime = (timestamp() - startTime) / 1000.0
		return stats
	)
)

-- 主绘制函数（重构版，使用新的预览渲染器）
function drawAlignmentRays =
(
	try (
		-- 检查预览数据是否存在
		if not isPreviewActive or previewRays == undefined or previewRays.count == 0 then 
		(
			return ok
		)
		
		-- 使用图形窗口管理器获取GW
		local gwContext = getGraphicsWindow()
		if not gwContext.isValid then
		(
			-- 使用回调错误处理
			handleCallbackError "无法获取Graphics Window"
			return ok
		)
		
		-- 使用新的批量渲染器
		local renderStats = renderRayBatch previewRays gwContext.gw
		
		-- 检查渲染结果
		if renderStats.hasErrors then
		(
			handleCallbackError "渲染过程中出现错误"
		)
		
		return ok
		
	) catch (
		local errorMsg = "射线预览绘制失败: " + (getCurrentException() as string)
		format "错误：%\n" errorMsg
		handleCallbackError errorMsg
		return ok
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
)

-- 批量渲染射线
function renderRayBatch rayArray graphicsWindow =
(
	local stats = RenderStats totalRays:0 validRays:0 drawnLines:0 renderTime:0.0 hasErrors:false
	local startTime = timestamp()
	
	try (
		-- 输入验证
		if rayArray == undefined or rayArray.count == 0 then
		(
			format "预览渲染器：没有射线数据\n"
			return stats
		)
		
		if graphicsWindow == undefined then
		(
			format "预览渲染器：图形窗口无效\n"
			stats.hasErrors = true
			return stats
		)
		
		stats.totalRays = rayArray.count
		
		-- 设置绘制颜色
		try (
			graphicsWindow.setColor #line alignmentPreviewColor
		) catch (
			format "预览渲染器：无法设置绘制颜色\n"
			stats.hasErrors = true
		)
		
		-- 性能限制
		local maxRays = 100
		local rayCount = amin #(rayArray.count, maxRays)
		
		-- 收集所有线段数据
		local allLines = #()
		local validRayCount = 0
		
		for i = 1 to rayCount do
		(
			local rayData = rayArray[i]
			if rayData != undefined then
			(
				try (
					local startPt = rayData.startPoint
					local endPt = rayData.endPoint
					
					-- 验证点的有效性
					if startPt != undefined and endPt != undefined and 
					   classOf startPt == Point3 and classOf endPt == Point3 then
					(
						-- 添加主射线
						append allLines #(startPt, endPt)
						validRayCount += 1
						
						-- 添加箭头几何体
						local arrowLines = createArrowGeometry startPt endPt 2.0
						for arrowLine in arrowLines do
						(
							append allLines arrowLine
						)
					)
				) catch (
					-- 单个射线处理失败时继续
					stats.hasErrors = true
					continue
				)
			)
		)
		
		stats.validRays = validRayCount
		
		-- 批量绘制所有线段
		local drawnCount = 0
		local batchSize = 50 -- 每批绘制50条线段
		
		for i = 1 to allLines.count by batchSize do
		(
			local endIndex = amin #(i + batchSize - 1, allLines.count)
			
			-- 绘制当前批次
			for j = i to endIndex do
			(
				try (
					graphicsWindow.polyline allLines[j] false
					drawnCount += 1
				) catch (
					-- 单条线段绘制失败时继续
					stats.hasErrors = true
					continue
				)
			)
			
			-- 每批次后短暂暂停，避免阻塞UI
			if endIndex < allLines.count then
				windows.processPostedMessages()
		)
		
		stats.drawnLines = drawnCount
		
		-- 更新显示
		try (
			graphicsWindow.enlargeUpdateRect #whole
			graphicsWindow.updateScreen()
		) catch (
			-- 更新失败时使用备用方法
			try (
				redrawViews()
			) catch (
				format "预览渲染器：无法更新显示\n"
				stats.hasErrors = true
			)
		)
		
		-- 计算渲染时间
		stats.renderTime = (timestamp() - startTime) / 1000.0
		
		-- 显示统计信息
		if validRayCount > 0 then
		(
			if rayArray.count > maxRays then
				format "预览渲染器：显示前 % 条射线（共 % 条），绘制 % 条线段，耗时 %.3f 秒\n" maxRays rayArray.count drawnCount stats.renderTime
			else
				format "预览渲染器：显示 % 条射线，绘制 % 条线段，耗时 %.3f 秒\n" validRayCount drawnCount stats.renderTime
		)
		
		return stats
		
	) catch (
		format "预览渲染器：批量渲染失败: %\n" (getCurrentException())
		stats.hasErrors = true
		stats.renderTime = (timestamp() - startTime) / 1000.0
		return stats
	)
)

-- 主绘制函数（重构版，使用新的预览渲染器）
function drawAlignmentRays =
(
	try (
		-- 检查预览数据是否存在
		if not isPreviewActive or previewRays == undefined or previewRays.count == 0 then 
		(
			return ok
		)
		
		-- 使用图形窗口管理器获取GW
		local gwContext = getGraphicsWindow()
		if not gwContext.isValid then
		(
			-- 使用回调错误处理
			handleCallbackError "无法获取Graphics Window"
			return ok
		)
		
		-- 使用新的批量渲染器
		local renderStats = renderRayBatch previewRays gwContext.gw
		
		-- 检查渲染结果
		if renderStats.hasErrors then
		(
			handleCallbackError "渲染过程中出现错误"
		)
		
		return ok
		
	) catch (
		local errorMsg = "射线预览绘制失败: " + (getCurrentException() as string)
		format "错误：%\n" errorMsg
		handleCallbackError errorMsg
		return ok
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
)

-- 批量渲染射线
function renderRayBatch rayArray graphicsWindow =
(
	local stats = RenderStats totalRays:0 validRays:0 drawnLines:0 renderTime:0.0 hasErrors:false
	local startTime = timestamp()
	
	try (
		-- 输入验证
		if rayArray == undefined or rayArray.count == 0 then
		(
			format "预览渲染器：没有射线数据\n"
			return stats
		)
		
		if graphicsWindow == undefined then
		(
			format "预览渲染器：图形窗口无效\n"
			stats.hasErrors = true
			return stats
		)
		
		stats.totalRays = rayArray.count
		
		-- 设置绘制颜色
		try (
			graphicsWindow.setColor #line alignmentPreviewColor
		) catch (
			format "预览渲染器：无法设置绘制颜色\n"
			stats.hasErrors = true
		)
		
		-- 性能限制
		local maxRays = 100
		local rayCount = amin #(rayArray.count, maxRays)
		
		-- 收集所有线段数据
		local allLines = #()
		local validRayCount = 0
		
		for i = 1 to rayCount do
		(
			local rayData = rayArray[i]
			if rayData != undefined then
			(
				try (
					local startPt = rayData.startPoint
					local endPt = rayData.endPoint
					
					-- 验证点的有效性
					if startPt != undefined and endPt != undefined and 
					   classOf startPt == Point3 and classOf endPt == Point3 then
					(
						-- 添加主射线
						append allLines #(startPt, endPt)
						validRayCount += 1
						
						-- 添加箭头几何体
						local arrowLines = createArrowGeometry startPt endPt 2.0
						for arrowLine in arrowLines do
						(
							append allLines arrowLine
						)
					)
				) catch (
					-- 单个射线处理失败时继续
					stats.hasErrors = true
					continue
				)
			)
		)
		
		stats.validRays = validRayCount
		
		-- 批量绘制所有线段
		local drawnCount = 0
		local batchSize = 50 -- 每批绘制50条线段
		
		for i = 1 to allLines.count by batchSize do
		(
			local endIndex = amin #(i + batchSize - 1, allLines.count)
			
			-- 绘制当前批次
			for j = i to endIndex do
			(
				try (
					graphicsWindow.polyline allLines[j] false
					drawnCount += 1
				) catch (
					-- 单条线段绘制失败时继续
					stats.hasErrors = true
					continue
				)
			)
			
			-- 每批次后短暂暂停，避免阻塞UI
			if endIndex < allLines.count then
				windows.processPostedMessages()
		)
		
		stats.drawnLines = drawnCount
		
		-- 更新显示
		try (
			graphicsWindow.enlargeUpdateRect #whole
			graphicsWindow.updateScreen()
		) catch (
			-- 更新失败时使用备用方法
			try (
				redrawViews()
			) catch (
				format "预览渲染器：无法更新显示\n"
				stats.hasErrors = true
			)
		)
		
		-- 计算渲染时间
		stats.renderTime = (timestamp() - startTime) / 1000.0
		
		-- 显示统计信息
		if validRayCount > 0 then
		(
			if rayArray.count > maxRays then
				format "预览渲染器：显示前 % 条射线（共 % 条），绘制 % 条线段，耗时 %.3f 秒\n" maxRays rayArray.count drawnCount stats.renderTime
			else
				format "预览渲染器：显示 % 条射线，绘制 % 条线段，耗时 %.3f 秒\n" validRayCount drawnCount stats.renderTime
		)
		
		return stats
		
	) catch (
		format "预览渲染器：批量渲染失败: %\n" (getCurrentException())
		stats.hasErrors = true
		stats.renderTime = (timestamp() - startTime) / 1000.0
		return stats
	)
)

-- 主绘制函数（重构版，使用新的预览渲染器）
function drawAlignmentRays =
(
	try (
		-- 检查预览数据是否存在
		if not isPreviewActive or previewRays == undefined or previewRays.count == 0 then 
		(
			return ok
		)
		
		-- 使用图形窗口管理器获取GW
		local gwContext = getGraphicsWindow()
		if not gwContext.isValid then
		(
			-- 使用回调错误处理
			handleCallbackError "无法获取Graphics Window"
			return ok
		)
		
		-- 使用新的批量渲染器
		local renderStats = renderRayBatch previewRays gwContext.gw
		
		-- 检查渲染结果
		if renderStats.hasErrors then
		(
			handleCallbackError "渲染过程中出现错误"
		)
		
		return ok
		
	) catch (
		local errorMsg = "射线预览绘制失败: " + (getCurrentException() as string)
		format "错误：%\n" errorMsg
		handleCallbackError errorMsg
		return ok
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
)

-- 批量渲染射线
function renderRayBatch rayArray graphicsWindow =
(
	local stats = RenderStats totalRays:0 validRays:0 drawnLines:0 renderTime:0.0 hasErrors:false
	local startTime = timestamp()
	
	try (
		-- 输入验证
		if rayArray == undefined or rayArray.count == 0 then
		(
			format "预览渲染器：没有射线数据\n"
			return stats
		)
		
		if graphicsWindow == undefined then
		(
			format "预览渲染器：图形窗口无效\n"
			stats.hasErrors = true
			return stats
		)
		
		stats.totalRays = rayArray.count
		
		-- 设置绘制颜色
		try (
			graphicsWindow.setColor #line alignmentPreviewColor
		) catch (
			format "预览渲染器：无法设置绘制颜色\n"
			stats.hasErrors = true
		)
		
		-- 性能限制
		local maxRays = 100
		local rayCount = amin #(rayArray.count, maxRays)
		
		-- 收集所有线段数据
		local allLines = #()
		local validRayCount = 0
		
		for i = 1 to rayCount do
		(
			local rayData = rayArray[i]
			if rayData != undefined then
			(
				try (
					local startPt = rayData.startPoint
					local endPt = rayData.endPoint
					
					-- 验证点的有效性
					if startPt != undefined and endPt != undefined and 
					   classOf startPt == Point3 and classOf endPt == Point3 then
					(
						-- 添加主射线
						append allLines #(startPt, endPt)
						validRayCount += 1
						
						-- 添加箭头几何体
						local arrowLines = createArrowGeometry startPt endPt 2.0
						for arrowLine in arrowLines do
						(
							append allLines arrowLine
						)
					)
				) catch (
					-- 单个射线处理失败时继续
					stats.hasErrors = true
					continue
				)
			)
		)
		
		stats.validRays = validRayCount
		
		-- 批量绘制所有线段
		local drawnCount = 0
		local batchSize = 50 -- 每批绘制50条线段
		
		for i = 1 to allLines.count by batchSize do
		(
			local endIndex = amin #(i + batchSize - 1, allLines.count)
			
			-- 绘制当前批次
			for j = i to endIndex do
			(
				try (
					graphicsWindow.polyline allLines[j] false
					drawnCount += 1
				) catch (
					-- 单条线段绘制失败时继续
					stats.hasErrors = true
					continue
				)
			)
			
			-- 每批次后短暂暂停，避免阻塞UI
			if endIndex < allLines.count then
				windows.processPostedMessages()
		)
		
		stats.drawnLines = drawnCount
		
		-- 更新显示
		try (
			graphicsWindow.enlargeUpdateRect #whole
			graphicsWindow.updateScreen()
		) catch (
			-- 更新失败时使用备用方法
			try (
				redrawViews()
			) catch (
				format "预览渲染器：无法更新显示\n"
				stats.hasErrors = true
			)
		)
		
		-- 计算渲染时间
		stats.renderTime = (timestamp() - startTime) / 1000.0
		
		-- 显示统计信息
		if validRayCount > 0 then
		(
			if rayArray.count > maxRays then
				format "预览渲染器：显示前 % 条射线（共 % 条），绘制 % 条线段，耗时 %.3f 秒\n" maxRays rayArray.count drawnCount stats.renderTime
			else
				format "预览渲染器：显示 % 条射线，绘制 % 条线段，耗时 %.3f 秒\n" validRayCount drawnCount stats.renderTime
		)
		
		return stats
		
	) catch (
		format "预览渲染器：批量渲染失败: %\n" (getCurrentException())
		stats.hasErrors = true
		stats.renderTime = (timestamp() - startTime) / 1000.0
		return stats
	)
)

-- 主绘制函数（重构版，使用新的预览渲染器）
function drawAlignmentRays =
(
	try (
		-- 检查预览数据是否存在
		if not isPreviewActive or previewRays == undefined or previewRays.count == 0 then 
		(
			return ok
		)
		
		-- 使用图形窗口管理器获取GW
		local gwContext = getGraphicsWindow()
		if not gwContext.isValid then
		(
			-- 使用回调错误处理
			handleCallbackError "无法获取Graphics Window"
			return ok
		)
		
		-- 使用新的批量渲染器
		local renderStats = renderRayBatch previewRays gwContext.gw
		
		-- 检查渲染结果
		if renderStats.hasErrors then
		(
			handleCallbackError "渲染过程中出现错误"
		)
		
		return ok
		
	) catch (
		local errorMsg = "射线预览绘制失败: " + (getCurrentException() as string)
		format "错误：%\n" errorMsg
		handleCallbackError errorMsg
		return ok
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
)

-- 批量渲染射线
function renderRayBatch rayArray graphicsWindow =
(
	local stats = RenderStats totalRays:0 validRays:0 drawnLines:0 renderTime:0.0 hasErrors:false
	local startTime = timestamp()
	
	try (
		-- 输入验证
		if rayArray == undefined or rayArray.count == 0 then
		(
			format "预览渲染器：没有射线数据\n"
			return stats
		)
		
		if graphicsWindow == undefined then
		(
			format "预览渲染器：图形窗口无效\n"
			stats.hasErrors = true
			return stats
		)
		
		stats.totalRays = rayArray.count
		
		-- 设置绘制颜色
		try (
			graphicsWindow.setColor #line alignmentPreviewColor
		) catch (
			format "预览渲染器：无法设置绘制颜色\n"
			stats.hasErrors = true
		)
		
		-- 性能限制
		local maxRays = 100
		local rayCount = amin #(rayArray.count, maxRays)
		
		-- 收集所有线段数据
		local allLines = #()
		local validRayCount = 0
		
		for i = 1 to rayCount do
		(
			local rayData = rayArray[i]
			if rayData != undefined then
			(
				try (
					local startPt = rayData.startPoint
					local endPt = rayData.endPoint
					
					-- 验证点的有效性
					if startPt != undefined and endPt != undefined and 
					   classOf startPt == Point3 and classOf endPt == Point3 then
					(
						-- 添加主射线
						append allLines #(startPt, endPt)
						validRayCount += 1
						
						-- 添加箭头几何体
						local arrowLines = createArrowGeometry startPt endPt 2.0
						for arrowLine in arrowLines do
						(
							append allLines arrowLine
						)
					)
				) catch (
					-- 单个射线处理失败时继续
					stats.hasErrors = true
					continue
				)
			)
		)
		
		stats.validRays = validRayCount
		
		-- 批量绘制所有线段
		local drawnCount = 0
		local batchSize = 50 -- 每批绘制50条线段
		
		for i = 1 to allLines.count by batchSize do
		(
			local endIndex = amin #(i + batchSize - 1, allLines.count)
			
			-- 绘制当前批次
			for j = i to endIndex do
			(
				try (
					graphicsWindow.polyline allLines[j] false
					drawnCount += 1
				) catch (
					-- 单条线段绘制失败时继续
					stats.hasErrors = true
					continue
				)
			)
			
			-- 每批次后短暂暂停，避免阻塞UI
			if endIndex < allLines.count then
				windows.processPostedMessages()
		)
		
		stats.drawnLines = drawnCount
		
		-- 更新显示
		try (
			graphicsWindow.enlargeUpdateRect #whole
			graphicsWindow.updateScreen()
		) catch (
			-- 更新失败时使用备用方法
			try (
				redrawViews()
			) catch (
				format "预览渲染器：无法更新显示\n"
				stats.hasErrors = true
			)
		)
		
		-- 计算渲染时间
		stats.renderTime = (timestamp() - startTime) / 1000.0
		
		-- 显示统计信息
		if validRayCount > 0 then
		(
			if rayArray.count > maxRays then
				format "预览渲染器：显示前 % 条射线（共 % 条），绘制 % 条线段，耗时 %.3f 秒\n" maxRays rayArray.count drawnCount stats.renderTime
			else
				format "预览渲染器：显示 % 条射线，绘制 % 条线段，耗时 %.3f 秒\n" validRayCount drawnCount stats.renderTime
		)
		
		return stats
		
	) catch (
		format "预览渲染器：批量渲染失败: %\n" (getCurrentException())
		stats.hasErrors = true
		stats.renderTime = (timestamp() - startTime) / 1000.0
		return stats
	)
)

-- 主绘制函数（重构版，使用新的预览渲染器）
function drawAlignmentRays =
(
	try (
		-- 检查预览数据是否存在
		if not isPreviewActive or previewRays == undefined or previewRays.count == 0 then 
		(
			return ok
		)
		
		-- 使用图形窗口管理器获取GW
		local gwContext = getGraphicsWindow()
		if not gwContext.isValid then
		(
			-- 使用回调错误处理
			handleCallbackError "无法获取Graphics Window"
			return ok
		)
		
		-- 使用新的批量渲染器
		local renderStats = renderRayBatch previewRays gwContext.gw
		
		-- 检查渲染结果
		if renderStats.hasErrors then
		(
			handleCallbackError "渲染过程中出现错误"
		)
		
		return ok
		
	) catch (
		local errorMsg = "射线预览绘制失败: " + (getCurrentException() as string)
		format "错误：%\n" errorMsg
		handleCallbackError errorMsg
		return ok
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
)

-- 批量渲染射线
function renderRayBatch rayArray graphicsWindow =
(
	local stats = RenderStats totalRays:0 validRays:0 drawnLines:0 renderTime:0.0 hasErrors:false
	local startTime = timestamp()
	
	try (
		-- 输入验证
		if rayArray == undefined or rayArray.count == 0 then
		(
			format "预览渲染器：没有射线数据\n"
			return stats
		)
		
		if graphicsWindow == undefined then
		(
			format "预览渲染器：图形窗口无效\n"
			stats.hasErrors = true
			return stats
		)
		
		stats.totalRays = rayArray.count
		
		-- 设置绘制颜色
		try (
			graphicsWindow.setColor #line alignmentPreviewColor
		) catch (
			format "预览渲染器：无法设置绘制颜色\n"
			stats.hasErrors = true
		)
		
		-- 性能限制
		local maxRays = 100
		local rayCount = amin #(rayArray.count, maxRays)
		
		-- 收集所有线段数据
		local allLines = #()
		local validRayCount = 0
		
		for i = 1 to rayCount do
		(
			local rayData = rayArray[i]
			if rayData != undefined then
			(
				try (
					local startPt = rayData.startPoint
					local endPt = rayData.endPoint
					
					-- 验证点的有效性
					if startPt != undefined and endPt != undefined and 
					   classOf startPt == Point3 and classOf endPt == Point3 then
					(
						-- 添加主射线
						append allLines #(startPt, endPt)
						validRayCount += 1
						
						-- 添加箭头几何体
						local arrowLines = createArrowGeometry startPt endPt 2.0
						for arrowLine in arrowLines do
						(
							append allLines arrowLine
						)
					)
				) catch (
					-- 单个射线处理失败时继续
					stats.hasErrors = true
					continue
				)
			)
		)
		
		stats.validRays = validRayCount
		
		-- 批量绘制所有线段
		local drawnCount = 0
		local batchSize = 50 -- 每批绘制50条线段
		
		for i = 1 to allLines.count by batchSize do
		(
			local endIndex = amin #(i + batchSize - 1, allLines.count)
			
			-- 绘制当前批次
			for j = i to endIndex do
			(
				try (
					graphicsWindow.polyline allLines[j] false
					drawnCount += 1
				) catch (
					-- 单条线段绘制失败时继续
					stats.hasErrors = true
					continue
				)
			)
			
			-- 每批次后短暂暂停，避免阻塞UI
			if endIndex < allLines.count then
				windows.processPostedMessages()
		)
		
		stats.drawnLines = drawnCount
		
		-- 更新显示
		try (
			graphicsWindow.enlargeUpdateRect #whole
			graphicsWindow.updateScreen()
		) catch (
			-- 更新失败时使用备用方法
			try (
				redrawViews()
			) catch (
				format "预览渲染器：无法更新显示\n"
				stats.hasErrors = true
			)
		)
		
		-- 计算渲染时间
		stats.renderTime = (timestamp() - startTime) / 1000.0
		
		-- 显示统计信息
		if validRayCount > 0 then
		(
			if rayArray.count > maxRays then
				format "预览渲染器：显示前 % 条射线（共 % 条），绘制 % 条线段，耗时 %.3f 秒\n" maxRays rayArray.count drawnCount stats.renderTime
			else
				format "预览渲染器：显示 % 条射线，绘制 % 条线段，耗时 %.3f 秒\n" validRayCount drawnCount stats.renderTime
		)
		
		return stats
		
	) catch (
		format "预览渲染器：批量渲染失败: %\n" (getCurrentException())
		stats.hasErrors = true
		stats.renderTime = (timestamp() - startTime) / 1000.0
		return stats
	)
)

-- 主绘制函数（重构版，使用新的预览渲染器）
function drawAlignmentRays =
(
	try (
		-- 检查预览数据是否存在
		if not isPreviewActive or previewRays == undefined or previewRays.count == 0 then 
		(
			return ok
		)
		
		-- 使用图形窗口管理器获取GW
		local gwContext = getGraphicsWindow()
		if not gwContext.isValid then
		(
			-- 使用回调错误处理
			handleCallbackError "无法获取Graphics Window"
			return ok
		)
		
		-- 使用新的批量渲染器
		local renderStats = renderRayBatch previewRays gwContext.gw
		
		-- 检查渲染结果
		if renderStats.hasErrors then
		(
			handleCallbackError "渲染过程中出现错误"
		)
		
		return ok
		
	) catch (
		local errorMsg = "射线预览绘制失败: " + (getCurrentException() as string)
		format "错误：%\n" errorMsg
		handleCallbackError errorMsg
		return ok
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
)

-- 批量渲染射线
function renderRayBatch rayArray graphicsWindow =
(
	local stats = RenderStats totalRays:0 validRays:0 drawnLines:0 renderTime:0.0 hasErrors:false
	local startTime = timestamp()
	
	try (
		-- 输入验证
		if rayArray == undefined or rayArray.count == 0 then
		(
			format "预览渲染器：没有射线数据\n"
			return stats
		)
		
		if graphicsWindow == undefined then
		(
			format "预览渲染器：图形窗口无效\n"
			stats.hasErrors = true
			return stats
		)
		
		stats.totalRays = rayArray.count
		
		-- 设置绘制颜色
		try (
			graphicsWindow.setColor #line alignmentPreviewColor
		) catch (
			format "预览渲染器：无法设置绘制颜色\n"
			stats.hasErrors = true
		)
		
		-- 性能限制
		local maxRays = 100
		local rayCount = amin #(rayArray.count, maxRays)
		
		-- 收集所有线段数据
		local allLines = #()
		local validRayCount = 0
		
		for i = 1 to rayCount do
		(
			local rayData = rayArray[i]
			if rayData != undefined then
			(
				try (
					local startPt = rayData.startPoint
					local endPt = rayData.endPoint
					
					-- 验证点的有效性
					if startPt != undefined and endPt != undefined and 
					   classOf startPt == Point3 and classOf endPt == Point3 then
					(
						-- 添加主射线
						append allLines #(startPt, endPt)
						validRayCount += 1
						
						-- 添加箭头几何体
						local arrowLines = createArrowGeometry startPt endPt 2.0
						for arrowLine in arrowLines do
						(
							append allLines arrowLine
						)
					)
				) catch (
					-- 单个射线处理失败时继续
					stats.hasErrors = true
					continue
				)
			)
		)
		
		stats.validRays = validRayCount
		
		-- 批量绘制所有线段
		local drawnCount = 0
		local batchSize = 50 -- 每批绘制50条线段
		
		for i = 1 to allLines.count by batchSize do
		(
			local endIndex = amin #(i + batchSize - 1, allLines.count)
			
			-- 绘制当前批次
			for j = i to endIndex do
			(
				try (
					graphicsWindow.polyline allLines[j] false
					drawnCount += 1
				) catch (
					-- 单条线段绘制失败时继续
					stats.hasErrors = true
					continue
				)
			)
			
			-- 每批次后短暂暂停，避免阻塞UI
			if endIndex < allLines.count then
				windows.processPostedMessages()
		)
		
		stats.drawnLines = drawnCount
		
		-- 更新显示
		try (
			graphicsWindow.enlargeUpdateRect #whole
			graphicsWindow.updateScreen()
		) catch (
			-- 更新失败时使用备用方法
			try (
				redrawViews()
			) catch (
				format "预览渲染器：无法更新显示\n"
				stats.hasErrors = true
			)
		)
		
		-- 计算渲染时间
		stats.renderTime = (timestamp() - startTime) / 1000.0
		
		-- 显示统计信息
		if validRayCount > 0 then
		(
			if rayArray.count > maxRays then
				format "预览渲染器：显示前 % 条射线（共 % 条），绘制 % 条线段，耗时 %.3f 秒\n" maxRays rayArray.count drawnCount stats.renderTime
			else
				format "预览渲染器：显示 % 条射线，绘制 % 条线段，耗时 %.3f 秒\n" validRayCount drawnCount stats.renderTime
		)
		
		return stats
		
	) catch (
		format "预览渲染器：批量渲染失败: %\n" (getCurrentException())
		stats.hasErrors = true
		stats.renderTime = (timestamp() - startTime) / 1000.0
		return stats
	)
)

-- 主绘制函数（重构版，使用新的预览渲染器）
function drawAlignmentRays =
(
	try (
		-- 检查预览数据是否存在
		if not isPreviewActive or previewRays == undefined or previewRays.count == 0 then 
		(
			return ok
		)
		
		-- 使用图形窗口管理器获取GW
		local gwContext = getGraphicsWindow()
		if not gwContext.isValid then
		(
			-- 使用回调错误处理
			handleCallbackError "无法获取Graphics Window"
			return ok
		)
		
		-- 使用新的批量渲染器
		local renderStats = renderRayBatch previewRays gwContext.gw
		
		-- 检查渲染结果
		if renderStats.hasErrors then
		(
			handleCallbackError "渲染过程中出现错误"
		)
		
		return ok
		
	) catch (
		local errorMsg = "射线预览绘制失败: " + (getCurrentException() as string)
		format "错误：%\n" errorMsg
		handleCallbackError errorMsg
		return ok
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
)

-- 批量渲染射线
function renderRayBatch rayArray graphicsWindow =
(
	local stats = RenderStats totalRays:0 validRays:0 drawnLines:0 renderTime:0.0 hasErrors:false
	local startTime = timestamp()
	
	try (
		-- 输入验证
		if rayArray == undefined or rayArray.count == 0 then
		(
			format "预览渲染器：没有射线数据\n"
			return stats
		)
		
		if graphicsWindow == undefined then
		(
			format "预览渲染器：图形窗口无效\n"
			stats.hasErrors = true
			return stats
		)
		
		stats.totalRays = rayArray.count
		
		-- 设置绘制颜色
		try (
			graphicsWindow.setColor #line alignmentPreviewColor
		) catch (
			format "预览渲染器：无法设置绘制颜色\n"
			stats.hasErrors = true
		)
		
		-- 性能限制
		local maxRays = 100
		local rayCount = amin #(rayArray.count, maxRays)
		
		-- 收集所有线段数据
		local allLines = #()
		local validRayCount = 0
		
		for i = 1 to rayCount do
		(
			local rayData = rayArray[i]
			if rayData != undefined then
			(
				try (
					local startPt = rayData.startPoint
					local endPt = rayData.endPoint
					
					-- 验证点的有效性
					if startPt != undefined and endPt != undefined and 
					   classOf startPt == Point3 and classOf endPt == Point3 then
					(
						-- 添加主射线
						append allLines #(startPt, endPt)
						validRayCount += 1
						
						-- 添加箭头几何体
						local arrowLines = createArrowGeometry startPt endPt 2.0
						for arrowLine in arrowLines do
						(
							append allLines arrowLine
						)
					)
				) catch (
					-- 单个射线处理失败时继续
					stats.hasErrors = true
					continue
				)
			)
		)
		
		stats.validRays = validRayCount
		
		-- 批量绘制所有线段
		local drawnCount = 0
		local batchSize = 50 -- 每批绘制50条线段
		
		for i = 1 to allLines.count by batchSize do
		(
			local endIndex = amin #(i + batchSize - 1, allLines.count)
			
			-- 绘制当前批次
			for j = i to endIndex do
			(
				try (
					graphicsWindow.polyline allLines[j] false
					drawnCount += 1
				) catch (
					-- 单条线段绘制失败时继续
					stats.hasErrors = true
					continue
				)
			)
			
			-- 每批次后短暂暂停，避免阻塞UI
			if endIndex < allLines.count then
				windows.processPostedMessages()
		)
		
		stats.drawnLines = drawnCount
		
		-- 更新显示
		try (
			graphicsWindow.enlargeUpdateRect #whole
			graphicsWindow.updateScreen()
		) catch (
			-- 更新失败时使用备用方法
			try (
				redrawViews()
			) catch (
				format "预览渲染器：无法更新显示\n"
				stats.hasErrors = true
			)
		)
		
		-- 计算渲染时间
		stats.renderTime = (timestamp() - startTime) / 1000.0
		
		-- 显示统计信息
		if validRayCount > 0 then
		(
			if rayArray.count > maxRays then
				format "预览渲染器：显示前 % 条射线（共 % 条），绘制 % 条线段，耗时 %.3f 秒\n" maxRays rayArray.count drawnCount stats.renderTime
			else
				format "预览渲染器：显示 % 条射线，绘制 % 条线段，耗时 %.3f 秒\n" validRayCount drawnCount stats.renderTime
		)
		
		return stats
		
	) catch (
		format "预览渲染器：批量渲染失败: %\n" (getCurrentException())
		stats.hasErrors = true
		stats.renderTime = (timestamp() - startTime) / 1000.0
		return stats
	)
)

-- 主绘制函数（重构版，使用新的预览渲染器）
function drawAlignmentRays =
(
	try (
		-- 检查预览数据是否存在
		if not isPreviewActive or previewRays == undefined or previewRays.count == 0 then 
		(
			return ok
		)
		
		-- 使用图形窗口管理器获取GW
		local gwContext = getGraphicsWindow()
		if not gwContext.isValid then
		(
			-- 使用回调错误处理
			handleCallbackError "无法获取Graphics Window"
			return ok
		)
		
		-- 使用新的批量渲染器
		local renderStats = renderRayBatch previewRays gwContext.gw
		
		-- 检查渲染结果
		if renderStats.hasErrors then
		(
			handleCallbackError "渲染过程中出现错误"
		)
		
		return ok
		
	) catch (
		local errorMsg = "射线预览绘制失败: " + (getCurrentException() as string)
		format "错误：%\n" errorMsg
		handleCallbackError errorMsg
		return ok
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
)

-- 批量渲染射线
function renderRayBatch rayArray graphicsWindow =
(
	local stats = RenderStats totalRays:0 validRays:0 drawnLines:0 renderTime:0.0 hasErrors:false
	local startTime = timestamp()
	
	try (
		-- 输入验证
		if rayArray == undefined or rayArray.count == 0 then
		(
			format "预览渲染器：没有射线数据\n"
			return stats
		)
		
		if graphicsWindow == undefined then
		(
			format "预览渲染器：图形窗口无效\n"
			stats.hasErrors = true
			return stats
		)
		
		stats.totalRays = rayArray.count
		
		-- 设置绘制颜色
		try (
			graphicsWindow.setColor #line alignmentPreviewColor
		) catch (
			format "预览渲染器：无法设置绘制颜色\n"
			stats.hasErrors = true
		)
		
		-- 性能限制
		local maxRays = 100
		local rayCount = amin #(rayArray.count, maxRays)
		
		-- 收集所有线段数据
		local allLines = #()
		local validRayCount = 0
		
		for i = 1 to rayCount do
		(
			local rayData = rayArray[i]
			if rayData != undefined then
			(
				try (
					local startPt = rayData.startPoint
					local endPt = rayData.endPoint
					
					-- 验证点的有效性
					if startPt != undefined and endPt != undefined and 
					   classOf startPt == Point3 and classOf endPt == Point3 then
					(
						-- 添加主射线
						append allLines #(startPt, endPt)
						validRayCount += 1
						
						-- 添加箭头几何体
						local arrowLines = createArrowGeometry startPt endPt 2.0
						for arrowLine in arrowLines do
						(
							append allLines arrowLine
						)
					)
				) catch (
					-- 单个射线处理失败时继续
					stats.hasErrors = true
					continue
				)
			)
		)
		
		stats.validRays = validRayCount
		
		-- 批量绘制所有线段
		local drawnCount = 0
		local batchSize = 50 -- 每批绘制50条线段
		
		for i = 1 to allLines.count by batchSize do
		(
			local endIndex = amin #(i + batchSize - 1, allLines.count)
			
			-- 绘制当前批次
			for j = i to endIndex do
			(
				try (
					graphicsWindow.polyline allLines[j] false
					drawnCount += 1
				) catch (
					-- 单条线段绘制失败时继续
					stats.hasErrors = true
					continue
				)
			)
			
			-- 每批次后短暂暂停，避免阻塞UI
			if endIndex < allLines.count then
				windows.processPostedMessages()
		)
		
		stats.drawnLines = drawnCount
		
		-- 更新显示
		try (
			graphicsWindow.enlargeUpdateRect #whole
			graphicsWindow.updateScreen()
		) catch (
			-- 更新失败时使用备用方法
			try (
				redrawViews()
			) catch (
				format "预览渲染器：无法更新显示\n"
				stats.hasErrors = true
			)
		)
		
		-- 计算渲染时间
		stats.renderTime = (timestamp() - startTime) / 1000.0
		
		-- 显示统计信息
		if validRayCount > 0 then
		(
			if rayArray.count > maxRays then
				format "预览渲染器：显示前 % 条射线（共 % 条），绘制 % 条线段，耗时 %.3f 秒\n" maxRays rayArray.count drawnCount stats.renderTime
			else
				format "预览渲染器：显示 % 条射线，绘制 % 条线段，耗时 %.3f 秒\n" validRayCount drawnCount stats.renderTime
		)
		
		return stats
		
	) catch (
		format "预览渲染器：批量渲染失败: %\n" (getCurrentException())
		stats.hasErrors = true
		stats.renderTime = (timestamp() - startTime) / 1000.0
		return stats
	)
)

-- 主绘制函数（重构版，使用新的预览渲染器）
function drawAlignmentRays =
(
	try (
		-- 检查预览数据是否存在
		if not isPreviewActive or previewRays == undefined or previewRays.count == 0 then 
		(
			return ok
		)
		
		-- 使用图形窗口管理器获取GW
		local gwContext = getGraphicsWindow()
		if not gwContext.isValid then
		(
			-- 使用回调错误处理
			handleCallbackError "无法获取Graphics Window"
			return ok
		)
		
		-- 使用新的批量渲染器
		local renderStats = renderRayBatch previewRays gwContext.gw
		
		-- 检查渲染结果
		if renderStats.hasErrors then
		(
			handleCallbackError "渲染过程中出现错误"
		)
		
		return ok
		
	) catch (
		local errorMsg = "射线预览绘制失败: " + (getCurrentException() as string)
		format "错误：%\n" errorMsg
		handleCallbackError errorMsg
		return ok
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
)

-- 批量渲染射线
function renderRayBatch rayArray graphicsWindow =
(
	local stats = RenderStats totalRays:0 validRays:0 drawnLines:0 renderTime:0.0 hasErrors:false
	local startTime = timestamp()
	
	try (
		-- 输入验证
		if rayArray == undefined or rayArray.count == 0 then
		(
			format "预览渲染器：没有射线数据\n"
			return stats
		)
		
		if graphicsWindow == undefined then
		(
			format "预览渲染器：图形窗口无效\n"
			stats.hasErrors = true
			return stats
		)
		
		stats.totalRays = rayArray.count
		
		-- 设置绘制颜色
		try (
			graphicsWindow.setColor #line alignmentPreviewColor
		) catch (
			format "预览渲染器：无法设置绘制颜色\n"
			stats.hasErrors = true
		)
		
		-- 性能限制
		local maxRays = 100
		local rayCount = amin #(rayArray.count, maxRays)
		
		-- 收集所有线段数据
		local allLines = #()
		local validRayCount = 0
		
		for i = 1 to rayCount do
		(
			local rayData = rayArray[i]
			if rayData != undefined then
			(
				try (
					local startPt = rayData.startPoint
					local endPt = rayData.endPoint
					
					-- 验证点的有效性
					if startPt != undefined and endPt != undefined and 
					   classOf startPt == Point3 and classOf endPt == Point3 then
					(
						-- 添加主射线
						append allLines #(startPt, endPt)
						validRayCount += 1
						
						-- 添加箭头几何体
						local arrowLines = createArrowGeometry startPt endPt 2.0
						for arrowLine in arrowLines do
						(
							append allLines arrowLine
						)
					)
				) catch (
					-- 单个射线处理失败时继续
					stats.hasErrors = true
					continue
				)
			)
		)
		
		stats.validRays = validRayCount
		
		-- 批量绘制所有线段
		local drawnCount = 0
		local batchSize = 50 -- 每批绘制50条线段
		
		for i = 1 to allLines.count by batchSize do
		(
			local endIndex = amin #(i + batchSize - 1, allLines.count)
			
			-- 绘制当前批次
			for j = i to endIndex do
			(
				try (
					graphicsWindow.polyline allLines[j] false
					drawnCount += 1
				) catch (
					-- 单条线段绘制失败时继续
					stats.hasErrors = true
					continue
				)
			)
			
			-- 每批次后短暂暂停，避免阻塞UI
			if endIndex < allLines.count then
				windows.processPostedMessages()
		)
		
		stats.drawnLines = drawnCount
		
		-- 更新显示
		try (
			graphicsWindow.enlargeUpdateRect #whole
			graphicsWindow.updateScreen()
		) catch (
			-- 更新失败时使用备用方法
			try (
				redrawViews()
			) catch (
				format "预览渲染器：无法更新显示\n"
				stats.hasErrors = true
			)
		)
		
		-- 计算渲染时间
		stats.renderTime = (timestamp() - startTime) / 1000.0
		
		-- 显示统计信息
		if validRayCount > 0 then
		(
			if rayArray.count > maxRays then
				format "预览渲染器：显示前 % 条射线（共 % 条），绘制 % 条线段，耗时 %.3f 秒\n" maxRays rayArray.count drawnCount stats.renderTime
			else
				format "预览渲染器：显示 % 条射线，绘制 % 条线段，耗时 %.3f 秒\n" validRayCount drawnCount stats.renderTime
		)
		
		return stats
		
	) catch (
		format "预览渲染器：批量渲染失败: %\n" (getCurrentException())
		stats.hasErrors = true
		stats.renderTime = (timestamp() - startTime) / 1000.0
		return stats
	)
)

-- 主绘制函数（重构版，使用新的预览渲染器）
function drawAlignmentRays =
(
	try (
		-- 检查预览数据是否存在
		if not isPreviewActive or previewRays == undefined or previewRays.count == 0 then 
		(
			return ok
		)
		
		-- 使用图形窗口管理器获取GW
		local gwContext = getGraphicsWindow()
		if not gwContext.isValid then
		(
			-- 使用回调错误处理
			handleCallbackError "无法获取Graphics Window"
			return ok
		)
		
		-- 使用新的批量渲染器
		local renderStats = renderRayBatch previewRays gwContext.gw
		
		-- 检查渲染结果
		if renderStats.hasErrors then
		(
			handleCallbackError "渲染过程中出现错误"
		)
		
		return ok
		
	) catch (
		local errorMsg = "射线预览绘制失败: " + (getCurrentException() as string)
		format "错误：%\n" errorMsg
		handleCallbackError errorMsg
		return ok
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
)

-- 批量渲染射线
function renderRayBatch rayArray graphicsWindow =
(
	local stats = RenderStats totalRays:0 validRays:0 drawnLines:0 renderTime:0.0 hasErrors:false
	local startTime = timestamp()
	
	try (
		-- 输入验证
		if rayArray == undefined or rayArray.count == 0 then
		(
			format "预览渲染器：没有射线数据\n"
			return stats
		)
		
		if graphicsWindow == undefined then
		(
			format "预览渲染器：图形窗口无效\n"
			stats.hasErrors = true
			return stats
		)
		
		stats.totalRays = rayArray.count
		
		-- 设置绘制颜色
		try (
			graphicsWindow.setColor #line alignmentPreviewColor
		) catch (
			format "预览渲染器：无法设置绘制颜色\n"
			stats.hasErrors = true
		)
		
		-- 性能限制
		local maxRays = 100
		local rayCount = amin #(rayArray.count, maxRays)
		
		-- 收集所有线段数据
		local allLines = #()
		local validRayCount = 0
		
		for i = 1 to rayCount do
		(
			local rayData = rayArray[i]
			if rayData != undefined then
			(
				try (
					local startPt = rayData.startPoint
					local endPt = rayData.endPoint
					
					-- 验证点的有效性
					if startPt != undefined and endPt != undefined and 
					   classOf startPt == Point3 and classOf endPt == Point3 then
					(
						-- 添加主射线
						append allLines #(startPt, endPt)
						validRayCount += 1
						
						-- 添加箭头几何体
						local arrowLines = createArrowGeometry startPt endPt 2.0
						for arrowLine in arrowLines do
						(
							append allLines arrowLine
						)
					)
				) catch (
					-- 单个射线处理失败时继续
					stats.hasErrors = true
					continue
				)
			)
		)
		
		stats.validRays = validRayCount
		
		-- 批量绘制所有线段
		local drawnCount = 0
		local batchSize = 50 -- 每批绘制50条线段
		
		for i = 1 to allLines.count by batchSize do
		(
			local endIndex = amin #(i + batchSize - 1, allLines.count)
			
			-- 绘制当前批次
			for j = i to endIndex do
			(
				try (
					graphicsWindow.polyline allLines[j] false
					drawnCount += 1
				) catch (
					-- 单条线段绘制失败时继续
					stats.hasErrors = true
					continue
				)
			)
			
			-- 每批次后短暂暂停，避免阻塞UI
			if endIndex < allLines.count then
				windows.processPostedMessages()
		)
		
		stats.drawnLines = drawnCount
		
		-- 更新显示
		try (
			graphicsWindow.enlargeUpdateRect #whole
			graphicsWindow.updateScreen()
		) catch (
			-- 更新失败时使用备用方法
			try (
				redrawViews()
			) catch (
				format "预览渲染器：无法更新显示\n"
				stats.hasErrors = true
			)
		)
		
		-- 计算渲染时间
		stats.renderTime = (timestamp() - startTime) / 1000.0
		
		-- 显示统计信息
		if validRayCount > 0 then
		(
			if rayArray.count > maxRays then
				format "预览渲染器：显示前 % 条射线（共 % 条），绘制 % 条线段，耗时 %.3f 秒\n" maxRays rayArray.count drawnCount stats.renderTime
			else
				format "预览渲染器：显示 % 条射线，绘制 % 条线段，耗时 %.3f 秒\n" validRayCount drawnCount stats.renderTime
		)
		
		return stats
		
	) catch (
		format "预览渲染器：批量渲染失败: %\n" (getCurrentException())
		stats.hasErrors = true
		stats.renderTime = (timestamp() - startTime) / 1000.0
		return stats
	)
)

-- 主绘制函数（重构版，使用新的预览渲染器）
function drawAlignmentRays =
(
	try (
		-- 检查预览数据是否存在
		if not isPreviewActive or previewRays == undefined or previewRays.count == 0 then 
		(
			return ok
		)
		
		-- 使用图形窗口管理器获取GW
		local gwContext = getGraphicsWindow()
		if not gwContext.isValid then
		(
			-- 使用回调错误处理
			handleCallbackError "无法获取Graphics Window"
			return ok
		)
		
		-- 使用新的批量渲染器
		local renderStats = renderRayBatch previewRays gwContext.gw
		
		-- 检查渲染结果
		if renderStats.hasErrors then
		(
			handleCallbackError "渲染过程中出现错误"
		)
		
		return ok
		
	) catch (
		local errorMsg = "射线预览绘制失败: " + (getCurrentException() as string)
		format "错误：%\n" errorMsg
		handleCallbackError errorMsg
		return ok
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
)

-- 批量渲染射线
function renderRayBatch rayArray graphicsWindow =
(
	local stats = RenderStats totalRays:0 validRays:0 drawnLines:0 renderTime:0.0 hasErrors:false
	local startTime = timestamp()
	
	try (
		-- 输入验证
		if rayArray == undefined or rayArray.count == 0 then
		(
			format "预览渲染器：没有射线数据\n"
			return stats
		)
		
		if graphicsWindow == undefined then
		(
			format "预览渲染器：图形窗口无效\n"
			stats.hasErrors = true
			return stats
		)
		
		stats.totalRays = rayArray.count
		
		-- 设置绘制颜色
		try (
			graphicsWindow.setColor #line alignmentPreviewColor
		) catch (
			format "预览渲染器：无法设置绘制颜色\n"
			stats.hasErrors = true
		)
		
		-- 性能限制
		local maxRays = 100
		local rayCount = amin #(rayArray.count, maxRays)
		
		-- 收集所有线段数据
		local allLines = #()
		local validRayCount = 0
		
		for i = 1 to rayCount do
		(
			local rayData = rayArray[i]
			if rayData != undefined then
			(
				try (
					local startPt = rayData.startPoint
					local endPt = rayData.endPoint
					
					-- 验证点的有效性
					if startPt != undefined and endPt != undefined and 
					   classOf startPt == Point3 and classOf endPt == Point3 then
					(
						-- 添加主射线
						append allLines #(startPt, endPt)
						validRayCount += 1
						
						-- 添加箭头几何体
						local arrowLines = createArrowGeometry startPt endPt 2.0
						for arrowLine in arrowLines do
						(
							append allLines arrowLine
						)
					)
				) catch (
					-- 单个射线处理失败时继续
					stats.hasErrors = true
					continue
				)
			)
		)
		
		stats.validRays = validRayCount
		
		-- 批量绘制所有线段
		local drawnCount = 0
		local batchSize = 50 -- 每批绘制50条线段
		
		for i = 1 to allLines.count by batchSize do
		(
			local endIndex = amin #(i + batchSize - 1, allLines.count)
			
			-- 绘制当前批次
			for j = i to endIndex do
			(
				try (
					graphicsWindow.polyline allLines[j] false
					drawnCount += 1
				) catch (
					-- 单条线段绘制失败时继续
					stats.hasErrors = true
					continue
				)
			)
			
			-- 每批次后短暂暂停，避免阻塞UI
			if endIndex < allLines.count then
				windows.processPostedMessages()
		)
		
		stats.drawnLines = drawnCount
		
		-- 更新显示
		try (
			graphicsWindow.enlargeUpdateRect #whole
			graphicsWindow.updateScreen()
		) catch (
			-- 更新失败时使用备用方法
			try (
				redrawViews()
			) catch (
				format "预览渲染器：无法更新显示\n"
				stats.hasErrors = true
			)
		)
		
		-- 计算渲染时间
		stats.renderTime = (timestamp() - startTime) / 1000.0
		
		-- 显示统计信息
		if validRayCount > 0 then
		(
			if rayArray.count > maxRays then
				format "预览渲染器：显示前 % 条射线（共 % 条），绘制 % 条线段，耗时 %.3f 秒\n" maxRays rayArray.count drawnCount stats.renderTime
			else
				format "预览渲染器：显示 % 条射线，绘制 % 条线段，耗时 %.3f 秒\n" validRayCount drawnCount stats.renderTime
		)
		
		return stats
		
	) catch (
		format "预览渲染器：批量渲染失败: %\n" (getCurrentException())
		stats.hasErrors = true
		stats.renderTime = (timestamp() - startTime) / 1000.0
		return stats
	)
)

-- 主绘制函数（重构版，使用新的预览渲染器）
function drawAlignmentRays =
(
	try (
		-- 检查预览数据是否存在
		if not isPreviewActive or previewRays == undefined or previewRays.count == 0 then 
		(
			return ok
		)
		
		-- 使用图形窗口管理器获取GW
		local gwContext = getGraphicsWindow()
		if not gwContext.isValid then
		(
			-- 使用回调错误处理
			handleCallbackError "无法获取Graphics Window"
			return ok
		)
		
		-- 使用新的批量渲染器
		local renderStats = renderRayBatch previewRays gwContext.gw
		
		-- 检查渲染结果
		if renderStats.hasErrors then
		(
			handleCallbackError "渲染过程中出现错误"
		)
		
		return ok
		
	) catch (
		local errorMsg = "射线预览绘制失败: " + (getCurrentException() as string)
		format "错误：%\n" errorMsg
		handleCallbackError errorMsg
		return ok
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
)

-- 批量渲染射线
function renderRayBatch rayArray graphicsWindow =
(
	local stats = RenderStats totalRays:0 validRays:0 drawnLines:0 renderTime:0.0 hasErrors:false
	local startTime = timestamp()
	
	try (
		-- 输入验证
		if rayArray == undefined or rayArray.count == 0 then
		(
			format "预览渲染器：没有射线数据\n"
			return stats
		)
		
		if graphicsWindow == undefined then
		(
			format "预览渲染器：图形窗口无效\n"
			stats.hasErrors = true
			return stats
		)
		
		stats.totalRays = rayArray.count
		
		-- 设置绘制颜色
		try (
			graphicsWindow.setColor #line alignmentPreviewColor
		) catch (
			format "预览渲染器：无法设置绘制颜色\n"
			stats.hasErrors = true
		)
		
		-- 性能限制
		local maxRays = 100
		local rayCount = amin #(rayArray.count, maxRays)
		
		-- 收集所有线段数据
		local allLines = #()
		local validRayCount = 0
		
		for i = 1 to rayCount do
		(
			local rayData = rayArray[i]
			if rayData != undefined then
			(
				try (
					local startPt = rayData.startPoint
					local endPt = rayData.endPoint
					
					-- 验证点的有效性
					if startPt != undefined and endPt != undefined and 
					   classOf startPt == Point3 and classOf endPt == Point3 then
					(
						-- 添加主射线
						append allLines #(startPt, endPt)
						validRayCount += 1
						
						-- 添加箭头几何体
						local arrowLines = createArrowGeometry startPt endPt 2.0
						for arrowLine in arrowLines do
						(
							append allLines arrowLine
						)
					)
				) catch (
					-- 单个射线处理失败时继续
					stats.hasErrors = true
					continue
				)
			)
		)
		
		stats.validRays = validRayCount
		
		-- 批量绘制所有线段
		local drawnCount = 0
		local batchSize = 50 -- 每批绘制50条线段
		
		for i = 1 to allLines.count by batchSize do
		(
			local endIndex = amin #(i + batchSize - 1, allLines.count)
			
			-- 绘制当前批次
			for j = i to endIndex do
			(
				try (
					graphicsWindow.polyline allLines[j] false
					drawnCount += 1
				) catch (
					-- 单条线段绘制失败时继续
					stats.hasErrors = true
					continue
				)
			)
			
			-- 每批次后短暂暂停，避免阻塞UI
			if endIndex < allLines.count then
				windows.processPostedMessages()
		)
		
		stats.drawnLines = drawnCount
		
		-- 更新显示
		try (
			graphicsWindow.enlargeUpdateRect #whole
			graphicsWindow.updateScreen()
		) catch (
			-- 更新失败时使用备用方法
			try (
				redrawViews()
			) catch (
				format "预览渲染器：无法更新显示\n"
				stats.hasErrors = true
			)
		)
		
		-- 计算渲染时间
		stats.renderTime = (timestamp() - startTime) / 1000.0
		
		-- 显示统计信息
		if validRayCount > 0 then
		(
			if rayArray.count > maxRays then
				format "预览渲染器：显示前 % 条射线（共 % 条），绘制 % 条线段，耗时 %.3f 秒\n" maxRays rayArray.count drawnCount stats.renderTime
			else
				format "预览渲染器：显示 % 条射线，绘制 % 条线段，耗时 %.3f 秒\n" validRayCount drawnCount stats.renderTime
		)
		
		return stats
		
	) catch (
		format "预览渲染器：批量渲染失败: %\n" (getCurrentException())
		stats.hasErrors = true
		stats.renderTime = (timestamp() - startTime) / 1000.0
		return stats
	)
)

-- 主绘制函数（重构版，使用新的预览渲染器）
function drawAlignmentRays =
(
	try (
		-- 检查预览数据是否存在
		if not isPreviewActive or previewRays == undefined or previewRays.count == 0 then 
		(
			return ok
		)
		
		-- 使用图形窗口管理器获取GW
		local gwContext = getGraphicsWindow()
		if not gwContext.isValid then
		(
			-- 使用回调错误处理
			handleCallbackError "无法获取Graphics Window"
			return ok
		)
		
		-- 使用新的批量渲染器
		local renderStats = renderRayBatch previewRays gwContext.gw
		
		-- 检查渲染结果
		if renderStats.hasErrors then
		(
			handleCallbackError "渲染过程中出现错误"
		)
		
		return ok
		
	) catch (
		local errorMsg = "射线预览绘制失败: " + (getCurrentException() as string)
		format "错误：%\n" errorMsg
		handleCallbackError errorMsg
		return ok
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
)

-- 批量渲染射线
function renderRayBatch rayArray graphicsWindow =
(
	local stats = RenderStats totalRays:0 validRays:0 drawnLines:0 renderTime:0.0 hasErrors:false
	local startTime = timestamp()
	
	try (
		-- 输入验证
		if rayArray == undefined or rayArray.count == 0 then
		(
			format "预览渲染器：没有射线数据\n"
			return stats
		)
		
		if graphicsWindow == undefined then
		(
			format "预览渲染器：图形窗口无效\n"
			stats.hasErrors = true
			return stats
		)
		
		stats.totalRays = rayArray.count
		
		-- 设置绘制颜色
		try (
			graphicsWindow.setColor #line alignmentPreviewColor
		) catch (
			format "预览渲染器：无法设置绘制颜色\n"
			stats.hasErrors = true
		)
		
		-- 性能限制
		local maxRays = 100
		local rayCount = amin #(rayArray.count, maxRays)
		
		-- 收集所有线段数据
		local allLines = #()
		local validRayCount = 0
		
		for i = 1 to rayCount do
		(
			local rayData = rayArray[i]
			if rayData != undefined then
			(
				try (
					local startPt = rayData.startPoint
					local endPt = rayData.endPoint
					
					-- 验证点的有效性
					if startPt != undefined and endPt != undefined and 
					   classOf startPt == Point3 and classOf endPt == Point3 then
					(
						-- 添加主射线
						append allLines #(startPt, endPt)
						validRayCount += 1
						
						-- 添加箭头几何体
						local arrowLines = createArrowGeometry startPt endPt 2.0
						for arrowLine in arrowLines do
						(
							append allLines arrowLine
						)
					)
				) catch (
					-- 单个射线处理失败时继续
					stats.hasErrors = true
					continue
				)
			)
		)
		
		stats.validRays = validRayCount
		
		-- 批量绘制所有线段
		local drawnCount = 0
		local batchSize = 50 -- 每批绘制50条线段
		
		for i = 1 to allLines.count by batchSize do
		(
			local endIndex = amin #(i + batchSize - 1, allLines.count)
			
			-- 绘制当前批次
			for j = i to endIndex do
			(
				try (
					graphicsWindow.polyline allLines[j] false
					drawnCount += 1
				) catch (
					-- 单条线段绘制失败时继续
					stats.hasErrors = true
					continue
				)
			)
			
			-- 每批次后短暂暂停，避免阻塞UI
			if endIndex < allLines.count then
				windows.processPostedMessages()
		)
		
		stats.drawnLines = drawnCount
		
		-- 更新显示
		try (
			graphicsWindow.enlargeUpdateRect #whole
			graphicsWindow.updateScreen()
		) catch (
			-- 更新失败时使用备用方法
			try (
				redrawViews()
			) catch (
				format "预览渲染器：无法更新显示\n"
				stats.hasErrors = true
			)
		)
		
		-- 计算渲染时间
		stats.renderTime = (timestamp() - startTime) / 1000.0
		
		-- 显示统计信息
		if validRayCount > 0 then
		(
			if rayArray.count > maxRays then
				format "预览渲染器：显示前 % 条射线（共 % 条），绘制 % 条线段，耗时 %.3f 秒\n" maxRays rayArray.count drawnCount stats.renderTime
			else
				format "预览渲染器：显示 % 条射线，绘制 % 条线段，耗时 %.3f 秒\n" validRayCount drawnCount stats.renderTime
		)
		
		return stats
		
	) catch (
		format "预览渲染器：批量渲染失败: %\n" (getCurrentException())
		stats.hasErrors = true
		stats.renderTime = (timestamp() - startTime) / 1000.0
		return stats
	)
)

-- 主绘制函数（重构版，使用新的预览渲染器）
function drawAlignmentRays =
(
	try (
		-- 检查预览数据是否存在
		if not isPreviewActive or previewRays == undefined or previewRays.count == 0 then 
		(
			return ok
		)
		
		-- 使用图形窗口管理器获取GW
		local gwContext = getGraphicsWindow()
		if not gwContext.isValid then
		(
			-- 使用回调错误处理
			handleCallbackError "无法获取Graphics Window"
			return ok
		)
		
		-- 使用新的批量渲染器
		local renderStats = renderRayBatch previewRays gwContext.gw
		
		-- 检查渲染结果
		if renderStats.hasErrors then
		(
			handleCallbackError "渲染过程中出现错误"
		)
		
		return ok
		
	) catch (
		local errorMsg = "射线预览绘制失败: " + (getCurrentException() as string)
		format "错误：%\n" errorMsg
		handleCallbackError errorMsg
		return ok
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
)

-- 批量渲染射线
function renderRayBatch rayArray graphicsWindow =
(
	local stats = RenderStats totalRays:0 validRays:0 drawnLines:0 renderTime:0.0 hasErrors:false
	local startTime = timestamp()
	
	try (
		-- 输入验证
		if rayArray == undefined or rayArray.count == 0 then
		(
			format "预览渲染器：没有射线数据\n"
			return stats
		)
		
		if graphicsWindow == undefined then
		(
			format "预览渲染器：图形窗口无效\n"
			stats.hasErrors = true
			return stats
		)
		
		stats.totalRays = rayArray.count
		
		-- 设置绘制颜色
		try (
			graphicsWindow.setColor #line alignmentPreviewColor
		) catch (
			format "预览渲染器：无法设置绘制颜色\n"
			stats.hasErrors = true
		)
		
		-- 性能限制
		local maxRays = 100
		local rayCount = amin #(rayArray.count, maxRays)
		
		-- 收集所有线段数据
		local allLines = #()
		local validRayCount = 0
		
		for i = 1 to rayCount do
		(
			local rayData = rayArray[i]
			if rayData != undefined then
			(
				try (
					local startPt = rayData.startPoint
					local endPt = rayData.endPoint
					
					-- 验证点的有效性
					if startPt != undefined and endPt != undefined and 
					   classOf startPt == Point3 and classOf endPt == Point3 then
					(
						-- 添加主射线
						append allLines #(startPt, endPt)
						validRayCount += 1
						
						-- 添加箭头几何体
						local arrowLines = createArrowGeometry startPt endPt 2.0
						for arrowLine in arrowLines do
						(
							append allLines arrowLine
						)
					)
				) catch (
					-- 单个射线处理失败时继续
					stats.hasErrors = true
					continue
				)
			)
		)
		
		stats.validRays = validRayCount
		
		-- 批量绘制所有线段
		local drawnCount = 0
		local batchSize = 50 -- 每批绘制50条线段
		
		for i = 1 to allLines.count by batchSize do
		(
			local endIndex = amin #(i + batchSize - 1, allLines.count)
			
			-- 绘制当前批次
			for j = i to endIndex do
			(
				try (
					graphicsWindow.polyline allLines[j] false
					drawnCount += 1
				) catch (
					-- 单条线段绘制失败时继续
					stats.hasErrors = true
					continue
				)
			)
			
			-- 每批次后短暂暂停，避免阻塞UI
			if endIndex < allLines.count then
				windows.processPostedMessages()
		)
		
		stats.drawnLines = drawnCount
		
		-- 更新显示
		try (
			graphicsWindow.enlargeUpdateRect #whole
			graphicsWindow.updateScreen()
		) catch (
			-- 更新失败时使用备用方法
			try (
				redrawViews()
			) catch (
				format "预览渲染器：无法更新显示\n"
				stats.hasErrors = true
			)
		)
		
		-- 计算渲染时间
		stats.renderTime = (timestamp() - startTime) / 1000.0
		
		-- 显示统计信息
		if validRayCount > 0 then
		(
			if rayArray.count > maxRays then
				format "预览渲染器：显示前 % 条射线（共 % 条），绘制 % 条线段，耗时 %.3f 秒\n" maxRays rayArray.count drawnCount stats.renderTime
			else
				format "预览渲染器：显示 % 条射线，绘制 % 条线段，耗时 %.3f 秒\n" validRayCount drawnCount stats.renderTime
		)
		
		return stats
		
	) catch (
		format "预览渲染器：批量渲染失败: %\n" (getCurrentException())
		stats.hasErrors = true
		stats.renderTime = (timestamp() - startTime) / 1000.0
		return stats
	)
)

-- 主绘制函数（重构版，使用新的预览渲染器）
function drawAlignmentRays =
(
	try (
		-- 检查预览数据是否存在
		if not isPreviewActive or previewRays == undefined or previewRays.count == 0 then 
		(
			return ok
		)
		
		-- 使用图形窗口管理器获取GW
		local gwContext = getGraphicsWindow()
		if not gwContext.isValid then
		(
			-- 使用回调错误处理
			handleCallbackError "无法获取Graphics Window"
			return ok
		)
		
		-- 使用新的批量渲染器
		local renderStats = renderRayBatch previewRays gwContext.gw
		
		-- 检查渲染结果
		if renderStats.hasErrors then
		(
			handleCallbackError "渲染过程中出现错误"
		)
		
		return ok
		
	) catch (
		local errorMsg = "射线预览绘制失败: " + (getCurrentException() as string)
		format "错误：%\n" errorMsg
		handleCallbackError errorMsg
		return ok
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
)

-- 批量渲染射线
function renderRayBatch rayArray graphicsWindow =
(
	local stats = RenderStats totalRays:0 validRays:0 drawnLines:0 renderTime:0.0 hasErrors:false
	local startTime = timestamp()
	
	try (
		-- 输入验证
		if rayArray == undefined or rayArray.count == 0 then
		(
			format "预览渲染器：没有射线数据\n"
			return stats
		)
		
		if graphicsWindow == undefined then
		(
			format "预览渲染器：图形窗口无效\n"
			stats.hasErrors = true
			return stats
		)
		
		stats.totalRays = rayArray.count
		
		-- 设置绘制颜色
		try (
			graphicsWindow.setColor #line alignmentPreviewColor
		) catch (
			format "预览渲染器：无法设置绘制颜色\n"
			stats.hasErrors = true
		)
		
		-- 性能限制
		local maxRays = 100
		local rayCount = amin #(rayArray.count, maxRays)
		
		-- 收集所有线段数据
		local allLines = #()
		local validRayCount = 0
		
		for i = 1 to rayCount do
		(
			local rayData = rayArray[i]
			if rayData != undefined then
			(
				try (
					local startPt = rayData.startPoint
					local endPt = rayData.endPoint
					
					-- 验证点的有效性
					if startPt != undefined and endPt != undefined and 
					   classOf startPt == Point3 and classOf endPt == Point3 then
					(
						-- 添加主射线
						append allLines #(startPt, endPt)
						validRayCount += 1
						
						-- 添加箭头几何体
						local arrowLines = createArrowGeometry startPt endPt 2.0
						for arrowLine in arrowLines do
						(
							append allLines arrowLine
						)
					)
				) catch (
					-- 单个射线处理失败时继续
					stats.hasErrors = true
					continue
				)
			)
		)
		
		stats.validRays = validRayCount
		
		-- 批量绘制所有线段
		local drawnCount = 0
		local batchSize = 50 -- 每批绘制50条线段
		
		for i = 1 to allLines.count by batchSize do
		(
			local endIndex = amin #(i + batchSize - 1, allLines.count)
			
			-- 绘制当前批次
			for j = i to endIndex do
			(
				try (
					graphicsWindow.polyline allLines[j] false
					drawnCount += 1
				) catch (
					-- 单条线段绘制失败时继续
					stats.hasErrors = true
					continue
				)
			)
			
			-- 每批次后短暂暂停，避免阻塞UI
			if endIndex < allLines.count then
				windows.processPostedMessages()
		)
		
		stats.drawnLines = drawnCount
		
		-- 更新显示
		try (
			graphicsWindow.enlargeUpdateRect #whole
			graphicsWindow.updateScreen()
		) catch (
			-- 更新失败时使用备用方法
			try (
				redrawViews()
			) catch (
				format "预览渲染器：无法更新显示\n"
				stats.hasErrors = true
			)
		)
		
		-- 计算渲染时间
		stats.renderTime = (timestamp() - startTime) / 1000.0
		
		-- 显示统计信息
		if validRayCount > 0 then
		(
			if rayArray.count > maxRays then
				format "预览渲染器：显示前 % 条射线（共 % 条），绘制 % 条线段，耗时 %.3f 秒\n" maxRays rayArray.count drawnCount stats.renderTime
			else
				format "预览渲染器：显示 % 条射线，绘制 % 条线段，耗时 %.3f 秒\n" validRayCount drawnCount stats.renderTime
		)
		
		return stats
		
	) catch (
		format "预览渲染器：批量渲染失败: %\n" (getCurrentException())
		stats.hasErrors = true
		stats.renderTime = (timestamp() - startTime) / 1000.0
		return stats
	)
)

-- 主绘制函数（重构版，使用新的预览渲染器）
function drawAlignmentRays =
(
	try (
		-- 检查预览数据是否存在
		if not isPreviewActive or previewRays == undefined or previewRays.count == 0 then 
		(
			return ok
		)
		
		-- 使用图形窗口管理器获取GW
		local gwContext = getGraphicsWindow()
		if not gwContext.isValid then
		(
			-- 使用回调错误处理
			handleCallbackError "无法获取Graphics Window"
			return ok
		)
		
		-- 使用新的批量渲染器
		local renderStats = renderRayBatch previewRays gwContext.gw
		
		-- 检查渲染结果
		if renderStats.hasErrors then
		(
			handleCallbackError "渲染过程中出现错误"
		)
		
		return ok
		
	) catch (
		local errorMsg = "射线预览绘制失败: " + (getCurrentException() as string)
		format "错误：%\n" errorMsg
		handleCallbackError errorMsg
		return ok
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
)

-- 批量渲染射线
function renderRayBatch rayArray graphicsWindow =
(
	local stats = RenderStats totalRays:0 validRays:0 drawnLines:0 renderTime:0.0 hasErrors:false
	local startTime = timestamp()
	
	try (
		-- 输入验证
		if rayArray == undefined or rayArray.count == 0 then
		(
			format "预览渲染器：没有射线数据\n"
			return stats
		)
		
		if graphicsWindow == undefined then
		(
			format "预览渲染器：图形窗口无效\n"
			stats.hasErrors = true
			return stats
		)
		
		stats.totalRays = rayArray.count
		
		-- 设置绘制颜色
		try (
			graphicsWindow.setColor #line alignmentPreviewColor
		) catch (
			format "预览渲染器：无法设置绘制颜色\n"
			stats.hasErrors = true
		)
		
		-- 性能限制
		local maxRays = 100
		local rayCount = amin #(rayArray.count, maxRays)
		
		-- 收集所有线段数据
		local allLines = #()
		local validRayCount = 0
		
		for i = 1 to rayCount do
		(
			local rayData = rayArray[i]
			if rayData != undefined then
			(
				try (
					local startPt = rayData.startPoint
					local endPt = rayData.endPoint
					
					-- 验证点的有效性
					if startPt != undefined and endPt != undefined and 
					   classOf startPt == Point3 and classOf endPt == Point3 then
					(
						-- 添加主射线
						append allLines #(startPt, endPt)
						validRayCount += 1
						
						-- 添加箭头几何体
						local arrowLines = createArrowGeometry startPt endPt 2.0
						for arrowLine in arrowLines do
						(
							append allLines arrowLine
						)
					)
				) catch (
					-- 单个射线处理失败时继续
					stats.hasErrors = true
					continue
				)
			)
		)
		
		stats.validRays = validRayCount
		
		-- 批量绘制所有线段
		local drawnCount = 0
		local batchSize = 50 -- 每批绘制50条线段
		
		for i = 1 to allLines.count by batchSize do
		(
			local endIndex = amin #(i + batchSize - 1, allLines.count)
			
			-- 绘制当前批次
			for j = i to endIndex do
			(
				try (
					graphicsWindow.polyline allLines[j] false
					drawnCount += 1
				) catch (
					-- 单条线段绘制失败时继续
					stats.hasErrors = true
					continue
				)
			)
			
			-- 每批次后短暂暂停，避免阻塞UI
			if endIndex < allLines.count then
				windows.processPostedMessages()
		)
		
		stats.drawnLines = drawnCount
		
		-- 更新显示
		try (
			graphicsWindow.enlargeUpdateRect #whole
			graphicsWindow.updateScreen()
		) catch (
			-- 更新失败时使用备用方法
			try (
				redrawViews()
			) catch (
				format "预览渲染器：无法更新显示\n"
				stats.hasErrors = true
			)
		)
		
		-- 计算渲染时间
		stats.renderTime = (timestamp() - startTime) / 1000.0
		
		-- 显示统计信息
		if validRayCount > 0 then
		(
			if rayArray.count > maxRays then
				format "预览渲染器：显示前 % 条射线（共 % 条），绘制 % 条线段，耗时 %.3f 秒\n" maxRays rayArray.count drawnCount stats.renderTime
			else
				format "预览渲染器：显示 % 条射线，绘制 % 条线段，耗时 %.3f 秒\n" validRayCount drawnCount stats.renderTime
		)
		
		return stats
		
	) catch (
		format "预览渲染器：批量渲染失败: %\n" (getCurrentException())
		stats.hasErrors = true
		stats.renderTime = (timestamp() - startTime) / 1000.0
		return stats
	)
)

-- 主绘制函数（重构版，使用新的预览渲染器）
function drawAlignmentRays =
(
	try (
		-- 检查预览数据是否存在
		if not isPreviewActive or previewRays == undefined or previewRays.count == 0 then 
		(
			return ok
		)
		
		-- 使用图形窗口管理器获取GW
		local gwContext = getGraphicsWindow()
		if not gwContext.isValid then
		(
			-- 使用回调错误处理
			handleCallbackError "无法获取Graphics Window"
			return ok
		)
		
		-- 使用新的批量渲染器
		local renderStats = renderRayBatch previewRays gwContext.gw
		
		-- 检查渲染结果
		if renderStats.hasErrors then
		(
			handleCallbackError "渲染过程中出现错误"
		)
		
		return ok
		
	) catch (
		local errorMsg = "射线预览绘制失败: " + (getCurrentException() as string)
		format "错误：%\n" errorMsg
		handleCallbackError errorMsg
		return ok
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
)

-- 批量渲染射线
function renderRayBatch rayArray graphicsWindow =
(
	local stats = RenderStats totalRays:0 validRays:0 drawnLines:0 renderTime:0.0 hasErrors:false
	local startTime = timestamp()
	
	try (
		-- 输入验证
		if rayArray == undefined or rayArray.count == 0 then
		(
			format "预览渲染器：没有射线数据\n"
			return stats
		)
		
		if graphicsWindow == undefined then
		(
			format "预览渲染器：图形窗口无效\n"
			stats.hasErrors = true
			return stats
		)
		
		stats.totalRays = rayArray.count
		
		-- 设置绘制颜色
		try (
			graphicsWindow.setColor #line alignmentPreviewColor
		) catch (
			format "预览渲染器：无法设置绘制颜色\n"
			stats.hasErrors = true
		)
		
		-- 性能限制
		local maxRays = 100
		local rayCount = amin #(rayArray.count, maxRays)
		
		-- 收集所有线段数据
		local allLines = #()
		local validRayCount = 0
		
		for i = 1 to rayCount do
		(
			local rayData = rayArray[i]
			if rayData != undefined then
			(
				try (
					local startPt = rayData.startPoint
					local endPt = rayData.endPoint
					
					-- 验证点的有效性
					if startPt != undefined and endPt != undefined and 
					   classOf startPt == Point3 and classOf endPt == Point3 then
					(
						-- 添加主射线
						append allLines #(startPt, endPt)
						validRayCount += 1
						
						-- 添加箭头几何体
						local arrowLines = createArrowGeometry startPt endPt 2.0
						for arrowLine in arrowLines do
						(
							append allLines arrowLine
						)
					)
				) catch (
					-- 单个射线处理失败时继续
					stats.hasErrors = true
					continue
				)
			)
		)
		
		stats.validRays = validRayCount
		
		-- 批量绘制所有线段
		local drawnCount = 0
		local batchSize = 50 -- 每批绘制50条线段
		
		for i = 1 to allLines.count by batchSize do
		(
			local endIndex = amin #(i + batchSize - 1, allLines.count)
			
			-- 绘制当前批次
			for j = i to endIndex do
			(
				try (
					graphicsWindow.polyline allLines[j] false
					drawnCount += 1
				) catch (
					-- 单条线段绘制失败时继续
					stats.hasErrors = true
					continue
				)
			)
			
			-- 每批次后短暂暂停，避免阻塞UI
			if endIndex < allLines.count then
				windows.processPostedMessages()
		)
		
		stats.drawnLines = drawnCount
		
		-- 更新显示
		try (
			graphicsWindow.enlargeUpdateRect #whole
			graphicsWindow.updateScreen()
		) catch (
			-- 更新失败时使用备用方法
			try (
				redrawViews()
			) catch (
				format "预览渲染器：无法更新显示\n"
				stats.hasErrors = true
			)
		)
		
		-- 计算渲染时间
		stats.renderTime = (timestamp() - startTime) / 1000.0
		
		-- 显示统计信息
		if validRayCount > 0 then
		(
			if rayArray.count > maxRays then
				format "预览渲染器：显示前 % 条射线（共 % 条），绘制 % 条线段，耗时 %.3f 秒\n" maxRays rayArray.count drawnCount stats.renderTime
			else
				format "预览渲染器：显示 % 条射线，绘制 % 条线段，耗时 %.3f 秒\n" validRayCount drawnCount stats.renderTime
		)
		
		return stats
		
	) catch (
		format "预览渲染器：批量渲染失败: %\n" (getCurrentException())
		stats.hasErrors = true
		stats.renderTime = (timestamp() - startTime) / 1000.0
		return stats
	)
)

-- 主绘制函数（重构版，使用新的预览渲染器）
function drawAlignmentRays =
(
	try (
		-- 检查预览数据是否存在
		if not isPreviewActive or previewRays == undefined or previewRays.count == 0 then 
		(
			return ok
		)
		
		-- 使用图形窗口管理器获取GW
		local gwContext = getGraphicsWindow()
		if not gwContext.isValid then
		(
			-- 使用回调错误处理
			handleCallbackError "无法获取Graphics Window"
			return ok
		)
		
		-- 使用新的批量渲染器
		local renderStats = renderRayBatch previewRays gwContext.gw
		
		-- 检查渲染结果
		if renderStats.hasErrors then
		(
			handleCallbackError "渲染过程中出现错误"
		)
		
		return ok
		
	) catch (
		local errorMsg = "射线预览绘制失败: " + (getCurrentException() as string)
		format "错误：%\n" errorMsg
		handleCallbackError errorMsg
		return ok
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
)

-- 批量渲染射线
function renderRayBatch rayArray graphicsWindow =
(
	local stats = RenderStats totalRays:0 validRays:0 drawnLines:0 renderTime:0.0 hasErrors:false
	local startTime = timestamp()
	
	try (
		-- 输入验证
		if rayArray == undefined or rayArray.count == 0 then
		(
			format "预览渲染器：没有射线数据\n"
			return stats
		)
		
		if graphicsWindow == undefined then
		(
			format "预览渲染器：图形窗口无效\n"
			stats.hasErrors = true
			return stats
		)
		
		stats.totalRays = rayArray.count
		
		-- 设置绘制颜色
		try (
			graphicsWindow.setColor #line alignmentPreviewColor
		) catch (
			format "预览渲染器：无法设置绘制颜色\n"
			stats.hasErrors = true
		)
		
		-- 性能限制
		local maxRays = 100
		local rayCount = amin #(rayArray.count, maxRays)
		
		-- 收集所有线段数据
		local allLines = #()
		local validRayCount = 0
		
		for i = 1 to rayCount do
		(
			local rayData = rayArray[i]
			if rayData != undefined then
			(
				try (
					local startPt = rayData.startPoint
					local endPt = rayData.endPoint
					
					-- 验证点的有效性
					if startPt != undefined and endPt != undefined and 
					   classOf startPt == Point3 and classOf endPt == Point3 then
					(
						-- 添加主射线
						append allLines #(startPt, endPt)
						validRayCount += 1
						
						-- 添加箭头几何体
						local arrowLines = createArrowGeometry startPt endPt 2.0
						for arrowLine in arrowLines do
						(
							append allLines arrowLine
						)
					)
				) catch (
					-- 单个射线处理失败时继续
					stats.hasErrors = true
					continue
				)
			)
		)
		
		stats.validRays = validRayCount
		
		-- 批量绘制所有线段
		local drawnCount = 0
		local batchSize = 50 -- 每批绘制50条线段
		
		for i = 1 to allLines.count by batchSize do
		(
			local endIndex = amin #(i + batchSize - 1, allLines.count)
			
			-- 绘制当前批次
			for j = i to endIndex do
			(
				try (
					graphicsWindow.polyline allLines[j] false
					drawnCount += 1
				) catch (
					-- 单条线段绘制失败时继续
					stats.hasErrors = true
					continue
				)
			)
			
			-- 每批次后短暂暂停，避免阻塞UI
			if endIndex < allLines.count then
				windows.processPostedMessages()
		)
		
		stats.drawnLines = drawnCount
		
		-- 更新显示
		try (
			graphicsWindow.enlargeUpdateRect #whole
			graphicsWindow.updateScreen()
		) catch (
			-- 更新失败时使用备用方法
			try (
				redrawViews()
			) catch (
				format "预览渲染器：无法更新显示\n"
				stats.hasErrors = true
			)
		)
		
		-- 计算渲染时间
		stats.renderTime = (timestamp() - startTime) / 1000.0
		
		-- 显示统计信息
		if validRayCount > 0 then
		(
			if rayArray.count > maxRays then
				format "预览渲染器：显示前 % 条射线（共 % 条），绘制 % 条线段，耗时 %.3f 秒\n" maxRays rayArray.count drawnCount stats.renderTime
			else
				format "预览渲染器：显示 % 条射线，绘制 % 条线段，耗时 %.3f 秒\n" validRayCount drawnCount stats.renderTime
		)
		
		return stats
		
	) catch (
		format "预览渲染器：批量渲染失败: %\n" (getCurrentException())
		stats.hasErrors = true
		stats.renderTime = (timestamp() - startTime) / 1000.0
		return stats
	)
)

-- 主绘制函数（重构版，使用新的预览渲染器）
function drawAlignmentRays =
(
	try (
		-- 检查预览数据是否存在
		if not isPreviewActive or previewRays == undefined or previewRays.count == 0 then 
		(
			return ok
		)
		
		-- 使用图形窗口管理器获取GW
		local gwContext = getGraphicsWindow()
		if not gwContext.isValid then
		(
			-- 使用回调错误处理
			handleCallbackError "无法获取Graphics Window"
			return ok
		)
		
		-- 使用新的批量渲染器
		local renderStats = renderRayBatch previewRays gwContext.gw
		
		-- 检查渲染结果
		if renderStats.hasErrors then
		(
			handleCallbackError "渲染过程中出现错误"
		)
		
		return ok
		
	) catch (
		local errorMsg = "射线预览绘制失败: " + (getCurrentException() as string)
		format "错误：%\n" errorMsg
		handleCallbackError errorMsg
		return ok
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
)

-- 批量渲染射线
function renderRayBatch rayArray graphicsWindow =
(
	local stats = RenderStats totalRays:0 validRays:0 drawnLines:0 renderTime:0.0 hasErrors:false
	local startTime = timestamp()
	
	try (
		-- 输入验证
		if rayArray == undefined or rayArray.count == 0 then
		(
			format "预览渲染器：没有射线数据\n"
			return stats
		)
		
		if graphicsWindow == undefined then
		(
			format "预览渲染器：图形窗口无效\n"
			stats.hasErrors = true
			return stats
		)
		
		stats.totalRays = rayArray.count
		
		-- 设置绘制颜色
		try (
			graphicsWindow.setColor #line alignmentPreviewColor
		) catch (
			format "预览渲染器：无法设置绘制颜色\n"
			stats.hasErrors = true
		)
		
		-- 性能限制
		local maxRays = 100
		local rayCount = amin #(rayArray.count, maxRays)
		
		-- 收集所有线段数据
		local allLines = #()
		local validRayCount = 0
		
		for i = 1 to rayCount do
		(
			local rayData = rayArray[i]
			if rayData != undefined then
			(
				try (
					local startPt = rayData.startPoint
					local endPt = rayData.endPoint
					
					-- 验证点的有效性
					if startPt != undefined and endPt != undefined and 
					   classOf startPt == Point3 and classOf endPt == Point3 then
					(
						-- 添加主射线
						append allLines #(startPt, endPt)
						validRayCount += 1
						
						-- 添加箭头几何体
						local arrowLines = createArrowGeometry startPt endPt 2.0
						for arrowLine in arrowLines do
						(
							append allLines arrowLine
						)
					)
				) catch (
					-- 单个射线处理失败时继续
					stats.hasErrors = true
					continue
				)
			)
		)
		
		stats.validRays = validRayCount
		
		-- 批量绘制所有线段
		local drawnCount = 0
		local batchSize = 50 -- 每批绘制50条线段
		
		for i = 1 to allLines.count by batchSize do
		(
			local endIndex = amin #(i + batchSize - 1, allLines.count)
			
			-- 绘制当前批次
			for j = i to endIndex do
			(
				try (
					graphicsWindow.polyline allLines[j] false
					drawnCount += 1
				) catch (
					-- 单条线段绘制失败时继续
					stats.hasErrors = true
					continue
				)
			)
			
			-- 每批次后短暂暂停，避免阻塞UI
			if endIndex < allLines.count then
				windows.processPostedMessages()
		)
		
		stats.drawnLines = drawnCount
		
		-- 更新显示
		try (
			graphicsWindow.enlargeUpdateRect #whole
			graphicsWindow.updateScreen()
		) catch (
			-- 更新失败时使用备用方法
			try (
				redrawViews()
			) catch (
				format "预览渲染器：无法更新显示\n"
				stats.hasErrors = true
			)
		)
		
		-- 计算渲染时间
		stats.renderTime = (timestamp() - startTime) / 1000.0
		
		-- 显示统计信息
		if validRayCount > 0 then
		(
			if rayArray.count > maxRays then
				format "预览渲染器：显示前 % 条射线（共 % 条），绘制 % 条线段，耗时 %.3f 秒\n" maxRays rayArray.count drawnCount stats.renderTime
			else
				format "预览渲染器：显示 % 条射线，绘制 % 条线段，耗时 %.3f 秒\n" validRayCount drawnCount stats.renderTime
		)
		
		return stats
		
	) catch (
		format "预览渲染器：批量渲染失败: %\n" (getCurrentException())
		stats.hasErrors = true
		stats.renderTime = (timestamp() - startTime) / 1000.0
		return stats
	)
)

-- 主绘制函数（重构版，使用新的预览渲染器）
function drawAlignmentRays =
(
	try (
		-- 检查预览数据是否存在
		if not isPreviewActive or previewRays == undefined or previewRays.count == 0 then 
		(
			return ok
		)
		
		-- 使用图形窗口管理器获取GW
		local gwContext = getGraphicsWindow()
		if not gwContext.isValid then
		(
			-- 使用回调错误处理
			handleCallbackError "无法获取Graphics Window"
			return ok
		)
		
		-- 使用新的批量渲染器
		local renderStats = renderRayBatch previewRays gwContext.gw
		
		-- 检查渲染结果
		if renderStats.hasErrors then
		(
			handleCallbackError "渲染过程中出现错误"
		)
		
		return ok
		
	) catch (
		local errorMsg = "射线预览绘制失败: " + (getCurrentException() as string)
		format "错误：%\n" errorMsg
		handleCallbackError errorMsg
		return ok
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
)

-- 批量渲染射线
function renderRayBatch rayArray graphicsWindow =
(
	local stats = RenderStats totalRays:0 validRays:0 drawnLines:0 renderTime:0.0 hasErrors:false
	local startTime = timestamp()
	
	try (
		-- 输入验证
		if rayArray == undefined or rayArray.count == 0 then
		(
			format "预览渲染器：没有射线数据\n"
			return stats
		)
		
		if graphicsWindow == undefined then
		(
			format "预览渲染器：图形窗口无效\n"
			stats.hasErrors = true
			return stats
		)
		
		stats.totalRays = rayArray.count
		
		-- 设置绘制颜色
		try (
			graphicsWindow.setColor #line alignmentPreviewColor
		) catch (
			format "预览渲染器：无法设置绘制颜色\n"
			stats.hasErrors = true
		)
		
		-- 性能限制
		local maxRays = 100
		local rayCount = amin #(rayArray.count, maxRays)
		
		-- 收集所有线段数据
		local allLines = #()
		local validRayCount = 0
		
		for i = 1 to rayCount do
		(
			local rayData = rayArray[i]
			if rayData != undefined then
			(
				try (
					local startPt = rayData.startPoint
					local endPt = rayData.endPoint
					
					-- 验证点的有效性
					if startPt != undefined and endPt != undefined and 
					   classOf startPt == Point3 and classOf endPt == Point3 then
					(
						-- 添加主射线
						append allLines #(startPt, endPt)
						validRayCount += 1
						
						-- 添加箭头几何体
						local arrowLines = createArrowGeometry startPt endPt 2.0
						for arrowLine in arrowLines do
						(
							append allLines arrowLine
						)
					)
				) catch (
					-- 单个射线处理失败时继续
					stats.hasErrors = true
					continue
				)
			)
		)
		
		stats.validRays = validRayCount
		
		-- 批量绘制所有线段
		local drawnCount = 0
		local batchSize = 50 -- 每批绘制50条线段
		
		for i = 1 to allLines.count by batchSize do
		(
			local endIndex = amin #(i + batchSize - 1, allLines.count)
			
			-- 绘制当前批次
			for j = i to endIndex do
			(
				try (
					graphicsWindow.polyline allLines[j] false
					drawnCount += 1
				) catch (
					-- 单条线段绘制失败时继续
					stats.hasErrors = true
					continue
				)
			)
			
			-- 每批次后短暂暂停，避免阻塞UI
			if endIndex < allLines.count then
				windows.processPostedMessages()
		)
		
		stats.drawnLines = drawnCount
		
		-- 更新显示
		try (
			graphicsWindow.enlargeUpdateRect #whole
			graphicsWindow.updateScreen()
		) catch (
			-- 更新失败时使用备用方法
			try (
				redrawViews()
			) catch (
				format "预览渲染器：无法更新显示\n"
				stats.hasErrors = true
			)
		)
		
		-- 计算渲染时间
		stats.renderTime = (timestamp() - startTime) / 1000.0
		
		-- 显示统计信息
		if validRayCount > 0 then
		(
			if rayArray.count > maxRays then
				format "预览渲染器：显示前 % 条射线（共 % 条），绘制 % 条线段，耗时 %.3f 秒\n" maxRays rayArray.count drawnCount stats.renderTime
			else
				format "预览渲染器：显示 % 条射线，绘制 % 条线段，耗时 %.3f 秒\n" validRayCount drawnCount stats.renderTime
		)
		
		return stats
		
	) catch (
		format "预览渲染器：批量渲染失败: %\n" (getCurrentException())
		stats.hasErrors = true
		stats.renderTime = (timestamp() - startTime) / 1000.0
		return stats
	)
)

-- 主绘制函数（重构版，使用新的预览渲染器）
function drawAlignmentRays =
(
	try (
		-- 检查预览数据是否存在
		if not isPreviewActive or previewRays == undefined or previewRays.count == 0 then 
		(
			return ok
		)
		
		-- 使用图形窗口管理器获取GW
		local gwContext = getGraphicsWindow()
		if not gwContext.isValid then
		(
			-- 使用回调错误处理
			handleCallbackError "无法获取Graphics Window"
			return ok
		)
		
		-- 使用新的批量渲染器
		local renderStats = renderRayBatch previewRays gwContext.gw
		
		-- 检查渲染结果
		if renderStats.hasErrors then
		(
			handleCallbackError "渲染过程中出现错误"
		)
		
		return ok
		
	) catch (
		local errorMsg = "射线预览绘制失败: " + (getCurrentException() as string)
		format "错误：%\n" errorMsg
		handleCallbackError errorMsg
		return ok
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
)

-- 批量渲染射线
function renderRayBatch rayArray graphicsWindow =
(
	local stats = RenderStats totalRays:0 validRays:0 drawnLines:0 renderTime:0.0 hasErrors:false
	local startTime = timestamp()
	
	try (
		-- 输入验证
		if rayArray == undefined or rayArray.count == 0 then
		(
			format "预览渲染器：没有射线数据\n"
			return stats
		)
		
		if graphicsWindow == undefined then
		(
			format "预览渲染器：图形窗口无效\n"
			stats.hasErrors = true
			return stats
		)
		
		stats.totalRays = rayArray.count
		
		-- 设置绘制颜色
		try (
			graphicsWindow.setColor #line alignmentPreviewColor
		) catch (
			format "预览渲染器：无法设置绘制颜色\n"
			stats.hasErrors = true
		)
		
		-- 性能限制
		local maxRays = 100
		local rayCount = amin #(rayArray.count, maxRays)
		
		-- 收集所有线段数据
		local allLines = #()
		local validRayCount = 0
		
		for i = 1 to rayCount do
		(
			local rayData = rayArray[i]
			if rayData != undefined then
			(
				try (
					local startPt = rayData.startPoint
					local endPt = rayData.endPoint
					
					-- 验证点的有效性
					if startPt != undefined and endPt != undefined and 
					   classOf startPt == Point3 and classOf endPt == Point3 then
					(
						-- 添加主射线
						append allLines #(startPt, endPt)
						validRayCount += 1
						
						-- 添加箭头几何体
						local arrowLines = createArrowGeometry startPt endPt 2.0
						for arrowLine in arrowLines do
						(
							append allLines arrowLine
						)
					)
				) catch (
					-- 单个射线处理失败时继续
					stats.hasErrors = true
					continue
				)
			)
		)
		
		stats.validRays = validRayCount
		
		-- 批量绘制所有线段
		local drawnCount = 0
		local batchSize = 50 -- 每批绘制50条线段
		
		for i = 1 to allLines.count by batchSize do
		(
			local endIndex = amin #(i + batchSize - 1, allLines.count)
			
			-- 绘制当前批次
			for j = i to endIndex do
			(
				try (
					graphicsWindow.polyline allLines[j] false
					drawnCount += 1
				) catch (
					-- 单条线段绘制失败时继续
					stats.hasErrors = true
					continue
				)
			)
			
			-- 每批次后短暂暂停，避免阻塞UI
			if endIndex < allLines.count then
				windows.processPostedMessages()
		)
		
		stats.drawnLines = drawnCount
		
		-- 更新显示
		try (
			graphicsWindow.enlargeUpdateRect #whole
			graphicsWindow.updateScreen()
		) catch (
			-- 更新失败时使用备用方法
			try (
				redrawViews()
			) catch (
				format "预览渲染器：无法更新显示\n"
				stats.hasErrors = true
			)
		)
		
		-- 计算渲染时间
		stats.renderTime = (timestamp() - startTime) / 1000.0
		
		-- 显示统计信息
		if validRayCount > 0 then
		(
			if rayArray.count > maxRays then
				format "预览渲染器：显示前 % 条射线（共 % 条），绘制 % 条线段，耗时 %.3f 秒\n" maxRays rayArray.count drawnCount stats.renderTime
			else
				format "预览渲染器：显示 % 条射线，绘制 % 条线段，耗时 %.3f 秒\n" validRayCount drawnCount stats.renderTime
		)
		
		return stats
		
	) catch (
		format "预览渲染器：批量渲染失败: %\n" (getCurrentException())
		stats.hasErrors = true
		stats.renderTime = (timestamp() - startTime) / 1000.0
		return stats
	)
)

-- 主绘制函数（重构版，使用新的预览渲染器）
function drawAlignmentRays =
(
	try (
		-- 检查预览数据是否存在
		if not isPreviewActive or previewRays == undefined or previewRays.count == 0 then 
		(
			return ok
		)
		
		-- 使用图形窗口管理器获取GW
		local gwContext = getGraphicsWindow()
		if not gwContext.isValid then
		(
			-- 使用回调错误处理
			handleCallbackError "无法获取Graphics Window"
			return ok
		)
		
		-- 使用新的批量渲染器
		local renderStats = renderRayBatch previewRays gwContext.gw
		
		-- 检查渲染结果
		if renderStats.hasErrors then
		(
			handleCallbackError "渲染过程中出现错误"
		)
		
		return ok
		
	) catch (
		local errorMsg = "射线预览绘制失败: " + (getCurrentException() as string)
		format "错误：%\n" errorMsg
		handleCallbackError errorMsg
		return ok
	)
) arrowBase - crossVec * arrowSize * 0.3
		
		-- 添加箭头线段
		append arrowLines #(endPoint, arrowPt1)
		append arrowLines #(endPoint, arrowPt2)
		
		-- 添加箭头底部连线（可选，使箭头更明显）
		append arrowLines #(arrowPt1, arrowPt2)
		
		return arrowLines
		
	) catch (
		format "预览渲染器：箭头几何体创建失败\n"
		return arrowLines
	)
)

-- 批量渲染射线
function renderRayBatch rayArray graphicsWindow =
(
	local stats = RenderStats totalRays:0 validRays:0 drawnLines:0 renderTime:0.0 hasErrors:false
	local startTime = timestamp()
	
	try (
		-- 输入验证
		if rayArray == undefined or rayArray.count == 0 then
		(
			format "预览渲染器：没有射线数据\n"
			return stats
		)
		
		if graphicsWindow == undefined then
		(
			format "预览渲染器：图形窗口无效\n"
			stats.hasErrors = true
			return stats
		)
		
		stats.totalRays = rayArray.count
		
		-- 设置绘制颜色
		try (
			graphicsWindow.setColor #line alignmentPreviewColor
		) catch (
			format "预览渲染器：无法设置绘制颜色\n"
			stats.hasErrors = true
		)
		
		-- 性能限制
		local maxRays = 100
		local rayCount = amin #(rayArray.count, maxRays)
		
		-- 收集所有线段数据
		local allLines = #()
		local validRayCount = 0
		
		for i = 1 to rayCount do
		(
			local rayData = rayArray[i]
			if rayData != undefined then
			(
				try (
					local startPt = rayData.startPoint
					local endPt = rayData.endPoint
					
					-- 验证点的有效性
					if startPt != undefined and endPt != undefined and 
					   classOf startPt == Point3 and classOf endPt == Point3 then
					(
						-- 添加主射线
						append allLines #(startPt, endPt)
						validRayCount += 1
						
						-- 添加箭头几何体
						local arrowLines = createArrowGeometry startPt endPt 2.0
						for arrowLine in arrowLines do
						(
							append allLines arrowLine
						)
					)
				) catch (
					-- 单个射线处理失败时继续
					stats.hasErrors = true
					continue
				)
			)
		)
		
		stats.validRays = validRayCount
		
		-- 批量绘制所有线段
		local drawnCount = 0
		local batchSize = 50 -- 每批绘制50条线段
		
		for i = 1 to allLines.count by batchSize do
		(
			local endIndex = amin #(i + batchSize - 1, allLines.count)
			
			-- 绘制当前批次
			for j = i to endIndex do
			(
				try (
					graphicsWindow.polyline allLines[j] false
					drawnCount += 1
				) catch (
					-- 单条线段绘制失败时继续
					stats.hasErrors = true
					continue
				)
			)
			
			-- 每批次后短暂暂停，避免阻塞UI
			if endIndex < allLines.count then
				windows.processPostedMessages()
		)
		
		stats.drawnLines = drawnCount
		
		-- 更新显示
		try (
			graphicsWindow.enlargeUpdateRect #whole
			graphicsWindow.updateScreen()
		) catch (
			-- 更新失败时使用备用方法
			try (
				redrawViews()
			) catch (
				format "预览渲染器：无法更新显示\n"
				stats.hasErrors = true
			)
		)
		
		-- 计算渲染时间
		stats.renderTime = (timestamp() - startTime) / 1000.0
		
		-- 显示统计信息
		if validRayCount > 0 then
		(
			if rayArray.count > maxRays then
				format "预览渲染器：显示前 % 条射线（共 % 条），绘制 % 条线段，耗时 %.3f 秒\n" maxRays rayArray.count drawnCount stats.renderTime
			else
				format "预览渲染器：显示 % 条射线，绘制 % 条线段，耗时 %.3f 秒\n" validRayCount drawnCount stats.renderTime
		)
		
		return stats
		
	) catch (
		format "预览渲染器：批量渲染失败: %\n" (getCurrentException())
		stats.hasErrors = true
		stats.renderTime = (timestamp() - startTime) / 1000.0
		return stats
	)
)

-- 主绘制函数（重构版，使用新的预览渲染器）
function drawAlignmentRays =
(
	try (
		-- 检查预览数据是否存在
		if not isPreviewActive or previewRays == undefined or previewRays.count == 0 then 
		(
			return ok
		)
		
		-- 使用图形窗口管理器获取GW
		local gwContext = getGraphicsWindow()
		if not gwContext.isValid then
		(
			-- 使用回调错误处理
			handleCallbackError "无法获取Graphics Window"
			return ok
		)
		
		-- 使用新的批量渲染器
		local renderStats = renderRayBatch previewRays gwContext.gw
		
		-- 检查渲染结果
		if renderStats.hasErrors then
		(
			handleCallbackError "渲染过程中出现错误"
		)
		
		return ok
		
	) catch (
		local errorMsg = "射线预览绘制失败: " + (getCurrentException() as string)
		format "错误：%\n" errorMsg
		handleCallbackError errorMsg
		return ok
	)
)

-- ========== 回调管理器 (Callback Manager) ==========

-- 回调状态结构
struct CallbackState (
	isRegistered,     -- Boolean: 回调是否已注册
	callbackFunction, -- Function: 回调函数引用
	registrationTime, -- Integer: 注册时间戳
	errorCount        -- Integer: 错误计数
)

-- 全局回调状态
global alignCallbackState = CallbackState isRegistered:false callbackFunction:undefined registrationTime:0 errorCount:0

-- 安全注册预览回调函数
function registerSafeCallback callbackFunction =
(
	try (
		-- 输入验证
		if callbackFunction == undefined then
		(
			format "回调管理器：回调函数不能为空\n"
			return false
		)
		
		-- 先执行完整清理
		if not unregisterSafeCallback() then
		(
			format "回调管理器：清理旧回调失败\n"
		)
		
		-- 验证预览数据
		if previewRays == undefined or previewRays.count == 0 then
		(
			format "回调管理器：没有预览数据，跳过回调注册\n"
			return false
		)
		
		-- 测试回调函数是否可执行
		try (
			-- 执行一次测试调用
			callbackFunction()
		) catch (
			format "回调管理器：回调函数测试失败: %\n" (getCurrentException())
			return false
		)
		
		-- 注册新的回调
		try (
			alignPreviewCallback = callbackFunction
			registerRedrawViewsCallback alignPreviewCallback
			
			-- 更新状态
			alignCallbackState.isRegistered = true
			alignCallbackState.callbackFunction = callbackFunction
			alignCallbackState.registrationTime = timestamp()
			alignCallbackState.errorCount = 0
			isPreviewActive = true
			
			-- 立即刷新一次视图
			try (
				redrawViews()
			) catch (
				format "回调管理器：初始视图刷新失败\n"
			)
			
			format "回调管理器：预览回调已安全注册，显示 % 条射线\n" previewRays.count
			return true
			
		) catch (
			format "回调管理器：回调注册失败: %\n" (getCurrentException())
			-- 注册失败时清理状态
			alignPreviewCallback = undefined
			alignCallbackState.isRegistered = false
			isPreviewActive = false
			return false
		)
		
	) catch (
		format "回调管理器：注册过程发生严重错误: %\n" (getCurrentException())
		return false
	)
)

-- 安全注销预览回调函数
function unregisterSafeCallback =
(
	local success = true
	
	try (
		-- 注销回调（即使回调函数为空也要尝试）
		try (
			if alignPreviewCallback != undefined then
			(
				unregisterRedrawViewsCallback alignPreviewCallback
			)
			-- 也尝试注销可能存在的其他回调引用
			if alignCallbackState.callbackFunction != undefined then
			(
				unregisterRedrawViewsCallback alignCallbackState.callbackFunction
			)
		) catch (
			format "回调管理器：注销回调时出现错误: %\n" (getCurrentException())
			success = false
		)
		
		-- 清理全局变量
		alignPreviewCallback = undefined
		isPreviewActive = false
		
		-- 清理回调状态
		alignCallbackState.isRegistered = false
		alignCallbackState.callbackFunction = undefined
		alignCallbackState.registrationTime = 0
		alignCallbackState.errorCount = 0
		
		-- 清理预览数据
		previewRays = #()
		
		-- 强制完整重绘（使用兼容性方法）
		try (
			forceCompleteRedraw()
		) catch (
			try (
				redrawViews()
			) catch (
				format "回调管理器：视图重绘失败\n"
				success = false
			)
		)
		
		if success then
			format "回调管理器：预览回调已安全注销并清理\n"
		else
			format "回调管理器：回调注销完成，但有部分错误\n"
		
		return success
		
	) catch (
		format "回调管理器：注销过程发生严重错误: %\n" (getCurrentException())
		-- 即使出错也要尝试基本清理
		alignPreviewCallback = undefined
		isPreviewActive = false
		alignCallbackState.isRegistered = false
		return false
	)
)

-- 检查回调状态
function checkCallbackStatus =
(
	try (
		local statusMsg = "回调管理器状态：\n"
		statusMsg += "- 注册状态: " + (if alignCallbackState.isRegistered then "已注册" else "未注册") + "\n"
		statusMsg += "- 预览活动: " + (if isPreviewActive then "是" else "否") + "\n"
		statusMsg += "- 射线数量: " + previewRays.count as string + "\n"
		statusMsg += "- 错误计数: " + alignCallbackState.errorCount as string + "\n"
		
		if alignCallbackState.isRegistered then
		(
			local elapsed = (timestamp() - alignCallbackState.registrationTime) / 1000.0
			statusMsg += "- 运行时间: " + elapsed as string + " 秒\n"
		)
		
		format "%\n" statusMsg
		return alignCallbackState.isRegistered
		
	) catch (
		format "回调管理器：状态检查失败\n"
		return false
	)
)

-- 回调错误处理函数
function handleCallbackError errorMsg =
(
	try (
		alignCallbackState.errorCount += 1
		format "回调管理器：回调执行错误 #%: %\n" alignCallbackState.errorCount errorMsg
		
		-- 如果错误过多，自动注销回调
		if alignCallbackState.errorCount >= 5 then
		(
			format "回调管理器：错误过多，自动注销回调\n"
			unregisterSafeCallback()
		)
		
	) catch (
		format "回调管理器：错误处理失败\n"
	)
)

-- 向后兼容的函数（使用新的安全回调管理器）
function registerPreviewCallback =
(
	return registerSafeCallback drawAlignmentRays
)

function unregisterPreviewCallback =
(
	return unregisterSafeCallback()
)

-- ========== 射线计算器 (Ray Calculator) ==========

-- 增强的射线信息结构
struct RayInfo (
	startPoint,    -- Point3: 射线起点
	endPoint,      -- Point3: 射线终点/交点
	isValid,       -- Boolean: 数据有效性标志
	hasIntersection, -- Boolean: 是否有真实交点
	distance       -- Float: 射线长度
)

-- 验证射线数据的有效性
function validateRayData rayData =
(
	try (
		if rayData == undefined then return false
		if rayData.startPoint == undefined or rayData.endPoint == undefined then return false
		if classOf rayData.startPoint != Point3 or classOf rayData.endPoint != Point3 then return false
		
		-- 检查点是否为有效数值（不是NaN或无穷大）
		local startPt = rayData.startPoint
		local endPt = rayData.endPoint
		
		if not (isValidFloat startPt.x and isValidFloat startPt.y and isValidFloat startPt.z) then return false
		if not (isValidFloat endPt.x and isValidFloat endPt.y and isValidFloat endPt.z) then return false
		
		return true
	) catch (
		return false
	)
)

-- 检查浮点数是否有效（不是NaN或无穷大）
function isValidFloat val =
(
	try (
		if val == undefined then return false
		-- 检查是否为数字
		if classOf val != Float and classOf val != Integer then return false
		-- 检查是否为有限数值
		return (val == val and val != 1.#INF and val != -1.#INF)
	) catch (
		return false
	)
)

-- 改进的单个射线计算函数
function calculateRayToSurface obj targetSurface =
(
	try (
		-- 输入验证
		if not isValidGeometry obj or not isValidGeometry targetSurface then
		(
			return (RayInfo startPoint:undefined endPoint:undefined isValid:false hasIntersection:false distance:0.0)
		)
		
		-- 获取物体边界框
		local objBBox = obj.boundingBox
		if objBBox == undefined then
		(
			return (RayInfo startPoint:undefined endPoint:undefined isValid:false hasIntersection:false distance:0.0)
		)
		
		local pMin = objBBox[1]
		local pMax = objBBox[2]
		
		-- 计算物体中心点
		local centerX = pMin.x + 0.5 * (pMax.x - pMin.x)
		local centerY = pMin.y + 0.5 * (pMax.y - pMin.y)
		
		-- 计算起始高度（目标表面上方）
		local targetBBox = targetSurface.boundingBox
		local surfaceHeight = if targetBBox != undefined then targetBBox[2].z else 0.0
		local objHeight = pMax.z - pMin.z
		local startHeight = surfaceHeight + (amax #(objHeight, 100.0))
		
		local startPoint = [centerX, centerY, startHeight]
		
		-- 验证起始点
		if not (isValidFloat startPoint.x and isValidFloat startPoint.y and isValidFloat startPoint.z) then
		(
			return (RayInfo startPoint:undefined endPoint:undefined isValid:false hasIntersection:false distance:0.0)
		)
		
		-- 创建向下的射线
		local rayC = ray startPoint [0, 0, -1]
		local pSurf = intersectRay targetSurface rayC
		
		local endPoint, hasIntersection
		
		if pSurf != undefined and pSurf.position != undefined then
		(
			endPoint = pSurf.position
			hasIntersection = true
		)
		else
		(
			-- 没有交点时，创建默认的向下射线
			endPoint = startPoint + [0, 0, -200.0]
			hasIntersection = false
		)
		
		-- 计算距离
		local rayDistance = length (endPoint - startPoint)
		
		-- 创建射线信息
		local rayData = RayInfo startPoint:startPoint endPoint:endPoint isValid:true hasIntersection:hasIntersection distance:rayDistance
		
		-- 最终验证
		if validateRayData rayData then
			return rayData
		else
			return (RayInfo startPoint:undefined endPoint:undefined isValid:false hasIntersection:false distance:0.0)
		
	) catch (
		format "射线计算错误: %\n" (getCurrentException())
		return (RayInfo startPoint:undefined endPoint:undefined isValid:false hasIntersection:false distance:0.0)
	)
)

-- 批量射线计算函数（增强版）
function calculateRayBatch objects targetSurface maxCount =
(
	local rayResults = #()
	local processedCount = 0
	local validCount = 0
	local startTime = timestamp()
	
	try (
		-- 输入验证
		if objects == undefined or objects.count == 0 then
		(
			format "射线计算器：没有输入对象\n"
			return rayResults
		)
		
		if not isValidGeometry targetSurface then
		(
			format "射线计算器：目标表面无效\n"
			return rayResults
		)
		
		-- 确定处理数量
		local actualCount = if maxCount != undefined then (amin #(objects.count, maxCount)) else objects.count
		
		-- 进度跟踪（超过50个对象时显示进度）
		local showProgress = (actualCount > 50)
		local progressInterval = 10 -- 每10个对象更新一次进度
		
		if showProgress then
			format "射线计算器：开始批量计算 % 个对象的射线...\n" actualCount
		
		-- 批量处理对象
		for i = 1 to actualCount do
		(
			local obj = objects[i]
			
			-- 验证对象
			if isValidGeometry obj then
			(
				try (
					-- 计算单个射线
					local rayData = calculateRayToSurface obj targetSurface
					
					if rayData != undefined and rayData.isValid then
					(
						append rayResults rayData
						validCount += 1
					)
					
					processedCount += 1
					
					-- 显示进度（每处理10个对象或处理完成时）
					if showProgress and ((mod i progressInterval) == 0 or i == actualCount) then
					(
						local elapsed = (timestamp() - startTime) / 1000.0
						format "射线计算器：已处理 %/% 个对象，有效射线 % 条，耗时 %.2f 秒\n" i actualCount validCount elapsed
					)
					
				) catch (
					-- 单个对象计算失败时继续
					format "射线计算器：对象 % 计算失败\n" obj.name
					continue
				)
			)
			else
			(
				format "射线计算器：跳过无效对象 %\n" (if obj != undefined then obj.name else "未知对象")
			)
		)
		
		-- 最终统计
		local totalTime = (timestamp() - startTime) / 1000.0
		format "射线计算器：批量计算完成，处理 % 个对象，生成 % 条有效射线，总耗时 %.2f 秒\n" processedCount validCount totalTime
		
		return rayResults
		
	) catch (
		format "射线计算器：批量计算发生错误: %\n" (getCurrentException())
		return rayResults
	)
)

-- 计算射线预览数据（使用新的批量计算器）
function calculatePreviewRays targetSurface =
(
	try (
		-- 验证输入参数
		if not isValidGeometry targetSurface then
		(
			format "错误: 目标表面不是有效的几何体\n"
			return false
		)
		
		-- 获取选中的对象
		local selectedObjs = getCurrentSelection()
		if selectedObjs.count == 0 then
		(
			format "错误: 没有选中任何对象\n"
			return false
		)
		
		-- 清空之前的预览数据
		previewRays = #()
		
		-- 性能限制设置
		local maxPreviewObjs = 100 -- 提高限制，因为新的计算器更高效
		
		if selectedObjs.count > maxPreviewObjs then
			format "性能优化: 只预览前 % 个对象（共 % 个）\n" maxPreviewObjs selectedObjs.count
		
		-- 使用新的批量射线计算器
		local rayResults = calculateRayBatch selectedObjs targetSurface maxPreviewObjs
		
		-- 转换为旧格式以保持兼容性
		for rayData in rayResults do
		(
			if rayData.isValid then
			(
				-- 创建兼容的 rayInfo 结构
				local compatRay = rayInfo startPoint:rayData.startPoint endPoint:rayData.endPoint
				append previewRays compatRay
			)
		)
		
		local successCount = previewRays.count
		format "预览计算完成，成功生成 % 条预览射线\n" successCount
		
		return (successCount > 0)
		
	) catch (
		format "计算预览射线时发生错误: %\n" (getCurrentException())
		return false
	)
)

-- ========== 自动清理和资源管理系统 ==========

-- 资源跟踪结构
struct ResourceTracker (
	callbacks = #(),          -- 已注册的回调列表
	dialogs = #(),           -- 已创建的对话框列表
	globalVars = #(),        -- 已创建的全局变量列表
	tempData = #(),          -- 临时数据列表
	systemCallbacks = #(),   -- 系统回调列表
	lastCleanupTime = 0      -- 最后清理时间
)

-- 全局资源跟踪器
global alignResourceTracker = ResourceTracker()

-- 注册资源到跟踪器
function registerResource resourceType resourceRef =
(
	try (
		case resourceType of
		(
			"callback": (
				if findItem alignResourceTracker.callbacks resourceRef == 0 then
					append alignResourceTracker.callbacks resourceRef
			)
			"dialog": (
				if findItem alignResourceTracker.dialogs resourceRef == 0 then
					append alignResourceTracker.dialogs resourceRef
			)
			"globalVar": (
				if findItem alignResourceTracker.globalVars resourceRef == 0 then
					append alignResourceTracker.globalVars resourceRef
			)
			"tempData": (
				if findItem alignResourceTracker.tempData resourceRef == 0 then
					append alignResourceTracker.tempData resourceRef
			)
			"systemCallback": (
				if findItem alignResourceTracker.systemCallbacks resourceRef == 0 then
					append alignResourceTracker.systemCallbacks resourceRef
			)
		)
		
		return true
		
	) catch (
		format "资源管理器：注册资源失败\n"
		return false
	)
)

-- 注销资源从跟踪器
function unregisterResource resourceType resourceRef =
(
	try (
		case resourceType of
		(
			"callback": (
				local index = findItem alignResourceTracker.callbacks resourceRef
				if index > 0 then deleteItem alignResourceTracker.callbacks index
			)
			"dialog": (
				local index = findItem alignResourceTracker.dialogs resourceRef
				if index > 0 then deleteItem alignResourceTracker.dialogs index
			)
			"globalVar": (
				local index = findItem alignResourceTracker.globalVars resourceRef
				if index > 0 then deleteItem alignResourceTracker.globalVars index
			)
			"tempData": (
				local index = findItem alignResourceTracker.tempData resourceRef
				if index > 0 then deleteItem alignResourceTracker.tempData index
			)
			"systemCallback": (
				local index = findItem alignResourceTracker.systemCallbacks resourceRef
				if index > 0 then deleteItem alignResourceTracker.systemCallbacks index
			)
		)
		
		return true
		
	) catch (
		format "资源管理器：注销资源失败\n"
		return false
	)
)

-- 对话框关闭时的清理函数
function cleanupOnDialogClose =
(
	try (
		format "资源管理器：开始对话框关闭清理...\n"
		
		-- 清理预览系统
		if unregisterSafeCallback() then
			format "资源管理器：预览回调已清理\n"
		
		-- 清理状态
		cleanupPreviewState()
		
		-- 清理全局变量
		isAlignmentActive = false
		alignDialogInstance = undefined
		
		-- 清理临时数据
		for tempData in alignResourceTracker.tempData do
		(
			try (
				tempData = undefined
			) catch ()
		)
		alignResourceTracker.tempData = #()
		
		-- 更新清理时间
		alignResourceTracker.lastCleanupTime = timestamp()
		
		format "资源管理器：对话框关闭清理完成\n"
		return true
		
	) catch (
		format "资源管理器：对话框关闭清理失败: %\n" (getCurrentException())
		return false
	)
)

-- 系统事件清理函数
function cleanupOnSystemEvent eventType =
(
	try (
		format "资源管理器：系统事件清理 (%)\n" eventType
		
		-- 强制清理所有回调
		unregisterSafeCallback()
		
		-- 清理所有状态
		cleanupPreviewState()
		
		-- 清理对话框（如果存在）
		for dlg in alignResourceTracker.dialogs do
		(
			try (
				destroyDialog dlg
			) catch ()
		)
		alignResourceTracker.dialogs = #()
		
		-- 重置全局变量
		isAlignmentActive = false
		alignDialogInstance = undefined
		
		-- 清理资源跟踪器
		alignResourceTracker.callbacks = #()
		alignResourceTracker.tempData = #()
		alignResourceTracker.lastCleanupTime = timestamp()
		
		format "资源管理器：系统事件清理完成\n"
		return true
		
	) catch (
		format "资源管理器：系统事件清理失败: %\n" (getCurrentException())
		return false
	)
)

-- 内存泄漏预防机制
function preventMemoryLeaks =
(
	try (
		-- 清理大型数组
		if previewRays != undefined and previewRays.count > 1000 then
		(
			format "资源管理器：清理大型射线数组 (% 条射线)\n" previewRays.count
			previewRays = #()
		)
		
		-- 清理未使用的全局变量
		if alignmentStateManager != undefined then
		(
			if alignmentStateManager.renderStats != undefined then
			(
				-- 清理旧的渲染统计
				local elapsed = (timestamp() - alignmentStateManager.lastUpdateTime) / 1000.0
				if elapsed > 300 then -- 5分钟后清理
				(
					alignmentStateManager.renderStats = undefined
					format "资源管理器：清理旧的渲染统计数据\n"
				)
			)
		)
		
		-- 强制垃圾回收（如果可用）
		try (
			gc()
			format "资源管理器：执行垃圾回收\n"
		) catch ()
		
		return true
		
	) catch (
		format "资源管理器：内存泄漏预防失败\n"
		return false
	)
)

-- 完整的系统清理函数
function cleanupAlignment =
(
	try (
		format "资源管理器：开始完整系统清理...\n"
		
		-- 清理预览系统
		unregisterSafeCallback()
		cleanupPreviewState()
		
		-- 清理对话框
		if alignDialogInstance != undefined then
		(
			try (
				destroyDialog alignDialogInstance
				unregisterResource "dialog" alignDialogInstance
			) catch ()
			alignDialogInstance = undefined
		)
		
		-- 清理所有跟踪的对话框
		for dlg in alignResourceTracker.dialogs do
		(
			try (destroyDialog dlg) catch ()
		)
		alignResourceTracker.dialogs = #()
		
		-- 重置状态变量
		isAlignmentActive = false
		
		-- 清理资源跟踪器
		alignResourceTracker.callbacks = #()
		alignResourceTracker.tempData = #()
		alignResourceTracker.globalVars = #()
		alignResourceTracker.lastCleanupTime = timestamp()
		
		-- 预防内存泄漏
		preventMemoryLeaks()
		
		format "资源管理器：完整系统清理完成\n"
		return true
		
	) catch (
		format "资源管理器：完整系统清理失败: %\n" (getCurrentException())
		return false
	)
)

-- 自动清理检查函数
function performAutoCleanup =
(
	try (
		local currentTime = timestamp()
		local timeSinceLastCleanup = (currentTime - alignResourceTracker.lastCleanupTime) / 1000.0
		
		-- 每10分钟执行一次自动清理
		if timeSinceLastCleanup > 600 then
		(
			format "资源管理器：执行自动清理检查...\n"
			
			-- 检查是否有孤立的回调
			if alignCallbackState != undefined and alignCallbackState.isRegistered and not isPreviewActive then
			(
				format "资源管理器：发现孤立回调，清理中...\n"
				unregisterSafeCallback()
			)
			
			-- 预防内存泄漏
			preventMemoryLeaks()
			
			alignResourceTracker.lastCleanupTime = currentTime
		)
		
		return true
		
	) catch (
		format "资源管理器：自动清理检查失败\n"
		return false
	)
)

-- 获取资源使用报告
function getResourceReport =
(
	try (
		local report = "资源管理器报告：\n"
		report += "- 已注册回调: " + alignResourceTracker.callbacks.count as string + "\n"
		report += "- 活动对话框: " + alignResourceTracker.dialogs.count as string + "\n"
		report += "- 全局变量: " + alignResourceTracker.globalVars.count as string + "\n"
		report += "- 临时数据: " + alignResourceTracker.tempData.count as string + "\n"
		report += "- 系统回调: " + alignResourceTracker.systemCallbacks.count as string + "\n"
		
		local timeSinceCleanup = (timestamp() - alignResourceTracker.lastCleanupTime) / 1000.0
		report += "- 最后清理: " + timeSinceCleanup as string + " 秒前\n"
		
		-- 内存使用情况
		if previewRays != undefined then
			report += "- 预览射线: " + previewRays.count as string + " 条\n"
		
		return report
		
	) catch (
		return "资源管理器：获取报告失败"
	)
)

rollout 对齐到物体表面 "对齐到物体表面" width:320 height:500
(
	-- 单次对齐区域
	groupBox grp1 "单次对齐" pos:[10,10] width:300 height:80
	button btn4 "对齐到物体表面" pos:[20,30] width:160 height:27
	label lbl1 "先选择要对齐的物体，然后点击按钮，再选择需要对齐到的物体表面" pos:[20,60] width:280 height:25
	
	-- 预览控制区域
	groupBox grp4 "预览控制" pos:[10,100] width:300 height:60
	checkbox chkPreview "显示射线预览" pos:[20,120] width:120 height:20 checked:false
	button btnRefreshPreview "刷新预览" pos:[150,118] width:70 height:25
	button btnClearPreview "清除预览" pos:[230,118] width:70 height:25
	
	-- 队列管理区域
	groupBox grp2 "队列管理" pos:[10,170] width:300 height:280
	listBox queueList "目标地面队列:" pos:[20,190] width:200 height:12
	button btnAddToQueue "添加选中" pos:[230,190] width:70 height:25
	button btnRemoveFromQueue "删除选中" pos:[230,220] width:70 height:25
	button btnClearQueue "清空队列" pos:[230,250] width:70 height:25
	button btnQueueAlign "队列对齐" pos:[230,290] width:70 height:35
	label lblQueueCount "队列: 0 项" pos:[20,420] width:100 height:20
	
	-- 状态显示区域
	groupBox grp3 "状态信息" pos:[10,460] width:300 height:50
	label lbl2 "状态：就绪" pos:[20,480] width:280 height:20
	
	-- 原有变量
	local targetSurface = undefined
	
	-- 队列相关变量
	local surfaceQueue = #()         -- 目标地面队列数组
	local queueNames = #()           -- 队列显示名称数组
	local currentQueueIndex = 1      -- 当前处理的队列索引
	local isQueueMode = false        -- 是否为队列模式
	
	-- 队列管理函数
	function updateQueueDisplay =
	(
		queueList.items = queueNames
		lblQueueCount.text = "队列: " + surfaceQueue.count as string + " 项"
	)
	
	function addToQueue =
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
			-- 检查是否为有效的几何体（使用新的验证函数）
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
			append queueNames obj.name
			append addedNames obj.name
			addedCount += 1
		)
		
		updateQueueDisplay()
		
		-- 显示添加结果
		if addedCount > 0 then
		(
			if addedCount == 1 then
				lbl2.text = "状态：已添加 " + addedNames[1] + " 到队列"
			else
				lbl2.text = "状态：已添加 " + addedCount as string + " 个模型到队列"
			
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
	
	function removeFromQueue =
	(
		local selIndex = queueList.selection
		if selIndex > 0 and selIndex <= surfaceQueue.count then
		(
			local removedName = queueNames[selIndex]
			deleteItem surfaceQueue selIndex
			deleteItem queueNames selIndex
			updateQueueDisplay()
			lbl2.text = "状态：已从队列删除 " + removedName
		)
		else
		(
			messageBox "请先选择要删除的队列项" title:"删除错误"
		)
	)
	
	function clearQueue =
	(
		if surfaceQueue.count > 0 then
		(
			local result = queryBox "确定要清空整个队列吗？" title:"确认清空"
			if result then
			(
				surfaceQueue = #()
				queueNames = #()
				updateQueueDisplay()
				lbl2.text = "状态：队列已清空"
			)
		)
		else
		(
			messageBox "队列已经是空的" title:"清空队列"
		)
	)
	
	-- 统一的对齐算法函数（增强版）
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

-- 批量对齐到指定表面的函数（重构版）
function alignToSpecificSurface surface =
(
	-- 获取当前选择的物体
	local obj = getCurrentSelection()
	local num_obj = obj.count
	
	if num_obj == 0 then
	(
		lbl2.text = "状态：没有选中的物体，跳过对齐"
		return false
	)
	
	lbl2.text = "状态：正在对齐到 " + surface.name + "..."
	windows.processPostedMessages()
	
	-- 批量对齐当前选择的物体，每500个更新一次界面
	local updateInterval = 500
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
		
		-- 每处理500个对象或处理完成时更新界面
		if (mod i updateInterval) == 0 or i == num_obj then
		(
			lbl2.text = "状态：已对齐 " + processedCount as string + "/" + num_obj as string + " 到 " + surface.name
			windows.processPostedMessages()
		)
	)
	
	lbl2.text = "状态：完成对齐到 " + surface.name + "（共处理 " + processedCount as string + " 个对象）"
	return true
)
	
	-- 处理队列对齐的函数
	function processQueueAlignment =
	(
		if surfaceQueue.count == 0 then
		(
			messageBox "队列为空，请先添加目标地面" title:"队列对齐"
			return false
		)
		
		-- 获取当前选择的物体
		local initialSelection = getCurrentSelection()
		if initialSelection.count == 0 then
		(
			messageBox "请先选择要对齐的物体" title:"队列对齐"
			return false
		)
		
		lbl2.text = "状态：开始队列对齐，共 " + surfaceQueue.count as string + " 个目标地面"
		windows.processPostedMessages()
		
		-- 逐个处理队列中的目标地面
		for i = 1 to surfaceQueue.count do
		(
			-- 检查是否还有选中的物体
			local currentSelection = getCurrentSelection()
			if currentSelection.count == 0 then
			(
				lbl2.text = "状态：所有物体已对齐完成"
				exit
			)
			
			-- 对齐到当前队列项
			lbl2.text = "状态：处理队列 " + i as string + "/" + surfaceQueue.count as string + " - " + queueNames[i]
			windows.processPostedMessages()
			
			alignToSpecificSurface surfaceQueue[i]
			
			-- 短暂延迟以便用户看到进度
			sleep 0.5
		)
		
		lbl2.text = "状态：队列对齐全部完成"
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
			
			-- 检查是否为有效的几何体（使用新的验证函数）
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
		
		-- 批量对齐当前选择的物体，每500个更新一次界面
		local updateInterval = 500
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
			
			-- 每处理500个对象或处理完成时更新界面
			if (mod i updateInterval) == 0 or i == num_obj then
			(
				lbl2.text = "状态：已对齐 " + processedCount as string + "/" + num_obj as string
				windows.processPostedMessages()
			)
		)
		
		lbl2.text = "状态：本批对齐完成（共处理 " + processedCount as string + " 个对象）"
		return true
	)
	
	-- ========== 预览控制事件处理器（重构版） ==========
	
	-- 预览复选框状态变化处理器
	on chkPreview changed state do
	(
		try (
			if state then
			(
				-- 启用预览流程
				format "预览控制：开始启用预览...\n"
				
				-- 验证图形窗口可用性
				local gwContext = getGraphicsWindow()
				if not gwContext.isValid then
				(
					messageBox "图形窗口不可用，预览功能无法启用" title:"预览错误"
					chkPreview.checked = false
					setErrorState "图形窗口不可用"
					lbl2.text = "状态：图形窗口不可用，预览功能禁用"
					return undefined
				)
				
				-- 选择目标表面
				local targetSurface = pickObject prompt:"选择目标表面以显示射线预览（右键取消）"
				
				if targetSurface == undefined then
				(
					-- 用户取消选择
					chkPreview.checked = false
					setPreviewState false 0
					lbl2.text = "状态：用户取消预览"
					return undefined
				)
				
				if not isValidGeometry targetSurface then
				(
					messageBox "选择的对象不是有效的几何体" title:"选择错误"
					chkPreview.checked = false
					setErrorState "无效的目标表面"
					lbl2.text = "状态：目标表面无效"
					return undefined
				)
				
				-- 设置目标表面
				setTargetSurface targetSurface
				
				-- 计算预览射线
				lbl2.text = "状态：正在计算预览射线..."
				windows.processPostedMessages()
				
				if calculatePreviewRays targetSurface then
				(
					-- 注册预览回调
					if registerSafeCallback drawAlignmentRays then
					(
						-- 更新状态
						setPreviewState true previewRays.count
						lbl2.text = "状态：射线预览已启用，显示 " + previewRays.count as string + " 条射线"
						format "预览控制：预览启用成功\n"
					)
					else
					(
						-- 回调注册失败
						chkPreview.checked = false
						setErrorState "回调注册失败"
						lbl2.text = "状态：预览回调注册失败"
					)
				)
				else
				(
					-- 射线计算失败
					chkPreview.checked = false
					setErrorState "射线计算失败"
					lbl2.text = "状态：无法生成预览射线"
				)
			)
			else
			(
				-- 禁用预览流程
				format "预览控制：开始禁用预览...\n"
				
				if unregisterSafeCallback() then
				(
					setPreviewState false 0
					lbl2.text = "状态：射线预览已关闭"
					format "预览控制：预览禁用成功\n"
				)
				else
				(
					setErrorState "预览禁用失败"
					lbl2.text = "状态：预览关闭时出现问题"
				)
			)
			
			-- 验证状态一致性
			validateStateConsistency()
			
		) catch (
			local errorMsg = "预览控制发生错误: " + (getCurrentException() as string)
			format "%\n" errorMsg
			
			-- 错误恢复
			chkPreview.checked = false
			unregisterSafeCallback()
			setErrorState errorMsg
			lbl2.text = "状态：预览控制错误"
		)
	)
	
	-- 刷新预览按钮处理器
	on btnRefreshPreview pressed do
	(
		try (
			if not chkPreview.checked then
			(
				messageBox "请先启用射线预览" title:"刷新预览"
				return undefined
			)
			
			format "预览控制：开始刷新预览...\n"
			lbl2.text = "状态：正在刷新预览..."
			windows.processPostedMessages()
			
			-- 检查当前目标表面
			local currentTarget = if alignmentStateManager != undefined then alignmentStateManager.targetSurface else undefined
			local targetSurface = undefined
			
			if currentTarget != undefined and isValidGeometry currentTarget then
			(
				-- 使用当前目标表面
				targetSurface = currentTarget
				format "预览控制：使用当前目标表面 %\n" targetSurface.name
			)
			else
			(
				-- 重新选择目标表面
				targetSurface = pickObject prompt:"选择目标表面以刷新射线预览（右键取消）"
				
				if targetSurface == undefined then
				(
					lbl2.text = "状态：用户取消刷新"
					return undefined
				)
				
				if not isValidGeometry targetSurface then
				(
					messageBox "选择的对象不是有效的几何体" title:"选择错误"
					lbl2.text = "状态：目标表面无效"
					return undefined
				)
				
				setTargetSurface targetSurface
			)
			
			-- 重新计算预览射线
			if calculatePreviewRays targetSurface then
			(
				-- 更新状态
				setPreviewState true previewRays.count
				
				-- 强制重绘
				try (
					forceCompleteRedraw()
				) catch (
					redrawViews()
				)
				
				lbl2.text = "状态：射线预览已刷新，显示 " + previewRays.count as string + " 条射线"
				format "预览控制：预览刷新成功\n"
			)
			else
			(
				setErrorState "刷新时射线计算失败"
				lbl2.text = "状态：无法刷新预览射线"
			)
			
		) catch (
			local errorMsg = "刷新预览发生错误: " + (getCurrentException() as string)
			format "%\n" errorMsg
			setErrorState errorMsg
			lbl2.text = "状态：刷新预览失败"
		)
	)
	
	-- 清除预览按钮处理器
	on btnClearPreview pressed do
	(
		try (
			format "预览控制：开始清除预览...\n"
			
			-- 完全清理预览状态
			if unregisterSafeCallback() then
			(
				cleanupPreviewState()
				chkPreview.checked = false
				lbl2.text = "状态：射线预览已清除"
				format "预览控制：预览清除成功\n"
			)
			else
			(
				-- 即使注销失败也要尝试清理
				cleanupPreviewState()
				chkPreview.checked = false
				setErrorState "预览清除时出现问题"
				lbl2.text = "状态：预览清除完成（有部分错误）"
			)
			
			-- 验证清理结果
			validateStateConsistency()
			
		) catch (
			local errorMsg = "清除预览发生错误: " + (getCurrentException() as string)
			format "%\n" errorMsg
			
			-- 强制清理
			try (
				cleanupPreviewState()
				chkPreview.checked = false
			) catch ()
			
			setErrorState errorMsg
			lbl2.text = "状态：预览清除失败"
		)
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
	
	on btnAddToQueue pressed do addToQueue()
	on btnRemoveFromQueue pressed do removeFromQueue()
	on btnClearQueue pressed do clearQueue()
	on btnQueueAlign pressed do processQueueAlignment()
	
	-- ========== 对话框生命周期管理 ==========
	
	-- 对话框打开事件处理器
	on 对齐到物体表面 open do
	(
		try (
			format "对话框管理：对话框正在打开...\n"
			
			-- 注册对话框到资源跟踪器
			registerResource "dialog" 对齐到物体表面
			alignDialogInstance = 对齐到物体表面
			
			-- 初始化队列显示
			updateQueueDisplay()
			
			-- 初始化状态显示
			updatePreviewStatus statusMsg.ready
			
			-- 验证系统状态
			validateStateConsistency()
			
			-- 执行自动清理检查
			performAutoCleanup()
			
			format "对话框管理：对话框打开完成\n"
			
		) catch (
			format "对话框管理：对话框打开时发生错误: %\n" (getCurrentException())
			updateErrorStatus "对话框初始化失败"
		)
	)
	
	-- 对话框关闭事件处理器
	on 对齐到物体表面 close do
	(
		try (
			format "对话框管理：对话框正在关闭...\n"
			
			-- 执行对话框关闭清理
			cleanupOnDialogClose()
			
			-- 从资源跟踪器注销对话框
			unregisterResource "dialog" 对齐到物体表面
			
			format "对话框管理：对话框关闭完成\n"
			
		) catch (
			format "对话框管理：对话框关闭时发生错误: %\n" (getCurrentException())
		)
	)

)

-- ========== 脚本初始化系统 ==========

-- 增强的脚本初始化函数
function initializeAlignmentScript =
(
	try (
		format "=== 对齐到物体表面脚本 v2.2 初始化 ===\n"
		
		-- 步骤1：清理之前的实例
		format "初始化步骤 1/5：清理之前的实例...\n"
		try (destroyDialog 对齐到物体表面) catch ()
		cleanupAlignment()
		
		-- 步骤2：验证脚本完整性
		format "初始化步骤 2/5：验证脚本完整性...\n"
		if not validateScriptIntegrity() then
		(
			format "错误：脚本完整性验证失败\n"
			return false
		)
		
		-- 步骤3：初始化组件系统
		format "初始化步骤 3/5：初始化组件系统...\n"
		
		-- 初始化状态管理器
		if not initializeStateManager() then
		(
			format "警告：状态管理器初始化失败\n"
		)
		
		-- 初始化资源跟踪器
		alignResourceTracker = ResourceTracker()
		
		-- 步骤4：注册系统回调
		format "初始化步骤 4/5：注册系统回调...\n"
		callbacks.removeScripts id:#alignToSurfaceCleanup
		callbacks.addScript #systemPreReset "cleanupOnSystemEvent(\"reset\")" id:#alignToSurfaceCleanup
		callbacks.addScript #systemPreNew "cleanupOnSystemEvent(\"new\")" id:#alignToSurfaceCleanup
		callbacks.addScript #filePreOpen "cleanupOnSystemEvent(\"fileOpen\")" id:#alignToSurfaceCleanup
		
		registerResource "systemCallback" #alignToSurfaceCleanup
		
		-- 步骤5：创建并显示对话框
		format "初始化步骤 5/5：创建对话框...\n"
		createdialog 对齐到物体表面 style:#(#style_minimizebox, #style_titlebar, #style_sysmenu)
		
		if 对齐到物体表面 != undefined then
		(
			alignDialogInstance = 对齐到物体表面
			format "✓ 脚本初始化成功完成\n"
			format "=== 对齐到物体表面脚本已就绪 ===\n"
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

-- 增强的系统清理函数
fn cleanupOnSystemEvent eventType =
(
	try (
		format "系统事件清理：%\n" eventType
		cleanupOnSystemEvent eventType
	) catch (
		format "系统事件清理失败: %\n" (getCurrentException())
	)
)

-- 传统清理函数（向后兼容）
fn cleanupOnExit =
(
	cleanupOnSystemEvent "exit"
)

-- ========== 错误恢复机制 ==========

-- 错误类型枚举
struct ErrorTypes (
	GRAPHICS_WINDOW = "graphics_window",
	CALLBACK_REGISTRATION = "callback_registration", 
	RAY_CALCULATION = "ray_calculation",
	RENDERING = "rendering",
	STATE_CORRUPTION = "state_corruption",
	MEMORY_LEAK = "memory_leak",
	DIALOG_ERROR = "dialog_error",
	SYSTEM_ERROR = "system_error"
)

-- 全局错误类型实例
global errorTypes = ErrorTypes()

-- 错误恢复策略结构
struct ErrorRecoveryStrategy (
	errorType,           -- String: 错误类型
	recoveryAction,      -- Function: 恢复动作
	maxRetries,          -- Integer: 最大重试次数
	retryDelay,          -- Integer: 重试延迟（毫秒）
	fallbackAction       -- Function: 回退动作
)

-- 错误历史记录结构
struct ErrorRecord (
	timestamp,           -- Integer: 错误时间戳
	errorType,           -- String: 错误类型
	errorMessage,        -- String: 错误消息
	recoveryAttempted,   -- Boolean: 是否尝试恢复
	recoverySuccessful,  -- Boolean: 恢复是否成功
	context              -- String: 错误上下文
)

-- 全局错误历史
global errorHistory = #()

-- 错误恢复策略注册表
global recoveryStrategies = #()

-- 注册错误恢复策略
function registerRecoveryStrategy errorType recoveryAction maxRetries retryDelay fallbackAction =
(
	try (
		local strategy = ErrorRecoveryStrategy errorType:errorType recoveryAction:recoveryAction maxRetries:maxRetries retryDelay:retryDelay fallbackAction:fallbackAction
		append recoveryStrategies strategy
		
		format "错误恢复：注册策略 '%'\n" errorType
		return true
		
	) catch (
		format "错误恢复：注册策略失败\n"
		return false
	)
)

-- 记录错误
function recordError errorType errorMessage context =
(
	try (
		local record = ErrorRecord timestamp:(timestamp()) errorType:errorType errorMessage:errorMessage recoveryAttempted:false recoverySuccessful:false context:context
		append errorHistory record
		
		-- 限制错误历史大小
		if errorHistory.count > 100 then
		(
			deleteItem errorHistory 1
		)
		
		format "错误记录：% - %\n" errorType errorMessage
		return (errorHistory.count)
		
	) catch (
		format "错误记录：记录失败\n"
		return 0
	)
)

-- 执行错误恢复
function attemptErrorRecovery errorType errorMessage context =
(
	try (
		-- 记录错误
		local recordIndex = recordError errorType errorMessage context
		
		-- 查找恢复策略
		local strategy = undefined
		for s in recoveryStrategies do
		(
			if s.errorType == errorType then
			(
				strategy = s
				exit
			)
		)
		
		if strategy == undefined then
		(
			format "错误恢复：未找到 '%' 的恢复策略\n" errorType
			return false
		)
		
		-- 标记开始恢复尝试
		if recordIndex > 0 then
			errorHistory[recordIndex].recoveryAttempted = true
		
		-- 执行恢复策略
		local recoverySuccess = false
		local retryCount = 0
		
		while retryCount < strategy.maxRetries and not recoverySuccess do
		(
			try (
				format "错误恢复：尝试恢复 '%'（第 %/% 次）\n" errorType (retryCount + 1) strategy.maxRetries
				
				-- 执行恢复动作
				recoverySuccess = strategy.recoveryAction()
				
				if not recoverySuccess and retryCount < strategy.maxRetries - 1 then
				(
					-- 等待重试延迟
					sleep (strategy.retryDelay / 1000.0)
				)
				
			) catch (
				format "错误恢复：恢复动作执行失败: %\n" (getCurrentException())
			)
			
			retryCount += 1
		)
		
		-- 如果恢复失败，尝试回退动作
		if not recoverySuccess and strategy.fallbackAction != undefined then
		(
			try (
				format "错误恢复：执行回退动作\n"
				recoverySuccess = strategy.fallbackAction()
			) catch (
				format "错误恢复：回退动作失败: %\n" (getCurrentException())
			)
		)
		
		-- 更新恢复结果
		if recordIndex > 0 then
			errorHistory[recordIndex].recoverySuccessful = recoverySuccess
		
		if recoverySuccess then
			format "错误恢复：'%' 恢复成功\n" errorType
		else
			format "错误恢复：'%' 恢复失败\n" errorType
		
		return recoverySuccess
		
	) catch (
		format "错误恢复：恢复过程失败: %\n" (getCurrentException())
		return false
	)
)

-- 自动状态重置
function autoStateReset =
(
	try (
		format "错误恢复：执行自动状态重置...\n"
		
		-- 重置预览状态
		cleanupPreviewState()
		
		-- 重置回调状态
		if alignCallbackState != undefined then
		(
			alignCallbackState.isRegistered = false
			alignCallbackState.errorCount = 0
		)
		
		-- 重置全局变量
		isPreviewActive = false
		previewRays = #()
		
		-- 重新初始化状态管理器
		initializeStateManager()
		
		format "错误恢复：自动状态重置完成\n"
		return true
		
	) catch (
		format "错误恢复：自动状态重置失败\n"
		return false
	)
)

-- 图形窗口恢复
function recoverGraphicsWindow =
(
	try (
		format "错误恢复：尝试恢复图形窗口...\n"
		
		-- 测试图形窗口可用性
		local gwContext = getGraphicsWindow()
		if gwContext.isValid then
		(
			format "错误恢复：图形窗口恢复成功\n"
			return true
		)
		
		-- 尝试刷新视图
		try (
			redrawViews()
			sleep 1
			
			gwContext = getGraphicsWindow()
			if gwContext.isValid then
			(
				format "错误恢复：通过视图刷新恢复图形窗口\n"
				return true
			)
		) catch ()
		
		format "错误恢复：图形窗口恢复失败\n"
		return false
		
	) catch (
		format "错误恢复：图形窗口恢复过程失败\n"
		return false
	)
)

-- 回调系统恢复
function recoverCallbackSystem =
(
	try (
		format "错误恢复：尝试恢复回调系统...\n"
		
		-- 完全清理回调
		unregisterSafeCallback()
		
		-- 等待一段时间
		sleep 0.5
		
		-- 如果有预览数据，重新注册回调
		if previewRays != undefined and previewRays.count > 0 then
		(
			if registerSafeCallback drawAlignmentRays then
			(
				format "错误恢复：回调系统恢复成功\n"
				return true
			)
		)
		
		format "错误恢复：回调系统恢复完成（无需重新注册）\n"
		return true
		
	) catch (
		format "错误恢复：回调系统恢复失败\n"
		return false
	)
)

-- 内存泄漏恢复
function recoverFromMemoryLeak =
(
	try (
		format "错误恢复：执行内存泄漏恢复...\n"
		
		-- 清理大型数据结构
		if previewRays != undefined and previewRays.count > 0 then
		(
			previewRays = #()
			format "错误恢复：清理预览射线数据\n"
		)
		
		-- 清理性能跟踪数据
		if performanceTracker.count > 10 then
		(
			performanceTracker = #()
			format "错误恢复：清理性能跟踪数据\n"
		)
		
		-- 清理错误历史（保留最近20条）
		if errorHistory.count > 20 then
		(
			local newHistory = #()
			for i = (errorHistory.count - 19) to errorHistory.count do
				append newHistory errorHistory[i]
			errorHistory = newHistory
			format "错误恢复：清理错误历史数据\n"
		)
		
		-- 执行垃圾回收
		try (
			gc()
			format "错误恢复：执行垃圾回收\n"
		) catch ()
		
		return true
		
	) catch (
		format "错误恢复：内存泄漏恢复失败\n"
		return false
	)
)

-- 对话框恢复
function recoverDialog =
(
	try (
		format "错误恢复：尝试恢复对话框...\n"
		
		-- 检查对话框是否存在
		if alignDialogInstance != undefined then
		(
			try (
				-- 尝试访问对话框
				local testAccess = alignDialogInstance.lbl2.text
				format "错误恢复：对话框正常\n"
				return true
			) catch (
				-- 对话框损坏，需要重建
				alignDialogInstance = undefined
			)
		)
		
		-- 重建对话框
		try (
			destroyDialog 对齐到物体表面
		) catch ()
		
		createdialog 对齐到物体表面 style:#(#style_minimizebox, #style_titlebar, #style_sysmenu)
		
		if 对齐到物体表面 != undefined then
		(
			alignDialogInstance = 对齐到物体表面
			format "错误恢复：对话框重建成功\n"
			return true
		)
		
		format "错误恢复：对话框重建失败\n"
		return false
		
	) catch (
		format "错误恢复：对话框恢复过程失败\n"
		return false
	)
)

-- 初始化错误恢复系统
function initializeErrorRecovery =
(
	try (
		format "错误恢复：初始化恢复系统...\n"
		
		-- 注册恢复策略
		registerRecoveryStrategy errorTypes.GRAPHICS_WINDOW recoverGraphicsWindow 3 1000 autoStateReset
		registerRecoveryStrategy errorTypes.CALLBACK_REGISTRATION recoverCallbackSystem 2 500 autoStateReset
		registerRecoveryStrategy errorTypes.STATE_CORRUPTION autoStateReset 1 0 undefined
		registerRecoveryStrategy errorTypes.MEMORY_LEAK recoverFromMemoryLeak 1 0 undefined
		registerRecoveryStrategy errorTypes.DIALOG_ERROR recoverDialog 2 1000 undefined
		
		format "错误恢复：恢复系统初始化完成\n"
		return true
		
	) catch (
		format "错误恢复：恢复系统初始化失败\n"
		return false
	)
)

-- 获取错误报告
function getErrorReport =
(
	try (
		local report = "错误恢复系统报告：\n"
		
		if errorHistory.count == 0 then
		(
			report += "- 暂无错误记录\n"
			return report
		)
		
		-- 统计信息
		local totalErrors = errorHistory.count
		local recoveryAttempts = 0
		local successfulRecoveries = 0
		
		for record in errorHistory do
		(
			if record.recoveryAttempted then recoveryAttempts += 1
			if record.recoverySuccessful then successfulRecoveries += 1
		)
		
		report += "- 总错误数: " + totalErrors as string + "\n"
		report += "- 恢复尝试: " + recoveryAttempts as string + "\n"
		report += "- 成功恢复: " + successfulRecoveries as string + "\n"
		
		if recoveryAttempts > 0 then
		(
			local successRate = (successfulRecoveries as float / recoveryAttempts) * 100
			report += "- 恢复成功率: " + successRate as string + "%\n"
		)
		
		-- 最近错误
		if totalErrors > 0 then
		(
			local lastError = errorHistory[totalErrors]
			local elapsed = (timestamp() - lastError.timestamp) / 1000.0
			report += "- 最近错误: " + lastError.errorType + " (" + elapsed as string + " 秒前)\n"
		)
		
		return report
		
	) catch (
		return "错误恢复系统报告：获取失败"
	)
)

-- 执行脚本初始化
try (
	-- 初始化错误恢复系统
	initializeErrorRecovery()
	
	-- 初始化主脚本
	initializeAlignmentScript()
	
) catch (
	format "脚本启动失败: %\n" (getCurrentException())
	
	-- 尝试基本恢复
	try (
		autoStateReset()
		format "执行了基本错误恢复\n"
	) catch (
		format "基本错误恢复也失败了\n"
	)
)