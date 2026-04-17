function ctx = build_project_context(cfg)
%BUILD_PROJECT_CONTEXT Load the HFSS data and prepare normalized manifolds.

raw = readmatrix(cfg.data.csvPath, 'NumHeaderLines', 1);
raw = raw(~all(isnan(raw), 2), :);

thetaDeg = raw(:, 4).';
valueCols = [5 7; 9 11; 13 15; 17 19; 21 23; 25 27; 29 31; 33 35];
numElements = size(valueCols, 1);
numAngles = size(raw, 1);

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

ai = local_ideal_manifold(thetaDeg, cfg.array.numElements, cfg.array.elementSpacingLambda);
ctx = struct();
ctx.rootDir = cfg.rootDir;
ctx.thetaDeg = thetaDeg;
ctx.numAngles = numel(thetaDeg);
ctx.numElements = cfg.array.numElements;
ctx.gridStepDeg = median(diff(thetaDeg));
ctx.AHRaw = ahRaw;
ctx.AH = local_normalize_columns(ahRaw);
ctx.AI = local_normalize_columns(ai);
end

function aIdeal = local_ideal_manifold(thetaDeg, numElements, spacingLambda)
elementIndex = (0:numElements-1).';
phaseSlope = 2 * pi * spacingLambda;
aIdeal = exp(1i * phaseSlope * elementIndex * sind(thetaDeg));
end

function manifold = local_normalize_columns(manifold)
refPhase = exp(-1i * angle(manifold(1, :)));
manifold = manifold .* refPhase;
colNorm = vecnorm(manifold, 2, 1);
colNorm(colNorm < eps) = 1;
manifold = manifold ./ colNorm;
end
