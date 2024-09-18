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

Iname = '/home/arango/ROMS/Projects/WC13/RBL4DVAR/80km/wc13_itl_20040103.nc';

if (exist(Iname, 'file'))
  got_RBL4DVAR = true;
else
  got_RBL4DVAR = false;
end

% Set ROMS-JEDI Data sub-directory with respect the "build":

% Bdir  = '../../build/roms-jedi/test/Data/';
  Bdir  = '../../build_3dvar_new/roms-jedi/test/Data/';

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

I4dvarB     = [Bdir, '4dvar/bump/wc13_roms_4dvar_inc_', IniDate];
I4dvarD     = [Bdir, '4dvar/diffusion/wc13_roms_4dvar_inc_',   IniDate];

IletKF      = [Bdir, 'letkf/solver/wc13_roms_letkf_inc_',       IniDate];
IletKFsplit = [Bdir, 'letkf/split_solver/wc13_roms_letkf_inc_', IniDate];
IletKF3dhyb = [Bdir, 'letkf/3dhyb/wc13_roms_3dhyb_inc_',        IniDate]; 

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

doSlice   = true;     % plot horizontal slice
doSection = false;    % plot vertical section

% Set ploting arguments.

rec  = 1;
lev  = 30;
type = -20;
map  = 1;
indx = 20;
wrt  = -500;

% Set ploting range arguments.

R.zeta = [-Inf Inf];
R.u    = [-0.2 0.2];
R.v    = [-0.2 0.2];
R.temp = [-1.5 1.5];
%R.salt = [-1.0 1.0];
R.salt = [-0.4 1.0];

% Plot ROMS-JEDI Regular 3D-Var increments (primal and dual).

if (doSlice)
  F=plot_state(G,I3dvarRP,rec,lev,type,map,'h',indx,wrt,'3dvarRP',R);
end
if (doSection)
  F=plot_state(G,I3dvarRP,rec,lev,type,map,'r',indx,wrt,'3dvarRP');
end

if (doSlice)
  F=plot_state(G,I3dvarRP,rec,lev,type,map,'h',indx,wrt,'3dvarRD',R);
end
if (doSection)
  F=plot_state(G,I3dvarRP,rec,lev,type,map,'r',indx,wrt,'3dvarRD');
end

% Plot ROMS-JEDI 3D-FGAT increments (primal and dual).

if (doSlice)
  F=plot_state(G,I3dfgatP,rec,lev,type,map,'h',indx,wrt,'3dfgatP',R);
end
if (doSection)
  F=plot_state(G,I3dfgatP,rec,lev,type,map,'r',indx,wrt,'3dfgatP');
end

if (doSlice)
  F=plot_state(G,I3dfgatP,rec,lev,type,map,'h',indx,wrt,'3dfgatD',R);
end
if (doSection)
  F=plot_state(G,I3dfgatP,rec,lev,type,map,'r',indx,wrt,'3dfgatD');
end

% Plot ROMS-JEDI 4D-FGAT increments (primal and dual).

if (doSlice)
  F=plot_state(G,I4dfgatP,rec,lev,type,map,'h',indx,wrt,'4dfgatP',R);
end
if (doSection)
  F=plot_state(G,I4dfgatP,rec,lev,type,map,'r',indx,wrt,'4dfgatP');
end

if (doSlice)
  F=plot_state(G,I4dfgatD,rec,lev,type,map,'h',indx,wrt,'4dfgatD',R);
end
 if (doSection)
  F=plot_state(G,I4dfgatD,rec,lev,type,map,'r',indx,wrt,'4dfgatD');
end

% Plot ROMS-JEDI Regular 3DEnVar increments (primal and dual).

if (doSlice)
  F=plot_state(G,I3denvarRP,rec,lev,type,map,'h',indx,wrt,'3denvarRP',R);
end
if (doSection)
  F=plot_state(G,I3denvarRP,rec,lev,type,map,'r',indx,wrt,'3denvarRP');
end

if (doSlice)
  F=plot_state(G,I3denvarRD,rec,lev,type,map,'h',indx,wrt,'3denvarRD',R);
end
if (doSection)
  F=plot_state(G,I3denvarRD,rec,lev,type,map,'r',indx,wrt,'3denvarRD');
end

% Plot ROMS-JEDI 3DEnVar 4D-FGAT increments (primal and dual).

if (doSlice)
  F=plot_state(G,I3denvarFP,rec,lev,type,map,'h',indx,wrt,'3denvarFP',R);
end
if (doSection)
  F=plot_state(G,I3denvarFP,rec,lev,type,map,'r',indx,wrt,'3denvarFP');
end

if (doSlice)
  F=plot_state(G,I3denvarFD,rec,lev,type,map,'h',indx,wrt,'3denvarFD',R);
end
if (doSection)
  F=plot_state(G,I3denvarFD,rec,lev,type,map,'r',indx,wrt,'3denvarFD');
end

% Plot ROMS-JEDI Regular Hybrid 3DEnVar increments (primal and dual).

if (doSlice)
  F=plot_state(G,I3dhybRP,rec,lev,type,map,'h',indx,wrt,'3dhybRP',R);
end
if (doSection)
  F=plot_state(G,I3dhybRP,rec,lev,type,map,'r',indx,wrt,'3dhybRP');
end

if (doSlice)
  F=plot_state(G,I3dhybRD,rec,lev,type,map,'h',indx,wrt,'3dhybRD',R);
end
if (doSection)
  F=plot_state(G,I3dhybRD,rec,lev,type,map,'r',indx,wrt,'3dhybRD');
end

% Plot ROMS-JEDI Hybrid 3DEnVar 4D-FGAT increments (primal and dual).

if (doSlice)
  F=plot_state(G,I3dhybFP,rec,lev,type,map,'h',indx,wrt,'3dhybFP',R);
end
if (doSection)
  F=plot_state(G,I3dhybFP,rec,lev,type,map,'r',indx,wrt,'3dhybFP');
end

if (doSlice)
  F=plot_state(G,I3dhybFD,rec,lev,type,map,'h',indx,wrt,'3dhybFD',R);
end
if (doSection)
  F=plot_state(G,I3dhybFD,rec,lev,type,map,'r',indx,wrt,'3dhybFD');
end

% Plot ROMS-JEDI 4DVar increments (BUMP/NICAS and Diffusion).

if (doSlice)
  F=plot_state(G,I4dvarB,rec,lev,type,map,'h',indx,wrt,'4dvarB',R);
end
if (doSection)
  F=plot_state(G,I4dvarB,rec,lev,type,map,'r',indx,wrt,'4dvarB');
end

if (doSlice)
  F=plot_state(G,I4dvarD,rec,lev,type,map,'h',indx,wrt,'4dvarD',R);
end
if (doSection)
  F=plot_state(G,I4dvarD,rec,lev,type,map,'r',indx,wrt,'4dvarD');
end

% Plot ROMS native 4DVar increments.

if (doSlice)
  F=plot_state(G,Iname,2,lev,type,map,'h',indx,wrt,'native',R);
end
if (doSection)
  F=plot_state(G,Iname,2,lev,type,map,'r',indx,wrt,'native');
end

%--------------------------------------------------------------------------
% Kalman Filter Data Assimilation.
%--------------------------------------------------------------------------

% Plot LETKF

if (doSlice)
  F=plot_state(G,IletKF,rec,lev,type,map,'h',indx,wrt,'letKF',R);
end
if (doSection)
  F=plot_state(G,IletKF,rec,lev,type,map,'r',indx,wrt,'letKF');
end

% Plot LETKF/Hybrid 3DEnVar.

if (doSlice)
  F=plot_state(G,IletKF3dhyb,rec,lev,type,map,'h',indx,wrt,'letKF3dhyb',R);
end
if (doSection)
  F=plot_state(G,IletKF3dhyb,rec,lev,type,map,'r',indx,wrt,'letKF3dhyb');
end