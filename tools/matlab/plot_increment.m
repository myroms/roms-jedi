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

Hname  = '../../../jediroms_wc13/RBL4DVAR/r01/wc13_fwd_20040103_outer0.nc';
Iname1 = '../../../jediroms_wc13/RBL4DVAR/r01/wc13_itl_20040103.nc';

  Bdir  = '../../build/roms-jedi/test/Data/';
% Bdir  = '../../build_debug/roms-jedi/test/Data/';

IniDate = '2004-01-03-00.00.00.nc';
MidDate = '2004-01-05-00.00.00.nc';

I3dvarRP    = [Bdir, '3dvar/regular/primal/wc13_roms_3dvar_inc_', MidDate];
I3dvarRD    = [Bdir, '3dvar/regular/dual/wc13_roms_3dvar_inc_',   MidDate];

I3dvarFP    = [Bdir, '3dvar/fgat/primal/wc13_roms_3dvar_inc_' IniDate];
I3dvarFD    = [Bdir, '3dvar/fgat/dual/wc13_roms_3dvar_inc_',  IniDate];

I3denvarRP  = [Bdir, '3denvar/regular/primal/wc13_roms_3denvar_inc_', MidDate];
I3denvarRD  = [Bdir, '3denvar/regular/dual/wc13_roms_3denvar_inc_',   MidDate];

I3denvarFP  = [Bdir, '3denvar/fgat/primal/wc13_roms_3denvar_inc_', IniDate];
I3denvarFD  = [Bdir, '3denvar/fgat/dual/wc13_roms_3denvar_inc_',   IniDate];

I3dhybRP    = [Bdir, '3dhyb/regular/primal/wc13_roms_3dhyb_inc_', MidDate];
I3dhybRD    = [Bdir, '3dhyb/regular/dual/wc13_roms_3dhyb_inc_',   MidDate];

I3dhybFP    = [Bdir, '3dhyb/fgat/primal/wc13_roms_3dhyb_inc_', IniDate];
I3dhybFD    = [Bdir, '3dhyb/fgat/dual/wc13_roms_3dhyb_inc_',   IniDate];

IletKF      = [Bdir, 'letkf/solver/wc13_roms_letkf_inc_',       IniDate];
IletKFsplit = [Bdir, 'letkf/split_solver/wc13_roms_letkf_inc_', IniDate];
IletKF3dhyb = [Bdir, 'letkf/3dhyb/wc13_roms_3dhyb_inc_',        IniDate]; 

rh  = 160;                % horizontal correlation radius (km)
rv  = 150;                % vertical correlation radius (m)
rec = 2;                  % native 4D-Var final outer-loop increments
lev = 30;                 % surface level

wrtPNG  = true;
DoTitle = false;

 IncVar='temp'; PNGprefix='PNG/Tsur_'; Frange=[-1.5 1.5];   Vname='  Surface Temperature';
%IncVar='zeta'; PNGprefix='PNG/SSH_';  Frange=[-0.15 0.15]; Vname='  Free Surface';

%Label=[' (', num2str(rh), 'km, ', num2str(rv), 'm)'];
 Label=blanks(2); 

% Get Grid structure.

if (~exist('G', 'var'))
  G = get_roms_grid(Hname, Hname, 1);
end

%--------------------------------------------------------------------------
% Variational Data Assimilation.
%--------------------------------------------------------------------------

% Plot native 4D-Var increments (rh=50 km, rv=30 m).

F = plot_field(G, Iname1, IncVar, rec, lev, Frange, true, -20);
if (DoTitle)
  title(strcat('Dual 4D-Var: ',Vname,' (50km, 30m)'));
else
  title(blanks(2));
end
if (wrtPNG)
  print(strcat(PNGprefix,'dual_4dvar.png'),'-dpng','-r300');
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
  title(strcat('Dual 3D-Var: ',Vname,' (250km, 150m)'));
else
  title(blanks(2));
end
if (wrtPNG)
  print(strcat(PNGprefix,'dual_3dvar.png'),'-dpng','-r300');
end

% Plot ROMS-JEDI 3D-FGAT increments (primal and dual).

F = plot_field(G, I3dvarFP, IncVar, 1, lev, Frange, true, -20);
if (DoTitle)
  title(strcat('Primal 3D-FGAT: ',Vname, Label));
else
  title(blanks(2));
end
if (wrtPNG)
  print(strcat(PNGprefix,'primal_3dfgat.png'),'-dpng','-r300');
end

F = plot_field(G, I3dvarFD, IncVar, 1, lev, Frange, true, -20);
if (DoTitle)
  title(strcat('Dual 3D-FGAT: ', Vname, Label));
else
  title(blanks(2));
end
if (wrtPNG)
  print(strcat(PNGprefix,'dual_3dfgat.png'),'-dpng','-r300');
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

% Plot ROMS-JEDI 3DEnVar FGAT increments (primal and dual).

F = plot_field(G, I3denvarFP, IncVar, 1, lev, Frange, true, -20);
if (DoTitle)
  title(strcat('Primal 3DEnVar-FGAT: ', Vname, Label));
else
  title(blanks(2));
end
if (wrtPNG)
  print(strcat(PNGprefix,'primal_3denvar_fgat.png'),'-dpng','-r300');
end

F = plot_field(G, I3denvarFD, IncVar, 1, lev, Frange, true, -20);
if (DoTitle)
  title(strcat('Dual 3DEnVar-FGAT: ', Vname, Label));
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

% Plot ROMS-JEDI Hybrid 3DEnVar FGAT increments (primal and dual).

F = plot_field(G, I3dhybFP, IncVar, 1, lev, Frange, true, -20);
if (DoTitle)
  title(strcat('Primal Hybrid 3DEnVar-FGAT: ', Vname, Label));
else
  title(blanks(2));
end
if (wrtPNG)
  print(strcat(PNGprefix,'primal_3dhyb_fgat.png'),'-dpng','-r300');
end

F = plot_field(G, I3dhybFD, IncVar, 1, lev, Frange, true, -20);
if (DoTitle)
  title(strcat('Dual Hybrid 3DEnVar-FGAT: ', Vname, Label));
else
  title(blanks(2));
end
if (wrtPNG)
  print(strcat(PNGprefix,'dual_3dhyb_fgat.png'),'-dpng','-r300');
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
