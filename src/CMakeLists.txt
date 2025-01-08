# (C) Copyright 2019-2025 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

add_subdirectory( romsjedi )
add_subdirectory( mains )

# Add the CPP coding norms test
##############################################################################

# find cpplint.py, if not found assume it will be built by oops in this bundle

find_file(CPPLINT_PY cpplint.py HINTS ${OOPS_PATH}/bin)
if(NOT CPPLINT_PY)
  set(CPPLINT_PY ${CMAKE_BINARY_DIR}/bin/cpplint.py)
endif()

ecbuild_add_test( TARGET romsjedi_coding_norms
                  TYPE SCRIPT
                  COMMAND ${CPPLINT_PY}
                  ARGS --quiet --recursive ${CMAKE_CURRENT_SOURCE_DIR}
                  WORKING_DIRECTORY ${CMAKE_BINARY_DIR}/bin )
