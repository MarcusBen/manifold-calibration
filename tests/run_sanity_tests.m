rootDir = fileparts(fileparts(mfilename('fullpath')));
setup_paths(rootDir);

fprintf('Running project sanity tests...\n');

cfg = default_config(rootDir);
ctx = build_project_context(cfg);

local_test_hfss_loader_grid_normalization(ctx);
local_test_calibration_split(ctx);
local_test_ideal_manifold(ctx);
local_test_ard_calibration_reconstruction(cfg, ctx);
local_test_oracle_truth_lookup(ctx);
local_test_snapshot_snr_sanity(ctx);
local_test_music_single_oracle(ctx);
local_test_music_double_oracle(ctx);
local_test_music_benchmark_pairwise_grid_backend(ctx);
local_test_common_snapshot_policy(ctx);
local_test_backend_utils_covariance_fit(ctx);
local_test_backend_utils_spice_spectra(ctx);
local_test_backend_utils_classification();
local_test_music_backend_baseline(ctx);
local_test_music_pair_rescore_backend(ctx);
local_test_spice_backend(ctx);
local_test_spice_plus_backend(ctx);
local_test_doa_backend_dispatch_spice(ctx);
local_test_backend_benchmark_accepts_spice(ctx);
local_test_pairwise_grid_ml_backend(ctx);
local_test_pairwise_grid_ml_preserves_covariance_objective(ctx);
local_test_triplet_grid_ml_backend(ctx);
local_test_backend_benchmark_common_snapshots(ctx);
local_test_backend_benchmark_shapes(ctx);
local_test_backend_benchmark_singleton_backend_methods(ctx);
local_test_backend_benchmark_malformed_pair_penalty(ctx);
local_test_core_config_defaults(cfg);
local_test_core_source_benchmark_common_snapshots(ctx);
local_test_core_source_benchmark_parallel_backends(ctx);
local_test_core_triplet_benchmark(ctx);
local_test_case13_condition_construction(cfg);
local_test_case13_delta_label();

fprintf('All sanity tests PASS.\n');

function local_test_hfss_loader_grid_normalization(ctx)
local_assert_equal(ctx.numElements, 8, 'HFSS element count');
local_assert_equal(ctx.numAngles, 601, 'HFSS grid length');
local_assert_close(ctx.thetaDeg(1), -60, 1e-12, 'HFSS first angle');
local_assert_close(ctx.thetaDeg(end), 60, 1e-12, 'HFSS last angle');
local_assert_close(ctx.gridStepDeg, 0.2, 1e-12, 'HFSS grid step');
local_assert_close(max(abs(vecnorm(ctx.AH, 2, 1) - 1)), 0, 1e-12, 'HFSS column norms');
local_assert_close(max(abs(vecnorm(ctx.AI, 2, 1) - 1)), 0, 1e-12, 'Ideal column norms');
local_assert_close(max(abs(angle(ctx.AH(1, :)))), 0, 1e-12, 'HFSS first-element phase reference');
end

function local_test_calibration_split(ctx)
calIdx = select_calibration_indices(ctx.thetaDeg, 9, 'uniform');
testIdx = setdiff(1:ctx.numAngles, calIdx);
local_assert_equal(numel(calIdx), 9, 'calibration count');
local_assert_true(numel(unique(calIdx)) == 9, 'calibration indices are unique');
local_assert_true(isempty(intersect(calIdx, testIdx)), 'calibration/test split is disjoint');
local_assert_close(ctx.thetaDeg(calIdx(1)), -60, 1e-12, 'uniform calibration left edge');
local_assert_close(ctx.thetaDeg(calIdx(end)), 60, 1e-12, 'uniform calibration right edge');
end

function local_test_ideal_manifold(ctx)
idx0 = local_angle_index(ctx.thetaDeg, 0);
idx30 = local_angle_index(ctx.thetaDeg, 30);
local_assert_close(max(abs(ctx.AI(:, idx0) - ctx.AI(1, idx0))), 0, 1e-12, ...
    'boresight ideal manifold phase');
phaseStep = angle(ctx.AI(2, idx30) * conj(ctx.AI(1, idx30)));
local_assert_close(phaseStep, pi / 4, 1e-12, '30 deg ideal manifold phase step');
end

function local_test_ard_calibration_reconstruction(cfg, ctx)
fastCfg = cfg.model;
fastCfg.v2.enabled = false;
fastCfg.v3.enabled = false;
calIdx = select_calibration_indices(ctx.thetaDeg, cfg.case3.representativeL, 'uniform');
models = build_sparse_models(ctx, calIdx, fastCfg);
relErr = norm(models.AARD(:, calIdx) - ctx.AH(:, calIdx), 'fro') / norm(ctx.AH(:, calIdx), 'fro');
local_assert_true(relErr < 1e-8, sprintf('ARD calibration reconstruction relErr=%g', relErr));
local_assert_equal(size(models.AARD), size(ctx.AH), 'ARD manifold size');
end

function local_test_oracle_truth_lookup(ctx)
idx = local_angle_index(ctx.thetaDeg, 23.8);
oracle = struct('name', 'oracle', 'label', 'HFSS Oracle', 'manifold', ctx.AH);
local_assert_close(abs(ctx.AH(:, idx)' * oracle.manifold(:, idx)), 1, 1e-12, ...
    'HFSS oracle truth lookup correlation');
end

function local_test_snapshot_snr_sanity(ctx)
rng(9201, 'twister');
idx = local_angle_index(ctx.thetaDeg, 10);
lowSnr = local_simulate_snapshots(ctx.AH(:, idx), 0, 500);
highSnr = local_simulate_snapshots(ctx.AH(:, idx), 40, 500);
lowCov = (lowSnr * lowSnr') / size(lowSnr, 2);
highCov = (highSnr * highSnr') / size(highSnr, 2);
lowEig = sort(real(eig(lowCov)), 'descend');
highEig = sort(real(eig(highCov)), 'descend');
local_assert_true(highEig(1) / highEig(2) > lowEig(1) / lowEig(2), ...
    'snapshot covariance eigengap increases with SNR');
end

function local_test_music_single_oracle(ctx)
rng(9202, 'twister');
method = struct('name', 'oracle', 'label', 'HFSS Oracle', 'manifold', ctx.AH);
evalCfg = struct('mode', 'single', 'trueAngles', 12.4, 'snrDb', 30, ...
    'snapshots', 800, 'monteCarlo', 1, 'toleranceDeg', 0.4, ...
    'collectRepresentativeSpectrum', true);
bench = benchmark_music(ctx, method, evalCfg);
local_assert_close(bench.methods.representativeEstAnglesDeg, 12.4, 0.4, ...
    'single-source oracle MUSIC estimate');
end

function local_test_music_double_oracle(ctx)
rng(9203, 'twister');
method = struct('name', 'oracle', 'label', 'HFSS Oracle', 'manifold', ctx.AH);
evalCfg = struct('mode', 'double', 'trueAngles', [-20 15], 'snrDb', 30, ...
    'snapshots', 1200, 'monteCarlo', 1, 'toleranceDeg', 0.6, ...
    'biasedToleranceDeg', 2, 'marginalToleranceDeg', 5, ...
    'collectRepresentativeSpectrum', true);
bench = benchmark_music(ctx, method, evalCfg);
local_assert_true(all(abs(bench.methods.representativeEstAnglesDeg - [-20 15]) <= 0.6), ...
    'double-source oracle MUSIC estimate');
local_assert_equal(bench.methods.perTargetSeparationCollapseRate, 0, ...
    'double-source collapse diagnostic for clean oracle case');
end

function local_test_music_benchmark_pairwise_grid_backend(ctx)
rng(92031, 'twister');
method = struct('name', 'oracle', 'label', 'HFSS Oracle', 'manifold', ctx.AH);
evalCfg = struct('mode', 'double', 'trueAngles', [23.8 31.8], 'snrDb', 30, ...
    'snapshots', 1200, 'monteCarlo', 1, 'toleranceDeg', 0.6, ...
    'biasedToleranceDeg', 2, 'marginalToleranceDeg', 5, ...
    'backendName', 'pairwise_grid_ml', ...
    'backendCfg', struct('candidateAnglesDeg', 20:0.2:36, ...
    'minimumSeparationDeg', 2, 'maximumSeparationDeg', 30, ...
    'topCandidateCount', 4), ...
    'collectRepresentativeSpectrum', true);
bench = benchmark_music(ctx, method, evalCfg);
local_assert_true(bench.methods.resolutionRate == 1, ...
    'benchmark_music pairwise-grid backend resolves high-SNR oracle pair');
local_assert_true(~isempty(bench.methods.representativeSpectrum), ...
    'benchmark_music pairwise-grid backend keeps representative spectrum fallback');
end

function local_test_common_snapshot_policy(ctx)
rng(9204, 'twister');
methods = repmat(struct('name', '', 'label', '', 'manifold', []), 1, 2);
methods(1) = struct('name', 'oracle_a', 'label', 'Oracle A', 'manifold', ctx.AH);
methods(2) = struct('name', 'oracle_b', 'label', 'Oracle B', 'manifold', ctx.AH);
evalCfg = struct('mode', 'double', 'trueAngles', [23.8 31.8; 35.8 45.8], ...
    'snrDb', 5, 'snapshots', 200, 'monteCarlo', 3, 'toleranceDeg', 0.6, ...
    'biasedToleranceDeg', 2, 'marginalToleranceDeg', 5, ...
    'collectRepresentativeSpectrum', false);
bench = benchmark_music(ctx, methods, evalCfg);
local_assert_equal(bench.snapshotPolicy, 'common_truth_snapshots_across_methods', ...
    'common snapshot policy label');
local_assert_true(isequaln(bench.methods(1).perTargetRmse, bench.methods(2).perTargetRmse), ...
    'common snapshots make identical methods share per-target RMSE');
local_assert_true(isequaln(bench.methods(1).perTargetStableRate, bench.methods(2).perTargetStableRate), ...
    'common snapshots make identical methods share stable rates');
local_assert_true(isequaln(bench.methods(1).perTargetSeparationCollapseRate, ...
    bench.methods(2).perTargetSeparationCollapseRate), ...
    'common snapshots make identical methods share collapse rates');
end

function local_test_backend_utils_covariance_fit(ctx)
idx = [local_angle_index(ctx.thetaDeg, -20), local_angle_index(ctx.thetaDeg, 15)];
aPair = ctx.AH(:, idx);
sourcePower = [1.5; 0.7];
noisePower = 0.05;
covariance = aPair * diag(sourcePower) * aPair' + noisePower * eye(ctx.numElements);
[score, fit] = doa_backend_utils('covariance_score', covariance, aPair);
local_assert_true(score < 1e-10, sprintf('backend covariance fit score=%g', score));
local_assert_close(fit.sourcePower(:), sourcePower, 1e-8, 'backend covariance source powers');
local_assert_close(fit.noisePower, noisePower, 1e-8, 'backend covariance noise power');
end

function local_test_backend_utils_spice_spectra(ctx)
rng(93011, 'twister');
idx = [local_angle_index(ctx.thetaDeg, -18), local_angle_index(ctx.thetaDeg, 14)];
x = local_simulate_snapshots(ctx.AH(:, idx), 35, 1200);
covariance = (x * x') / size(x, 2);
alg = struct('maxIterations', 60, 'tolerance', 1e-5, 'diagonalLoading', 1e-8);
[spiceSpectrum, spiceInfo] = doa_backend_utils('spice_spectrum', covariance, ctx.AH, alg);
[spicePlusSpectrum, spicePlusInfo] = doa_backend_utils('spice_plus_spectrum', covariance, ctx.AH, alg);
spicePeakAngles = sort(ctx.thetaDeg(doa_backend_utils('pick_local_peaks', spiceSpectrum, 2)));
spicePlusPeakAngles = sort(ctx.thetaDeg(doa_backend_utils('pick_local_peaks', spicePlusSpectrum, 2)));
local_assert_equal(numel(spiceSpectrum), numel(ctx.thetaDeg), ...
    'SPICE spectrum length');
local_assert_equal(numel(spicePlusSpectrum), numel(ctx.thetaDeg), ...
    'SPICE+ spectrum length');
local_assert_true(all(isfinite(spiceSpectrum)) && all(spiceSpectrum >= 0), ...
    'SPICE spectrum finite nonnegative');
local_assert_true(all(isfinite(spicePlusSpectrum)) && all(spicePlusSpectrum >= 0), ...
    'SPICE+ spectrum finite nonnegative');
local_assert_true(all(abs(spicePeakAngles - [-18 14]) <= 0.8), ...
    'SPICE spectrum peaks recover source angles');
local_assert_true(all(abs(spicePlusPeakAngles - [-18 14]) <= 0.8), ...
    'SPICE+ spectrum peaks recover source angles');
local_assert_true(isfield(spiceInfo, 'iterations') && spiceInfo.iterations > 0, ...
    'SPICE iteration diagnostics');
local_assert_true(isfield(spicePlusInfo, 'iterations') && spicePlusInfo.iterations > 0, ...
    'SPICE+ iteration diagnostics');
local_assert_true(isfield(spicePlusInfo, 'sigmaHat') && isfinite(spicePlusInfo.sigmaHat), ...
    'SPICE+ sigma diagnostics');
zeroLoadingAlg = alg;
zeroLoadingAlg.diagonalLoading = 0;
local_assert_error(@() doa_backend_utils('spice_spectrum', covariance, ctx.AH, zeroLoadingAlg), ...
    'spice_spectrum:InvalidOptions', 'SPICE rejects zero diagonal loading');
local_assert_error(@() doa_backend_utils('spice_plus_spectrum', covariance, ctx.AH, zeroLoadingAlg), ...
    'spice_spectrum:InvalidOptions', 'SPICE+ rejects zero diagonal loading');
end

function local_test_backend_utils_classification()
stateCfg = struct('stableToleranceDeg', 0.6, 'biasedToleranceDeg', 2, 'marginalToleranceDeg', 5);
peakIdx = doa_backend_utils('pick_local_peaks', [1 2 3 4], 2);
flatIdx = doa_backend_utils('pick_local_peaks', [1 1 1 1], 2);
stable = doa_backend_utils('classify_double', [23.8 31.8], [23.8 31.8], stateCfg);
biased = doa_backend_utils('classify_double', [24.8 32.6], [23.8 31.8], stateCfg);
nonPairState = doa_backend_utils('classify_double', 1, [1 2], stateCfg);
collapsed = doa_backend_utils('separation_collapsed', [27.0 28.0], [23.8 31.8]);
nonPairCollapsed = doa_backend_utils('separation_collapsed', [1 2 3], [1 2 3]);
local_assert_true(numel(peakIdx) == 2 && numel(unique(peakIdx)) == 2, ...
    'backend peak picker backfills monotonic spectrum');
local_assert_true(numel(flatIdx) == 2 && numel(unique(flatIdx)) == 2, ...
    'backend peak picker backfills flat spectrum');
local_assert_true(stable.isStable && stable.isResolved, 'backend stable classification');
local_assert_true(biased.isBiased && biased.isResolved, 'backend biased classification');
local_assert_true(~nonPairState.isResolved && strcmp(nonPairState.name, 'unresolved'), ...
    'backend classification non-pair guard');
local_assert_true(collapsed, 'backend separation collapse diagnostic');
local_assert_true(~nonPairCollapsed, 'backend separation collapse non-pair guard');
end

function local_test_music_backend_baseline(ctx)
rng(9301, 'twister');
idx = [local_angle_index(ctx.thetaDeg, -20), local_angle_index(ctx.thetaDeg, 15)];
x = local_simulate_snapshots(ctx.AH(:, idx), 40, 1200);
backendCfg = struct('numSources', 2);
result = doa_backend_music_baseline(x, ctx.AH, ctx.thetaDeg, backendCfg);
local_assert_true(all(abs(result.estAnglesDeg - [-20 15]) <= 0.4), ...
    'baseline backend MUSIC recovers high-SNR oracle pair');
local_assert_equal(numel(result.spectrum), numel(ctx.thetaDeg), ...
    'baseline backend MUSIC spectrum length');
end

function local_test_music_pair_rescore_backend(ctx)
rng(9302, 'twister');
idx = [local_angle_index(ctx.thetaDeg, -20), local_angle_index(ctx.thetaDeg, 15)];
x = local_simulate_snapshots(ctx.AH(:, idx), 35, 1200);
backendCfg = struct('numSources', 2, 'candidatePeakCount', 10, 'minimumSeparationDeg', 2);
result = doa_backend_music_pair_rescore(x, ctx.AH, ctx.thetaDeg, backendCfg);
local_assert_true(all(abs(result.estAnglesDeg - [-20 15]) <= 0.6), ...
    'pair-rescore backend recovers high-SNR oracle pair');
local_assert_true(isfield(result.diagnostics, 'topCandidatePairsDeg'), ...
    'pair-rescore backend saves top candidates');
local_assert_true(size(result.diagnostics.topCandidatePairsDeg, 2) == 2, ...
    'pair-rescore candidate pairs have two columns');
end

function local_test_spice_backend(ctx)
rng(93021, 'twister');
idx = [local_angle_index(ctx.thetaDeg, -18), local_angle_index(ctx.thetaDeg, 14)];
x = local_simulate_snapshots(ctx.AH(:, idx), 35, 1200);
backendCfg = struct('numSources', 2, 'variant', 'spice', ...
    'maxIterations', 60, 'tolerance', 1e-5, 'diagonalLoading', 1e-8, ...
    'minimumSeparationDeg', 3);
result = doa_backend_spice(x, ctx.AH, ctx.thetaDeg, backendCfg);
local_assert_true(all(abs(result.estAnglesDeg - [-18 14]) <= 0.8), ...
    'SPICE backend recovers high-SNR oracle pair');
local_assert_equal(result.name, 'spice', 'SPICE backend name');
local_assert_equal(numel(result.spectrum), numel(ctx.thetaDeg), ...
    'SPICE backend spectrum length');
local_assert_true(isfield(result.diagnostics, 'iterations'), ...
    'SPICE backend iteration diagnostics');
end

function local_test_spice_plus_backend(ctx)
rng(93022, 'twister');
idx = [local_angle_index(ctx.thetaDeg, -18), local_angle_index(ctx.thetaDeg, 14)];
x = local_simulate_snapshots(ctx.AH(:, idx), 35, 1200);
backendCfg = struct('numSources', 2, 'variant', 'spice_plus', ...
    'maxIterations', 60, 'tolerance', 1e-5, 'diagonalLoading', 1e-8, ...
    'minimumSeparationDeg', 3);
result = doa_backend_spice(x, ctx.AH, ctx.thetaDeg, backendCfg);
local_assert_true(all(abs(result.estAnglesDeg - [-18 14]) <= 0.8), ...
    'SPICE+ backend recovers high-SNR oracle pair');
local_assert_equal(result.name, 'spice_plus', 'SPICE+ backend name');
local_assert_true(isfield(result.diagnostics, 'sigmaHat'), ...
    'SPICE+ backend sigma diagnostics');
end

function local_test_doa_backend_dispatch_spice(ctx)
rng(93023, 'twister');
idx = [local_angle_index(ctx.thetaDeg, -18), local_angle_index(ctx.thetaDeg, 14)];
x = local_simulate_snapshots(ctx.AH(:, idx), 35, 1200);
backendCfg = struct('numSources', 2, 'minimumSeparationDeg', 3, ...
    'maxIterations', 60, 'tolerance', 1e-5, 'diagonalLoading', 1e-8);
result = doa_backend_dispatch('spice_plus', x, ctx.AH, ctx.thetaDeg, backendCfg);
local_assert_equal(result.name, 'spice_plus', 'dispatcher SPICE+ backend name');
local_assert_true(all(abs(result.estAnglesDeg - [-18 14]) <= 0.8), ...
    'dispatcher SPICE+ recovers high-SNR oracle pair');
end

function local_test_backend_benchmark_accepts_spice(ctx)
rng(93024, 'twister');
methods = struct('name', 'oracle', 'label', 'HFSS Oracle', 'manifold', ctx.AH);
evalCfg = local_backend_test_eval_cfg();
evalCfg.trueAngles = [-18 14];
evalCfg.monteCarlo = 1;
backendCfg = local_backend_test_backend_cfg(ctx);
backendCfg.backendNames = {'music', 'spice_plus', 'pairwise_grid_ml'};
backendCfg.maxIterations = 40;
backendCfg.tolerance = 1e-5;
backendCfg.diagonalLoading = 1e-8;
backendCfg.minimumSeparationDeg = 3;
bench = benchmark_doa_backends(ctx, methods, evalCfg, backendCfg);
local_assert_equal(bench.backendNames, backendCfg.backendNames, ...
    'backend benchmark preserves SPICE backend names');
local_assert_equal(size(bench.rmse, 1), 3, ...
    'backend benchmark has three backend rows');
end

function local_test_pairwise_grid_ml_backend(ctx)
rng(9303, 'twister');
idx = [local_angle_index(ctx.thetaDeg, -20), local_angle_index(ctx.thetaDeg, 15)];
x = local_simulate_snapshots(ctx.AH(:, idx), 35, 1200);
backendCfg = struct('numSources', 2, 'candidateAnglesDeg', -30:1:30, ...
    'minimumSeparationDeg', 2, 'maximumSeparationDeg', 50, 'topCandidateCount', 8);
result = doa_backend_pairwise_grid_ml(x, ctx.AH, ctx.thetaDeg, backendCfg);
local_assert_true(all(abs(result.estAnglesDeg - [-20 15]) <= 1.0), ...
    'pairwise grid ML backend recovers high-SNR oracle pair');
local_assert_true(isfield(result.diagnostics, 'topCandidatePairsDeg'), ...
    'pairwise grid ML saves top candidates');
local_assert_true(all(diff(result.diagnostics.topCandidateScores) >= -eps), ...
    'pairwise grid ML top scores sorted');
end

function local_test_pairwise_grid_ml_preserves_covariance_objective(ctx)
rng(93031, 'twister');
idx = [local_angle_index(ctx.thetaDeg, 6.8), local_angle_index(ctx.thetaDeg, 16.8)];
x = local_simulate_snapshots(ctx.AH(:, idx), 25, 900);
covariance = (x * x') / size(x, 2);
backendCfg = struct('numSources', 2, 'candidateAnglesDeg', 0:1:22, ...
    'minimumSeparationDeg', 2, 'maximumSeparationDeg', 25, 'topCandidateCount', 6);
result = doa_backend_pairwise_grid_ml(x, ctx.AH, ctx.thetaDeg, backendCfg);
topPairs = result.diagnostics.topCandidatePairsDeg;
topScores = result.diagnostics.topCandidateScores;
for pairIdx = 1:size(topPairs, 1)
    gridIdx = [local_angle_index(ctx.thetaDeg, topPairs(pairIdx, 1)), ...
        local_angle_index(ctx.thetaDeg, topPairs(pairIdx, 2))];
    referenceScore = doa_backend_utils('covariance_score', covariance, ctx.AH(:, gridIdx));
    local_assert_close(topScores(pairIdx), referenceScore, 1e-10, ...
        'pairwise grid ML batched score matches covariance objective');
end
end

function local_test_triplet_grid_ml_backend(ctx)
rng(93032, 'twister');
idx = [local_angle_index(ctx.thetaDeg, -18), local_angle_index(ctx.thetaDeg, -6), ...
    local_angle_index(ctx.thetaDeg, 12)];
x = local_simulate_snapshots(ctx.AH(:, idx), 35, 1200);
backendCfg = struct('numSources', 3, 'candidateAnglesDeg', -24:2:18, ...
    'minimumSeparationDeg', 2, 'maximumSeparationDeg', 40, 'topCandidateCount', 6);
result = doa_backend_triplet_grid_ml(x, ctx.AH, ctx.thetaDeg, backendCfg);
local_assert_true(all(abs(result.estAnglesDeg - [-18 -6 12]) <= 2.0), ...
    'triplet grid ML backend recovers high-SNR oracle triplet');
local_assert_true(isfield(result.diagnostics, 'topCandidateSetsDeg'), ...
    'triplet grid ML saves top candidates');
local_assert_true(size(result.diagnostics.topCandidateSetsDeg, 2) == 3, ...
    'triplet grid ML candidate sets have three columns');
local_assert_true(isfield(result.diagnostics, 'candidateSetIndex'), ...
    'triplet grid ML saves all candidate set indices');
local_assert_true(isfield(result.diagnostics, 'candidateSetScores'), ...
    'triplet grid ML saves all candidate scores');
local_assert_true(isfield(result.diagnostics, 'candidateSetAnglesDeg'), ...
    'triplet grid ML saves all candidate set angles');
local_assert_true(isfield(result.diagnostics, 'marginalAnglesDeg'), ...
    'triplet grid ML saves marginal angles');
local_assert_true(isfield(result.diagnostics, 'marginalConfidence'), ...
    'triplet grid ML saves marginal confidence');
local_assert_equal(numel(result.diagnostics.marginalConfidence), ...
    numel(result.diagnostics.marginalAnglesDeg), ...
    'triplet grid ML marginal confidence length');
local_assert_true(all(diff(result.diagnostics.candidateSetScores) >= -eps), ...
    'triplet grid ML candidate scores sorted');
for trueAngle = [-18 -6 12]
    [distance, marginalIdx] = min(abs(result.diagnostics.marginalAnglesDeg - trueAngle));
    local_assert_true(distance <= 1e-9 && ...
        isfinite(result.diagnostics.marginalConfidence(marginalIdx)), ...
        sprintf('triplet grid ML finite marginal confidence at %.1f deg', trueAngle));
end
end

function local_test_backend_benchmark_common_snapshots(ctx)
rng(9304, 'twister');
methods = repmat(struct('name', '', 'label', '', 'manifold', []), 1, 2);
methods(1) = struct('name', 'oracle_a', 'label', 'Oracle A', 'manifold', ctx.AH);
methods(2) = struct('name', 'oracle_b', 'label', 'Oracle B', 'manifold', ctx.AH);
evalCfg = local_backend_test_eval_cfg();
backendCfg = local_backend_test_backend_cfg(ctx);
bench = benchmark_doa_backends(ctx, methods, evalCfg, backendCfg);
local_assert_equal(bench.snapshotPolicy, 'common_truth_snapshots_across_backends_and_methods', ...
    'backend benchmark common snapshot policy');
local_assert_true(isequaln(bench.rmse(:, :, 1), bench.rmse(:, :, 2)), ...
    'backend benchmark identical methods share RMSE');
local_assert_true(isequaln(bench.stableRate(:, :, 1), bench.stableRate(:, :, 2)), ...
    'backend benchmark identical methods share stable rates');
end

function local_test_backend_benchmark_shapes(ctx)
rng(9305, 'twister');
methods = struct('name', 'oracle', 'label', 'HFSS Oracle', 'manifold', ctx.AH);
evalCfg = local_backend_test_eval_cfg();
backendCfg = local_backend_test_backend_cfg(ctx);
bench = benchmark_doa_backends(ctx, methods, evalCfg, backendCfg);
metricSize = [size(bench.rmse, 1), size(bench.rmse, 2), size(bench.rmse, 3)];
summarySize = [numel(backendCfg.backendNames), numel(methods)];
local_assert_equal(metricSize, [numel(backendCfg.backendNames), size(evalCfg.trueAngles, 1), 1], ...
    'backend benchmark metric dimensions');
local_assert_equal(size(bench.summary.meanRmse), summarySize, ...
    'backend benchmark summary RMSE dimensions');
local_assert_equal(size(bench.summary.meanResolution), summarySize, ...
    'backend benchmark summary resolution dimensions');
local_assert_equal(size(bench.summary.meanStable), summarySize, ...
    'backend benchmark summary stable dimensions');
local_assert_equal(size(bench.summary.meanCollapse), summarySize, ...
    'backend benchmark summary collapse dimensions');
local_assert_true(isfield(bench, 'backendDiagnostics'), 'backend benchmark diagnostics field');
end

function local_test_backend_benchmark_singleton_backend_methods(ctx)
rng(9306, 'twister');
methods = repmat(struct('name', '', 'label', '', 'manifold', []), 1, 2);
methods(1) = struct('name', 'oracle_a', 'label', 'Oracle A', 'manifold', ctx.AH);
methods(2) = struct('name', 'oracle_b', 'label', 'Oracle B', 'manifold', ctx.AH);
evalCfg = local_backend_test_eval_cfg();
backendCfg = local_backend_test_backend_cfg(ctx);
backendCfg.backendNames = {'music'};
bench = benchmark_doa_backends(ctx, methods, evalCfg, backendCfg);
local_assert_equal(size(bench.summary.meanResolution, 1), 1, ...
    'singleton backend summary resolution row count');
local_assert_equal(size(bench.summary.meanResolution, 2), 2, ...
    'singleton backend summary resolution method count');
local_assert_equal(size(bench.summary.meanRmse), [1, 2], ...
    'singleton backend summary RMSE dimensions');
end

function local_test_backend_benchmark_malformed_pair_penalty(ctx)
rng(9307, 'twister');
methods = struct('name', 'oracle', 'label', 'HFSS Oracle', 'manifold', ctx.AH);
evalCfg = local_backend_test_eval_cfg();
evalCfg.trueAngles = evalCfg.trueAngles(1, :);
evalCfg.monteCarlo = 1;
backendCfg = local_backend_test_backend_cfg(ctx);
backendCfg.backendNames = {'music'};
backendCfg.numSources = 1;
bench = benchmark_doa_backends(ctx, methods, evalCfg, backendCfg);
local_assert_true(isinf(bench.rmse(1, 1, 1)), ...
    'malformed backend pair estimate receives infinite RMSE');
local_assert_equal(bench.resolutionRate(1, 1, 1), 0, ...
    'malformed backend pair estimate remains unresolved');
end

function local_test_core_config_defaults(cfg)
local_assert_true(isfield(cfg, 'core'), 'core config exists');
local_assert_true(all(ismember({'manifold_sanity', 'single_source', ...
    'two_source', 'three_source', 'backend_ablation'}, cfg.core.enabledCases)), ...
    'core config names expected cases');
local_assert_equal(size(cfg.core.twoSourcePairsDeg, 2), 2, ...
    'core two-source pairs have two columns');
local_assert_equal(size(cfg.core.threeSourceSetsDeg, 2), 3, ...
    'core three-source sets have three columns');
end

function local_test_core_source_benchmark_common_snapshots(ctx)
rng(9308, 'twister');
methods = repmat(struct('name', '', 'label', '', 'manifold', []), 1, 2);
methods(1) = struct('name', 'oracle_a', 'label', 'Oracle A', 'manifold', ctx.AH);
methods(2) = struct('name', 'oracle_b', 'label', 'Oracle B', 'manifold', ctx.AH);
evalCfg = struct('numSources', 2, 'trueAngles', [6.8 16.8], ...
    'snrDb', 20, 'snapshots', 300, 'monteCarlo', 2, 'toleranceDeg', 1.0, ...
    'backendName', 'pairwise_grid_ml', 'threeSourceBackendName', 'triplet_grid_ml');
backendCfg = struct('candidateAnglesDeg', 0:1:24, 'minimumSeparationDeg', 2, ...
    'maximumSeparationDeg', 30, 'topCandidateCount', 5);
bench = benchmark_core_sources(ctx, methods, evalCfg, backendCfg);
local_assert_equal(bench.snapshotPolicy, 'common_truth_snapshots_across_methods', ...
    'core benchmark common snapshot policy');
local_assert_true(isequaln(bench.perTargetRmse(:, 1), bench.perTargetRmse(:, 2)), ...
    'core benchmark identical methods share RMSE');
local_assert_true(isequaln(bench.perTargetResolvedRate(:, 1), bench.perTargetResolvedRate(:, 2)), ...
    'core benchmark identical methods share resolution rate');
end

function local_test_core_source_benchmark_parallel_backends(ctx)
rng(93042, 'twister');
methods = struct('name', 'oracle', 'label', 'HFSS Oracle', 'manifold', ctx.AH);
evalCfg = struct('numSources', 2, 'trueAngles', [-18 14], 'snrDb', 35, ...
    'snapshots', 1000, 'monteCarlo', 1, 'toleranceDeg', 1.0, ...
    'backendNames', {{'music', 'spice_plus', 'pairwise_grid_ml'}});
backendCfg = struct('candidateAnglesDeg', -30:1:30, ...
    'minimumSeparationDeg', 3, 'maximumSeparationDeg', 60, ...
    'topCandidateCount', 6, 'maxIterations', 40, 'tolerance', 1e-5, ...
    'diagonalLoading', 1e-8);
bench = benchmark_core_sources(ctx, methods, evalCfg, backendCfg);
local_assert_equal(bench.backendNames, evalCfg.backendNames, ...
    'core benchmark preserves backend names');
local_assert_equal(size(bench.perTargetRmse), [1 1 3], ...
    'core benchmark RMSE dimensions target-method-backend');
local_assert_equal(size(bench.summary.meanRmse), [1 3], ...
    'core benchmark summary dimensions method-backend');
local_assert_equal(bench.snapshotPolicy, ...
    'common_truth_snapshots_across_backends_and_methods', ...
    'core benchmark parallel backend snapshot policy');
local_assert_equal(bench.backendDiagnostics{1, 1, 2, 1}.backendName, 'spice_plus', ...
    'core benchmark diagnostics include backend name');
end

function local_test_core_triplet_benchmark(ctx)
rng(9309, 'twister');
methods = struct('name', 'oracle', 'label', 'HFSS Oracle', 'manifold', ctx.AH);
evalCfg = struct('numSources', 3, 'trueAngles', [-18 -6 12], ...
    'snrDb', 30, 'snapshots', 500, 'monteCarlo', 1, 'toleranceDeg', 2.0, ...
    'backendName', 'pairwise_grid_ml', 'threeSourceBackendName', 'triplet_grid_ml');
backendCfg = struct('candidateAnglesDeg', -24:2:18, 'minimumSeparationDeg', 2, ...
    'maximumSeparationDeg', 40, 'topCandidateCount', 5);
bench = benchmark_core_sources(ctx, methods, evalCfg, backendCfg);
local_assert_equal(bench.numSources, 3, 'core triplet benchmark source count');
local_assert_true(bench.perTargetResolvedRate(1, 1) == 1, ...
    'core triplet benchmark resolves high-SNR oracle triplet');
local_assert_true(numel(bench.representative.estAnglesDeg) == 3, ...
    'core triplet benchmark representative estimate has three angles');
end

function local_test_case13_condition_construction(cfg)
conditions = case13_helpers('condition_table', cfg.case13);
local_assert_true(~isempty(conditions), 'case13 condition table is nonempty');
local_assert_true(all([conditions.calibrationCount] >= 5), ...
    'case13 condition calibration counts populated');
local_assert_true(all(ismember([conditions.numSources], [1 2 3])), ...
    'case13 condition source counts valid');
threeSourceIdx = find([conditions.numSources] == 3, 1, 'first');
local_assert_true(numel(conditions(threeSourceIdx).targetAnglesDeg) == 3, ...
    'case13 three-source targets have three angles');
end

function local_test_case13_delta_label()
local_assert_equal(case13_helpers('delta_label', -0.10, 0.05, true), 'win', ...
    'case13 negative RMSE delta is win');
local_assert_equal(case13_helpers('delta_label', 0.10, 0.05, true), 'loss', ...
    'case13 positive RMSE delta is loss');
local_assert_equal(case13_helpers('delta_label', 0.01, 0.05, true), 'neutral', ...
    'case13 small RMSE delta is neutral');
local_assert_equal(case13_helpers('delta_label', 0.10, 0.05, false), 'win', ...
    'case13 positive resolved-rate delta is win');
end

function evalCfg = local_backend_test_eval_cfg()
evalCfg = struct('mode', 'double', 'trueAngles', [23.8 31.8; 35.8 45.8], ...
    'snrDb', 15, 'snapshots', 300, 'monteCarlo', 2, 'toleranceDeg', 0.6, ...
    'biasedToleranceDeg', 2, 'marginalToleranceDeg', 5, ...
    'collectRepresentative', true);
end

function backendCfg = local_backend_test_backend_cfg(ctx)
backendCfg = struct();
backendCfg.backendNames = {'music', 'music_pair_rescore', 'pairwise_grid_ml'};
backendCfg.candidatePeakCount = 8;
backendCfg.minimumSeparationDeg = 2;
backendCfg.maximumSeparationDeg = 30;
backendCfg.candidateAnglesDeg = unique([23.8 31.8 35.8 45.8 -30:2:50]);
backendCfg.topCandidateCount = 5;
backendCfg.numSources = 2;
backendCfg.scanAnglesDeg = ctx.thetaDeg;
end

function x = local_simulate_snapshots(aTrue, snrDb, snapshots)
sourceSignals = (randn(size(aTrue, 2), snapshots) + 1i * randn(size(aTrue, 2), snapshots)) / sqrt(2);
signalOnly = aTrue * sourceSignals;
signalPower = mean(abs(signalOnly(:)) .^ 2);
noisePower = signalPower / (10 ^ (snrDb / 10));
noise = sqrt(noisePower / 2) * (randn(size(signalOnly)) + 1i * randn(size(signalOnly)));
x = signalOnly + noise;
end

function idx = local_angle_index(thetaDeg, queryAngle)
[distance, idx] = min(abs(thetaDeg - queryAngle));
tolDeg = median(diff(sort(thetaDeg))) / 2 + 1e-9;
if distance > tolDeg
    error('Angle %.6f deg is not on the grid.', queryAngle);
end
end

function local_assert_true(condition, message)
if ~condition
    error('Sanity test failed: %s', message);
end
fprintf('PASS: %s\n', message);
end

function local_assert_equal(actual, expected, message)
if ischar(actual) || isstring(actual)
    condition = strcmp(char(actual), char(expected));
else
    condition = isequaln(actual, expected);
end
local_assert_true(condition, message);
end

function local_assert_close(actual, expected, tolerance, message)
condition = all(abs(actual(:) - expected(:)) <= tolerance);
local_assert_true(condition, message);
end

function local_assert_error(callback, expectedIdentifier, message)
try
    callback();
catch err
    local_assert_true(strcmp(err.identifier, expectedIdentifier), message);
    return;
end
error('Sanity test failed: %s', message);
end
