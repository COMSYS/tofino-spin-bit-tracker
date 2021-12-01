cmake_minimum_required(VERSION 3.2)
project(tofino_switch_control LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(SDE_LIB_PATH $ENV{SDE_INSTALL}/lib)
set(THREADS_PREFER_PTHREAD_FLAG ON)

include(GNUInstallDirs)

include_directories($ENV{SDE_INSTALL}/include/)
link_directories($SDE/install/lib)


find_package(Threads REQUIRED)
find_library(AVAGO_LIBRARY libavago.so PATHS ${SDE_LIB_PATH})
find_library(DRIVER_LIBRARY libdriver.so PATHS ${SDE_LIB_PATH})
find_library(BFSYS_LIBRARY libbfsys.so PATHS ${SDE_LIB_PATH})
find_library(BFUTILS_LIBRARY libbfutils.so PATHS ${SDE_LIB_PATH})
find_library(BF_SHELL_PLUGIN_CLISH bfshell_plugin_clish.so PATHS ${SDE_LIB_PATH})
find_library(BF_SHELL_PLUGIN_PIPEMGR bfshell_plugin_pipemgr.so PATHS ${SDE_LIB_PATH})
find_library(BF_SHELL_PLUGIN_DEBUG bfshell_plugin_debug.so PATHS ${SDE_LIB_PATH})
find_library(BF_SHELL_PLUGIN_BFRT bfshell_plugin_bf_rt.so PATHS ${SDE_LIB_PATH})

include_directories(/opt/loguru/)
set(LIB_SOURCES ${LIB_SOURCES} /opt/loguru/loguru.cpp)

find_package(Boost 1.58 COMPONENTS program_options REQUIRED )

file(GLOB SRCS
    "*.cpp"
)

add_executable(tofino_switch_control ${SRCS} ${LIB_SOURCES})
target_link_libraries(tofino_switch_control Threads::Threads gmp gmpxx ${Boost_LIBRARIES} dl)

target_link_libraries(tofino_switch_control
    ${AVAGO_LIBRARY} ${DRIVER_LIBRARY} ${BFSYS_LIBRARY} ${BFUTILS_LIBRARY} 
    ${BF_SHELL_PLUGIN_CLISH} ${BF_SHELL_PLUGIN_PIPEMGR} ${BF_SHELL_PLUGIN_DEBUG} ${BF_SHELL_PLUGIN_BFRT})