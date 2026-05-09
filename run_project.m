function results = run_project(selectedCases, cfg)
%RUN_PROJECT Run the MATLAB manifold-calibration experiments.
%
% Usage:
%   run_project()              % run current mainline Case 12
%   run_project([1 3 7])       % run selected cases
%
% The code follows the project documents:
%   1) HFSS data are always treated as the truth manifold.
%   2) Sparse calibration angles are used only to reconstruct the manifold.
%   3) DOA snapshots are always generated from the HFSS truth manifold.

if nargin < 1 || isempty(selectedCases)
    selectedCases = 12;
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
if cfg.run.useTraceableDirs
    local_prepare_version_output(cfg);
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
    @case10_random_split_robustness, ...
    @case11_backend_diagnostic, ...
    @case12_core_1to3_source_mainline};
caseFolderNames = { ...
    'case01_problem_validation', ...
    'case02_dominant_mismatch', ...
    'case03_unseen_generalization', ...
    'case04_calibration_count_sensitivity', ...
    'case05_sampling_strategy_sensitivity', ...
    'case06_model_sensitivity', ...
    'case07_single_source_snr', ...
    'case08_single_source_snapshots', ...
    'case09_two_source_resolution', ...
    'case10_random_split_robustness', ...
    'case11_backend_diagnostic', ...
    'case12_core_1to3_source_mainline'};

results = struct();
completedCaseFolders = {};

for runIdx = 1:numel(selectedCases)
    caseId = selectedCases(runIdx);
    if caseId < 1 || caseId > numel(caseRunners)
        error('Case id must be an integer in [1, 12].');
    end

    fprintf('\n=== Running Case %02d ===\n', caseId);
    fieldName = sprintf('case%02d', caseId);
    results.(fieldName) = caseRunners{caseId}(cfg, ctx);
    completedCaseFolders{end+1} = caseFolderNames{caseId}; %#ok<AGROW>
    if cfg.run.useTraceableDirs
        local_write_manifest(cfg, completedCaseFolders, selectedCases);
    end
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
methodNames = {'Ideal', 'Interpolation', 'ARD', 'Proposed V1', 'Proposed V2', ...
    'Proposed V3.3', 'HFSS Oracle'};
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
    metricsProposedV3 = compute_manifold_metrics(ctx.AH(:, models.testIdx), models.AProposedV3(:, models.testIdx));
    perMethodError = [ ...
        metricsIdeal.relativeError(:), ...
        metricsInterp.relativeError(:), ...
        metricsARD.relativeError(:), ...
        metricsProposedV1.relativeError(:), ...
        metricsProposedV2.relativeError(:), ...
        metricsProposedV3.relativeError(:), ...
        zeros(numel(models.testIdx), 1)];

    meanUnseenError(lIdx, :) = [ ...
        mean(metricsIdeal.relativeError), ...
        mean(metricsInterp.relativeError), ...
        mean(metricsARD.relativeError), ...
        mean(metricsProposedV1.relativeError), ...
        mean(metricsProposedV2.relativeError), ...
        mean(metricsProposedV3.relativeError), ...
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
    plot(ctx.thetaDeg, rad2deg(repModels.phaseFitV3Full(elementIdx, :)), '-', 'LineWidth', 1.2);
    scatter(repModels.calAnglesDeg, rad2deg(repModels.phaseTruthFull(elementIdx, repModels.calIdx)), ...
        36, 'filled');
    grid on;
    ylabel(sprintf('Element %d (deg)', elementIdx));
    title(sprintf('Case 3: phase reconstruction for element %d', elementIdx));
end
xlabel('Angle (deg)');
legend({'HFSS truth', 'Interpolation', 'Proposed V1 fit', 'Proposed V2 fit', ...
    'Proposed V3.3 fit', ...
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
    plot(elemAxis, abs(repModels.AProposedV3(:, gridIdx)), 'p-', 'LineWidth', 1.2);
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
    plot(elemAxis, rad2deg(unwrap(angle(repModels.AProposedV3(:, gridIdx)))), 'p-', 'LineWidth', 1.2);
    grid on;
    xlabel('Element index');
    ylabel('Phase (deg)');
    title(sprintf('Phase at %.1f deg', queryAngle));
end
legend({'HFSS truth', 'Ideal', 'Interpolation', 'ARD', 'Proposed V1', 'Proposed V2', ...
    'Proposed V3.3'}, ...
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
methods = local_named_methods(ctx, models, {'ideal', 'interp', 'ard', 'proposed_v1', ...
    'proposed_v2', 'proposed_v3', 'oracle'});
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
methods = local_named_methods(ctx, models, {'ideal', 'interp', 'ard', 'proposed_v1', ...
    'proposed_v2', 'proposed_v3', 'oracle'});

[sourcePairs, pairSelection] = case09_helpers('source_pairs', cfg.case9, ctx, models.calAnglesDeg);
[taskPairsDeg, v2TaskPairsDeg, v3TaskPairsDeg] = local_task_pairs_from_models(models);
[sourcePairs, pairSelection, taskExcludedPairCount] = case09_helpers('exclude_task_pairs', ...
    sourcePairs, pairSelection, taskPairsDeg);
taskEvalOverlapCount = case09_helpers('count_task_eval_overlap', sourcePairs, taskPairsDeg);
pairLabels = case09_helpers('pair_labels', sourcePairs);
separationDeg = round(sourcePairs(:, 2) - sourcePairs(:, 1), 10);
pairCenterDeg = mean(sourcePairs, 2);
discriminativeMinSeparationDeg = case09_helpers('optional_field', ...
    cfg.case9, 'discriminativeMinSeparationDeg', 6);
discriminativeMask = separationDeg >= discriminativeMinSeparationDeg;

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
evalCfg.backendName = case09_helpers('optional_field', cfg.case9, 'backendName', 'music');
evalCfg.backendCfg = local_case09_backend_cfg(cfg.case9, ctx.thetaDeg, sourcePairs);
bench = benchmark_music(ctx, methods, evalCfg);

resolutionProb = zeros(numel(separationDeg), numel(methods));
pairRmse = zeros(numel(separationDeg), numel(methods));
marginalRate = zeros(numel(separationDeg), numel(methods));
biasedRate = zeros(numel(separationDeg), numel(methods));
stableRate = zeros(numel(separationDeg), numel(methods));
unresolvedRate = zeros(numel(separationDeg), numel(methods));
separationCollapseRate = zeros(numel(separationDeg), numel(methods));
for methodIdx = 1:numel(methods)
    resolutionProb(:, methodIdx) = bench.methods(methodIdx).perTargetResolutionRate;
    pairRmse(:, methodIdx) = bench.methods(methodIdx).perTargetRmse;
    marginalRate(:, methodIdx) = bench.methods(methodIdx).perTargetMarginalRate;
    biasedRate(:, methodIdx) = bench.methods(methodIdx).perTargetBiasedRate;
    stableRate(:, methodIdx) = bench.methods(methodIdx).perTargetStableRate;
    unresolvedRate(:, methodIdx) = bench.methods(methodIdx).perTargetUnresolvedRate;
    separationCollapseRate(:, methodIdx) = bench.methods(methodIdx).perTargetSeparationCollapseRate;
end

[uniqueSep, resolutionMean, resolutionStd] = case09_helpers('group_metric', separationDeg, resolutionProb);
[~, pairRmseMean, pairRmseStd] = case09_helpers('group_metric', separationDeg, pairRmse);
[~, stableMean, stableStd] = case09_helpers('group_metric', separationDeg, stableRate);
[~, collapseMean, collapseStd] = case09_helpers('group_metric', separationDeg, separationCollapseRate);
[pairDeltaResolution, pairDeltaStable] = case09_helpers('v3_delta_from_ard', ...
    methods, resolutionMean, stableMean);
overallSummary = case09_helpers('subset_summary', methods, true(size(separationDeg)), ...
    resolutionProb, stableRate, pairRmse, marginalRate, biasedRate, unresolvedRate);
discriminativeSummary = case09_helpers('subset_summary', methods, discriminativeMask, ...
    resolutionProb, stableRate, pairRmse, marginalRate, biasedRate, unresolvedRate);
overallSummary.meanSeparationCollapse = mean(separationCollapseRate, 1);
discriminativeSummary.meanSeparationCollapse = mean(separationCollapseRate(discriminativeMask, :), 1);
v1ExperienceDiagnostics = case09_helpers('v1_experience_diagnostics', ...
    methods, overallSummary, discriminativeSummary, uniqueSep, resolutionMean, stableMean);
centerBinDeg = case09_helpers('optional_field', cfg.model.v3, 'taskPairCenterBinDeg', 10);
taskStratumHist = case09_helpers('pair_stratum_hist', v3TaskPairsDeg, centerBinDeg);
evalStratumHist = case09_helpers('pair_stratum_hist', sourcePairs, centerBinDeg);
v3StablePairDiagnostics = case09_helpers('v3_stable_pair_diagnostics', models);

[exampleIdx, exampleSelectionReason] = case09_helpers('select_example_pair', bench, methods, separationDeg, ...
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
for trueIdx = 1:numel(examplePair)
    xline(examplePair(trueIdx), 'k--', 'LineWidth', 1.0, 'HandleVisibility', 'off');
end
grid on;
xlabel('Scan angle (deg)');
ylabel('Pseudo-spectrum (dB)');
title(sprintf('Case 9: representative MUSIC spectrum at [%g, %g] deg', ...
    examplePair(1), examplePair(2)));
legend({methods.label}, 'Location', 'best');
local_add_truth_scan_sgtitle('Case 9: near-threshold two-source resolution', ...
    local_case09_backend_subtitle(evalCfg.backendName));
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
caseResult.v2TaskPairsDeg = v2TaskPairsDeg;
caseResult.v3TaskPairsDeg = v3TaskPairsDeg;
caseResult.taskExcludedPairCount = taskExcludedPairCount;
caseResult.taskEvalOverlapCount = taskEvalOverlapCount;
caseResult.separationDeg = separationDeg;
caseResult.pairCenterDeg = pairCenterDeg;
caseResult.discriminativeMinSeparationDeg = discriminativeMinSeparationDeg;
caseResult.discriminativeMask = discriminativeMask;
caseResult.resolutionProb = resolutionProb;
caseResult.pairRmse = pairRmse;
caseResult.marginalRate = marginalRate;
caseResult.biasedRate = biasedRate;
caseResult.stableRate = stableRate;
caseResult.unresolvedRate = unresolvedRate;
caseResult.estimatedSeparationCollapseRate = separationCollapseRate;
caseResult.groupedSeparationDeg = uniqueSep;
caseResult.groupedResolutionMean = resolutionMean;
caseResult.groupedResolutionStd = resolutionStd;
caseResult.groupedPairRmseMean = pairRmseMean;
caseResult.groupedPairRmseStd = pairRmseStd;
caseResult.groupedStableMean = stableMean;
caseResult.groupedStableStd = stableStd;
caseResult.groupedSeparationCollapseMean = collapseMean;
caseResult.groupedSeparationCollapseStd = collapseStd;
caseResult.pairDeltaResolution = pairDeltaResolution;
caseResult.pairDeltaStable = pairDeltaStable;
caseResult.overallSummary = overallSummary;
caseResult.discriminativeSummary = discriminativeSummary;
caseResult.v1ExperienceDiagnostics = v1ExperienceDiagnostics;
caseResult.taskStratumHist = taskStratumHist;
caseResult.evalStratumHist = evalStratumHist;
caseResult.v3StablePairDiagnostics = v3StablePairDiagnostics;
caseResult.examplePairIndex = exampleIdx;
caseResult.exampleSelectionReason = exampleSelectionReason;
caseResult.backendName = evalCfg.backendName;
caseResult.backendCfg = evalCfg.backendCfg;
caseResult.benchmark = bench;
caseResult.exampleBenchmark = exampleBench;
save(fullfile(outDir, 'case09_results.mat'), 'caseResult');
end

function backendCfg = local_case09_backend_cfg(case9Cfg, thetaDeg, sourcePairs)
backendCfg = struct();
backendCfg.numSources = 2;
backendCfg.candidatePeakCount = case09_helpers('optional_field', ...
    case9Cfg, 'backendCandidatePeakCount', 12);
backendCfg.minimumSeparationDeg = case09_helpers('optional_field', ...
    case9Cfg, 'backendMinimumSeparationDeg', 2);
backendCfg.maximumSeparationDeg = case09_helpers('optional_field', ...
    case9Cfg, 'backendMaximumSeparationDeg', 30);
backendCfg.topCandidateCount = case09_helpers('optional_field', ...
    case9Cfg, 'backendTopCandidateCount', 8);
backendCfg.candidateAnglesDeg = local_case09_backend_candidate_angles(thetaDeg, sourcePairs, case9Cfg);
backendCfg.pairIndex = local_case09_backend_pair_index(thetaDeg, backendCfg);
end

function candidateAnglesDeg = local_case09_backend_candidate_angles(thetaDeg, sourcePairs, case9Cfg)
strideDeg = case09_helpers('optional_field', case9Cfg, 'backendCandidateAngleStrideDeg', 1);
thetaDeg = thetaDeg(:).';
minAngle = max(min(thetaDeg), min(sourcePairs(:)) - 20);
maxAngle = min(max(thetaDeg), max(sourcePairs(:)) + 20);
if strideDeg <= 0
    candidateAnglesDeg = thetaDeg(thetaDeg >= minAngle & thetaDeg <= maxAngle);
    return;
end

queryAngles = minAngle:strideDeg:maxAngle;
candidateIdx = zeros(1, numel(queryAngles));
tolDeg = local_angle_tolerance_from_grid(thetaDeg);
keep = false(1, numel(queryAngles));
for queryIdx = 1:numel(queryAngles)
    [distance, nearestIdx] = min(abs(thetaDeg - queryAngles(queryIdx)));
    if distance <= tolDeg
        candidateIdx(queryIdx) = nearestIdx;
        keep(queryIdx) = true;
    end
end
candidateAnglesDeg = thetaDeg(unique(candidateIdx(keep), 'stable'));
end

function pairIdx = local_case09_backend_pair_index(thetaDeg, backendCfg)
candidateIdx = zeros(1, numel(backendCfg.candidateAnglesDeg));
for angleIdx = 1:numel(backendCfg.candidateAnglesDeg)
    candidateIdx(angleIdx) = local_angle_index(thetaDeg, backendCfg.candidateAnglesDeg(angleIdx));
end
candidateIdx = unique(candidateIdx, 'stable');
pairIdx = zeros(0, 2);
for firstIdx = 1:numel(candidateIdx)-1
    for secondIdx = firstIdx+1:numel(candidateIdx)
        candidate = [candidateIdx(firstIdx), candidateIdx(secondIdx)];
        separationDeg = abs(diff(thetaDeg(candidate)));
        if separationDeg >= backendCfg.minimumSeparationDeg && separationDeg <= backendCfg.maximumSeparationDeg
            pairIdx(end+1, :) = candidate; %#ok<AGROW>
        end
    end
end
end

function subtitle = local_case09_backend_subtitle(backendName)
switch lower(strtrim(backendName))
    case 'music'
        backendLabel = 'MUSIC peak picking';
    case 'music_pair_rescore'
        backendLabel = 'MUSIC peak candidates with covariance-fit pair rescoring';
    case 'pairwise_grid_ml'
        backendLabel = 'pairwise grid covariance-fit ML';
    otherwise
        backendLabel = strrep(backendName, '_', ' ');
end
subtitle = sprintf('HFSS truth snapshots; estimator manifolds use %s backend', backendLabel);
end

function caseResult = case10_random_split_robustness(cfg, ctx)
rng(cfg.randomSeed + 10, 'twister');
outDir = local_case_output_dir(cfg, 'case10_random_split_robustness');

numSplits = cfg.case10.numSplits;
methodKeys = {'ideal', 'interp', 'ard', 'proposed_v1', 'proposed_v2', 'proposed_v3'};
methodLabels = {'Ideal', 'Interp', 'ARD', 'Proposed V1', 'Proposed V2', 'Proposed V3.3'};
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
    metricsProposedV3 = compute_manifold_metrics(ctx.AH(:, models.testIdx), models.AProposedV3(:, models.testIdx));
    manifoldError(splitIdx, :) = [ ...
        mean(metricsIdeal.relativeError), ...
        mean(metricsInterp.relativeError), ...
        mean(metricsARD.relativeError), ...
        mean(metricsProposedV1.relativeError), ...
        mean(metricsProposedV2.relativeError), ...
        mean(metricsProposedV3.relativeError)];

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

function caseResult = case11_backend_diagnostic(cfg, ctx)
rng(cfg.randomSeed + 11, 'twister');
outDir = local_case_output_dir(cfg, 'case11_backend_diagnostic');

calIdx = select_calibration_indices(ctx.thetaDeg, cfg.case3.representativeL, 'uniform');
models = build_sparse_models(ctx, calIdx, cfg.model);
methods = local_named_methods(ctx, models, cfg.case11.methodKeys);

evalCfg = struct();
evalCfg.mode = 'double';
evalCfg.trueAngles = cfg.case11.sourcePairsDeg;
evalCfg.snrDb = cfg.case11.evalSNRDb;
evalCfg.snapshots = cfg.case11.snapshots;
evalCfg.monteCarlo = cfg.case11.monteCarlo;
evalCfg.toleranceDeg = cfg.case11.toleranceDeg;
evalCfg.biasedToleranceDeg = cfg.case11.biasedToleranceDeg;
evalCfg.marginalToleranceDeg = cfg.case11.marginalToleranceDeg;
evalCfg.collectRepresentative = true;

backendCfg = struct();
backendCfg.backendNames = cfg.case11.backendNames;
backendCfg.numSources = 2;
backendCfg.candidatePeakCount = cfg.case11.candidatePeakCount;
backendCfg.minimumSeparationDeg = cfg.case11.minimumSeparationDeg;
backendCfg.maximumSeparationDeg = cfg.case11.maximumSeparationDeg;
backendCfg.topCandidateCount = cfg.case11.topCandidateCount;
backendCfg.candidateAnglesDeg = local_case11_candidate_angles(ctx.thetaDeg, cfg.case11);

bench = benchmark_doa_backends(ctx, methods, evalCfg, backendCfg);

caseResult = struct();
caseResult.outputDir = outDir;
caseResult.sourcePairsDeg = bench.trueAngleSetsDeg;
caseResult.backendNames = bench.backendNames;
caseResult.methodLabels = bench.methodLabels;
caseResult.methodNames = bench.methodNames;
caseResult.snapshotPolicy = bench.snapshotPolicy;
caseResult.rmse = bench.rmse;
caseResult.resolutionRate = bench.resolutionRate;
caseResult.stableRate = bench.stableRate;
caseResult.marginalRate = bench.marginalRate;
caseResult.biasedRate = bench.biasedRate;
caseResult.unresolvedRate = bench.unresolvedRate;
caseResult.collapseRate = bench.collapseRate;
caseResult.oracleCeilingDelta = bench.summary.oracleGainOverMusic;
caseResult.backendDiagnostics = bench.backendDiagnostics;
caseResult.representative = bench.representative;
caseResult.summary = bench.summary;

local_plot_case11_backend_summary(caseResult, outDir);
save(fullfile(outDir, 'case11_results.mat'), 'caseResult');
end

function candidateAnglesDeg = local_case11_candidate_angles(thetaDeg, case11Cfg)
strideDeg = case11Cfg.candidateAngleStrideDeg;
if isempty(strideDeg) || strideDeg <= 0
    strideDeg = 1;
end

minAngle = max(min(thetaDeg), min(case11Cfg.sourcePairsDeg(:)) - 20);
maxAngle = min(max(thetaDeg), max(case11Cfg.sourcePairsDeg(:)) + 20);
candidateAnglesDeg = minAngle:strideDeg:maxAngle;
candidateAnglesDeg = unique([candidateAnglesDeg(:); case11Cfg.sourcePairsDeg(:)]).';
end

function local_plot_case11_backend_summary(caseResult, outDir)
backendLabels = local_case11_display_labels(caseResult.backendNames);
methodLabels = local_case11_display_labels(caseResult.methodLabels);
meanResolution = local_case11_backend_method_mean(caseResult.resolutionRate);
meanStable = local_case11_backend_method_mean(caseResult.stableRate);

local_plot_case11_backend_metric(backendLabels, methodLabels, meanResolution, ...
    'Resolution rate', 'Backend resolution rate', [0 1], ...
    fullfile(outDir, 'backend_resolution_summary.png'));
local_plot_case11_backend_metric(backendLabels, methodLabels, meanStable, ...
    'Stable rate', 'Backend stable rate', [0 1], ...
    fullfile(outDir, 'backend_stable_summary.png'));
local_plot_case11_oracle_ceiling(backendLabels, caseResult.summary, ...
    fullfile(outDir, 'backend_oracle_ceiling.png'));
end

function local_plot_case11_backend_metric(backendLabels, methodLabels, values, ylabelText, titleText, yLimits, filePath)
fig = figure('Visible', 'off', 'Position', [120 120 980 560]);
local_case11_bar(backendLabels, values);
grid on;
if ~isempty(yLimits)
    ylim(yLimits);
end
ylabel(ylabelText);
title(titleText, 'FontWeight', 'bold');
set(gca, 'TickLabelInterpreter', 'none');
if numel(methodLabels) > 1
    legend(methodLabels, 'Location', 'bestoutside', 'Interpreter', 'none');
end
save_figure(fig, filePath);
end

function local_plot_case11_oracle_ceiling(backendLabels, summary, filePath)
oracleGain = local_case11_summary_vector(summary, 'oracleGainOverMusic', numel(backendLabels));
v3Gap = local_case11_summary_vector(summary, 'v3ToOracleGap', numel(backendLabels));
plotValues = [oracleGain(:), v3Gap(:)];

fig = figure('Visible', 'off', 'Position', [140 140 980 560]);
local_case11_bar(backendLabels, plotValues);
grid on;
ylabel('Resolution-rate delta');
title('Oracle backend gain and V3-to-oracle gap', 'FontWeight', 'bold');
set(gca, 'TickLabelInterpreter', 'none');
legend({'Oracle gain over MUSIC', 'V3 gap to oracle'}, ...
    'Location', 'bestoutside', 'Interpreter', 'none');
save_figure(fig, filePath);
end

function metricMean = local_case11_backend_method_mean(metric)
metricMean = reshape(mean(metric, 2), [size(metric, 1), size(metric, 3)]);
end

function values = local_case11_summary_vector(summary, fieldName, expectedCount)
values = NaN(expectedCount, 1);
if isstruct(summary) && isfield(summary, fieldName) && ~isempty(summary.(fieldName))
    rawValues = summary.(fieldName);
    copyCount = min(numel(rawValues), expectedCount);
    values(1:copyCount) = rawValues(1:copyCount);
end
end

function local_case11_bar(backendLabels, values)
if isempty(values)
    bar(categorical(backendLabels), values);
elseif size(values, 2) == 1
    bar(categorical(backendLabels), values(:, 1));
else
    bar(categorical(backendLabels), values);
end
end

function labels = local_case11_display_labels(labels)
for labelIdx = 1:numel(labels)
    labelText = char(labels{labelIdx});
    switch labelText
        case 'music'
            labelText = 'MUSIC';
        case 'music_pair_rescore'
            labelText = 'MUSIC pair rescore';
        case 'pairwise_grid_ml'
            labelText = 'Pairwise grid ML';
        case 'proposed_v3'
            labelText = 'Proposed V3.3';
        case 'proposed_v1'
            labelText = 'Proposed V1';
        case 'ard'
            labelText = 'ARD';
        case 'oracle'
            labelText = 'HFSS Oracle';
        otherwise
            labelText = strrep(labelText, '_', ' ');
    end
    labels{labelIdx} = labelText;
end
end

function caseResult = case12_core_1to3_source_mainline(cfg, ctx)
rng(cfg.randomSeed + 12, 'twister');
outDir = local_case_output_dir(cfg, 'case12_core_1to3_source_mainline');

calIdx = select_calibration_indices(ctx.thetaDeg, cfg.case3.representativeL, 'uniform');
models = build_sparse_models(ctx, calIdx, cfg.model);
methods = local_named_methods(ctx, models, cfg.core.methodKeys);

caseResult = struct();
caseResult.outputDir = outDir;
caseResult.coreConfig = cfg.core;
caseResult.methodLabels = {methods.label};
caseResult.methodNames = {methods.name};
caseResult.calibrationAnglesDeg = ctx.thetaDeg(calIdx);
caseResult.manifoldSanity = local_core_manifold_sanity(ctx, methods);
caseResult.singleSource = local_core_source_run(ctx, methods, cfg, 1, ...
    cfg.core.singleSourceAnglesDeg(:));
caseResult.twoSource = local_core_source_run(ctx, methods, cfg, 2, ...
    cfg.core.twoSourcePairsDeg);
caseResult.threeSource = local_core_source_run(ctx, methods, cfg, 3, ...
    cfg.core.threeSourceSetsDeg);
caseResult.backendAblation = local_core_backend_ablation(ctx, methods, cfg);

local_plot_case12_core_summary(caseResult, outDir);
local_plot_case12_representative_spectra(caseResult, outDir);
local_plot_case12_paper_figures(caseResult, outDir);
save(fullfile(outDir, 'case12_results.mat'), 'caseResult');
end

function sanity = local_core_manifold_sanity(ctx, methods)
numMethods = numel(methods);
meanRelativeError = zeros(1, numMethods);
maxRelativeError = zeros(1, numMethods);
meanCorrelationLoss = zeros(1, numMethods);
for methodIdx = 1:numMethods
    metrics = compute_manifold_metrics(ctx.AH, methods(methodIdx).manifold);
    meanRelativeError(methodIdx) = mean(metrics.relativeError);
    maxRelativeError(methodIdx) = max(metrics.relativeError);
    meanCorrelationLoss(methodIdx) = mean(1 - metrics.correlation);
end
sanity = struct();
sanity.methodLabels = {methods.label};
sanity.methodNames = {methods.name};
sanity.meanRelativeError = meanRelativeError;
sanity.maxRelativeError = maxRelativeError;
sanity.meanCorrelationLoss = meanCorrelationLoss;
end

function result = local_core_source_run(ctx, methods, cfg, numSources, trueAngleSetsDeg)
evalCfg = struct();
evalCfg.numSources = numSources;
evalCfg.trueAngles = trueAngleSetsDeg;
evalCfg.snrDb = cfg.core.evalSNRDb;
evalCfg.snapshots = cfg.core.snapshots;
evalCfg.monteCarlo = cfg.core.monteCarlo;
evalCfg.toleranceDeg = 1.0;
evalCfg.backendName = cfg.core.backendName;
evalCfg.threeSourceBackendName = cfg.core.threeSourceBackendName;

backendCfg = local_core_backend_cfg(cfg.core, ctx.thetaDeg, trueAngleSetsDeg, numSources);
result = benchmark_core_sources(ctx, methods, evalCfg, backendCfg);
result.backendCfg = backendCfg;
end

function backendCfg = local_core_backend_cfg(coreCfg, thetaDeg, angleSetsDeg, numSources)
if numSources == 3
    strideDeg = local_optional_config_value(coreCfg, 'threeSourceCandidateAngleStrideDeg', ...
        coreCfg.backendCandidateAngleStrideDeg);
else
    strideDeg = coreCfg.backendCandidateAngleStrideDeg;
end
if isempty(strideDeg) || strideDeg <= 0
    strideDeg = 1;
end
minAngle = max(min(thetaDeg), min(angleSetsDeg(:)) - 18);
maxAngle = min(max(thetaDeg), max(angleSetsDeg(:)) + 18);
candidateAnglesDeg = minAngle:strideDeg:maxAngle;
candidateAnglesDeg = unique([candidateAnglesDeg(:); angleSetsDeg(:)]).';

backendCfg = struct();
backendCfg.candidateAnglesDeg = candidateAnglesDeg;
backendCfg.minimumSeparationDeg = coreCfg.backendMinimumSeparationDeg;
backendCfg.maximumSeparationDeg = coreCfg.backendMaximumSeparationDeg;
backendCfg.topCandidateCount = coreCfg.topCandidateCount;
backendCfg.numSources = numSources;
backendCfg.scanAnglesDeg = thetaDeg;
end

function value = local_optional_config_value(inputStruct, fieldName, defaultValue)
if isfield(inputStruct, fieldName) && ~isempty(inputStruct.(fieldName))
    value = inputStruct.(fieldName);
else
    value = defaultValue;
end
end

function backendResult = local_core_backend_ablation(ctx, methods, cfg)
evalCfg = struct();
evalCfg.mode = 'double';
evalCfg.trueAngles = cfg.core.twoSourcePairsDeg;
evalCfg.snrDb = cfg.core.evalSNRDb;
evalCfg.snapshots = cfg.core.snapshots;
evalCfg.monteCarlo = cfg.core.monteCarlo;
evalCfg.toleranceDeg = 1.0;
evalCfg.biasedToleranceDeg = cfg.case9.biasedToleranceDeg;
evalCfg.marginalToleranceDeg = cfg.case9.marginalToleranceDeg;
evalCfg.collectRepresentative = true;

backendCfg = local_core_backend_cfg(cfg.core, ctx.thetaDeg, cfg.core.twoSourcePairsDeg, 2);
backendCfg.backendNames = {'music', 'music_pair_rescore', 'pairwise_grid_ml'};
backendCfg.candidatePeakCount = 12;
backendResult = benchmark_doa_backends(ctx, methods, evalCfg, backendCfg);
end

function local_plot_case12_core_summary(caseResult, outDir)
methodLabels = local_case11_display_labels(caseResult.methodLabels);
rmseValues = [caseResult.singleSource.summary.meanRmse(:), ...
    caseResult.twoSource.summary.meanRmse(:), ...
    caseResult.threeSource.summary.meanRmse(:)];
resolvedValues = [caseResult.singleSource.summary.meanResolvedRate(:), ...
    caseResult.twoSource.summary.meanResolvedRate(:), ...
    caseResult.threeSource.summary.meanResolvedRate(:)];

fig = figure('Visible', 'off', 'Position', [120 120 1180 520]);
bar(categorical(methodLabels), rmseValues);
grid on;
ylabel('Mean RMSE (deg)');
title('Case 12: Core 1/2/3-source RMSE', 'FontWeight', 'bold');
legend({'1 source', '2 sources', '3 sources'}, 'Location', 'bestoutside');
set(gca, 'TickLabelInterpreter', 'none');
save_figure(fig, fullfile(outDir, 'core_rmse_summary.png'));

fig = figure('Visible', 'off', 'Position', [120 120 1180 520]);
bar(categorical(methodLabels), resolvedValues);
grid on;
ylim([0 1]);
ylabel('Resolved rate');
title('Case 12: Core 1/2/3-source resolved rate', 'FontWeight', 'bold');
legend({'1 source', '2 sources', '3 sources'}, 'Location', 'bestoutside');
set(gca, 'TickLabelInterpreter', 'none');
save_figure(fig, fullfile(outDir, 'core_resolved_summary.png'));
end

function local_plot_case12_representative_spectra(caseResult, outDir)
local_plot_case12_spectrum(caseResult.twoSource, 'Case 12: two-source representative spectrum', ...
    fullfile(outDir, 'core_two_source_spectrum.png'));
local_plot_case12_three_source_spectrum(caseResult.threeSource, ...
    fullfile(outDir, 'core_three_source_spectrum.png'));
end

function local_plot_case12_paper_figures(caseResult, outDir)
methodLabels = local_case11_display_labels(caseResult.methodLabels);
rmseValues = [caseResult.singleSource.summary.meanRmse(:), ...
    caseResult.twoSource.summary.meanRmse(:), ...
    caseResult.threeSource.summary.meanRmse(:)];
resolvedValues = [caseResult.singleSource.summary.meanResolvedRate(:), ...
    caseResult.twoSource.summary.meanResolvedRate(:), ...
    caseResult.threeSource.summary.meanResolvedRate(:)];

local_plot_case12_paper_metric(methodLabels, caseResult.methodNames, rmseValues, ...
    'Mean RMSE (deg)', 'Case 12: core RMSE by source count', ...
    fullfile(outDir, 'paper_core_rmse_ranked.png'), []);
local_plot_case12_paper_metric(methodLabels, caseResult.methodNames, resolvedValues, ...
    'Resolved rate', 'Case 12: core resolved rate by source count', ...
    fullfile(outDir, 'paper_core_resolved_ranked.png'), [0 1]);
local_plot_case12_paper_three_source_spectrum(caseResult.threeSource, ...
    fullfile(outDir, 'paper_three_source_spectrum.png'));
end

function local_plot_case12_paper_metric(methodLabels, methodNames, values, ylabelText, titleText, filePath, yLimits)
fig = figure('Visible', 'off', 'Position', [120 120 1180 560]);
hold on;
sourceLabels = {'1 source', '2 sources', '3 sources'};
markers = {'o', 's', '^'};
lineStyles = {'-', '--', '-.'};
xBase = 1:numel(methodLabels);
xOffsets = [-0.12, 0, 0.12];
colors = lines(3);
for sourceIdx = 1:3
    plot(xBase + xOffsets(sourceIdx), values(:, sourceIdx), ...
        'LineStyle', lineStyles{sourceIdx}, 'Marker', markers{sourceIdx}, ...
        'LineWidth', 1.8, 'MarkerSize', 7, 'Color', colors(sourceIdx, :));
end
grid on;
xlim([0.5, numel(methodLabels) + 0.5]);
if ~isempty(yLimits)
    ylim(yLimits);
else
    ylim([0, max(values(:)) * 1.08]);
end
set(gca, 'XTick', xBase, 'XTickLabel', methodLabels, 'TickLabelInterpreter', 'none');
xtickangle(25);
ylabel(ylabelText);
title(titleText, 'FontWeight', 'bold');
legend(sourceLabels, 'Location', 'bestoutside');
local_annotate_case12_metric_values(xBase, xOffsets, values, methodNames);
save_figure(fig, filePath);
end

function local_annotate_case12_metric_values(xBase, xOffsets, values, methodNames)
v3Idx = find(strcmp(methodNames, 'proposed_v3'), 1, 'first');
oracleIdx = find(strcmp(methodNames, 'oracle'), 1, 'first');
excluded = strcmp(methodNames, 'ideal') | strcmp(methodNames, 'oracle');
isRatePlot = all(values(:) >= 0) && all(values(:) <= 1);
for sourceIdx = 1:size(values, 2)
    candidates = values(:, sourceIdx);
    candidates(excluded(:)) = NaN;
    if isRatePlot
        [~, bestIdx] = max(candidates);
    else
        [~, bestIdx] = min(candidates);
    end
    annotateIdx = unique([v3Idx, oracleIdx, bestIdx], 'stable');
    annotateIdx = annotateIdx(~isnan(annotateIdx) & annotateIdx > 0);
    for idx = reshape(annotateIdx, 1, [])
        value = values(idx, sourceIdx);
        if ~isfinite(value)
            continue;
        end
        text(xBase(idx) + xOffsets(sourceIdx), value, sprintf(' %.3g', value), ...
            'FontSize', 8, 'Rotation', 35, 'VerticalAlignment', 'bottom', ...
            'HorizontalAlignment', 'left');
    end
end
end

function local_plot_case12_spectrum(sourceResult, titleText, filePath)
fig = figure('Visible', 'off', 'Position', [120 120 1080 560]);
hold on;
trueAngles = sort(sourceResult.trueAngleSetsDeg(1, :));
for methodIdx = 1:numel(sourceResult.methodLabels)
    spectrum = sourceResult.representative(methodIdx).spectrum;
    if isempty(spectrum)
        continue;
    end
    spectrumDb = 10 * log10(real(spectrum) ./ max(real(spectrum)));
    plot(sourceResult.backendCfg.scanAnglesDeg, spectrumDb, 'LineWidth', 1.5);
end
local_plot_case12_truth_lines(trueAngles);
grid on;
xlabel('Angle (deg)');
ylabel('Normalized MUSIC spectrum (dB)');
title(titleText, 'FontWeight', 'bold');
legend(local_case11_display_labels(sourceResult.methodLabels), ...
    'Location', 'bestoutside', 'Interpreter', 'none');
ylim([-40 1]);
save_figure(fig, filePath);
end

function local_plot_case12_three_source_spectrum(sourceResult, filePath)
fig = figure('Visible', 'off', 'Position', [120 120 1180 720]);
layout = tiledlayout(2, 1, 'Padding', 'compact', 'TileSpacing', 'compact');
trueAngles = sort(sourceResult.trueAngleSetsDeg(1, :));
colors = lines(numel(sourceResult.methodLabels));

nexttile;
hold on;
for methodIdx = 1:numel(sourceResult.methodLabels)
    spectrum = sourceResult.representative(methodIdx).spectrum;
    if isempty(spectrum)
        continue;
    end
    spectrumDb = 10 * log10(real(spectrum) ./ max(real(spectrum)));
    plot(sourceResult.backendCfg.scanAnglesDeg, spectrumDb, 'LineWidth', 1.5, ...
        'Color', colors(methodIdx, :));
    local_plot_case12_estimated_markers(sourceResult.representative(methodIdx).estAnglesDeg, ...
        colors(methodIdx, :), -38, methodIdx);
end
local_plot_case12_truth_lines(trueAngles);
grid on;
xlabel('Angle (deg)');
ylabel('Normalized MUSIC spectrum (dB)');
ylim([-40 1]);
title('MUSIC pseudo-spectrum', 'FontWeight', 'bold');

nexttile;
hold on;
for methodIdx = 1:numel(sourceResult.methodLabels)
    diagnostics = sourceResult.representative(methodIdx).diagnostics;
    if ~isfield(diagnostics, 'marginalAnglesDeg') || ...
            ~isfield(diagnostics, 'marginalConfidence')
        continue;
    end
    marginalConfidence = diagnostics.marginalConfidence(:).';
    plot(diagnostics.marginalAnglesDeg, marginalConfidence, ...
        'o-', 'LineWidth', 1.5, 'MarkerSize', 4, 'Color', colors(methodIdx, :));
    finiteConfidence = marginalConfidence(isfinite(marginalConfidence));
    if isempty(finiteConfidence)
        markerY = NaN;
    else
        markerY = min(finiteConfidence);
    end
    local_plot_case12_estimated_markers(sourceResult.representative(methodIdx).estAnglesDeg, ...
        colors(methodIdx, :), markerY, methodIdx);
end
local_plot_case12_truth_lines(trueAngles);
grid on;
xlabel('Angle (deg)');
ylabel('Triplet marginal confidence');
title('Triplet-grid backend marginal confidence', 'FontWeight', 'bold');

legend(local_case11_display_labels(sourceResult.methodLabels), ...
    'Location', 'bestoutside', 'Interpreter', 'none');
title(layout, 'Case 12: three-source MUSIC spectrum + triplet-grid backend marginal score', ...
    'FontWeight', 'bold');
save_figure(fig, filePath);
end

function local_plot_case12_paper_three_source_spectrum(sourceResult, filePath)
selectedNames = {'ard', 'proposed_v3', 'oracle', 'ideal'};
selectedIdx = local_case12_method_indices(sourceResult.methodNames, selectedNames);
fig = figure('Visible', 'off', 'Position', [120 120 1180 720]);
layout = tiledlayout(2, 1, 'Padding', 'compact', 'TileSpacing', 'compact');
trueAngles = sort(sourceResult.trueAngleSetsDeg(1, :));
xWindow = [max(min(sourceResult.backendCfg.scanAnglesDeg), min(trueAngles) - 10), ...
    min(max(sourceResult.backendCfg.scanAnglesDeg), max(trueAngles) + 10)];
[colors, lineStyles, markers] = local_case12_paper_styles(numel(selectedIdx));

nexttile;
hold on;
for plotIdx = 1:numel(selectedIdx)
    methodIdx = selectedIdx(plotIdx);
    spectrum = sourceResult.representative(methodIdx).spectrum;
    if isempty(spectrum)
        continue;
    end
    spectrumDb = 10 * log10(real(spectrum) ./ max(real(spectrum)));
    spectrumDb = local_case12_smooth_vector(spectrumDb, 5);
    plot(sourceResult.backendCfg.scanAnglesDeg, spectrumDb, ...
        'LineStyle', lineStyles{plotIdx}, 'Marker', 'none', 'LineWidth', 2.0, ...
        'Color', colors(plotIdx, :));
    local_plot_case12_estimated_markers(sourceResult.representative(methodIdx).estAnglesDeg, ...
        colors(plotIdx, :), -34, plotIdx);
end
local_plot_case12_truth_lines(trueAngles);
grid on;
xlim(xWindow);
ylim([-36 1]);
xlabel('Angle (deg)');
ylabel('Smoothed MUSIC spectrum (dB)');
title('Display-smoothed MUSIC pseudo-spectrum', 'FontWeight', 'bold');

nexttile;
hold on;
for plotIdx = 1:numel(selectedIdx)
    methodIdx = selectedIdx(plotIdx);
    diagnostics = sourceResult.representative(methodIdx).diagnostics;
    if ~isfield(diagnostics, 'marginalAnglesDeg') || ...
            ~isfield(diagnostics, 'marginalConfidence')
        continue;
    end
    marginalConfidence = diagnostics.marginalConfidence(:).';
    plot(diagnostics.marginalAnglesDeg, marginalConfidence, ...
        'LineStyle', lineStyles{plotIdx}, 'Marker', markers{plotIdx}, ...
        'LineWidth', 2.0, 'MarkerSize', 5, 'Color', colors(plotIdx, :));
    finiteConfidence = marginalConfidence(isfinite(marginalConfidence));
    if isempty(finiteConfidence)
        markerY = NaN;
    else
        markerY = min(finiteConfidence);
    end
    local_plot_case12_estimated_markers(sourceResult.representative(methodIdx).estAnglesDeg, ...
        colors(plotIdx, :), markerY, plotIdx);
end
local_plot_case12_truth_lines(trueAngles);
grid on;
xlim(xWindow);
xlabel('Angle (deg)');
ylabel('Triplet marginal confidence');
title('Backend-consistent triplet marginal confidence', 'FontWeight', 'bold');

legend(local_case11_display_labels(sourceResult.methodLabels(selectedIdx)), ...
    'Location', 'bestoutside', 'Interpreter', 'none');
title(layout, 'Case 12: paper-readable three-source spectrum diagnostic', ...
    'FontWeight', 'bold');
save_figure(fig, filePath);
end

function selectedIdx = local_case12_method_indices(methodNames, selectedNames)
selectedIdx = zeros(1, 0);
for nameIdx = 1:numel(selectedNames)
    matchIdx = find(strcmp(methodNames, selectedNames{nameIdx}), 1, 'first');
    if ~isempty(matchIdx)
        selectedIdx(end+1) = matchIdx; %#ok<AGROW>
    end
end
end

function [colors, lineStyles, markers] = local_case12_paper_styles(numSeries)
baseColors = [ ...
    0.0000 0.4470 0.7410; ...
    0.8500 0.3250 0.0980; ...
    0.4660 0.6740 0.1880; ...
    0.4940 0.1840 0.5560];
colors = baseColors(1:numSeries, :);
lineStyles = {'-', '--', '-.', ':'};
markers = {'o', 's', '^', 'd'};
end

function smoothed = local_case12_smooth_vector(values, windowLength)
values = values(:).';
if windowLength <= 1 || numel(values) < windowLength
    smoothed = values;
    return;
end
kernel = ones(1, windowLength) / windowLength;
smoothed = conv(values, kernel, 'same');
end

function local_plot_case12_truth_lines(trueAngles)
for angleIdx = 1:numel(trueAngles)
    xline(trueAngles(angleIdx), '--k', 'LineWidth', 1.0, 'HandleVisibility', 'off');
end
end

function local_plot_case12_estimated_markers(estAnglesDeg, colorValue, yValue, methodIdx)
if isempty(estAnglesDeg) || ~isfinite(yValue)
    return;
end
estAnglesDeg = sort(estAnglesDeg(:).');
yOffset = 0.03 * methodIdx;
for angleIdx = 1:numel(estAnglesDeg)
    plot(estAnglesDeg(angleIdx), yValue + yOffset, 'v', ...
        'Color', colorValue, 'MarkerFaceColor', colorValue, ...
        'MarkerSize', 5, 'HandleVisibility', 'off');
end
end

function outDir = local_case_output_dir(cfg, caseFolderName)
if cfg.run.useTraceableDirs
    if ~isfield(cfg.run, 'runId') || isempty(cfg.run.runId)
        error('cfg.run.runId is required when cfg.run.useTraceableDirs is true.');
    end
    outDir = fullfile(local_version_output_dir(cfg), caseFolderName);
else
    outDir = fullfile(cfg.outputDir, caseFolderName);
end
if ~exist(outDir, 'dir')
    mkdir(outDir);
elseif cfg.run.useTraceableDirs && local_case_output_has_results(outDir)
    error('Traceable output directory already contains result files: %s', outDir);
end
end

function hasResults = local_case_output_has_results(outDir)
matFiles = dir(fullfile(outDir, '*.mat'));
pngFiles = dir(fullfile(outDir, '*.png'));
hasResults = ~isempty(matFiles) || ~isempty(pngFiles);
end

function versionDir = local_version_output_dir(cfg)
versionDir = fullfile(cfg.run.resultRoot, cfg.run.runId);
end

function local_prepare_version_output(cfg)
versionDir = local_version_output_dir(cfg);
if exist(versionDir, 'dir') && local_version_output_has_results(versionDir)
    error('Traceable version directory already contains result files: %s', versionDir);
end
if ~exist(versionDir, 'dir')
    mkdir(versionDir);
end
local_write_run_notes(versionDir, cfg);
local_write_manifest(cfg, {}, []);
end

function hasResults = local_version_output_has_results(versionDir)
matFiles = dir(fullfile(versionDir, '**', '*.mat'));
pngFiles = dir(fullfile(versionDir, '**', '*.png'));
manifestFile = fullfile(versionDir, 'manifest.md');
hasResults = ~isempty(matFiles) || ~isempty(pngFiles) || exist(manifestFile, 'file');
end

function local_write_run_notes(versionDir, cfg)
notesPath = fullfile(versionDir, 'RUN_NOTES.md');
if exist(notesPath, 'file')
    return;
end

fid = fopen(notesPath, 'w');
if fid < 0
    error('Unable to write RUN_NOTES.md in %s', versionDir);
end
cleanupObj = onCleanup(@() fclose(fid));

fprintf(fid, '# Run Notes\n\n');
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
fprintf(fid, '- Case 9 discriminative minimum separation deg: `%.12g`\n\n', ...
    cfg.case9.discriminativeMinSeparationDeg);
fprintf(fid, '- MUSIC snapshot policy: `common_truth_snapshots_across_methods`\n\n');
if isfield(cfg, 'core')
    fprintf(fid, '## Case 12 Core 1/2/3-Source Mainline\n\n');
    fprintf(fid, '- Enabled blocks: `%s`\n', local_config_list_text(cfg.core.enabledCases));
    fprintf(fid, '- Monte Carlo: `%d`\n', cfg.core.monteCarlo);
    fprintf(fid, '- Snapshots: `%d`\n', cfg.core.snapshots);
    fprintf(fid, '- Evaluation SNR dB: `%.12g`\n', cfg.core.evalSNRDb);
    fprintf(fid, '- Two-source backend: `%s`\n', cfg.core.backendName);
    fprintf(fid, '- Three-source backend: `%s`\n', cfg.core.threeSourceBackendName);
    fprintf(fid, '- Candidate angle stride deg: `%.12g`\n', cfg.core.backendCandidateAngleStrideDeg);
    if isfield(cfg.core, 'threeSourceCandidateAngleStrideDeg')
        fprintf(fid, '- Three-source candidate angle stride deg: `%.12g`\n', ...
            cfg.core.threeSourceCandidateAngleStrideDeg);
    end
    fprintf(fid, '- Caveat: `Case 12 is a compact structure diagnostic for RMSE and spectra, not a full paper-profile run.`\n\n');
end
if isfield(cfg, 'case11')
    fprintf(fid, '## Case 11 Backend Diagnostic\n\n');
    fprintf(fid, '- Source pairs deg: `%s`\n', mat2str(cfg.case11.sourcePairsDeg));
    fprintf(fid, '- Monte Carlo: `%d`\n', cfg.case11.monteCarlo);
    fprintf(fid, '- Backend names: `%s`\n', local_config_list_text(cfg.case11.backendNames));
    fprintf(fid, '- Method keys: `%s`\n', local_config_list_text(cfg.case11.methodKeys));
    fprintf(fid, '- Candidate peak count: `%d`\n', cfg.case11.candidatePeakCount);
    fprintf(fid, '- Candidate angle stride deg: `%.12g`\n', cfg.case11.candidateAngleStrideDeg);
    fprintf(fid, '- Minimum separation deg: `%.12g`\n', cfg.case11.minimumSeparationDeg);
    fprintf(fid, '- Maximum separation deg: `%.12g`\n', cfg.case11.maximumSeparationDeg);
    fprintf(fid, '- Top candidate count: `%d`\n', cfg.case11.topCandidateCount);
    fprintf(fid, '- Caveat: `Case 11 is diagnostic-only backend screening evidence, not final paper-profile evidence unless stated.`\n\n');
end
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
if isfield(cfg, 'model') && isfield(cfg.model, 'v3')
fprintf(fid, '- Proposed V3 enabled: `%d`\n', logical(cfg.model.v3.enabled));
fprintf(fid, '- Proposed V3 label: `%s`\n', cfg.model.v3.label);
fprintf(fid, '- Proposed V3 stage: `%s`\n', cfg.model.v3.stage);
fprintf(fid, '- Proposed V3 base: `%s`\n', cfg.model.v3.base);
fprintf(fid, '- Proposed V3 task data mode: `%s`\n', cfg.model.v3.taskDataMode);
fprintf(fid, '- Proposed V3 pair objective: `%s`\n', cfg.model.v3.pairObjectiveMode);
fprintf(fid, '- Proposed V3 pair selection: `%s`\n', cfg.model.v3.taskPairSelectionMode);
fprintf(fid, '- Proposed V3 SPSA iterations: `%d`\n', cfg.model.v3.numSpsaIterations);
fprintf(fid, '- Proposed V3 anchor weight: `%.12g`\n', cfg.model.v3.lambdaAnchor);
fprintf(fid, '- Proposed V3 guard weight: `%.12g`\n', cfg.model.v3.lambdaGuard);
fprintf(fid, '- Proposed V3 trust radius rad: `%.12g`\n', cfg.model.v3.trustRadiusRad);
fprintf(fid, '- Proposed V3 task SNR dB: `%.12g`\n', cfg.model.v3.taskSnrDb);
fprintf(fid, '- Proposed V3 stable score mode: `%s`\n', cfg.model.v3.stableScoreMode);
fprintf(fid, '- Proposed V3 stable background mode: `%s`\n', cfg.model.v3.stableBackgroundMode);
fprintf(fid, '- Proposed V3 note: `V3.3 case9-aligned global stable-pair residual; screening result, not final full paper-profile evidence unless stated.`\n\n');
end
fprintf(fid, '## Git Status Short\n\n');
fprintf(fid, '```text\n%s\n```\n', cfg.run.gitStatusShort);
end

function text = local_config_list_text(values)
if iscell(values)
    parts = cell(size(values));
    for idx = 1:numel(values)
        parts{idx} = local_config_scalar_text(values{idx});
    end
    text = strjoin(parts(:).', ', ');
elseif isstring(values)
    text = strjoin(cellstr(values(:).'), ', ');
elseif ischar(values)
    text = values;
else
    text = mat2str(values);
end
end

function text = local_config_scalar_text(value)
if isstring(value) || ischar(value)
    text = char(value);
else
    text = mat2str(value);
end
end

function local_write_manifest(cfg, completedCaseFolders, selectedCases)
manifestPath = fullfile(local_version_output_dir(cfg), 'manifest.md');
fid = fopen(manifestPath, 'w');
if fid < 0
    error('Unable to write manifest.md in %s', local_version_output_dir(cfg));
end
cleanupObj = onCleanup(@() fclose(fid));

fprintf(fid, '# Results manifest\n\n');
fprintf(fid, '- Version hash: `%s`\n', cfg.run.pendingLocalHash);
fprintf(fid, '- Base HEAD: `%s`\n', cfg.run.baseHead);
if isempty(strtrim(cfg.run.gitStatusShort))
    fprintf(fid, '- Worktree state: clean or not recorded\n');
else
    fprintf(fid, '- Worktree state: uncommitted code changes recorded in `RUN_NOTES.md`\n');
end
fprintf(fid, '- Command: `%s`\n\n', cfg.run.command);

fprintf(fid, '## Cases\n\n');
if isempty(completedCaseFolders)
    fprintf(fid, '- No case outputs completed yet.\n');
else
    for idx = 1:numel(completedCaseFolders)
        fprintf(fid, '- `%s`: outputs in `%s/`\n', completedCaseFolders{idx}, completedCaseFolders{idx});
    end
end

if ~isempty(selectedCases) && numel(completedCaseFolders) < numel(selectedCases)
    fprintf(fid, '\n## Not run or not completed\n\n');
    fprintf(fid, '- Remaining selected cases had not completed when this manifest was written.\n');
end
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
if ~isfield(cfg.model, 'v3') || isempty(cfg.model.v3)
    cfg.model.v3 = struct();
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
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'enabled', true);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'label', 'Proposed V3.3');
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'base', 'ard');
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'stage', 'case9_aligned_global_stable_refinement');
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'segmentCentersDeg', [-50 0 50]);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'order', 1);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'lambda', 1e-3);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'pairTaskEnabled', true);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'taskDataMode', 'heldout_hfss');
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'taskScanStrideDeg', 1);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'taskSingleHeldoutCount', 12);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'taskPairSeparationDeg', [4 5 6 8 10]);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'taskPairCount', 20);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'taskPairSelectionMode', 'distribution_matched');
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'taskPairCenterBinDeg', 10);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'guardHeldoutCount', 64);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'taskSnrDb', 5);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'numSpsaIterations', 8);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'learningRate', 0.004);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'perturbationScale', 0.004);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'maxGradNorm', 5);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'lambdaCal', 1);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'lambdaSingle', 0.02);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'lambdaPair', 0.08);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'lambdaMid', 0);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'lambdaAnchor', 50);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'lambdaGuard', 10);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'lambdaCal0', 20);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'lambdaSmooth', 1e-3);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'lambdaReg', 1e-4);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'softmaxGamma', 8);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'midMargin', 0.2);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'pairObjectiveMode', 'stable_neighborhood');
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'stableNeighborhoodDeg', 0.6);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'stableScoreMode', 'peak');
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'stableBackgroundMode', 'global_competitor');
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'stableBackgroundWindowDeg', 4);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'stableEndpointFloor', -2.5);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'stableMidMargin', 0.15);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'stableBackgroundMargin', 0.10);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'stableBalanceMargin', 0.15);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'stableEtaSub', 1);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'stableEtaEnd', 1);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'stableEtaMid', 1);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'stableEtaBg', 0.5);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'stableEtaBalance', 0.5);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'trustRadiusRad', 0.04);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'calibrationNullSigmaDeg', 0.25);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'edgeMaskEnabled', true);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'edgeMaskStartDeg', 35);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'edgeMaskTransitionDeg', 6);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'edgeMaskMinimum', 0.25);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'maxCalibrationDrift', 1e-3);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'guardRelativeTolerance', 0.003);
cfg.model.v3 = local_set_default_field(cfg.model.v3, 'maxAnchorRmsDrift', 0.02);

if isfield(cfg, 'case9')
    cfg.case9 = local_set_default_field(cfg.case9, 'maxPairsPerSeparation', 21);
    cfg.case9 = local_set_default_field(cfg.case9, 'separationSweepDeg', [1 2 3 4 5 6 8 10]);
    cfg.case9 = local_set_default_field(cfg.case9, 'discriminativeMinSeparationDeg', 6);
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

function local_add_truth_scan_sgtitle(mainTitle, subtitle)
if nargin < 2 || isempty(subtitle)
    subtitle = 'HFSS truth snapshots; MUSIC scan uses the listed estimator manifolds';
end
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
    [sourcePairs, pairSelection] = case09_helpers('source_pairs', caseCfg, ctx, calAnglesDeg);
    pairSelection.mode = ['case4_' pairSelection.mode];
    return;
end

if ~isfield(caseCfg, 'sourcePairsDeg') || isempty(caseCfg.sourcePairsDeg)
    error('Case 4 requires either separationSweepDeg or sourcePairsDeg.');
end

sourcePairs = case09_helpers('filter_pairs', caseCfg.sourcePairsDeg, ctx.thetaDeg, calAnglesDeg);
if isempty(sourcePairs)
    sourcePairs = case09_helpers('filter_pairs', caseCfg.sourcePairsDeg, ctx.thetaDeg);
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
        case 'proposed_v3'
            methodLabel = 'Proposed V3.3';
            if isfield(models, 'v3Diagnostics') && isfield(models.v3Diagnostics, 'label') && ...
                    ~isempty(models.v3Diagnostics.label)
                methodLabel = models.v3Diagnostics.label;
            end
            methods(methodIdx) = local_method('proposed_v3', methodLabel, models.AProposedV3);
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

function [taskPairsDeg, v2TaskPairsDeg, v3TaskPairsDeg] = local_task_pairs_from_models(models)
v2TaskPairsDeg = local_diagnostic_task_pairs(models, 'v2Diagnostics');
v3TaskPairsDeg = local_diagnostic_task_pairs(models, 'v3Diagnostics');
taskPairsDeg = [v2TaskPairsDeg; v3TaskPairsDeg];
if ~isempty(taskPairsDeg)
    taskPairsDeg = unique(sort(round(taskPairsDeg, 10), 2), 'rows', 'stable');
end
end

function taskPairsDeg = local_diagnostic_task_pairs(models, diagnosticField)
taskPairsDeg = zeros(0, 2);
if isfield(models, diagnosticField)
    diagnostic = models.(diagnosticField);
    if isfield(diagnostic, 'taskPairsDeg') && ~isempty(diagnostic.taskPairsDeg)
        taskPairsDeg = unique(sort(round(diagnostic.taskPairsDeg, 10), 2), 'rows', 'stable');
    end
end
end

function [xValues, yValues] = local_box_inputs(dataMatrix, labels)
numSamples = size(dataMatrix, 1);

xValues = categorical(repelem(labels, numSamples));
yValues = reshape(dataMatrix, [], 1);
end
