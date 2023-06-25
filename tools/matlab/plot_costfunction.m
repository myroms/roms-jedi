%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Matlab Script to plot data assimilation convergence. %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Initialize. All the directory paths are relative to:
%
%             ${ROMS_HOME}/roms-jedi/tools/matlab
%
% It extracts convergence data from standard output files, which
% are specified in the YAML file pair 'log output filename'.
%

% Set ROMS-JEDI Data sub-directory with respect the "build":

% Cdir = '../../build/roms-jedi/test/testoutput/';
  Cdir = '../../build_wc13/roms-jedi/test/testoutput/';

% ROMS-JEDI Unit Tests log files with respect sub-directory "Cdir":

L3dvarRP   = strcat(Cdir, '3dvar_regular_primal.log');
L3dvarRD   = strcat(Cdir, '3dvar_regular_dual.log');

L3dfgatP   = strcat(Cdir, '3dfgat_primal.log');
L3dfgatD   = strcat(Cdir, '3dfgat_dual.log');

L4dfgatP   = strcat(Cdir, '4dfgat_primal.log');
L4dfgatD   = strcat(Cdir, '4dfgat_dual.log');

L3denvarRP = strcat(Cdir, '3denvar_regular_primal.log');
L3denvarRD = strcat(Cdir, '3denvar_regular_dual.log');

L3denvarFP = strcat(Cdir, '3denvar_4dfgat_primal.log');
L3denvarFD = strcat(Cdir, '3denvar_4dfgat_dual.log');

L3dhybRP   = strcat(Cdir, '3dhyb_regular_primal.log');
L3dhybRD   = strcat(Cdir, '3dhyb_regular_dual.log');

L3dhybFP   = strcat(Cdir, '3dhyb_4dfgat_primal.log');
L3dhybFD   = strcat(Cdir, '3dhyb_4dfgat_dual.log');

wrtPNG = false;
PNGdir = 'PNG/';

% If applicable, create PNG subdirectory.

if (wrtPNG && ~exist('PNG', 'dir'))
  unix('mkdir PNG');
end

%--------------------------------------------------------------------------
% Extract minimization information from log files.
%--------------------------------------------------------------------------

% 3D-Var

[~,v]=unix(['grep ninner ', L3dvarRP]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  SvRP = extract_values(L3dvarRP, 'Gradient reduction', '=', ninner);
  SvRP_J  = extract_values(L3dvarRP, 'Quadratic cost function: J ',   '=', ninner);
  SvRP_Jo = extract_values(L3dvarRP, 'Quadratic cost function: JoJc', '=', ninner);
  SvRP_Jb = extract_values(L3dvarRP, 'Quadratic cost function: Jb',   '=', ninner);
end

[~,v]=unix(['grep ninner ', L3dvarRD]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  SvRD = extract_values(L3dvarRD, 'Gradient reduction', '=', ninner);
  SvRD_J  = extract_values(L3dvarRD, 'CostFunction: Nonlinear', 'J =', 2);
  SvRD_Jo = extract_values(L3dvarRD, 'CostJo   : Nonlinear', 'Jo =', 2);
  SvRD_Jb = extract_values(L3dvarRD, ': CostJb   : Nonlinear', 'Jb =', 2);
end

% 3DEnVar

[~,v]=unix(['grep ninner ', L3denvarRP]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  SeRP = extract_values(L3denvarRP, 'Gradient reduction', '=', ninner);
  SeRP_J  = extract_values(L3denvarRP, 'Quadratic cost function: J ',   '=', ninner);
  SeRP_Jo = extract_values(L3denvarRP, 'Quadratic cost function: JoJc', '=', ninner);
  SeRP_Jb = extract_values(L3denvarRP, 'Quadratic cost function: Jb',   '=', ninner);
end

[~,v]=unix(['grep ninner ', L3denvarRD]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  SeRD = extract_values(L3denvarRD, 'Gradient reduction', '=', ninner);
  SeRD_J  = extract_values(L3denvarRD, 'CostFunction: Nonlinear', 'J =', 2);
  SeRD_Jo = extract_values(L3denvarRD, 'CostJo   : Nonlinear', 'Jo =', 2);
  SeRD_Jb = extract_values(L3denvarRD, ': CostJb   : Nonlinear', 'Jb =', 2);
end

% Hybrid 3DEnVar

[~,v]=unix(['grep ninner ', L3dhybRP]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  ShRP = extract_values(L3dhybRP, 'Gradient reduction', '=', ninner);
  ShRP_J  = extract_values(L3dhybRP, 'Quadratic cost function: J ',   '=', ninner);
  ShRP_Jo = extract_values(L3dhybRP, 'Quadratic cost function: JoJc', '=', ninner);
  ShRP_Jb = extract_values(L3dhybRP, 'Quadratic cost function: Jb',   '=', ninner);
end

[~,v]=unix(['grep ninner ', L3dhybRD]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  ShRD = extract_values(L3dhybRD, 'Gradient reduction', '=', ninner);
  ShRD_J  = extract_values(L3dhybRD, 'CostFunction: Nonlinear', 'J =', 2);
  ShRD_Jo = extract_values(L3dhybRD, 'CostJo   : Nonlinear', 'Jo =', 2);
  ShRD_Jb = extract_values(L3dhybRD, ': CostJb   : Nonlinear', 'Jb =', 2);
end

% 3D-Var 3D-FGAT.

[~,v]=unix(['grep ninner ', L3dfgatP]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  SvF3P = extract_values(L3dfgatP, 'Gradient reduction', '=', ninner);
  SvF3P_J  = extract_values(L3dfgatP, 'Quadratic cost function: J ',   '=', ninner);
  SvF3P_Jo = extract_values(L3dfgatP, 'Quadratic cost function: JoJc', '=', ninner);
  SvF3P_Jb = extract_values(L3dfgatP, 'Quadratic cost function: Jb',   '=', ninner);
end

[~,v]=unix(['grep ninner ', L3dfgatD]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  SvF3D = extract_values(L3dfgatD, 'Gradient reduction', '=', ninner);
  SvF3D_J  = extract_values(L3dfgatD, 'CostFunction: Nonlinear', 'J =', 2);
  SvF3D_Jo = extract_values(L3dfgatD, 'CostJo   : Nonlinear', 'Jo =', 2);
  SvF3D_Jb = extract_values(L3dfgatD, ': CostJb   : Nonlinear', 'Jb =', 2);
end

% 3D-Var 4D-FGAT.

[~,v]=unix(['grep ninner ', L4dfgatP]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  SvF4P = extract_values(L4dfgatP, 'Gradient reduction', '=', ninner);
  SvF4P_J  = extract_values(L4dfgatP, 'Quadratic cost function: J ',   '=', ninner);
  SvF4P_Jo = extract_values(L4dfgatP, 'Quadratic cost function: JoJc', '=', ninner);
  SvF4P_Jb = extract_values(L4dfgatP, 'Quadratic cost function: Jb',   '=', ninner);
end

[~,v]=unix(['grep ninner ', L4dfgatD]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  SvF4D = extract_values(L4dfgatD, 'Gradient reduction', '=', ninner);
  SvF4D_J  = extract_values(L4dfgatD, 'CostFunction: Nonlinear', 'J =', 2);
  SvF4D_Jo = extract_values(L4dfgatD, 'CostJo   : Nonlinear', 'Jo =', 2);
  SvF4D_Jb = extract_values(L4dfgatD, ': CostJb   : Nonlinear', 'Jb =', 2);
end

% 3DEnVar 4D-FGAT

[~,v]=unix(['grep ninner ', L3denvarFP]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  SeFP = extract_values(L3denvarFP, 'Gradient reduction', '=', ninner);
  SeFP_J  = extract_values(L3denvarFP, 'Quadratic cost function: J ',   '=', ninner);
  SeFP_Jo = extract_values(L3denvarFP, 'Quadratic cost function: JoJc', '=', ninner);
  SeFP_Jb = extract_values(L3denvarFP, 'Quadratic cost function: Jb',   '=', ninner);
end

[~,v]=unix(['grep ninner ', L3denvarFD]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  SeFD = extract_values(L3denvarFD, 'Gradient reduction', '=', ninner);
  SeFD_J  = extract_values(L3denvarFD, 'CostFunction: Nonlinear', 'J =', 2);
  SeFD_Jo = extract_values(L3denvarFD, 'CostJo   : Nonlinear', 'Jo =', 2);
  SeFD_Jb = extract_values(L3denvarFD, ': CostJb   : Nonlinear', 'Jb =', 2);
end

% Hybrid 3DEnVar 4D-FGAT

[~,v]=unix(['grep ninner ', L3dhybFP]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  ShFP = extract_values(L3dhybFP, 'Gradient reduction', '=', ninner);
  ShFP_J  = extract_values(L3dhybFP, 'Quadratic cost function: J ',   '=', ninner);
  ShFP_Jo = extract_values(L3dhybFP, 'Quadratic cost function: JoJc', '=', ninner);
  ShFP_Jb = extract_values(L3dhybFP, 'Quadratic cost function: Jb',   '=', ninner);
end

[~,v]=unix(['grep ninner ', L3dhybFD]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  ShFD = extract_values(L3dhybFD, 'Gradient reduction', '=', ninner);
  ShFD_J  = extract_values(L3dhybFD, 'CostFunction: Nonlinear', 'J =', 2);
  ShFD_Jo = extract_values(L3dhybFD, 'CostJo   : Nonlinear', 'Jo =', 2);
  ShFD_Jb = extract_values(L3dhybFD, ': CostJb   : Nonlinear', 'Jb =', 2);
end

x = 1:ninner;

%--------------------------------------------------------------------------
% Plot minimization information.
%--------------------------------------------------------------------------

% Plot Gradient Reduction regular 3D-Var cases.

figure;
subplot(2,1,1)
h1=plot(x, SvRP.values(:,1), 'ko-',  ...
        x, SeRP.values(:,1), 'rs-',  ...
        x, ShRP.values(:,1), 'b^-',  ...
        'MarkerSize', 8);
   set(h1, {'MarkerFaceColor'}, get(h1,'Color'));
h1Ax=gca;
axis([h1Ax.XLim(1) h1Ax.XLim(2),0 h1Ax.YLim(2)+50]);
set(h1Ax, 'YTick', 0:50:350);

xlabel('Inner Loop');
ylabel('Gradient Reduction');
title('Regular 3D-Var Primal Formulation');
legend('3dVar', '3dEnVar', 'Hybrid 3dEnVar');

subplot(2,1,2)
h2=plot(x, SvRD.values(:,1), 'ko-', ...
        x, SeRD.values(:,1), 'rs-', ...
        x, ShRD.values(:,1), 'b^-', ...
        'MarkerSize', 8);
   set(h2, {'MarkerFaceColor'}, get(h2,'Color'));
h2Ax=gca;
axis([h2Ax.XLim(1) h2Ax.XLim(2) 0 h2Ax.YLim(2)+50]);
set(h2Ax, 'YTick', 0:50:350);
	     
title('Regular 3D-Var Dual Formulation');
xlabel('Inner Loop');
ylabel('Gradient Reduction');
legend('3dVar', '3dEnVar', 'Hybrid 3dEnVar');

if (wrtPNG)
  print(strcat(PNGdir, 'GradRed_3dvar.png'), '-dpng', '-r300');
end

% Plot Gradient Reduction 3D-Var FGAT cases.

figure;
subplot(2,1,1)
h1=plot(x, SvF3P.values(:,1), 'ko-', ...
        x, SvF4P.values(:,1), 'g+--', ...
        x, SeFP.values(:,1),  'rs-', ...
        x, ShFP.values(:,1),  'b^-', ...
        'MarkerSize', 8);
   set(h1, {'MarkerFaceColor'}, get(h1,'Color'));
h1Ax=gca;
axis([h1Ax.XLim(1) h1Ax.XLim(2),0 h1Ax.YLim(2)+50]);
set(h1Ax, 'YTick', 0:50:350);

xlabel('Inner Loop');
ylabel('Gradient Reduction');
title('3D-Var FGAT Primal Formulation');
legend('3D-FGAT', '4D-FGAT', '3dEnVar', 'Hybrid 3dEnVar');

subplot(2,1,2)
h2=plot(x, SvF3D.values(:,1), 'ko-', ...
        x, SvF4D.values(:,1), 'g+--', ...
        x, SeFD.values(:,1),  'rs-', ...
        x, ShFD.values(:,1),  'b^-', ...
        'MarkerSize', 8);
   set(h2, {'MarkerFaceColor'}, get(h2,'Color'));
h2Ax=gca;
h2Ax=gca;
axis([h2Ax.XLim(1) h2Ax.XLim(2) 0 h2Ax.YLim(2)+50]);
set(h2Ax, 'YTick', 0:50:350);

title('3D-Var FGAT Dual Formulation');
xlabel('Inner Loop');
ylabel('Gradient Reduction');
legend('3D-FGAT', '4D-FGAT', '3dEnVar', 'Hybrid 3dEnVar');

if (wrtPNG)
  print(strcat(PNGdir, 'GradRed_fgat.png'), '-dpng', '-r300');
end

% Plot total Primal Formulation cost function.

figure;
subplot(2,1,1)
h3=plot(x, SvRP_J.values(:,1), 'ko-',  ...
        x, SeRP_J.values(:,1), 'rs-',  ...
        x, ShRP_J.values(:,1), 'b^-',  ...
        'MarkerSize', 8);
   set(h3, {'MarkerFaceColor'}, get(h3,'Color'));
xlabel('Inner Loop');
ylabel('J');
title('Regular 3D-Var Primal Formulation');
legend('3dVar', '3dEnVar', 'Hybrid 3dEnVar');

subplot(2,1,2)
h4=plot(x, SvF3P_J.values(:,1), 'ko-',  ...
        x, SvF4P_J.values(:,1), 'g+--', ...
        x, SeFP_J.values(:,1),  'rs-',  ...
        x, ShFP_J.values(:,1),  'b^-',  ...
        'MarkerSize', 8);
   set(h4, {'MarkerFaceColor'}, get(h4,'Color'));
title('3D-Var FGAT Primal Formulation');
xlabel('Inner Loop');
ylabel('J');
legend('3D-FGAT', '4D-FGAT', '3dEnVar', 'Hybrid 3dEnVar');

if (wrtPNG)
  print(strcat(PNGdir, 'J_3dvar_primal.png'), '-dpng', '-r300');
end

% Plot total Dual Formulation cost function.

YR = [SvRD_J.values(1,1), SvRD_J.values(1,2);   ...
      SeRD_J.values(1,1), SeRD_J.values(1,2);   ...
      ShRD_J.values(1,1), ShRD_J.values(1,2)];

YF = [SvF3D_J.values(1,1), SvF3D_J.values(1,2); ...
      SvF4D_J.values(1,1), SvF4D_J.values(1,2); ...
      SeFD_J.values(1,1),  SeFD_J.values(1,2);  ...
      ShFD_J.values(1,1),  ShFD_J.values(1,2)];

labelsR = {'Initial', 'Final';   ...
           'Initial', 'Final';   ...
           'Initial', 'Final'};

labelsF = {'Initial', 'Final';   ...
           'Initial', 'Final';   ...
           'Initial', 'Final';   ...
           'Initial', 'Final'};

figure;

subplot(2,1,1)
hb1=bar(YR, 'grouped');
hAx1=gca;
hAx1.YLim = [hAx1.YLim(1) hAx1.YLim(2)+500];

hT=[];
for i=1:length(hb1)
  hT=[hT, text(hb1(i).XData+hb1(i).XOffset, hb1(i).YData, labelsR(:,i), ...
      'VerticalAlignment','bottom','horizontalalign','center')];
end
title('Regular 3D-Var Dual Formulation');
ylabel('J')
set(hAx1, 'xticklabel', {'3dvar','3dEnVar','Hybrid 3dEnVar'});

subplot(2,1,2)
hb2=bar(YF, 'grouped');
hAx2=gca;
hAx2.YLim = [hAx2.YLim(1) hAx2.YLim(2)+500];

hT=[];
for i=1:length(hb2)
  hT=[hT, text(hb2(i).XData+hb2(i).XOffset, hb2(i).YData, labelsF(:,i), ...
      'VerticalAlignment','bottom','horizontalalign','center')];
end
title('FGAT Dual Formulation');
ylabel('J')
set(hAx2, 'xticklabel', {'3D-FGAT','4D-FGAT', '3dEnVar','Hybrid 3dEnVar'});

if (wrtPNG)
  print(strcat(PNGdir, 'J_3dvar_dual.png'), '-dpng', '-r300');
end
