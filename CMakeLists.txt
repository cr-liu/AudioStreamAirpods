cmake_minimum_required(VERSION 3.14)

project(AudioStreamAirpods VERSION 0.1 LANGUAGES CXX)

set(CMAKE_INCLUDE_CURRENT_DIR ON)

set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# set(CMAKE_XCODE_ATTRIBUTE_APPLICATION_EXTENSION_API_ONLY "NO")

# QtCreator supports the following variables for Android, which are identical to qmake Android variables.
# Check https://doc.qt.io/qt/deployment-android.html for more information.
# They need to be set before the find_package(...) calls below.

#if(ANDROID)
#    set(ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/android")
#    if (ANDROID_ABI STREQUAL "armeabi-v7a")
#        set(ANDROID_EXTRA_LIBS
#            ${CMAKE_CURRENT_SOURCE_DIR}/path/to/libcrypto.so
#            ${CMAKE_CURRENT_SOURCE_DIR}/path/to/libssl.so)
#    endif()
#endif()

find_package(QT NAMES Qt6 Qt5 COMPONENTS Core Quick REQUIRED)
find_package(Qt${QT_VERSION_MAJOR} COMPONENTS
        Core Quick QuickControls2 Network REQUIRED)

set(PROJECT_SOURCES
        src/main.cpp
        src/gui/qml.qrc
        src/objc/objcapi.h
        src/objc/objcapi.mm
        src/objc/airpodsmotionobjc.h
        src/objc/airpodsmotionobjc.mm
)

if(${QT_VERSION_MAJOR} GREATER_EQUAL 6)
    qt_add_executable(AudioStreamAirpods
        MANUAL_FINALIZATION
        ${PROJECT_SOURCES}
    )
else()
    if(ANDROID)
        add_library(AudioStreamAirpods SHARED
            ${PROJECT_SOURCES}
        )
    else()
        add_executable(AudioStreamAirpods
          ${PROJECT_SOURCES}
        )
    endif()
endif()

target_compile_definitions(AudioStreamAirpods
  PRIVATE $<$<OR:$<CONFIG:Debug>,$<CONFIG:RelWithDebInfo>>:QT_QML_DEBUG>)
target_link_libraries(AudioStreamAirpods
  PRIVATE
  Qt${QT_VERSION_MAJOR}::Core
  Qt${QT_VERSION_MAJOR}::Quick
  Qt${QT_VERSION_MAJOR}::QuickControls2
  Qt${QT_VERSION_MAJOR}::Network)

set_target_properties(AudioStreamAirpods PROPERTIES
#  MACOSX_BUNDLE_INFO_PLIST ${CMAKE_SOURCE_DIR}/Info.plist
  MACOSX_BUNDLE_GUI_IDENTIFIER "com.manebell.\${PRODUCT_NAME}"
  MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
  MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
)

if(QT_VERSION_MAJOR EQUAL 6)
    qt_import_qml_plugins(AudioStreamAirpods)
    qt_finalize_executable(AudioStreamAirpods)
endif()
