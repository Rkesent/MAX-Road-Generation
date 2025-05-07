# 3ds Max车道标线生成插件 CMake构建文件

cmake_minimum_required(VERSION 3.10)
project(RoadLineGenerator)

# 设置C++标准
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 3ds Max SDK路径（需要根据实际安装路径修改）
set(MAX_SDK_PATH "C:/Program Files/Autodesk/3ds Max 2022 SDK/maxsdk")

# 包含目录
include_directories(
    ${MAX_SDK_PATH}/include
    ${CMAKE_CURRENT_SOURCE_DIR}
)

# 链接目录
link_directories(
    ${MAX_SDK_PATH}/lib
)

# 源文件
set(SOURCES
    RoadLineGenerator.cpp
    RansacAlgorithm.cpp
    IntersectionDetection.cpp
    LineGeneration.cpp
    DialogHandler.cpp
    SplineUtils.cpp
    RoadLineGenerator.rc
)

# 头文件
set(HEADERS
    RoadLineGenerator.h
    resource.h
)

# 添加DLL目标
add_library(RoadLineGenerator SHARED ${SOURCES} ${HEADERS})

# 设置输出名称
set_target_properties(RoadLineGenerator PROPERTIES
    OUTPUT_NAME "RoadLineGenerator"
    PREFIX ""
    SUFFIX ".dlr"
)

# 链接库
target_link_libraries(RoadLineGenerator
    core.lib
    geom.lib
    mesh.lib
    maxutil.lib
    maxscrpt.lib
    paramblk2.lib
)

# 安装规则
install(TARGETS RoadLineGenerator
    RUNTIME DESTINATION "${MAX_PLUGINS_PATH}"
)

# 复制到3ds Max插件目录的自定义目标
add_custom_command(TARGET RoadLineGenerator POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:RoadLineGenerator> "$ENV{ADSK_3DSMAX_x64_2021}/plugins/"
    COMMENT "复制插件到3ds Max插件目录"
)