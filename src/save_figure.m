function save_figure(figHandle, filePath)
%SAVE_FIGURE Export a figure to disk and close it afterward.

outputDir = fileparts(filePath);
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

set(figHandle, 'Color', 'w');
exportgraphics(figHandle, filePath, 'Resolution', 180);
close(figHandle);
end
