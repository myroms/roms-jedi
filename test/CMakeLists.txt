list( APPEND socaroms_test_input
  testinput/geometry.yml
  testinput/errorcovariance.yml
  testinput/geometryiterator.yml
  testinput/getvalues.yml
  testinput/lineargetvalues.yml
  testinput/linearmodel.yml
  testinput/increment.yml
  testinput/model.yml
  testinput/modelaux.yml
  testinput/state.yml
  )


# link the input files for the tests
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/testinput)
foreach(FILENAME ${socaroms_test_input})
  execute_process(COMMAND ${CMAKE_COMMAND} -E create_symlink
    ${CMAKE_CURRENT_SOURCE_DIR}/${FILENAME}
    ${CMAKE_CURRENT_BINARY_DIR}/${FILENAME} )
endforeach()


#================================================================================
# Tests of class interfaces
#================================================================================

#ecbuild_add_test(
#  TARGET  test_socaroms_geometry
#  SOURCES executables/TestGeometry.cc
#  ARGS    testinput/geometry.yml
#  LIBS    socaroms )

# TODO(template_impl) ecbuild_add_test(
# TODO(template_impl)   TARGET  test_socaroms_state
# TODO(template_impl)   SOURCES executables/TestState.cc
# TODO(template_impl)   ARGS    testinput/state.yml
# TODO(template_impl)   LIBS    socaroms )

# TODO(template_impl) ecbuild_add_test(
# TODO(template_impl)   TARGET  test_socaroms_increment
# TODO(template_impl)   SOURCES executables/TestIncrement.cc
# TODO(template_impl)   ARGS    testinput/increment.yml
# TODO(template_impl)   LIBS    socaroms )

# TODO(template_impl) ecbuild_add_test(
# TODO(template_impl)   TARGET  test_socaroms_model
# TODO(template_impl)   SOURCES executables/TestModel.cc
# TODO(template_impl)   ARGS    testinput/model.yml
# TODO(template_impl)   LIBS    socaroms )

# TODO(template_impl) ecbuild_add_test(
# TODO(template_impl)   TARGET  test_socaroms_modelauxcontrol
# TODO(template_impl)   SOURCES executables/TestModelAuxControl.cc
# TODO(template_impl)   ARGS    testinput/modelaux.yml
# TODO(template_impl)   LIBS    socaroms )

# TODO(template_impl) ecbuild_add_test(
# TODO(template_impl)   TARGET  test_socaroms_getvalues
# TODO(template_impl)   SOURCES executables/TestGetValues.cc
# TODO(template_impl)   ARGS    testinput/getvalues.yml
# TODO(template_impl)   LIBS    socaroms )

# TODO(template_impl) ecbuild_add_test(
# TODO(template_impl)   TARGET  test_socaroms_lineargetvalues
# TODO(template_impl)   SOURCES executables/TestLinearGetValues.cc
# TODO(template_impl)   ARGS    testinput/lineargetvalues.yml
# TODO(template_impl)   LIBS    socaroms )

# TODO(template_impl) ecbuild_add_test(
# TODO(template_impl)   TARGET  test_socaroms_errorcovariance
# TODO(template_impl)   SOURCES executables/TestErrorCovariance.cc
# TODO(template_impl)   ARGS    testinput/errorcovariance.yml
# TODO(template_impl)   LIBS    socaroms )

# TODO(template_impl) ecbuild_add_test(
# TODO(template_impl)   TARGET  test_socaroms_modelauxcovariance
# TODO(template_impl)   SOURCES executables/TestModelAuxCovariance.cc
# TODO(template_impl)   ARGS    testinput/modelaux.yml
# TODO(template_impl)   LIBS    socaroms )

# TODO(template_impl) ecbuild_add_test(
# TODO(template_impl)   TARGET  test_socaroms_modelauxincrement
# TODO(template_impl)   SOURCES executables/TestModelAuxIncrement.cc
# TODO(template_impl)   ARGS    testinput/modelaux.yml
# TODO(template_impl)   LIBS    socaroms )

# TODO(template_impl) ecbuild_add_test(
# TODO(template_impl)   TARGET  test_socaroms_linearmodel
# TODO(template_impl)   SOURCES executables/TestLinearModel.cc
# TODO(template_impl)   ARGS    testinput/linearmodel.yml
# TODO(template_impl)   LIBS    socaroms )

# TODO(template_impl) ecbuild_add_test(
# TODO(template_impl)   TARGET  test_socaroms_geometryiterator
# TODO(template_impl)   SOURCES executables/TestGeometryIterator.cc
# TODO(template_impl)   ARGS    testinput/geometryiterator.yml
# TODO(template_impl)   LIBS    socaroms )
