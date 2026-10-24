cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "discord_rpc_manager.cpp"
  "flutter_window.cpp"
  "jump_list.cpp"
  "main.cpp"
  "system_tray_manager.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})
target_compile_features(${BINARY_NAME} PRIVATE cxx_std_20)

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Enforce UTF-8 source and execution character sets for MSVC
if(MSVC)
  target_compile_options(${BINARY_NAME} PRIVATE /utf-8)
endif()

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib" "propsys.lib" "shell32.lib" "uxtheme.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Discord Social SDK configuration (unauthenticated RPC for Windows)
set(DISCORD_SDK_DIR "${CMAKE_SOURCE_DIR}/libs/discord")
if(EXISTS "${DISCORD_SDK_DIR}/include")
  target_include_directories(${BINARY_NAME} PRIVATE "${DISCORD_SDK_DIR}/include")
  if(EXISTS "${DISCORD_SDK_DIR}/lib/discord_partner_sdk.lib")
    target_link_libraries(${BINARY_NAME} PRIVATE "${DISCORD_SDK_DIR}/lib/discord_partner_sdk.lib")
  endif()
  if(EXISTS "${DISCORD_SDK_DIR}/bin/discord_partner_sdk.dll")
    add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${DISCORD_SDK_DIR}/bin/discord_partner_sdk.dll"
        "$<TARGET_FILE_DIR:${BINARY_NAME}>"
    )
  endif()
endif()

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)
