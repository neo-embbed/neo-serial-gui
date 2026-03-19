cmake_minimum_required(VERSION 3.16)

project(neo-serial-gui VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2)

qt_standard_project_setup(REQUIRES 6.8)

# Core library sources
set(CORE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../core)
set(CORE_SOURCES
    ${CORE_DIR}/session/session.cpp
    ${CORE_DIR}/transport/uart/uart_transport.cpp
    ${CORE_DIR}/parameter/parameter_card.cpp
)
set(CORE_HEADERS
    ${CORE_DIR}/session/session.h
    ${CORE_DIR}/transport/transport.h
    ${CORE_DIR}/transport/uart/uart_transport.h
    ${CORE_DIR}/parameter/parameter_card.h
)

qt_add_executable(appneo-serial-gui
    main.cpp
    session_bridge.h
    session_bridge.cpp
    card_bridge.h
    card_bridge.cpp
    ${CORE_SOURCES}
    ${CORE_HEADERS}
)

target_include_directories(appneo-serial-gui PRIVATE
    ${CORE_DIR}/..
)

qt_add_qml_module(appneo-serial-gui
    URI neo-serial-gui
    VERSION 1.0
    QML_FILES
        Main.qml
)

set_target_properties(appneo-serial-gui PROPERTIES
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appneo-serial-gui
    PRIVATE Qt6::Quick
    PRIVATE Qt6::QuickControls2
)

# Windows serial port needs setupapi for port enumeration
if(WIN32)
    target_link_libraries(appneo-serial-gui PRIVATE setupapi)
endif()

include(GNUInstallDirs)
install(TARGETS appneo-serial-gui
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
