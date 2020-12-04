# (C) Copyright 2019-2019 UCAR.
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

################################################################################
# ROMS-JEDI interface
################################################################################

cmake_minimum_required( VERSION 3.8 FATAL_ERROR )

project( roms-jedi C CXX Fortran)

set( CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake;${CMAKE_MODULE_PATH})

set( ENABLE_OS_TESTS           OFF CACHE BOOL "Disable OS tests" FORCE )
set( ENABLE_LARGE_FILE_SUPPORT OFF CACHE BOOL "Disable testing of large file support" FORCE )
set( ENABLE_MPI                ON CACHE BOOL "Compile with MPI" )

include( ecbuild_system NO_POLICY_SCOPE )

ecbuild_requires_macro_version( 2.5 )


################################################################################
# Project
################################################################################

ecbuild_declare_project()

ecbuild_enable_fortran( REQUIRED )
ecbuild_add_cxx11_flags()

set( ROMS_LINKER_LANGUAGE CXX )


################################################################################
# Dependencies
################################################################################

# Boost Headers
set( Boost_MINIMUM_VERSION "1.47" )
include_directories( ${Boost_INCLUDE_DIR} )

# NetCDF
find_package( NetCDF REQUIRED COMPONENTS Fortran )
include_directories( ${NETCDF_INCLUDE_DIRS} )

# eckit
ecbuild_use_package( PROJECT eckit VERSION 1.1.0 REQUIRED )
include_directories( ${ECKIT_INCLUDE_DIRS} )
link_libraries( ${ECKIT_LIBRARIES} )

# fckit
ecbuild_use_package( PROJECT fckit VERSION 0.4.1 REQUIRED )
include_directories( ${FCKIT_INCLUDE_DIRS} )

# atlas
ecbuild_use_package( PROJECT atlas VERSION 0.18.1 REQUIRED )
include_directories( ${ATLAS_INCLUDE_DIRS} )

# oops
ecbuild_use_package( PROJECT oops VERSION 0.1.0 REQUIRED )
include_directories( ${OOPS_INCLUDE_DIRS} )
add_definitions(-DATLASIFIED=1)

# saber
ecbuild_use_package( PROJECT saber VERSION 0.0.1 REQUIRED )
include_directories( ${SABER_INCLUDE_DIRS} )

# ioda
ecbuild_use_package( PROJECT ioda VERSION 0.1.0 REQUIRED )
include_directories( ${IODA_INCLUDE_DIRS} )

# ufo
ecbuild_use_package( PROJECT ufo VERSION 0.1.0 REQUIRED )
include_directories( ${UFO_INCLUDE_DIRS} )

# ROMS                                                                                                                         
find_library( ROMS_LIBRARY
              NAMES "libROMS.so"
              DOC "ROMS library"
              HINTS ${roms_DIR}
              PATH_SUFFIXES lib )

mark_as_advanced( ROMS_LIBRARY )

find_file( ROMS_INCLUDE_FILE
           NAMES "ocean_control_mod.mod"
           DOC "ROMS include directory"
           HINTS ${roms_DIR}
           PATH_SUFFIXES include module )

mark_as_advanced( ROMS_INCLUDE_FILE )

if( ROMS_INCLUDE_FILE )
    get_filename_component(ROMS_INCLUDE_FILE ${ROMS_INCLUDE_FILE} ABSOLUTE)
    get_filename_component(ROMS_INCLUDE_DIR  ${ROMS_INCLUDE_FILE} DIRECTORY)
endif()

include_directories( ${ROMS_INCLUDE_DIR} )
link_libraries( ${ROMS_LIBRARY} )

message( STATUS "ROMS_INCLUDE_DIR = ${ROMS_INCLUDE_DIR}" )
message( STATUS "ROMS_LIBRARY = ${ROMS_LIBRARY}" )

# MPI
ecbuild_find_mpi( COMPONENTS CXX Fortran REQUIRED )
ecbuild_include_mpi()
link_libraries( ${MPI_CXX_LIBRARIES} ${MPI_Fortran_LIBRARIES} )

################################################################################
# Export package info
################################################################################
list( APPEND ROMS_TPLS atlas atlas_f LAPACK MPI NetCDF )

set( ROMS_INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/src
                       ${CMAKE_CURRENT_BINARY_DIR}/src
                       ${CMAKE_Fortran_MODULE_DIRECTORY} )
set( ROMS_LIBRARIES roms-jedi )

get_directory_property( ROMS_DEFINITIONS COMPILE_DEFINITIONS )

foreach( _tpl ${ROMS_TPLS} )
string( TOUPPER ${_tpl} TPL )
list( APPEND ROMS_EXTRA_DEFINITIONS   ${${TPL}_DEFINITIONS}  ${${TPL}_TPL_DEFINITIONS}  )
list( APPEND ROMS_EXTRA_INCLUDE_DIRS  ${${TPL}_INCLUDE_DIRS} ${${TPL}_TPL_INCLUDE_DIRS} )
list( APPEND ROMS_EXTRA_LIBRARIES     ${${TPL}_LIBRARIES}    ${${TPL}_TPL_LIBRARIES}    )
endforeach()


################################################################################
# Sources
################################################################################
include( roms_compiler_flags )
include_directories( ${ROMS_INCLUDE_DIRS} ${ROMS_EXTRA_INCLUDE_DIRS} )

add_subdirectory( src )
add_subdirectory( test )

if(ECBUILD_INSTALL_FORTRAN_MODULES)
  install(DIRECTORY ${CMAKE_Fortran_MODULE_DIRECTORY}/${CMAKE_CFG_INTDIR} DESTINATION ${INSTALL_INCLUDE_DIR} )
endif()

################################################################################
# Finalise configuration
################################################################################

# prepares a tar.gz of the sources and/or binaries
ecbuild_install_project( NAME roms-jedi )

# print the summary of the configuration
ecbuild_print_summary()
