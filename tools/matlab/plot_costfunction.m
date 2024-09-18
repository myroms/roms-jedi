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
  Cdir = '../../build_3dvar_new/roms-jedi/test/testoutput/';

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

L4dvarB    = strcat(Cdir, '4dvar_bump.log');
L4dvarD    = strcat(Cdir, '4dvar_diffusion.log');

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
  ninner  = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  SvRP    = extract_values(L3dvarRP, 'Norm reduction', '=', ninner);
  SvRP_rn = extract_values(L3dvarRP, 'Residual norm', '=', ninner);
  SvRP_J  = extract_values(L3dvarRP, 'Quadratic cost function: J ',   '=', ninner);
  SvRP_Jo = extract_values(L3dvarRP, 'Quadratic cost function: JoJc', '=', ninner);
  SvRP_Jb = extract_values(L3dvarRP, 'Quadratic cost function: Jb',   '=', ninner);
end

[~,v]=unix(['grep ninner ', L3dvarRD]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner  = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  SvRD    = extract_values(L3dvarRD, 'Norm reduction', '=', ninner);
  SvRD_rn = extract_values(L3dvarRD, 'Residual norm', '=', ninner);
  SvRD_J  = extract_values(L3dvarRD, 'CostFunction: Nonlinear', 'J =', 2);
  SvRD_Jo = extract_values(L3dvarRD, 'CostJo   : Nonlinear', 'Jo =', 2);
  SvRD_Jb = extract_values(L3dvarRD, ': CostJb   : Nonlinear', 'Jb =', 2);
end

% 3DEnVar

[~,v]=unix(['grep ninner ', L3denvarRP]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner  = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  SeRP    = extract_values(L3denvarRP, 'Norm reduction', '=', ninner);
  SeRP_rn = extract_values(L3denvarRP, 'Residual norm', '=', ninner);
  SeRP_J  = extract_values(L3denvarRP, 'Quadratic cost function: J ',   '=', ninner);
  SeRP_Jo = extract_values(L3denvarRP, 'Quadratic cost function: JoJc', '=', ninner);
  SeRP_Jb = extract_values(L3denvarRP, 'Quadratic cost function: Jb',   '=', ninner);
end

[~,v]=unix(['grep ninner ', L3denvarRD]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner  = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  SeRD    = extract_values(L3denvarRD, 'Norm reduction', '=', ninner);
  SeRD_rn = extract_values(L3denvarRD, 'Residual norm', '=', ninner);
  SeRD_J  = extract_values(L3denvarRD, 'CostFunction: Nonlinear', 'J =', 2);
  SeRD_Jo = extract_values(L3denvarRD, 'CostJo   : Nonlinear', 'Jo =', 2);
  SeRD_Jb = extract_values(L3denvarRD, ': CostJb   : Nonlinear', 'Jb =', 2);
end

% Hybrid 3DEnVar

[~,v]=unix(['grep ninner ', L3dhybRP]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner  = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  ShRP    = extract_values(L3dhybRP, 'Norm reduction', '=', ninner);
  ShRP_rn = extract_values(L3dhybRP, 'Residual norm', '=', ninner);
  ShRP_J  = extract_values(L3dhybRP, 'Quadratic cost function: J ',   '=', ninner);
  ShRP_Jo = extract_values(L3dhybRP, 'Quadratic cost function: JoJc', '=', ninner);
  ShRP_Jb = extract_values(L3dhybRP, 'Quadratic cost function: Jb',   '=', ninner);
end

[~,v]=unix(['grep ninner ', L3dhybRD]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner  = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  ShRD    = extract_values(L3dhybRD, 'Norm reduction', '=', ninner);
  ShRD_rn = extract_values(L3dhybRD, 'Residual norm', '=', ninner);
  ShRD_J  = extract_values(L3dhybRD, 'CostFunction: Nonlinear', 'J =', 2);
  ShRD_Jo = extract_values(L3dhybRD, 'CostJo   : Nonlinear', 'Jo =', 2);
  ShRD_Jb = extract_values(L3dhybRD, ': CostJb   : Nonlinear', 'Jb =', 2);
end

% 3D-Var 3D-FGAT.

[~,v]=unix(['grep ninner ', L3dfgatP]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner   = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  SvF3P    = extract_values(L3dfgatP, 'Norm reduction', '=', ninner);
  SvF3P_rn = extract_values(L3dfgatP, 'Residual norm', '=', ninner);
  SvF3P_J  = extract_values(L3dfgatP, 'Quadratic cost function: J ',   '=', ninner);
  SvF3P_Jo = extract_values(L3dfgatP, 'Quadratic cost function: JoJc', '=', ninner);
  SvF3P_Jb = extract_values(L3dfgatP, 'Quadratic cost function: Jb',   '=', ninner);
end

[~,v]=unix(['grep ninner ', L3dfgatD]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner   = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  SvF3D    = extract_values(L3dfgatD, 'Norm reduction', '=', ninner);
  SvF3D_rn = extract_values(L3dfgatD, 'Residual norm', '=', ninner);
  SvF3D_J  = extract_values(L3dfgatD, 'CostFunction: Nonlinear', 'J =', 2);
  SvF3D_Jo = extract_values(L3dfgatD, 'CostJo   : Nonlinear', 'Jo =', 2);
  SvF3D_Jb = extract_values(L3dfgatD, ': CostJb   : Nonlinear', 'Jb =', 2);
end

% 3D-Var 4D-FGAT.

[~,v]=unix(['grep ninner ', L4dfgatP]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner   = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  SvF4P    = extract_values(L4dfgatP, 'Norm reduction', '=', ninner);
  SvF4P_rn = extract_values(L4dfgatP, 'Residual norm', '=', ninner);
  SvF4P_J  = extract_values(L4dfgatP, 'Quadratic cost function: J ',   '=', ninner);
  SvF4P_Jo = extract_values(L4dfgatP, 'Quadratic cost function: JoJc', '=', ninner);
  SvF4P_Jb = extract_values(L4dfgatP, 'Quadratic cost function: Jb',   '=', ninner);
end

[~,v]=unix(['grep ninner ', L4dfgatD]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner   = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  SvF4D    = extract_values(L4dfgatD, 'Norm reduction', '=', ninner);
  SvF4D_rn = extract_values(L4dfgatD, 'Residual norm', '=', ninner);
  SvF4D_J  = extract_values(L4dfgatD, 'CostFunction: Nonlinear', 'J =', 2);
  SvF4D_Jo = extract_values(L4dfgatD, 'CostJo   : Nonlinear', 'Jo =', 2);
  SvF4D_Jb = extract_values(L4dfgatD, ': CostJb   : Nonlinear', 'Jb =', 2);
end

% 3DEnVar 4D-FGAT

[~,v]=unix(['grep ninner ', L3denvarFP]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner  = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  SeFP    = extract_values(L3denvarFP, 'Norm reduction', '=', ninner);
  SeFP_rn = extract_values(L3denvarFP, 'Residual norm', '=', ninner);
  SeFP_J  = extract_values(L3denvarFP, 'Quadratic cost function: J ',   '=', ninner);
  SeFP_Jo = extract_values(L3denvarFP, 'Quadratic cost function: JoJc', '=', ninner);
  SeFP_Jb = extract_values(L3denvarFP, 'Quadratic cost function: Jb',   '=', ninner);
end

[~,v]=unix(['grep ninner ', L3denvarFD]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner  = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  SeFD    = extract_values(L3denvarFD, 'Norm reduction', '=', ninner);
  SeFD_rn = extract_values(L3denvarFD, 'Residual norm', '=', ninner);
  SeFD_J  = extract_values(L3denvarFD, 'CostFunction: Nonlinear', 'J =', 2);
  SeFD_Jo = extract_values(L3denvarFD, 'CostJo   : Nonlinear', 'Jo =', 2);
  SeFD_Jb = extract_values(L3denvarFD, ': CostJb   : Nonlinear', 'Jb =', 2);
end

% Hybrid 3DEnVar 4D-FGAT

[~,v]=unix(['grep ninner ', L3dhybFP]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner  = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  ShFP    = extract_values(L3dhybFP, 'Norm reduction', '=', ninner);
  ShFP_rn = extract_values(L3dhybFP, 'Residual norm', '=', ninner);
  ShFP_J  = extract_values(L3dhybFP, 'Quadratic cost function: J ',   '=', ninner);
  ShFP_Jo = extract_values(L3dhybFP, 'Quadratic cost function: JoJc', '=', ninner);
  ShFP_Jb = extract_values(L3dhybFP, 'Quadratic cost function: Jb',   '=', ninner);
end

[~,v]=unix(['grep ninner ', L3dhybFD]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner  = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  ShFD    = extract_values(L3dhybFD, 'Norm reduction', '=', ninner);
  ShFD_rn = extract_values(L3dhybFD, 'Residual norm', '=', ninner);
  ShFD_J  = extract_values(L3dhybFD, 'CostFunction: Nonlinear', 'J =', 2);
  ShFD_Jo = extract_values(L3dhybFD, 'CostJo   : Nonlinear', 'Jo =', 2);
  ShFD_Jb = extract_values(L3dhybFD, ': CostJb   : Nonlinear', 'Jb =', 2);
end

x3 = 1:ninner;

% 4D-Var BUMP-NICAS

[~,v]=unix(['grep ninner ', L4dvarB]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner  = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  S4vB    = extract_values(L4dvarB, 'Norm reduction', '=', ninner);
  S4vB_rn = extract_values(L4dvarB, 'Residual norm', '=', ninner);
  S4vB_J  = extract_values(L4dvarB, 'CostFunction: Nonlinear', 'J =', 2);
  S4vB_Jo = extract_values(L4dvarB, 'CostJo   : Nonlinear', 'Jo =', 2);
  S4vB_Jb = extract_values(L4dvarB, ': CostJb   : Nonlinear', 'Jb =', 2);
end

% 4D-Var Diffusion operator.

[~,v]=unix(['grep ninner ', L4dvarD]);
ind = findstr(v, 'ninner => ');
if (~isempty(ind))
  ninner  = str2num(extractAfter(v(ind(1):ind(1)+14), '=>'));
  S4vD    = extract_values(L4dvarD, 'Norm reduction', '=', ninner);
  S4vD_rn = extract_values(L4dvarD, 'Residual norm', '=', ninner);
  S4vD_J  = extract_values(L4dvarD, 'CostFunction: Nonlinear', 'J =', 2);
  S4vD_Jo = extract_values(L4dvarD, 'CostJo   : Nonlinear', 'Jo =', 2);
  S4vD_Jb = extract_values(L4dvarD, ': CostJb   : Nonlinear', 'Jb =', 2);
end

x4 = 1:ninner;

%--------------------------------------------------------------------------
% Plot minimization information.
%--------------------------------------------------------------------------

doTitle = false;

%........................................
% Plot Norms regular primal 3D-Var cases.
%........................................

figure;
subplot(2,1,1)
h1=plot(x3, SvRP_rn.values(:,1), 'ko-',  ...
        x3, SeRP_rn.values(:,1), 'rs-',  ...
        x3, ShRP_rn.values(:,1), 'b^-',  ...
        'MarkerSize', 8);
   set(h1, {'MarkerFaceColor'}, get(h1,'Color'));
h1Ax=gca;
axis([0 max(x3) 0 1600]);
set(h1Ax, 'XTick', 0:1:max(x3), 'YTick', 0:400:1600);

xlabel('Inner Loop');
ylabel('Residual Norm');
if (doTitle)
  title('Regular 3D-Var Primal Formulation');
end
legend('3dVar', '3dEnVar', 'Hybrid 3dEnVar');
subplot(2,1,2)
h2=plot(x3, SvRP.values(:,1), 'ko-',  ...
        x3, SeRP.values(:,1), 'rs-',  ...
        x3, ShRP.values(:,1), 'b^-',  ...
        'MarkerSize', 8);
   set(h2, {'MarkerFaceColor'}, get(h2,'Color'));
h2Ax=gca;
axis([0 max(x3) 0 1]);
set(h2Ax, 'XTick', 0:1:max(x3), 'YTick', 0:0.2:1);

xlabel('Inner Loop');
ylabel('Norm Reduction');
if (doTitle)
  title('Regular 3D-Var Primal Formulation');
end
legend('3dVar', '3dEnVar', 'Hybrid 3dEnVar');

if (wrtPNG)
  png_file=strcat(PNGdir, 'Norms_3dvar_primal.png'); 
  exportgraphics(gcf, png_file, 'resolution', 300);
end

%......................................
% Plot Norms regular dual 3D-Var cases.
%......................................

figure;
subplot(2,1,1)
h1=plot(x3, SvRD_rn.values(:,1), 'ko-',  ...
        x3, SeRD_rn.values(:,1), 'rs-',  ...
        x3, ShRD_rn.values(:,1), 'b^-',  ...
        'MarkerSize', 8);
   set(h1, {'MarkerFaceColor'}, get(h1,'Color'));
h1Ax=gca;
axis([0 max(x3) 0 1600]);
set(h1Ax, 'XTick', 0:1:max(x3), 'YTick', 0:400:1600);

xlabel('Inner Loop');
ylabel('Residual Norm');
if (doTitle)
  title('Regular 3D-Var Dual Formulation');
end
legend('3dVar', '3dEnVar', 'Hybrid 3dEnVar');

subplot(2,1,2)
h2=plot(x3, SvRD.values(:,1), 'ko-',  ...
        x3, SeRD.values(:,1), 'rs-',  ...
        x3, ShRD.values(:,1), 'b^-',  ...
        'MarkerSize', 8);
   set(h2, {'MarkerFaceColor'}, get(h2,'Color'));
h2Ax=gca;
axis([0 max(x3) 0 1]);
set(h2Ax, 'XTick', 0:1:max(x3), 'YTick', 0:0.2:1);

xlabel('Inner Loop');
ylabel('Norm Reduction');
if (doTitle)
  title('Regular 3D-Var Dual Formulation');
end
legend('3dVar', '3dEnVar', 'Hybrid 3dEnVar');

if (wrtPNG)
  png_file=strcat(PNGdir, 'Norms_3dvar_dual.png');
  exportgraphics(gcf, png_file, 'resolution', 300);
end

%.....................................
% Plot Norms 3D-Var primal FGAT cases.
%.....................................

figure;
subplot(2,1,1)
h1=plot(x3, SvF3P_rn.values(:,1), 'ko-',  ...
        x3, SvF4P_rn.values(:,1), 'g+--', ...
        x3, SeFP_rn.values(:,1),  'rs-',  ...
        x3, ShFP_rn.values(:,1),  'b^-',  ...
        'MarkerSize', 8);
   set(h1, {'MarkerFaceColor'}, get(h1,'Color'));
h1Ax=gca;
axis([0 max(x3) 0 1600]);
set(h1Ax, 'XTick', 0:1:max(x3), 'YTick', 0:400:1600);

xlabel('Inner Loop');
ylabel('Residual Norm');
if (doTitle)
  title('3D-Var FGAT Primal Formulation');
end
legend('3D-FGAT', '4D-FGAT', '3dEnVar', 'Hybrid 3dEnVar');

subplot(2,1,2)
h2=plot(x3, SvF3P.values(:,1), 'ko-',  ...
        x3, SvF4P.values(:,1), 'g+--', ...
        x3, SeFP.values(:,1),  'rs-',  ...
        x3, ShFP.values(:,1),  'b^-',  ...
        'MarkerSize', 8);
   set(h2, {'MarkerFaceColor'}, get(h2,'Color'));
h2Ax=gca;
axis([0 max(x3) 0 1]);
set(h2Ax, 'XTick', 0:1:max(x3), 'YTick', 0:0.2:1);

xlabel('Inner Loop');
ylabel('Norm Reduction');
if (doTitle)
  title('3D-Var FGAT Primal Formulation');
end
legend('3D-FGAT', '4D-FGAT', '3dEnVar', 'Hybrid 3dEnVar');

if (wrtPNG)
  png_file=strcat(PNGdir, 'Norms_fgat_primal.png');
  exportgraphics(gcf, png_file, 'resolution', 300);
end

%...................................
% Plot Norms 3D-Var dual FGAT cases.
%...................................

figure;
subplot(2,1,1)
h1=plot(x3, SvF3D_rn.values(:,1), 'ko-',  ...
        x3, SvF4D_rn.values(:,1), 'g+--', ...
        x3, SeFD_rn.values(:,1),  'rs-',  ...
        x3, ShFD_rn.values(:,1),  'b^-',  ...
        'MarkerSize', 8);
   set(h1, {'MarkerFaceColor'}, get(h1,'Color'));
h1Ax=gca;
axis([0 max(x3) 0 1600]);
set(h1Ax, 'XTick', 0:1:max(x3), 'YTick', 0:400:1600);

xlabel('Inner Loop');
ylabel('Residual Norm');
if (doTitle)
  title('3D-Var FGAT Dual Formulation');
end
legend('3D-FGAT', '4D-FGAT', '3dEnVar', 'Hybrid 3dEnVar');

subplot(2,1,2)
h2=plot(x3, SvF3D.values(:,1), 'ko-',  ...
        x3, SvF4D.values(:,1), 'g+--', ...
        x3, SeFD.values(:,1),  'rs-',  ...
        x3, ShFD.values(:,1),  'b^-',  ...
        'MarkerSize', 8);
   set(h2, {'MarkerFaceColor'}, get(h2,'Color'));
h2Ax=gca;
axis([0 max(x3) 0 1]);
set(h2Ax, 'XTick', 0:1:max(x3), 'YTick', 0:0.2:1);

xlabel('Inner Loop');
ylabel('Norm Reduction');
if (doTitle)
  title('3D-Var FGAT Dual Formulation');
end
legend('3D-FGAT', '4D-FGAT', '3dEnVar', 'Hybrid 3dEnVar');

if (wrtPNG)
  png_file=strcat(PNGdir, 'Norms_fgat_dual.png');
  exportgraphics(gcf, png_file, 'resolution', 300);
end

%..............................................
% Plot 4D-Var Norm Reduction and Residual Norm.
%..............................................

figure;
subplot(2,1,1)
h1=plot(x4, S4vB_rn.values(:,1), 'ro-', ...
        x4, S4vD_rn.values(:,1), 'b^-', ...
        'MarkerSize', 8);
   set(h1, {'MarkerFaceColor'}, get(h1,'Color'));
h1Ax=gca;
axis([0 max(x4) 0 2000]);
set(h1Ax, 'XTick', 0:2:max(x4), 'YTick', 0:500:2000);
	     
if (doTitle)
  title('4D-Var Dual Formulation');
end
xlabel('Inner Loop');
ylabel('Residual Norm');
legend('BUMP/NICAS', 'Diffusion');

subplot(2,1,2)
h2=plot(x4, S4vB.values(:,1), 'ro-',  ...
        x4, S4vD.values(:,1), 'b^-',  ...
        'MarkerSize', 8);
   set(h2, {'MarkerFaceColor'}, get(h2,'Color'));
h2Ax=gca;
axis([0 max(x4) 0 1]);
set(h2Ax, 'XTick', 0:2:max(x4), 'YTick', 0:0.2:1);

xlabel('Inner Loop');
ylabel('Norm Reduction');
if (doTitle)
  title('4D-Var Dual Formulation');
end
legend('BUMP/NICAS', 'Diffusion');

if (wrtPNG)
  png_file=strcat(PNGdir, 'Norms_4dvar.png');
  exportgraphics(gcf, png_file, 'resolution', 300);
end

%.............................................
% Plot total Primal Formulation cost function.
%.............................................

figure;
subplot(2,1,1)
h3=plot(x, SvRP_J.values(:,1), 'ko-',  ...
        x, SeRP_J.values(:,1), 'rs-',  ...
        x, ShRP_J.values(:,1), 'b^-',  ...
        'MarkerSize', 8);
   set(h3, {'MarkerFaceColor'}, get(h3,'Color'));
xlabel('Inner Loop');
ylabel('J');
if (doTitle)
  title('Regular 3D-Var Primal Formulation');
else
  title('Regular 3D-Var');
end
legend('3dVar', '3dEnVar', 'Hybrid 3dEnVar');

subplot(2,1,2)
h4=plot(x, SvF3P_J.values(:,1), 'ko-',  ...
        x, SvF4P_J.values(:,1), 'g+--', ...
        x, SeFP_J.values(:,1),  'rs-',  ...
        x, ShFP_J.values(:,1),  'b^-',  ...
        'MarkerSize', 8);
   set(h4, {'MarkerFaceColor'}, get(h4,'Color'));
if (doTitle)
  title('3D-Var FGAT Primal Formulation');
else
  title('3D/4D FGAT');
end
xlabel('Inner Loop');
ylabel('J');
legend('3D-FGAT', '4D-FGAT', '3dEnVar', 'Hybrid 3dEnVar');

if (wrtPNG)
  png_file=strcat(PNGdir, 'J_3dvar_primal.png');
  exportgraphics(gcf, png_file, 'resolution', 300);
end

%..................................................
% Plot total 3D-Var Dual Formulation cost function.
%..................................................

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
%hAx1.YLim = [hAx1.YLim(1) hAx1.YLim(2)+500];
hAx1.YLim = [hAx1.YLim(1) 14000];

hT=[];
for i=1:length(hb1)
  hT=[hT, text(hb1(i).XData+hb1(i).XOffset, hb1(i).YData, labelsR(:,i), ...
      'VerticalAlignment','bottom','horizontalalign','center')];
end
if (doTitle)
  title('Regular 3D-Var Dual Formulation');
else
  title('Regular 3D-Var');
end
ylabel('J')
set(hAx1, 'xticklabel', {'3dvar','3dEnVar','Hybrid 3dEnVar'});
set(hAx1, 'YTick', 0:2000:14000);

subplot(2,1,2)
hb2=bar(YF, 'grouped');
hAx2=gca;
%hAx2.YLim = [hAx2.YLim(1) hAx2.YLim(2)+500];
hAx2.YLim = [hAx2.YLim(1) 14000];

hT=[];
for i=1:length(hb2)
  hT=[hT, text(hb2(i).XData+hb2(i).XOffset, hb2(i).YData, labelsF(:,i), ...
      'VerticalAlignment','bottom','horizontalalign','center')];
end
if (doTitle)
  title('FGAT Dual Formulation');
else
  title('3D/4D FGAT');
end

ylabel('J')
set(hAx2, 'xticklabel', {'3D-FGAT','4D-FGAT', '3dEnVar','Hybrid 3dEnVar'});
set(hAx2, 'YTick', 0:2000:14000);

if (wrtPNG)
  png_file=strcat(PNGdir, 'J_3dvar_dual.png');
  exportgraphics(gcf, png_file, 'resolution', 300);
end

%..................................................
% Plot total 3D-Var Dual Formulation cost function.
%..................................................

Y4 = [S4vB_J.values(1,1), S4vB_J.values(1,3);   ...
      S4vD_J.values(1,1), S4vD_J.values(1,3)];

labelsY4 = {'Initial', 'Final';   ...
            'Initial', 'Final'};

figure;

hb1=bar(Y4, 'grouped');
hAx1=gca;
%hAx1.YLim = [hAx1.YLim(1) hAx1.YLim(2)+500];
hAx1.YLim = [hAx1.YLim(1) 14000];

hT=[];
for i=1:length(hb1)
  hT=[hT, text(hb1(i).XData+hb1(i).XOffset, hb1(i).YData, labelsY4(:,i), ...
      'VerticalAlignment','bottom','horizontalalign','center')];
end
if (doTitle)
  title('4D-Var Dual Formulation');
end
ylabel('J')
set(hAx1, 'xticklabel', {'BUMP/NICAS','Diffusion'});
set(hAx1, 'YTick', 0:2000:14000);

if (wrtPNG)
  png_file=strcat(PNGdir, 'J_4dvar_dual.png');
  exportgraphics(gcf, png_file, 'resolution', 300);
end
