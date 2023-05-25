# ROMS interface to JEDI

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;![roms-jedi logo](https://www.myroms.org/trac/ROMS-JEDI_400px.png)

![roms-jedi logo](https://www.myroms.org/trac/roms_jedi_600px.png)

The following instructions should have the steps needed to implement an interface capable of
running some of the basic JEDI applications, as well as the available data assimilation drivers.


### To get started:

-  Check out the **`ROMS-JEDI`** interface repository.

   ```
   git clone https://github.com/JCSDA-internal/roms-jedi.git                            (default)
   git clone https://github.com/JCSDA-internal/roms-jedi roms-jedi.git <interface_dir>
   ```

   During configuration, the latest version of **`ROMS`** source code is downloaded from
   https://github.com/JCSDA-internal/roms_src.git. The source code includes ROMS nonlinear model
   (**NLM**), perturbation tangent linear model (**TLM**), finite-amplitude tangent linear model
   (**RPM**), and adjoint model (**ADM**) kernels. For any **`ROMS-JEDI`** application, activate
   the **`JEDI`** C-preprocessing option when configuring **`ROMS`** header file to include the
   **NLM**, **TLM**, **ADM** kernels, and direct interface to the **`ROMS_initialize`**,
   **`ROMS_run`**, and **`ROMS_finalize`** driver phases.

-  By default, **`ROMS-JEDI`** is configured with a coarse (54x53x30 grid points) US West Coast
   (**WC13**) application. See https://www.myroms.org/wiki/4DVar_Tutorial_Introduction for detailed
   information about the **WC13** configuration. However, any other ROMS application can be
   configured by including in the **ecbuild** command the directives **`-DROMS_APP="MyAppCPP"`** and
   **`-DROMS_APP_DIR="MyAppDirPath"`**.

-  Make sure that you computer have installed the **`jedi-stack`** software for either **gfortran**
   or **ifort** containing several packages need to run the **`ROMS-JEDI`** interface. For more
   information, please check https://github.com/JCSDA-internal/jedi-stack.

   In our computers at Rutgers University, the **`jedi-stack`** can be loaded by executing either:

   ```
   > module purge;  module load stack-gcc;    module list                     (gfortran compiler)
   > module purge;  module load stack-intel;  module list                     (ifort compiler)
   ```

   Installing the **`jedi-stack`** is not trivial and requires computer software expertise.

-  We also like to define the **MPIRUN** environmental variable to specify the **MPI** executable in
   a particular computer (say, **srun**, **mpirun**, etc.). We need the full path for **ctest** to work.
   For example,
   ```
   setenv MPIRUN /opt/slurm/bin/srun
   ```
   Notice that we specify this executable in the **ecbuid** command.

-  Several environmental variables can be activated for **verbose debugging** of the building blocks
   for the **`ROMS-JEDI`** interface: (use **1** or **true** to activate and **0** or **false**
   to deactivate)
   ```
   setenv LdebugGeometry             1
   setenv LdebugAnalyticInit         1
   setenv LdebugField                1
   setenv LdebugFields               1
   setenv LdebugFieldsUtils          1
   setenv LdebugGeometry             1
   setenv LdebugLinearModel          1
   setenv LdebugLinearModel2Geovals  1
   setenv LdebugModel                1
   setenv LdebugModel2Geovals        1
   setenv LdebugTrajectory           1
   ```

-  Our strategy is to create a **Bundle** and **build** subdirectory for each application. For **WC13**
   (default), we create **Bundle_wc13** and **build_wc13** below. Please follow the following steps to
   configure **`ROMS-JEDI`** in your computer:

   ```
   git clone https://github.com/JCSDA-internal/roms-jedi.git

   cd roms-jedi                                   !> ROMS-JEDI interface directory, <interface_dir>
   mkdir Bundle_wc13
   cp bundle/.gitignore bundle/CMakeLists.txt Bundle_wc13
   mkdir build_wc13
   cd build_wc13

   ecbuild -DMPIEXEC_EXECUTABLE=$MPIRUN -DMPIEXEC_NUMPROC_FLAG="-n" ../Bundle_wc13
   make -j 10

   cd roms-jedi                                   !> sub-directory: <interface_dir>/build_wc13/roms-jedi
   ctest -N                                       !> lists all the Unit Tests available
   ctest -E -V get_                               !> runs all the Unit Tests

   cd test/Data                                   !> sub-directory: <interface_dir>/build_wc13/roms-jedi/test/Data
                                                  !> to check the results in various sub-directories
   ```

-  For example, if running the US East Coast **DOPPIO** application (240x104x40 grid points) or any other, please follow
   the following steps to configure **`ROMS-JEDI`**:


   ```
   cd roms-jedi                                   !> ROMS-JEDI interface directory, <interface_dir>
   mkdir Bundle_doppio
   cp bundle/.gitignore bundle/CMakeLists.txt Bundle_doppio
   mkdir build_doppio
   cd build_doppio

   ecbuild -DMPIEXEC_EXECUTABLE=$MPIRUN -DMPIEXEC_NUMPROC_FLAG="-n" -DROMS_APP="DOPPIO" -DROMS_APP_DIR="DOPPIOpath" ../Bundle_doppio
   make -j 10

   cd roms-jedi                                   !> sub-directory: <interface_dir>/build_doppio/roms-jedi
   ctest -N                                       !> lists all the Unit Tests available
   ctest -E -V get_                               !> runs all the Unit Test

   cd test/Data                                   !> sub-directory: <interface_dir>/build_doppio/roms-doppio/test/Data
                                                  !> to check the results in various sub-directories
   ```

-  The **ecbuild** command builds by default the **Release** (optimized) version of **`JEDI`** and **`ROMS-JEDI`**. However, if
   debugging (**-g** option) include the directive **`-DCMAKE_BUILD_TYPE=debug`** to the **ecbuild** command.

-  Any **`ROMS`** application can be run in **`ROMS-JEDI`** by specifying the appropriate CPP option and necessary input files. Only
   **WC13** is provided with the interface. However, we facilitate how to run such applications. Notice that the **WC13**
   configuration and input files are located in **`roms-jedi/test/Applications/wc13`**. The template input YAML files are located
   **`roms-jedi/test/templates`**. We use a **Perl** script to create the application input YAML files from the templates. Please
   check in **`roms-jedi/test/Applications/wc13/testinput`**.