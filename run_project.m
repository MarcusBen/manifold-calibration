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

if ~exist(cfg.outputDir, 'dir')
    mkdir(cfg.outputDir);
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

exampleAngle = cfg.case1.exampleAngleDeg;
methods = [ ...
    local_method('ideal', 'Ideal', ctx.AI), ...
    local_method('oracle', 'HFSS Oracle', ctx.AH)];

evalCfg = struct();
evalCfg.mode = 'single';
evalCfg.trueAngles = exampleAngle;
evalCfg.snrDb = cfg.case1.highSNRDb;
evalCfg.snapshots = cfg.case1.snapshots;
evalCfg.monteCarlo = 1;
evalCfg.toleranceDeg = cfg.case1.toleranceDeg;
evalCfg.collectRepresentativeSpectrum = true;
exampleSpectrum = benchmark_music(ctx, methods, evalCfg);

fig = figure('Visible', 'off', 'Position', [140 140 1100 500]);
hold on;
for methodIdx = 1:numel(exampleSpectrum.methods)
    plot(ctx.thetaDeg, 10 * log10(exampleSpectrum.methods(methodIdx).representativeSpectrum), ...
        'LineWidth', 1.6);
end
grid on;
xlabel('Scan angle (deg)');
ylabel('Pseudo-spectrum (dB)');
title(sprintf('Case 1: MUSIC spectrum at %.1f deg, SNR = %g dB', exampleAngle, cfg.case1.highSNRDb));
legend({exampleSpectrum.methods.label}, 'Location', 'best');
save_figure(fig, fullfile(outDir, 'example_music_spectrum.png'));

evalCfg.trueAngles = local_single_source_eval_angles(ctx, [], cfg);
evalCfg.monteCarlo = cfg.case1.monteCarlo;
evalCfg.collectRepresentativeSpectrum = false;
highSnrSweep = benchmark_music(ctx, methods, evalCfg);

fig = figure('Visible', 'off', 'Position', [160 160 1100 500]);
hold on;
for methodIdx = 1:numel(highSnrSweep.methods)
    plot(highSnrSweep.trueAngleSetsDeg, highSnrSweep.methods(methodIdx).perTargetRmse, ...
        'o-', 'LineWidth', 1.4, 'MarkerSize', 5);
end
grid on;
xlabel('True angle (deg)');
ylabel('DOA RMSE (deg)');
title(sprintf('Case 1: high-SNR angle error, SNR = %g dB', cfg.case1.highSNRDb));
legend({highSnrSweep.methods.label}, 'Location', 'best');
save_figure(fig, fullfile(outDir, 'high_snr_angle_bias.png'));

caseResult = struct();
caseResult.outputDir = outDir;
caseResult.metrics = metrics;
caseResult.contextDiagnostics = ctx.diagnostics;
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
    local_method('amp_phase', 'Amp+Phase', aAmpPhase)];

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
set(gca, 'XTickLabel', {'Ideal', 'Phase', 'Amplitude', 'Amp+Phase'});
ylabel('Mean manifold relative error');
title('Case 2: manifold approximation error');

nexttile;
bar(arrayfun(@(s) s.rmse, bench.methods));
grid on;
set(gca, 'XTickLabel', {bench.methods.label});
ylabel('Single-source DOA RMSE (deg)');
title(sprintf('Case 2: DOA RMSE at %g dB', cfg.case2.evalSNRDb));
xtickangle(20);
save_figure(fig, fullfile(outDir, 'mismatch_dominance.png'));

caseResult = struct();
caseResult.outputDir = outDir;
caseResult.energySharePercent = energyShare;
caseResult.manifoldMetrics = struct( ...
    'ideal', metricsIdeal, ...
    'phaseOnly', metricsPhase, ...
    'amplitudeOnly', metricsAmplitude, ...
    'ampPhase', metricsAmpPhase);
caseResult.benchmark = bench;
save(fullfile(outDir, 'case02_results.mat'), 'caseResult');
end

function caseResult = case03_unseen_generalization(cfg, ctx)
rng(cfg.randomSeed + 3, 'twister');
outDir = local_case_output_dir(cfg, 'case03_unseen_generalization');

lValues = cfg.case3.lValues;
methodNames = {'Ideal', 'Interpolation', 'Proposed', 'HFSS Oracle'};
meanUnseenError = zeros(numel(lValues), numel(methodNames));
storedModels = cell(1, numel(lValues));

for lIdx = 1:numel(lValues)
    calIdx = select_calibration_indices(ctx.thetaDeg, lValues(lIdx), 'uniform');
    storedModels{lIdx} = build_sparse_models(ctx, calIdx, cfg.model);
    models = storedModels{lIdx};

    metricsIdeal = compute_manifold_metrics(ctx.AH(:, models.testIdx), ctx.AI(:, models.testIdx));
    metricsInterp = compute_manifold_metrics(ctx.AH(:, models.testIdx), models.AInterp(:, models.testIdx));
    metricsProposed = compute_manifold_metrics(ctx.AH(:, models.testIdx), models.AProposed(:, models.testIdx));

    meanUnseenError(lIdx, :) = [ ...
        mean(metricsIdeal.relativeError), ...
        mean(metricsInterp.relativeError), ...
        mean(metricsProposed.relativeError), ...
        0];
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

fig = figure('Visible', 'off', 'Position', [140 140 1200 700]);
tiledlayout(numel(cfg.case3.representativeElements), 1, 'Padding', 'compact', 'TileSpacing', 'compact');
for plotIdx = 1:numel(cfg.case3.representativeElements)
    elementIdx = cfg.case3.representativeElements(plotIdx);
    nexttile;
    hold on;
    plot(ctx.thetaDeg, rad2deg(repModels.phaseTruthFull(elementIdx, :)), 'k-', 'LineWidth', 1.6);
    plot(ctx.thetaDeg, rad2deg(repModels.phaseInterpFull(elementIdx, :)), '--', 'LineWidth', 1.4);
    plot(ctx.thetaDeg, rad2deg(repModels.phaseFitFull(elementIdx, :)), '-.', 'LineWidth', 1.6);
    scatter(repModels.calAnglesDeg, rad2deg(repModels.phaseTruthFull(elementIdx, repModels.calIdx)), ...
        36, 'filled');
    grid on;
    ylabel(sprintf('Element %d (deg)', elementIdx));
    title(sprintf('Case 3: phase reconstruction for element %d', elementIdx));
end
xlabel('Angle (deg)');
legend({'HFSS truth', 'Interpolation', 'Proposed fit', 'Calibration samples'}, 'Location', 'eastoutside');
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
    plot(elemAxis, abs(repModels.AProposed(:, gridIdx)), '^-', 'LineWidth', 1.4);
    grid on;
    xlabel('Element index');
    ylabel('Magnitude');
    title(sprintf('Magnitude at %.1f deg', queryAngle));

    nexttile;
    hold on;
    plot(elemAxis, rad2deg(unwrap(angle(ctx.AH(:, gridIdx)))), 'ko-', 'LineWidth', 1.4);
    plot(elemAxis, rad2deg(unwrap(angle(ctx.AI(:, gridIdx)))), 's-', 'LineWidth', 1.2);
    plot(elemAxis, rad2deg(unwrap(angle(repModels.AInterp(:, gridIdx)))), 'd--', 'LineWidth', 1.2);
    plot(elemAxis, rad2deg(unwrap(angle(repModels.AProposed(:, gridIdx)))), '^-', 'LineWidth', 1.4);
    grid on;
    xlabel('Element index');
    ylabel('Phase (deg)');
    title(sprintf('Phase at %.1f deg', queryAngle));
end
legend({'HFSS truth', 'Ideal', 'Interpolation', 'Proposed'}, 'Location', 'eastoutside');
save_figure(fig, fullfile(outDir, 'steering_vector_comparison.png'));

caseResult = struct();
caseResult.outputDir = outDir;
caseResult.lValues = lValues;
caseResult.meanUnseenError = meanUnseenError;
caseResult.representativeModels = repModels;
save(fullfile(outDir, 'case03_results.mat'), 'caseResult');
end

function caseResult = case04_calibration_count_sensitivity(cfg, ctx)
rng(cfg.randomSeed + 4, 'twister');
outDir = local_case_output_dir(cfg, 'case04_calibration_count_sensitivity');

lValues = cfg.case4.lValues;
methodKeys = {'ideal', 'interp', 'proposed', 'oracle'};
methodsLegend = {'Ideal', 'Interpolation', 'Proposed', 'HFSS Oracle'};

manifoldError = zeros(numel(lValues), numel(methodKeys));
singleRmse = zeros(numel(lValues), numel(methodKeys));
resolutionProb = zeros(numel(lValues), numel(methodKeys));
perL = cell(1, numel(lValues));

for lIdx = 1:numel(lValues)
    fprintf('Case 4: L = %d\n', lValues(lIdx));
    calIdx = select_calibration_indices(ctx.thetaDeg, lValues(lIdx), 'uniform');
    models = build_sparse_models(ctx, calIdx, cfg.model);
    perL{lIdx}.models = models;

    metricsIdeal = compute_manifold_metrics(ctx.AH(:, models.testIdx), ctx.AI(:, models.testIdx));
    metricsInterp = compute_manifold_metrics(ctx.AH(:, models.testIdx), models.AInterp(:, models.testIdx));
    metricsProposed = compute_manifold_metrics(ctx.AH(:, models.testIdx), models.AProposed(:, models.testIdx));
    manifoldError(lIdx, :) = [ ...
        mean(metricsIdeal.relativeError), ...
        mean(metricsInterp.relativeError), ...
        mean(metricsProposed.relativeError), ...
        0];

    methods = local_named_methods(ctx, models, methodKeys);
    evalCfg = struct();
    evalCfg.mode = 'single';
    evalCfg.trueAngles = local_single_source_eval_angles(ctx, models, cfg);
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

    validPairs = local_filter_pairs(cfg.case4.sourcePairsDeg, ctx.thetaDeg, models.calAnglesDeg);
    if isempty(validPairs)
        validPairs = cfg.case4.sourcePairsDeg;
    end
    evalCfg.mode = 'double';
    evalCfg.trueAngles = validPairs;
    doubleBench = benchmark_music(ctx, methods, evalCfg);
    for methodIdx = 1:numel(methodKeys)
        resolutionProb(lIdx, methodIdx) = doubleBench.methods(methodIdx).successRate;
    end
    perL{lIdx}.doubleBenchmark = doubleBench;
end

fig = figure('Visible', 'off', 'Position', [120 120 1300 480]);
tiledlayout(1, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

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
for methodIdx = 1:numel(methodKeys)
    plot(lValues, resolutionProb(:, methodIdx), 'o-', 'LineWidth', 1.5, 'MarkerSize', 7);
end
grid on;
ylim([0 1]);
xlabel('Calibration count L');
ylabel('Resolution probability');
title('Case 4: two-source resolution vs L');
legend(methodsLegend, 'Location', 'best');
save_figure(fig, fullfile(outDir, 'calibration_count_sensitivity.png'));

caseResult = struct();
caseResult.outputDir = outDir;
caseResult.lValues = lValues;
caseResult.manifoldError = manifoldError;
caseResult.singleRmse = singleRmse;
caseResult.resolutionProb = resolutionProb;
caseResult.perL = perL;
save(fullfile(outDir, 'case04_results.mat'), 'caseResult');
end

function caseResult = case05_sampling_strategy_sensitivity(cfg, ctx)
rng(cfg.randomSeed + 5, 'twister');
outDir = local_case_output_dir(cfg, 'case05_sampling_strategy_sensitivity');

strategyNames = cfg.case5.strategyNames;
snrSweep = cfg.case5.snrSweepDb;

meanUnseenError = zeros(1, numel(strategyNames));
stdUnseenError = zeros(1, numel(strategyNames));
meanRmse = zeros(numel(strategyNames), numel(snrSweep));
stdRmse = zeros(numel(strategyNames), numel(snrSweep));
details = cell(1, numel(strategyNames));

for strategyIdx = 1:numel(strategyNames)
    strategyName = strategyNames{strategyIdx};
    fprintf('Case 5: strategy = %s\n', strategyName);
    if strcmpi(strategyName, 'random')
        numTrials = cfg.case5.randomTrials;
    else
        numTrials = 1;
    end

    unseenTrials = zeros(numTrials, 1);
    rmseTrials = zeros(numTrials, numel(snrSweep));
    details{strategyIdx} = cell(numTrials, 1);

    for trialIdx = 1:numTrials
        seed = cfg.randomSeed + 500 + strategyIdx * 100 + trialIdx;
        calIdx = select_calibration_indices(ctx.thetaDeg, cfg.case5.l, strategyName, seed);
        models = build_sparse_models(ctx, calIdx, cfg.model);

        metricsProposed = compute_manifold_metrics(ctx.AH(:, models.testIdx), models.AProposed(:, models.testIdx));
        unseenTrials(trialIdx) = mean(metricsProposed.relativeError);

        methods = local_named_methods(ctx, models, {'proposed'});
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
            rmseTrials(trialIdx, snrIdx) = bench.methods(1).rmse;
            details{strategyIdx}{trialIdx}.(['snr_' strrep(num2str(snrSweep(snrIdx)), '-', 'm')]) = bench;
        end
    end

    meanUnseenError(strategyIdx) = mean(unseenTrials);
    stdUnseenError(strategyIdx) = std(unseenTrials);
    meanRmse(strategyIdx, :) = mean(rmseTrials, 1);
    stdRmse(strategyIdx, :) = std(rmseTrials, 0, 1);
    details{strategyIdx} = struct('unseenTrials', unseenTrials, 'rmseTrials', rmseTrials);
end

fig = figure('Visible', 'off', 'Position', [140 140 1200 500]);
tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
bar(meanUnseenError);
hold on;
errorbar(1:numel(strategyNames), meanUnseenError, stdUnseenError, '.k', 'LineWidth', 1.2);
grid on;
set(gca, 'XTick', 1:numel(strategyNames), 'XTickLabel', strategyNames);
xtickangle(20);
ylabel('Mean unseen relative error');
title(sprintf('Case 5: sampling strategy, L = %d', cfg.case5.l));

nexttile;
hold on;
for strategyIdx = 1:numel(strategyNames)
    errorbar(snrSweep, meanRmse(strategyIdx, :), stdRmse(strategyIdx, :), ...
        'o-', 'LineWidth', 1.4, 'MarkerSize', 6);
end
grid on;
xlabel('SNR (dB)');
ylabel('DOA RMSE (deg)');
title('Case 5: strategy sensitivity on DOA RMSE');
legend(strategyNames, 'Location', 'best');
save_figure(fig, fullfile(outDir, 'sampling_strategy_sensitivity.png'));

caseResult = struct();
caseResult.outputDir = outDir;
caseResult.strategyNames = strategyNames;
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
basisTypes = cfg.case6.basisTypes;
orders = cfg.case6.orders;
lambdas = cfg.case6.lambdas;

errorCube = zeros(numel(orders), numel(lambdas), numel(basisTypes));

for basisIdx = 1:numel(basisTypes)
    for orderIdx = 1:numel(orders)
        for lambdaIdx = 1:numel(lambdas)
            modelCfg = cfg.model;
            modelCfg.basisType = basisTypes{basisIdx};
            modelCfg.order = orders(orderIdx);
            modelCfg.lambda = lambdas(lambdaIdx);

            models = build_sparse_models(ctx, calIdx, modelCfg);
            metrics = compute_manifold_metrics(ctx.AH(:, models.testIdx), models.AProposed(:, models.testIdx));
            errorCube(orderIdx, lambdaIdx, basisIdx) = mean(metrics.relativeError);
        end
    end
end

bestCurve = squeeze(min(errorCube, [], 2));

fig = figure('Visible', 'off', 'Position', [120 120 1300 820]);
tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

for basisIdx = 1:numel(basisTypes)
    nexttile;
    imagesc(errorCube(:, :, basisIdx));
    colorbar;
    set(gca, 'XTick', 1:numel(lambdas), ...
        'XTickLabel', arrayfun(@num2str, lambdas, 'UniformOutput', false), ...
        'YTick', 1:numel(orders), ...
        'YTickLabel', arrayfun(@num2str, orders, 'UniformOutput', false));
    xlabel('\lambda');
    ylabel('Order P');
    title(sprintf('Case 6: %s basis', basisTypes{basisIdx}));
end

nexttile([1 2]);
hold on;
for basisIdx = 1:numel(basisTypes)
    plot(orders, bestCurve(:, basisIdx), 'o-', 'LineWidth', 1.5, 'MarkerSize', 7);
end
grid on;
xlabel('Model order P');
ylabel('Best unseen relative error over \lambda');
title(sprintf('Case 6: best error curve at L = %d', cfg.case6.l));
legend(basisTypes, 'Location', 'best');
save_figure(fig, fullfile(outDir, 'model_sensitivity.png'));

caseResult = struct();
caseResult.outputDir = outDir;
caseResult.orders = orders;
caseResult.lambdas = lambdas;
caseResult.basisTypes = basisTypes;
caseResult.errorCube = errorCube;
caseResult.bestCurve = bestCurve;
save(fullfile(outDir, 'case06_results.mat'), 'caseResult');
end

function caseResult = case07_single_source_snr(cfg, ctx)
rng(cfg.randomSeed + 7, 'twister');
outDir = local_case_output_dir(cfg, 'case07_single_source_snr');

calIdx = select_calibration_indices(ctx.thetaDeg, cfg.case3.representativeL, 'uniform');
models = build_sparse_models(ctx, calIdx, cfg.model);
methods = local_named_methods(ctx, models, {'ideal', 'interp', 'proposed', 'oracle'});
snrSweep = cfg.case7.snrSweepDb;
evalAngles = local_single_source_eval_angles(ctx, models, cfg);

rmse = zeros(numel(snrSweep), numel(methods));
successRate = zeros(numel(snrSweep), numel(methods));
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
    end
end

fig = figure('Visible', 'off', 'Position', [130 130 1200 500]);
tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

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
title('Case 7: success rate vs SNR');
legend({methods.label}, 'Location', 'best');
save_figure(fig, fullfile(outDir, 'rmse_and_success_vs_snr.png'));

exampleAngle = cfg.case7.exampleAngleDeg;
exampleAngle = local_nearest_angle_from_set(exampleAngle, models.testAnglesDeg);

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
save_figure(fig, fullfile(outDir, 'representative_spectra.png'));

caseResult = struct();
caseResult.outputDir = outDir;
caseResult.models = models;
caseResult.evalAnglesDeg = evalAngles;
caseResult.snrSweep = snrSweep;
caseResult.rmse = rmse;
caseResult.successRate = successRate;
caseResult.details = details;
save(fullfile(outDir, 'case07_results.mat'), 'caseResult');
end

function caseResult = case08_single_source_snapshots(cfg, ctx)
rng(cfg.randomSeed + 8, 'twister');
outDir = local_case_output_dir(cfg, 'case08_single_source_snapshots');

calIdx = select_calibration_indices(ctx.thetaDeg, cfg.case3.representativeL, 'uniform');
models = build_sparse_models(ctx, calIdx, cfg.model);
methods = local_named_methods(ctx, models, {'ideal', 'interp', 'proposed', 'oracle'});
evalAngles = local_single_source_eval_angles(ctx, models, cfg);

snapshotSweep = cfg.case8.snapshotSweep;
snrValues = cfg.case8.snrValuesDb;
rmse = zeros(numel(snapshotSweep), numel(methods), numel(snrValues));
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
        end
    end
end

fig = figure('Visible', 'off', 'Position', [140 140 1200 520]);
tiledlayout(1, numel(snrValues), 'Padding', 'compact', 'TileSpacing', 'compact');

for snrIdx = 1:numel(snrValues)
    nexttile;
    hold on;
    for methodIdx = 1:numel(methods)
        plot(snapshotSweep, rmse(:, methodIdx, snrIdx), 'o-', 'LineWidth', 1.5, 'MarkerSize', 7);
    end
    grid on;
    xlabel('Snapshots');
    ylabel('RMSE (deg)');
    title(sprintf('Case 8: SNR = %g dB', snrValues(snrIdx)));
end
legend({methods.label}, 'Location', 'eastoutside');
save_figure(fig, fullfile(outDir, 'rmse_vs_snapshots.png'));

caseResult = struct();
caseResult.outputDir = outDir;
caseResult.models = models;
caseResult.evalAnglesDeg = evalAngles;
caseResult.snapshotSweep = snapshotSweep;
caseResult.snrValues = snrValues;
caseResult.rmse = rmse;
caseResult.details = details;
save(fullfile(outDir, 'case08_results.mat'), 'caseResult');
end

function caseResult = case09_two_source_resolution(cfg, ctx)
rng(cfg.randomSeed + 9, 'twister');
outDir = local_case_output_dir(cfg, 'case09_two_source_resolution');

calIdx = select_calibration_indices(ctx.thetaDeg, cfg.case3.representativeL, 'uniform');
models = build_sparse_models(ctx, calIdx, cfg.model);
methods = local_named_methods(ctx, models, {'ideal', 'proposed', 'oracle'});

sourcePairs = local_case9_source_pairs(cfg.case9, ctx.thetaDeg, models.calAnglesDeg);
pairLabels = local_case9_pair_labels(sourcePairs);
separationDeg = sourcePairs(:, 2) - sourcePairs(:, 1);
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

exampleIdx = local_case9_select_example_pair(bench, methods, separationDeg, ...
    cfg.case9.exampleTargetResolutionProb);
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
save_figure(fig, fullfile(outDir, 'two_source_resolution.png'));

caseResult = struct();
caseResult.outputDir = outDir;
caseResult.models = models;
caseResult.sourcePairsDeg = sourcePairs;
caseResult.sourcePairLabels = pairLabels;
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
caseResult.benchmark = bench;
caseResult.exampleBenchmark = exampleBench;
save(fullfile(outDir, 'case09_results.mat'), 'caseResult');
end

function caseResult = case10_random_split_robustness(cfg, ctx)
rng(cfg.randomSeed + 10, 'twister');
outDir = local_case_output_dir(cfg, 'case10_random_split_robustness');

numSplits = cfg.case10.numSplits;
manifoldError = zeros(numSplits, 3);
singleRmse = zeros(numSplits, 3);
splitAngles = cell(numSplits, 1);

for splitIdx = 1:numSplits
    fprintf('Case 10: random split %d/%d\n', splitIdx, numSplits);
    calIdx = select_calibration_indices(ctx.thetaDeg, cfg.case10.l, 'random', cfg.randomSeed + 2000 + splitIdx);
    models = build_sparse_models(ctx, calIdx, cfg.model);
    splitAngles{splitIdx} = models.calAnglesDeg;

    metricsIdeal = compute_manifold_metrics(ctx.AH(:, models.testIdx), ctx.AI(:, models.testIdx));
    metricsInterp = compute_manifold_metrics(ctx.AH(:, models.testIdx), models.AInterp(:, models.testIdx));
    metricsProposed = compute_manifold_metrics(ctx.AH(:, models.testIdx), models.AProposed(:, models.testIdx));
    manifoldError(splitIdx, :) = [ ...
        mean(metricsIdeal.relativeError), ...
        mean(metricsInterp.relativeError), ...
        mean(metricsProposed.relativeError)];

    methods = local_named_methods(ctx, models, {'ideal', 'interp', 'proposed'});
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

[xErr, yErr] = local_box_inputs(manifoldError, {'Ideal', 'Interp', 'Proposed'});
[xRmse, yRmse] = local_box_inputs(singleRmse, {'Ideal', 'Interp', 'Proposed'});

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
caseResult.manifoldError = manifoldError;
caseResult.singleRmse = singleRmse;
caseResult.calibrationAnglesDeg = splitAngles;
save(fullfile(outDir, 'case10_results.mat'), 'caseResult');
end

function outDir = local_case_output_dir(cfg, caseFolderName)
outDir = fullfile(cfg.outputDir, caseFolderName);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
end

function cfg = local_complete_runtime_config(cfg, rootDir)
if ~isfield(cfg, 'rootDir') || isempty(cfg.rootDir)
    cfg.rootDir = rootDir;
end
if ~isfield(cfg, 'outputDir') || isempty(cfg.outputDir)
    cfg.outputDir = fullfile(rootDir, 'results_step0p2_qw');
end
if ~isfield(cfg, 'eval') || isempty(cfg.eval)
    cfg.eval = struct();
end
cfg.eval = local_set_default_field(cfg.eval, 'targetMode', 'stratified');
cfg.eval = local_set_default_field(cfg.eval, 'targetStrideDeg', 2);
cfg.eval = local_set_default_field(cfg.eval, 'edgeBandDeg', 8);
cfg.eval = local_set_default_field(cfg.eval, 'highMismatchCount', 12);
cfg.eval = local_set_default_field(cfg.eval, 'useFullGridForManifoldMetrics', true);

if isfield(cfg, 'case9')
    cfg.case9 = local_set_default_field(cfg.case9, 'maxPairsPerSeparation', 21);
    cfg.case9 = local_set_default_field(cfg.case9, 'separationSweepDeg', [1 2 3 4 5 6 8 10]);
    cfg.case9 = local_set_default_field(cfg.case9, 'biasedToleranceDeg', 2);
    cfg.case9 = local_set_default_field(cfg.case9, 'marginalToleranceDeg', 5);
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
        case 'proposed'
            methods(methodIdx) = local_method('proposed', 'Proposed', models.AProposed);
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

function sourcePairs = local_case9_source_pairs(caseCfg, thetaGrid, calAnglesDeg)
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

if isfield(caseCfg, 'maxPairsPerSeparation') && ~isempty(caseCfg.maxPairsPerSeparation) && ...
        isfinite(caseCfg.maxPairsPerSeparation) && caseCfg.maxPairsPerSeparation > 0
    sourcePairs = local_case9_limit_pairs_per_separation(sourcePairs, caseCfg.maxPairsPerSeparation);
end
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

function limitedPairs = local_case9_limit_pairs_per_separation(sourcePairs, maxPairsPerSeparation)
separationDeg = sourcePairs(:, 2) - sourcePairs(:, 1);
uniqueSep = unique(round(separationDeg, 10), 'sorted');
limitedPairs = zeros(0, 2);

for sepIdx = 1:numel(uniqueSep)
    pairIdx = find(abs(separationDeg - uniqueSep(sepIdx)) < 1e-9);
    if numel(pairIdx) > maxPairsPerSeparation
        pickLocal = unique(round(linspace(1, numel(pairIdx), maxPairsPerSeparation)));
        pairIdx = pairIdx(pickLocal);
    end
    limitedPairs = [limitedPairs; sourcePairs(pairIdx, :)]; %#ok<AGROW>
end
end

function pairLabels = local_case9_pair_labels(sourcePairs)
pairLabels = arrayfun(@(rowIdx) sprintf('[%g,%g]', sourcePairs(rowIdx, 1), sourcePairs(rowIdx, 2)), ...
    1:size(sourcePairs, 1), 'UniformOutput', false);
end

function [uniqueSep, meanMetric, stdMetric] = local_case9_group_metric(separationDeg, metricMatrix)
uniqueSep = unique(separationDeg, 'sorted');
meanMetric = zeros(numel(uniqueSep), size(metricMatrix, 2));
stdMetric = zeros(numel(uniqueSep), size(metricMatrix, 2));

for sepIdx = 1:numel(uniqueSep)
    pairMask = abs(separationDeg - uniqueSep(sepIdx)) < 1e-9;
    meanMetric(sepIdx, :) = mean(metricMatrix(pairMask, :), 1);
    stdMetric(sepIdx, :) = std(metricMatrix(pairMask, :), 0, 1);
end
end

function exampleIdx = local_case9_select_example_pair(bench, methods, separationDeg, targetResolutionProb)
methodIdx = find(strcmp({methods.name}, 'proposed'), 1, 'first');
if isempty(methodIdx)
    methodIdx = 1;
end

proposed = bench.methods(methodIdx);
stateMatrix = [ ...
    proposed.perTargetUnresolvedRate(:), ...
    proposed.perTargetMarginalRate(:), ...
    proposed.perTargetBiasedRate(:), ...
    proposed.perTargetStableRate(:)];
stateEntropy = -sum(stateMatrix .* log(max(stateMatrix, eps)), 2);

candidateMask = proposed.perTargetResolutionRate > 0.2 & ...
    proposed.perTargetResolutionRate < 0.98 & ...
    (proposed.perTargetMarginalRate + proposed.perTargetBiasedRate) > 0.05;
if ~any(candidateMask)
    candidateMask = proposed.perTargetResolutionRate > 0.05 & ...
        proposed.perTargetResolutionRate < 1;
end
if ~any(candidateMask)
    candidateMask = true(size(proposed.perTargetResolutionRate));
end

candidateIdx = find(candidateMask);
score = abs(proposed.perTargetResolutionRate(candidateIdx) - targetResolutionProb) ...
    - 0.6 * stateEntropy(candidateIdx) ...
    + 0.01 * separationDeg(candidateIdx);
[~, bestLocalIdx] = min(score);
exampleIdx = candidateIdx(bestLocalIdx);
end

function [xValues, yValues] = local_box_inputs(dataMatrix, labels)
numMethods = size(dataMatrix, 2);
numSamples = size(dataMatrix, 1);

xValues = categorical(repelem(labels, numSamples));
yValues = reshape(dataMatrix, [], 1);
end
