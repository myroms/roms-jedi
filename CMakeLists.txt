# (C) Copyright 2019-2019 UCAR.
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

################################################################################
# ROMS-JEDI interface
################################################################################

cmake_minimum_required( VERSION 3.12 )
project( roms-jedi VERSION 0.0.0 LANGUAGES C CXX Fortran)

find_package(ecbuild 3.3.2 REQUIRED)
include( ecbuild_system NO_POLICY_SCOPE )
ecbuild_declare_project()

list( APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)
include( roms-jedi_compiler_flags )

################################################################################
# Dependencies
################################################################################
find_package( NetCDF REQUIRED COMPONENTS Fortran)
find_package( gsl-lite REQUIRED HINTS $ENV{gsl_list_DIR})
find_package( eckit  1.11.6   REQUIRED)
find_package( fckit  0.7.0    REQUIRED)
find_package( atlas  0.20.2   REQUIRED)
find_package( oops   1.0.0    REQUIRED)
find_package( saber  1.0.0    REQUIRED)
find_package( ioda   1.0.0    REQUIRED)
find_package( ufo    1.0.0    REQUIRED)
include_directories( ${NETCDF_INCLUDE_DIRS} )

# ROMS
include_directories( ${ROMS_INCLUDE_DIR} )
link_libraries( ${ROMS_LIBRARY} )

message( STATUS "################################################################################" )
#message( STATUS "ROMS_INCLUDE_DIR = ${ROMS_INCLUDE_DIR}" )
#message( STATUS "ROMS_LIBRARY = ${ROMS_LIBRARY}" )
message( STATUS "################################################################################" )



################################################################################
# Sources
################################################################################
set( ROMS-JEDI_LINKER_LANGUAGE CXX)

add_subdirectory( src )
add_subdirectory( test )


# print the summary of the configuration
ecbuild_print_summary()











