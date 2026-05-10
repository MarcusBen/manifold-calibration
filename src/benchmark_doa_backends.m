function result = benchmark_doa_backends(ctx, methods, evalCfg, backendCfg)
%BENCHMARK_DOA_BACKENDS Compare two-source DOA backends with common snapshots.

modeName = lower(strtrim(evalCfg.mode));
if ~strcmp(modeName, 'double')
    error('benchmark_doa_backends currently supports double-source mode only.');
end

numSources = size(evalCfg.trueAngles, 2);
if numSources ~= 2
    error('benchmark_doa_backends expects exactly two sources.');
end

[trueAngleSets, trueIdxSets] = doa_backend_utils('snap_angle_sets', ctx.thetaDeg, evalCfg.trueAngles);
backendNames = backendCfg.backendNames;
numBackends = numel(backendNames);
numTargets = size(trueAngleSets, 1);
numMethods = numel(methods);
stateCfg = struct('stableToleranceDeg', evalCfg.toleranceDeg, ...
    'biasedToleranceDeg', evalCfg.biasedToleranceDeg, ...
    'marginalToleranceDeg', evalCfg.marginalToleranceDeg);

snapshotsByTarget = cell(numTargets, evalCfg.monteCarlo);
for targetIdx = 1:numTargets
    aTrue = ctx.AH(:, trueIdxSets(targetIdx, :));
    for mcIdx = 1:evalCfg.monteCarlo
        snapshotsByTarget{targetIdx, mcIdx} = doa_backend_utils( ...
            'simulate_snapshots', aTrue, evalCfg.snrDb, evalCfg.snapshots);
    end
end

trialRmse = zeros(numBackends, numTargets, numMethods, evalCfg.monteCarlo);
trialResolution = false(numBackends, numTargets, numMethods, evalCfg.monteCarlo);
trialMarginal = false(numBackends, numTargets, numMethods, evalCfg.monteCarlo);
trialBiased = false(numBackends, numTargets, numMethods, evalCfg.monteCarlo);
trialStable = false(numBackends, numTargets, numMethods, evalCfg.monteCarlo);
trialCollapse = false(numBackends, numTargets, numMethods, evalCfg.monteCarlo);
backendDiagnostics = cell(numBackends, numTargets, numMethods, evalCfg.monteCarlo);
representative = repmat(struct('estAnglesDeg', [], 'diagnostics', []), numBackends, numMethods);

for backendIdx = 1:numBackends
    for methodIdx = 1:numMethods
        for targetIdx = 1:numTargets
            trueAngles = sort(trueAngleSets(targetIdx, :));
            for mcIdx = 1:evalCfg.monteCarlo
                x = snapshotsByTarget{targetIdx, mcIdx};
                backendResult = local_run_backend(backendNames{backendIdx}, x, ...
                    methods(methodIdx).manifold, ctx.thetaDeg, backendCfg);
                estAngles = sort(backendResult.estAnglesDeg(:).');
                if numel(estAngles) == 2
                    trialRmse(backendIdx, targetIdx, methodIdx, mcIdx) = ...
                        sqrt(mean((estAngles - trueAngles) .^ 2));
                else
                    trialRmse(backendIdx, targetIdx, methodIdx, mcIdx) = Inf;
                end
                state = doa_backend_utils('classify_double', estAngles, trueAngles, stateCfg);
                trialResolution(backendIdx, targetIdx, methodIdx, mcIdx) = state.isResolved;
                trialMarginal(backendIdx, targetIdx, methodIdx, mcIdx) = state.isMarginal;
                trialBiased(backendIdx, targetIdx, methodIdx, mcIdx) = state.isBiased;
                trialStable(backendIdx, targetIdx, methodIdx, mcIdx) = state.isStable;
                trialCollapse(backendIdx, targetIdx, methodIdx, mcIdx) = ...
                    doa_backend_utils('separation_collapsed', estAngles, trueAngles);
                backendDiagnostics{backendIdx, targetIdx, methodIdx, mcIdx} = backendResult.diagnostics;
                if local_collect_representative(evalCfg) && targetIdx == 1 && mcIdx == 1
                    representative(backendIdx, methodIdx).estAnglesDeg = estAngles;
                    representative(backendIdx, methodIdx).diagnostics = backendResult.diagnostics;
                end
            end
        end
    end
end

result = struct();
result.mode = modeName;
result.snapshotPolicy = 'common_truth_snapshots_across_backends_and_methods';
result.backendNames = backendNames;
result.methodLabels = {methods.label};
result.methodNames = {methods.name};
result.requestedAngleSetsDeg = evalCfg.trueAngles;
result.trueAngleSetsDeg = trueAngleSets;
result.rmse = mean(trialRmse, 4);
result.resolutionRate = mean(trialResolution, 4);
result.marginalRate = mean(trialMarginal, 4);
result.biasedRate = mean(trialBiased, 4);
result.stableRate = mean(trialStable, 4);
result.unresolvedRate = 1 - result.resolutionRate;
result.collapseRate = mean(trialCollapse, 4);
result.backendDiagnostics = backendDiagnostics;
result.representative = representative;
result.summary = local_summary(result);
end

function backendResult = local_run_backend(backendName, x, scanManifold, scanAnglesDeg, backendCfg)
switch lower(strtrim(backendName))
    case 'music'
        backendResult = doa_backend_music_baseline(x, scanManifold, scanAnglesDeg, backendCfg);
    case 'music_pair_rescore'
        backendResult = doa_backend_music_pair_rescore(x, scanManifold, scanAnglesDeg, backendCfg);
    case 'pairwise_grid_ml'
        backendResult = doa_backend_pairwise_grid_ml(x, scanManifold, scanAnglesDeg, backendCfg);
    otherwise
        error('Unknown DOA backend: %s', backendName);
end
end

function collect = local_collect_representative(evalCfg)
collect = isfield(evalCfg, 'collectRepresentative') && evalCfg.collectRepresentative;
end

function summary = local_summary(result)
musicIdx = find(strcmp(result.backendNames, 'music'), 1, 'first');
oracleIdx = find(strcmp(result.methodNames, 'oracle'), 1, 'first');
v3Idx = find(strcmp(result.methodNames, 'proposed_v3'), 1, 'first');
v1Idx = find(strcmp(result.methodNames, 'proposed_v1'), 1, 'first');

summary = struct();
summary.meanRmse = local_mean_over_targets(result.rmse, result);
summary.meanResolution = local_mean_over_targets(result.resolutionRate, result);
summary.meanStable = local_mean_over_targets(result.stableRate, result);
summary.meanCollapse = local_mean_over_targets(result.collapseRate, result);
summary.oracleGainOverMusic = NaN(numel(result.backendNames), 1);
summary.v3GainOverMusic = NaN(numel(result.backendNames), 1);
summary.v1GainOverMusic = NaN(numel(result.backendNames), 1);
summary.v3ToOracleGap = NaN(numel(result.backendNames), 1);
summary.v1ToOracleGap = NaN(numel(result.backendNames), 1);

if ~isempty(musicIdx) && ~isempty(oracleIdx)
    oracleMusic = summary.meanResolution(musicIdx, oracleIdx);
    summary.oracleGainOverMusic = summary.meanResolution(:, oracleIdx) - oracleMusic;
end
if ~isempty(musicIdx) && ~isempty(v3Idx)
    v3Music = summary.meanResolution(musicIdx, v3Idx);
    summary.v3GainOverMusic = summary.meanResolution(:, v3Idx) - v3Music;
end
if ~isempty(musicIdx) && ~isempty(v1Idx)
    v1Music = summary.meanResolution(musicIdx, v1Idx);
    summary.v1GainOverMusic = summary.meanResolution(:, v1Idx) - v1Music;
end
if ~isempty(oracleIdx) && ~isempty(v3Idx)
    summary.v3ToOracleGap = summary.meanResolution(:, oracleIdx) - summary.meanResolution(:, v3Idx);
end
if ~isempty(oracleIdx) && ~isempty(v1Idx)
    summary.v1ToOracleGap = summary.meanResolution(:, oracleIdx) - summary.meanResolution(:, v1Idx);
end
end

function values = local_mean_over_targets(metric, result)
values = reshape(mean(metric, 2), [numel(result.backendNames), numel(result.methodNames)]);
end
