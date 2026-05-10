function result = benchmark_core_sources(ctx, methods, evalCfg, backendCfg)
%BENCHMARK_CORE_SOURCES Benchmark 1/2/3-source DOA with common truth snapshots.

numSources = evalCfg.numSources;
if ~ismember(numSources, [1 2 3])
    error('Core source benchmark supports numSources in {1,2,3}.');
end
if size(evalCfg.trueAngles, 2) ~= numSources
    error('trueAngles column count must match numSources.');
end

[trueAngleSets, trueIdxSets] = doa_backend_utils('snap_angle_sets', ...
    ctx.thetaDeg, evalCfg.trueAngles);
numTargets = size(trueAngleSets, 1);
numMethods = numel(methods);
numMonteCarlo = evalCfg.monteCarlo;

snapshotsByTarget = cell(numTargets, numMonteCarlo);
for targetIdx = 1:numTargets
    aTrue = ctx.AH(:, trueIdxSets(targetIdx, :));
    for mcIdx = 1:numMonteCarlo
        snapshotsByTarget{targetIdx, mcIdx} = doa_backend_utils( ...
            'simulate_snapshots', aTrue, evalCfg.snrDb, evalCfg.snapshots);
    end
end

trialRmse = zeros(numTargets, numMethods, numMonteCarlo);
trialResolved = false(numTargets, numMethods, numMonteCarlo);
trialWorstAbsError = zeros(numTargets, numMethods, numMonteCarlo);
backendDiagnostics = cell(numTargets, numMethods, numMonteCarlo);
representative = repmat(struct('estAnglesDeg', [], 'spectrum', [], ...
    'diagnostics', []), 1, numMethods);

for methodIdx = 1:numMethods
    for targetIdx = 1:numTargets
        trueAngles = sort(trueAngleSets(targetIdx, :));
        for mcIdx = 1:numMonteCarlo
            x = snapshotsByTarget{targetIdx, mcIdx};
            backendResult = local_run_core_backend(x, methods(methodIdx).manifold, ...
                ctx.thetaDeg, numSources, evalCfg, backendCfg);
            estAngles = sort(backendResult.estAnglesDeg(:).');
            if numel(estAngles) == numSources
                absError = abs(estAngles - trueAngles);
                trialRmse(targetIdx, methodIdx, mcIdx) = sqrt(mean(absError .^ 2));
                trialWorstAbsError(targetIdx, methodIdx, mcIdx) = max(absError);
                trialResolved(targetIdx, methodIdx, mcIdx) = ...
                    all(absError <= evalCfg.toleranceDeg);
            else
                trialRmse(targetIdx, methodIdx, mcIdx) = Inf;
                trialWorstAbsError(targetIdx, methodIdx, mcIdx) = Inf;
                trialResolved(targetIdx, methodIdx, mcIdx) = false;
            end
            backendDiagnostics{targetIdx, methodIdx, mcIdx} = backendResult.diagnostics;
            if targetIdx == 1 && mcIdx == 1
                representative(methodIdx).estAnglesDeg = estAngles;
                representative(methodIdx).spectrum = backendResult.spectrum;
                representative(methodIdx).diagnostics = backendResult.diagnostics;
            end
        end
    end
end

result = struct();
result.numSources = numSources;
result.snapshotPolicy = 'common_truth_snapshots_across_methods';
result.methodLabels = {methods.label};
result.methodNames = {methods.name};
result.requestedAngleSetsDeg = evalCfg.trueAngles;
result.trueAngleSetsDeg = trueAngleSets;
result.backendName = local_backend_name(numSources, evalCfg);
result.perTargetRmse = mean(trialRmse, 3);
result.perTargetResolvedRate = mean(trialResolved, 3);
result.perTargetWorstAbsError = mean(trialWorstAbsError, 3);
result.backendDiagnostics = backendDiagnostics;
result.representative = representative;
result.summary = struct();
result.summary.meanRmse = mean(result.perTargetRmse, 1);
result.summary.meanResolvedRate = mean(result.perTargetResolvedRate, 1);
result.summary.meanWorstAbsError = mean(result.perTargetWorstAbsError, 1);
end

function backendResult = local_run_core_backend(x, scanManifold, scanAnglesDeg, ...
    numSources, evalCfg, backendCfg)
covariance = (x * x') / size(x, 2);
spectrum = doa_backend_utils('music_spectrum', covariance, scanManifold, numSources);
switch numSources
    case 1
        peakIdx = doa_backend_utils('pick_local_peaks', spectrum, 1);
        backendResult = struct();
        backendResult.name = 'music';
        backendResult.estAnglesDeg = scanAnglesDeg(peakIdx);
        backendResult.spectrum = spectrum;
        backendResult.diagnostics = struct('peakIndex', peakIdx);
    case 2
        pairCfg = backendCfg;
        pairCfg.numSources = 2;
        pairCfg.scanAnglesDeg = scanAnglesDeg;
        backendResult = doa_backend_pairwise_grid_ml(x, scanManifold, scanAnglesDeg, pairCfg);
        backendResult.spectrum = spectrum;
    case 3
        tripletCfg = backendCfg;
        tripletCfg.numSources = 3;
        tripletCfg.scanAnglesDeg = scanAnglesDeg;
        backendResult = doa_backend_triplet_grid_ml(x, scanManifold, scanAnglesDeg, tripletCfg);
        backendResult.spectrum = spectrum;
    otherwise
        error('Unsupported numSources=%d.', numSources);
end
backendResult.diagnostics.backendName = local_backend_name(numSources, evalCfg);
end

function name = local_backend_name(numSources, evalCfg)
switch numSources
    case 1
        name = 'music';
    case 2
        name = evalCfg.backendName;
    case 3
        name = evalCfg.threeSourceBackendName;
end
end
