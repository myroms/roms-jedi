# ROMS interface to JEDI

The following instructions should have the steps needed to implement an interface capable of
running some of the basic JEDI applications, as well as the LETKF data assimilation application.
(Instructions for the variational DA applications are still in the works).

To get started:

1. Checkout this repository
   ```
   git clone https://github.com/JCSDA-internal/roms-jedi <source_dir>
   ```
2. setup the build directory. For simplicity, and unlike other current JEDI projects, the bundle
   `CMakeLists.txt` is actually present in this repository at `bundle/` instead of in a separate
   repository (Feel free to make the bundle a separate repository for your project if you wish).
   ```
   cd ../
   mkdir <build_dir>
   cd <build_dir>
   ecbuild ../<source_dir>/bundle
   ```
3. Compile, and run the unit tests. At this point, only the `Geometry` test is enabled, and it
   will fail until you start implementing the interface.
   ```
   cd <proj_name>
   make -j4
   ctest
   ```

## JEDI Applications

This is a list of the applications (roughly in order from simplest to hardest to implement), along
with which unit tests should be implemented and have passing before attempting to compile and run the application. First,
decide which application you want to get working. Then, ensure the associated unit tests pass ( see "Unit Tests" section below).
Last, the application can be built by uncommenting the appropriate lines in the `src/mains/CMakeLists.txt` file. Note, the unit
tests dont seem to cover all the aspects of the interface required by the applications, so even if your unit tests pass you might
still have to implement more class methods

### hofx_nomodel.x

- TestGeometry
- TestState
- TestGetValues

### forecast.x

- TestGeometry
- TestModel
- TestState

### makeobs.x

- TestGeometry
- TestState
- TestGetValues

### hofx.x

- TestGeometry
- TestModel
- TestState

### dirac.x

### letkf.x

- TestGeometry
- TestGeometryIterator
- TestIncrement
- TestState

### staticbinit.x

- TestCovariance
- TestGeometry
- TestIncrement
- TestState

### var.x

## Unit Tests

The following is a list of the unit tests (in alphabetical order), along with a list of the required interface classes
that need to be implemented. ( This does not include already implemented interfaces provided by UFO and IODA.).

To get a unit test working:
1. uncomment the desired test from `test/CmakeLists.txt`
2. uncomment the required classes in `src/<proj_name>/Traits.h` and `src/<proj_name>/CMakeLists.txt`
3. hopefully at this point it is able to compile..
4. Running `ctest` within `<build_dir>/<proj_name>/` should run the test, but it will fail. Running
   ctest with the `-V` option will allow you to see the output. There should be errors explicitly telling you
   which class methods need to be implemented. Also, model specific parameters will need to be added to the input
   `test/testinput/interface.yml`


### TestErrorCovariance

- Covariance
- Geometry
- Increment
- State

### TestGeometry

- Geometry

### TestGeometryIterator

- Geometry
- GeometryIterator
- Increment

### TestGetValues

- Geometry
- State
- GetValues

### TestIncrement

- Geometry
- Increment
- State

### TestLinearGetValues

- Geometry
- Increment
- LinearGetValues
- State

### TestLinearModel

- Covariance
- Geometry
- Increment
- ModelAuxControl
- ModelAuxIncrement
- State

### TestModel

- Geometry
- Model (Note: will compile without, but won't run)
- ModelAuxControl
- State

### TestModelAuxControl

- Geometry
- ModelAuxControl

### ModelAuxCovariance

- Geometry
- ModelAuxCovariance

### ModelAuxIncrement

- Geometry
- ModelAuxCovariance
- ModelAuxIncrement

### TestState

- Geometry
- State
