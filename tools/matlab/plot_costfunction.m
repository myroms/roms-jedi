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

Cdir = '../../build/roms-jedi/test/testoutput/';
 
L3dvarRP   = strcat(Cdir, '3dvar_regular_primal.log');
L3dvarRD   = strcat(Cdir, '3dvar_regular_dual.log');

L3dvarFP   = strcat(Cdir, '3dvar_fgat_primal.log');
L3dvarFD   = strcat(Cdir, '3dvar_fgat_dual.log');

L3denvarRP = strcat(Cdir, '3denvar_regular_primal.log');
L3denvarRD = strcat(Cdir, '3denvar_regular_dual.log');

L3denvarFP = strcat(Cdir, '3denvar_fgat_primal.log');
L3denvarFD = strcat(Cdir, '3denvar_fgat_dual.log');

L3dhybRP   = strcat(Cdir, '3dhyb_regular_primal.log');
L3dhybRD   = strcat(Cdir, '3dhyb_regular_dual.log');

L3dhybFP   = strcat(Cdir, '3dhyb_fgat_primal.log');
L3dhybFD   = strcat(Cdir, '3dhyb_fgat_dual.log');

wrtPNG = true;
PNGdir = 'PNG/';

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

% 3D-Var FGAT.

[~,v]=unix(['grep ninner ', L3dvarFP]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  SvFP = extract_values(L3dvarFP, 'Gradient reduction', '=', ninner);
  SvFP_J  = extract_values(L3dvarFP, 'Quadratic cost function: J ',   '=', ninner);
  SvFP_Jo = extract_values(L3dvarFP, 'Quadratic cost function: JoJc', '=', ninner);
  SvFP_Jb = extract_values(L3dvarFP, 'Quadratic cost function: Jb',   '=', ninner);
end

[~,v]=unix(['grep ninner ', L3dvarFD]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  SvFD = extract_values(L3dvarFD, 'Gradient reduction', '=', ninner);
  SvFD_J  = extract_values(L3dvarFD, 'CostFunction: Nonlinear', 'J =', 2);
  SvFD_Jo = extract_values(L3dvarFD, 'CostJo   : Nonlinear', 'Jo =', 2);
  SvFD_Jb = extract_values(L3dvarFD, ': CostJb   : Nonlinear', 'Jb =', 2);
end

% 3DEnVar FGAT

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

% Hybrid 3DEnVar FGAT

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
h1=plot(x, SvFP.values(:,1), 'ko-',  ...
        x, SeFP.values(:,1), 'rs-',  ...
        x, ShFP.values(:,1), 'b^-',  ...
        'MarkerSize', 8);
   set(h1, {'MarkerFaceColor'}, get(h1,'Color'));
h1Ax=gca;
axis([h1Ax.XLim(1) h1Ax.XLim(2),0 h1Ax.YLim(2)+50]);
set(h1Ax, 'YTick', 0:50:350);

xlabel('Inner Loop');
ylabel('Gradient Reduction');
title('3D-Var FGAT Primal Formulation');
legend('3dVar', '3dEnVar', 'Hybrid 3dEnVar');

subplot(2,1,2)
h2=plot(x, SvFD.values(:,1), 'ko-', ...
        x, SeFD.values(:,1), 'rs-', ...
        x, ShFD.values(:,1), 'b^-', ...
        'MarkerSize', 8);
   set(h2, {'MarkerFaceColor'}, get(h2,'Color'));
h2Ax=gca;
h2Ax=gca;
axis([h2Ax.XLim(1) h2Ax.XLim(2) 0 h2Ax.YLim(2)+50]);
set(h2Ax, 'YTick', 0:50:350);

title('3D-Var FGAT Dual Formulation');
xlabel('Inner Loop');
ylabel('Gradient Reduction');
legend('3dVar', '3dEnVar', 'Hybrid 3dEnVar');

if (wrtPNG)
  print(strcat(PNGdir, 'GradRed_3dvar_fgat.png'), '-dpng', '-r300');
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
h4=plot(x, SvFP_J.values(:,1), 'ko-', ...
        x, SeFP_J.values(:,1), 'rs-', ...
        x, ShFP_J.values(:,1), 'b^-', ...
        'MarkerSize', 8);
   set(h4, {'MarkerFaceColor'}, get(h4,'Color'));
title('3D-Var FGAT Primal Formulation');
xlabel('Inner Loop');
ylabel('J');
legend('3dVar', '3dEnVar', 'Hybrid 3dEnVar');

if (wrtPNG)
  print(strcat(PNGdir, 'J_3dvar_primal.png'), '-dpng', '-r300');
end

% Plot total Dual Formulation cost function.

YR = [SvRD_J.values(1,1), SvRD_J.values(1,2);   ...
      SeRD_J.values(1,1), SeRD_J.values(1,2);   ...
      ShRD_J.values(1,1), ShRD_J.values(1,2)];

YF = [SvFD_J.values(1,1), SvFD_J.values(1,2);   ...
      SeFD_J.values(1,1), SeFD_J.values(1,2);   ...
      ShFD_J.values(1,1), ShFD_J.values(1,2)];

labels = {'Initial', 'Final';   ...
          'Initial', 'Final';   ...
          'Initial', 'Final'};

figure;

subplot(2,1,1)
hb1=bar(YR, 'grouped');
hAx1=gca;
hAx1.YLim = [hAx1.YLim(1) hAx1.YLim(2)+500];

hT=[];
for i=1:length(hb1)
  hT=[hT, text(hb1(i).XData+hb1(i).XOffset, hb1(i).YData, labels(:,i),  ...
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
  hT=[hT, text(hb2(i).XData+hb2(i).XOffset, hb2(i).YData, labels(:,i),  ...
      'VerticalAlignment','bottom','horizontalalign','center')];
end
title('3D-Var FGAT Dual Formulation');
ylabel('J')
set(hAx2, 'xticklabel', {'3dvar','3dEnVar','Hybrid 3dEnVar'});

if (wrtPNG)
  print(strcat(PNGdir, 'J_3dvar_dual.png'), '-dpng', '-r300');
end






