# 3ds Max车道标线生成插件安装指南

## 编译步骤

### 环境准备

1. 安装Visual Studio 2019或更高版本
2. 安装3ds Max 2021或更高版本
3. 下载并安装3ds Max SDK（与您的3ds Max版本匹配）

### 使用Visual Studio编译

1. 打开Visual Studio，创建新的DLL项目
2. 将`src`目录下的所有文件添加到项目中
3. 配置项目属性：
   - 包含目录：添加3ds Max SDK的include目录
   - 库目录：添加3ds Max SDK的lib目录
   - 链接器输入：添加core.lib, geom.lib, mesh.lib, maxutil.lib, maxscrpt.lib, paramblk2.lib等依赖库
   - 输出文件扩展名：.dlr
4. 编译项目

### 使用CMake编译（推荐）

1. 修改`src/CMakeLists.txt`中的`MAX_SDK_PATH`变量，指向您的3ds Max SDK安装路径
2. 创建构建目录：
   ```
   mkdir build
   cd build
   ```
3. 生成项目文件：
   ```
   cmake ..
   ```
4. 编译项目：
   ```
   cmake --build . --config Release
   ```

## 安装方法

1. 将编译生成的`RoadLineGenerator.dlr`文件复制到3ds Max的plugins目录
   - 通常位于`C:\Program Files\Autodesk\3ds Max 20XX\plugins`
2. 启动3ds Max
3. 在实用工具面板中找到"车道标线生成器"工具

## 使用方法

1. 在3ds Max中创建或导入样条线
2. 选择样条线
3. 打开实用工具面板，找到"车道标线生成器"
4. 设置标线参数：
   - 标线类型：选择实线、虚线、斑马线或导流线
   - 宽度：设置标线宽度（米）
   - 间距：设置虚线或斑马线间距（米）
   - 颜色：设置标线颜色
   - RANSAC参数：调整迭代次数和误差阈值
5. 点击"生成标线"按钮

## 测试注意事项

1. 确保样条线是连续的，没有断开或重叠
2. 对于复杂的交叉路口，可能需要手动调整RANSAC参数
3. 实时预览功能可能会影响性能，如果遇到卡顿，请关闭此选项
4. 如果插件加载失败，请检查是否有缺少的依赖库

## 常见问题解决

1. **插件未显示在实用工具面板中**
   - 检查插件是否正确复制到plugins目录
   - 使用3ds Max的插件管理器检查是否有加载错误

2. **生成标线失败**
   - 确保已选择有效的样条线
   - 检查RANSAC参数是否合适
   - 尝试调整标线宽度和间距参数

3. **编译错误**
   - 确保3ds Max SDK路径正确设置
   - 检查是否包含了所有必要的依赖库