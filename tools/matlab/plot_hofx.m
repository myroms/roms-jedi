%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Matlab Script to plot H(x). %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Initialize. All the directory paths are relative to:
%
%             ${ROMS_HOME}/roms-jedi/tools/matlab
%

Hdir = '../../build/roms-jedi/test/Data/';

H3dvarRP    = [Hdir, '3dvar/regular/primal/wc13_XXX_3dvar_regular.nc4'];
H3dvarRD    = [Hdir, '3dvar/regular/dual/wc13_XXX_3dvar_regular.nc4'];

H3dvarFP    = [Hdir, '3dvar/fgat/primal/wc13_XXX_3dvar_fgat.nc4'];
H3dvarFD    = [Hdir, '3dvar/fgat/dual/wc13_XXX_3dvar_fgat.nc4'];

H3denvarRP  = [Hdir, '3denvar/regular/primal/wc13_XXX_3denvar_regular.nc4'];
H3denvarRD  = [Hdir, '3denvar/regular/dual/wc13_XXX_3denvar_regular.nc4'];

H3denvarFP  = [Hdir, '3denvar/fgat/primal/wc13_XXX_3denvar_fgat.nc4'];
H3denvarFD  = [Hdir, '3denvar/fgat/dual/wc13_XXX_3denvar_fgat.nc4'];

H3dhybRP    = [Hdir, '3dhyb/regular/primal/wc13_XXX_3dhyb_regular.nc4'];
H3dhybRD    = [Hdir, '3dhyb/regular/dual/wc13_XXX_3dhyb_regular.nc4'];

H3dhybFP    = [Hdir, '3dhyb/fgat/primal/wc13_XXX_3dhyb_fgat.nc4'];
H3dhybFD    = [Hdir, '3dhyb/fgat/dual/wc13_XXX_3dhyb_fgat.nc4'];

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

% Plot ROMS-JEDI 3D-Var FGAT H(x) (primal and dual).

plot_ioda(strrep(H3dvarFP, 'XXX', 'adt'), 'hofx0', 'PNG/3dvarFP_');
plot_ioda(strrep(H3dvarFP, 'XXX', 'adt'), 'hofx1', 'PNG/3dvarFP_');
plot_ioda(strrep(H3dvarFP, 'XXX', 'sst'), 'hofx0', 'PNG/3dvarFP_');
plot_ioda(strrep(H3dvarFP, 'XXX', 'sst'), 'hofx1', 'PNG/3dvarFP_');

plot_ioda(strrep(H3dvarFD, 'XXX', 'adt'), 'hofx0', 'PNG/3dvarFD_');
plot_ioda(strrep(H3dvarFD, 'XXX', 'adt'), 'hofx1', 'PNG/3dvarFD_');
plot_ioda(strrep(H3dvarFD, 'XXX', 'sst'), 'hofx0', 'PNG/3dvarFD_');
plot_ioda(strrep(H3dvarFD, 'XXX', 'sst'), 'hofx1', 'PNG/3dvarFD_');

% Plot ROMS-JEDI Regular 3DEnVar H(x) (primal and dual).

plot_ioda(strrep(H3denvarRP, 'XXX', 'adt'), 'hofx0', 'PNG/3denvarRP_');
plot_ioda(strrep(H3denvarRP, 'XXX', 'adt'), 'hofx1', 'PNG/3denvarRP_');
plot_ioda(strrep(H3denvarRP, 'XXX', 'sst'), 'hofx0', 'PNG/3denvarRP_');
plot_ioda(strrep(H3denvarRP, 'XXX', 'sst'), 'hofx1', 'PNG/3denvarRP_');

plot_ioda(strrep(H3denvarRD, 'XXX', 'adt'), 'hofx0', 'PNG/3denvarRD_');
plot_ioda(strrep(H3denvarRD, 'XXX', 'adt'), 'hofx1', 'PNG/3denvarRD_');
plot_ioda(strrep(H3denvarRD, 'XXX', 'sst'), 'hofx0', 'PNG/3denvarRD_');
plot_ioda(strrep(H3denvarRD, 'XXX', 'sst'), 'hofx1', 'PNG/3denvarRD_');

% Plot ROMS-JEDI 3DEnVar FGAT H(x) (primal and dual).

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

% Plot ROMS-JEDI Hybrid 3DEnVar FGAT H(x) (primal and dual).

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




