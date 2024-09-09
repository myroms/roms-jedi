%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Matlab script to plot ROMS-JEDI Data Assimilation Increments. %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% It uses the following native ROMS Matlab repository functions:
%
%    matlab/grid/get_roms_grid.m
%    matlab/utility/plot_field.m
%
% ROMS Matlab repository: svn checkout https://www.myroms.org/svn/src/matlab
%

% Initialize. All the directory paths are relative to:
%
%             ${ROMS_HOME}/roms-jedi/tools/matlab

% If available, set native ROMS RBL-4DVar increment for comparison:

Iname = '../../../jediroms_wc13/RBL4DVAR/r01/wc13_itl_20040103.nc';

if (exist(Iname, 'file'))
  got_RBL4DVAR = true;
else
  got_RBL4DVAR = false;
end

% Set ROMS-JEDI Data sub-directory with respect the "build":

% Bdir  = '../../build/roms-jedi/test/Data/';
  Bdir  = '../../build_wc13/roms-jedi/test/Data/';

% Set ROMS nonlinear model history file. Only needed to build
% ROMS application grid structure.

Hname = [Bdir, 'roms/wc13_his.nc'];

% Set inital and middle DA window NetCDF suffixes.

IniDate = '2004-01-03-00.00.00.nc';
MidDate = '2004-01-05-00.00.00.nc';
  
% ROMS-JEDI Ouput NetCDF files with respect sub-directory "Bdir":

I3dvarRP    = [Bdir, '3dvar/regular/primal/wc13_roms_3dvar_inc_', MidDate];
I3dvarRD    = [Bdir, '3dvar/regular/dual/wc13_roms_3dvar_inc_',   MidDate];

I3dfgatP    = [Bdir, '3dvar/3dfgat/primal/wc13_roms_3dfgat_inc_' MidDate];
I3dfgatD    = [Bdir, '3dvar/3dfgat/dual/wc13_roms_3dfgat_inc_',  MidDate];

I4dfgatP    = [Bdir, '3dvar/4dfgat/primal/wc13_roms_4dfgat_inc_' IniDate];
I4dfgatD    = [Bdir, '3dvar/4dfgat/dual/wc13_roms_4dfgat_inc_',  IniDate];

I3denvarRP  = [Bdir, '3denvar/regular/primal/wc13_roms_3denvar_inc_', MidDate];
I3denvarRD  = [Bdir, '3denvar/regular/dual/wc13_roms_3denvar_inc_',   MidDate];

I3denvarFP  = [Bdir, '3denvar/4dfgat/primal/wc13_roms_3denvar_inc_', IniDate];
I3denvarFD  = [Bdir, '3denvar/4dfgat/dual/wc13_roms_3denvar_inc_',   IniDate];

I3dhybRP    = [Bdir, '3dhyb/regular/primal/wc13_roms_3dhyb_inc_', MidDate];
I3dhybRD    = [Bdir, '3dhyb/regular/dual/wc13_roms_3dhyb_inc_',   MidDate];

I3dhybFP    = [Bdir, '3dhyb/4dfgat/primal/wc13_roms_3dhyb_inc_', IniDate];
I3dhybFD    = [Bdir, '3dhyb/4dfgat/dual/wc13_roms_3dhyb_inc_',   IniDate];

IletKF      = [Bdir, 'letkf/solver/wc13_roms_letkf_inc_',       IniDate];
IletKFsplit = [Bdir, 'letkf/split_solver/wc13_roms_letkf_inc_', IniDate];
IletKF3dhyb = [Bdir, 'letkf/3dhyb/wc13_roms_3dhyb_inc_',        IniDate]; 

rh  = 160;                % horizontal correlation radius (km)
rv  = 150;                % vertical correlation radius (m)
rec = 2;                  % native 4D-Var final outer-loop increments
lev = 30;                 % surface level

wrtPNG  = false;
DoTitle = true;

 IncVar='temp'; PNGprefix='PNG/Tsur_'; Frange=[-1.5 1.5];   Vname='  Surface Temperature';
%IncVar='zeta'; PNGprefix='PNG/SSH_';  Frange=[-0.15 0.15]; Vname='  Free Surface';

%Label=[' (', num2str(rh), 'km, ', num2str(rv), 'm)'];
 Label=blanks(2); 

% Get Grid structure.

if (~exist('G', 'var'))
  G = get_roms_grid(Hname, Hname, 1);
end

% If applicable, create PNG subdirectory.

if (wrtPNG && ~exist('PNG', 'dir'))
  unix('mkdir PNG');
end

%--------------------------------------------------------------------------
% Variational Data Assimilation.
%--------------------------------------------------------------------------

% Plot native 4D-Var increments (rh=50 km, rv=30 m).

if (got_RBL4DVAR)
 F = plot_field(G, Iname, IncVar, rec, lev, Frange, true, -20);
 if (DoTitle)
   title(strcat('Dual 4D-Var: ',Vname,' (50km, 30m)'));
 else
   title(blanks(2));
 end
 if (wrtPNG)
   print(strcat(PNGprefix,'dual_4dvar.png'),'-dpng','-r300');
 end
end

% Plot ROMS-JEDI Regular 3D-Var increments (primal and dual).

F = plot_field(G, I3dvarRP, IncVar, 1, lev, Frange, true, -20);
if (DoTitle)
  title(strcat('Primal 3D-Var: ', Vname, Label));
else
  title(blanks(2));
end
if (wrtPNG)
  print(strcat(PNGprefix,'primal_3dvar.png'),'-dpng','-r300');
end

F = plot_field(G, I3dvarRD, IncVar, 1, lev, Frange, true, -20);
if (DoTitle)
  title(strcat('Dual 3D-Var: ',Vname, Label));
else
  title(blanks(2));
end
if (wrtPNG)
  print(strcat(PNGprefix,'dual_3dvar.png'),'-dpng','-r300');
end

% Plot ROMS-JEDI 3D-FGAT increments (primal and dual).

F = plot_field(G, I3dfgatP, IncVar, 1, lev, Frange, true, -20);
if (DoTitle)
  title(strcat('Primal 3D-FGAT: ',Vname, Label));
else
  title(blanks(2));
end
if (wrtPNG)
  print(strcat(PNGprefix,'primal_3dfgat.png'),'-dpng','-r300');
end

F = plot_field(G, I3dfgatD, IncVar, 1, lev, Frange, true, -20);
if (DoTitle)
  title(strcat('Dual 3D-FGAT: ', Vname, Label));
else
  title(blanks(2));
end
if (wrtPNG)
  print(strcat(PNGprefix,'dual_3dfgat.png'),'-dpng','-r300');
end

% Plot ROMS-JEDI 4D-FGAT increments (primal and dual).

F = plot_field(G, I4dfgatP, IncVar, 1, lev, Frange, true, -20);
if (DoTitle)
  title(strcat('Primal 4D-FGAT: ',Vname, Label));
else
  title(blanks(2));
end
if (wrtPNG)
  print(strcat(PNGprefix,'primal_4dfgat.png'),'-dpng','-r300');
end

F = plot_field(G, I3dfgatD, IncVar, 1, lev, Frange, true, -20);
if (DoTitle)
  title(strcat('Dual 4D-FGAT: ', Vname, Label));
else
  title(blanks(2));
end
if (wrtPNG)
  print(strcat(PNGprefix,'dual_4dfgat.png'),'-dpng','-r300');
end

% Plot ROMS-JEDI Regular 3DEnVar increments (primal and dual).

F = plot_field(G, I3denvarRP, IncVar, 1, lev, Frange, true, -20);
if (DoTitle)
  title(strcat('Primal 3DEnVar: ', Vname, Label));
else
  title(blanks(2));
end
if (wrtPNG)
  print(strcat(PNGprefix,'primal_3denvar.png'),'-dpng','-r300');
end

F = plot_field(G, I3denvarRD, IncVar, 1, lev, Frange, true, -20);
if (DoTitle)
  title(strcat('Dual 3DEnVar: ', Vname, Label));
else
  title(blanks(2));
end
if (wrtPNG)
  print(strcat(PNGprefix,'dual_3denvar.png'),'-dpng','-r300');
end

% Plot ROMS-JEDI 3DEnVar 4D-FGAT increments (primal and dual).

F = plot_field(G, I3denvarFP, IncVar, 1, lev, Frange, true, -20);
if (DoTitle)
  title(strcat('Primal 3DEnVar-4DFGAT: ', Vname, Label));
else
  title(blanks(2));
end
if (wrtPNG)
  print(strcat(PNGprefix,'primal_3denvar_fgat.png'),'-dpng','-r300');
end

F = plot_field(G, I3denvarFD, IncVar, 1, lev, Frange, true, -20);
if (DoTitle)
  title(strcat('Dual 3DEnVar-4DFGAT: ', Vname, Label));
else
  title(blanks(2));
end
if (wrtPNG)
  print(strcat(PNGprefix,'dual_3denvar_fgat.png'),'-dpng','-r300');
end

% Plot ROMS-JEDI Regular Hybrid 3DEnVar increments (primal and dual).

F = plot_field(G, I3dhybRP, IncVar, 1, lev, Frange, true, -20);
if (DoTitle)
  title(strcat('Primal Hybrid 3DEnVar: ', Vname, Label));
else
  title(blanks(2));
end
if (wrtPNG)
  print(strcat(PNGprefix,'primal_3dhyb.png'), '-dpng','-r300');
end

F = plot_field(G, I3dhybRD, IncVar, 1, lev, Frange, true, -20);
if (DoTitle)
  title(strcat('Dual Hybrid 3DEnVar: ', Vname, Label));
else
  title(blanks(2));
end
if (wrtPNG)
  print(strcat(PNGprefix,'dual_3dhyb.png'),'-dpng','-r300');
end

% Plot ROMS-JEDI Hybrid 3DEnVar 4D-FGAT increments (primal and dual).

F = plot_field(G, I3dhybFP, IncVar, 1, lev, Frange, true, -20);
if (DoTitle)
  title(strcat('Primal Hybrid 3DEnVar-4DFGAT: ', Vname, Label));
else
  title(blanks(2));
end
if (wrtPNG)
  print(strcat(PNGprefix,'primal_3dhyb_4dfgat.png'),'-dpng','-r300');
end

F = plot_field(G, I3dhybFD, IncVar, 1, lev, Frange, true, -20);
if (DoTitle)
  title(strcat('Dual Hybrid 3DEnVar-FGAT: ', Vname, Label));
else
  title(blanks(2));
end
if (wrtPNG)
  print(strcat(PNGprefix,'dual_3dhyb_4dfgat.png'),'-dpng','-r300');
end

%--------------------------------------------------------------------------
% Kalman Filter Data Assimilation.
%--------------------------------------------------------------------------

% Plot LETKF

F = plot_field(G, IletKF, IncVar, 1, lev, Frange, true, -20);
if (DoTitle)
  title(strcat('LETKF:', Vname, Label));
else
  title(blanks(2));
end
if (wrtPNG)
  print(strcat(PNGprefix,'letkf.png'),'-dpng','-r300');
end

% Plot LETKF split observer solver

F = plot_field(G, IletKFsplit, IncVar, 1, lev, Frange, true, -20);
if (DoTitle)
  title(strcat('LETKF Split Observer:', Vname, Label));
else
  title(blanks(2));
end
if (wrtPNG)
  print(strcat(PNGprefix,'letkf_split_observer.png'),'-dpng','-r300');
end

% Plot LETKF/Hybrid 3DEnVar.

F = plot_field(G, IletKF3dhyb, IncVar, 1, lev, Frange, true, -20);
if (DoTitle)
  title(strcat('LETKF/Hybrid 3DEnVar:', Vname, Label));
else
  title(blanks(2));
end
if (wrtPNG)
  print(strcat(PNGprefix,'letkf_3dhyb.png'),'-dpng','-r300');
end
