function [S] = extract_values(fname, pattern, token, nvalues)

%
% EXTRACT_VALUES: Extracts numerical values from JEDI standard output file
%
% [S] = extract_values(fname, pattern, token, nvalues)
%
% It extracts numerical values from JEDI standard output files for analisys
% and plotting.
%
% On Input:
%
%    fname         Standard output filename (string)
%
%    pattern       String pattern to search line-by-line (string)
%  
%    token         String token before the numerical value (string)
%                    For example, '='
%
%    nvalues       Number of values per set (scalar)
%
%
% On Output:
%
%    S             Numerical values structure (struct)
%
%                    S.fname   = fname
%                    S.pattern = pattern
%                    S.token   = token
%                    S.ni      = nvalues
%                    S.nj
%                    S.values(ni,nj)
%                    
% Example:
%
%   S = extract_values('3dvar_fgat_primal.log',                         ...
%                      'Gradient reduction', '=', ninner)
%  
  
% svn $Id$
%=========================================================================%
%  Copyright (c) 2002-2023 The ROMS/TOMS Group                            %
%    Licensed under a MIT/X style license                                 %
%    See License_ROMS.txt                           Hernan G. Arango      %
%=========================================================================%

% Initialize.

S = struct('fname'            , [],                                     ...
           'pattern'          , [],                                     ...
           'token'            , [],                                     ...
           'ni'               , [],                                     ...
           'nj'               , [],                                     ...
           'values'           , []);

S.fname   = fname;
S.pattern = pattern;
S.token   = token;

% Open standard input file.

fid = fopen(fname,'r');
if (fid < 0)
  error(['Cannot open ' fname '.'])
end

% Read in and extract numerical values.

n = 0;

values = nan([1 10000]);
sline  = fgetl(fid);

while ischar(sline)
  if (~isempty(sline))
    if (contains(sline, pattern) && contains(sline, token))
      n = n+1;
      values(n) = str2double(extractAfter(sline, token));
    end
  end
  sline = fgetl(fid);
end
values = values(1:n);

% Load values. Usually, the values extracted are repeated more than once
% bcause JEDI iterative algorithm.  For example, cost function, gradient
% reduction, etc.

S.ni = nvalues;
S.nj = fix(n / nvalues);
S.values = reshape(values(1:S.ni*S.nj), S.ni, S.nj);

fclose(fid);

return
