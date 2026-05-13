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
backendNames = local_backend_names(numSources, evalCfg);
numBackends = numel(backendNames);

snapshotsByTarget = cell(numTargets, numMonteCarlo);
for targetIdx = 1:numTargets
    aTrue = ctx.AH(:, trueIdxSets(targetIdx, :));
    for mcIdx = 1:numMonteCarlo
        snapshotsByTarget{targetIdx, mcIdx} = doa_backend_utils( ...
            'simulate_snapshots', aTrue, evalCfg.snrDb, evalCfg.snapshots);
    end
end

trialRmse = zeros(numTargets, numMethods, numBackends, numMonteCarlo);
trialResolved = false(numTargets, numMethods, numBackends, numMonteCarlo);
trialWorstAbsError = zeros(numTargets, numMethods, numBackends, numMonteCarlo);
backendDiagnostics = cell(numTargets, numMethods, numBackends, numMonteCarlo);
representative = repmat(struct('estAnglesDeg', [], 'spectrum', [], ...
    'diagnostics', []), numBackends, numMethods);

for methodIdx = 1:numMethods
    for targetIdx = 1:numTargets
        trueAngles = sort(trueAngleSets(targetIdx, :));
        for mcIdx = 1:numMonteCarlo
            x = snapshotsByTarget{targetIdx, mcIdx};
            for backendIdx = 1:numBackends
                backendResult = local_run_core_backend(backendNames{backendIdx}, x, ...
                    methods(methodIdx).manifold, ctx.thetaDeg, numSources, backendCfg);
                estAngles = sort(backendResult.estAnglesDeg(:).');
                if numel(estAngles) == numSources
                    absError = abs(estAngles - trueAngles);
                    trialRmse(targetIdx, methodIdx, backendIdx, mcIdx) = ...
                        sqrt(mean(absError .^ 2));
                    trialWorstAbsError(targetIdx, methodIdx, backendIdx, mcIdx) = max(absError);
                    trialResolved(targetIdx, methodIdx, backendIdx, mcIdx) = ...
                        all(absError <= evalCfg.toleranceDeg);
                else
                    trialRmse(targetIdx, methodIdx, backendIdx, mcIdx) = Inf;
                    trialWorstAbsError(targetIdx, methodIdx, backendIdx, mcIdx) = Inf;
                    trialResolved(targetIdx, methodIdx, backendIdx, mcIdx) = false;
                end
                backendDiagnostics{targetIdx, methodIdx, backendIdx, mcIdx} = ...
                    backendResult.diagnostics;
                if targetIdx == 1 && mcIdx == 1
                    representative(backendIdx, methodIdx).estAnglesDeg = estAngles;
                    representative(backendIdx, methodIdx).spectrum = backendResult.spectrum;
                    representative(backendIdx, methodIdx).diagnostics = backendResult.diagnostics;
                end
            end
        end
    end
end

result = struct();
result.numSources = numSources;
if numBackends > 1
    result.snapshotPolicy = 'common_truth_snapshots_across_backends_and_methods';
else
    result.snapshotPolicy = 'common_truth_snapshots_across_methods';
end
result.methodLabels = {methods.label};
result.methodNames = {methods.name};
result.requestedAngleSetsDeg = evalCfg.trueAngles;
result.trueAngleSetsDeg = trueAngleSets;
result.backendName = backendNames{1};
result.backendNames = backendNames;
result.perTargetRmse = mean(trialRmse, 4);
result.perTargetResolvedRate = mean(trialResolved, 4);
result.perTargetWorstAbsError = mean(trialWorstAbsError, 4);
if numBackends == 1
    result.perTargetRmse = result.perTargetRmse(:, :, 1);
    result.perTargetResolvedRate = result.perTargetResolvedRate(:, :, 1);
    result.perTargetWorstAbsError = result.perTargetWorstAbsError(:, :, 1);
    result.backendDiagnostics = local_single_backend_diagnostics( ...
        backendDiagnostics, numTargets, numMethods, numMonteCarlo);
else
    result.backendDiagnostics = backendDiagnostics;
end
result.representative = representative;
result.summary = struct();
if numBackends == 1
    result.summary.meanRmse = mean(result.perTargetRmse, 1);
    result.summary.meanResolvedRate = mean(result.perTargetResolvedRate, 1);
    result.summary.meanWorstAbsError = mean(result.perTargetWorstAbsError, 1);
else
    result.summary.meanRmse = local_mean_over_targets(result.perTargetRmse, ...
        numMethods, numBackends);
    result.summary.meanResolvedRate = local_mean_over_targets( ...
        result.perTargetResolvedRate, numMethods, numBackends);
    result.summary.meanWorstAbsError = local_mean_over_targets( ...
        result.perTargetWorstAbsError, numMethods, numBackends);
end
end

function backendResult = local_run_core_backend(backendName, x, scanManifold, scanAnglesDeg, ...
    numSources, backendCfg)
covariance = (x * x') / size(x, 2);
spectrum = doa_backend_utils('music_spectrum', covariance, scanManifold, numSources);
backendCfg.numSources = numSources;
backendCfg.scanAnglesDeg = scanAnglesDeg;
backendResult = doa_backend_dispatch(backendName, x, scanManifold, scanAnglesDeg, backendCfg);
if ~isfield(backendResult, 'spectrum') || isempty(backendResult.spectrum)
    backendResult.spectrum = spectrum;
end
backendResult.diagnostics.backendName = backendName;
end

function values = local_mean_over_targets(metric, numMethods, numBackends)
values = reshape(mean(metric, 1), [numMethods, numBackends]);
end

function diagnostics = local_single_backend_diagnostics(backendDiagnostics, ...
    numTargets, numMethods, numMonteCarlo)
diagnostics = cell(numTargets, numMethods, numMonteCarlo);
for mcIdx = 1:numMonteCarlo
    diagnostics(:, :, mcIdx) = backendDiagnostics(:, :, 1, mcIdx);
end
end

function names = local_backend_names(numSources, evalCfg)
if isfield(evalCfg, 'backendNames') && ~isempty(evalCfg.backendNames)
    names = evalCfg.backendNames;
    if ischar(names) || isstring(names)
        names = cellstr(names);
    end
    names = reshape(names, 1, []);
else
    names = {local_backend_name(numSources, evalCfg)};
end
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
