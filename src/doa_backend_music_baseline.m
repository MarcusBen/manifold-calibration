function result = doa_backend_music_baseline(x, scanManifold, scanAnglesDeg, backendCfg)
%DOA_BACKEND_MUSIC_BASELINE Current grid MUSIC estimator as a backend.

if nargin < 4 || isempty(backendCfg)
    backendCfg = struct();
end

numSources = local_optional_field(backendCfg, 'numSources', 2);
covariance = (x * x') / size(x, 2);
spectrum = doa_backend_utils('music_spectrum', covariance, scanManifold, numSources);
peakIdx = doa_backend_utils('pick_local_peaks', spectrum, max(numSources + 8, 12));

if numel(peakIdx) < numSources
    [~, fallbackIdx] = maxk(spectrum, min(numSources + 8, numel(spectrum)));
    peakIdx = unique([peakIdx(:); fallbackIdx(:)], 'stable');
end

selectedIdx = zeros(1, 0);
for candidate = reshape(peakIdx, 1, [])
    if ~ismember(candidate, selectedIdx)
        selectedIdx(end+1) = candidate; %#ok<AGROW>
    end
    if numel(selectedIdx) == numSources
        break;
    end
end

if numel(selectedIdx) < numSources
    [~, allOrder] = maxk(spectrum, min(numSources, numel(spectrum)));
    selectedIdx = allOrder(:).';
end

selectedIdx = selectedIdx(1:numSources);

result = struct();
result.name = 'music';
result.estAnglesDeg = sort(scanAnglesDeg(selectedIdx));
result.spectrum = spectrum;
result.covariance = covariance;
result.diagnostics = struct();
result.diagnostics.selectedGridIndex = selectedIdx;
result.diagnostics.selectedSpectrumValue = spectrum(selectedIdx);
end

function value = local_optional_field(inputStruct, fieldName, defaultValue)
if isfield(inputStruct, fieldName) && ~isempty(inputStruct.(fieldName))
    value = inputStruct.(fieldName);
else
    value = defaultValue;
end
end
