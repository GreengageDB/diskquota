cmake_minimum_required(VERSION 3.20)
# cmake_path requires 3.20

project(diskquota)

if(NOT CMAKE_BUILD_TYPE)
  message(STATUS "Setting build type to 'Debug' as none was specified.")
  set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Choose the type of build." FORCE)
endif()

# generate 'compile_commands.json'
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Retrieve repository information
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/Git.cmake)
GitHash_Get(DISKQUOTA_GIT_HASH)

include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/Gpdb.cmake)


# set include directories for all sub-projects
include_directories(${PG_INCLUDE_DIR_SERVER})
include_directories(${PG_INCLUDE_DIR}) # for libpq
# Overwrite the default build type flags set by cmake.
# We don't want the '-O3 -DNDEBUG' from cmake. Instead, those will be set by the CFLAGS from pg_config.
# And, the good news is, GPDB release always have '-g'.
set(CMAKE_C_FLAGS_RELEASE "" CACHE
    STRING "Flags for RELEASE build" FORCE)
set(CMAKE_C_FLAGS_DEBUG "-DDISKQUOTA_DEBUG"
    CACHE STRING "Flags for DEBUG build" FORCE)
# set link flags for all sub-projects
set(CMAKE_MODULE_LINKER_FLAGS "${PG_LD_FLAGS}")
if (APPLE)
    set(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} -bundle_loader ${PG_BIN_DIR}/postgres")
endif()
# set c and ld flags for all projects
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Werror=clobbered ${PG_C_FLAGS}")

# generate version
# DISKQUOTA_VERSION is the extension's own SQL-schema version: it drives the .so
# name (DISKQUOTA_BINARY_NAME below) and must match a real control/ddl/diskquota--X.Y.sql
# file and diskquota.control's default_version, so it is intentionally NOT tied to
# git tags/releases - it only ever comes from the VERSION file (or an explicit
# -DDISKQUOTA_VERSION= override).
if(NOT DEFINED DISKQUOTA_VERSION)
  file(STRINGS VERSION DISKQUOTA_VERSION)
endif()

# DISKQUOTA_PACKAGE_VERSION is the distribution/package version (used for
# CPACK_PACKAGE_VERSION, i.e. the .deb version) - independent of DISKQUOTA_VERSION
# above. Prefer the git release tag; fall back to DISKQUOTA_VERSION for local
# builds with no tags (or pass -DDISKQUOTA_PACKAGE_VERSION= to override either).
if(NOT DEFINED DISKQUOTA_PACKAGE_VERSION)
  set(DISKQUOTA_PACKAGE_VERSION "")
  if(GIT_EXECUTABLE)
    execute_process(
      COMMAND ${GIT_EXECUTABLE} describe --tags
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
      OUTPUT_VARIABLE DISKQUOTA_GIT_DESCRIBE
      OUTPUT_STRIP_TRAILING_WHITESPACE
      ERROR_QUIET
      RESULT_VARIABLE DISKQUOTA_GIT_DESCRIBE_RESULT)
    if(DISKQUOTA_GIT_DESCRIBE_RESULT EQUAL 0 AND DISKQUOTA_GIT_DESCRIBE)
      # "1.2.2-3-gabcdef" (3 commits past tag 1.2.2) -> "1.2.2+dev.3.gabcdef".
      # An exact tag (e.g. "1.2.2", no "-N-gHASH" suffix) is used as-is.
      string(REGEX REPLACE "^(.*)-([0-9]+)-(g[0-9a-f]+)$" "\\1+dev.\\2.\\3"
             DISKQUOTA_PACKAGE_VERSION "${DISKQUOTA_GIT_DESCRIBE}")
    endif()
  endif()
  if(NOT DISKQUOTA_PACKAGE_VERSION)
    set(DISKQUOTA_PACKAGE_VERSION "${DISKQUOTA_VERSION}")
  endif()
endif()

string(REGEX REPLACE "^([0-9]+).[0-9]+.[0-9]+$" "\\1" DISKQUOTA_MAJOR_VERSION
                     ${DISKQUOTA_VERSION})
string(REGEX REPLACE "^[0-9]+.([0-9]+).[0-9]+$" "\\1" DISKQUOTA_MINOR_VERSION
                     ${DISKQUOTA_VERSION})
string(REGEX REPLACE "^[0-9]+.[0-9]+.([0-9]+)$" "\\1" DISKQUOTA_PATCH_VERSION
                     ${DISKQUOTA_VERSION})

if("${DISKQUOTA_MAJOR_VERSION}.${DISKQUOTA_MINOR_VERSION}" STREQUAL "1.0")
  # in special, version 1.0.x do not has suffix
  set(DISKQUOTA_BINARY_NAME "diskquota")
else()
  set(DISKQUOTA_BINARY_NAME
      "diskquota-${DISKQUOTA_MAJOR_VERSION}.${DISKQUOTA_MINOR_VERSION}")
endif()

add_compile_definitions(
  DISKQUOTA_VERSION="${DISKQUOTA_VERSION}"
  DISKQUOTA_MAJOR_VERSION=${DISKQUOTA_MAJOR_VERSION}
  DISKQUOTA_MINOR_VERSION=${DISKQUOTA_MINOR_VERSION}
  DISKQUOTA_PATCH_VERSION=${DISKQUOTA_PATCH_VERSION}
  DISKQUOTA_BINARY_NAME="${DISKQUOTA_BINARY_NAME}")

set(SRC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src")
file(GLOB diskquota_SRC "${SRC_DIR}/*.c")

set(DISKQUOTA_DDL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/control/ddl")
file(GLOB diskquota_DDL "${DISKQUOTA_DDL_DIR}/*")

add_library(diskquota MODULE ${diskquota_SRC})

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX
      "${PG_HOME}"
      CACHE PATH "default install prefix" FORCE)
endif()

set_target_properties(
  diskquota
  PROPERTIES OUTPUT_NAME ${DISKQUOTA_BINARY_NAME}
             PREFIX ""
             C_STANDARD 99
             LINKER_LANGUAGE "C")

if (${GP_MAJOR_VERSION} STRGREATER_EQUAL "7")
  TARGET_LINK_LIBRARIES(diskquota ${PG_LIB_DIR}/libpq.so)
endif()

# packing part, move to a separate file if this part is too large
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/Distro.cmake)

if(DEFINED DISKQUOTA_LAST_RELEASE_PATH)
  message(STATUS "Copy pervious installer from ${DISKQUOTA_LAST_RELEASE_PATH}")
  file(ARCHIVE_EXTRACT INPUT ${DISKQUOTA_LAST_RELEASE_PATH} PATTERNS "*.so")
  file(GLOB so_files_list
       "${CMAKE_BINARY_DIR}/lib/postgresql/*.so")

  foreach(so_path IN LISTS so_files_list)
    get_filename_component(so_name ${so_path} NAME_WLE)
    # Replace 'diskquota-x.y' with 'x.y'. 'diskquota' won't be replaced, which belongs to 1.x release.
    string(REPLACE "diskquota-" "" so_ver ${so_name})
    # Install the previous so files. Those so files have versions less than current version.
    # diskqutoa.so doesn't have version string in the file name. It belongs to 1.x release.
    if((${so_ver} STREQUAL "diskquota") OR
      ${so_ver} VERSION_LESS ${DISKQUOTA_MAJOR_VERSION}.${DISKQUOTA_MINOR_VERSION})
      list(APPEND DISKQUOTA_PREVIOUS_LIBRARY ${so_path})
    endif()
  endforeach()

  install(PROGRAMS ${DISKQUOTA_PREVIOUS_LIBRARY} DESTINATION "lib/postgresql/")

  get_filename_component(
    DISKQUOTA_LAST_RELEASE_FILENAME ${DISKQUOTA_LAST_RELEASE_PATH} NAME CACHE
    "last release installer name")
  string(
    REGEX
    REPLACE "^diskquota-([0-9]+).[0-9]+.[0-9]+-.*$" "\\1"
            DISKQUOTA_LAST_MAJOR_VERSION ${DISKQUOTA_LAST_RELEASE_FILENAME})
  string(
    REGEX
    REPLACE "^diskquota-[0-9]+.([0-9]+).[0-9]+-.*$" "\\1"
            DISKQUOTA_LAST_MINOR_VERSION ${DISKQUOTA_LAST_RELEASE_FILENAME})
  string(
    REGEX
    REPLACE "^diskquota-[0-9]+.[0-9]+.([0-9]+)-.*$" "\\1"
            DISKQUOTA_LAST_PATCH_VERSION ${DISKQUOTA_LAST_RELEASE_FILENAME})

  set(DISKQUOTA_LAST_VERSION
      "${DISKQUOTA_LAST_MAJOR_VERSION}.${DISKQUOTA_LAST_MINOR_VERSION}.${DISKQUOTA_LAST_PATCH_VERSION}"
  )
endif()

set(tgz_NAME
    "diskquota-${DISKQUOTA_MAJOR_VERSION}.${DISKQUOTA_MINOR_VERSION}.${DISKQUOTA_PATCH_VERSION}-${DISTRO_NAME}_x86_64"
)
set(CPACK_GENERATOR "TGZ")
set(CPACK_INCLUDE_TOPLEVEL_DIRECTORY OFF)
set(CPACK_PACKAGE_FILE_NAME ${tgz_NAME})
set(CPACK_PACKAGE_VERSION ${DISKQUOTA_PACKAGE_VERSION})
# CPack's DEB/RPM generators default this to "/usr", ignoring CMAKE_INSTALL_PREFIX
# (which tracks wherever the build's pg_config lives, e.g. a devel GPHOME used just
# to compile against). The package itself must install to the path a real Greengage
# is deployed at, same convention as pxf-fdw (see pxf/debian/rules).
set(DISKQUOTA_PACKAGE_PREFIX "/opt/greengagedb/greengage${GP_MAJOR_VERSION}" CACHE PATH
    "Installation prefix baked into the DEB/RPM package, independent of CMAKE_INSTALL_PREFIX")
set(CPACK_PACKAGING_INSTALL_PREFIX "${DISKQUOTA_PACKAGE_PREFIX}")

# DEB packaging. The package is versioned per-GP-major-version (diskquota6,
# diskquota7, ...) since the .so is compiled against a specific GPDB's
# headers/libpq and is installed under that GPDB's own GPHOME.
set(CPACK_DEBIAN_PACKAGE_NAME "diskquota${GP_MAJOR_VERSION}")
set(CPACK_DEBIAN_FILE_NAME "DEB-DEFAULT")
set(CPACK_DEBIAN_PACKAGE_MAINTAINER "Greengage <greengage@greengagedb.org>")
set(CPACK_DEBIAN_PACKAGE_SECTION "database")
set(CPACK_DEBIAN_PACKAGE_DEPENDS "greengage${GP_MAJOR_VERSION}")
set(CPACK_DEBIAN_PACKAGE_PROVIDES "diskquota")
set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
set(CPACK_DEBIAN_PACKAGE_DESCRIPTION
    "Diskquota extension for Greengage ${GP_MAJOR_VERSION}
 Diskquota is an extension that provides disk usage enforcement for
 database objects in Greengage DB. It supports setting quota limits on
 schemas and roles and limiting the amount of disk space they can use.")

include(CPack)
# create_artifact target is used to tar the package with version into a version-less tarball to be
# used on concourse gcs resource. It will be uploaded to a gcs version file (no diskquota version
# string in the file name), and be retrieved in the release step. Then we don't have to firgure out
# a way to add the version string back to the release file name, just untar it.
set(artifact_NAME "diskquota.tar.gz")
add_custom_target(create_artifact
  COMMAND
  ${CMAKE_COMMAND} --build . --target package
  COMMAND
  ${CMAKE_COMMAND} -E tar czvf ${artifact_NAME} "${tgz_NAME}.tar.gz")

# package_deb builds the .deb via CPack's DEB generator (needs dpkg-dev for
# dpkg-shlibdeps). GP_MAJOR_VERSION/DISKQUOTA_VERSION are picked up from
# whichever GPDB's pg_config was used to configure this build (-DPG_CONFIG=...),
# so build once per GPDB major version (6 and 7) to get both packages.
add_custom_target(package_deb
  COMMAND ${CMAKE_CPACK_COMMAND} -G DEB)
# packing end

# Create build-info
# The diskquota-build-info shouldn't be copied to GPDB release by install_gpdb_component
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/BuildInfo.cmake)
set(build_info_PATH ${CMAKE_CURRENT_BINARY_DIR}/diskquota-build-info)
BuildInfo_Create(${build_info_PATH}
  VARS
  DISKQUOTA_GIT_HASH
  DISKQUOTA_VERSION
  GP_MAJOR_VERSION
  GP_VERSION
  CMAKE_BUILD_TYPE)
# Create build-info end

# Add installcheck targets
add_subdirectory(tests)
add_subdirectory(upgrade_test)

# NOTE: keep install part at the end of file, to overwrite previous binary
install(PROGRAMS "cmake/install_gpdb_component" DESTINATION ".")
install(FILES ${diskquota_DDL} DESTINATION "share/postgresql/extension/")
install(TARGETS diskquota DESTINATION "lib/postgresql/")
install(FILES ${build_info_PATH} DESTINATION ".")

file(GLOB sql_files RELATIVE ${DISKQUOTA_DDL_DIR} "${DISKQUOTA_DDL_DIR}/diskquota--2.*.sql")
list(FILTER sql_files EXCLUDE REGEX ".*--.*--.*")
list(FILTER sql_files EXCLUDE REGEX ".*diskquota--${DISKQUOTA_MAJOR_VERSION}.${DISKQUOTA_MINOR_VERSION}.*")
foreach(so IN LISTS sql_files)
  string(REGEX REPLACE "^diskquota--([0-9]+)\.([0-9]+).sql$" "diskquota-\\1.\\2.so" so ${so})
  install(CODE "execute_process(COMMAND ${CMAKE_COMMAND} -E create_symlink ${DISKQUOTA_BINARY_NAME}.so \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/lib/postgresql/${so}\")")
endforeach()
