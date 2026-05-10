function ctx = build_project_context(cfg)
%BUILD_PROJECT_CONTEXT Load the HFSS data and prepare normalized manifolds.

raw = readmatrix(cfg.data.csvPath, 'NumHeaderLines', 1);
raw = raw(~all(isnan(raw), 2), :);

thetaDeg = raw(:, 4).';
freqGHz = raw(:, 3).';
valueCols = [5 7; 9 11; 13 15; 17 19; 21 23; 25 27; 29 31; 33 35];
numElements = size(valueCols, 1);
numAngles = size(raw, 1);

local_validate_hfss_table(raw, thetaDeg, freqGHz, valueCols, cfg);

if numElements ~= cfg.array.numElements
    error('HFSS data contains %d ports, but cfg.array.numElements=%d.', ...
        numElements, cfg.array.numElements);
end

ahRaw = zeros(numElements, numAngles);
for elementIdx = 1:numElements
    reCol = valueCols(elementIdx, 1);
    imCol = valueCols(elementIdx, 2);
    ahRaw(elementIdx, :) = raw(:, reCol).' + 1i * raw(:, imCol).';
end

[thetaDeg, sortIdx] = sort(thetaDeg, 'ascend');
ahRaw = ahRaw(:, sortIdx);
freqGHz = freqGHz(sortIdx);

ai = local_ideal_manifold(thetaDeg, cfg.array.numElements, cfg.array.elementSpacingLambda);
ahNorm = local_normalize_columns(ahRaw);
aiNorm = local_normalize_columns(ai);

ctx = struct();
ctx.rootDir = cfg.rootDir;
ctx.dataPath = cfg.data.csvPath;
ctx.dataFrequencyGHz = median(freqGHz);
ctx.arrayFrequencyHz = cfg.array.frequencyHz;
ctx.elementSpacingLambda = cfg.array.elementSpacingLambda;
ctx.thetaDeg = thetaDeg;
ctx.numAngles = numel(thetaDeg);
ctx.numElements = cfg.array.numElements;
ctx.gridStepDeg = median(diff(thetaDeg));
ctx.angleRangeDeg = [thetaDeg(1), thetaDeg(end)];
ctx.AHRaw = ahRaw;
ctx.AH = ahNorm;
ctx.AI = aiNorm;
ctx.diagnostics = local_context_diagnostics(ctx.AH, thetaDeg, cfg);
end

function aIdeal = local_ideal_manifold(thetaDeg, numElements, spacingLambda)
elementIndex = (0:numElements-1).';
phaseSlope = 2 * pi * spacingLambda;
aIdeal = exp(1i * phaseSlope * elementIndex * sind(thetaDeg));
end

function local_validate_hfss_table(raw, thetaDeg, freqGHz, valueCols, cfg)
if isempty(raw)
    error('HFSS table is empty: %s', cfg.data.csvPath);
end

if size(raw, 2) < max(valueCols(:))
    error('HFSS table has %d columns, but at least %d columns are required.', ...
        size(raw, 2), max(valueCols(:)));
end

if any(~isfinite(raw), 'all')
    error('HFSS table contains NaN or Inf values: %s', cfg.data.csvPath);
end

expectedFreqGHz = cfg.array.frequencyHz / 1e9;
if max(abs(freqGHz - expectedFreqGHz)) > 1e-6
    error('HFSS frequency column is not %.6g GHz. Observed range is [%.6g, %.6g] GHz.', ...
        expectedFreqGHz, min(freqGHz), max(freqGHz));
end

if numel(unique(round(thetaDeg, 10))) ~= numel(thetaDeg)
    error('HFSS angle grid contains duplicate angles.');
end

[thetaSorted, sortIdx] = sort(thetaDeg, 'ascend');
if any(abs(thetaDeg(sortIdx) - thetaSorted) > 1e-10)
    error('Unexpected angle sorting failure.');
end

if numel(thetaSorted) > 1
    stepDeg = median(diff(thetaSorted));
    if max(abs(diff(thetaSorted) - stepDeg)) > 1e-9
        error('HFSS angle grid is not uniformly spaced.');
    end
else
    stepDeg = NaN;
end

[~, fileName, fileExt] = fileparts(cfg.data.csvPath);
if strcmp([fileName fileExt], 'step0.2deg.csv')
    if numel(thetaSorted) ~= 601 || abs(thetaSorted(1) + 60) > 1e-9 || ...
            abs(thetaSorted(end) - 60) > 1e-9 || abs(stepDeg - 0.2) > 1e-9
        error('step0.2deg.csv must contain the grid -60:0.2:60.');
    end
end
end

function diagnostics = local_context_diagnostics(ahNorm, thetaDeg, cfg)
spacingGrid = linspace(0, 0.5, 1001);
meanCorrelation = zeros(size(spacingGrid));

for idx = 1:numel(spacingGrid)
    ai = local_ideal_manifold(thetaDeg, cfg.array.numElements, spacingGrid(idx));
    ai = local_normalize_columns(ai);
    meanCorrelation(idx) = mean(abs(sum(conj(ahNorm) .* ai, 1)));
end

[bestMeanCorrelation, bestIdx] = max(meanCorrelation);
configuredIdeal = local_ideal_manifold(thetaDeg, cfg.array.numElements, cfg.array.elementSpacingLambda);
configuredIdeal = local_normalize_columns(configuredIdeal);
configuredCorrelation = abs(sum(conj(ahNorm) .* configuredIdeal, 1));

diagnostics = struct();
diagnostics.bestFitSpacingLambda = spacingGrid(bestIdx);
diagnostics.bestFitMeanCorrelation = bestMeanCorrelation;
diagnostics.configuredSpacingLambda = cfg.array.elementSpacingLambda;
diagnostics.configuredMeanCorrelation = mean(configuredCorrelation);
diagnostics.configuredMinCorrelation = min(configuredCorrelation);
diagnostics.configuredMaxCorrelation = max(configuredCorrelation);
end

function manifold = local_normalize_columns(manifold)
refPhase = exp(-1i * angle(manifold(1, :)));
manifold = manifold .* refPhase;
colNorm = vecnorm(manifold, 2, 1);
colNorm(colNorm < eps) = 1;
manifold = manifold ./ colNorm;
end
