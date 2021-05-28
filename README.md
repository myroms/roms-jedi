# ROMS interface to JEDI

The following instructions should have the steps needed to implement an interface capable of
running some of the basic JEDI applications, as well as the available data assimilation drivers.


To get started:

1. Check out the ROMS source code repository. It is highly recommended to clone to the default
   destination sub-directories `<source_dir=roms_src>`, `<interface_dir=roms-jedi>`, and
   `<project_dir=jediroms_wc13>`. They need to be located in the same user's root directory
   `<root_dir>` if using relative paths. The source code includes ROMS nonlinear model (NLM),
   perturbation tangent linear model (TLM), finite-amplitude tangent linear model (RPM), and
   adjoint model (ADM) kernels.

   ```
   git clone https://github.com/JCSDA-internal/roms_src.git                             (default)
   git clone https://github.com/JCSDA-internal/roms_src.git <source_dir>
   ```

2. Check out the ROMS-JEDI interface repository

   ```
   git clone https://github.com/JCSDA-internal/roms-jedi.git                            (default)
   git clone https://github.com/JCSDA-internal/roms-jedi roms-jedi.git <interface_dir>
   ```

3. Check out the ROMS-JEDI application repository

   ```
   git clone https://www.myroms.org/git/jediroms_wc13                                   (default)
   git clone https://www.myroms.org/git/jediroms_wc13 <project_dir>
   ```

4. Set environmental variables to load JEDI modules. In orion we need:

   ```
   setenv JEDI_OPT /work/noaa/da/grubin/opt/modules
   module use ${JEDI_OPT}/modulefiles/core
   module load jedi/intel-impi
   ```

5. Set environmental variables for the ROMS root directory `ROMS_HOME` where roms_src was
   was installed and it build directory `ROMS_BUILD_DIR` at the command line or loggin script.
   Also, ROMS needs `NF_CONFIG` for the location of the NetCDF Fortran utility for compiling
   and linking:

   ```
   setenv ROMS_HOME <root_dir>
   setenv ROMS_BUILD_DIR ${ROMS_HOME}/jediroms_wc13/JEDI/CBuild_roms
   setenv NF_CONFIG ${NETCDF}/bin/nf-config
   ```

6. Create ROMS shared library `libROMS.so` configured for US West COAST application WC13, which
   will be used to test the ROMS-JEDI interface.  ROMS is configured with all the C-preprocessing
   options to run the Restricted, B-preconditioned Lanczos 4D-Var (RBL4D-Var), strong or weak
   constraint data assimilation algorithm (check: www.myroms.org/wiki/RBL4D-Var_Tutorial).  The
   shared library includes the NLM, TLM, and ADM kernels. Primarily, ROMS needs the NetCDF library.
   Some applications may require additional libraries. Check www.myroms.org/wiki/External_Libraries
   for more information. Customize `cbuild_roms.sh` to change options and the compiler; see `FORT`
   environmental variable. This step needs to be done only once per application.  

   ```
   cd ${ROMS_HOME}                                !> root directory where roms_src is installed
   cd jediroms_wc13/JEDI                          !> ROMS-JEDI application directory
   cbuild_roms.sh -j 10                           !> CMake script to compile ROMS (default ifort)
   ```

7. Setup the ROMS-JEDI build directory. For simplicity, and unlike other current JEDI projects, the bundle
   `CMakeLists.txt` is actually present in this repository at `bundle` sub-directory instead of in a separate
   repository (Feel free to make the bundle a separate repository for your project if you wish).

   ```
   cd roms-jedi                                   !> ROMS-JEDI interface directory, <interface_dir>
   mkdir build
   cd build
   ecbuild -DMPIEXEC_EXECUTABLE="/opt/slurm/bin/srun" -DMPIEXEC_NUMPROC_FLAG="-n" -DROMS_BUILD_DIR=$ROMS_BUILD_DIR ../bundle
   make update
   ```

8. Compile, and run the unit tests

   ```
   make -j 10
   cd roms-jedi                                   !> sub-directory: <interface_dir>/build/roms-jedi
   ctest -N
   ```

   NOTE: In `<interface_dir>/build/roms-jedi/test` there is a `orion_tests.sh` to run the unit tests
         using SLURM in orion. Customize that script for desired unit tests.

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
