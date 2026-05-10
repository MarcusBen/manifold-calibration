function result = benchmark_advantage_audit(ctx, cfg, conditions)
%BENCHMARK_ADVANTAGE_AUDIT Audit frontend advantage after backend switch.

case13Cfg = case13_helpers('profile_config', cfg.case13);
methodKeys = case13Cfg.methodKeys;
numConditions = numel(conditions);
conditionResults = repmat(local_empty_condition_result(), numConditions, 1);

modelCache = containers.Map('KeyType', 'double', 'ValueType', 'any');
for conditionIdx = 1:numConditions
    condition = conditions(conditionIdx);
    if isKey(modelCache, condition.calibrationCount)
        models = modelCache(condition.calibrationCount);
    else
        calIdx = select_calibration_indices(ctx.thetaDeg, condition.calibrationCount, 'uniform');
        models = build_sparse_models(ctx, calIdx, cfg.model);
        models.case13CalibrationAnglesDeg = ctx.thetaDeg(calIdx);
        modelCache(condition.calibrationCount) = models;
    end
    methods = local_case13_named_methods(ctx, models, methodKeys);
    conditionResults(conditionIdx) = local_run_condition(ctx, methods, case13Cfg, condition);
end

result = struct();
result.profile = case13Cfg.profile;
result.snapshotPolicy = 'common_truth_snapshots_across_methods';
result.methodKeys = methodKeys;
result.conditions = conditions;
result.conditionResults = conditionResults;
result.summaryTable = local_condition_summary_table(conditionResults);
result.failureTable = local_failure_table(conditionResults);
result.winSummary = local_win_summary(conditionResults);
end

function entry = local_empty_condition_result()
entry = struct();
entry.calibrationCount = [];
entry.snrDb = [];
entry.numSources = [];
entry.stratum = '';
entry.difficulty = '';
entry.trueAnglesDeg = [];
entry.methodNames = {};
entry.methodLabels = {};
entry.rmse = [];
entry.resolvedRate = [];
entry.worstAbsError = [];
entry.v33Rmse = NaN;
entry.ardRmse = NaN;
entry.bestBaselineName = '';
entry.bestBaselineRmse = NaN;
entry.oracleRmse = NaN;
entry.deltaRmseV33MinusArd = NaN;
entry.deltaRmseV33MinusBestBaseline = NaN;
entry.deltaRmseV33MinusOracle = NaN;
entry.deltaResolvedV33MinusArd = NaN;
entry.deltaResolvedV33MinusBestBaseline = NaN;
entry.v33VsArdLabel = 'neutral';
entry.v33VsBestBaselineLabel = 'neutral';
end

function methods = local_case13_named_methods(ctx, models, methodKeys)
methods = repmat(struct('name', '', 'label', '', 'manifold', []), 1, numel(methodKeys));
for idx = 1:numel(methodKeys)
    key = methodKeys{idx};
    switch key
        case 'ideal'
            methods(idx) = struct('name', 'ideal', 'label', 'Ideal', 'manifold', ctx.AI);
        case 'interp'
            methods(idx) = struct('name', 'interp', 'label', 'Interpolation', 'manifold', models.AInterp);
        case 'ard'
            methods(idx) = struct('name', 'ard', 'label', 'ARD', 'manifold', models.AARD);
        case 'proposed_v1'
            methods(idx) = struct('name', 'proposed_v1', 'label', 'Proposed V1', 'manifold', models.AProposedV1);
        case 'proposed_v2'
            methods(idx) = struct('name', 'proposed_v2', 'label', 'Proposed V2', 'manifold', models.AProposedV2);
        case 'proposed_v3'
            methodLabel = 'Proposed V3.3';
            if isfield(models, 'v3Diagnostics') && isfield(models.v3Diagnostics, 'label') && ...
                    ~isempty(models.v3Diagnostics.label)
                methodLabel = models.v3Diagnostics.label;
            end
            methods(idx) = struct('name', 'proposed_v3', 'label', methodLabel, 'manifold', models.AProposedV3);
        case 'oracle'
            methods(idx) = struct('name', 'oracle', 'label', 'HFSS Oracle', 'manifold', ctx.AH);
        otherwise
            error('Unknown Case13 method key: %s', key);
    end
end
end

function entry = local_run_condition(ctx, methods, case13Cfg, condition)
evalCfg = struct();
evalCfg.numSources = condition.numSources;
evalCfg.trueAngles = condition.targetAnglesDeg;
evalCfg.snrDb = condition.snrDb;
evalCfg.snapshots = case13Cfg.snapshots;
evalCfg.monteCarlo = case13Cfg.monteCarlo;
evalCfg.toleranceDeg = case13Cfg.toleranceDeg;
evalCfg.backendName = case13Cfg.backendName;
evalCfg.threeSourceBackendName = case13Cfg.threeSourceBackendName;
backendCfg = local_backend_cfg(case13Cfg, ctx.thetaDeg, condition.targetAnglesDeg, condition.numSources);
bench = benchmark_core_sources(ctx, methods, evalCfg, backendCfg);

entry = local_empty_condition_result();
entry.calibrationCount = condition.calibrationCount;
entry.snrDb = condition.snrDb;
entry.numSources = condition.numSources;
entry.stratum = condition.stratum;
entry.difficulty = condition.difficulty;
entry.trueAnglesDeg = bench.trueAngleSetsDeg;
entry.methodNames = bench.methodNames;
entry.methodLabels = bench.methodLabels;
entry.rmse = bench.perTargetRmse(1, :);
entry.resolvedRate = bench.perTargetResolvedRate(1, :);
entry.worstAbsError = bench.perTargetWorstAbsError(1, :);
entry = local_add_deltas(entry, case13Cfg);
end

function backendCfg = local_backend_cfg(case13Cfg, thetaDeg, angleSetsDeg, numSources)
if numSources == 3
    strideDeg = case13Cfg.threeSourceCandidateAngleStrideDeg;
else
    strideDeg = case13Cfg.backendCandidateAngleStrideDeg;
end
minAngle = max(min(thetaDeg), min(angleSetsDeg(:)) - 18);
maxAngle = min(max(thetaDeg), max(angleSetsDeg(:)) + 18);
candidateAnglesDeg = unique([(minAngle:strideDeg:maxAngle).'; angleSetsDeg(:)]).';
backendCfg = struct();
backendCfg.candidateAnglesDeg = candidateAnglesDeg;
backendCfg.minimumSeparationDeg = case13Cfg.backendMinimumSeparationDeg;
backendCfg.maximumSeparationDeg = case13Cfg.backendMaximumSeparationDeg;
backendCfg.topCandidateCount = case13Cfg.topCandidateCount;
backendCfg.numSources = numSources;
backendCfg.scanAnglesDeg = thetaDeg;
end

function entry = local_add_deltas(entry, case13Cfg)
v3Idx = find(strcmp(entry.methodNames, 'proposed_v3'), 1, 'first');
ardIdx = find(strcmp(entry.methodNames, 'ard'), 1, 'first');
oracleIdx = find(strcmp(entry.methodNames, 'oracle'), 1, 'first');
baselineMask = ismember(entry.methodNames, {'interp', 'ard', 'proposed_v1', 'proposed_v2'});
baselineIdx = find(baselineMask);
[bestBaselineRmse, localBestIdx] = min(entry.rmse(baselineIdx));
bestIdx = baselineIdx(localBestIdx);

entry.v33Rmse = entry.rmse(v3Idx);
entry.ardRmse = entry.rmse(ardIdx);
entry.bestBaselineName = entry.methodNames{bestIdx};
entry.bestBaselineRmse = bestBaselineRmse;
entry.oracleRmse = entry.rmse(oracleIdx);
entry.deltaRmseV33MinusArd = entry.v33Rmse - entry.ardRmse;
entry.deltaRmseV33MinusBestBaseline = entry.v33Rmse - entry.bestBaselineRmse;
entry.deltaRmseV33MinusOracle = entry.v33Rmse - entry.oracleRmse;
entry.deltaResolvedV33MinusArd = entry.resolvedRate(v3Idx) - entry.resolvedRate(ardIdx);
entry.deltaResolvedV33MinusBestBaseline = entry.resolvedRate(v3Idx) - entry.resolvedRate(bestIdx);
entry.v33VsArdLabel = case13_helpers('delta_label', ...
    entry.deltaRmseV33MinusArd, case13Cfg.winToleranceDeg, true);
entry.v33VsBestBaselineLabel = case13_helpers('delta_label', ...
    entry.deltaRmseV33MinusBestBaseline, case13Cfg.winToleranceDeg, true);
end

function summaryTable = local_condition_summary_table(conditionResults)
numRows = numel(conditionResults);
calibrationCount = zeros(numRows, 1);
snrDb = zeros(numRows, 1);
numSources = zeros(numRows, 1);
stratum = strings(numRows, 1);
difficulty = strings(numRows, 1);
bestBaselineName = strings(numRows, 1);
v33Rmse = zeros(numRows, 1);
ardRmse = zeros(numRows, 1);
bestBaselineRmse = zeros(numRows, 1);
oracleRmse = zeros(numRows, 1);
deltaRmseV33MinusArd = zeros(numRows, 1);
deltaRmseV33MinusBestBaseline = zeros(numRows, 1);
deltaRmseV33MinusOracle = zeros(numRows, 1);
deltaResolvedV33MinusArd = zeros(numRows, 1);
deltaResolvedV33MinusBestBaseline = zeros(numRows, 1);
v33VsArdLabel = strings(numRows, 1);
v33VsBestBaselineLabel = strings(numRows, 1);
for rowIdx = 1:numRows
    entry = conditionResults(rowIdx);
    calibrationCount(rowIdx) = entry.calibrationCount;
    snrDb(rowIdx) = entry.snrDb;
    numSources(rowIdx) = entry.numSources;
    stratum(rowIdx) = string(entry.stratum);
    difficulty(rowIdx) = string(entry.difficulty);
    bestBaselineName(rowIdx) = string(entry.bestBaselineName);
    v33Rmse(rowIdx) = entry.v33Rmse;
    ardRmse(rowIdx) = entry.ardRmse;
    bestBaselineRmse(rowIdx) = entry.bestBaselineRmse;
    oracleRmse(rowIdx) = entry.oracleRmse;
    deltaRmseV33MinusArd(rowIdx) = entry.deltaRmseV33MinusArd;
    deltaRmseV33MinusBestBaseline(rowIdx) = entry.deltaRmseV33MinusBestBaseline;
    deltaRmseV33MinusOracle(rowIdx) = entry.deltaRmseV33MinusOracle;
    deltaResolvedV33MinusArd(rowIdx) = entry.deltaResolvedV33MinusArd;
    deltaResolvedV33MinusBestBaseline(rowIdx) = entry.deltaResolvedV33MinusBestBaseline;
    v33VsArdLabel(rowIdx) = string(entry.v33VsArdLabel);
    v33VsBestBaselineLabel(rowIdx) = string(entry.v33VsBestBaselineLabel);
end
summaryTable = table(calibrationCount, snrDb, numSources, stratum, difficulty, ...
    bestBaselineName, v33Rmse, ardRmse, bestBaselineRmse, oracleRmse, ...
    deltaRmseV33MinusArd, deltaRmseV33MinusBestBaseline, deltaRmseV33MinusOracle, ...
    deltaResolvedV33MinusArd, deltaResolvedV33MinusBestBaseline, ...
    v33VsArdLabel, v33VsBestBaselineLabel);
end

function failureTable = local_failure_table(conditionResults)
summaryTable = local_condition_summary_table(conditionResults);
lossMask = summaryTable.deltaRmseV33MinusBestBaseline > 0;
failureTable = summaryTable(lossMask, :);
if ~isempty(failureTable)
    [~, order] = sort(failureTable.deltaRmseV33MinusBestBaseline, 'descend');
    failureTable = failureTable(order, :);
end
end

function winSummary = local_win_summary(conditionResults)
summaryTable = local_condition_summary_table(conditionResults);
labels = ["win"; "neutral"; "loss"];
winSummary = table(labels, zeros(numel(labels), 1), zeros(numel(labels), 1), ...
    'VariableNames', {'label', 'vsArdCount', 'vsBestBaselineCount'});
for labelIdx = 1:numel(labels)
    winSummary.vsArdCount(labelIdx) = sum(summaryTable.v33VsArdLabel == labels(labelIdx));
    winSummary.vsBestBaselineCount(labelIdx) = sum(summaryTable.v33VsBestBaselineLabel == labels(labelIdx));
end
end
