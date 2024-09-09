# (C) COPYRIGHT 2018-2024 UCAR
#
# THIS SOFTWARE IS LICENSED UNDER THE TERMS OF THE APACHE LICENCE VERSION 2.0
# WHICH CAN BE OBTAINED AT HTTP://WWW.APACHE.ORG/LICENSES/LICENSE-2.0.

#-------------------------------------------------------------------------------
#
# ROMS-BUNDLE:
#
# The ROMS-JEDI interface has a bundle sub-directory feature to facilitate
# running various ROMS applications. The strategy is to create a Bundle and
# build sub-directories for each application. For example, for WC13 (default
# application), we could create "Bundle_wc13" and "build_wc13".
#
# By default, ecbuild is configured with RelWithDebInfo resulting in slower
# execution. Use -DCMAKE_BUILD_TYPE at the ecbuild command line for other
# building options like -DCMAKE_BUILD_TYPE=Release (fast, optimized code)
# or -DCMAKE_BUILD_TYPE=Debug for debugging (slower code).
#
# To build the roms-jedi interface use:
# 
#   mkdir Bundle_wc13 build_wc13
#   cp bundle/.gitignore bundle/CMakeLists.txt Bundle_wc13
#   cd build_wc13
#
#   ecbuild -DMPIEXEC_EXECUTABLE=$MPIRUN -DMPIEXEC_NUMPROC_FLAG="-n" -DCMAKE_BUILD_TYPE=Release ../Bundle_wc13
#
# or
#
#   mkdir Bundle_debug build_debug
#   cp bundle/.gitignore bundle/CMakeLists.txt Bundle_debug
#   cd build_debug
#   ecbuild -DMPIEXEC_EXECUTABLE=$MPIRUN -DMPIEXEC_NUMPROC_FLAG="-n" -DCMAKE_BUILD_TYPE=Debug ../Bundle_debug
#
# For other ROMS-JEDI applications, we need to additionally specify ROMS_APP and
# ROMS_APP_DIR in the ecbuild command:
#
#   ecbuild ... -DROMS_APP="DOPPIO" -DROMS_APP_DIR="MyAppDirPath" ../Bundle_app
#
#-------------------------------------------------------------------------------

cmake_minimum_required( VERSION 3.12 FATAL_ERROR)

find_package( ecbuild 3.6 REQUIRED HINTS ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/../ecbuild)

project( roms-jedi VERSION 1.0.0 LANGUAGES C CXX Fortran )

include( ecbuild_bundle )

message( STATUS "---------------------------------------------------------" )
message( STATUS "By default, ecbuild is configured with RelWithDebInfo" )
message( STATUS "resulting in slower execution. Use -DCMAKE_BUILD_TYPE" )
message( STATUS "at the ecbuild command line for other options like" )
message( STATUS "-DCMAKE_BUILD_TYPE=Release or -DCMAKE_BUILD_TYPE=Debug")
message( STATUS "---------------------------------------------------------" )

message( STATUS "BUNDLE ECBUILD_DEFAULT_BUILD_TYPE = ${ECBUILD_DEFAULT_BUILD_TYPE}" )
message( STATUS "BUNDLE CMAKE_BUILD_TYPE = ${CMAKE_BUILD_TYPE}" )

# Set number of mpi-processes to use if the MPIEXEC_NUMPROC value is specified in
# the 'ecbuild' command line or default MPI_NCPUS=2 and MPI_NCPUS_MAX=12 for simple
# and computationally demanding algorithms (like 4D-Var Unit Tests), respectively.

if ( NOT MPIEXEC_NUMPROC )
  set( MPI_NCPUS 2 )
  set( MPI_NCPUS_MAX 12 )
  math( EXPR MPI_3xNCPUS "${MPI_NCPUS} * 3")
else()
  set( MPI_NCPUS ${MPIEXEC_NUMPROC} )
  set( MPI_NCPUS_MAX ${MPIEXEC_NUMPROC} )
  math( EXPR MPI_3xNCPUS "${MPI_NCPUS} * 3")
endif()

# ROMS application (Default: WC13).
#
# If WC13, create a symbolic link to ROMS-JEDI source code path because we need access
# to ROMS header file during configuration and ROMS source code processing.

message( STATUS "---------------------------------------------------------" )
message( STATUS "ROMS Application:" )
message( STATUS "---------------------------------------------------------" )

if( NOT ROMS_APP AND NOT ROMS_APP_DIR )
  set( ROMS_APP WC13 )
  set( ROMS_APP_DIR ${CMAKE_CURRENT_SOURCE_DIR}/roms-jedi/test/Applications/wc13 )

  set( ROMSJEDI_APPLICATION     ${ROMS_APP} )
  set( ROMSJEDI_APPLICATION_DIR ${ROMS_APP_DIR} )

  execute_process( COMMAND ${CMAKE_COMMAND} -E create_symlink .. ${CMAKE_CURRENT_SOURCE_DIR}/roms-jedi )
elseif( ROMS_APP AND NOT ROMS_APP_DIR )
  message( ERROR "If you set ROMS_APP you must also set ROMS_APP_DIR to
                  the absolute path containing your application configuration." )
else()
  set( ROMSJEDI_APPLICATION     ${ROMS_APP} )
  set( ROMSJEDI_APPLICATION_DIR ${ROMS_APP_DIR} )
endif()

message( STATUS "ROMSJEDI_APPLICATION=${ROMSJEDI_APPLICATION}" )
message( STATUS "ROMSJEDI_APPLICATION_DIR=${ROMSJEDI_APPLICATION_DIR}" )
message( STATUS "MPIEXEC_NUMPROC=${MPI_NCPUS}" )
message( STATUS "MPIEXEC_NUMPROC_ENS_HOFX=${MPI_3xNCPUS}" )

set( MY_HEADER_DIR ${ROMS_APP_DIR} )
set( MY_CPP_FLAGS ANALYTICAL_DIR='${ROMS_APP_DIR}';HEADER_DIR='${ROMS_APP_DIR}';ROOT_DIR='${CMAKE_CURRENT_SOURCE_DIR}/roms';MPI )
set( LIBTYPE SHARED )
set( ROMS_EXECUTABLE OFF )
set( MPI ON )

message( STATUS "---------------------------------------------------------" )

# Define bundle

ecbuild_bundle_initialize()

# Use external jedi-cmake or build in bundle

if( DEFINED ENV{jedi_cmake_ROOT} )
  include( $ENV{jedi_cmake_ROOT}/share/jedicmake/Functions/git_functions.cmake )
else()
  ecbuild_bundle( PROJECT jedicmake GIT "https://github.com/jcsda-internal/jedi-cmake.git" BRANCH develop UPDATE RECURSIVE )
  include( jedicmake/cmake/Functions/git_functions.cmake )
endif()

# Required repositories

 ecbuild_bundle( PROJECT roms       GIT "https://github.com/myroms/roms.git"                 BRANCH develop UPDATE )
 ecbuild_bundle( PROJECT oops       GIT "https://github.com/jcsda-internal/oops.git"         BRANCH develop UPDATE )
 ecbuild_bundle( PROJECT vader      GIT "https://github.com/jcsda-internal/vader.git"        BRANCH develop UPDATE )
 ecbuild_bundle( PROJECT saber      GIT "https://github.com/jcsda-internal/saber.git"        BRANCH develop UPDATE )

 ecbuild_bundle( PROJECT gsw        GIT "https://github.com/jcsda-internal/GSW-Fortran.git"  BRANCH develop UPDATE )
 ecbuild_bundle( PROJECT ioda       GIT "https://github.com/jcsda-internal/ioda.git"         BRANCH develop UPDATE )
 ecbuild_bundle( PROJECT ufo        GIT "https://github.com/jcsda-internal/ufo.git"          BRANCH develop UPDATE )

 ecbuild_bundle( PROJECT roms-jedi  SOURCE ../ )

# Finalize bundle

ecbuild_bundle_finalize()
