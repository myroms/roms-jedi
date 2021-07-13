#include_directories( ${CMAKE_CURRENT_SOURCE_DIR} )

# the source code in this directory,
# all other files are handled through the subdirectory's respective CMakeLists.txt

list( APPEND roms_src_files
  Traits.h
  Fortran.h
)

# a convenience frunction to make adding source files from subdirectories easier
# (To keep from having to use the full path every time)

function(roms_target_sources)
  foreach( src IN LISTS ARGN)
    target_sources(roms PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/${src})
  endforeach()
endfunction()

# the main library for this interface

ecbuild_add_library( TARGET   roms
                     SOURCES  ${roms_src_files}
                     INSTALL_HEADERS LISTED
                     LINKER_LANGUAGE ${ROMS_LINKER_LANGUAGE}
                    )

target_include_directories(roms PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/..>
  $<INSTALL_INTERFACE:include/roms>)

target_compile_features( roms PUBLIC cxx_std_11 )

target_link_libraries( roms PUBLIC NetCDF::NetCDF_Fortran )
target_link_libraries( roms PUBLIC fckit )
target_link_libraries( roms PUBLIC atlas )
target_link_libraries( roms PUBLIC atlas_f )
target_link_libraries( roms PUBLIC gsw )
target_link_libraries( roms PUBLIC oops )
target_link_libraries( roms PUBLIC saber )
target_link_libraries( roms PUBLIC ioda )
target_link_libraries( roms PUBLIC ufo )

# add source code in the subdirectories

add_subdirectory(AnalyticInit)
add_subdirectory(Fields)
add_subdirectory(Geometry)
add_subdirectory(GeometryIterator)
add_subdirectory(GetValues)
add_subdirectory(Increment)
add_subdirectory(State)
add_subdirectory(VariableChanges)

# TODO(template_impl) add_subdirectory(Covariance)
# TODO(template_impl) add_subdirectory(Model)
# TODO(template_impl) add_subdirectory(ModelAux)
