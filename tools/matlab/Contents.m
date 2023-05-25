%
% ROMS-JEDI Matlab Proccessing Scripts:
% ====================================
%
% IODA Files Processing:
%
% create_ioda_obs   - Creates a new IODA observation NetCDF-4 file
%                     from specified data structure, S.
%
% ioda_read         - Reads an existing IODA observation NetCDF-4
%                     file and stores all the variables into
%                     structrue array, S.
%
% ioda_write        - Writes IODA observation data into a NetCDF-4
%                     from input strcuture, S.
%
% roms2ioda         - Converts ROMS native 4D-Var NetCDF to IODA
%                     NetCDF-4 files. It creates one file per each
%                     observation type.
%
% Standard Output Processing:
%
% extract_values    - Extracts numerical values from ROMS-JEDI
%                     standard output file.
%
% Ploting Tools:    Native ROMS Matlab functions can be downloaded
%                   from their repository:
%
%                   svn checkout https://www.myroms.org/svn/src/matlab
%
% plot_cosfunction  - Plots Dual/Primal Variational Assimilation
%                     convergence variables:
%
%                       * 'Gradient reduction'
%                       * 'CostFunction: Nonlinear'
%                       * 'CostJo   : Nonlinear'
%                       * ': CostJb   : Nonlinear'
%                       * 'Quadratic cost function: J '
%                       * 'Quadratic cost function: JoJc'
%                       * 'Quadratic cost function: Jb'
%
% plot_dirac        - Plots Error Covariace modelling Dirac
%                     Impulses. It uses ROMS native 'plot_field'
%                     and 'plot_section' functions.
%
% plot_hofx         - Plots initial and final H(x) for the data
%                     assimilation algorithms.
%
% plot_increment    - Plots Data Assimilation increments. It use
%                     ROMS native 'plot_field' function.
%
% plot_ioda         - Plots specified data from an IODA NetCDF-4
%                     file.
%