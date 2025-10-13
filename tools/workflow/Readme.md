<img width="824" alt="image" src="https://github.com/user-attachments/assets/d15ec2a4-70e3-410f-a2ae-d09682a9f0f2">

This subdirectory contains several scripts designed to facilitate the configuration of
any **ROMS** application within the **ROMS-JEDI** data assimilation framework. By default,
the **ROMS-JEDI** interface utilizes the **ROMS** U.S. West Coast (**WC13**) application,
which has a horizontal resolution of approximately 30 km (**54**x**53**x**30**). This
application is also used to test all **ROMS** 
[native](https://www.myroms.org/wiki/4DVar_Tutorial_Introduction) **4D-Var** algorithms.

The purpose of these scripts is to provide a simple **workflow** mechanism for configuring other
regional **ROMS** applications, identified by their **CPP** options. Additionally, to automate
the setup process, which requires **YAML** files to run any of the data assimilation algorithms
with a dynamic set of observations that are changing for each analysis cycle in operational
applications.

The current plan is to develop an interface to automate the generation of input **YAML**
files for operational data assimilation cycles. **JEDI** provides more sophisticated **Python**-based
algorithms for the same purpose as **EWOK**, which requires specific data tanks that a regular
user may not have access to.

---

### JEDI Configuration Script: `jedi_config`

The **jedi_config.csh** or **jedi_config.sh** scripts create the application **`Bundle_suffix`**
and **`build_suffix`** working subdirectories, where **suffix** is a user identifier for the
application or solution. It also generates the appropriate **ecbuild** configuration command,
defining various macros for **CMake**.

``` c
jedi_config.sh suffix [options]

Options:

  suffix                   Bundle and build subdirectories identifier suffix
  
  -a app_name app_dir      Configure a user ROMS application
                              'app_name' is the ROMS application CPP option
                              'app_dir'  is the application data path

  -d                       Configure ecbuild with 'Debug' build type

  -n_min NP_min            Minimum Number of MPI processes for tests
                              NP_min = 2 by default

  -n NP                    Number of MPI processes, if using -a option
                              NP = 12 by default
  ```

The option **-a** adds the **`-DMPIEXEC_NUMPROC`=npets**, **`-DROMS_APP`=app_name**, and
**`-DROMS_APP_DIR`=app_dir** to the **ecbuild** command, and it indicates that the
default **`WC13`** application for the **ROMS-JEDI** interface is not configured. Thus,
you can omit the **-a** argument when configuring the default **WC13** application.

For example, to configure our Coupled Forecast Framework (**CFF**) configuration of the U.S. East Coast
([**USEC**](https://github.com/myroms/roms_test/blob/main/USEC/RBL4DVAR_mixres/Readme.md))
grids at 3km (**CFF-USEC3**), we get the following **ecbuild** command at the top directory
root where **ROMS-JEDI** was installed:

``` c
> cd roms-jedi
> jedi_config.sh usec3 -a USEC /home/arango/ROMS/JediApps/usec -n_min 4 -n 16

Current directory: /home/arango/ocean/repository/git/roms-jedi

Created subdirectory: Bundle_usec3
Created subdirectory: build_usec3

'bundle/.gitignore' -> 'Bundle_usec3/.gitignore'
'bundle/CMakeLists.txt' -> 'Bundle_usec3/CMakeLists.txt'

<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
To configure 'ecbuild' with 'Release' build, you need to type:

cd build_usec3;
ecbuild -DMPIEXEC_EXECUTABLE=$MPIRUN -DMPIEXEC_NUMPROC_FLAG="-n" -DMPIEXEC_NUMPROC_MIN=4 -DMPIEXEC_NUMPROC=16 -DPython3_EXECUTABLE="`which python3`" -DROMS_APP=USEC -DROMS_APP_DIR=/home/arango/ROMS/JediApps/usec -DCMAKE_BUILD_TYPE=Release ../Bundle_usec3
<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
```
As you can see, the **ecbuild** command is too long to type or remember from memory, which
makes this script valuable because we can copy and paste to configure.

> [!NOTE]  
> The copying and pasting of the above lines changes into the directory **build_usec3** first before executing
> the **ecbuild** command. If the configuration is successful, type **make -j 10** to compile
> and link all the **JEDI** building blocks. It will take around 10-15 minutes.

> [!IMPORTANT]  
> The created **Bundle_usec3** directory contains the main **CMakeList.txt** and the downloaded source
> code for all the **JEDI** building blocks that will be compiled and linked in the **build_usec3**
> subdirectory. All the algorithms will be executed from the **build_usec3** subdirectory.

The following subdirectories are associated with the **ROMS-JEDI** interface:

``` d
  roms-jedi/
           /Bundle_usec
           /build_usec
                      /roms-jedi
                                 /test
                                      /Data
                                           /usec
                                                /input
                                                /obs
                                      /testinput
                                      /testoutput
                                      /testref
```

The **Data** subdirectory will contain several subdirectories for storing the results:

``` d
Data/
     bump/
     bump_loc/
     difference/
     diffusion/
     dirac/
     ensembles/
     forecast/
     hofx/
     increment/
     letkf/
     makeobs/
     roms/
     trajectory/
     usec -> /home/arango/ROMS/JediApps/usec/
     3dvar/
     3dfgat/
     3denvar/
     3dhyb/
     4dfgat/
     4dvar/
```
---

### Creating ROMS-JEDI Input YAML Files: `template2yaml`

Each algorithm in **JEDI** uses a **YAML** input file to run an executable.  For example, to run the
**4D-Var** data assimilation, individually, we will use:

``` c
> cd roms-jedi
> cd build_usec3/roms-jedi/test
> mpirun -n 12 ../../bin/romsjedi_var.x testinput/4dvar_bump.yaml > & log & ; tail log
```
Alternatively, we may run the following **ctest** command:

``` c
> cd roms-jedi
> cd build_usec3/roms-jedi
> ctest -N                                       (list all available test cases)
> ctest -VV -R test_romsjedi_4dvar_bump
```

Creating all the input **YAML** files needed to run the **ROMS-JEDI** interface requires expertise and
knowledge of **JEDI** and data assimilation. The **Perl** script **`template2yaml.pl`** is provided
to facilitate the generation of all input **YAML** files from templates:

``` c
template2yaml.pl [options]

Usage:

  app_file                 ROMS application YAML parameters file (ASCII)
  
  src_dir                  Path for ROMS-JEDI source code

  -notest                  Disable regression testing of Unit Tests with reference files
                             (optional)

  -obs list                Use the comma-separated, case-insensitive list of observations
                             instead of those listed in app_file. The User can choose which
                             IODA observation types/files to include in the data assimilation
                             algorithm (optional). For instance:

                             - obs t,s,sst,adt,uv_codar                  

Examples:

  template2yam.pl app_file src_dir -notest -obs T,S,SST,ADT
or
  template2yaml.pl wc13_yaml_parameters.dat /home/arango/ocean/repository/git/roms-jedi
or
  template2yaml.pl myapp_yaml_parameters.dat ROOT_DIR/roms-jedi -notest -obs t,s,ts_glider,sst,sss,adt
```

The **`template2yaml.pl`** Perl script reads the **ROMS** **`app_file`** parameters
(ASCII file), which contains various key-value pairs (see file
[**wc13_yaml_parameters.dat**](https://github.com/myroms/roms-jedi/blob/cb295f9eb9aa7da5b8f214d7c11b2ef07702b09a/test/Applications/wc13/wc13_yaml_parameters.dat) including the values needed for the default **`WC13`** application).
These pairs, combined with the [**roms-jedi/test/templates**](https://github.com/myroms/roms-jedi/tree/develop/test/templates) files (extension **`.yaml.tmpl`**), generate all the necessary  **YAML** configuration files for the **ROMS-JEDI** interface.

Users can activate the **`-notest`** option to suppress the regression testing method, which
allows them to verify that newly introduced code changes, bug fixes, or updates do not negatively affect
the previous results of a **ROMS-JEDI** application. Regression testing requires reference files located
in the application subdirectory [**testref**](https://github.com/myroms/roms-jedi/tree/develop/test/Applications/wc13/testref).
It is important to frequently update these reference files when
restructuring the **JEDI** source code, changing configuration parameters, using different compilers, or
applying different parallel partitions. The users may deactivate regression testing when using a generic
**ROMS** application. This **Perl** script with the **`-notest`** option will comment out the test block in the
input **YAML** files, suppressing regression testing. For instance:

```
#test:
#  reference filename: testref/4dvar_bump.ref
#  float relative tolerance: 1.0e-3
#  log output filename: testoutput/4dvar_bump.log
#  test output filename: testoutput/4dvar_bump.out
```

The user can utilize the **-obs** token to specify a list of comma-separated, case-insensitive observation types
included in multiple **IODA** files for use in the **JEDI** data assimilation algorithms. **No blank spaces between
list members are allowed** because **Perl** will identify them as separate tokens. There are two methods to define this list. 

In the provided **app_file**, the observation types can be specified using the **`__OBSERVATIONS__`** token, as shown below:

```d
# ROMS-JEDI data assimilation NetCDF-4 (IODA Version 3) for the input observations.
# The observations are separated by type and platform to facilitate processing by various UFO operators.

__OBSERVATIONS__               T,S,SST,ADT
```

Users can override the default observation list using the optional **-obs** argument while running the **`template2yaml.pl` Perl** script.
This list of unique keywords can be associated with **IODA** filenames and can be easily expanded to include other types of observations and files.
Currently, we anticipate the following keywords:

| Keyword       | Observation Type                 | IODA file Example |
|---------------|----------------------------------|-------------------|
| **ADT**       | SSH Altimetry                | **myapp**_adt_yyyymmdd.nc4  |
| **S**         | Salinity                     | **myapp**_salt_yyyymmdd.nc4 |
| **SSS**       | Satellite Salinity           | **myapp**_sss_yyyymmdd.nc4 |
| **SST**       | Satellite Temperature        | **myapp**_sst_yyyymmdd.nc4 |
| **T**         | Tempetature                  | **myapp**_temp_yyyymmdd.nc4 |
| **TS**        | Temperature/Salinity profile | **myapp**_TS_yyyymmdd.nc4 |
| **TS_GLIDER** | Temperature/Salinity glider  | **myapp**_TS_glider_yyyymmdd.nc4 |
| **UV_CODAR**  | HF radar velocities          | **myapp**_uv_codar_yyyymmdd.nc4 |

The user must provide an **observation block** for each data assimilation cycle. That
block is identified as **`__SINGLE_OBSERVATION_DATA__`** or **`__OBSERVATION_DATA__`** in the
**YAML** templates:

- The **`__SINGLE_OBSERVATION_DATA__`** identifier is used only for single observation test cases,
  including a **TS** pair, an **SST** datum, or a couple of **ADT** measurements. It uses the
  [**obs_singleObs.yaml.tmpl**](https://github.com/myroms/roms-jedi/blob/develop/test/Utility/obs_singleObs.yaml.tmpl)
  as a template to build the observation block in associated **YAML** files. For example, in
  [**4dvar_singleObs_bump.yaml.tmpl**](https://github.com/myroms/roms-jedi/blob/develop/test/templates/4dvar_singleObs_bump.yaml.tmpl),
  you would find:

  ``` yaml
  ...
  cost function:
    cost type: 4D-Var
    time window:
      begin: *date
      length: *ForecastLength
    analysis variables: *roms_analysis

    geometry: &geom
      project_dir: __PROJECT_DIR__
      roms_stdinp: __ROMS_STDINP_MAX__
      fields metadata: Data/fields_metadata.yaml
      ng: 1                                        # ROMS nested grid number

    model:
      name: ROMS
      model variables: *roms_state
      simulation length: *ForecastLength
      tstep: *TimeStep

    background:
      fields_dir: __FIELDS_DIR__
      fields_filename: __ROMS_INI_PRIOR__
      fields_record: __INI_PRIOR_RECORD__
      state variables: *roms_state
      date: *date

    background error:
      covariance model: SABER
      saber central block:
        saber block name: BUMP_NICAS
        active variables: *roms_analysis
        fields metadata:
          sea_surface_height_above_geoid:
            vert_coord: vert_coord_2d
        read:
          drivers:
            multivariate strategy: univariate
            read global nicas: false
            read local nicas: true
          model:
            level for 2d variables: last
            do not cross mask boundaries: true
          nicas:
            interpolation in global file: false
          io:
            data directory: Data/bump
            files prefix: __ROMS_APP___bump_cor_max
          grids:
          - model:
              variables:
              - sea_surface_height_above_geoid
          - model:
              variables:
              - sea_water_temperature
              - sea_water_salinity

      saber outer blocks:
      - saber block name: StdDev
        read:
          model file:
            fields_dir: __FIELDS_DIR__
            fields_filename: __ROMS_PRIOR_STD__
            fields_record: 1
            state variables: *roms_analysis
            date: *date

    observations:
      obs perturbations: false                     # default
      observers:

      __SINGLE_OBSERVATION_DATA__

  variational:
    minimizer:
      algorithm: RPCG                              # Dual   formulation
    iterations:
    - ninner: 1                                    # each item defined an outer loop
      gradient norm reduction: 1E-10
      test: on
      online diagnostics:
        adj obs test: false
        adj tlm test: false
        online adj test: false
        tlm approx test: false
        tlm propag test: false
        tlm taylor test: false
      geometry: *geom
      linear model:
        name: LMROMS
        date: *date
        simulation length: *ForecastLength
        lm variables: *roms_analysis
        tstep: *TimeStep
        trajectory:
          model variables: *roms_state
          tstep: __TRAJECTORY_TIMESTEP__
        variable change: Identity
      diagnostics:                                 # Written into output IODA files
        departures: ombg                           # OBS - H(Xb)
      online diagnostics:
        write increment: true
        increment:                                 # DA increment output file
          state component:
            single_record: true
            data_dir: Data/4dvar/singleObs/bump
           prefix: __ROMS_APP___roms
            exp: 4dvar
            type: inc
            date: *date
  ...
  ```

 - The **`__OBSERVATION_DATA__`** identifier is used for the whole set of observations that
   may contain any of the following observer spaces (**`obs space`**): InsituTS, InsituTemperature, InsituSalinity,
   SST, SSS, ADT, and UVcodar. It uses
   [**observations.yaml.tmpl**](https://github.com/myroms/roms-jedi/blob/develop/test/Utility/observations.yaml.tmpl) 
   as a template to build the observation block in the data assimilation  **YAML** files for available
   algorithms. For example, in [**4dvar_bump.yaml.tmpl**](https://github.com/myroms/roms-jedi/blob/develop/test/templates/4dvar_bump.yaml.tmpl), 
   you would find a similar structure to the above template in the observation block:

   ``` yaml
   ...
   cost function:
     ...
     observations:
       obs perturbations: false                     # default
       observers:

       __OBSERVATION_DATA__

   variational:
   ...
   ```
   
> [!CAUTION]
> The format and indentation of **YAML** pairs are strict and important. It requires
> expertise. Thus, automatic generation via string manipulation scripts is advantageous to
> avoid syntax errors.

---

### Updating Unit Test Reference Files: `update_testref`

As the **JEDI** building blocks and the **ROMS-JEDI** interface evolve, updating the regression data
values for each **Unit Test** reference file in the 
[**testref**](https://github.com/myroms/roms-jedi/tree/develop/test/Applications/wc13/testref)
folder may be necessary. Regression testing serves as a safety mechanism that ensures any new code changes,
bug fixes, or updates do not adversely impact the previous results of a **ROMS-JEDI** application.
Typically, we need to update these reference files when there are changes to the **JEDI** source code structure,
configuration parameters, compiler options, or the application of different parallel partitions.
The script **`update_testref.sh`** facilitates this task and must be executed from the
**`roms-jedi/build_*/roms-jedi/test`** subdirectory.

``` c
update_testref.sh  yaml_file

Options:

  yaml_file                ROMS-JEDI Unit Test input YAML filename
  
Example:

  update_testref.sh  testinput/4dvar_bump.yaml
or
  update_testref.sh  4dvar_bump.yaml
or
  update_testref.sh  4dvar_bump
  ```
This script must be executed from the correct location to function properly. Mostly,
all the **YAML** files have a regression block at the bottom. For example,
[**4dvar_bump.yaml**](https://github.com/myroms/roms-jedi/blob/develop/test/Applications/wc13/testinput/4dvar_bump.yaml)
has:

``` yaml
test:
  reference filename: testref/4dvar_bump.ref
  float relative tolerance: 1.0e-3
  log output filename: testoutput/4dvar_bump.log
  test output filename: testoutput/4dvar_bump.out
```
After a specific Unit Test fails because exceeding the relative tolerance value, the **`update_testref.sh`**
will replace the data in **`testref/4dvar_bump.ref`** with its new values in **`testoutput/4dvar_bump.out`**,
for example.  Thus, we must execute this script from the relative path **`roms-jedi/build_*/roms-jedi/test`**.
