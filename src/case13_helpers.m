function varargout = case13_helpers(action, varargin)
%CASE13_HELPERS Deterministic helpers for backend-switched advantage audit.

switch lower(strtrim(action))
    case 'profile_config'
        varargout{1} = local_profile_config(varargin{:});
    case 'target_sets'
        [varargout{1:nargout}] = local_target_sets(varargin{:});
    case 'condition_table'
        varargout{1} = local_condition_table(varargin{:});
    case 'delta_label'
        varargout{1} = local_delta_label(varargin{:});
    otherwise
        error('Unsupported Case13 helper action: %s', action);
end
end

function auditCfg = local_profile_config(case13Cfg)
auditCfg = case13Cfg;
profileName = lower(strtrim(case13Cfg.profile));
switch profileName
    case 'auditsmoke'
        auditCfg.monteCarlo = case13Cfg.auditSmokeMonteCarlo;
        auditCfg.targetsPerCondition = 1;
        auditCfg.calibrationCounts = case13Cfg.auditSmokeCalibrationCounts;
        auditCfg.snrDb = case13Cfg.auditSmokeSNRDb;
        auditCfg.strata = case13Cfg.auditSmokeStrata;
    case 'auditfull'
        auditCfg.monteCarlo = case13Cfg.auditFullMonteCarlo;
        auditCfg.targetsPerCondition = 2;
    otherwise
        error('Unknown Case13 profile: %s', case13Cfg.profile);
end
end

function targets = local_target_sets(numSources, stratum, difficulty)
stratum = lower(strtrim(stratum));
difficulty = lower(strtrim(difficulty));
if numSources == 1
    switch stratum
        case 'center'
            angleSets = [0; 8.8];
        case 'mid'
            angleSets = [-24.2; 24.8];
        case 'edge'
            angleSets = [-46.2; 46.8];
        otherwise
            error('Unknown Case13 stratum: %s', stratum);
    end
elseif numSources == 2
    switch stratum
        case 'center'
            medium = [-8.2 3.8; 6.8 16.8];
            hard = [-4.2 3.8; 10.8 16.8];
        case 'mid'
            medium = [-28.2 -16.2; 20.8 32.8];
            hard = [-24.2 -16.2; 24.8 32.8];
        case 'edge'
            medium = [-50.2 -38.2; 38.8 50.8];
            hard = [-46.2 -38.2; 42.8 50.8];
        otherwise
            error('Unknown Case13 stratum: %s', stratum);
    end
    angleSets = local_pick_difficulty(medium, hard, difficulty);
elseif numSources == 3
    switch stratum
        case 'center'
            medium = [-12.2 0 12.8; -8.2 4.8 18.8];
            hard = [-8.2 0 8.8; -4.2 4.8 12.8];
        case 'mid'
            medium = [-30.2 -16.2 -2.2; 12.8 26.8 40.8];
            hard = [-24.2 -14.2 -4.2; 20.8 30.8 40.8];
        case 'edge'
            medium = [-54.2 -42.2 -30.2; 30.8 42.8 54.8];
            hard = [-52.2 -44.2 -36.2; 36.8 44.8 52.8];
        otherwise
            error('Unknown Case13 stratum: %s', stratum);
    end
    angleSets = local_pick_difficulty(medium, hard, difficulty);
else
    error('Unsupported Case13 source count: %d', numSources);
end
targets = struct();
targets.numSources = numSources;
targets.stratum = stratum;
targets.difficulty = difficulty;
targets.angleSetsDeg = angleSets;
end

function angleSets = local_pick_difficulty(medium, hard, difficulty)
switch difficulty
    case 'medium'
        angleSets = medium;
    case 'hard'
        angleSets = hard;
    otherwise
        error('Unknown Case13 difficulty: %s', difficulty);
end
end

function conditions = local_condition_table(case13Cfg)
auditCfg = local_profile_config(case13Cfg);
rows = struct('calibrationCount', {}, 'snrDb', {}, 'numSources', {}, ...
    'stratum', {}, 'difficulty', {}, 'targetAnglesDeg', {});
for calCount = reshape(auditCfg.calibrationCounts, 1, [])
    for snrDb = reshape(auditCfg.snrDb, 1, [])
        for numSources = 1:3
            for stratumIdx = 1:numel(auditCfg.strata)
                stratum = auditCfg.strata{stratumIdx};
                if numSources == 1
                    difficultyList = {'medium'};
                else
                    difficultyList = auditCfg.difficulties;
                end
                for difficultyIdx = 1:numel(difficultyList)
                    difficulty = difficultyList{difficultyIdx};
                    targets = local_target_sets(numSources, stratum, difficulty);
                    targetCount = min(auditCfg.targetsPerCondition, size(targets.angleSetsDeg, 1));
                    for targetIdx = 1:targetCount
                        rows(end+1).calibrationCount = calCount; %#ok<AGROW>
                        rows(end).snrDb = snrDb;
                        rows(end).numSources = numSources;
                        rows(end).stratum = stratum;
                        rows(end).difficulty = difficulty;
                        rows(end).targetAnglesDeg = targets.angleSetsDeg(targetIdx, :);
                    end
                end
            end
        end
    end
end
conditions = rows;
end

function label = local_delta_label(deltaValue, tolerance, lowerIsBetter)
if nargin < 3
    lowerIsBetter = true;
end
if lowerIsBetter
    if deltaValue < -tolerance
        label = 'win';
    elseif deltaValue > tolerance
        label = 'loss';
    else
        label = 'neutral';
    end
else
    if deltaValue > tolerance
        label = 'win';
    elseif deltaValue < -tolerance
        label = 'loss';
    else
        label = 'neutral';
    end
end
end
