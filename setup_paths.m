function setup_paths(rootDir)
%SETUP_PATHS Add the project directories needed by the MATLAB workflow.

if nargin < 1 || isempty(rootDir)
    rootDir = fileparts(mfilename('fullpath'));
end

addpath(rootDir);

srcDir = fullfile(rootDir, 'src');
if exist(srcDir, 'dir')
    addpath(srcDir);
end
end
