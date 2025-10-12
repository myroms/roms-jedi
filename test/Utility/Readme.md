<img width="824" alt="image" src="https://github.com/user-attachments/assets/d15ec2a4-70e3-410f-a2ae-d09682a9f0f2">

This subdirectory contains various files that the **ROMS-JEDI** interface uses to specify fields and observations metadata for
**JEDI**. It includes templates for generating the observation block in the input **YAML** files necessary for a data assimilation
cycle and scripts that provide detailed information on how to run unit tests or specific interface algorithms.

- **`field_metadata.yaml`:**  A **ROMS-JEDI** metadata for state and control vector variables,
  including various field attributes and properties. For example:
  ``` yaml
  - name:         'sea_water_temperature'
    surface name: 'sea_surface_temperature'
    short name:   'tocn'
    io name:      'temp'
    io file:      'ocn'
    gtype:        'r'
    levels:       'full_ocn'
    units:        'Celsius'

  - name:         'sea_water_salinity'
    surface name: 'sea_surface_salinity'
    short name:   'socn'
    io name:      'salt'
    io file:      'ocn'
    gtype:        'r'
    levels:       'full_ocn'
    units:        'nondimensional'
    property:     'positive definite'
  
  ...
  ```

- **`obsop_name_map.yaml`:** Observation variables metadata names and alises for input/ouput **IODA** files and **UFO** operators. Currently, we have:
  ``` yaml
  - name: depthBelowWaterSurface
    alias: ocean_depth
  - name: waterTemperature
    alias: sea_water_temperature
  - name: waterPotentialTemperature
    alias: sea_water_potential_temperature
  - name: seaSurfaceTemperature
    alias: sea_surface_temperature
  - name: salinity
    alias: sea_water_salinity
  - name: seaSurfaceSalinity
    alias: sea_surface_salinity
  - name: waterZonalVelocity
    alias: eastward_sea_water_velocity
  - name: waterSurfaceZonalVelocity
    alias: surface_eastward_sea_water_velocity
  - name: waterMeridionalVelocity
    alias: northward_sea_water_velocity
  - name: waterSurfaceMeridionalVelocity
    alias: surface_northward_sea_water_velocity
  ```
  
- **`observations.yaml.tmpl`:** Template used by the **Perl** script
  [**`template2yaml.pl`**](https://github.com/myroms/roms-jedi/blob/ef85cd32a8fc2a6dedab5da3856a69cf7d07338b/tools/workflow/template2yaml.pl#L1)
  to generate the observations block in input **YAML** files, identified in the templates by the **`__OBSERVATION_DATA__`**
  descriptor:
  ``` yaml
      observations:
      obs perturbations: false                     # default
      observers:

      __OBSERVATION_DATA__
  ```

- **`obs_SingleObs.yaml.tmpl`:** Template used by the **Perl** script
  [**`template2yaml.pl`**](https://github.com/myroms/roms-jedi/blob/ef85cd32a8fc2a6dedab5da3856a69cf7d07338b/tools/workflow/template2yaml.pl#L1)
  to generate the observations block in input **YAML** files, identified in the templates by the **`__SINGLE_OBSERVATION_DATA__`**
  descriptor, used to test the data assimilation algorithms and their background error hypothesis in **JEDI**.
  ``` yaml
      observations:
      obs perturbations: false                     # default
      observers:

      __SINGLE_OBSERVATION_DATA__
  ```

- **`myapp_yaml_parameters.dat`**: ASCII generic parameter file used by the **`template2yaml.pl`** Perl script to create application-specific
  **YAML** files from templates. Users must customize it for their specific application.
  
- **`batch_tests.sh`:** Unit Tests execution script with lots of information and parameters to gain better control when running all
  or a specific case for submitting and queuing jobs in **`batch`**.  It has information and instructions that are hard to remember.

- **`slurm_tests.sh`:** Unit Tests execution script with lots of information and parameters to gain better control when running all
  or a specific case for submitting and queuing jobs in **`slurm`** in high-performance computing (**HPC**). It has information and
  instructions that are hard to remember.
