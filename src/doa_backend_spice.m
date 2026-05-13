function result = doa_backend_spice(x, scanManifold, scanAnglesDeg, backendCfg)
%DOA_BACKEND_SPICE SPICE-family sparse covariance backend.

if nargin < 4 || isempty(backendCfg)
    backendCfg = struct();
end

numSources = local_optional_field(backendCfg, 'numSources', 2);
variant = char(lower(strtrim(local_optional_field(backendCfg, 'variant', 'spice_plus'))));
candidatePeakCount = local_optional_field(backendCfg, 'candidatePeakCount', max(numSources + 8, 12));
minimumSeparationDeg = local_optional_field(backendCfg, 'minimumSeparationDeg', 0);
alg = struct();
alg.maxIterations = local_optional_field(backendCfg, 'maxIterations', 100);
alg.tolerance = local_optional_field(backendCfg, 'tolerance', 1e-6);
alg.diagonalLoading = local_optional_field(backendCfg, 'diagonalLoading', 1e-8);

if numSources > numel(scanAnglesDeg)
    error('SPICE backend requires numSources <= number of scan angles.');
end

covariance = (x * x') / size(x, 2);
switch variant
    case 'spice'
        [spectrum, info] = doa_backend_utils('spice_spectrum', covariance, scanManifold, alg);
    case 'spice_plus'
        [spectrum, info] = doa_backend_utils('spice_plus_spectrum', covariance, scanManifold, alg);
    otherwise
        error('Unsupported SPICE backend variant: %s', variant);
end

peakIdx = doa_backend_utils('pick_local_peaks', spectrum, candidatePeakCount);
selectedIdx = local_select_separated_peaks(peakIdx, spectrum, scanAnglesDeg, ...
    numSources, minimumSeparationDeg);

result = struct();
result.name = variant;
result.estAnglesDeg = sort(scanAnglesDeg(selectedIdx));
result.spectrum = spectrum;
result.covariance = covariance;
result.diagnostics = info;
result.diagnostics.selectedGridIndex = selectedIdx;
result.diagnostics.selectedSpectrumValue = spectrum(selectedIdx);
result.diagnostics.minimumSeparationDeg = minimumSeparationDeg;
end

function selectedIdx = local_select_separated_peaks(peakIdx, spectrum, ...
    scanAnglesDeg, numSources, minimumSeparationDeg)
peakIdx = unique(peakIdx(:).', 'stable');
selectedIdx = local_greedy_separated(peakIdx, scanAnglesDeg, numSources, minimumSeparationDeg);
if numel(selectedIdx) == numSources
    return;
end

[~, globalOrder] = sort(spectrum(:), 'descend');
candidateIdx = unique([selectedIdx(:); globalOrder(:)], 'stable').';
selectedIdx = local_greedy_separated(candidateIdx, scanAnglesDeg, numSources, minimumSeparationDeg);
if numel(selectedIdx) == numSources
    return;
end

remainingIdx = globalOrder(~ismember(globalOrder, selectedIdx));
needed = min(numSources - numel(selectedIdx), numel(remainingIdx));
selectedIdx = [selectedIdx, reshape(remainingIdx(1:needed), 1, [])];
end

function selectedIdx = local_greedy_separated(candidateIdx, scanAnglesDeg, ...
    numSources, minimumSeparationDeg)
selectedIdx = zeros(1, 0);
for candidate = reshape(candidateIdx, 1, [])
    if ismember(candidate, selectedIdx)
        continue;
    end
    if isempty(selectedIdx) || ...
            all(abs(scanAnglesDeg(candidate) - scanAnglesDeg(selectedIdx)) >= minimumSeparationDeg)
        selectedIdx(end+1) = candidate; %#ok<AGROW>
    end
    if numel(selectedIdx) == numSources
        break;
    end
end
end

function value = local_optional_field(inputStruct, fieldName, defaultValue)
if isfield(inputStruct, fieldName) && ~isempty(inputStruct.(fieldName))
    value = inputStruct.(fieldName);
else
    value = defaultValue;
end
end
