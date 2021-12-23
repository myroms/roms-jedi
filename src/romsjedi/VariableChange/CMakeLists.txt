#include_directories( ${CMAKE_CURRENT_SOURCE_DIR} )

# the source code in this directory,
# all other files are handled through the subdirectory's respective CMakeLists.txt

roms_target_sources(
  VariableChange.cc
  VariableChange.h
)

# add source code in the subdirectories

add_subdirectory(Base)
add_subdirectory(Model2GeoVaLs)
