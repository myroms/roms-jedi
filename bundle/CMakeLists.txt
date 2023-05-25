# (C) COPYRIGHT 2018-2023 UCAR
#
# THIS SOFTWARE IS LICENSED UNDER THE TERMS OF THE APACHE LICENCE VERSION 2.0
# WHICH CAN BE OBTAINED AT HTTP://WWW.APACHE.ORG/LICENSES/LICENSE-2.0.

#-------------------------------------------------------------------------------
#
# ROMS-BUNDLE:
#
# To build the roms-jedi interface use:
# 
#   mkdir build
#   cd build
#
#   ecbuild -DMPIEXEC_EXECUTABLE=$MPIRUN -DMPIEXEC_NUMPROC_FLAG="-n" -DCMAKE_BUILD_TYPE=Release ../bundle
#
# or
#
#   mkdir build_debug
#   cd build_debug
#   ecbuild -DMPIEXEC_EXECUTABLE=$MPIRUN -DMPIEXEC_NUMPROC_FLAG="-n" -DCMAKE_BUILD_TYPE=Debug ../bundle
#
# For other ROMS-JEDI applications, we need to additionally specify ROMS_APP and
# ROMS_APP_DIR in the ecbuild command:
#
#   ecbuild ... -DROMS_APP="DOPPIO" -DROMS_APP_DIR="MyAppDirPath" ../bundle
#
#-------------------------------------------------------------------------------

cmake_minimum_required( VERSION 3.12 FATAL_ERROR)

find_package( ecbuild 3.6 REQUIRED HINTS ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/../ecbuild)

project( roms-jedi VERSION 1.0.0 LANGUAGES C CXX Fortran )

include( ecbuild_bundle )

# Default release mode

set( ECBUILD_DEFAULT_BUILD_TYPE Release )

# ROMS application (Default: WC13).
#
# If WC13, create a symbolic link to ROMS-JEDI source code path because we need access
# to ROMS header file during configuration and ROMS source code processing.

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

set( MY_HEADER_DIR ${ROMS_APP_DIR} )
set( MY_CPP_FLAGS ANALYTICAL_DIR='${ROMS_APP_DIR}';HEADER_DIR='${ROMS_APP_DIR}';ROOT_DIR='${CMAKE_CURRENT_SOURCE_DIR}/roms';MPI )
set( LIBTYPE SHARED )
set( ROMS_EXECUTABLE OFF )
set( MPI ON )

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

 ecbuild_bundle( PROJECT roms       GIT "https://github.com/JCSDA-internal/roms_src.git"     BRANCH master  UPDATE )
 ecbuild_bundle( PROJECT oops       GIT "https://github.com/jcsda-internal/oops.git"         BRANCH develop UPDATE )
#ecbuild_bundle( PROJECT vader      GIT "https://github.com/jcsda-internal/vader.git"        BRANCH develop UPDATE )
 ecbuild_bundle( PROJECT saber      GIT "https://github.com/jcsda-internal/saber.git"        BRANCH develop UPDATE )

 ecbuild_bundle( PROJECT gsw        GIT "https://github.com/jcsda-internal/GSW-Fortran.git"  BRANCH develop UPDATE )
 ecbuild_bundle( PROJECT ioda       GIT "https://github.com/jcsda-internal/ioda.git"         BRANCH develop UPDATE )
 ecbuild_bundle( PROJECT ufo        GIT "https://github.com/jcsda-internal/ufo.git"          BRANCH develop UPDATE )

 ecbuild_bundle( PROJECT roms-jedi  SOURCE ../ )

# Finalize bundle

ecbuild_bundle_finalize()
