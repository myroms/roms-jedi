# (C) Copyright 2017-2021 UCAR.
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# The source code in this directory. ll other files are handled through the
# sub-directory respective CMakeLists.txt

#include_directories( ${CMAKE_CURRENT_SOURCE_DIR} )

list( APPEND roms_src_files
  Traits.h
  Fortran.h
)

# A convenience function to make adding source files from subdirectories easier
# (To keep from having to use the full path every time)

function(roms_target_sources)
  foreach( src IN LISTS ARGN)
    target_sources(romsjedi PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/${src})
  endforeach()
endfunction()

# The main library for this interface

ecbuild_add_library( TARGET   romsjedi
                     SOURCES  ${roms_src_files}
                     INSTALL_HEADERS LISTED
                     LINKER_LANGUAGE ${ROMS_LINKER_LANGUAGE}
                    )

target_include_directories(romsjedi PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/..>
  $<INSTALL_INTERFACE:include/romsjedi>)

target_compile_features( romsjedi PUBLIC cxx_std_11 )

target_link_libraries( romsjedi PUBLIC NetCDF::NetCDF_Fortran )
target_link_libraries( romsjedi PUBLIC fckit )
target_link_libraries( romsjedi PUBLIC atlas )
target_link_libraries( romsjedi PUBLIC atlas_f )
target_link_libraries( romsjedi PUBLIC gsw )
target_link_libraries( romsjedi PUBLIC oops )
target_link_libraries( romsjedi PUBLIC saber )
target_link_libraries( romsjedi PUBLIC ioda )
target_link_libraries( romsjedi PUBLIC ufo )

# Add source code in the sub-directories

add_subdirectory(AnalyticInit)
add_subdirectory(Fields)
add_subdirectory(Geometry)
add_subdirectory(GeometryIterator)
add_subdirectory(GetValues)
add_subdirectory(Increment)
add_subdirectory(Model)
add_subdirectory(ModelBias)
add_subdirectory(State)
add_subdirectory(VariableChanges)

# TODO(template_impl) add_subdirectory(Covariance)

