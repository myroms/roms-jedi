%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Matlab Script to plot H(x). %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Initialize. All the directory paths are relative to:
%
%             ${ROMS_HOME}/roms-jedi/tools/matlab
%

% Set ROMS-JEDI Data sub-directory with respect the "build":

%Hdir = '../../build/roms-jedi/test/Data/';
 Hdir = '../../build_3dvar_new/roms-jedi/test/Data/';

% Set ROMS-JEDI Ouput NetCDF files with respect sub-directory "Hdir":
 
H3dvarRP    = [Hdir, '3dvar/regular/primal/wc13_XXX_3dvar_regular.nc4'];
H3dvarRD    = [Hdir, '3dvar/regular/dual/wc13_XXX_3dvar_regular.nc4'];

H3dfgatP    = [Hdir, '3dvar/3dfgat/primal/wc13_XXX_3dfgat.nc4'];
H3dfgatD    = [Hdir, '3dvar/3dfgat/dual/wc13_XXX_3dfgat.nc4'];

H4dfgatP    = [Hdir, '3dvar/4dfgat/primal/wc13_XXX_4dfgat.nc4'];
H4dfgatD    = [Hdir, '3dvar/4dfgat/dual/wc13_XXX_4dfgat.nc4'];

H3denvarRP  = [Hdir, '3denvar/regular/primal/wc13_XXX_3denvar_regular.nc4'];
H3denvarRD  = [Hdir, '3denvar/regular/dual/wc13_XXX_3denvar_regular.nc4'];

H3denvarFP  = [Hdir, '3denvar/4dfgat/primal/wc13_XXX_3denvar_4dfgat.nc4'];
H3denvarFD  = [Hdir, '3denvar/4dfgat/dual/wc13_XXX_3denvar_4dfgat.nc4'];

H3dhybRP    = [Hdir, '3dhyb/regular/primal/wc13_XXX_3dhyb_regular.nc4'];
H3dhybRD    = [Hdir, '3dhyb/regular/dual/wc13_XXX_3dhyb_regular.nc4'];

H3dhybFP    = [Hdir, '3dhyb/4dfgat/primal/wc13_XXX_3dhyb_4dfgat.nc4'];
H3dhybFD    = [Hdir, '3dhyb/4dfgat/dual/wc13_XXX_3dhyb_4dfgat.nc4'];

H4dvarB     = [Hdir, '4dvar/bump/wc13_XXX_4dvar.nc4'];
H4dvarD     = [Hdir, '4dvar/diffusion/wc13_XXX_4dvar.nc4'];

HletKF      = [Hdir, 'letkf/solver/wc13_XXX_letkf.nc4'];
HletKFsplit = [Hdir, 'letkf/split_observer/wc13_XXX_letkf_split_observer.nc4'];
HletKF3dhyb = [Hdir, 'letkf/3dhyb/wc13_XXX_letkf_3dhyb.nc4'];

%--------------------------------------------------------------------------
% Variational Data Assimilation.
%--------------------------------------------------------------------------

% Plot ROMS-JEDI Regular 3D-Var H(x) (primal and dual).

plot_ioda(strrep(H3dvarRP, 'XXX', 'adt'),  'hofx0', 'PNG/3dvarRP_');
plot_ioda(strrep(H3dvarRP, 'XXX', 'adt'),  'hofx1', 'PNG/3dvarRP_');
plot_ioda(strrep(H3dvarRP, 'XXX', 'sst'),  'hofx0', 'PNG/3dvarRP_');
plot_ioda(strrep(H3dvarRP, 'XXX', 'sst'),  'hofx1', 'PNG/3dvarRP_');
plot_ioda(strrep(H3dvarRP, 'XXX', 'temp'), 'hofx0', 'PNG/3dvarRP_');
plot_ioda(strrep(H3dvarRP, 'XXX', 'temp'), 'hofx1', 'PNG/3dvarRP_');
plot_ioda(strrep(H3dvarRP, 'XXX', 'salt'), 'hofx0', 'PNG/3dvarRP_');
plot_ioda(strrep(H3dvarRP, 'XXX', 'salt'), 'hofx1', 'PNG/3dvarRP_');


plot_ioda(strrep(H3dvarRD, 'XXX', 'adt'),  'hofx0', 'PNG/3dvarRD_');
plot_ioda(strrep(H3dvarRD, 'XXX', 'adt'),  'hofx1', 'PNG/3dvarRD_');
plot_ioda(strrep(H3dvarRD, 'XXX', 'sst'),  'hofx0', 'PNG/3dvarRD_');
plot_ioda(strrep(H3dvarRD, 'XXX', 'sst'),  'hofx1', 'PNG/3dvarRD_');
plot_ioda(strrep(H3dvarRD, 'XXX', 'temp'), 'hofx0', 'PNG/3dvarRD_');
plot_ioda(strrep(H3dvarRD, 'XXX', 'temp'), 'hofx1', 'PNG/3dvarRD_');
plot_ioda(strrep(H3dvarRD, 'XXX', 'salt'), 'hofx0', 'PNG/3dvarRD_');
plot_ioda(strrep(H3dvarRD, 'XXX', 'salt'), 'hofx1', 'PNG/3dvarRD_');

% Plot ROMS-JEDI 3D-Var 3D-FGAT H(x) (primal and dual).

plot_ioda(strrep(H3dfgatP, 'XXX', 'adt'),  'hofx0', 'PNG/3dfgatP_');
plot_ioda(strrep(H3dfgatP, 'XXX', 'adt'),  'hofx1', 'PNG/3dfgatP_');
plot_ioda(strrep(H3dfgatP, 'XXX', 'sst'),  'hofx0', 'PNG/3dfgatP_');
plot_ioda(strrep(H3dfgatP, 'XXX', 'sst'),  'hofx1', 'PNG/3dfgatP_');
plot_ioda(strrep(H3dfgatP, 'XXX', 'temp'), 'hofx0', 'PNG/3dfgatP_');
plot_ioda(strrep(H3dfgatP, 'XXX', 'temp'), 'hofx1', 'PNG/3dfgatP_');
plot_ioda(strrep(H3dfgatP, 'XXX', 'salt'), 'hofx0', 'PNG/3dfgatP_');
plot_ioda(strrep(H3dfgatP, 'XXX', 'salt'), 'hofx1', 'PNG/3dfgatP_');

plot_ioda(strrep(H3dfgatD, 'XXX', 'adt'),  'hofx0', 'PNG/3dfgatD_');
plot_ioda(strrep(H3dfgatD, 'XXX', 'adt'),  'hofx1', 'PNG/3dfgatD_');
plot_ioda(strrep(H3dfgatD, 'XXX', 'sst'),  'hofx0', 'PNG/3dfgatD_');
plot_ioda(strrep(H3dfgatD, 'XXX', 'sst'),  'hofx1', 'PNG/3dfgatD_');
plot_ioda(strrep(H3dfgatD, 'XXX', 'temp'), 'hofx0', 'PNG/3dfgatD_');
plot_ioda(strrep(H3dfgatD, 'XXX', 'temp'), 'hofx1', 'PNG/3dfgatD_');
plot_ioda(strrep(H3dfgatD, 'XXX', 'salt'), 'hofx0', 'PNG/3dfgatD_');
plot_ioda(strrep(H3dfgatD, 'XXX', 'salt'), 'hofx1', 'PNG/3dfgatD_');

% Plot ROMS-JEDI 3D-Var 4D-FGAT H(x) (primal and dual).

plot_ioda(strrep(H4dfgatP, 'XXX', 'adt'),  'hofx0', 'PNG/4dfgatP_');
plot_ioda(strrep(H4dfgatP, 'XXX', 'adt'),  'hofx1', 'PNG/4dfgatP_');
plot_ioda(strrep(H4dfgatP, 'XXX', 'sst'),  'hofx0', 'PNG/4dfgatP_');
plot_ioda(strrep(H4dfgatP, 'XXX', 'sst'),  'hofx1', 'PNG/4dfgatP_');
plot_ioda(strrep(H4dfgatP, 'XXX', 'temp'), 'hofx0', 'PNG/4dfgatP_');
plot_ioda(strrep(H4dfgatP, 'XXX', 'temp'), 'hofx1', 'PNG/4dfgatP_');
plot_ioda(strrep(H4dfgatP, 'XXX', 'salt'), 'hofx0', 'PNG/4dfgatP_');
plot_ioda(strrep(H4dfgatP, 'XXX', 'salt'), 'hofx1', 'PNG/4dfgatP_');

plot_ioda(strrep(H4dfgatD, 'XXX', 'adt'),  'hofx0', 'PNG/4dfgatD_');
plot_ioda(strrep(H4dfgatD, 'XXX', 'adt'),  'hofx1', 'PNG/4dfgatD_');
plot_ioda(strrep(H4dfgatD, 'XXX', 'sst'),  'hofx0', 'PNG/4dfgatD_');
plot_ioda(strrep(H4dfgatD, 'XXX', 'sst'),  'hofx1', 'PNG/4dfgatD_');
plot_ioda(strrep(H4dfgatD, 'XXX', 'temp'), 'hofx0', 'PNG/4dfgatD_');
plot_ioda(strrep(H4dfgatD, 'XXX', 'temp'), 'hofx1', 'PNG/4dfgatD_');
plot_ioda(strrep(H4dfgatD, 'XXX', 'salt'), 'hofx0', 'PNG/4dfgatD_');
plot_ioda(strrep(H4dfgatD, 'XXX', 'salt'), 'hofx1', 'PNG/4dfgatD_');

% Plot ROMS-JEDI Regular 3DEnVar H(x) (primal and dual).

plot_ioda(strrep(H3denvarRP, 'XXX', 'adt'),  'hofx0', 'PNG/3denvarRP_');
plot_ioda(strrep(H3denvarRP, 'XXX', 'adt'),  'hofx1', 'PNG/3denvarRP_');
plot_ioda(strrep(H3denvarRP, 'XXX', 'sst'),  'hofx0', 'PNG/3denvarRP_');
plot_ioda(strrep(H3denvarRP, 'XXX', 'sst'),  'hofx1', 'PNG/3denvarRP_');
plot_ioda(strrep(H3denvarRP, 'XXX', 'temp'), 'hofx0', 'PNG/3denvarRP_');
plot_ioda(strrep(H3denvarRP, 'XXX', 'temp'), 'hofx1', 'PNG/3denvarRP_');
plot_ioda(strrep(H3denvarRP, 'XXX', 'salt'), 'hofx0', 'PNG/3denvarRP_');
plot_ioda(strrep(H3denvarRP, 'XXX', 'salt'), 'hofx1', 'PNG/3denvarRP_');

plot_ioda(strrep(H3denvarRD, 'XXX', 'adt'),  'hofx0', 'PNG/3denvarRD_');
plot_ioda(strrep(H3denvarRD, 'XXX', 'adt'),  'hofx1', 'PNG/3denvarRD_');
plot_ioda(strrep(H3denvarRD, 'XXX', 'sst'),  'hofx0', 'PNG/3denvarRD_');
plot_ioda(strrep(H3denvarRD, 'XXX', 'sst'),  'hofx1', 'PNG/3denvarRD_');
plot_ioda(strrep(H3denvarRD, 'XXX', 'temp'), 'hofx0', 'PNG/3denvarRD_');
plot_ioda(strrep(H3denvarRD, 'XXX', 'temp'), 'hofx1', 'PNG/3denvarRD_');
plot_ioda(strrep(H3denvarRD, 'XXX', 'salt'), 'hofx0', 'PNG/3denvarRD_');
plot_ioda(strrep(H3denvarRD, 'XXX', 'salt'), 'hofx1', 'PNG/3denvarRD_');

% Plot ROMS-JEDI 3DEnVar 4D-FGAT H(x) (primal and dual).

plot_ioda(strrep(H3denvarFP, 'XXX', 'adt'),  'hofx0', 'PNG/3denvarFP_');
plot_ioda(strrep(H3denvarFP, 'XXX', 'adt'),  'hofx1', 'PNG/3denvarFP_');
plot_ioda(strrep(H3denvarFP, 'XXX', 'sst'),  'hofx0', 'PNG/3denvarFP_');
plot_ioda(strrep(H3denvarFP, 'XXX', 'sst'),  'hofx1', 'PNG/3denvarFP_');
plot_ioda(strrep(H3denvarFP, 'XXX', 'temp'), 'hofx0', 'PNG/3denvarFP_');
plot_ioda(strrep(H3denvarFP, 'XXX', 'temp'), 'hofx1', 'PNG/3denvarFP_');
plot_ioda(strrep(H3denvarFP, 'XXX', 'salt'), 'hofx0', 'PNG/3denvarFP_');
plot_ioda(strrep(H3denvarFP, 'XXX', 'salt'), 'hofx1', 'PNG/3denvarFP_');

plot_ioda(strrep(H3denvarFD, 'XXX', 'adt'),  'hofx0', 'PNG/3denvarFD_');
plot_ioda(strrep(H3denvarFD, 'XXX', 'adt'),  'hofx1', 'PNG/3denvarFD_');
plot_ioda(strrep(H3denvarFD, 'XXX', 'sst'),  'hofx0', 'PNG/3denvarFD_');
plot_ioda(strrep(H3denvarFD, 'XXX', 'sst'),  'hofx1', 'PNG/3denvarFD_');
plot_ioda(strrep(H3denvarFD, 'XXX', 'temp'), 'hofx0', 'PNG/3denvarFD_');
plot_ioda(strrep(H3denvarFD, 'XXX', 'temp'), 'hofx1', 'PNG/3denvarFD_');
plot_ioda(strrep(H3denvarFD, 'XXX', 'salt'), 'hofx0', 'PNG/3denvarFD_');
plot_ioda(strrep(H3denvarFD, 'XXX', 'salt'), 'hofx1', 'PNG/3denvarFD_');

% Plot ROMS-JEDI Regular Hybrid 3DEnVar H(x) (primal and dual).

plot_ioda(strrep(H3dhybRP, 'XXX', 'adt'),  'hofx0', 'PNG/3dhybRP_');
plot_ioda(strrep(H3dhybRP, 'XXX', 'adt'),  'hofx1', 'PNG/3dhybRP_');
plot_ioda(strrep(H3dhybRP, 'XXX', 'sst'),  'hofx0', 'PNG/3dhybRP_');
plot_ioda(strrep(H3dhybRP, 'XXX', 'sst'),  'hofx1', 'PNG/3dhybRP_');
plot_ioda(strrep(H3dhybRP, 'XXX', 'temp'), 'hofx0', 'PNG/3dhybRP_');
plot_ioda(strrep(H3dhybRP, 'XXX', 'temp'), 'hofx1', 'PNG/3dhybRP_');
plot_ioda(strrep(H3dhybRP, 'XXX', 'salt'), 'hofx0', 'PNG/3dhybRP_');
plot_ioda(strrep(H3dhybRP, 'XXX', 'salt'), 'hofx1', 'PNG/3dhybRP_');

plot_ioda(strrep(H3dhybRD, 'XXX', 'adt'),  'hofx0', 'PNG/3dhybRD_');
plot_ioda(strrep(H3dhybRD, 'XXX', 'adt'),  'hofx1', 'PNG/3dhybRD_');
plot_ioda(strrep(H3dhybRD, 'XXX', 'sst'),  'hofx0', 'PNG/3dhybRD_');
plot_ioda(strrep(H3dhybRD, 'XXX', 'sst'),  'hofx1', 'PNG/3dhybRD_');
plot_ioda(strrep(H3dhybRD, 'XXX', 'temp'), 'hofx0', 'PNG/3dhybRD_');
plot_ioda(strrep(H3dhybRD, 'XXX', 'temp'), 'hofx1', 'PNG/3dhybRD_');
plot_ioda(strrep(H3dhybRD, 'XXX', 'salt'), 'hofx0', 'PNG/3dhybRD_');
plot_ioda(strrep(H3dhybRD, 'XXX', 'salt'), 'hofx1', 'PNG/3dhybRD_');

% Plot ROMS-JEDI Hybrid 3DEnVar 4D-FGAT H(x) (primal and dual).

plot_ioda(strrep(H3dhybFP, 'XXX', 'adt'),  'hofx0', 'PNG/3dhybFP_');
plot_ioda(strrep(H3dhybFP, 'XXX', 'adt'),  'hofx1', 'PNG/3dhybFP_');
plot_ioda(strrep(H3dhybFP, 'XXX', 'sst'),  'hofx0', 'PNG/3dhybFP_');
plot_ioda(strrep(H3dhybFP, 'XXX', 'sst'),  'hofx1', 'PNG/3dhybFP_');
plot_ioda(strrep(H3dhybFP, 'XXX', 'temp'), 'hofx0', 'PNG/3dhybFP_');
plot_ioda(strrep(H3dhybFP, 'XXX', 'temp'), 'hofx1', 'PNG/3dhybFP_');
plot_ioda(strrep(H3dhybFP, 'XXX', 'salt'), 'hofx0', 'PNG/3dhybFP_');
plot_ioda(strrep(H3dhybFP, 'XXX', 'salt'), 'hofx1', 'PNG/3dhybFP_');

plot_ioda(strrep(H3dhybFD, 'XXX', 'adt'),  'hofx0', 'PNG/3dhybFD_');
plot_ioda(strrep(H3dhybFD, 'XXX', 'adt'),  'hofx1', 'PNG/3dhybFD_');
plot_ioda(strrep(H3dhybFD, 'XXX', 'sst'),  'hofx0', 'PNG/3dhybFD_');
plot_ioda(strrep(H3dhybFD, 'XXX', 'sst'),  'hofx1', 'PNG/3dhybFD_');
plot_ioda(strrep(H3dhybFD, 'XXX', 'temp'), 'hofx0', 'PNG/3dhybFD_');
plot_ioda(strrep(H3dhybFD, 'XXX', 'temp'), 'hofx1', 'PNG/3dhybFD_');
plot_ioda(strrep(H3dhybFD, 'XXX', 'salt'), 'hofx0', 'PNG/3dhybFD_');
plot_ioda(strrep(H3dhybFD, 'XXX', 'salt'), 'hofx1', 'PNG/3dhybFD_');

% Plot ROMS-JEDI 4D-Var H(x) (BUMP and Diffusion).

plot_ioda(strrep(H4dvarB, 'XXX', 'adt'),  'hofx0', 'PNG/4dvarB_');
plot_ioda(strrep(H4dvarB, 'XXX', 'adt'),  'hofx1', 'PNG/4dvarB_');
plot_ioda(strrep(H4dvarB, 'XXX', 'sst'),  'hofx0', 'PNG/4dvarB_');
plot_ioda(strrep(H4dvarB, 'XXX', 'sst'),  'hofx1', 'PNG/4dvarB_');
plot_ioda(strrep(H4dvarB, 'XXX', 'temp'), 'hofx0', 'PNG/4dvarB_');
plot_ioda(strrep(H4dvarB, 'XXX', 'temp'), 'hofx1', 'PNG/4dvarB_');
plot_ioda(strrep(H4dvarB, 'XXX', 'salt'), 'hofx0', 'PNG/4dvarB_');
plot_ioda(strrep(H4dvarB, 'XXX', 'salt'), 'hofx1', 'PNG/4dvarB_');

plot_ioda(strrep(H4dvarD, 'XXX', 'adt'),  'ombg', 'PNG/4dvarD_');
plot_ioda(strrep(H4dvarD, 'XXX', 'adt'),  'oman', 'PNG/4dvarD_');
plot_ioda(strrep(H4dvarD, 'XXX', 'sst'),  'ombg', 'PNG/4dvarD_');
plot_ioda(strrep(H4dvarD, 'XXX', 'sst'),  'oman', 'PNG/4dvarD_');
plot_ioda(strrep(H4dvarD, 'XXX', 'temp'), 'ombg', 'PNG/4dvarD_');
plot_ioda(strrep(H4dvarD, 'XXX', 'temp'), 'oman', 'PNG/4dvarD_');
plot_ioda(strrep(H4dvarD, 'XXX', 'salt'), 'ombg', 'PNG/4dvarD_');
plot_ioda(strrep(H4dvarD, 'XXX', 'salt'), 'oman', 'PNG/4dvarD_');

%--------------------------------------------------------------------------
% Kalman Filter Data Assimilation.
%--------------------------------------------------------------------------

% Plot LETKF H(x), ensemble member 1

plot_ioda(strrep(HletKF, 'XXX', 'adt'),  'hofx0_1', 'PNG/letKF_');
plot_ioda(strrep(HletKF, 'XXX', 'sst'),  'hofx0_1', 'PNG/letKF_');
plot_ioda(strrep(HletKF, 'XXX', 'temp'), 'hofx0_1', 'PNG/letKF_');
plot_ioda(strrep(HletKF, 'XXX', 'salt'), 'hofx0_1', 'PNG/letKF_');

% Plot LETKF split observer H(x), member 1

plot_ioda(strrep(HletKFsplit, 'XXX', 'adt'), 'hofx0_1', 'PNG/letKF_');
plot_ioda(strrep(HletKFsplit, 'XXX', 'sst'), 'hofx0_1', 'PNG/letKF_');

% Plot LETKF/Hybrid 3DEnVar H(x).

plot_ioda(strrep(HletKF3dhyb, 'XXX', 'adt'), 'hofx0', 'PNG/letKF_3dhyb_');
plot_ioda(strrep(HletKF3dhyb, 'XXX', 'sst'), 'hofx1', 'PNG/letKF_3dhyb_');




