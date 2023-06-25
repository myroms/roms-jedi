%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Matlab Script to plot H(x). %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Initialize. All the directory paths are relative to:
%
%             ${ROMS_HOME}/roms-jedi/tools/matlab
%

% Set ROMS-JEDI Data sub-directory with respect the "build":

%Hdir = '../../build/roms-jedi/test/Data/';
 Hdir = '../../build_wc13/roms-jedi/test/Data/';

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

HletKF      = [Hdir, 'letkf/solver/wc13_XXX_letkf.nc4'];
HletKFsplit = [Hdir, 'letkf/split_observer/wc13_XXX_letkf_split_observer.nc4'];
HletKF3dhyb = [Hdir, 'letkf/3dhyb/wc13_XXX_letkf_3dhyb.nc4'];

%--------------------------------------------------------------------------
% Variational Data Assimilation.
%--------------------------------------------------------------------------

% Plot ROMS-JEDI Regular 3D-Var H(x) (primal and dual).

plot_ioda(strrep(H3dvarRP, 'XXX', 'adt'), 'hofx0', 'PNG/3dvarRP_');
plot_ioda(strrep(H3dvarRP, 'XXX', 'adt'), 'hofx1', 'PNG/3dvarRP_');
plot_ioda(strrep(H3dvarRP, 'XXX', 'sst'), 'hofx0', 'PNG/3dvarRP_');
plot_ioda(strrep(H3dvarRP, 'XXX', 'sst'), 'hofx1', 'PNG/3dvarRP_');

plot_ioda(strrep(H3dvarRD, 'XXX', 'adt'), 'hofx0', 'PNG/3dvarRD_');
plot_ioda(strrep(H3dvarRD, 'XXX', 'adt'), 'hofx1', 'PNG/3dvarRD_');
plot_ioda(strrep(H3dvarRD, 'XXX', 'sst'), 'hofx0', 'PNG/3dvarRD_');
plot_ioda(strrep(H3dvarRD, 'XXX', 'sst'), 'hofx1', 'PNG/3dvarRD_');

% Plot ROMS-JEDI 3D-Var 3D-FGAT H(x) (primal and dual).

plot_ioda(strrep(H3dfgatP, 'XXX', 'adt'), 'hofx0', 'PNG/3dfgatP_');
plot_ioda(strrep(H3dfgatP, 'XXX', 'adt'), 'hofx1', 'PNG/3dfgatP_');
plot_ioda(strrep(H3dfgatP, 'XXX', 'sst'), 'hofx0', 'PNG/3dfgatP_');
plot_ioda(strrep(H3dfgatP, 'XXX', 'sst'), 'hofx1', 'PNG/3dfgatP_');

plot_ioda(strrep(H3dfgatD, 'XXX', 'adt'), 'hofx0', 'PNG/3dfgatD_');
plot_ioda(strrep(H3dfgatD, 'XXX', 'adt'), 'hofx1', 'PNG/3dfgatD_');
plot_ioda(strrep(H3dfgatD, 'XXX', 'sst'), 'hofx0', 'PNG/3dfgatD_');
plot_ioda(strrep(H3dfgatD, 'XXX', 'sst'), 'hofx1', 'PNG/3dfgatD_');

% Plot ROMS-JEDI 3D-Var 4D-FGAT H(x) (primal and dual).

plot_ioda(strrep(H4dfgatP, 'XXX', 'adt'), 'hofx0', 'PNG/4dfgatP_');
plot_ioda(strrep(H4dfgatP, 'XXX', 'adt'), 'hofx1', 'PNG/4dfgatP_');
plot_ioda(strrep(H4dfgatP, 'XXX', 'sst'), 'hofx0', 'PNG/4dfgatP_');
plot_ioda(strrep(H4dfgatP, 'XXX', 'sst'), 'hofx1', 'PNG/4dfgatP_');

plot_ioda(strrep(H4dfgatD, 'XXX', 'adt'), 'hofx0', 'PNG/4dfgatD_');
plot_ioda(strrep(H4dfgatD, 'XXX', 'adt'), 'hofx1', 'PNG/4dfgatD_');
plot_ioda(strrep(H4dfgatD, 'XXX', 'sst'), 'hofx0', 'PNG/4dfgatD_');
plot_ioda(strrep(H4dfgatD, 'XXX', 'sst'), 'hofx1', 'PNG/4dfgatD_');

% Plot ROMS-JEDI Regular 3DEnVar H(x) (primal and dual).

plot_ioda(strrep(H3denvarRP, 'XXX', 'adt'), 'hofx0', 'PNG/3denvarRP_');
plot_ioda(strrep(H3denvarRP, 'XXX', 'adt'), 'hofx1', 'PNG/3denvarRP_');
plot_ioda(strrep(H3denvarRP, 'XXX', 'sst'), 'hofx0', 'PNG/3denvarRP_');
plot_ioda(strrep(H3denvarRP, 'XXX', 'sst'), 'hofx1', 'PNG/3denvarRP_');

plot_ioda(strrep(H3denvarRD, 'XXX', 'adt'), 'hofx0', 'PNG/3denvarRD_');
plot_ioda(strrep(H3denvarRD, 'XXX', 'adt'), 'hofx1', 'PNG/3denvarRD_');
plot_ioda(strrep(H3denvarRD, 'XXX', 'sst'), 'hofx0', 'PNG/3denvarRD_');
plot_ioda(strrep(H3denvarRD, 'XXX', 'sst'), 'hofx1', 'PNG/3denvarRD_');

% Plot ROMS-JEDI 3DEnVar 4D-FGAT H(x) (primal and dual).

plot_ioda(strrep(H3denvarFP, 'XXX', 'adt'), 'hofx0', 'PNG/3denvarFP_');
plot_ioda(strrep(H3denvarFP, 'XXX', 'adt'), 'hofx1', 'PNG/3denvarFP_');
plot_ioda(strrep(H3denvarFP, 'XXX', 'sst'), 'hofx0', 'PNG/3denvarFP_');
plot_ioda(strrep(H3denvarFP, 'XXX', 'sst'), 'hofx1', 'PNG/3denvarFP_');

plot_ioda(strrep(H3denvarFD, 'XXX', 'adt'), 'hofx0', 'PNG/3denvarFD_');
plot_ioda(strrep(H3denvarFD, 'XXX', 'adt'), 'hofx1', 'PNG/3denvarFD_');
plot_ioda(strrep(H3denvarFD, 'XXX', 'sst'), 'hofx0', 'PNG/3denvarFD_');
plot_ioda(strrep(H3denvarFD, 'XXX', 'sst'), 'hofx1', 'PNG/3denvarFD_');

% Plot ROMS-JEDI Regular Hybrid 3DEnVar H(x) (primal and dual).

plot_ioda(strrep(H3dhybRP, 'XXX', 'adt'), 'hofx0', 'PNG/3dhybRP_');
plot_ioda(strrep(H3dhybRP, 'XXX', 'adt'), 'hofx1', 'PNG/3dhybRP_');
plot_ioda(strrep(H3dhybRP, 'XXX', 'sst'), 'hofx0', 'PNG/3dhybRP_');
plot_ioda(strrep(H3dhybRP, 'XXX', 'sst'), 'hofx1', 'PNG/3dhybRP_');

plot_ioda(strrep(H3dhybRD, 'XXX', 'adt'), 'hofx0', 'PNG/3dhybRD_');
plot_ioda(strrep(H3dhybRD, 'XXX', 'adt'), 'hofx1', 'PNG/3dhybRD_');
plot_ioda(strrep(H3dhybRD, 'XXX', 'sst'), 'hofx0', 'PNG/3dhybRD_');
plot_ioda(strrep(H3dhybRD, 'XXX', 'sst'), 'hofx1', 'PNG/3dhybRD_');

% Plot ROMS-JEDI Hybrid 3DEnVar 4D-FGAT H(x) (primal and dual).

plot_ioda(strrep(H3dhybFP, 'XXX', 'adt'), 'hofx0', 'PNG/3dhybFP_');
plot_ioda(strrep(H3dhybFP, 'XXX', 'adt'), 'hofx1', 'PNG/3dhybFP_');
plot_ioda(strrep(H3dhybFP, 'XXX', 'sst'), 'hofx0', 'PNG/3dhybFP_');
plot_ioda(strrep(H3dhybFP, 'XXX', 'sst'), 'hofx1', 'PNG/3dhybFP_');

plot_ioda(strrep(H3dhybFD, 'XXX', 'adt'), 'hofx0', 'PNG/3dhybFD_');
plot_ioda(strrep(H3dhybFD, 'XXX', 'adt'), 'hofx1', 'PNG/3dhybFD_');
plot_ioda(strrep(H3dhybFD, 'XXX', 'sst'), 'hofx0', 'PNG/3dhybFD_');
plot_ioda(strrep(H3dhybFD, 'XXX', 'sst'), 'hofx1', 'PNG/3dhybFD_');

%--------------------------------------------------------------------------
% Kalman Filter Data Assimilation.
%--------------------------------------------------------------------------

% Plot LETKF H(x), ensemble member 1

plot_ioda(strrep(HletKF, 'XXX', 'adt'), 'hofx0_1', 'PNG/letKF_');
plot_ioda(strrep(HletKF, 'XXX', 'sst'), 'hofx0_1', 'PNG/letKF_');

% Plot LETKF split observer H(x), member 1

plot_ioda(strrep(HletKFsplit, 'XXX', 'adt'), 'hofx0_1', 'PNG/letKF_');
plot_ioda(strrep(HletKFsplit, 'XXX', 'sst'), 'hofx0_1', 'PNG/letKF_');

% Plot LETKF/Hybrid 3DEnVar H(x).

plot_ioda(strrep(HletKF3dhyb, 'XXX', 'adt'), 'hofx0', 'PNG/letKF_3dhyb_');
plot_ioda(strrep(HletKF3dhyb, 'XXX', 'sst'), 'hofx1', 'PNG/letKF_3dhyb_');




