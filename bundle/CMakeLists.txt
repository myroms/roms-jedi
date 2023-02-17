# (C) COPYRIGHT 2018-2023 UCAR
#
# THIS SOFTWARE IS LICENSED UNDER THE TERMS OF THE APACHE LICENCE VERSION 2.0
# WHICH CAN BE OBTAINED AT HTTP://WWW.APACHE.ORG/LICENSES/LICENSE-2.0.

#-------------------------------------------------------------------------------
#
# ROMS-BUNDLE
#
# To build the roms-jedi interface use:
# 
#   mkdir build
#   cd build
#
#   ecbuild -DMPIEXEC_EXECUTABLE=$MPIRUN -DMPIEXEC_NUMPROC_FLAG="-n" -DROMS_BUILD_DIR=$ROMS_BUILD_DIR -DCMAKE_BUILD_TYPE=Release ../bundle
#
# or
#
#   mkdir build_debug
#   cd build_debug
#   ecbuild -DMPIEXEC_EXECUTABLE=$MPIRUN -DMPIEXEC_NUMPROC_FLAG="-n" -DROMS_BUILD_DIR=$ROMS_BUILDG_DIR  -DCMAKE_BUILD_TYPE=Debug ../bundle
#
#-------------------------------------------------------------------------------

cmake_minimum_required( VERSION 3.12 FATAL_ERROR)

find_package( ecbuild 3.6 REQUIRED HINTS ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/../ecbuild)

project( roms-jedi VERSION 1.0.0 LANGUAGES C CXX Fortran )

include( ecbuild_bundle )

# Default release mode

set( ECBUILD_DEFAULT_BUILD_TYPE Release )

# Define bundle

ecbuild_bundle_initialize()

# Use external jedi-cmake or build in bundle

if(DEFINED ENV{jedi_cmake_ROOT})
  include( $ENV{jedi_cmake_ROOT}/share/jedicmake/Functions/git_functions.cmake )
else()
  ecbuild_bundle( PROJECT jedicmake GIT "https://github.com/jcsda-internal/jedi-cmake.git" BRANCH develop UPDATE RECURSIVE )
  include( jedicmake/cmake/Functions/git_functions.cmake )
endif()

# Required repositories

 ecbuild_bundle( PROJECT oops       GIT "https://github.com/jcsda-internal/oops.git"         BRANCH develop UPDATE )
#ecbuild_bundle( PROJECT vader      GIT "https://github.com/jcsda-internal/vader.git"        BRANCH develop UPDATE )
 ecbuild_bundle( PROJECT saber      GIT "https://github.com/jcsda-internal/saber.git"        BRANCH develop UPDATE )

 ecbuild_bundle( PROJECT gsw        GIT "https://github.com/jcsda-internal/GSW-Fortran.git"  BRANCH develop UPDATE )
 ecbuild_bundle( PROJECT ioda       GIT "https://github.com/jcsda-internal/ioda.git"         BRANCH develop UPDATE )
 ecbuild_bundle( PROJECT ufo        GIT "https://github.com/jcsda-internal/ufo.git"          BRANCH develop UPDATE )

#ecbuild_bundle( PROJECT roms-jedi  GIT "https://github.com/JCSDA-internal/roms_src.git"     BRANCH master  UPDATE )
 ecbuild_bundle( PROJECT roms-jedi  SOURCE ../)

ecbuild_bundle_finalize()
