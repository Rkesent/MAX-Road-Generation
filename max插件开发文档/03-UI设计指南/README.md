# 3ds Max 插件 UI 设计指南

## 目录

- [设计原则](#设计原则)
- [UI 控件库](#ui-控件库)
- [布局指南](#布局指南)
- [图标和资源](#图标和资源)
- [响应式设计](#响应式设计)
- [辅助功能](#辅助功能)
- [本地化考虑](#本地化考虑)

## 设计原则

### 一致性

- 遵循 3ds Max 的整体设计语言
- 使用一致的控件样式和行为
- 保持术语和图标的一致性
- 遵循用户已经熟悉的工作流程

### 简洁性

- 界面应简洁明了，避免视觉混乱
- 将复杂功能分解为简单步骤
- 默认显示最常用的选项，将高级选项放在子菜单或折叠面板中
- 避免不必要的装饰元素

### 反馈

- 提供清晰的操作反馈
- 使用视觉提示指示当前状态
- 对长时间操作提供进度指示
- 错误信息应具体且提供解决方案

### 灵活性

- 支持不同的工作流程
- 提供快捷键和自定义选项
- 考虑不同技能水平的用户
- 支持撤销/重做操作

## UI 控件库

3ds Max SDK 提供了丰富的 UI 控件库，以下是常用控件及其适用场景：

### 基础控件

#### 按钮 (Button)

```cpp
ICustButton* createBtn = GetICustButton(GetDlgItem(hWnd, IDC_CREATE_BTN));
createBtn->SetText(_T("创建"));
createBtn->SetTooltip(TRUE, _T("创建新对象"));
```

适用场景：触发操作、确认对话框

#### 复选框 (Checkbox)

```cpp
ICustCheck* showWireframeCheck = GetICustCheck(GetDlgItem(hWnd, IDC_SHOW_WIREFRAME));
showWireframeCheck->SetText(_T("显示线框"));
showWireframeCheck->SetChecked(TRUE);
```

适用场景：开关选项、布尔设置

#### 单选按钮 (Radio Button)

```cpp
ICustRadioButton* radioSmooth = GetICustRadioButton(GetDlgItem(hWnd, IDC_RADIO_SMOOTH));
radioSmooth->SetText(_T("平滑"));
radioSmooth->SetCheck(TRUE);
```

适用场景：互斥选项、模式选择

#### 文本输入框 (Edit Box)

```cpp
ICustEdit* nameEdit = GetICustEdit(GetDlgItem(hWnd, IDC_NAME_EDIT));
nameEdit->SetText(_T("默认名称"));
nameEdit->SetTooltip(TRUE, _T("输入对象名称"));
```

适用场景：文本输入、命名

#### 下拉列表 (Dropdown List)

```cpp
ICustComboBox* materialCombo = GetICustComboBox(GetDlgItem(hWnd, IDC_MATERIAL_COMBO));
materialCombo->AddItem(_T("标准材质"), 0);
materialCombo->AddItem(_T("物理材质"), 1);
materialCombo->SetCurSel(0);
```

适用场景：从预定义选项中选择

### 高级控件

#### 滑块 (Slider)

```cpp
ISlider* opacitySlider = GetISlider(GetDlgItem(hWnd, IDC_OPACITY_SLIDER));
opacitySlider->SetRange(0, 100);
opacitySlider->SetValue(100);
```

适用场景：调整数值范围

#### 颜色选择器 (Color Picker)

```cpp
IColorSwatch* colorSwatch = GetIColorSwatch(GetDlgItem(hWnd, IDC_COLOR_SWATCH));
colorSwatch->SetColor(Color(1.0f, 0.0f, 0.0f));
```

适用场景：颜色选择

#### 旋转控件 (Spinner)

```cpp
ISpinnerControl* scaleSpinner = SetupFloatSpinner(hWnd, IDC_SCALE_SPINNER, IDC_SCALE_EDIT, 0.0f, 100.0f, 1.0f);
scaleSpinner->SetValue(1.0f, FALSE);
```

适用场景：精确数值调整

#### 列表视图 (List View)

```cpp
IListControl* objectList = GetIListControl(GetDlgItem(hWnd, IDC_OBJECT_LIST));
objectList->AppendItem(_T("对象1"), 0);
objectList->AppendItem(_T("对象2"), 1);
```

适用场景：显示和选择多个项目

#### 树视图 (Tree View)

```cpp
ITreeView* sceneTree = GetITreeView(GetDlgItem(hWnd, IDC_SCENE_TREE));
HTREEITEM hRoot = sceneTree->InsertItem(_T("场景"), NULL, NULL);
sceneTree->InsertItem(_T("对象1"), hRoot, NULL);
```

适用场景：层次结构数据显示

#### 进度条 (Progress Bar)

```cpp
IProgressBar* progressBar = GetIProgressBar(GetDlgItem(hWnd, IDC_PROGRESS));
progressBar->SetRange(0, 100);
progressBar->SetPos(50);
```

适用场景：显示操作进度

### 自定义控件

#### 自定义按钮 (Custom Button)

```cpp
class MyCustomButton : public CustButton {
public:
    void OnClick() override {
        // 自定义点击行为
    }
};
```

#### 自定义面板 (Custom Panel)

```cpp
class MyRollout : public IRollupWindow {
public:
    void Init(HWND hWnd) {
        // 初始化面板
    }
};
```

## 布局指南

### 布局原则

- 使用网格系统组织控件
- 相关控件应分组在一起
- 遵循从上到下、从左到右的阅读顺序
- 保持适当的间距和对齐

### 常用布局模式

#### 选项卡布局

```cpp
IRollupWindow* rollupWindow = GetIRollupWindow(GetDlgItem(hWnd, IDC_ROLLUP));
rollupWindow->AppendRollup(hGeometryPanel, _T("几何"), ROLLUP_CAT_STANDARD);
rollupWindow->AppendRollup(hMaterialPanel, _T("材质"), ROLLUP_CAT_STANDARD);
```

#### 分组框布局

```cpp
// 在对话框模板中定义分组框
// 然后将相关控件放在分组框内
```

#### 折叠面板布局

```cpp
IRollupWindow* rollupWindow = GetIRollupWindow(GetDlgItem(hWnd, IDC_ROLLUP));
rollupWindow->AppendRollup(hAdvancedPanel, _T("高级选项"), ROLLUP_CAT_STANDARD);
```

### 响应式布局

- 考虑不同屏幕分辨率
- 使用相对尺寸而非固定尺寸
- 测试在不同 DPI 设置下的显示效果

```cpp
// 获取系统 DPI 并相应调整控件大小
int dpi = GetDpiForWindow(hWnd);
int scaledSize = MulDiv(baseSize, dpi, 96);
```

## 图标和资源

### 图标设计

- 使用简单、清晰的图标
- 提供不同尺寸的图标版本
- 保持与 3ds Max 内置图标的风格一致
- 考虑高 DPI 显示

### 资源管理

```cpp
// 加载图标资源
HICON hIcon = LoadIcon(hInstance, MAKEINTRESOURCE(IDI_PLUGIN_ICON));

// 设置按钮图标
ICustButton* toolButton = GetICustButton(GetDlgItem(hWnd, IDC_TOOL_BTN));
toolButton->SetImage(hIcon, 0, 0);
```

### 图标尺寸

- 工具栏图标：16x16, 24x24, 32x32
- 对话框图标：32x32
- 高 DPI 版本：对应尺寸的 2x 和 3x 版本

## 响应式设计

### DPI 感知

```cpp
// 在 DLL 入口点启用 DPI 感知
SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);

// 根据 DPI 缩放控件
void ScaleControlForDpi(HWND hWnd, int controlId, int dpi)
{
    HWND hControl = GetDlgItem(hWnd, controlId);
    RECT rect;
    GetWindowRect(hControl, &rect);
    
    int width = MulDiv(rect.right - rect.left, dpi, 96);
    int height = MulDiv(rect.bottom - rect.top, dpi, 96);
    
    SetWindowPos(hControl, NULL, 0, 0, width, height, SWP_NOMOVE | SWP_NOZORDER);
}
```

### 窗口调整

- 允许调整对话框大小
- 控件应随窗口大小调整
- 提供最小窗口尺寸限制

```cpp
// 处理窗口大小调整
case WM_SIZE:
{
    int width = LOWORD(lParam);
    int height = HIWORD(lParam);
    
    // 调整控件位置和大小
    SetWindowPos(GetDlgItem(hWnd, IDC_CONTROL), NULL, 
                 0, 0, width - 20, height - 20, 
                 SWP_NOMOVE | SWP_NOZORDER);
    break;
}
```

## 辅助功能

### 键盘导航

- 所有功能应可通过键盘访问
- 提供快捷键
- 使用合理的 Tab 顺序

```cpp
// 设置控件 Tab 顺序
SetWindowPos(GetDlgItem(hWnd, IDC_FIRST), HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
SetWindowPos(GetDlgItem(hWnd, IDC_SECOND), HWND_BOTTOM, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
```

### 屏幕阅读器支持

- 为控件提供描述性文本
- 使用 Windows 辅助功能 API

```cpp
// 设置控件辅助功能描述
SetWindowAccessibleName(GetDlgItem(hWnd, IDC_CONTROL), _T("颜色选择器"));
```

### 高对比度支持

- 测试在高对比度模式下的显示效果
- 避免仅依赖颜色传达信息
- 提供足够的对比度

## 本地化考虑

### 文本扩展

- 为翻译后可能变长的文本预留空间
- 避免硬编码布局尺寸
- 测试不同语言下的界面布局

### 资源字符串

```cpp
// 从资源加载本地化字符串
TCHAR buffer[256];
LoadString(hInstance, IDS_BUTTON_CREATE, buffer, 256);
button->SetText(buffer);
```

### 双向文本支持

- 考虑从右到左语言的支持
- 使用 Windows 双向文本 API

```cpp
// 启用从右到左布局
DWORD exStyle = GetWindowLong(hWnd, GWL_EXSTYLE);
SetWindowLong(hWnd, GWL_EXSTYLE, exStyle | WS_EX_LAYOUTRTL);
```