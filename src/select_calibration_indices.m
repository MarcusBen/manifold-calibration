function calIdx = select_calibration_indices(thetaDeg, numSamples, strategy, seed)
%SELECT_CALIBRATION_INDICES Pick calibration angles using a named strategy.

arguments
    thetaDeg (1, :) double
    numSamples (1, 1) double {mustBeInteger, mustBePositive}
    strategy (1, :) char
    seed (1, 1) double = NaN
end

numAngles = numel(thetaDeg);
if numSamples > numAngles
    error('Requested %d calibration angles, but only %d are available.', ...
        numSamples, numAngles);
end

strategy = lower(strtrim(strategy));

switch strategy
    case 'uniform'
        targetAngles = linspace(thetaDeg(1), thetaDeg(end), numSamples);
        calIdx = local_match_targets(thetaDeg, targetAngles, numSamples);
    case 'center_dense'
        z = linspace(-1, 1, numSamples);
        targetAngles = max(abs(thetaDeg)) * (z .^ 3);
        calIdx = local_match_targets(thetaDeg, targetAngles, numSamples);
    case 'edge_enhanced'
        z = linspace(-1, 1, numSamples);
        targetAngles = max(abs(thetaDeg)) * sign(z) .* abs(z) .^ (1/3);
        calIdx = local_match_targets(thetaDeg, targetAngles, numSamples);
    case 'random'
        if ~isnan(seed)
            rng(seed, 'twister');
        end
        calIdx = sort(randperm(numAngles, numSamples));
    otherwise
        error('Unknown calibration strategy: %s', strategy);
end
end

function calIdx = local_match_targets(thetaDeg, targetAngles, numSamples)
selected = zeros(1, 0);

for target = targetAngles
    [~, order] = sort(abs(thetaDeg - target), 'ascend');
    for candidate = order
        if ~ismember(candidate, selected)
            selected(end+1) = candidate; %#ok<AGROW>
            break;
        end
    end
end

if numel(selected) < numSamples
    remaining = setdiff(1:numel(thetaDeg), selected, 'stable');
    [~, fillOrder] = sort(abs(thetaDeg(remaining) - mean(thetaDeg)), 'ascend');
    selected = [selected, remaining(fillOrder(1:(numSamples-numel(selected))))]; %#ok<AGROW>
end

calIdx = sort(unique(selected(1:numSamples)));
end
