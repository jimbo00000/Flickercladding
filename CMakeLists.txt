CMAKE_MINIMUM_REQUIRED( VERSION 2.6 )
PROJECT( Flickercladding-Desktop )

SET( GL_FRAMEWORK "GLFW" CACHE STRING "Which OpenGL windowing framework to use" )
MESSAGE( "CMAKE_SYSTEM_NAME: ${CMAKE_SYSTEM_NAME}" )

INCLUDE(cmake_modules/InvokePython.cmake)
INVOKEPYTHON( "tools/hardcode_shaders.py" )

ADD_DEFINITIONS(-DAPP_DATA_DIRECTORY="${CMAKE_CURRENT_SOURCE_DIR}/data/")

#
# Platform-dependent section
#
IF( WIN32 )
    MESSAGE(STATUS "MSVC_VERSION=${MSVC_VERSION}")
    # 1600 = VS 10.0
    # 1700 = VS 11.0
    # 1800 = VS 12.0

    #
    # Custom Windows include and link dirs for my machine:
    #
    SET( LIBS_HOME "C:/lib" CACHE STRING "Location of support libraries Glut, Glew and others"  )

    SET( GLM_ROOT "${LIBS_HOME}/glm-0.9.5.4/glm" CACHE STRING "glm root" )
    INCLUDE_DIRECTORIES( "${GLM_ROOT}" )
    ADD_DEFINITIONS( -DGLM_FORCE_RADIANS )

    IF( GL_FRAMEWORK STREQUAL "GLFW" )
        MESSAGE("Using GLFW Framework.")

        SET( GLFW3_ROOT "${LIBS_HOME}/glfw-3.1.2.bin.WIN32" CACHE STRING "glfw root" )
        IF( MSVC_VERSION STREQUAL "1600" ) # VS 2010
            LINK_DIRECTORIES( "${GLFW3_ROOT}/lib-vc2010" )
        ELSEIF( MSVC_VERSION STREQUAL "1700" )
            LINK_DIRECTORIES( "${GLFW3_ROOT}/lib-vc2012" )
        ELSEIF( MSVC_VERSION STREQUAL "1800" )
            LINK_DIRECTORIES( "${GLFW3_ROOT}/lib-vc2013" )
        ELSEIF( MSVC_VERSION STREQUAL "1900" )
            LINK_DIRECTORIES( "${GLFW3_ROOT}/lib-vc2015" )
        ENDIF()
        INCLUDE_DIRECTORIES( "${GLFW3_ROOT}/include" )
        SET( FRAMEWORK_LIBS glfw3.lib )
    ENDIF()

    SET( PLATFORM_LIBS
        ${FRAMEWORK_LIBS}
        opengl32.lib glu32.lib
        Winmm.lib
        ws2_32.lib
        )

    ADD_DEFINITIONS( /W4 -D_CRT_SECURE_NO_WARNINGS )
    add_definitions(-DUNICODE -D_UNICODE)

    # These lines will silence some linker warnings on VS2010,
    # but also remove debug info from the debug build.
    #SET( CMAKE_EXE_LINKER_FLAGS /NODEFAULTLIB:\"libcmt.lib\" )
    #SET( CMAKE_EXE_LINKER_FLAGS_DEBUG /NODEFAULTLIB:\"msvcrt.lib\" )
ELSEIF( APPLE )
    ADD_DEFINITIONS( -D_MACOS )

    # Todo - build OVR with RTTI support
    SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fno-rtti")

    SET( LIBS_HOME "~/Development" )

    INCLUDE_DIRECTORIES ( /System/Library/Frameworks )
    FIND_LIBRARY(COCOA_LIBRARY Cocoa)
    FIND_LIBRARY(IOKIT_LIBRARY IOKit)
    FIND_LIBRARY(OpenGL_LIBRARY OpenGL )
    MARK_AS_ADVANCED (COCOA_LIBRARY
                      GLUT_LIBRARY
                      IOKIT_LIBRARY
                      OpenGL_LIBRARY
                      OVR_LIBRARY)
    INCLUDE_DIRECTORIES( "/opt/local/include/" )
    LINK_DIRECTORIES   ( "/opt/local/lib" )

    SET( GLM_ROOT "${LIBS_HOME}/glm-0.9.5.4/glm" CACHE STRING "glm root" )
    INCLUDE_DIRECTORIES( "${GLM_ROOT}" )
    ADD_DEFINITIONS( -DGLM_FORCE_RADIANS )

    #SET( PLATFORM_LIBS  ${COCOA_LIBRARY} ${IOKIT_LIBRARY} )
    SET( PLATFORM_LIBS
        ${FRAMEWORK_LIBS}
        ${COCOA_LIBRARY}
        ${IOKIT_LIBRARY}
        ${OpenGL_LIBRARY}
        -lGLEW
        -lglfw
        )
ELSEIF( UNIX )
    ADD_DEFINITIONS( -D_UNIX )
    IF( CMAKE_SYSTEM_NAME STREQUAL "Linux" )
        ADD_DEFINITIONS( -D_LINUX )
    ELSEIF( CMAKE_SYSTEM_NAME STREQUAL "FreeBSD" )
        ADD_DEFINITIONS( -D_FREEBSD )
        INCLUDE_DIRECTORIES( /usr/local/include )
        LINK_DIRECTORIES( /usr/local/lib )
    ENDIF()

    SET( LIBS_HOME "~/lib" )

    #ADD_DEFINITIONS( -D_DEBUG )
    #SET(CMAKE_CXX_FLAGS "-ggdb")
    #SET(CMAKE_CXX_FLAGS_DEBUG "-ggdb")

    SET( GLM_ROOT "${LIBS_HOME}/glm-0.9.5.4/glm" CACHE STRING "glm root" )
    INCLUDE_DIRECTORIES( "${GLM_ROOT}" )
    ADD_DEFINITIONS( -DGLM_FORCE_RADIANS )

    IF( GL_FRAMEWORK STREQUAL "GLFW" )
        MESSAGE("Using GLFW Framework.")
        INCLUDE_DIRECTORIES( "/usr/local/include/GLFW" )
        SET( FRAMEWORK_LIBS -lglfw )
    ELSE()
        MESSAGE("Unknown GL_FRAMEWORK: choose GLFW, SDL or SFML.")
    ENDIF()

    find_package(OpenGL REQUIRED)
    include_directories( ${OPENGL_INCLUDE_DIRS} )

    SET( PLATFORM_LIBS
        
        -lGL
        -lGLU
        ${FRAMEWORK_LIBS}
        -lXinerama # GLFW 3.1
        -lXcursor # GLFW 3.1
        -ldl
        -lm
        )
ENDIF()

#
# Platform-independent section
#

SET( SRC_HOME "app/src/main/jni" )
SET( DESKTOP_SRC_HOME "desktop_src" )

FILE( GLOB_RECURSE UTIL_SOURCE_FILES
    ${SRC_HOME}/Util/*.cpp
    ${SRC_HOME}/Util/*.h
    )

FILE( GLOB_RECURSE GLUTIL_SOURCE_FILES
    ${SRC_HOME}/GLUtil/*.cpp
    ${SRC_HOME}/GLUtil/*.h
    )

FILE( GLOB_RECURSE SCENE_SOURCE_FILES
    ${SRC_HOME}/Scene/*.cpp
    ${SRC_HOME}/Scene/*.h
    )

FILE( GLOB_RECURSE DESKTOP_UTILS_SOURCE_FILES
    ${DESKTOP_SRC_HOME}/Desktop_Utils/*.cpp
    ${DESKTOP_SRC_HOME}/Desktop_Utils/*.h
    )

INCLUDE_DIRECTORIES("${SRC_HOME}")
INCLUDE_DIRECTORIES("${SRC_HOME}/Util")
INCLUDE_DIRECTORIES("${SRC_HOME}/GLUtil")
INCLUDE_DIRECTORIES("${SRC_HOME}/Shaders")
INCLUDE_DIRECTORIES("${SRC_HOME}/autogen")
INCLUDE_DIRECTORIES("${SRC_HOME}/Scene")
INCLUDE_DIRECTORIES("${DESKTOP_SRC_HOME}/Desktop_Utils")
# Python script will dump generated headers to autogen/
INCLUDE_DIRECTORIES("${SRC_HOME}/autogen")

ADD_LIBRARY( Util           ${UTIL_SOURCE_FILES} )
ADD_LIBRARY( GLUtil         ${GLUTIL_SOURCE_FILES} )
ADD_LIBRARY( Scene          ${SCENE_SOURCE_FILES} )
ADD_LIBRARY( Desktop_Utils  ${DESKTOP_UTILS_SOURCE_FILES} )

SET( GLAD_HOME "desktop_src/GL" )
INCLUDE_DIRECTORIES("${GLAD_HOME}/include")
ADD_LIBRARY( Glad ${GLAD_HOME}/src/glad.c )

IF( GL_FRAMEWORK STREQUAL "GLFW" )
    ADD_EXECUTABLE( ${PROJECT_NAME} desktop_src/glfw_main.cpp )
ENDIF()

TARGET_LINK_LIBRARIES( ${PROJECT_NAME}
    Desktop_Utils
    Scene
    Glad
    GLUtil
    Util
    ${PLATFORM_LIBS}
    )
