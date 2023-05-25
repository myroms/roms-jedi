%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Matlab script to plot Dirac impulses. %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% It uses the following native ROMS Matlab repository functions:
%
%    matlab/colormaps/CMAP/cmap.m
%    matlab/grid/get_roms_grid.m
%    matlab/utility/plot_field.m
%
% ROMS Matlab repository: svn checkout https://www.myroms.org/svn/src/matlab
%

% Initialize. All the directory paths are relative to:
%
%             ${ROMS_HOME}/roms-jedi/tools/matlab

Bdir  = '../../build/roms-jedi/test/Data/';

Hname = strcat(Bdir, 'roms/wc13_his.nc');
Dname = strcat(Bdir, 'dirac/wc13_roms_dirac_inc_2004-01-03-00.00.00.nc');
Vname = strcat(Bdir, 'dirac/wc13_roms_dirac_var_2004-01-03-00.00.00.nc');

rh     = 160;      % horizontal correlation radius (km)
rv     = 150;      % vertical correlation radius (m)
rec    = 1;        % time record to process

wrtPNG = false;    % write PNG files
PNGdir = 'PNG/';   % output PNG files directory

zeta_file = strcat(PNGdir, 'dirac_ssh.png');
temp_file = strcat(PNGdir, 'dirac_temp.png');
Tsec_file = strcat(PNGdir, 'dirac_temp_sec.png');
salt_file = strcat(PNGdir, 'dirac_salt.png');
Ssec_file = strcat(PNGdir, 'dirac_salt_sec.png');

% Get ROMS grid structure.

if (~exist('G', 'var'))
  G = get_roms_grid(Hname, Hname);
end

% Plot free surface.

ixdir = 25; iydir = 20; izdir = 1;

ZH = plot_field(G, Dname, 'zeta', rec, izdir, [-Inf Inf], true, -10);
colormap(flipud(cmap('L9')));

if (wrtPNG)
  title(blanks(8));
  print(zeta_file, '-dpng', '-r300');
else
  title(['Free Surface:    rh=', num2str(rh)]);
end

% Plot temperature.

ixdir = 30; iydir = 10; izdir = 30;

TH = plot_field(G, Dname, 'temp', rec, izdir, [-Inf Inf], true, -10);
colormap((cmap('L18')));
if (wrtPNG)
  title(blanks(8));
  print(temp_file, '-dpng', '-r300');
else
  title(['Temperature:    rh=', num2str(rh), ' rv=', num2str(rv)]);
end

TV = plot_section(G, Dname, 'temp', rec, 'r', iydir, -10);
axis([-Inf Inf -1000 0]);
colormap((cmap('L18')));
grid on;
if (wrtPNG)
  title(blanks(8));
  print(Tsec_file, '-dpng', '-r300');
else
  title(['Temperature:    rh=', num2str(rh), ' rv=', num2str(rv)]);
end

% Plot salinity.

ixdir = 20; iydir = 40; izdir = 30;

SH = plot_field(G, Dname, 'salt', rec, izdir, [-Inf Inf], true, -10);
colormap((cmap('L17')));
title('Salinity:    rh=250, rv=100');
if (wrtPNG)
  title(blanks(8));
  print(salt_file, '-dpng', '-r300');
else
  title(['Salinity:    rh=', num2str(rh), ' rv=', num2str(rv)]);
end

SV = plot_section(G, Dname, 'salt', rec, 'r', iydir, -10);
axis([-Inf Inf -1000 0]);
colormap((cmap('L17')));
grid on;
title('Salinity:    rh=250, rv=100');
if (wrtPNG)
  title(blanks(8));
  print(Ssec_file, '-dpng', '-r300');
else
  title(['Salinity:    rh=', num2str(rh), ' rv=', num2str(rv)]);
end

