# (C) COPYRIGHT 2018-2022 UCAR
#
# THIS SOFTWARE IS LICENSED UNDER THE TERMS OF THE APACHE LICENCE VERSION 2.0
# WHICH CAN BE OBTAINED AT HTTP://WWW.APACHE.ORG/LICENSES/LICENSE-2.0.

#
# ROMS-BUNDLE
#

cmake_minimum_required( VERSION 3.12)
project( roms-jedi VERSION 1.0.0 LANGUAGES C CXX Fortran )

find_package( ecbuild 3.3.2 QUIET)
include( ecbuild_bundle )

ecbuild_bundle_initialize()

ecbuild_bundle( PROJECT jedicmake       GIT "https://github.com/jcsda-internal/jedi-cmake.git"      UPDATE BRANCH develop )
include( jedicmake/cmake/Functions/git_functions.cmake  )

# required repositories

ecbuild_bundle( PROJECT oops            GIT "https://github.com/jcsda-internal/oops.git"            UPDATE BRANCH develop )
ecbuild_bundle( PROJECT saber           GIT "https://github.com/jcsda-internal/saber.git"           UPDATE BRANCH develop )
ecbuild_bundle( PROJECT ioda            GIT "https://github.com/jcsda-internal/ioda.git"            UPDATE BRANCH develop )
ecbuild_bundle( PROJECT gsw             GIT "https://github.com/jcsda-internal/GSW-Fortran.git"     UPDATE BRANCH develop )
ecbuild_bundle( PROJECT ufo             GIT "https://github.com/jcsda-internal/ufo.git"             UPDATE BRANCH develop )
ecbuild_bundle( PROJECT roms-jedi       SOURCE ../)

ecbuild_bundle_finalize()
