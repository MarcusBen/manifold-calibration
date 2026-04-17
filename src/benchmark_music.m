function result = benchmark_music(ctx, methods, evalCfg)
%BENCHMARK_MUSIC Run single-source or two-source MUSIC experiments.

modeName = lower(strtrim(evalCfg.mode));
collectSpectrum = isfield(evalCfg, 'collectRepresentativeSpectrum') && evalCfg.collectRepresentativeSpectrum;

switch modeName
    case 'single'
        trueAngleSets = evalCfg.trueAngles(:);
        numSources = 1;
    case 'double'
        trueAngleSets = evalCfg.trueAngles;
        numSources = size(trueAngleSets, 2);
    otherwise
        error('Unsupported benchmark mode: %s', evalCfg.mode);
end

numTargets = size(trueAngleSets, 1);
numMethods = numel(methods);
toleranceDeg = evalCfg.toleranceDeg;

result = struct();
result.mode = modeName;
result.trueAngleSetsDeg = trueAngleSets;
result.methods = repmat(struct(), 1, numMethods);

for methodIdx = 1:numMethods
    result.methods(methodIdx).name = methods(methodIdx).name;
    result.methods(methodIdx).label = methods(methodIdx).label;
    result.methods(methodIdx).successRate = NaN;
    result.methods(methodIdx).rmse = NaN;
    result.methods(methodIdx).perTargetRmse = NaN(numTargets, 1);
    result.methods(methodIdx).perTargetSuccess = NaN(numTargets, 1);
    result.methods(methodIdx).representativeSpectrum = [];
    result.methods(methodIdx).representativeEstAnglesDeg = [];
end

for methodIdx = 1:numMethods
    switch modeName
        case 'single'
            trialErrors = zeros(numTargets, evalCfg.monteCarlo);
        case 'double'
            trialErrors = zeros(numTargets, evalCfg.monteCarlo);
    end
    trialSuccess = false(numTargets, evalCfg.monteCarlo);

    for targetIdx = 1:numTargets
        trueAngles = trueAngleSets(targetIdx, :);
        trueIdx = local_angles_to_indices(ctx.thetaDeg, trueAngles);
        aTrue = ctx.AH(:, trueIdx);

        for mcIdx = 1:evalCfg.monteCarlo
            x = local_simulate_snapshots(aTrue, evalCfg.snrDb, evalCfg.snapshots);
            [estAngles, spectrum] = local_estimate_music(x, methods(methodIdx).manifold, ctx.thetaDeg, numSources);

            if strcmp(modeName, 'single')
                trialErrors(targetIdx, mcIdx) = estAngles(1) - trueAngles(1);
                trialSuccess(targetIdx, mcIdx) = abs(trialErrors(targetIdx, mcIdx)) <= toleranceDeg;
            else
                estAngles = sort(estAngles(:).');
                trueAngles = sort(trueAngles(:).');
                trialErrors(targetIdx, mcIdx) = sqrt(mean((estAngles - trueAngles) .^ 2));
                trialSuccess(targetIdx, mcIdx) = all(abs(estAngles - trueAngles) <= toleranceDeg);
            end

            if collectSpectrum && targetIdx == 1 && mcIdx == 1
                result.methods(methodIdx).representativeSpectrum = spectrum;
                result.methods(methodIdx).representativeEstAnglesDeg = estAngles;
            end
        end
    end

    if strcmp(modeName, 'single')
        result.methods(methodIdx).rmse = sqrt(mean(trialErrors(:) .^ 2));
        result.methods(methodIdx).perTargetRmse = sqrt(mean(trialErrors .^ 2, 2));
    else
        result.methods(methodIdx).rmse = mean(trialErrors(:));
        result.methods(methodIdx).perTargetRmse = mean(trialErrors, 2);
    end

    result.methods(methodIdx).successRate = mean(trialSuccess(:));
    result.methods(methodIdx).perTargetSuccess = mean(trialSuccess, 2);
end
end

function idx = local_angles_to_indices(thetaGrid, queryAngles)
idx = zeros(size(queryAngles));
for k = 1:numel(queryAngles)
    matches = find(abs(thetaGrid - queryAngles(k)) < 1e-9, 1, 'first');
    if isempty(matches)
        error('Angle %.6f deg is not available in the HFSS grid.', queryAngles(k));
    end
    idx(k) = matches;
end
end

function x = local_simulate_snapshots(aTrue, snrDb, snapshots)
numSources = size(aTrue, 2);
sourceSignals = (randn(numSources, snapshots) + 1i * randn(numSources, snapshots)) / sqrt(2);
signalOnly = aTrue * sourceSignals;
signalPower = mean(abs(signalOnly(:)) .^ 2);
noisePower = signalPower / (10 ^ (snrDb / 10));
noise = sqrt(noisePower / 2) * ...
    (randn(size(signalOnly)) + 1i * randn(size(signalOnly)));
x = signalOnly + noise;
end

function [estAngles, spectrum] = local_estimate_music(x, scanManifold, scanAngles, numSources)
covariance = (x * x') / size(x, 2);
spectrum = local_music_spectrum(covariance, scanManifold, numSources);
estAngles = local_pick_top_k_peaks(spectrum, scanAngles, numSources);
end

function spectrum = local_music_spectrum(covariance, scanManifold, numSources)
[eigVec, eigVal] = eig(covariance, 'vector');
[~, order] = sort(real(eigVal), 'descend');
eigVec = eigVec(:, order);
noiseSubspace = eigVec(:, numSources+1:end);
projection = noiseSubspace' * scanManifold;
denominator = sum(abs(projection) .^ 2, 1);
denominator(denominator < eps) = eps;
spectrum = real(1 ./ denominator);
end

function estAngles = local_pick_top_k_peaks(spectrum, scanAngles, k)
spectrum = spectrum(:).';
scanAngles = scanAngles(:).';
numPoints = numel(spectrum);

isPeak = false(1, numPoints);
if numPoints == 1
    isPeak(1) = true;
else
    isPeak(1) = spectrum(1) >= spectrum(2);
    isPeak(end) = spectrum(end) >= spectrum(end-1);
    for idx = 2:numPoints-1
        isPeak(idx) = spectrum(idx) >= spectrum(idx-1) && spectrum(idx) >= spectrum(idx+1);
    end
end

peakIdx = find(isPeak);
if isempty(peakIdx)
    [~, peakIdx] = maxk(spectrum, k);
else
    [~, order] = sort(spectrum(peakIdx), 'descend');
    peakIdx = peakIdx(order);
end

selected = zeros(1, 0);
for candidate = peakIdx
    if isempty(selected) || all(abs(candidate - selected) > 1)
        selected(end+1) = candidate; %#ok<AGROW>
    end
    if numel(selected) == k
        break;
    end
end

if numel(selected) < k
    [~, allOrder] = maxk(spectrum, min(k + 8, numPoints));
    for candidate = allOrder
        if ~ismember(candidate, selected)
            selected(end+1) = candidate; %#ok<AGROW>
        end
        if numel(selected) == k
            break;
        end
    end
end

estAngles = sort(scanAngles(selected(1:k)));
end
