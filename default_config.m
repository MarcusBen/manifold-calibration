function cfg = default_config(rootDir, profileName)
%DEFAULT_CONFIG Create the default MATLAB configuration for the project.

if nargin < 1 || isempty(rootDir)
    rootDir = fileparts(mfilename('fullpath'));
end
if nargin < 2 || isempty(profileName)
    profileName = 'default';
end
profileName = char(profileName);

cfg = struct();
cfg.rootDir = rootDir;
cfg.outputDir = fullfile(rootDir, 'results_step0p2_qw');
cfg.randomSeed = 20260417;

cfg.data = struct();
cfg.data.csvPath = fullfile(rootDir, 'data', 'hfss', 'step0.2deg.csv');

cfg.array = struct();
cfg.array.numElements = 8;
cfg.array.frequencyHz = 2.5e9;
cfg.array.elementSpacingLambda = 0.25;

cfg.run = struct();
cfg.run.useTraceableDirs = false;
cfg.run.resultRoot = fullfile(rootDir, 'results');
cfg.run.runId = '';
cfg.run.pendingLocalHash = '';
cfg.run.baseHead = '';
cfg.run.gitStatusShort = '';
cfg.run.command = '';
cfg.run.notes = '';

cfg.eval = struct();
cfg.eval.targetMode = 'stratified';
cfg.eval.targetStrideDeg = 2;
cfg.eval.edgeBandDeg = 8;
cfg.eval.highMismatchCount = 12;
cfg.eval.useFullGridForManifoldMetrics = true;

cfg.model = struct();
cfg.model.basisType = 'chebyshev';
cfg.model.order = 3;
cfg.model.lambda = 1e-3;
cfg.model.interpMethod = 'spline';
cfg.model.regularization = 'order-weighted';
cfg.model.ard = struct();
cfg.model.ard.enabled = true;
cfg.model.ard.label = 'ARD';
cfg.model.ard.method = 'complex_correction_vector';
cfg.model.v2 = struct();
cfg.model.v2.enabled = true;
cfg.model.v2.label = 'Proposed V2';
cfg.model.v2.stage = 'full';
cfg.model.v2.segmentCentersDeg = [-50 0 50];
cfg.model.v2.order = 2;
cfg.model.v2.lambda = 1e-3;
cfg.model.v2.candidateMismatchWeights = [1 2 4];
cfg.model.v2.candidateEdgeWeights = [0.5 1 2];
cfg.model.v2.taskWeight = 0.25;
cfg.model.v2.taskNeighborhoodDeg = 0.4;
cfg.model.v2.pairTaskEnabled = true;
cfg.model.v2.taskDataMode = 'heldout_hfss';
cfg.model.v2.taskScanStrideDeg = 1;
cfg.model.v2.taskSingleHeldoutCount = 12;
cfg.model.v2.taskPairSeparationDeg = [4 5 6 8 10];
cfg.model.v2.taskPairCount = 16;
cfg.model.v2.taskSnrDb = 25;
cfg.model.v2.numSpsaIterations = 18;
cfg.model.v2.learningRate = 0.035;
cfg.model.v2.perturbationScale = 0.025;
cfg.model.v2.lambdaCal = 1;
cfg.model.v2.lambdaSmooth = 1e-3;
cfg.model.v2.lambdaSingle = 0.15;
cfg.model.v2.lambdaPair = 0.20;
cfg.model.v2.lambdaMid = 0.08;
cfg.model.v2.lambdaReg = 1e-4;
cfg.model.v2.softmaxGamma = 8;
cfg.model.v2.midMargin = 0.2;
cfg.model.v3 = struct();
cfg.model.v3.enabled = true;
cfg.model.v3.label = 'Proposed V3';
cfg.model.v3.base = 'ard';
cfg.model.v3.stage = 'ard_anchored_task_refinement';
cfg.model.v3.segmentCentersDeg = [-50 0 50];
cfg.model.v3.order = 1;
cfg.model.v3.lambda = 1e-3;
cfg.model.v3.pairTaskEnabled = true;
cfg.model.v3.lambdaCal = 1;
cfg.model.v3.lambdaSingle = 0.08;
cfg.model.v3.lambdaPair = 0.12;
cfg.model.v3.lambdaMid = 0.04;
cfg.model.v3.lambdaAnchor = 5;
cfg.model.v3.lambdaSmooth = 1e-3;
cfg.model.v3.lambdaReg = 1e-4;
cfg.model.v3.taskDataMode = 'heldout_hfss';
cfg.model.v3.taskScanStrideDeg = 1;
cfg.model.v3.taskSingleHeldoutCount = 12;
cfg.model.v3.taskPairSeparationDeg = [4 5 6 8 10];
cfg.model.v3.taskPairCount = 16;
cfg.model.v3.taskSnrDb = 25;
cfg.model.v3.numSpsaIterations = 12;
cfg.model.v3.learningRate = 0.020;
cfg.model.v3.perturbationScale = 0.015;
cfg.model.v3.maxGradNorm = 5;
cfg.model.v3.softmaxGamma = 8;
cfg.model.v3.midMargin = 0.2;

cfg.case1 = struct();
cfg.case1.exampleAngleDeg = 25; % Manual fallback only; default Case 1 selects a stress angle from the high-SNR sweep.
cfg.case1.highSNRDb = 40;
cfg.case1.snapshots = 2000;
cfg.case1.monteCarlo = 80;
cfg.case1.toleranceDeg = 0.4;

cfg.case2 = struct();
cfg.case2.evalSNRDb = 10;
cfg.case2.snapshots = 500;
cfg.case2.monteCarlo = 60;
cfg.case2.toleranceDeg = 1;

cfg.case3 = struct();
cfg.case3.lValues = [5 9 13];
cfg.case3.representativeL = 9;
cfg.case3.representativeElements = [1 4 8];
cfg.case3.representativeAnglesDeg = [-35 0 35];

cfg.case4 = struct();
cfg.case4.lValues = [3 5 7 9 13 17];
cfg.case4.evalSNRDb = 10;
cfg.case4.snapshots = 500;
cfg.case4.monteCarlo = 200;
cfg.case4.toleranceDeg = 1;
cfg.case4.separationSweepDeg = [4 5 6 8 10];
cfg.case4.maxPairsPerSeparation = 8;
cfg.case4.pairSelectionMode = 'research_coverage';
cfg.case4.sourcePairsDeg = [];
cfg.case4.useCommonTestSet = true;

cfg.case5 = struct();
cfg.case5.l = 9;
cfg.case5.strategyNames = {'uniform', 'center_dense', 'edge_enhanced', 'random'};
cfg.case5.randomTrials = 20;
cfg.case5.snrSweepDb = -10:5:15;
cfg.case5.snapshots = 300;
cfg.case5.monteCarlo = 40;
cfg.case5.toleranceDeg = 1;

cfg.case6 = struct();
cfg.case6.l = 9;
cfg.case6.orders = 1:5;
cfg.case6.lambdas = [0 1e-4 1e-3 1e-2 1e-1];
cfg.case6.basisTypes = {'polynomial', 'chebyshev'};
cfg.case6.lambdaSingleValues = [0 0.15];
cfg.case6.lambdaPairValues = [0 0.20];
cfg.case6.lambdaMidValues = [0 0.08];
cfg.case6.taskPairCounts = [0 16];
cfg.case6.case6V2Iterations = 10;

cfg.case7 = struct();
cfg.case7.snrSweepDb = -15:5:20;
cfg.case7.snapshots = 500;
cfg.case7.monteCarlo = 80;
cfg.case7.toleranceDeg = 0.5;
cfg.case7.exampleAngleMode = 'auto_high_mismatch_edge';
cfg.case7.exampleAngleDeg = 10;
cfg.case7.spectrumSnrDb = [-10 0 10];

cfg.case8 = struct();
cfg.case8.snapshotSweep = [50 100 200 500 1000];
cfg.case8.snrValuesDb = [0 10];
cfg.case8.monteCarlo = 80;
cfg.case8.toleranceDeg = 0.5;

cfg.case9 = struct();
cfg.case9.evalSNRDb = 5;
cfg.case9.snapshots = 500;
cfg.case9.monteCarlo = 80;
cfg.case9.toleranceDeg = 0.6;
cfg.case9.biasedToleranceDeg = 2;
cfg.case9.marginalToleranceDeg = 5;
cfg.case9.separationSweepDeg = [1 2 3 4 5 6 8 10];
cfg.case9.maxPairsPerSeparation = 21;
cfg.case9.pairSelectionMode = 'research_coverage';
cfg.case9.sourcePairsDeg = [];
cfg.case9.exampleTargetResolutionProb = 0.5;

cfg.case10 = struct();
cfg.case10.l = 9;
cfg.case10.numSplits = 40;
cfg.case10.evalSNRDb = 10;
cfg.case10.snapshots = 500;
cfg.case10.monteCarlo = 40;
cfg.case10.toleranceDeg = 1;

cfg = local_apply_profile(cfg, profileName);
end

function cfg = local_apply_profile(cfg, profileName)
switch lower(strtrim(profileName))
    case {'default', 'daily', ''}
        return;
    case 'paper'
        cfg.case1.monteCarlo = 120;
        cfg.case4.monteCarlo = 200;
        cfg.case7.monteCarlo = 200;
        cfg.case8.monteCarlo = 200;
        cfg.case9.monteCarlo = 300;
        cfg.model.v2.numSpsaIterations = 24;
        cfg.model.v3.numSpsaIterations = 18;
    otherwise
        error('Unknown default_config profile: %s', profileName);
end
end
