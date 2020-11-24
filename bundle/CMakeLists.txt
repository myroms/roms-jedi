# (C) COPYRIGHT 2018-2019 UCAR
#
# THIS SOFTWARE IS LICENSED UNDER THE TERMS OF THE APACHE LICENCE VERSION 2.0
# WHICH CAN BE OBTAINED AT HTTP://WWW.APACHE.ORG/LICENSES/LICENSE-2.0.

#
# SOCAROMS-BUNDLE
#

project( SOCAROMS-bundle C CXX Fortran )

cmake_minimum_required( VERSION 3.8 FATAL_ERROR )
include( ecbuild_bundle )

set( ECBUILD_DEFAULT_BUILD_TYPE RelWithDebInfo )
set( ENABLE_MPI ON CACHE BOOL "Compile with MPI" )

ecbuild_bundle_initialize()
ecbuild_requires_macro_version( 2.7 )

# Optional repositories
option( BUILD_ECKIT "download and build eckit (not needed if in a jedi container)" )
if ( BUILD_ECKIT )
  ecbuild_bundle( PROJECT eckit         GIT "https://github.com/jcsda-internal/eckit.git"           UPDATE BRANCH release-stable )
endif ()

# required repositories
ecbuild_bundle( PROJECT fckit           GIT "https://github.com/jcsda-internal/fckit.git"           UPDATE BRANCH release-stable )
ecbuild_bundle( PROJECT atlas           GIT "https://github.com/jcsda-internal/atlas.git"           UPDATE BRANCH release-stable )
ecbuild_bundle( PROJECT oops            GIT "https://github.com/jcsda-internal/oops.git"            UPDATE BRANCH develop )
ecbuild_bundle( PROJECT saber           GIT "https://github.com/jcsda-internal/saber.git"           UPDATE BRANCH develop )
ecbuild_bundle( PROJECT ioda            GIT "https://github.com/jcsda-internal/ioda.git"            UPDATE BRANCH develop )
ecbuild_bundle( PROJECT ioda-converters GIT "https://github.com/jcsda-internal/ioda-converters.git" UPDATE BRANCH develop )
ecbuild_bundle( PROJECT ufo             GIT "https://github.com/jcsda-internal/ufo.git"             UPDATE BRANCH develop )
ecbuild_bundle( PROJECT socaroms         SOURCE ../)

ecbuild_bundle_finalize()
