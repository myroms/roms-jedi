<img width="824" alt="image" src="https://github.com/user-attachments/assets/d15ec2a4-70e3-410f-a2ae-d09682a9f0f2">

## Introduction

The **native ROMS 4D-Var** observation file and **H(x)** operators have been refactored to use
multiple **IODA-type** enhanced **NetCDF-4** files with first-level grouping. A **NetCF4-4 Group**
is based on the underlying **HDF5** data model. It is equivalent to a subdirectory in the file and
allows structuring the observation data hierarchically within a single file.  The different **groups**
may contain variables with the same name without conflict, allowing the storage of various data
properties, like observation value, observation error, quality control flags, model **H(x)** values,
background error, innovation, increment, residual, and many others.

> [!IMPORTANT]
> The main objective is to have **IODA-type** observation files that can be used either in the **native ROMS 4D-Var**
> drivers or in any of the **ROMS-JEDI** data assimilation algorithms. The output from data assimilation is also stored
> in **IODA-type** files, but in different new groups for diagnostic and post-processing purposes. Unlike with the
> native ROMS classic NetCDF files, the input **IODA-type** files are **unmodified** during data assimilation.

The strategy is to have an **IODA-type** observation file for each variable in the control vector, like **SSH**,
**SST**, **SSS**, **HF radar** velocities, **temperature**, and **salinity** individual files in a particular data
assimilation cycle. A file can include multiple variables representing vectors (**u**- and **v**-momentum) and
spectral data with exact coordinates (**lon**, **lat**, **depth**, **time**). It may also contain multiple scalar
variables if at the precise location, such as **T** and **S** profiles or biological profiles for various ecosystem
state variables. I may also include secondary variables to compute a control variable with an elaborate operator.
This structure gives us a lot of flexibility for filtering and averaging operators.

There are scripts in this directory that can be used to convert (**`roms2ioda.m`**) a single **native ROMS 4D-Var**
classic **NetCDF** (version **3** or **4**) file into multiple **IODA-type** enhanced **NetCDF-4** files.

## MetaData Group

The **MetaData** Group in the **IODA-type** enhanced **NetCDF-4** file contains variables that describe each observation's
multidimensional coordinates and other characteristics. This group is the top level of the hierarchical structure in
the **IODA** file. Additional variables provide unique functionalities in native **ROMS 4D-Var** and **ROMS-JEDI**
applications without impacting their compatibility with the general **JEDI** building blocks.

| MetaData Variables | Algorithms        | Description |
|--------------------|-------------------|-------------|
| **dateTime**       | **JEDI**/native   | **Time** for each observation (seconds since reference date-time) | 
| **depth**          | **JEDI**/native   | **Depth** below sea level for each observation (meter; negative) |
| **latitude**       | **JEDI**/native   | **Latitude** for each observation (degrees_north) |
| **longitude**      | **JEDI**/native   | **Longitude** for each observation (degrees_east) |
| **sequenceNumber** | **JEDI**          | Original **sequence order** to unmap parallel Round Robin **IODA** processing | 
| **variables_name** | **JEDI**          | **UFO/IODA** observation **standard name** (string) |
|  |  |  |
| **dateTimeAverageBegin** | native **ROMS** | Observation **start** of **time-averaged** window (seconds since reference date-time) |  
| **dateTimeAverageEnd**   | native **ROMS** | Observation **end** of **time-averaged** window (seconds since reference date-time) |
| **provenance**           | native **ROMS** | Observation **origin** identifier (integer) |
| **spatialAverage**       | native **ROMS** | Half-length of **spatial-averaged** filter scale for **H(x)** computation |
| **stateID**              | native **ROMS** | Internal **ROMS** state vector variable indentifier associtated with observation (integer)|
| **surveyIndex**          | native **ROMS** | Observation **survey time** indices (integer) as they appear in **dateTime** |
| **surveyTime**           | native **ROMS** | Observation **survey time** (seconds since reference date-time) |
| **x_grid**               | native **ROMS** | Fractional **X**-grid location for each observation (floating-point) |
| **y_grid**               | native **ROMS** | Fractional **Y**-grid location for each observation (floating-point) |
| **y_grid**               | native **ROMS** | Fractional **Z**-grid location for each observation (floating-point) |

Here is an example of the **MetaData** schema demonstrating the current variables. The design is expandable, allowing additional variables
to be added as necessary for new observational data strings and complex **H(x)** operators.

``` c
group: MetaData {
  variables:
  	int64 dateTime(Location) ;
  		dateTime:long_name = "elapsed observation time since reference" ;
  		dateTime:units = "seconds since 2019-08-27T00:00:00Z" ;
  	int64 dateTimeAverageBegin(timeWindow) ;
  		dateTimeAverageBegin:long_name = "start of time averaging filter" ;
  		dateTimeAverageBegin:units = "seconds since 2019-08-27T00:00:00Z" ;
  	int64 dateTimeAverageEnd(timeWindow) ;
  		dateTimeAverageEnd:long_name = "end of time averaging filter" ;
  		dateTimeAverageEnd:units = "seconds since 2019-08-27T00:00:00Z" ;
  	float depth(Location) ;
  		depth:long_name = "observation depth below sea level" ;
  		depth:units = "meter" ;
  		depth:negative = "downwards" ;
  	float latitude(Location) ;
  		latitude:long_name = "observation latitude" ;
  		latitude:units = "degrees_north" ;
  	float longitude(Location) ;
  		longitude:long_name = "observation longitude" ;
  		longitude:units = "degrees_east" ;
  	int provenance(Location) ;
  		provenance:long_name = "observation origin identifier" ;
    float spatialAverage ;
  		spatialAverage:long_name = "half-length of spatial averaging filter" ;
  		spatialAverage:units = "meter" ;
  	int sequenceNumber(Location) ;
  		sequenceNumber:long_name = "observation sequence number" ;
  	int stateID(nvars) ;
  		stateID:long_name = "state variable index" ;
  	int surveyIndex(survey) ;
  		surveyIndex:long_name = "observation survey time indices as they appear in dateTime" ;
  	int64 surveyTime(survey) ;
  		surveyTime:long_name = "observation survey time" ;
  		surveyTime:units = "seconds since 2019-08-27T00:00:00Z" ;
  	string variables_name(nvars) ;
  		variables_name:long_name = "observation UFO/IODA standard name" ;
  		string variables_name:_FillValue = "" ;
  	float x_grid(Location) ;
  		x_grid:long_name = "observation fractional x-grid location" ;
  	float y_grid(Location) ;
  		y_grid:long_name = "observation fractional y-grid location" ;
  	float z_grid(Location) ;
  		z_grid:long_name = "observation fractional z-grid location" ;
  } // group MetaData
```

> [!NOTE]  
> - The floating-point data is represented in single precision, eliminating the need for double precision since the observations do not
> require that level of accuracy. Consequently, the files will be significantly smaller.
> - Time is recorded **seconds** from the reference date and time, represented as an **int64** integer. There is no necessity
> to store the time coordinate as double precision. Using **seconds** prevents errors when converting from larger units.
> The date and time are measured as **seconds since** the reference value.
> - To create smaller files and improve compression, we could record time as **seconds** from either the beginning of the
> simulation's year or, preferably, from the date and time of the data assimilation cycle. The reference value for the observation
> files is flexible; **ROMS** and **JEDI** will set it to the correct time!
> - If the **dateTimeAverageBegin** and **dateTimeAverageEnd** variables are present, the time-averaged **H(x)** operator is activated.
> It assumes that the input observations are time-averaged and the model values at the observation location are averaged over the
> specified time window. This time filter can be used to remove tidal or inertial signals.
> - The **provenance** variable is a user-defined integer identifier that indicates the origin of each observation. It is mainly used
> for quality control of observations and assessing their impacts and sensitivities to the data assimilation analysis.
> - If the **spatialAverage** variable is present, the area-averaged **H(x)** operator is activated. The input observations are
> area-averaged, and the model values at the observation locations are averaged over an area of influence determined by twice the
> specified half-length scale. This operator is intended for strict **2D** observations, such as **SSH**, **SST**, **SSS**, and
> **HF** radar velocities at a depth of 2 meters.
> - An observation file may include area- and time-averaged **H(x)** operators. However, the averaged operators are only
> available in **native ROMS** data assimilation algorithms.
> - The **stateID** descriptor is an internal **ROMS** index that relates observations to model prognostic state variables.
> - The **surveyTime** variable identifies observations with the same date and time coordinate to facilitate their bracketing during
> model time stepping and to accelerate the **H(x)** computation. It is assumed that **`all observations are organized in increasing order of time`**.
> - The **surveyIndex** represents the position of the storage vector element corresponding to a survey time within the **dateTime** variable.
> - The fractional spatial coordinates **x_grid**, **y_grid**, and **z_grid** are used for efficient interpolation in the **H(x)** operator.
> Identifying the grid cell that contains the observation can be computationally expensive in parallel processing, especially for non-plaid grids,
> which are typically the case.

## Data Groups

The **IODA-type** input and output files consist of multiple hierarchical groups that organize various fields related to observations,
**H(x)** computations, and data assimilation diagnostics. The table below summarizes all the groups (⬇️ **input file**, ⬆️ **output file**,
or ↕️ **both files**) in the native **ROMS 4D-Var** and **ROMS-JEDI** data assimilation algorithms.

| Data Group        | DA System                  |  Description           |        
|-------------------|----------------------------|------------------------|
| ↕️ **ObsError**   | **native ROMS**, **JEDI**  | Stores the error associated with each observation |
| ↕️ **ObsValue**   | **native ROMS**, **JEDI**  | Holds observational data |
| ↕️ **PreQC**      | **native ROMS**, **JEDI**  | Stores quality control information flag |
|    |    |    |
| ⬆️ **EffectiveError0** | **JEDI**              | Stores initial observation effective error after QC steps |
| ⬆️ **EffectiveError1** | **JEDI**              | Stores final observation effective error after QC steps |
| ⬆️ **EffectiveQC0**    | **JEDI**              | Stores initial QC value given by QCflags enumeration object |
| ⬆️ **EffectiveQC1**    | **JEDI**              | Stores final QC value given by QCflags enumeration object  |
| ⬆️ **ObsBias0**        | **JEDI**              | Stores information about initial/prior observation bias correction |
| ⬆️ **ObsBias1**        | **JEDI**              | Stores information about final/analysis observation bias correction |
| ⬆️ **hofx0**           | **JEDI**              | Stores first guess prior at the observation locations, **H(Xb)** operator |
| ⬆️ **hofx1**           | **JEDI**              | Stores data assimilation analysis at the observation locations, **H(Xa)** operator |
| ⬆️ **oman**            | **JEDI**              | Stores observation minus analysis, residual, **y - H(Xa)** |
| ⬆️ **ombg**            | **JEDI**              | Stores observation minus background/prior, innovation, **y - H(Xb)** |
|    |    |    |
| ⬆️ **BackgroundError** | **native ROMS**       | Stores background/prior error at the observation locations |
| ⬆️ **HofxInitial**     | **native ROMS**       | Stores first guess prior at the observation locations, **H(Xb)** operator |
| ⬆️ **HofxFinal**       | **native ROMS**       | Stores data assimilation analysis at the observation locations, **H(Xa)** operator |
| ⬆️ **Innovation**      | **native ROMS**       | Stores observation minus background/prior, **y - H(Xb)** |
| ⬆️ **Increment**       | **native ROMS**       | Stores analysis minus background/prior, **H(Xa) - H(Xb)** |
| ⬆️ **Residual**        | **native ROMS**       | Stores observation minus analysis, **y - H(Xa)** |

---

Below is an example of an **input** altimetry observations **IODA NetCDF-4** file designed for the **native ROMS 4D-Var**. This file includes
both area-averaged and time-averaged variables that will be used to compute the **H(x)** operator. The model Sea Surface Height (**SSH**) 
variable is time-averaged over **36** hours and area-averaged across a **60**-kilometer distance centered along the altimetry track.

``` c
% ncdump usec3_adt_20190827.nc4

netcdf usec3_adt_20190827 {
dimensions:
	Location = 1940 ;
	nvars = 1 ;
	survey = 17 ;
	timeWindow = 2 ;
variables:
	int Location(Location) ;
		Location:suggested_chunck_dim = 512 ;
	int nvars(nvars) ;
		nvars:suggested_chunck_dim = 100 ;
	int survey(survey) ;
		survey:suggested_chunck_dim = 100 ;
	int timeWindow(timeWindow) ;
		timeWindow:suggested_chunck_dim = 100 ;

// global attributes:
		:_ioda_layout = "ObsGroup" ;
		:_ioda_layout_version = 3 ;
		:odb_version = 1 ;
		:date_time = 2019082700. ;
		:datetimeReference = "2019-08-27T00:00:00Z" ;
		:description = "Native ROMS 4D-Var observations file converted to IODA" ;
		:sourceFiles = "usec3km_roms_obs_20190827.nc" ;
		:history = "Created from Matlab script: create_ioda_obs on Thursday - August 28, 2025 - 1:24:54.5017 PM" ;
data:

group: MetaData {
  variables:
  	int64 dateTime(Location) ;
  		dateTime:long_name = "elapsed observation time since reference" ;
  		dateTime:units = "seconds since 2019-08-27T00:00:00Z" ;
  	int64 dateTimeAverageBegin(timeWindow) ;
  		dateTimeAverageBegin:long_name = "start of time averaging filter" ;
  		dateTimeAverageBegin:units = "seconds since 2019-08-27T00:00:00Z" ;
  	int64 dateTimeAverageEnd(timeWindow) ;
  		dateTimeAverageEnd:long_name = "end of time averaging filter" ;
  		dateTimeAverageEnd:units = "seconds since 2019-08-27T00:00:00Z" ;
  	float latitude(Location) ;
  		latitude:long_name = "observation latitude" ;
  		latitude:units = "degrees_north" ;
  	float longitude(Location) ;
  		longitude:long_name = "observation longitude" ;
  		longitude:units = "degrees_east" ;
  	int provenance(Location) ;
  		provenance:long_name = "observation origin identifier" ;
  		provenance:negative = "repetitive observation at different times and error" ;
  	int sequenceNumber(Location) ;
  		sequenceNumber:long_name = "observation sequence number" ;
  	float spatialAverage ;
  		spatialAverage:long_name = "half-length of spatial averaging filter" ;
  		spatialAverage:units = "meter" ;
  	int stateID(nvars) ;
  		stateID:long_name = "state variable index" ;
  	int surveyIndex(survey) ;
  		surveyIndex:long_name = "observation survey time indices as they appear in dateTime" ;
  	int64 surveyTime(survey) ;
  		surveyTime:long_name = "observation survey time" ;
  		surveyTime:units = "seconds since 2019-08-27T00:00:00Z" ;
  	string variables_name(nvars) ;
  		variables_name:long_name = "observation UFO/IODA standard name" ;
  		string variables_name:_FillValue = "" ;
  	float x_grid(Location) ;
  		x_grid:long_name = "observation fractional x-grid location" ;
  	float y_grid(Location) ;
  		y_grid:long_name = "observation fractional y-grid location" ;
  data:

   dateTimeAverageBegin = "2019-08-27", "2019-08-28 12" ;

   dateTimeAverageEnd = "2019-08-28 12", "2019-08-30" ;

   spatialAverage = 30000 ;
  } // group MetaData

group: ObsError {
  variables:
  	float absoluteDynamicTopography(Location) ;
  		absoluteDynamicTopography:long_name = "observation error standard deviation" ;
  		absoluteDynamicTopography:units = "meter" ;
  		absoluteDynamicTopography:coordinates = "longitude, latitude, dateTime" ;
  data:
  } // group ObsError

group: ObsValue {
  variables:
  	float absoluteDynamicTopography(Location) ;
  		absoluteDynamicTopography:long_name = "observation value" ;
  		absoluteDynamicTopography:units = "meter" ;
  		absoluteDynamicTopography:coordinates = "longitude, latitude, dateTime" ;
  data:
  } // group ObsValue

group: PreQC {
  variables:
  	int absoluteDynamicTopography(Location) ;
  		absoluteDynamicTopography:long_name = "observation preset quality control filter identifier" ;
  		absoluteDynamicTopography:coordinates = "longitude, latitude, dateTime" ;
  data:
  } // group PreQC
}
```

---

The following is an example of an **IODA NetCDF-4** file output from **ROMS-JEDI 4D-Var**, demonstrating the various data groups.

``` c
% ncdump -h wc13_sst_4dvar.nc4

netcdf wc13_sst_4dvar {
dimensions:
	Location = UNLIMITED ; // (4952 currently)
	nvars = 1 ;

variables:
	int Location(Location) ;
		Location:suggested_chunck_dim = 4952 ;
	int nvars(nvars) ;
		nvars:suggested_chunck_dim = 100 ;

// global attributes:
		string :_ioda_layout = "ObsGroup" ;
		:date_time = 2004010300. ;
		string :datetimeReference = "2004-01-03T00:00:00Z" ;
		string :sourceFiles = "WC13/Data/wc13_obs_20040103.nc" ;

group: EffectiveError0 {
  variables:
  	float seaSurfaceTemperature(Location) ;
  } // group EffectiveError0

group: EffectiveError1 {
  variables:
  	float seaSurfaceTemperature(Location) ;
  } // group EffectiveError1

group: EffectiveQC0 {
  variables:
  	int seaSurfaceTemperature(Location) ;
  } // group EffectiveQC0

group: EffectiveQC1 {
  variables:
  	int seaSurfaceTemperature(Location) ;
  } // group EffectiveQC1

group: MetaData {
  variables:
  	int provenance(Location) ;
  		string provenance:flag_meanings = "blended_SST" ;
  		provenance:flag_values = 2 ;
  		string provenance:long_name = "observation origin identifier" ;
  	float latitude(Location) ;
  		string latitude:long_name = "observation latitude" ;
  		string latitude:units = "degrees_north" ;
  	int sequenceNumber(Location) ;
  		string sequenceNumber:long_name = "observations sequence number" ;
  	float longitude(Location) ;
  		string longitude:long_name = "observation longitude" ;
  		string longitude:units = "degrees_east" ;
  	int64 dateTime(Location) ;
  		string dateTime:long_name = "elapsed observation time since reference" ;
  		string dateTime:units = "seconds since 2004-01-03T00:00:00Z" ;
  	string variables_name(nvars) ;
  		string variables_name:long_name = "observation UFO/IODA standard name" ;
  } // group MetaData

group: ObsBias0 {
  variables:
  	float seaSurfaceTemperature(Location) ;
  } // group ObsBias0

group: ObsBias1 {
  variables:
  	float seaSurfaceTemperature(Location) ;
  } // group ObsBias1

group: ObsError {
  variables:
  	float seaSurfaceTemperature(Location) ;
  		string seaSurfaceTemperature:coordinates = "longitude, latitude, dateTime" ;
  		string seaSurfaceTemperature:long_name = "observation error standard deviation" ;
  		string seaSurfaceTemperature:units = "C" ;
  } // group ObsError

group: ObsValue {
  variables:
  	float seaSurfaceTemperature(Location) ;
  		string seaSurfaceTemperature:coordinates = "longitude, latitude, dateTime" ;
  		string seaSurfaceTemperature:long_name = "observation value" ;
  		string seaSurfaceTemperature:units = "C" ;
  } // group ObsValue

group: PreQC {
  variables:
  	int seaSurfaceTemperature(Location) ;
  		string seaSurfaceTemperature:coordinates = "longitude, latitude, dateTime" ;
  		string seaSurfaceTemperature:long_name = "observation preset quality control filter identifier" ;
  } // group PreQC

group: hofx0 {
  variables:
  	float seaSurfaceTemperature(Location) ;
  } // group hofx0

group: hofx1 {
  variables:
  	float seaSurfaceTemperature(Location) ;
  } // group hofx1

group: oman {
  variables:
  	float seaSurfaceTemperature(Location) ;
  } // group oman

group: ombg {
  variables:
  	float seaSurfaceTemperature(Location) ;
  } // group ombg
}
```

## Observation Variables

The table below displays the names of **native ROMS 4D-Var** and **ROMS-JEDI** observations in input and output
 **IODA** files and their relationship to the **ROMS** control vector. These variables are defined in
 **`obsop_name_map.yaml`**.

| Short Name  | State ID  | Standard Name                  | IODA Variable Name | 
|-------------|:---------:|--------------------------------|--------------------|
| ssh, SSH    | 1         | sea_surface_height_above_geoid | **absoluteDynamicTopography** |
| u, uocn     | 4         | eastward_sea_water_velocity    | **waterZonalVelocity** |
| v, vocn     | 5         | northward_sea_water_velocity   | **waterMeridionalVelocity** |
| sst, SST    | 6, 60     | sea_surface_temperature        | **seaSurfaceTemperature** |
| tocn, temp  | 6         | sea_water_temperature          | **waterTemperature** |
| sss, SSS    | 7, 70     | sea_surface_salinity           | **seaSurfaceSalinity** |
| socn, salt  | 7         | sea_water_salinity             | **salinity** |

Integrating sea surface height (**SSH**) into ocean models is complex due to the need for specialized **H(x)**
operators. The **zeta** (**𝜁**) state variable in **ROMS** represents the free surface. This variable is a time-varying,
physical boundary condition at the top of the numerical grid and is influenced by waves, tides, and currents.
Conversely, **SSH** is an instantaneous measurement typically obtained from satellite altimeters. This measurement
is relative to a reference ellipsoid and provides essential information about the Geoid, ocean dynamics, and
seawater steric effects resulting from variations in temperature and salinity (density).

The Geoid is an undulating surface that represents the level the ocean would reach if it were only influenced by
Earth's gravity, without any effects from currents or winds. The **SSH** can also be calculated
with respect to the Geoid, referred to as Absolute Dynamic Topography (**ADT**), as shown in the diagram below.
This quantity is used in the **JEDI/UFO `H(x)`** operator in the data assimilation algorithms.

<img width="901" height="374" alt="image" src="https://github.com/user-attachments/assets/e5a02bda-95cd-4dc7-8288-baf4b81dee2b" />

Therefore, the evolution of **𝜁(x,y,t)** represents the instantaneous **SSH**, but several corrections to altimetry data are required
to assimilate it correctly in a particular application.

## Native to IODA Conversion

The Matlab scripts **create_ioda_obs.m**, **ioda_metadata.m**, and **roms2ioda.m**, among others in this directory,
can be used to convert a single **native ROMS 4D-Var** classic **NetCDF** observations file into multiple **IODA-type**
enhanced **NetCDF-4** files.

To convert from **native** format to **IODA** files, follow these steps: 

1. Use the Matlab script **`ioda_metadata.m`** to set up the **IODA** metadata structure, denoted as **M**. This
  structure should contain information regarding the **NetCDF-4** names of the data assimilation control variables
  (**ioda_vname**), the standard name (**standard_name**), the area-averaged parameter (**half_length**, in kilometers),
  and the time-averaged parameter (**time_window**, in hours). Initially, the averaging parameters have empty values.

  ``` c
>> M=ioda_metadata(true);
 
IODA NetCDF-4 file Metadata Structure:
 
             name: 'SSH'
      half_length: []
      time_window: []
       ioda_vname: 'absoluteDynamicTopography'
    standard_name: 'absolute_dynamic_topography'

             name: 'SST'
      half_length: []
      time_window: []
       ioda_vname: 'seaSurfaceTemperature'
    standard_name: 'sea_surface_temperature'

             name: 'SSS'
      half_length: []
      time_window: []
       ioda_vname: 'seaSurfaceSalinity'
    standard_name: 'sea_surface_salinity'

             name: 'uv_CODAR'
      half_length: []
      time_window: []
       ioda_vname: {'waterZonalVelocity'  'waterMeridionalVelocity'}
    standard_name: {1×2 cell}

             name: 'ptemp'
      half_length: []
      time_window: []
       ioda_vname: 'waterPotentialTemperature'
    standard_name: 'sea_water_potential_temperature'

             name: 'temp'
      half_length: []
      time_window: []
       ioda_vname: 'waterTemperature'
    standard_name: 'sea_water_temperature'

             name: 'salt'
      half_length: []
      time_window: []
       ioda_vname: 'salinity'
    standard_name: 'sea_water_salinity'
```
2. Set area-averaged and/or time-averaged parameters for specific variables if appropriate. If these operators
   are not required, you can skip this step. For example, to set the area-averaged and time-averaged scales for
   **SSH** and time-averaging for **uv_CODAR**, use:
``` c
>> M(strcmp({M.name}, 'SSH')).half_length = 30;         % 30 km scale, effective scale 60 km
>> M(strcmp({M.name}, 'SSH')).time_window = 36;         % 24 hours averaging

>> M(strcmp({M.name}, 'uv_CODAR')).time_window = 24;    % 24 hours averaging
```
3. To check the final values of the **M** structure, use the intrinsic Matlab function **`struct2table`**:
``` d
>> disp(struct2table(M))

        name        half_length     time_window              ioda_vname                         standard_name           
    ____________    ____________    ____________    _____________________________    ___________________________________

    {'SSH'     }    {[      30]}    {[      36]}    {'absoluteDynamicTopography'}    {'absolute_dynamic_topography'    }
    {'SST'     }    {0×0 double}    {0×0 double}    {'seaSurfaceTemperature'    }    {'sea_surface_temperature'        }
    {'SSS'     }    {0×0 double}    {0×0 double}    {'seaSurfaceSalinity'       }    {'sea_surface_salinity'           }
    {'uv_CODAR'}    {0×0 double}    {[      24]}    {1×2 cell                   }    {1×2 cell                         }
    {'ptemp'   }    {0×0 double}    {0×0 double}    {'waterPotentialTemperature'}    {'sea_water_potential_temperature'}
    {'temp'    }    {0×0 double}    {0×0 double}    {'waterTemperature'         }    {'sea_water_temperature'          }
    {'salt'    }    {0×0 double}    {0×0 double}    {'salinity'                 }    {'sea_water_salinity'             }
```
4. Execute the **`roms2ioda.m`** script to convert from **native** to multiple **IODA** files:

``` c
>> ObsData = 'USEC/Data/OBS/usec3km_roms_obs_20190827.nc';     % single native classic NetCDF file 
>> HisName = 'USEC/Forward/usec3km_roms_his_20190827.nc';      % ROMS history NetCDF for geometry information

>> roms2ioda(ObsData, HisName, 'usec3', '20190827', M);
 
*** Creating observations file:  usec3_adt_20190827.nc4
*** Writing  observations file:  usec3_adt_20190827.nc4
 
*** Creating observations file:  usec3_sst_20190827.nc4
*** Writing  observations file:  usec3_sst_20190827.nc4
 
*** Creating observations file:  usec3_temp_20190827.nc4
*** Writing  observations file:  usec3_temp_20190827.nc4
 
*** Creating observations file:  usec3_ptemp_20190827.nc4
*** Writing  observations file:  usec3_ptemp_20190827.nc4
 
*** Creating observations file:  usec3_salt_20190827.nc4
*** Writing  observations file:  usec3_salt_20190827.nc4
 
*** Creating observations file:  usec3_uv_codar_20190827.nc4
*** Writing  observations file:  usec3_uv_codar_20190827.nc4
```
5. Check the output **IODA NetCDF-4** to ensure that averaging parameters, if any, are correct.
``` c
% ncdump -tv dateTimeAverageBegin,dateTimeAverageEnd,spatialAverage usec3_adt_20190827.nc4

group: MetaData {
  variables:
    ...
  	int64 dateTimeAverageBegin(timeWindow) ;
  		dateTimeAverageBegin:long_name = "start of time averaging filter" ;
  		dateTimeAverageBegin:units = "seconds since 2019-08-27T00:00:00Z" ;
  	int64 dateTimeAverageEnd(timeWindow) ;
  		dateTimeAverageEnd:long_name = "end of time averaging filter" ;
  		dateTimeAverageEnd:units = "seconds since 2019-08-27T00:00:00Z" ;
    ...
  	float spatialAverage ;
  		spatialAverage:long_name = "half-length of spatial averaging filter" ;
  		spatialAverage:units = "meter" ;
    ...

  data:

   dateTimeAverageBegin = "2019-08-27", "2019-08-28 12" ;

   dateTimeAverageEnd = "2019-08-28 12", "2019-08-30" ;

   spatialAverage = 30000 ;

  } // group MetaData
```

  and

``` c
% ncdump -tv dateTimeAverageBegin,dateTimeAverageEnd usec3_uv_codar_20190827.nc4

group: MetaData {
  variables:
    ...
  	int64 dateTimeAverageBegin(timeWindow) ;
  		dateTimeAverageBegin:long_name = "start of time averaging filter" ;
  		dateTimeAverageBegin:units = "seconds since 2019-08-27T00:00:00Z" ;
  	int64 dateTimeAverageEnd(timeWindow) ;
  		dateTimeAverageEnd:long_name = "end of time averaging filter" ;
  		dateTimeAverageEnd:units = "seconds since 2019-08-27T00:00:00Z" ;
  	 ...
  data:

   dateTimeAverageBegin = "2019-08-27", "2019-08-28", "2019-08-29" ;

   dateTimeAverageEnd = "2019-08-28", "2019-08-29", "2019-08-30" ;

 } // group MetaData
```

## Matlab Script roms2ioda.m

The documentation and instructions for the **`roms2ioda.m`** script is as follows:

``` js
% ROMS2IODA:  Converts ROMS observation NetCDF to IODA NetCDF4 files
%
% roms2ioda(ObsData, HisName, prefix, suffix, M)
%
% This function converts a ROMS 4D-Var observation NetCDF file into several
% IODA NetCDF files. One file per observation type is usually the way that
% the JEDI/UFO observation operator requires. Output files are of the form:
%
%                        prefix_obstype_suffix.nc4
%
% For example:           wc13_sst_20040103.nc4
%
% The area-averaged and time-averaged values will be used in ROMS H(x)
% computations with area-averaged and/or time-averaged filters.
%
% On Input:
%
%    ObsData     ROMS standard 4D-Var observation NetCDF filename (string)
%             or ROMS observation data structure (struct)
%
%    HisName     ROMS application history NetCDF filename (string)
%
%    prefix      Output file prefix associated with application (string)
%
%    suffix      Output file suffix associated with date and time, use
%                  YYYYMMDD or YYYYMMDDhh (numeric or string).
%
%                  NOTICE that the time of the output observations is
%                  converted to 'seconds since' time of suffix.
%
%                  For example, if suffix =  20040103  or
%                                  suffix = '20040103' then
%
%                  int64 dateTime(Location);
%                  dateTime:units = "seconds since 2004-01-03T00:00:00Z";
%
%                  Therefore, the input and output times of the observations
%                  may have different time references!
%
%    M           IODA enhanced NetCDF-4 file Metadata structure
%                  (struct array) computed with "ioda_metadat.m"
%
%                  M(:).name           variable short name
%                  M(:).half_length    area-averaged half-length (km) scale
%                  M(:).time_window    time-averaged window (hours)
%                  M(:).ioda_vname     IODA NetCDF-4 variable name
%                  M(:).standard_name  variable standard name
%
% USAGE:
% *****
%
%   Example to convert single WC13 native ROMS 4D-Var observation file
%   into multiple IODA-type files that can be used in native ROMS
%   and ROMS-JEDI data assimilation algorithms, like:
%
%     wc13_adt_20040103.nc4
%     wc13_sst_20040103.nc4
%     wc13_salt_20040103.nc4
%     wc13_temp_20040103.nc4
%
%   (1) Set IODA NetCDF-4 file metadata structure, S:
%
%       M = ioda_metadata(true);
%
%   (2) If applicable, set area-averaged and time-averaged parameters
%       for specialized H(x) operators. If not, you can skip this step.
%
%       M(strcmp({M.name}, 'SSH')).half_length = 30;             % km
%       M(strcmp({M.name}, 'SSH')).time_window = 36;             % hours
%
%       M(strcmp({M.name}, 'uv_CODAR')).time_window = 24;        % hours
%
%   (3) Convert a single native file into multiple IODA-type files:
%
%       ObsData = 'WC13/Data/wc13_obs_20040103.nc';
%       HisName = 'WC13/Forward/r06/wc13_roms_his_20040103.nc';
%
%       roms2ioda(ObsData, HisName, 'wc13', '20040103', M)
%
% Dependencies:
%
%                create_ioda_obs.m
%                get_roms_grid.m
%                ioda_metadata.m
%                obs_k2z.m
%                obs_read.m
```
