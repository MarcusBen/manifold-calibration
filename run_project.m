function results = run_project(selectedCases, cfg)
%RUN_PROJECT Run the MATLAB manifold-calibration experiments.
%
% Usage:
%   run_project()              % run all 10 cases
%   run_project([1 3 7])       % run selected cases
%
% The code follows the project documents:
%   1) HFSS data are always treated as the truth manifold.
%   2) Sparse calibration angles are used only to reconstruct the manifold.
%   3) DOA snapshots are always generated from the HFSS truth manifold.

if nargin < 1 || isempty(selectedCases)
    selectedCases = 1:10;
end

rootDir = fileparts(mfilename('fullpath'));
setup_paths(rootDir);

if nargin < 2 || isempty(cfg)
    cfg = default_config(rootDir);
else
    cfg.rootDir = rootDir;
    if ~isfield(cfg, 'outputDir') || isempty(cfg.outputDir)
        cfg.outputDir = fullfile(rootDir, 'results');
    end
end
cfg = local_complete_runtime_config(cfg, rootDir);

outputRoot = cfg.outputDir;
if cfg.run.useTraceableDirs
    outputRoot = cfg.run.resultRoot;
end
if ~exist(outputRoot, 'dir')
    mkdir(outputRoot);
end

ctx = build_project_context(cfg);
caseRunners = { ...
    @case01_problem_validation, ...
    @case02_dominant_mismatch, ...
    @case03_unseen_generalization, ...
    @case04_calibration_count_sensitivity, ...
    @case05_sampling_strategy_sensitivity, ...
    @case06_model_sensitivity, ...
    @case07_single_source_snr, ...
    @case08_single_source_snapshots, ...
    @case09_two_source_resolution, ...
    @case10_random_split_robustness};

results = struct();

for runIdx = 1:numel(selectedCases)
    caseId = selectedCases(runIdx);
    if caseId < 1 || caseId > numel(caseRunners)
        error('Case id must be an integer in [1, 10].');
    end

    fprintf('\n=== Running Case %02d ===\n', caseId);
    fieldName = sprintf('case%02d', caseId);
    results.(fieldName) = caseRunners{caseId}(cfg, ctx);
end
end

function caseResult = case01_problem_validation(cfg, ctx)
rng(cfg.randomSeed + 1, 'twister');
outDir = local_case_output_dir(cfg, 'case01_problem_validation');

metrics = compute_manifold_metrics(ctx.AH, ctx.AI);
phaseResidualDeg = rad2deg(unwrap(angle(ctx.AH .* conj(ctx.AI)), [], 2));
amplitudeResidual = abs(ctx.AH) ./ max(abs(ctx.AI), eps) - 1;

fig = figure('Visible', 'off', 'Position', [100 100 1200 760]);
tiledlayout(2, 1, 'Padding', 'compact', 'TileSpacing', 'compact');
nexttile;
plot(ctx.thetaDeg, phaseResidualDeg.', 'LineWidth', 1.2);
grid on;
xlabel('Angle (deg)');
ylabel('Phase residual (deg)');
title('Case 1: element-wise phase residual');
legend(compose('Element %d', 1:ctx.numElements), 'Location', 'eastoutside');
nexttile;
plot(ctx.thetaDeg, amplitudeResidual.', 'LineWidth', 1.2);
grid on;
xlabel('Angle (deg)');
ylabel('Amplitude residual');
title('Case 1: element-wise amplitude residual');
save_figure(fig, fullfile(outDir, 'residual_components.png'));

fig = figure('Visible', 'off', 'Position', [120 120 1100 700]);
tiledlayout(2, 1, 'Padding', 'compact', 'TileSpacing', 'compact');
nexttile;
plot(ctx.thetaDeg, metrics.correlation, 'o-', 'LineWidth', 1.4, 'MarkerSize', 5);
grid on;
xlabel('Angle (deg)');
ylabel('Complex correlation');
title('Case 1: steering-vector similarity');
nexttile;
plot(ctx.thetaDeg, metrics.relativeError, 'o-', 'LineWidth', 1.4, 'MarkerSize', 5);
grid on;
xlabel('Angle (deg)');
ylabel('Relative error');
title('Case 1: ideal-vs-HFSS manifold mismatch');
save_figure(fig, fullfile(outDir, 'similarity_curves.png'));

methods = [ ...
    local_method('ideal', 'Ideal', ctx.AI), ...
    local_method('oracle', 'HFSS Oracle', ctx.AH)];

evalCfg = struct();
evalCfg.mode = 'single';
evalCfg.trueAngles = local_single_source_eval_angles(ctx, [], cfg);
evalCfg.snrDb = cfg.case1.highSNRDb;
evalCfg.snapshots = cfg.case1.snapshots;
evalCfg.monteCarlo = cfg.case1.monteCarlo;
evalCfg.toleranceDeg = cfg.case1.toleranceDeg;
evalCfg.collectRepresentativeSpectrum = false;
highSnrSweep = benchmark_music(ctx, methods, evalCfg);

[stressExampleAngle, exampleSelectionReason, stressScore] = local_case1_select_stress_angle(highSnrSweep);

exampleEval = evalCfg;
exampleEval.trueAngles = stressExampleAngle;
exampleEval.monteCarlo = 1;
exampleEval.collectRepresentativeSpectrum = true;
exampleSpectrum = benchmark_music(ctx, methods, exampleEval);

fig = figure('Visible', 'off', 'Position', [140 140 1100 520]);
hold on;
for methodIdx = 1:numel(exampleSpectrum.methods)
    plot(ctx.thetaDeg, 10 * log10(exampleSpectrum.methods(methodIdx).representativeSpectrum), ...
        'LineWidth', 1.6);
end
grid on;
xlabel('Scan angle (deg)');
ylabel('Pseudo-spectrum (dB)');
title({sprintf('Case 1: high-SNR spectrum at %.1f deg, SNR = %g dB', ...
    stressExampleAngle, cfg.case1.highSNRDb), ...
    'HFSS truth snapshots; MUSIC scan uses the listed estimator manifolds'});
legend({exampleSpectrum.methods.label}, 'Location', 'best');
save_figure(fig, fullfile(outDir, 'example_music_spectrum.png'));

fig = figure('Visible', 'off', 'Position', [160 160 1180 720]);
tiledlayout(2, 1, 'Padding', 'compact', 'TileSpacing', 'compact');
nexttile;
hold on;
for methodIdx = 1:numel(highSnrSweep.methods)
    plot(highSnrSweep.trueAngleSetsDeg, highSnrSweep.methods(methodIdx).perTargetMeanError, ...
        'o-', 'LineWidth', 1.4, 'MarkerSize', 5);
end
xline(stressExampleAngle, 'k--', 'Stress example');
grid on;
xlabel('True angle (deg)');
ylabel('Signed bias (deg)');
title(sprintf('Case 1: high-SNR signed bias, SNR = %g dB', cfg.case1.highSNRDb));
legend({highSnrSweep.methods.label}, 'Location', 'best');

nexttile;
hold on;
for methodIdx = 1:numel(highSnrSweep.methods)
    plot(highSnrSweep.trueAngleSetsDeg, highSnrSweep.methods(methodIdx).perTargetRmse, ...
        'o-', 'LineWidth', 1.4, 'MarkerSize', 5);
end
xline(stressExampleAngle, 'k--', 'Stress example');
grid on;
xlabel('True angle (deg)');
ylabel('DOA RMSE (deg)');
title('Case 1: high-SNR RMSE floor check');
legend({highSnrSweep.methods.label}, 'Location', 'best');
save_figure(fig, fullfile(outDir, 'high_snr_angle_bias.png'));

caseResult = struct();
caseResult.outputDir = outDir;
caseResult.metrics = metrics;
caseResult.contextDiagnostics = ctx.diagnostics;
caseResult.stressExampleAngleDeg = stressExampleAngle;
caseResult.exampleSelectionReason = exampleSelectionReason;
caseResult.stressScoreDeg = stressScore;
caseResult.exampleSpectrum = exampleSpectrum;
caseResult.highSnrSweep = highSnrSweep;
save(fullfile(outDir, 'case01_results.mat'), 'caseResult');
end

function caseResult = case02_dominant_mismatch(cfg, ctx)
rng(cfg.randomSeed + 2, 'twister');
outDir = local_case_output_dir(cfg, 'case02_dominant_mismatch');

amplitudeRatio = abs(ctx.AH) ./ max(abs(ctx.AI), eps);
phaseResidual = angle(ctx.AH .* conj(ctx.AI));

aPhaseOnly = local_normalize_columns(exp(1i * phaseResidual) .* ctx.AI);
aAmplitudeOnly = local_normalize_columns(amplitudeRatio .* ctx.AI);
aAmpPhase = local_normalize_columns(amplitudeRatio .* exp(1i * phaseResidual) .* ctx.AI);

metricsIdeal = compute_manifold_metrics(ctx.AH, ctx.AI);
metricsPhase = compute_manifold_metrics(ctx.AH, aPhaseOnly);
metricsAmplitude = compute_manifold_metrics(ctx.AH, aAmplitudeOnly);
metricsAmpPhase = compute_manifold_metrics(ctx.AH, aAmpPhase);

phaseEnergy = sum(abs(exp(1i * phaseResidual) - 1) .^ 2, 'all');
amplitudeEnergy = sum(abs(amplitudeRatio - 1) .^ 2, 'all');
energyShare = 100 * [phaseEnergy, amplitudeEnergy] / (phaseEnergy + amplitudeEnergy);

methods = [ ...
    local_method('ideal', 'Ideal', ctx.AI), ...
    local_method('phase_only', 'Phase-only', aPhaseOnly), ...
    local_method('amplitude_only', 'Amplitude-only', aAmplitudeOnly), ...
    local_method('amp_phase_oracle', 'Amp+Phase Oracle', aAmpPhase)];

evalCfg = struct();
evalCfg.mode = 'single';
evalCfg.trueAngles = local_single_source_eval_angles(ctx, [], cfg);
evalCfg.snrDb = cfg.case2.evalSNRDb;
evalCfg.snapshots = cfg.case2.snapshots;
evalCfg.monteCarlo = cfg.case2.monteCarlo;
evalCfg.toleranceDeg = cfg.case2.toleranceDeg;
evalCfg.collectRepresentativeSpectrum = false;
bench = benchmark_music(ctx, methods, evalCfg);

fig = figure('Visible', 'off', 'Position', [120 120 1300 480]);
tiledlayout(1, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
bar(energyShare);
grid on;
set(gca, 'XTickLabel', {'Phase', 'Amplitude'});
ylabel('Energy share (%)');
title('Case 2: mismatch energy share');

nexttile;
bar([ ...
    mean(metricsIdeal.relativeError), ...
    mean(metricsPhase.relativeError), ...
    mean(metricsAmplitude.relativeError), ...
    mean(metricsAmpPhase.relativeError)]);
grid on;
set(gca, 'XTickLabel', {'Ideal', 'Phase', 'Amplitude', 'Amp+Phase Oracle'});
ylabel('Mean manifold relative error');
title('Case 2: manifold approximation error');

nexttile;
bar(arrayfun(@(s) s.rmse, bench.methods));
grid on;
set(gca, 'XTickLabel', {bench.methods.label});
ylabel('Single-source DOA RMSE (deg)');
title(sprintf('Case 2: DOA RMSE at %g dB', cfg.case2.evalSNRDb));
xtickangle(20);
local_add_truth_scan_sgtitle('Case 2: mismatch dominance; Amp+Phase Oracle is a full-residual upper bound');
save_figure(fig, fullfile(outDir, 'mismatch_dominance.png'));

caseResult = struct();
caseResult.outputDir = outDir;
caseResult.energySharePercent = energyShare;
caseResult.manifoldMetrics = struct( ...
    'ideal', metricsIdeal, ...
    'phaseOnly', metricsPhase, ...
    'amplitudeOnly', metricsAmplitude, ...
    'ampPhase', metricsAmpPhase);
caseResult.oracleUpperBoundMethod = 'Amp+Phase Oracle uses the full HFSS-vs-ideal residual and is not a same-budget deployable baseline.';
caseResult.benchmark = bench;
save(fullfile(outDir, 'case02_results.mat'), 'caseResult');
end

function caseResult = case03_unseen_generalization(cfg, ctx)
rng(cfg.randomSeed + 3, 'twister');
outDir = local_case_output_dir(cfg, 'case03_unseen_generalization');

lValues = cfg.case3.lValues;
methodNames = {'Ideal', 'Interpolation', 'ARD', 'Proposed V1', 'Proposed V2', 'HFSS Oracle'};
meanUnseenError = zeros(numel(lValues), numel(methodNames));
edgeUnseenError = zeros(numel(lValues), numel(methodNames));
worst10UnseenError = zeros(numel(lValues), numel(methodNames));
storedModels = cell(1, numel(lValues));

for lIdx = 1:numel(lValues)
    calIdx = select_calibration_indices(ctx.thetaDeg, lValues(lIdx), 'uniform');
    storedModels{lIdx} = build_sparse_models(ctx, calIdx, cfg.model);
    models = storedModels{lIdx};

    metricsIdeal = compute_manifold_metrics(ctx.AH(:, models.testIdx), ctx.AI(:, models.testIdx));
    metricsInterp = compute_manifold_metrics(ctx.AH(:, models.testIdx), models.AInterp(:, models.testIdx));
    metricsARD = compute_manifold_metrics(ctx.AH(:, models.testIdx), models.AARD(:, models.testIdx));
    metricsProposedV1 = compute_manifold_metrics(ctx.AH(:, models.testIdx), models.AProposedV1(:, models.testIdx));
    metricsProposedV2 = compute_manifold_metrics(ctx.AH(:, models.testIdx), models.AProposedV2(:, models.testIdx));
    perMethodError = [ ...
        metricsIdeal.relativeError(:), ...
        metricsInterp.relativeError(:), ...
        metricsARD.relativeError(:), ...
        metricsProposedV1.relativeError(:), ...
        metricsProposedV2.relativeError(:), ...
        zeros(numel(models.testIdx), 1)];

    meanUnseenError(lIdx, :) = [ ...
        mean(metricsIdeal.relativeError), ...
        mean(metricsInterp.relativeError), ...
        mean(metricsARD.relativeError), ...
        mean(metricsProposedV1.relativeError), ...
        mean(metricsProposedV2.relativeError), ...
        0];
    edgeMask = abs(models.testAnglesDeg(:)) >= max(abs(ctx.thetaDeg)) - cfg.eval.edgeBandDeg;
    if ~any(edgeMask)
        edgeMask = true(numel(models.testIdx), 1);
    end
    [~, hardOrder] = sort(metricsIdeal.relativeError(:), 'descend');
    worstCount = max(1, ceil(0.10 * numel(hardOrder)));
    worstMask = false(numel(models.testIdx), 1);
    worstMask(hardOrder(1:worstCount)) = true;
    edgeUnseenError(lIdx, :) = mean(perMethodError(edgeMask, :), 1);
    worst10UnseenError(lIdx, :) = mean(perMethodError(worstMask, :), 1);
end

repL = cfg.case3.representativeL;
repMatch = find(lValues == repL, 1, 'first');
if isempty(repMatch)
    repCalIdx = select_calibration_indices(ctx.thetaDeg, repL, 'uniform');
    repModels = build_sparse_models(ctx, repCalIdx, cfg.model);
else
    repModels = storedModels{repMatch};
end

fig = figure('Visible', 'off', 'Position', [120 120 1050 500]);
hold on;
for methodIdx = 1:numel(methodNames)
    plot(lValues, meanUnseenError(:, methodIdx), 'o-', 'LineWidth', 1.5, 'MarkerSize', 7);
end
grid on;
xlabel('Number of calibration angles L');
ylabel('Mean unseen relative error');
title('Case 3: unseen-direction manifold generalization');
legend(methodNames, 'Location', 'best');
save_figure(fig, fullfile(outDir, 'unseen_error_vs_L.png'));

fig = figure('Visible', 'off', 'Position', [125 125 1250 520]);
tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
nexttile;
hold on;
for methodIdx = 1:numel(methodNames)
    plot(lValues, edgeUnseenError(:, methodIdx), 'o-', 'LineWidth', 1.5, 'MarkerSize', 7);
end
grid on;
xlabel('Number of calibration angles L');
ylabel('Mean edge-band unseen relative error');
title(sprintf('Case 3: edge-band error, |angle| >= %.1f deg', max(abs(ctx.thetaDeg)) - cfg.eval.edgeBandDeg));

nexttile;
hold on;
for methodIdx = 1:numel(methodNames)
    plot(lValues, worst10UnseenError(:, methodIdx), 'o-', 'LineWidth', 1.5, 'MarkerSize', 7);
end
grid on;
xlabel('Number of calibration angles L');
ylabel('Mean worst-10% unseen relative error');
title('Case 3: hardest unseen angles by Ideal mismatch');
legend(methodNames, 'Location', 'best');
save_figure(fig, fullfile(outDir, 'edge_and_hard_unseen_error.png'));

fig = figure('Visible', 'off', 'Position', [140 140 1200 700]);
tiledlayout(numel(cfg.case3.representativeElements), 1, 'Padding', 'compact', 'TileSpacing', 'compact');
for plotIdx = 1:numel(cfg.case3.representativeElements)
    elementIdx = cfg.case3.representativeElements(plotIdx);
    nexttile;
    hold on;
    plot(ctx.thetaDeg, rad2deg(repModels.phaseTruthFull(elementIdx, :)), 'k-', 'LineWidth', 1.6);
    plot(ctx.thetaDeg, rad2deg(repModels.phaseInterpFull(elementIdx, :)), '--', 'LineWidth', 1.4);
    plot(ctx.thetaDeg, rad2deg(repModels.phaseFitV1Full(elementIdx, :)), '-.', 'LineWidth', 1.4);
    plot(ctx.thetaDeg, rad2deg(repModels.phaseFitV2Full(elementIdx, :)), ':', 'LineWidth', 1.8);
    scatter(repModels.calAnglesDeg, rad2deg(repModels.phaseTruthFull(elementIdx, repModels.calIdx)), ...
        36, 'filled');
    grid on;
    ylabel(sprintf('Element %d (deg)', elementIdx));
    title(sprintf('Case 3: phase reconstruction for element %d', elementIdx));
end
xlabel('Angle (deg)');
legend({'HFSS truth', 'Interpolation', 'Proposed V1 fit', 'Proposed V2 fit', ...
    'Calibration samples'}, 'Location', 'eastoutside');
save_figure(fig, fullfile(outDir, 'phase_reconstruction.png'));

fig = figure('Visible', 'off', 'Position', [150 150 1250 820]);
numRepAngles = numel(cfg.case3.representativeAnglesDeg);
tiledlayout(numRepAngles, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

for angleIdx = 1:numRepAngles
    queryAngle = cfg.case3.representativeAnglesDeg(angleIdx);
    gridIdx = local_angle_index(ctx.thetaDeg, queryAngle);
    elemAxis = 1:ctx.numElements;

    nexttile;
    hold on;
    plot(elemAxis, abs(ctx.AH(:, gridIdx)), 'ko-', 'LineWidth', 1.4);
    plot(elemAxis, abs(ctx.AI(:, gridIdx)), 's-', 'LineWidth', 1.2);
    plot(elemAxis, abs(repModels.AInterp(:, gridIdx)), 'd--', 'LineWidth', 1.2);
    plot(elemAxis, abs(repModels.AARD(:, gridIdx)), 'x-', 'LineWidth', 1.2);
    plot(elemAxis, abs(repModels.AProposedV1(:, gridIdx)), '^-', 'LineWidth', 1.2);
    plot(elemAxis, abs(repModels.AProposedV2(:, gridIdx)), 'v-', 'LineWidth', 1.4);
    grid on;
    xlabel('Element index');
    ylabel('Magnitude');
    title(sprintf('Magnitude at %.1f deg', queryAngle));

    nexttile;
    hold on;
    plot(elemAxis, rad2deg(unwrap(angle(ctx.AH(:, gridIdx)))), 'ko-', 'LineWidth', 1.4);
    plot(elemAxis, rad2deg(unwrap(angle(ctx.AI(:, gridIdx)))), 's-', 'LineWidth', 1.2);
    plot(elemAxis, rad2deg(unwrap(angle(repModels.AInterp(:, gridIdx)))), 'd--', 'LineWidth', 1.2);
    plot(elemAxis, rad2deg(unwrap(angle(repModels.AARD(:, gridIdx)))), 'x-', 'LineWidth', 1.2);
    plot(elemAxis, rad2deg(unwrap(angle(repModels.AProposedV1(:, gridIdx)))), '^-', 'LineWidth', 1.2);
    plot(elemAxis, rad2deg(unwrap(angle(repModels.AProposedV2(:, gridIdx)))), 'v-', 'LineWidth', 1.4);
    grid on;
    xlabel('Element index');
    ylabel('Phase (deg)');
    title(sprintf('Phase at %.1f deg', queryAngle));
end
legend({'HFSS truth', 'Ideal', 'Interpolation', 'ARD', 'Proposed V1', 'Proposed V2'}, ...
    'Location', 'eastoutside');
save_figure(fig, fullfile(outDir, 'steering_vector_comparison.png'));

caseResult = struct();
caseResult.outputDir = outDir;
caseResult.methodLabels = methodNames;
caseResult.lValues = lValues;
caseResult.meanUnseenError = meanUnseenError;
caseResult.edgeUnseenError = edgeUnseenError;
caseResult.worst10UnseenError = worst10UnseenError;
caseResult.representativeModels = repModels;
save(fullfile(outDir, 'case03_results.mat'), 'caseResult');
end

function caseResult = case04_calibration_count_sensitivity(cfg, ctx)
rng(cfg.randomSeed + 4, 'twister');
outDir = local_case_output_dir(cfg, 'case04_calibration_count_sensitivity');

lValues = cfg.case4.lValues;
methodKeys = {'ideal', 'interp', 'ard', 'proposed_v1', 'proposed_v2', 'oracle'};
methodsLegend = {'Ideal', 'Interpolation', 'ARD', 'Proposed V1', 'Proposed V2', 'HFSS Oracle'};

manifoldError = zeros(numel(lValues), numel(methodKeys));
singleRmse = zeros(numel(lValues), numel(methodKeys));
resolutionProb = zeros(numel(lValues), numel(methodKeys));
stableRate = zeros(numel(lValues), numel(methodKeys));
biasedRate = zeros(numel(lValues), numel(methodKeys));
marginalRate = zeros(numel(lValues), numel(methodKeys));
unresolvedRate = zeros(numel(lValues), numel(methodKeys));
sourcePairCount = zeros(numel(lValues), 1);
perL = cell(1, numel(lValues));

[commonSingleAngles, commonSourcePairs, commonPairSelection, commonExcludedAngles] = ...
    local_case4_common_test_set(cfg.case4, ctx, lValues, cfg);
useCommonTestSet = isfield(cfg.case4, 'useCommonTestSet') && cfg.case4.useCommonTestSet;

for lIdx = 1:numel(lValues)
    fprintf('Case 4: L = %d\n', lValues(lIdx));
    calIdx = select_calibration_indices(ctx.thetaDeg, lValues(lIdx), 'uniform');
    models = build_sparse_models(ctx, calIdx, cfg.model);
    perL{lIdx}.models = models;

    metricsIdeal = compute_manifold_metrics(ctx.AH(:, models.testIdx), ctx.AI(:, models.testIdx));
    metricsInterp = compute_manifold_metrics(ctx.AH(:, models.testIdx), models.AInterp(:, models.testIdx));
    metricsARD = compute_manifold_metrics(ctx.AH(:, models.testIdx), models.AARD(:, models.testIdx));
    metricsProposedV1 = compute_manifold_metrics(ctx.AH(:, models.testIdx), models.AProposedV1(:, models.testIdx));
    metricsProposedV2 = compute_manifold_metrics(ctx.AH(:, models.testIdx), models.AProposedV2(:, models.testIdx));
    manifoldError(lIdx, :) = [ ...
        mean(metricsIdeal.relativeError), ...
        mean(metricsInterp.relativeError), ...
        mean(metricsARD.relativeError), ...
        mean(metricsProposedV1.relativeError), ...
        mean(metricsProposedV2.relativeError), ...
        0];

    methods = local_named_methods(ctx, models, methodKeys);
    evalCfg = struct();
    evalCfg.mode = 'single';
    if useCommonTestSet
        evalCfg.trueAngles = commonSingleAngles;
    else
        evalCfg.trueAngles = local_single_source_eval_angles(ctx, models, cfg);
    end
    evalCfg.snrDb = cfg.case4.evalSNRDb;
    evalCfg.snapshots = cfg.case4.snapshots;
    evalCfg.monteCarlo = cfg.case4.monteCarlo;
    evalCfg.toleranceDeg = cfg.case4.toleranceDeg;
    evalCfg.collectRepresentativeSpectrum = false;
    singleBench = benchmark_music(ctx, methods, evalCfg);

    for methodIdx = 1:numel(methodKeys)
        singleRmse(lIdx, methodIdx) = singleBench.methods(methodIdx).rmse;
    end
    perL{lIdx}.singleBenchmark = singleBench;

    if useCommonTestSet
        validPairs = commonSourcePairs;
        pairSelection = commonPairSelection;
    else
        [validPairs, pairSelection] = local_case4_source_pairs(cfg.case4, ctx, models.calAnglesDeg);
    end
    evalCfg.mode = 'double';
    evalCfg.trueAngles = validPairs;
    doubleBench = benchmark_music(ctx, methods, evalCfg);
    for methodIdx = 1:numel(methodKeys)
        resolutionProb(lIdx, methodIdx) = doubleBench.methods(methodIdx).successRate;
        stableRate(lIdx, methodIdx) = doubleBench.methods(methodIdx).stableRate;
        biasedRate(lIdx, methodIdx) = doubleBench.methods(methodIdx).biasedRate;
        marginalRate(lIdx, methodIdx) = doubleBench.methods(methodIdx).marginalRate;
        unresolvedRate(lIdx, methodIdx) = 1 - doubleBench.methods(methodIdx).resolutionRate;
    end
    sourcePairCount(lIdx) = size(validPairs, 1);
    perL{lIdx}.sourcePairsDeg = validPairs;
    perL{lIdx}.pairSelection = pairSelection;
    perL{lIdx}.doubleBenchmark = doubleBench;
end

fig = figure('Visible', 'off', 'Position', [100 80 1450 780]);
tiledlayout(2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
hold on;
for methodIdx = 1:numel(methodKeys)
    plot(lValues, manifoldError(:, methodIdx), 'o-', 'LineWidth', 1.5, 'MarkerSize', 7);
end
grid on;
xlabel('Calibration count L');
ylabel('Mean unseen relative error');
title('Case 4: manifold error vs L');

nexttile;
hold on;
for methodIdx = 1:numel(methodKeys)
    plot(lValues, singleRmse(:, methodIdx), 'o-', 'LineWidth', 1.5, 'MarkerSize', 7);
end
grid on;
xlabel('Calibration count L');
ylabel('Single-source DOA RMSE (deg)');
title(sprintf('Case 4: DOA RMSE vs L at %g dB', cfg.case4.evalSNRDb));

nexttile;
hold on;
local_plot_case4_state_metric(lValues, stableRate, methodsLegend, 'Stable rate');
title('Case 4: stable');

nexttile;
local_plot_case4_state_metric(lValues, biasedRate, methodsLegend, 'Biased rate');
title('Case 4: biased');

nexttile;
local_plot_case4_state_metric(lValues, marginalRate, methodsLegend, 'Marginal rate');
title('Case 4: marginal');

nexttile;
local_plot_case4_state_metric(lValues, unresolvedRate, methodsLegend, 'Unresolved rate');
title('Case 4: unresolved');
legend(methodsLegend, 'Location', 'best');
save_figure(fig, fullfile(outDir, 'calibration_count_sensitivity.png'));

caseResult = struct();
caseResult.outputDir = outDir;
caseResult.methodLabels = methodsLegend;
caseResult.lValues = lValues;
caseResult.manifoldError = manifoldError;
caseResult.singleRmse = singleRmse;
caseResult.resolutionProb = resolutionProb;
caseResult.stableRate = stableRate;
caseResult.biasedRate = biasedRate;
caseResult.marginalRate = marginalRate;
caseResult.unresolvedRate = unresolvedRate;
caseResult.sourcePairCount = sourcePairCount;
caseResult.commonSingleAnglesDeg = commonSingleAngles;
caseResult.commonSourcePairsDeg = commonSourcePairs;
caseResult.commonPairSelection = commonPairSelection;
caseResult.commonExcludedCalibrationAnglesDeg = commonExcludedAngles;
caseResult.useCommonTestSet = useCommonTestSet;
caseResult.perL = perL;
save(fullfile(outDir, 'case04_results.mat'), 'caseResult');
end

function local_plot_case4_state_metric(lValues, metricMatrix, methodsLegend, yLabelText)
hold on;
for methodIdx = 1:numel(methodsLegend)
    plot(lValues, metricMatrix(:, methodIdx), 'o-', 'LineWidth', 1.5, 'MarkerSize', 7);
end
grid on;
ylim([0 1]);
xlabel('Calibration count L');
ylabel(yLabelText);
end

function caseResult = case05_sampling_strategy_sensitivity(cfg, ctx)
rng(cfg.randomSeed + 5, 'twister');
outDir = local_case_output_dir(cfg, 'case05_sampling_strategy_sensitivity');

strategyNames = cfg.case5.strategyNames;
snrSweep = cfg.case5.snrSweepDb;
methodKeys = {'ard', 'proposed_v1', 'proposed_v2'};
methodLabels = {'ARD', 'Proposed V1', 'Proposed V2'};
numMethods = numel(methodKeys);

meanUnseenError = zeros(numel(strategyNames), numMethods);
stdUnseenError = zeros(numel(strategyNames), numMethods);
meanRmse = zeros(numel(strategyNames), numel(snrSweep), numMethods);
stdRmse = zeros(numel(strategyNames), numel(snrSweep), numMethods);
details = cell(1, numel(strategyNames));

for strategyIdx = 1:numel(strategyNames)
    strategyName = strategyNames{strategyIdx};
    fprintf('Case 5: strategy = %s\n', strategyName);
    if strcmpi(strategyName, 'random')
        numTrials = cfg.case5.randomTrials;
    else
        numTrials = 1;
    end

    unseenTrials = zeros(numTrials, numMethods);
    rmseTrials = zeros(numTrials, numel(snrSweep), numMethods);
    details{strategyIdx} = cell(numTrials, 1);

    for trialIdx = 1:numTrials
        seed = cfg.randomSeed + 500 + strategyIdx * 100 + trialIdx;
        calIdx = select_calibration_indices(ctx.thetaDeg, cfg.case5.l, strategyName, seed);
        models = build_sparse_models(ctx, calIdx, cfg.model);

        metricsProposedV1 = compute_manifold_metrics( ...
            ctx.AH(:, models.testIdx), models.AProposedV1(:, models.testIdx));
        metricsProposedV2 = compute_manifold_metrics( ...
            ctx.AH(:, models.testIdx), models.AProposedV2(:, models.testIdx));
        metricsARD = compute_manifold_metrics( ...
            ctx.AH(:, models.testIdx), models.AARD(:, models.testIdx));
        unseenTrials(trialIdx, :) = [ ...
            mean(metricsARD.relativeError), ...
            mean(metricsProposedV1.relativeError), ...
            mean(metricsProposedV2.relativeError)];

        methods = local_named_methods(ctx, models, methodKeys);
        for snrIdx = 1:numel(snrSweep)
            rng(cfg.randomSeed + 900 + strategyIdx * 100 + trialIdx * 10 + snrIdx, 'twister');
            evalCfg = struct();
            evalCfg.mode = 'single';
            evalCfg.trueAngles = local_single_source_eval_angles(ctx, models, cfg);
            evalCfg.snrDb = snrSweep(snrIdx);
            evalCfg.snapshots = cfg.case5.snapshots;
            evalCfg.monteCarlo = cfg.case5.monteCarlo;
            evalCfg.toleranceDeg = cfg.case5.toleranceDeg;
            evalCfg.collectRepresentativeSpectrum = false;
            bench = benchmark_music(ctx, methods, evalCfg);
            for methodIdx = 1:numMethods
                rmseTrials(trialIdx, snrIdx, methodIdx) = bench.methods(methodIdx).rmse;
            end
            details{strategyIdx}{trialIdx}.(['snr_' strrep(num2str(snrSweep(snrIdx)), '-', 'm')]) = bench;
        end
    end

    meanUnseenError(strategyIdx, :) = mean(unseenTrials, 1);
    stdUnseenError(strategyIdx, :) = std(unseenTrials, 0, 1);
    meanRmse(strategyIdx, :, :) = mean(rmseTrials, 1);
    stdRmse(strategyIdx, :, :) = std(rmseTrials, 0, 1);
    details{strategyIdx} = struct('unseenTrials', unseenTrials, 'rmseTrials', rmseTrials);
end

fig = figure('Visible', 'off', 'Position', [140 140 1450 520]);
tiledlayout(1, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
bar(meanUnseenError);
hold on;
numStrategies = numel(strategyNames);
groupWidth = min(0.8, numMethods / (numMethods + 1.5));
for methodIdx = 1:numMethods
    x = (1:numStrategies) - groupWidth / 2 + ...
        (2 * methodIdx - 1) * groupWidth / (2 * numMethods);
    errorbar(x, meanUnseenError(:, methodIdx), stdUnseenError(:, methodIdx), ...
        '.k', 'LineWidth', 1.0);
end
grid on;
set(gca, 'XTick', 1:numel(strategyNames), 'XTickLabel', strategyNames);
xtickangle(20);
ylabel('Mean unseen relative error');
title(sprintf('Case 5: sampling strategy, L = %d', cfg.case5.l));
legend(methodLabels, 'Location', 'best');

nexttile;
hold on;
for strategyIdx = 1:numel(strategyNames)
    errorbar(snrSweep, meanRmse(strategyIdx, :, 1), stdRmse(strategyIdx, :, 1), ...
        'o-', 'LineWidth', 1.4, 'MarkerSize', 6);
end
grid on;
xlabel('SNR (dB)');
ylabel('DOA RMSE (deg)');
title('Case 5: ARD DOA RMSE');
legend(strategyNames, 'Location', 'best');

nexttile;
hold on;
for strategyIdx = 1:numel(strategyNames)
    errorbar(snrSweep, meanRmse(strategyIdx, :, 3), stdRmse(strategyIdx, :, 3), ...
        'o-', 'LineWidth', 1.4, 'MarkerSize', 6);
end
grid on;
xlabel('SNR (dB)');
ylabel('DOA RMSE (deg)');
title('Case 5: Proposed V2 DOA RMSE');
legend(strategyNames, 'Location', 'best');
save_figure(fig, fullfile(outDir, 'sampling_strategy_sensitivity.png'));

caseResult = struct();
caseResult.outputDir = outDir;
caseResult.strategyNames = strategyNames;
caseResult.methodLabels = methodLabels;
caseResult.meanUnseenError = meanUnseenError;
caseResult.stdUnseenError = stdUnseenError;
caseResult.meanRmse = meanRmse;
caseResult.stdRmse = stdRmse;
caseResult.details = details;
save(fullfile(outDir, 'case05_results.mat'), 'caseResult');
end

function caseResult = case06_model_sensitivity(cfg, ctx)
rng(cfg.randomSeed + 6, 'twister');
outDir = local_case_output_dir(cfg, 'case06_model_sensitivity');

calIdx = select_calibration_indices(ctx.thetaDeg, cfg.case6.l, 'uniform');
lambdaSingleValues = cfg.case6.lambdaSingleValues;
lambdaPairValues = cfg.case6.lambdaPairValues;
lambdaMidValues = cfg.case6.lambdaMidValues;
taskPairCounts = cfg.case6.taskPairCounts;

baseModels = build_sparse_models(ctx, calIdx, cfg.model);
metricsV1 = compute_manifold_metrics(ctx.AH(:, baseModels.testIdx), baseModels.AProposedV1(:, baseModels.testIdx));
v1ReferenceError = mean(metricsV1.relativeError);

errorCubeV2 = zeros(numel(lambdaSingleValues), numel(lambdaPairValues), ...
    numel(lambdaMidValues), numel(taskPairCounts));
objectiveInitial = zeros(size(errorCubeV2));
objectiveFinal = zeros(size(errorCubeV2));

for singleIdx = 1:numel(lambdaSingleValues)
    for pairIdx = 1:numel(lambdaPairValues)
        for midIdx = 1:numel(lambdaMidValues)
            for countIdx = 1:numel(taskPairCounts)
                modelCfg = cfg.model;
                modelCfg.v2.lambdaSingle = lambdaSingleValues(singleIdx);
                modelCfg.v2.lambdaPair = lambdaPairValues(pairIdx);
                modelCfg.v2.lambdaMid = lambdaMidValues(midIdx);
                modelCfg.v2.taskPairCount = taskPairCounts(countIdx);
                modelCfg.v2.numSpsaIterations = cfg.case6.case6V2Iterations;
                models = build_sparse_models(ctx, calIdx, modelCfg);
                metricsV2 = compute_manifold_metrics( ...
                    ctx.AH(:, models.testIdx), models.AProposedV2(:, models.testIdx));
                errorCubeV2(singleIdx, pairIdx, midIdx, countIdx) = mean(metricsV2.relativeError);
                objectiveInitial(singleIdx, pairIdx, midIdx, countIdx) = models.v2Diagnostics.initialObjective;
                objectiveFinal(singleIdx, pairIdx, midIdx, countIdx) = models.v2Diagnostics.finalObjective;
            end
        end
    end
end

bestByTaskPairCount = zeros(numel(taskPairCounts), 1);
for countIdx = 1:numel(taskPairCounts)
    slice = errorCubeV2(:, :, :, countIdx);
    bestByTaskPairCount(countIdx) = min(slice(:));
end
singlePairBest = squeeze(min(min(errorCubeV2, [], 4), [], 3));
pairMidBest = squeeze(min(min(errorCubeV2, [], 4), [], 1));

fig = figure('Visible', 'off', 'Position', [120 100 1350 780]);
tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
bar([v1ReferenceError, min(errorCubeV2(:))]);
grid on;
set(gca, 'XTickLabel', {'Proposed V1', 'Best Full V2'});
ylabel('Mean unseen relative error');
title(sprintf('Case 6: V1 reference vs Full V2, L = %d', cfg.case6.l));

nexttile;
plot(taskPairCounts, bestByTaskPairCount, 'o-', 'LineWidth', 1.5, 'MarkerSize', 7);
grid on;
xlabel('Held-out task pair count');
ylabel('Best Full V2 unseen error');
title('Case 6: task pair count sensitivity');

nexttile;
imagesc(singlePairBest);
colorbar;
set(gca, 'XTick', 1:numel(lambdaPairValues), ...
    'XTickLabel', arrayfun(@num2str, lambdaPairValues, 'UniformOutput', false), ...
    'YTick', 1:numel(lambdaSingleValues), ...
    'YTickLabel', arrayfun(@num2str, lambdaSingleValues, 'UniformOutput', false));
xlabel('\lambda_{pair}');
ylabel('\lambda_{single}');
title('Best over \lambda_{mid} and task pair count');

nexttile;
imagesc(pairMidBest);
colorbar;
set(gca, 'XTick', 1:numel(lambdaMidValues), ...
    'XTickLabel', arrayfun(@num2str, lambdaMidValues, 'UniformOutput', false), ...
    'YTick', 1:numel(lambdaPairValues), ...
    'YTickLabel', arrayfun(@num2str, lambdaPairValues, 'UniformOutput', false));
xlabel('\lambda_{mid}');
ylabel('\lambda_{pair}');
title('Best over \lambda_{single} and task pair count');
save_figure(fig, fullfile(outDir, 'model_sensitivity.png'));

caseResult = struct();
caseResult.outputDir = outDir;
caseResult.methodLabels = {'Proposed V1', 'Full Proposed V2'};
caseResult.lambdaSingleValues = lambdaSingleValues;
caseResult.lambdaPairValues = lambdaPairValues;
caseResult.lambdaMidValues = lambdaMidValues;
caseResult.taskPairCounts = taskPairCounts;
caseResult.case6V2Iterations = cfg.case6.case6V2Iterations;
caseResult.v1ReferenceError = v1ReferenceError;
caseResult.errorCube = errorCubeV2;
caseResult.errorCubeV2 = errorCubeV2;
caseResult.objectiveInitial = objectiveInitial;
caseResult.objectiveFinal = objectiveFinal;
caseResult.bestByTaskPairCount = bestByTaskPairCount;
save(fullfile(outDir, 'case06_results.mat'), 'caseResult');
end

function caseResult = case07_single_source_snr(cfg, ctx)
rng(cfg.randomSeed + 7, 'twister');
outDir = local_case_output_dir(cfg, 'case07_single_source_snr');

calIdx = select_calibration_indices(ctx.thetaDeg, cfg.case3.representativeL, 'uniform');
models = build_sparse_models(ctx, calIdx, cfg.model);
methods = local_named_methods(ctx, models, {'ideal', 'interp', 'ard', 'proposed_v1', 'proposed_v2', 'oracle'});
snrSweep = cfg.case7.snrSweepDb;
evalAngles = local_single_source_eval_angles(ctx, models, cfg);
evalSubsets = local_doa_eval_subsets(ctx, evalAngles, cfg);

rmse = zeros(numel(snrSweep), numel(methods));
successRate = zeros(numel(snrSweep), numel(methods));
meanAbsBias = zeros(numel(snrSweep), numel(methods));
p90AbsError = zeros(numel(snrSweep), numel(methods));
edgeRmse = zeros(numel(snrSweep), numel(methods));
edgeMeanAbsBias = zeros(numel(snrSweep), numel(methods));
edgeP90AbsError = zeros(numel(snrSweep), numel(methods));
hardRmse = zeros(numel(snrSweep), numel(methods));
hardMeanAbsBias = zeros(numel(snrSweep), numel(methods));
hardP90AbsError = zeros(numel(snrSweep), numel(methods));
details = cell(1, numel(snrSweep));

for snrIdx = 1:numel(snrSweep)
    fprintf('Case 7: SNR = %g dB\n', snrSweep(snrIdx));
    evalCfg = struct();
    evalCfg.mode = 'single';
    evalCfg.trueAngles = evalAngles;
    evalCfg.snrDb = snrSweep(snrIdx);
    evalCfg.snapshots = cfg.case7.snapshots;
    evalCfg.monteCarlo = cfg.case7.monteCarlo;
    evalCfg.toleranceDeg = cfg.case7.toleranceDeg;
    evalCfg.collectRepresentativeSpectrum = false;
    bench = benchmark_music(ctx, methods, evalCfg);
    details{snrIdx} = bench;
    for methodIdx = 1:numel(methods)
        rmse(snrIdx, methodIdx) = bench.methods(methodIdx).rmse;
        successRate(snrIdx, methodIdx) = bench.methods(methodIdx).successRate;
        meanAbsBias(snrIdx, methodIdx) = mean(bench.methods(methodIdx).perTargetAbsBias);
        p90AbsError(snrIdx, methodIdx) = bench.methods(methodIdx).p90AbsError;
        edgeRmse(snrIdx, methodIdx) = mean(bench.methods(methodIdx).perTargetRmse(evalSubsets.edgeMask));
        edgeMeanAbsBias(snrIdx, methodIdx) = mean(bench.methods(methodIdx).perTargetAbsBias(evalSubsets.edgeMask));
        edgeP90AbsError(snrIdx, methodIdx) = mean(bench.methods(methodIdx).perTargetP90AbsError(evalSubsets.edgeMask));
        hardRmse(snrIdx, methodIdx) = mean(bench.methods(methodIdx).perTargetRmse(evalSubsets.highMismatchMask));
        hardMeanAbsBias(snrIdx, methodIdx) = mean(bench.methods(methodIdx).perTargetAbsBias(evalSubsets.highMismatchMask));
        hardP90AbsError(snrIdx, methodIdx) = mean(bench.methods(methodIdx).perTargetP90AbsError(evalSubsets.highMismatchMask));
    end
end

fig = figure('Visible', 'off', 'Position', [130 130 1280 840]);
tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
hold on;
for methodIdx = 1:numel(methods)
    plot(snrSweep, rmse(:, methodIdx), 'o-', 'LineWidth', 1.5, 'MarkerSize', 7);
end
grid on;
xlabel('SNR (dB)');
ylabel('RMSE (deg)');
title('Case 7: single-source RMSE vs SNR');

nexttile;
hold on;
for methodIdx = 1:numel(methods)
    plot(snrSweep, successRate(:, methodIdx), 'o-', 'LineWidth', 1.5, 'MarkerSize', 7);
end
grid on;
ylim([0 1]);
xlabel('SNR (dB)');
ylabel('Success rate');
title(sprintf('Case 7: success rate vs SNR (%.1f deg)', cfg.case7.toleranceDeg));

nexttile;
hold on;
for methodIdx = 1:numel(methods)
    plot(snrSweep, meanAbsBias(:, methodIdx), 'o-', 'LineWidth', 1.5, 'MarkerSize', 7);
end
grid on;
xlabel('SNR (dB)');
ylabel('Mean absolute bias (deg)');
title('Case 7: bias floor vs SNR');

nexttile;
hold on;
for methodIdx = 1:numel(methods)
    plot(snrSweep, p90AbsError(:, methodIdx), 'o-', 'LineWidth', 1.5, 'MarkerSize', 7);
end
grid on;
xlabel('SNR (dB)');
ylabel('P90 absolute error (deg)');
title('Case 7: tail error vs SNR');
legend({methods.label}, 'Location', 'best');
local_add_truth_scan_sgtitle('Case 7: single-source SNR sweep');
save_figure(fig, fullfile(outDir, 'rmse_and_success_vs_snr.png'));

fig = figure('Visible', 'off', 'Position', [135 135 1280 840]);
tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
nexttile;
local_plot_method_curves(snrSweep, edgeMeanAbsBias, methods, 'SNR (dB)', ...
    'Mean absolute bias (deg)', 'Case 7: edge-band bias vs SNR');
nexttile;
local_plot_method_curves(snrSweep, hardMeanAbsBias, methods, 'SNR (dB)', ...
    'Mean absolute bias (deg)', 'Case 7: high-mismatch bias vs SNR');
nexttile;
local_plot_method_curves(snrSweep, edgeP90AbsError, methods, 'SNR (dB)', ...
    'Mean P90 absolute error (deg)', 'Case 7: edge-band tail error');
nexttile;
local_plot_method_curves(snrSweep, hardP90AbsError, methods, 'SNR (dB)', ...
    'Mean P90 absolute error (deg)', 'Case 7: high-mismatch tail error');
legend({methods.label}, 'Location', 'best');
local_add_truth_scan_sgtitle('Case 7: task-relevant edge/high-mismatch subsets');
save_figure(fig, fullfile(outDir, 'edge_hard_metrics_vs_snr.png'));

[exampleAngle, exampleSelectionReason] = local_case7_example_angle(ctx, models, evalAngles, cfg.case7);

fig = figure('Visible', 'off', 'Position', [150 150 1200 760]);
tiledlayout(numel(cfg.case7.spectrumSnrDb), 1, 'Padding', 'compact', 'TileSpacing', 'compact');
for snrIdx = 1:numel(cfg.case7.spectrumSnrDb)
    evalCfg = struct();
    evalCfg.mode = 'single';
    evalCfg.trueAngles = exampleAngle;
    evalCfg.snrDb = cfg.case7.spectrumSnrDb(snrIdx);
    evalCfg.snapshots = cfg.case7.snapshots;
    evalCfg.monteCarlo = 1;
    evalCfg.toleranceDeg = cfg.case7.toleranceDeg;
    evalCfg.collectRepresentativeSpectrum = true;
    spectrumBench = benchmark_music(ctx, methods, evalCfg);

    nexttile;
    hold on;
    for methodIdx = 1:numel(methods)
        plot(ctx.thetaDeg, 10 * log10(spectrumBench.methods(methodIdx).representativeSpectrum), ...
            'LineWidth', 1.4);
    end
    grid on;
    xlabel('Scan angle (deg)');
    ylabel('Pseudo-spectrum (dB)');
    title(sprintf('Case 7: example spectrum, true angle = %.1f deg, SNR = %g dB', ...
        exampleAngle, cfg.case7.spectrumSnrDb(snrIdx)));
end
legend({methods.label}, 'Location', 'eastoutside');
local_add_truth_scan_sgtitle(sprintf('Case 7: representative spectra; %s', exampleSelectionReason));
save_figure(fig, fullfile(outDir, 'representative_spectra.png'));

caseResult = struct();
caseResult.outputDir = outDir;
caseResult.models = models;
caseResult.methodLabels = {methods.label};
caseResult.evalAnglesDeg = evalAngles;
caseResult.snrSweep = snrSweep;
caseResult.rmse = rmse;
caseResult.successRate = successRate;
caseResult.meanAbsBias = meanAbsBias;
caseResult.p90AbsError = p90AbsError;
caseResult.evalSubsets = evalSubsets;
caseResult.edgeRmse = edgeRmse;
caseResult.edgeMeanAbsBias = edgeMeanAbsBias;
caseResult.edgeP90AbsError = edgeP90AbsError;
caseResult.highMismatchRmse = hardRmse;
caseResult.highMismatchMeanAbsBias = hardMeanAbsBias;
caseResult.highMismatchP90AbsError = hardP90AbsError;
caseResult.exampleAngleDeg = exampleAngle;
caseResult.exampleSelectionReason = exampleSelectionReason;
caseResult.details = details;
save(fullfile(outDir, 'case07_results.mat'), 'caseResult');
end

function caseResult = case08_single_source_snapshots(cfg, ctx)
rng(cfg.randomSeed + 8, 'twister');
outDir = local_case_output_dir(cfg, 'case08_single_source_snapshots');

calIdx = select_calibration_indices(ctx.thetaDeg, cfg.case3.representativeL, 'uniform');
models = build_sparse_models(ctx, calIdx, cfg.model);
methods = local_named_methods(ctx, models, {'ideal', 'interp', 'ard', 'proposed_v1', 'proposed_v2', 'oracle'});
evalAngles = local_single_source_eval_angles(ctx, models, cfg);
evalSubsets = local_doa_eval_subsets(ctx, evalAngles, cfg);

snapshotSweep = cfg.case8.snapshotSweep;
snrValues = cfg.case8.snrValuesDb;
rmse = zeros(numel(snapshotSweep), numel(methods), numel(snrValues));
meanAbsBias = zeros(numel(snapshotSweep), numel(methods), numel(snrValues));
p90AbsError = zeros(numel(snapshotSweep), numel(methods), numel(snrValues));
edgeRmse = zeros(numel(snapshotSweep), numel(methods), numel(snrValues));
edgeMeanAbsBias = zeros(numel(snapshotSweep), numel(methods), numel(snrValues));
edgeP90AbsError = zeros(numel(snapshotSweep), numel(methods), numel(snrValues));
hardRmse = zeros(numel(snapshotSweep), numel(methods), numel(snrValues));
hardMeanAbsBias = zeros(numel(snapshotSweep), numel(methods), numel(snrValues));
hardP90AbsError = zeros(numel(snapshotSweep), numel(methods), numel(snrValues));
details = cell(numel(snrValues), numel(snapshotSweep));

for snrIdx = 1:numel(snrValues)
    for snapIdx = 1:numel(snapshotSweep)
        fprintf('Case 8: SNR = %g dB, snapshots = %d\n', snrValues(snrIdx), snapshotSweep(snapIdx));
        evalCfg = struct();
        evalCfg.mode = 'single';
        evalCfg.trueAngles = evalAngles;
        evalCfg.snrDb = snrValues(snrIdx);
        evalCfg.snapshots = snapshotSweep(snapIdx);
        evalCfg.monteCarlo = cfg.case8.monteCarlo;
        evalCfg.toleranceDeg = cfg.case8.toleranceDeg;
        evalCfg.collectRepresentativeSpectrum = false;
        bench = benchmark_music(ctx, methods, evalCfg);
        details{snrIdx, snapIdx} = bench;
        for methodIdx = 1:numel(methods)
            rmse(snapIdx, methodIdx, snrIdx) = bench.methods(methodIdx).rmse;
            meanAbsBias(snapIdx, methodIdx, snrIdx) = mean(bench.methods(methodIdx).perTargetAbsBias);
            p90AbsError(snapIdx, methodIdx, snrIdx) = bench.methods(methodIdx).p90AbsError;
            edgeRmse(snapIdx, methodIdx, snrIdx) = mean(bench.methods(methodIdx).perTargetRmse(evalSubsets.edgeMask));
            edgeMeanAbsBias(snapIdx, methodIdx, snrIdx) = ...
                mean(bench.methods(methodIdx).perTargetAbsBias(evalSubsets.edgeMask));
            edgeP90AbsError(snapIdx, methodIdx, snrIdx) = ...
                mean(bench.methods(methodIdx).perTargetP90AbsError(evalSubsets.edgeMask));
            hardRmse(snapIdx, methodIdx, snrIdx) = ...
                mean(bench.methods(methodIdx).perTargetRmse(evalSubsets.highMismatchMask));
            hardMeanAbsBias(snapIdx, methodIdx, snrIdx) = ...
                mean(bench.methods(methodIdx).perTargetAbsBias(evalSubsets.highMismatchMask));
            hardP90AbsError(snapIdx, methodIdx, snrIdx) = ...
                mean(bench.methods(methodIdx).perTargetP90AbsError(evalSubsets.highMismatchMask));
        end
    end
end

fig = figure('Visible', 'off', 'Position', [140 140 1380 820]);
tiledlayout(numel(snrValues), 3, 'Padding', 'compact', 'TileSpacing', 'compact');

for snrIdx = 1:numel(snrValues)
    nexttile;
    hold on;
    for methodIdx = 1:numel(methods)
        plot(snapshotSweep, rmse(:, methodIdx, snrIdx), 'o-', 'LineWidth', 1.5, 'MarkerSize', 7);
    end
    grid on;
    xlabel('Snapshots');
    ylabel('RMSE (deg)');
    title(sprintf('Case 8: RMSE, SNR = %g dB', snrValues(snrIdx)));

    nexttile;
    hold on;
    for methodIdx = 1:numel(methods)
        plot(snapshotSweep, meanAbsBias(:, methodIdx, snrIdx), 'o-', 'LineWidth', 1.5, 'MarkerSize', 7);
    end
    grid on;
    xlabel('Snapshots');
    ylabel('Mean absolute bias (deg)');
    title(sprintf('Case 8: bias floor, SNR = %g dB', snrValues(snrIdx)));

    nexttile;
    hold on;
    for methodIdx = 1:numel(methods)
        plot(snapshotSweep, p90AbsError(:, methodIdx, snrIdx), 'o-', 'LineWidth', 1.5, 'MarkerSize', 7);
    end
    grid on;
    xlabel('Snapshots');
    ylabel('P90 absolute error (deg)');
    title(sprintf('Case 8: tail error, SNR = %g dB', snrValues(snrIdx)));
end
legend({methods.label}, 'Location', 'eastoutside');
local_add_truth_scan_sgtitle('Case 8: snapshots reduce variance; estimator-manifold bias can remain');
save_figure(fig, fullfile(outDir, 'rmse_vs_snapshots.png'));

fig = figure('Visible', 'off', 'Position', [145 145 1380 820]);
tiledlayout(numel(snrValues), 2, 'Padding', 'compact', 'TileSpacing', 'compact');
for snrIdx = 1:numel(snrValues)
    nexttile;
    local_plot_method_curves(snapshotSweep, edgeMeanAbsBias(:, :, snrIdx), methods, ...
        'Snapshots', 'Mean absolute bias (deg)', ...
        sprintf('Case 8: edge-band bias, SNR = %g dB', snrValues(snrIdx)));
    nexttile;
    local_plot_method_curves(snapshotSweep, hardMeanAbsBias(:, :, snrIdx), methods, ...
        'Snapshots', 'Mean absolute bias (deg)', ...
        sprintf('Case 8: high-mismatch bias, SNR = %g dB', snrValues(snrIdx)));
end
legend({methods.label}, 'Location', 'eastoutside');
local_add_truth_scan_sgtitle('Case 8: edge/high-mismatch bias under snapshot sweep');
save_figure(fig, fullfile(outDir, 'edge_hard_metrics_vs_snapshots.png'));

caseResult = struct();
caseResult.outputDir = outDir;
caseResult.models = models;
caseResult.methodLabels = {methods.label};
caseResult.evalAnglesDeg = evalAngles;
caseResult.snapshotSweep = snapshotSweep;
caseResult.snrValues = snrValues;
caseResult.rmse = rmse;
caseResult.meanAbsBias = meanAbsBias;
caseResult.p90AbsError = p90AbsError;
caseResult.evalSubsets = evalSubsets;
caseResult.edgeRmse = edgeRmse;
caseResult.edgeMeanAbsBias = edgeMeanAbsBias;
caseResult.edgeP90AbsError = edgeP90AbsError;
caseResult.highMismatchRmse = hardRmse;
caseResult.highMismatchMeanAbsBias = hardMeanAbsBias;
caseResult.highMismatchP90AbsError = hardP90AbsError;
caseResult.details = details;
save(fullfile(outDir, 'case08_results.mat'), 'caseResult');
end

function caseResult = case09_two_source_resolution(cfg, ctx)
rng(cfg.randomSeed + 9, 'twister');
outDir = local_case_output_dir(cfg, 'case09_two_source_resolution');

calIdx = select_calibration_indices(ctx.thetaDeg, cfg.case3.representativeL, 'uniform');
models = build_sparse_models(ctx, calIdx, cfg.model);
methods = local_named_methods(ctx, models, {'ideal', 'interp', 'ard', 'proposed_v1', 'proposed_v2', 'oracle'});

[sourcePairs, pairSelection] = local_case9_source_pairs(cfg.case9, ctx, models.calAnglesDeg);
taskPairsDeg = local_v2_task_pairs_from_models(models);
[sourcePairs, pairSelection, taskExcludedPairCount] = local_exclude_task_pairs_from_case9( ...
    sourcePairs, pairSelection, taskPairsDeg);
taskEvalOverlapCount = local_count_task_eval_overlap(sourcePairs, taskPairsDeg);
pairLabels = local_case9_pair_labels(sourcePairs);
separationDeg = round(sourcePairs(:, 2) - sourcePairs(:, 1), 10);
pairCenterDeg = mean(sourcePairs, 2);

evalCfg = struct();
evalCfg.mode = 'double';
evalCfg.trueAngles = sourcePairs;
evalCfg.snrDb = cfg.case9.evalSNRDb;
evalCfg.snapshots = cfg.case9.snapshots;
evalCfg.monteCarlo = cfg.case9.monteCarlo;
evalCfg.toleranceDeg = cfg.case9.toleranceDeg;
evalCfg.biasedToleranceDeg = cfg.case9.biasedToleranceDeg;
evalCfg.marginalToleranceDeg = cfg.case9.marginalToleranceDeg;
evalCfg.collectRepresentativeSpectrum = false;
bench = benchmark_music(ctx, methods, evalCfg);

resolutionProb = zeros(numel(separationDeg), numel(methods));
pairRmse = zeros(numel(separationDeg), numel(methods));
marginalRate = zeros(numel(separationDeg), numel(methods));
biasedRate = zeros(numel(separationDeg), numel(methods));
stableRate = zeros(numel(separationDeg), numel(methods));
unresolvedRate = zeros(numel(separationDeg), numel(methods));
for methodIdx = 1:numel(methods)
    resolutionProb(:, methodIdx) = bench.methods(methodIdx).perTargetResolutionRate;
    pairRmse(:, methodIdx) = bench.methods(methodIdx).perTargetRmse;
    marginalRate(:, methodIdx) = bench.methods(methodIdx).perTargetMarginalRate;
    biasedRate(:, methodIdx) = bench.methods(methodIdx).perTargetBiasedRate;
    stableRate(:, methodIdx) = bench.methods(methodIdx).perTargetStableRate;
    unresolvedRate(:, methodIdx) = bench.methods(methodIdx).perTargetUnresolvedRate;
end

[uniqueSep, resolutionMean, resolutionStd] = local_case9_group_metric(separationDeg, resolutionProb);
[~, pairRmseMean, pairRmseStd] = local_case9_group_metric(separationDeg, pairRmse);

[exampleIdx, exampleSelectionReason] = local_case9_select_example_pair(bench, methods, separationDeg, ...
    cfg.case9.exampleTargetResolutionProb, pairSelection);
examplePair = sourcePairs(exampleIdx, :);
exampleStateMatrix = zeros(numel(methods), 4);
for methodIdx = 1:numel(methods)
    exampleStateMatrix(methodIdx, :) = [ ...
        unresolvedRate(exampleIdx, methodIdx), ...
        marginalRate(exampleIdx, methodIdx), ...
        biasedRate(exampleIdx, methodIdx), ...
        stableRate(exampleIdx, methodIdx)];
end

exampleEval = evalCfg;
exampleEval.trueAngles = examplePair;
exampleEval.monteCarlo = 1;
exampleEval.collectRepresentativeSpectrum = true;
exampleBench = benchmark_music(ctx, methods, exampleEval);

fig = figure('Visible', 'off', 'Position', [140 140 1380 900]);
tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
hold on;
for methodIdx = 1:numel(methods)
    errorbar(uniqueSep, resolutionMean(:, methodIdx), resolutionStd(:, methodIdx), ...
        'o-', 'LineWidth', 1.5, 'MarkerSize', 7);
end
grid on;
ylim([0 1]);
xlabel('Source separation (deg)');
ylabel('Resolution probability');
title('Case 9: near-threshold resolution probability');
legend({methods.label}, 'Location', 'best');

nexttile;
hold on;
for methodIdx = 1:numel(methods)
    errorbar(uniqueSep, pairRmseMean(:, methodIdx), pairRmseStd(:, methodIdx), ...
        'o-', 'LineWidth', 1.5, 'MarkerSize', 7);
end
grid on;
xlabel('Source separation (deg)');
ylabel('Pair RMSE (deg)');
title('Case 9: pair RMSE in the hard interval');

nexttile;
bar(categorical({methods.label}), exampleStateMatrix, 'stacked');
grid on;
ylim([0 1]);
xlabel('Method');
ylabel('Probability');
title(sprintf('Case 9: state breakdown at [%g, %g] deg', examplePair(1), examplePair(2)));
legend({'Unresolved', 'Marginal', 'Biased', 'Stable'}, 'Location', 'bestoutside');

nexttile;
hold on;
for methodIdx = 1:numel(methods)
    plot(ctx.thetaDeg, 10 * log10(exampleBench.methods(methodIdx).representativeSpectrum), ...
        'LineWidth', 1.4);
end
grid on;
xlabel('Scan angle (deg)');
ylabel('Pseudo-spectrum (dB)');
title(sprintf('Case 9: representative hard spectrum at [%g, %g] deg', ...
    examplePair(1), examplePair(2)));
legend({methods.label}, 'Location', 'best');
local_add_truth_scan_sgtitle('Case 9: near-threshold two-source resolution');
save_figure(fig, fullfile(outDir, 'two_source_resolution.png'));

caseResult = struct();
caseResult.outputDir = outDir;
caseResult.models = models;
caseResult.methodLabels = {methods.label};
caseResult.sourcePairsDeg = sourcePairs;
caseResult.sourcePairLabels = pairLabels;
caseResult.pairSelectionMode = pairSelection.mode;
caseResult.pairSelectionScores = pairSelection;
caseResult.taskPairsDeg = taskPairsDeg;
caseResult.taskExcludedPairCount = taskExcludedPairCount;
caseResult.taskEvalOverlapCount = taskEvalOverlapCount;
caseResult.separationDeg = separationDeg;
caseResult.pairCenterDeg = pairCenterDeg;
caseResult.resolutionProb = resolutionProb;
caseResult.pairRmse = pairRmse;
caseResult.marginalRate = marginalRate;
caseResult.biasedRate = biasedRate;
caseResult.stableRate = stableRate;
caseResult.unresolvedRate = unresolvedRate;
caseResult.groupedSeparationDeg = uniqueSep;
caseResult.groupedResolutionMean = resolutionMean;
caseResult.groupedResolutionStd = resolutionStd;
caseResult.groupedPairRmseMean = pairRmseMean;
caseResult.groupedPairRmseStd = pairRmseStd;
caseResult.examplePairIndex = exampleIdx;
caseResult.exampleSelectionReason = exampleSelectionReason;
caseResult.benchmark = bench;
caseResult.exampleBenchmark = exampleBench;
save(fullfile(outDir, 'case09_results.mat'), 'caseResult');
end

function caseResult = case10_random_split_robustness(cfg, ctx)
rng(cfg.randomSeed + 10, 'twister');
outDir = local_case_output_dir(cfg, 'case10_random_split_robustness');

numSplits = cfg.case10.numSplits;
methodKeys = {'ideal', 'interp', 'ard', 'proposed_v1', 'proposed_v2'};
methodLabels = {'Ideal', 'Interp', 'ARD', 'Proposed V1', 'Proposed V2'};
manifoldError = zeros(numSplits, numel(methodKeys));
singleRmse = zeros(numSplits, numel(methodKeys));
splitAngles = cell(numSplits, 1);

for splitIdx = 1:numSplits
    fprintf('Case 10: random split %d/%d\n', splitIdx, numSplits);
    calIdx = select_calibration_indices(ctx.thetaDeg, cfg.case10.l, 'random', cfg.randomSeed + 2000 + splitIdx);
    models = build_sparse_models(ctx, calIdx, cfg.model);
    splitAngles{splitIdx} = models.calAnglesDeg;

    metricsIdeal = compute_manifold_metrics(ctx.AH(:, models.testIdx), ctx.AI(:, models.testIdx));
    metricsInterp = compute_manifold_metrics(ctx.AH(:, models.testIdx), models.AInterp(:, models.testIdx));
    metricsARD = compute_manifold_metrics(ctx.AH(:, models.testIdx), models.AARD(:, models.testIdx));
    metricsProposedV1 = compute_manifold_metrics(ctx.AH(:, models.testIdx), models.AProposedV1(:, models.testIdx));
    metricsProposedV2 = compute_manifold_metrics(ctx.AH(:, models.testIdx), models.AProposedV2(:, models.testIdx));
    manifoldError(splitIdx, :) = [ ...
        mean(metricsIdeal.relativeError), ...
        mean(metricsInterp.relativeError), ...
        mean(metricsARD.relativeError), ...
        mean(metricsProposedV1.relativeError), ...
        mean(metricsProposedV2.relativeError)];

    methods = local_named_methods(ctx, models, methodKeys);
    evalAngles = local_single_source_eval_angles(ctx, models, cfg);
    evalCfg = struct();
    evalCfg.mode = 'single';
    evalCfg.trueAngles = evalAngles;
    evalCfg.snrDb = cfg.case10.evalSNRDb;
    evalCfg.snapshots = cfg.case10.snapshots;
    evalCfg.monteCarlo = cfg.case10.monteCarlo;
    evalCfg.toleranceDeg = cfg.case10.toleranceDeg;
    evalCfg.collectRepresentativeSpectrum = false;
    bench = benchmark_music(ctx, methods, evalCfg);
    for methodIdx = 1:numel(methods)
        singleRmse(splitIdx, methodIdx) = bench.methods(methodIdx).rmse;
    end
end

[xErr, yErr] = local_box_inputs(manifoldError, methodLabels);
[xRmse, yRmse] = local_box_inputs(singleRmse, methodLabels);

fig = figure('Visible', 'off', 'Position', [130 130 1100 500]);
tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
nexttile;
boxchart(xErr, yErr);
grid on;
ylabel('Mean unseen relative error');
title(sprintf('Case 10: manifold error over %d random splits', numSplits));

nexttile;
boxchart(xRmse, yRmse);
grid on;
ylabel('Single-source DOA RMSE (deg)');
title(sprintf('Case 10: DOA RMSE over %d random splits', numSplits));
save_figure(fig, fullfile(outDir, 'random_split_robustness.png'));

caseResult = struct();
caseResult.outputDir = outDir;
caseResult.methodLabels = methodLabels;
caseResult.manifoldError = manifoldError;
caseResult.singleRmse = singleRmse;
caseResult.calibrationAnglesDeg = splitAngles;
save(fullfile(outDir, 'case10_results.mat'), 'caseResult');
end

function outDir = local_case_output_dir(cfg, caseFolderName)
if cfg.run.useTraceableDirs
    if ~isfield(cfg.run, 'runId') || isempty(cfg.run.runId)
        error('cfg.run.runId is required when cfg.run.useTraceableDirs is true.');
    end
    outDir = fullfile(cfg.run.resultRoot, caseFolderName, cfg.run.runId);
else
    outDir = fullfile(cfg.outputDir, caseFolderName);
end
if ~exist(outDir, 'dir')
    mkdir(outDir);
elseif cfg.run.useTraceableDirs && local_case_output_has_results(outDir)
    error('Traceable output directory already contains result files: %s', outDir);
end

if cfg.run.useTraceableDirs
    local_write_run_notes(outDir, cfg, caseFolderName);
end
end

function hasResults = local_case_output_has_results(outDir)
matFiles = dir(fullfile(outDir, '*.mat'));
pngFiles = dir(fullfile(outDir, '*.png'));
hasResults = ~isempty(matFiles) || ~isempty(pngFiles);
end

function local_write_run_notes(outDir, cfg, caseFolderName)
notesPath = fullfile(outDir, 'RUN_NOTES.md');
if exist(notesPath, 'file')
    return;
end

fid = fopen(notesPath, 'w');
if fid < 0
    error('Unable to write RUN_NOTES.md in %s', outDir);
end
cleanupObj = onCleanup(@() fclose(fid));

fprintf(fid, '# Run Notes\n\n');
fprintf(fid, '- Case: `%s`\n', caseFolderName);
fprintf(fid, '- Timestamp: `%s`\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf(fid, '- Pending local hash: `%s`\n', cfg.run.pendingLocalHash);
fprintf(fid, '- Base HEAD: `%s`\n', cfg.run.baseHead);
fprintf(fid, '- Run id: `%s`\n', cfg.run.runId);
fprintf(fid, '- Command: `%s`\n', cfg.run.command);
fprintf(fid, '- Notes: `%s`\n\n', cfg.run.notes);
fprintf(fid, '## Important Config\n\n');
fprintf(fid, '- Data: `%s`\n', cfg.data.csvPath);
fprintf(fid, '- Frequency Hz: `%.12g`\n', cfg.array.frequencyHz);
fprintf(fid, '- Element spacing lambda: `%.12g`\n', cfg.array.elementSpacingLambda);
fprintf(fid, '- Case 1 high SNR dB: `%.12g`\n', cfg.case1.highSNRDb);
fprintf(fid, '- Case 9 Monte Carlo: `%d`\n', cfg.case9.monteCarlo);
fprintf(fid, '- Case 9 separation sweep: `%s`\n\n', mat2str(cfg.case9.separationSweepDeg));
if isfield(cfg, 'model') && isfield(cfg.model, 'ard')
    fprintf(fid, '- ARD enabled: `%d`\n', logical(cfg.model.ard.enabled));
    fprintf(fid, '- ARD method: `%s`\n', cfg.model.ard.method);
    fprintf(fid, '- ARD note: `Method 2 complex correction-vector interpolation; no unknown coupling matrix C is estimated.`\n\n');
end
if isfield(cfg, 'model') && isfield(cfg.model, 'v2')
    fprintf(fid, '- Proposed V2 enabled: `%d`\n', logical(cfg.model.v2.enabled));
    fprintf(fid, '- Proposed V2 stage: `%s`\n', cfg.model.v2.stage);
    fprintf(fid, '- Proposed V2 pair task enabled: `%d`\n\n', logical(cfg.model.v2.pairTaskEnabled));
    fprintf(fid, '- Proposed V2 task data mode: `%s`\n', cfg.model.v2.taskDataMode);
    fprintf(fid, '- Proposed V2 SPSA iterations: `%d`\n', cfg.model.v2.numSpsaIterations);
    fprintf(fid, '- Proposed V2 note: `heldout_hfss uses extra task-supervised HFSS truth and is not same-budget with V1/Interpolation.`\n\n');
end
fprintf(fid, '## Git Status Short\n\n');
fprintf(fid, '```text\n%s\n```\n', cfg.run.gitStatusShort);
end

function cfg = local_complete_runtime_config(cfg, rootDir)
if ~isfield(cfg, 'rootDir') || isempty(cfg.rootDir)
    cfg.rootDir = rootDir;
end
if ~isfield(cfg, 'outputDir') || isempty(cfg.outputDir)
    cfg.outputDir = fullfile(rootDir, 'results_step0p2_qw');
end
if ~isfield(cfg, 'run') || isempty(cfg.run)
    cfg.run = struct();
end
cfg.run = local_set_default_field(cfg.run, 'useTraceableDirs', false);
cfg.run = local_set_default_field(cfg.run, 'resultRoot', fullfile(rootDir, 'results'));
cfg.run = local_set_default_field(cfg.run, 'runId', '');
cfg.run = local_set_default_field(cfg.run, 'pendingLocalHash', '');
cfg.run = local_set_default_field(cfg.run, 'baseHead', '');
cfg.run = local_set_default_field(cfg.run, 'gitStatusShort', '');
cfg.run = local_set_default_field(cfg.run, 'command', '');
cfg.run = local_set_default_field(cfg.run, 'notes', '');
if ~isfield(cfg, 'eval') || isempty(cfg.eval)
    cfg.eval = struct();
end
cfg.eval = local_set_default_field(cfg.eval, 'targetMode', 'stratified');
cfg.eval = local_set_default_field(cfg.eval, 'targetStrideDeg', 2);
cfg.eval = local_set_default_field(cfg.eval, 'edgeBandDeg', 8);
cfg.eval = local_set_default_field(cfg.eval, 'highMismatchCount', 12);
cfg.eval = local_set_default_field(cfg.eval, 'useFullGridForManifoldMetrics', true);

if ~isfield(cfg, 'model') || isempty(cfg.model)
    cfg.model = struct();
end
if ~isfield(cfg.model, 'v2') || isempty(cfg.model.v2)
    cfg.model.v2 = struct();
end
if ~isfield(cfg.model, 'ard') || isempty(cfg.model.ard)
    cfg.model.ard = struct();
end
cfg.model.ard = local_set_default_field(cfg.model.ard, 'enabled', true);
cfg.model.ard = local_set_default_field(cfg.model.ard, 'label', 'ARD');
cfg.model.ard = local_set_default_field(cfg.model.ard, 'method', 'complex_correction_vector');
cfg.model.v2 = local_set_default_field(cfg.model.v2, 'enabled', true);
cfg.model.v2 = local_set_default_field(cfg.model.v2, 'label', 'Proposed V2');
cfg.model.v2 = local_set_default_field(cfg.model.v2, 'stage', 'full');
cfg.model.v2 = local_set_default_field(cfg.model.v2, 'segmentCentersDeg', [-50 0 50]);
cfg.model.v2 = local_set_default_field(cfg.model.v2, 'order', 2);
cfg.model.v2 = local_set_default_field(cfg.model.v2, 'lambda', 1e-3);
cfg.model.v2 = local_set_default_field(cfg.model.v2, 'candidateMismatchWeights', [1 2 4]);
cfg.model.v2 = local_set_default_field(cfg.model.v2, 'candidateEdgeWeights', [0.5 1 2]);
cfg.model.v2 = local_set_default_field(cfg.model.v2, 'taskWeight', 0.25);
cfg.model.v2 = local_set_default_field(cfg.model.v2, 'taskNeighborhoodDeg', 0.4);
cfg.model.v2 = local_set_default_field(cfg.model.v2, 'pairTaskEnabled', true);
cfg.model.v2 = local_set_default_field(cfg.model.v2, 'taskDataMode', 'heldout_hfss');
cfg.model.v2 = local_set_default_field(cfg.model.v2, 'taskScanStrideDeg', 1);
cfg.model.v2 = local_set_default_field(cfg.model.v2, 'taskSingleHeldoutCount', 12);
cfg.model.v2 = local_set_default_field(cfg.model.v2, 'taskPairSeparationDeg', [4 5 6 8 10]);
cfg.model.v2 = local_set_default_field(cfg.model.v2, 'taskPairCount', 16);
cfg.model.v2 = local_set_default_field(cfg.model.v2, 'taskSnrDb', 25);
cfg.model.v2 = local_set_default_field(cfg.model.v2, 'numSpsaIterations', 18);
cfg.model.v2 = local_set_default_field(cfg.model.v2, 'learningRate', 0.035);
cfg.model.v2 = local_set_default_field(cfg.model.v2, 'perturbationScale', 0.025);
cfg.model.v2 = local_set_default_field(cfg.model.v2, 'lambdaCal', 1);
cfg.model.v2 = local_set_default_field(cfg.model.v2, 'lambdaSmooth', 1e-3);
cfg.model.v2 = local_set_default_field(cfg.model.v2, 'lambdaSingle', 0.15);
cfg.model.v2 = local_set_default_field(cfg.model.v2, 'lambdaPair', 0.20);
cfg.model.v2 = local_set_default_field(cfg.model.v2, 'lambdaMid', 0.08);
cfg.model.v2 = local_set_default_field(cfg.model.v2, 'lambdaReg', 1e-4);
cfg.model.v2 = local_set_default_field(cfg.model.v2, 'softmaxGamma', 8);
cfg.model.v2 = local_set_default_field(cfg.model.v2, 'midMargin', 0.2);

if isfield(cfg, 'case9')
    cfg.case9 = local_set_default_field(cfg.case9, 'maxPairsPerSeparation', 21);
    cfg.case9 = local_set_default_field(cfg.case9, 'separationSweepDeg', [1 2 3 4 5 6 8 10]);
    cfg.case9 = local_set_default_field(cfg.case9, 'biasedToleranceDeg', 2);
    cfg.case9 = local_set_default_field(cfg.case9, 'marginalToleranceDeg', 5);
    cfg.case9 = local_set_default_field(cfg.case9, 'pairSelectionMode', 'research_coverage');
end
if isfield(cfg, 'case7')
    cfg.case7 = local_set_default_field(cfg.case7, 'toleranceDeg', 0.5);
    cfg.case7 = local_set_default_field(cfg.case7, 'exampleAngleMode', 'auto_high_mismatch_edge');
    cfg.case7 = local_set_default_field(cfg.case7, 'exampleAngleDeg', 10);
end
if isfield(cfg, 'case8')
    cfg.case8 = local_set_default_field(cfg.case8, 'toleranceDeg', 0.5);
end
if isfield(cfg, 'case6')
    cfg.case6 = local_set_default_field(cfg.case6, 'lambdaSingleValues', [0 0.15]);
    cfg.case6 = local_set_default_field(cfg.case6, 'lambdaPairValues', [0 0.20]);
    cfg.case6 = local_set_default_field(cfg.case6, 'lambdaMidValues', [0 0.08]);
    cfg.case6 = local_set_default_field(cfg.case6, 'taskPairCounts', [0 16]);
    cfg.case6 = local_set_default_field(cfg.case6, 'case6V2Iterations', 10);
end
end

function inputStruct = local_set_default_field(inputStruct, fieldName, defaultValue)
if ~isfield(inputStruct, fieldName) || isempty(inputStruct.(fieldName))
    inputStruct.(fieldName) = defaultValue;
end
end

function evalAngles = local_single_source_eval_angles(ctx, models, cfg)
if nargin >= 2 && ~isempty(models) && isfield(models, 'testAnglesDeg')
    candidateAngles = models.testAnglesDeg(:).';
else
    candidateAngles = ctx.thetaDeg(:).';
end

candidateAngles = sort(unique(candidateAngles));
if isempty(candidateAngles)
    error('No candidate evaluation angles are available.');
end

targetMode = lower(strtrim(cfg.eval.targetMode));
if strcmp(targetMode, 'all')
    evalAngles = candidateAngles(:);
    return;
end

strideDeg = cfg.eval.targetStrideDeg;
if ~isfinite(strideDeg) || strideDeg <= 0
    strideDeg = 2;
end

targetGrid = candidateAngles(1):strideDeg:candidateAngles(end);
selected = local_nearest_angles_from_set(targetGrid, candidateAngles);

edgeBand = cfg.eval.edgeBandDeg;
anchors = [ ...
    candidateAngles(1), ...
    candidateAngles(1) + edgeBand, ...
    -edgeBand, ...
    0, ...
    edgeBand, ...
    candidateAngles(end) - edgeBand, ...
    candidateAngles(end)];
selected = [selected, local_nearest_angles_from_set(anchors, candidateAngles)]; %#ok<AGROW>

highMismatchCount = cfg.eval.highMismatchCount;
if highMismatchCount > 0
    candidateIdx = local_angle_indices(ctx.thetaDeg, candidateAngles);
    candidateMetrics = compute_manifold_metrics(ctx.AH(:, candidateIdx), ctx.AI(:, candidateIdx));
    [~, order] = sort(candidateMetrics.relativeError, 'descend');
    selected = [selected, candidateAngles(order(1:min(highMismatchCount, numel(order))))]; %#ok<AGROW>
end

evalAngles = sort(unique(selected(:)));
end

function nearestAngles = local_nearest_angles_from_set(queryAngles, availableAngles)
nearestAngles = zeros(size(queryAngles));
for idx = 1:numel(queryAngles)
    nearestAngles(idx) = local_nearest_angle_from_set(queryAngles(idx), availableAngles);
end
end

function nearestAngle = local_nearest_angle_from_set(queryAngle, availableAngles)
[~, nearestIdx] = min(abs(availableAngles(:).' - queryAngle));
nearestAngle = availableAngles(nearestIdx);
end

function local_add_truth_scan_sgtitle(mainTitle)
subtitle = 'HFSS truth snapshots; MUSIC scan uses the listed estimator manifolds';
if exist('sgtitle', 'file') == 2
    sgtitle({mainTitle, subtitle}, 'FontWeight', 'bold');
else
    annotation(gcf, 'textbox', [0.02 0.94 0.96 0.05], ...
        'String', sprintf('%s\n%s', mainTitle, subtitle), ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
end
end

function subsets = local_doa_eval_subsets(ctx, evalAngles, cfg)
evalAngles = evalAngles(:);
evalIdx = local_angle_indices(ctx.thetaDeg, evalAngles);
metrics = compute_manifold_metrics(ctx.AH(:, evalIdx), ctx.AI(:, evalIdx));

edgeThreshold = max(abs(ctx.thetaDeg)) - cfg.eval.edgeBandDeg;
edgeMask = abs(evalAngles) >= edgeThreshold;
if ~any(edgeMask)
    edgeMask = true(size(evalAngles));
end

[~, hardOrder] = sort(metrics.relativeError(:), 'descend');
hardCount = min(max(1, cfg.eval.highMismatchCount), numel(hardOrder));
highMismatchMask = false(size(evalAngles));
highMismatchMask(hardOrder(1:hardCount)) = true;

subsets = struct();
subsets.evalAnglesDeg = evalAngles;
subsets.edgeThresholdDeg = edgeThreshold;
subsets.edgeMask = edgeMask;
subsets.edgeAnglesDeg = evalAngles(edgeMask);
subsets.highMismatchMask = highMismatchMask;
subsets.highMismatchAnglesDeg = evalAngles(highMismatchMask);
subsets.idealRelativeError = metrics.relativeError(:);
end

function local_plot_method_curves(xValues, yMatrix, methods, xLabelText, yLabelText, titleText)
hold on;
for methodIdx = 1:numel(methods)
    plot(xValues, yMatrix(:, methodIdx), 'o-', 'LineWidth', 1.5, 'MarkerSize', 7);
end
grid on;
xlabel(xLabelText);
ylabel(yLabelText);
title(titleText);
end

function [sourcePairs, pairSelection] = local_case4_source_pairs(caseCfg, ctx, calAnglesDeg)
if isfield(caseCfg, 'separationSweepDeg') && ~isempty(caseCfg.separationSweepDeg)
    [sourcePairs, pairSelection] = local_case9_source_pairs(caseCfg, ctx, calAnglesDeg);
    pairSelection.mode = ['case4_' pairSelection.mode];
    return;
end

if ~isfield(caseCfg, 'sourcePairsDeg') || isempty(caseCfg.sourcePairsDeg)
    error('Case 4 requires either separationSweepDeg or sourcePairsDeg.');
end

sourcePairs = local_filter_pairs(caseCfg.sourcePairsDeg, ctx.thetaDeg, calAnglesDeg);
if isempty(sourcePairs)
    sourcePairs = local_filter_pairs(caseCfg.sourcePairsDeg, ctx.thetaDeg);
end

pairSelection = struct();
pairSelection.mode = 'case4_manual';
pairSelection.sourcePairsDeg = sourcePairs;
pairSelection.preLimitPairCount = size(caseCfg.sourcePairsDeg, 1);
pairSelection.selectedOriginalIndex = (1:size(sourcePairs, 1)).';
end

function [singleAngles, sourcePairs, pairSelection, excludedCalAngles] = ...
    local_case4_common_test_set(caseCfg, ctx, lValues, cfg)
tolDeg = local_angle_tolerance_from_grid(ctx.thetaDeg);
excludedCalAngles = zeros(0, 1);
for lValue = reshape(lValues, 1, [])
    calIdx = select_calibration_indices(ctx.thetaDeg, lValue, 'uniform');
    calAngles = ctx.thetaDeg(calIdx);
    excludedCalAngles = [excludedCalAngles; calAngles(:)]; %#ok<AGROW>
end
excludedCalAngles = unique(round(excludedCalAngles(:), 10), 'stable');

candidateMask = true(size(ctx.thetaDeg(:)));
for calIdx = 1:numel(excludedCalAngles)
    candidateMask = candidateMask & abs(ctx.thetaDeg(:) - excludedCalAngles(calIdx)) > tolDeg;
end

dummyModels = struct();
dummyModels.testAnglesDeg = ctx.thetaDeg(candidateMask);
singleAngles = local_single_source_eval_angles(ctx, dummyModels, cfg);
[sourcePairs, pairSelection] = local_case4_source_pairs(caseCfg, ctx, excludedCalAngles);
pairSelection.commonExcludedCalibrationAnglesDeg = excludedCalAngles;
pairSelection.commonSingleAnglesDeg = singleAngles;
end

function [exampleAngle, reason] = local_case7_example_angle(ctx, models, evalAngles, caseCfg)
modeName = 'auto_high_mismatch_edge';
if isfield(caseCfg, 'exampleAngleMode') && ~isempty(caseCfg.exampleAngleMode)
    modeName = lower(strtrim(caseCfg.exampleAngleMode));
end

if strcmp(modeName, 'manual')
    exampleAngle = local_nearest_angle_from_set(caseCfg.exampleAngleDeg, models.testAnglesDeg);
    reason = sprintf('manual angle %.1f deg snapped to unseen grid', exampleAngle);
    return;
end

candidateAngles = evalAngles(:).';
candidateIdx = local_angle_indices(ctx.thetaDeg, candidateAngles);
metrics = compute_manifold_metrics(ctx.AH(:, candidateIdx), ctx.AI(:, candidateIdx));
mismatchScore = metrics.relativeError(:);
mismatchScore = mismatchScore / max(max(mismatchScore), eps);
edgeScore = abs(candidateAngles(:)) / max(max(abs(ctx.thetaDeg)), eps);
score = 0.65 * mismatchScore + 0.35 * edgeScore;

[bestScore, bestIdx] = max(score);
exampleAngle = candidateAngles(bestIdx);
reason = sprintf(['auto high-mismatch/edge angle %.1f deg selected with score %.3f ' ...
    '(0.65 mismatch + 0.35 edge)'], exampleAngle, bestScore);
end

function [stressAngleDeg, reason, stressScore] = local_case1_select_stress_angle(bench)
idealIdx = find(strcmp({bench.methods.name}, 'ideal'), 1, 'first');
oracleIdx = find(strcmp({bench.methods.name}, 'oracle'), 1, 'first');

if isempty(idealIdx)
    idealIdx = 1;
end

ideal = bench.methods(idealIdx);
score = ideal.perTargetAbsBias(:) + ideal.perTargetRmse(:);
if ~isempty(oracleIdx)
    oracle = bench.methods(oracleIdx);
    score = score - oracle.perTargetRmse(:);
end

[stressScore, targetIdx] = max(score);
stressAngleDeg = bench.trueAngleSetsDeg(targetIdx);

if ~isempty(oracleIdx)
    reason = sprintf(['Selected %.1f deg because Ideal has the largest high-SNR ' ...
        'abs-bias plus RMSE minus HFSS Oracle RMSE score (%.3f deg).'], ...
        stressAngleDeg, stressScore);
else
    reason = sprintf(['Selected %.1f deg because Ideal has the largest high-SNR ' ...
        'abs-bias plus RMSE score (%.3f deg).'], stressAngleDeg, stressScore);
end
end

function method = local_method(name, label, manifold)
method = struct('name', name, 'label', label, 'manifold', manifold);
end

function methods = local_named_methods(ctx, models, methodKeys)
methods = repmat(struct('name', '', 'label', '', 'manifold', []), 1, numel(methodKeys));

for methodIdx = 1:numel(methodKeys)
    key = lower(strtrim(methodKeys{methodIdx}));
    switch key
        case 'ideal'
            methods(methodIdx) = local_method('ideal', 'Ideal', ctx.AI);
        case 'interp'
            methods(methodIdx) = local_method('interp', 'Interpolation', models.AInterp);
        case 'ard'
            methods(methodIdx) = local_method('ard', 'ARD', models.AARD);
        case 'proposed'
            methods(methodIdx) = local_method('proposed_v1', 'Proposed V1', models.AProposedV1);
        case 'proposed_v1'
            methods(methodIdx) = local_method('proposed_v1', 'Proposed V1', models.AProposedV1);
        case 'proposed_v2'
            methods(methodIdx) = local_method('proposed_v2', 'Proposed V2', models.AProposedV2);
        case 'oracle'
            methods(methodIdx) = local_method('oracle', 'HFSS Oracle', ctx.AH);
        otherwise
            error('Unknown method key: %s', methodKeys{methodIdx});
    end
end
end

function idx = local_angle_index(thetaDeg, queryAngle)
[distance, idx] = min(abs(thetaDeg - queryAngle));
tolDeg = local_angle_tolerance_from_grid(thetaDeg);
if distance > tolDeg
    error('Angle %.6f deg is %.6f deg away from the nearest grid point, exceeding tolerance %.6f deg.', ...
        queryAngle, distance, tolDeg);
end
end

function idx = local_angle_indices(thetaDeg, queryAngles)
idx = zeros(size(queryAngles));
for angleIdx = 1:numel(queryAngles)
    idx(angleIdx) = local_angle_index(thetaDeg, queryAngles(angleIdx));
end
end

function tolDeg = local_angle_tolerance_from_grid(thetaDeg)
if numel(thetaDeg) > 1
    tolDeg = median(diff(sort(thetaDeg))) / 2 + 1e-9;
else
    tolDeg = 1e-9;
end
end

function manifold = local_normalize_columns(manifold)
refPhase = exp(-1i * angle(manifold(1, :)));
manifold = manifold .* refPhase;
colNorm = vecnorm(manifold, 2, 1);
colNorm(colNorm < eps) = 1;
manifold = manifold ./ colNorm;
end

function validPairs = local_filter_pairs(candidatePairs, thetaGrid, calAnglesDeg)
tolDeg = local_angle_tolerance_from_grid(thetaGrid);
snappedPairs = zeros(size(candidatePairs));
availableMask = false(size(candidatePairs, 1), 1);

for pairIdx = 1:size(candidatePairs, 1)
    [leftDistance, leftIdx] = min(abs(thetaGrid - candidatePairs(pairIdx, 1)));
    [rightDistance, rightIdx] = min(abs(thetaGrid - candidatePairs(pairIdx, 2)));
    if leftDistance <= tolDeg && rightDistance <= tolDeg
        snappedPairs(pairIdx, :) = [thetaGrid(leftIdx), thetaGrid(rightIdx)];
        availableMask(pairIdx) = true;
    end
end

validPairs = snappedPairs(availableMask, :);

if nargin >= 3 && ~isempty(calAnglesDeg)
    unseenMask = true(size(validPairs, 1), 1);
    for pairIdx = 1:size(validPairs, 1)
        touchesCal = any(abs(calAnglesDeg - validPairs(pairIdx, 1)) <= tolDeg) || ...
            any(abs(calAnglesDeg - validPairs(pairIdx, 2)) <= tolDeg);
        unseenMask(pairIdx) = ~touchesCal;
    end
    if any(unseenMask)
        validPairs = validPairs(unseenMask, :);
    end
end
end

function [sourcePairs, pairSelection] = local_case9_source_pairs(caseCfg, ctx, calAnglesDeg)
thetaGrid = ctx.thetaDeg;
if isfield(caseCfg, 'sourcePairsDeg') && ~isempty(caseCfg.sourcePairsDeg)
    candidatePairs = caseCfg.sourcePairsDeg;
else
    candidatePairs = local_case9_generate_pairs(thetaGrid, caseCfg.separationSweepDeg);
end

sourcePairs = local_filter_pairs(candidatePairs, thetaGrid, calAnglesDeg);
if isempty(sourcePairs)
    sourcePairs = local_filter_pairs(candidatePairs, thetaGrid);
end

sourcePairs = sort(sourcePairs, 2);
sourcePairs = unique(sourcePairs, 'rows', 'stable');
separationDeg = sourcePairs(:, 2) - sourcePairs(:, 1);
pairCenterDeg = mean(sourcePairs, 2);
sourcePairs = sortrows([sourcePairs, separationDeg, pairCenterDeg], [3 4 1 2]);
sourcePairs = sourcePairs(:, 1:2);
preLimitPairs = sourcePairs;

if isfield(caseCfg, 'maxPairsPerSeparation') && ~isempty(caseCfg.maxPairsPerSeparation) && ...
        isfinite(caseCfg.maxPairsPerSeparation) && caseCfg.maxPairsPerSeparation > 0
    selectionMode = local_optional_case9_field(caseCfg, 'pairSelectionMode', 'research_coverage');
    [sourcePairs, selectedIdx] = local_case9_limit_pairs_per_separation( ...
        sourcePairs, caseCfg.maxPairsPerSeparation, ctx, calAnglesDeg, selectionMode);
else
    selectionMode = 'none';
    selectedIdx = 1:size(sourcePairs, 1);
end

pairSelection = local_case9_score_pairs(preLimitPairs, ctx, calAnglesDeg);
pairSelection.mode = selectionMode;
pairSelection.preLimitPairCount = size(preLimitPairs, 1);
pairSelection.selectedOriginalIndex = selectedIdx(:);
pairSelection = local_case9_subset_pair_selection(pairSelection, selectedIdx);
end

function taskPairsDeg = local_v2_task_pairs_from_models(models)
taskPairsDeg = zeros(0, 2);
if isfield(models, 'v2Diagnostics') && isfield(models.v2Diagnostics, 'taskPairsDeg') && ...
        ~isempty(models.v2Diagnostics.taskPairsDeg)
    taskPairsDeg = sort(models.v2Diagnostics.taskPairsDeg, 2);
end
end

function [sourcePairs, pairSelection, excludedCount] = local_exclude_task_pairs_from_case9( ...
    sourcePairs, pairSelection, taskPairsDeg)
excludedCount = 0;
if isempty(taskPairsDeg) || isempty(sourcePairs)
    return;
end

taskPairsDeg = sort(round(taskPairsDeg, 10), 2);
sourceRounded = sort(round(sourcePairs, 10), 2);
keepMask = true(size(sourcePairs, 1), 1);
for pairIdx = 1:size(sourceRounded, 1)
    overlaps = all(abs(taskPairsDeg - sourceRounded(pairIdx, :)) < 1e-9, 2);
    if any(overlaps)
        keepMask(pairIdx) = false;
        excludedCount = excludedCount + 1;
    end
end

sourcePairs = sourcePairs(keepMask, :);
pairSelection = local_case9_filter_pair_selection_by_mask(pairSelection, keepMask);
end

function overlapCount = local_count_task_eval_overlap(sourcePairs, taskPairsDeg)
overlapCount = 0;
if isempty(taskPairsDeg) || isempty(sourcePairs)
    return;
end

taskPairsDeg = sort(round(taskPairsDeg, 10), 2);
sourceRounded = sort(round(sourcePairs, 10), 2);
for pairIdx = 1:size(sourceRounded, 1)
    overlaps = all(abs(taskPairsDeg - sourceRounded(pairIdx, :)) < 1e-9, 2);
    if any(overlaps)
        overlapCount = overlapCount + 1;
    end
end
end

function pairSelection = local_case9_filter_pair_selection_by_mask(pairSelection, keepMask)
fieldsToFilter = {'sourcePairsDeg', 'pairMismatchScore', 'edgeScore', ...
    'calDistanceScore', 'combinedScore', 'selectedOriginalIndex'};
for fieldIdx = 1:numel(fieldsToFilter)
    fieldName = fieldsToFilter{fieldIdx};
    if isfield(pairSelection, fieldName)
        values = pairSelection.(fieldName);
        if size(values, 1) == numel(keepMask)
            pairSelection.(fieldName) = values(keepMask, :);
        end
    end
end
pairSelection.taskExcludedCount = sum(~keepMask);
end

function candidatePairs = local_case9_generate_pairs(thetaGrid, separationSweepDeg)
candidatePairs = zeros(0, 2);
tolDeg = local_angle_tolerance_from_grid(thetaGrid);

for sepDeg = reshape(separationSweepDeg, 1, [])
    for angleIdx = 1:numel(thetaGrid)
        partnerAngle = thetaGrid(angleIdx) + sepDeg;
        [distance, partnerIdx] = min(abs(thetaGrid - partnerAngle));
        if distance <= tolDeg
            candidatePairs(end+1, :) = [thetaGrid(angleIdx), thetaGrid(partnerIdx)]; %#ok<AGROW>
        end
    end
end
end

function [limitedPairs, selectedIdx] = local_case9_limit_pairs_per_separation( ...
    sourcePairs, maxPairsPerSeparation, ctx, calAnglesDeg, selectionMode)
separationDeg = sourcePairs(:, 2) - sourcePairs(:, 1);
uniqueSep = unique(round(separationDeg, 10), 'sorted');
limitedPairs = zeros(0, 2);
selectedIdx = zeros(0, 1);
useResearchCoverage = strcmpi(selectionMode, 'research_coverage');
if useResearchCoverage
    scores = local_case9_score_pairs(sourcePairs, ctx, calAnglesDeg);
end

for sepIdx = 1:numel(uniqueSep)
    pairIdx = find(abs(separationDeg - uniqueSep(sepIdx)) < 1e-9);
    if numel(pairIdx) > maxPairsPerSeparation
        if useResearchCoverage
            pairIdx = local_case9_research_coverage_indices(pairIdx, scores, sourcePairs, maxPairsPerSeparation);
        else
            pickLocal = unique(round(linspace(1, numel(pairIdx), maxPairsPerSeparation)));
            pairIdx = pairIdx(pickLocal);
        end
    end
    limitedPairs = [limitedPairs; sourcePairs(pairIdx, :)]; %#ok<AGROW>
    selectedIdx = [selectedIdx; pairIdx(:)]; %#ok<AGROW>
end
end

function pairSelection = local_case9_score_pairs(sourcePairs, ctx, calAnglesDeg)
leftIdx = local_angle_indices(ctx.thetaDeg, sourcePairs(:, 1));
rightIdx = local_angle_indices(ctx.thetaDeg, sourcePairs(:, 2));
leftMetrics = compute_manifold_metrics(ctx.AH(:, leftIdx), ctx.AI(:, leftIdx));
rightMetrics = compute_manifold_metrics(ctx.AH(:, rightIdx), ctx.AI(:, rightIdx));

maxAbsAngle = max(abs(ctx.thetaDeg));
if maxAbsAngle <= 0
    maxAbsAngle = 1;
end

pairMismatchScore = (leftMetrics.relativeError(:) + rightMetrics.relativeError(:)) / 2;
edgeScore = max(abs(sourcePairs), [], 2) / maxAbsAngle;

if nargin < 3 || isempty(calAnglesDeg)
    calDistanceScore = ones(size(pairMismatchScore));
else
    calDistance = zeros(size(pairMismatchScore));
    for pairIdx = 1:size(sourcePairs, 1)
        leftDistance = min(abs(calAnglesDeg(:) - sourcePairs(pairIdx, 1)));
        rightDistance = min(abs(calAnglesDeg(:) - sourcePairs(pairIdx, 2)));
        calDistance(pairIdx) = min(leftDistance, rightDistance);
    end
    calDistanceScore = min(calDistance / maxAbsAngle, 1);
end

combinedScore = 0.55 * pairMismatchScore + 0.30 * edgeScore + 0.15 * calDistanceScore;

pairSelection = struct();
pairSelection.mode = 'research_coverage';
pairSelection.sourcePairsDeg = sourcePairs;
pairSelection.pairMismatchScore = pairMismatchScore;
pairSelection.edgeScore = edgeScore;
pairSelection.calDistanceScore = calDistanceScore;
pairSelection.combinedScore = combinedScore;
pairSelection.weights = [0.55 0.30 0.15];
end

function subsetSelection = local_case9_subset_pair_selection(pairSelection, selectedIdx)
subsetSelection = pairSelection;
fieldsToSubset = {'sourcePairsDeg', 'pairMismatchScore', 'edgeScore', ...
    'calDistanceScore', 'combinedScore'};
for fieldIdx = 1:numel(fieldsToSubset)
    fieldName = fieldsToSubset{fieldIdx};
    values = pairSelection.(fieldName);
    if size(values, 1) == numel(pairSelection.combinedScore)
        subsetSelection.(fieldName) = values(selectedIdx, :);
    end
end
end

function selectedIdx = local_case9_research_coverage_indices(pairIdx, scores, sourcePairs, maxPairsPerSeparation)
selectedIdx = zeros(0, 1);

[~, combinedOrder] = sort(scores.combinedScore(pairIdx), 'descend');
combinedPick = pairIdx(combinedOrder(1:min(9, min(maxPairsPerSeparation, numel(combinedOrder)))));
selectedIdx = local_append_unique_indices(selectedIdx, combinedPick);

remainingSlots = maxPairsPerSeparation - numel(selectedIdx);
if remainingSlots > 0
    [~, edgeOrder] = sort(scores.edgeScore(pairIdx), 'descend');
    edgePick = pairIdx(edgeOrder(1:min(6, min(remainingSlots, numel(edgeOrder)))));
    selectedIdx = local_append_unique_indices(selectedIdx, edgePick);
end

while numel(selectedIdx) < maxPairsPerSeparation
    remaining = setdiff(pairIdx(:), selectedIdx(:), 'stable');
    if isempty(remaining)
        break;
    end
    nextIdx = local_case9_next_farthest_center_idx(remaining, selectedIdx, sourcePairs, scores);
    selectedIdx = local_append_unique_indices(selectedIdx, nextIdx);
end

selectedIdx = sort(selectedIdx(:));
end

function selectedIdx = local_append_unique_indices(selectedIdx, newIdx)
for idx = reshape(newIdx, 1, [])
    if ~ismember(idx, selectedIdx)
        selectedIdx(end+1, 1) = idx; %#ok<AGROW>
    end
end
end

function nextIdx = local_case9_next_farthest_center_idx(remaining, selectedIdx, sourcePairs, scores)
centers = mean(sourcePairs, 2);
if isempty(selectedIdx)
    [~, localIdx] = max(scores.combinedScore(remaining));
    nextIdx = remaining(localIdx);
    return;
end

selectedCenters = centers(selectedIdx);
minDistance = zeros(numel(remaining), 1);
for idx = 1:numel(remaining)
    minDistance(idx) = min(abs(centers(remaining(idx)) - selectedCenters));
end

tieBreaker = scores.combinedScore(remaining);
rankScore = minDistance + 1e-3 * tieBreaker;
[~, localIdx] = max(rankScore);
nextIdx = remaining(localIdx);
end

function pairLabels = local_case9_pair_labels(sourcePairs)
pairLabels = arrayfun(@(rowIdx) sprintf('[%g,%g]', sourcePairs(rowIdx, 1), sourcePairs(rowIdx, 2)), ...
    1:size(sourcePairs, 1), 'UniformOutput', false);
end

function [uniqueSep, meanMetric, stdMetric] = local_case9_group_metric(separationDeg, metricMatrix)
separationDeg = round(separationDeg, 10);
uniqueSep = unique(separationDeg, 'sorted');
meanMetric = zeros(numel(uniqueSep), size(metricMatrix, 2));
stdMetric = zeros(numel(uniqueSep), size(metricMatrix, 2));

for sepIdx = 1:numel(uniqueSep)
    pairMask = abs(separationDeg - uniqueSep(sepIdx)) < 1e-9;
    meanMetric(sepIdx, :) = mean(metricMatrix(pairMask, :), 1);
    stdMetric(sepIdx, :) = std(metricMatrix(pairMask, :), 0, 1);
end
end

function [exampleIdx, reason] = local_case9_select_example_pair( ...
    bench, methods, separationDeg, targetResolutionProb, pairSelection)
primaryIdx = find(strcmp({methods.name}, 'proposed_v2'), 1, 'first');
if isempty(primaryIdx)
    primaryIdx = find(strcmp({methods.name}, 'proposed'), 1, 'first');
end
if isempty(primaryIdx)
    primaryIdx = find(strcmp({methods.name}, 'proposed_v1'), 1, 'first');
end
if isempty(primaryIdx)
    primaryIdx = 1;
end
interpIdx = find(strcmp({methods.name}, 'interp'), 1, 'first');
v1Idx = find(strcmp({methods.name}, 'proposed_v1'), 1, 'first');

primary = bench.methods(primaryIdx);
primaryLabel = methods(primaryIdx).label;
stateMatrix = [ ...
    primary.perTargetUnresolvedRate(:), ...
    primary.perTargetMarginalRate(:), ...
    primary.perTargetBiasedRate(:), ...
    primary.perTargetStableRate(:)];
stateEntropy = -sum(stateMatrix .* log(max(stateMatrix, eps)), 2);

mixedMask = primary.perTargetResolutionRate > 0.05 & primary.perTargetResolutionRate < 0.98;
mismatchScore = zeros(size(primary.perTargetResolutionRate(:)));
if nargin >= 5 && isfield(pairSelection, 'combinedScore')
    mismatchScore = pairSelection.combinedScore(:);
    mismatchScore = mismatchScore / max(max(mismatchScore), eps);
end

baselineStable = [];
baselineResolution = [];
baselineLabels = {};
if ~isempty(interpIdx)
    baselineStable(:, end+1) = bench.methods(interpIdx).perTargetStableRate(:); %#ok<AGROW>
    baselineResolution(:, end+1) = bench.methods(interpIdx).perTargetResolutionRate(:); %#ok<AGROW>
    baselineLabels{end+1} = methods(interpIdx).label; %#ok<AGROW>
end
if ~isempty(v1Idx) && v1Idx ~= primaryIdx
    baselineStable(:, end+1) = bench.methods(v1Idx).perTargetStableRate(:); %#ok<AGROW>
    baselineResolution(:, end+1) = bench.methods(v1Idx).perTargetResolutionRate(:); %#ok<AGROW>
    baselineLabels{end+1} = methods(v1Idx).label; %#ok<AGROW>
end

if ~isempty(baselineStable)
    bestBaselineStable = max(baselineStable, [], 2);
    bestBaselineResolution = max(baselineResolution, [], 2);
    advantage = primary.perTargetStableRate(:) - bestBaselineStable + ...
        0.5 * (primary.perTargetResolutionRate(:) - bestBaselineResolution);
    candidateMask = mixedMask & advantage > 0.02;
    if any(candidateMask)
        candidateIdx = find(candidateMask);
        score = advantage(candidateIdx) + 0.4 * stateEntropy(candidateIdx) ...
            + 0.15 * mismatchScore(candidateIdx) - 0.02 * separationDeg(candidateIdx);
        [~, bestLocalIdx] = max(score);
        exampleIdx = candidateIdx(bestLocalIdx);
        reason = sprintf(['Selected [%g, %g] deg because %s improves stable/resolution ' ...
            'behavior over %s while remaining a mixed hard pair.'], ...
            bench.trueAngleSetsDeg(exampleIdx, 1), bench.trueAngleSetsDeg(exampleIdx, 2), ...
            primaryLabel, strjoin(baselineLabels, '/'));
        return;
    end
end

candidateMask = mixedMask;
if ~any(candidateMask)
    candidateMask = true(size(primary.perTargetResolutionRate));
end

candidateIdx = find(candidateMask);
score = 0.45 * mismatchScore(candidateIdx) + 0.35 * stateEntropy(candidateIdx) ...
    - abs(primary.perTargetResolutionRate(candidateIdx) - targetResolutionProb) ...
    - 0.02 * separationDeg(candidateIdx);
[~, bestLocalIdx] = max(score);
exampleIdx = candidateIdx(bestLocalIdx);
reason = sprintf(['Selected [%g, %g] deg as the hardest available high-mismatch pair; ' ...
    'no stable %s-over-baseline advantage pair was found in this run.'], ...
    bench.trueAngleSetsDeg(exampleIdx, 1), bench.trueAngleSetsDeg(exampleIdx, 2), primaryLabel);
end

function value = local_optional_case9_field(inputStruct, fieldName, defaultValue)
if isfield(inputStruct, fieldName) && ~isempty(inputStruct.(fieldName))
    value = inputStruct.(fieldName);
else
    value = defaultValue;
end
end

function [xValues, yValues] = local_box_inputs(dataMatrix, labels)
numSamples = size(dataMatrix, 1);

xValues = categorical(repelem(labels, numSamples));
yValues = reshape(dataMatrix, [], 1);
end
