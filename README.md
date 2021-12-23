# ROMS interface to JEDI

The following instructions should have the steps needed to implement an interface capable of
running some of the basic JEDI applications, as well as the available data assimilation drivers.


### To get started:

-  Check out the ROMS source code from GitHub repository. It is highly recommended to clone
   to the default destination sub-directories: **`<source_dir=roms_src>`**, **`<interface_dir=roms-jedi>`**,
   and **`<project_dir=jediroms_wc13>`**. If using relative paths, they need to be located in the
   same user's root directory **`<root_dir>`**. The source code includes ROMS nonlinear model
   (**NLM**), perturbation tangent linear model (**TLM**), finite-amplitude tangent linear model
   (**RPM**), and adjoint model (**ADM**) kernels. For any **`ROMS-JEDI`** application, activate the
   **`JEDI`** C-preprocessing option when compiling ROMS to include the **NLM**, **TLM**, **ADM** kernels,
   and direct interface to the **`ROMS_initialize`**, **`ROMS_run`**, and **`ROMS_finalize`** driver phases.

   ```
   git clone https://github.com/JCSDA-internal/roms_src.git                             (default)
   git clone https://github.com/JCSDA-internal/roms_src.git <source_dir>
   ```

-  Check out the **`ROMS-JEDI`** interface repository.

   ```
   git clone https://github.com/JCSDA-internal/roms-jedi.git                            (default)
   git clone https://github.com/JCSDA-internal/roms-jedi roms-jedi.git <interface_dir>
   ```

-  Check out the **`ROMS-JEDI`** application repository. We are using a one-third-degree US West
   Coast (**WC13**) application. See https://www.myroms.org/wiki/4DVar_Tutorial_Introduction
   for detailed information about the **WC13** configuration.

   ```
   git clone https://www.myroms.org/git/jediroms_wc13                                   (default)
   git clone https://www.myroms.org/git/jediroms_wc13 <project_dir>
   ```

- Set environmental variables to load JEDI modules. For example, in **orion** supercomputer we need:

   ```
   setenv JEDI_OPT /work/noaa/da/grubin/opt/modules
   module use ${JEDI_OPT}/modulefiles/core
   module load jedi/intel-impi
   ```

-  Set environmental variables for the ROMS root directory **`ROMS_HOME`** (where **`roms_src`** was
   installed) and its build directory **`ROMS_BUILD_DIR`** or **`ROMS_BUILDG_DIR`** at the command line
   or in your login script. Also, ROMS needs **`NF_CONFIG`** for the location of the NetCDF Fortran
   utility for compiling and linking.  We also like to define the **`MPIRUN`** environmental variable
   to specify the **MPI** executable in a particular computer (say, **`srun`**, **`mpirun`**, etc.).
   We need the full path for **`ctest`** to work.
   ```
   setenv ROMS_HOME       <root_dir>
   setenv ROMS_BUILD_DIR  ${ROMS_HOME}/jediroms_wc13/JEDI/CBuild_roms         (Release build type)
   setenv ROMS_BUILDG_DIR ${ROMS_HOME}/jediroms_wc13/JEDI/CBuild_romsG        (debug build type)
   setenv NF_CONFIG       ${NETCDF}/bin/nf-config
   setenv MPIRUN          /opt/slurm/bin/srun                                 (orion SLURM)
   ```

-  Create ROMS shared library **`libROMS.so`** configured for US West Coast application **WC13**, which
   will be used to test the **`ROMS-JEDI`** interface. The shared library includes the **NLM**, **TLM**,
   and **ADM** kernels. Primarily, ROMS needs the NetCDF library. Some applications may require additional
   libraries. Check www.myroms.org/wiki/External_Libraries for more information. Customize
   **`cbuild_roms.sh`** to change options and the compiler; see **`FORT`** environmental variable. This
   step needs to be done only once per application.  

   ```
   cd ${ROMS_HOME}                                !> root directory where roms_src is installed
   cd jediroms_wc13/JEDI                          !> ROMS-JEDI application directory
   cbuild_roms.sh -j 10                           !> CMake script to compile ROMS (default ifort)
   ```
   It is advisable to keep the **`roms_src`** repository up to date.  If changes are found, you need to recompile
   and generate an updated **`libROMS.so`** shared library.

-  Setup the **`ROMS-JEDI`** build directory. For simplicity, and unlike other current JEDI projects, the bundle
   **`CMakeLists.txt`** is actually present in this repository at **`bundle`** sub-directory instead of in a separate
   repository (Feel free to make the bundle a separate repository for your project if you wish).

   ```
   cd roms-jedi                                   !> ROMS-JEDI interface directory, <interface_dir>
   mkdir build
   cd build
   ecbuild -DMPIEXEC_EXECUTABLE=$MPIRUN -DMPIEXEC_NUMPROC_FLAG="-n" -DROMS_BUILD_DIR=$ROMS_BUILD_DIR -DCMAKE_BUILD_TYPE=Release ../bundle
   make update
   ```

   If debugging, use:

   ```
   ecbuild -DMPIEXEC_EXECUTABLE=$MPIRUN -DMPIEXEC_NUMPROC_FLAG="-n" -DROMS_BUILD_DIR=$ROMS_BUILDG_DIR -DCMAKE_BUILD_TYPE=debug ../bundle
   ```

   Some computer system requires additional **MPI** flags.  Use the **`MPI_ARGS`** macro:

   ```
   ecbuild -DMPIEXEC_EXECUTABLE=$MPIRUN -DMPI_ARGS="--mpi=pmi2" -DMPIEXEC_NUMPROC_FLAG="-n" -DROMS_BUILD_DIR=$ROMS_BUILD_DIR -DCMAKE_BUILD_TYPE=Release ../bundle
   ```

-  Compile, and run the Unit Tests.

   ```
   make -j 10
   cd roms-jedi                                   !> sub-directory: <interface_dir>/build/roms-jedi
   ctest -N
   ```

   NOTE: In subdirectory **`<interface_dir>/build/roms-jedi/test`** there are examples of scripts to run the Unit
         Tests using SLURM (**`orion_tests.sh`**) or regular batch or non-SLURM (**`batch_tests.sh`**) computers.
         Customize those scripts to run specific Unit Test(s) with **`ctest`** or manually.

### Implemend and Tested ROMS-JEDI Classes:

-  AnalyticInit
-  ErrorCovariance
-  Geometry
-  GeometryIterator
-  GetValues
-  Fields
-  Increment
-  LinearModel:  Need to address a couple of technical issues with the TL/AD increment exchange with OOPS
-  LinearVariableChange
-  Model
-  ModelBias
-  State
-  VariableChange

## JEDI Applications

This is a list of the applications (roughly in order from simplest to hardest to implement), along
with which unit tests should be implemented and have passing before attempting to compile and run the application.

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
that need to be implemented.

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
- Model
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
