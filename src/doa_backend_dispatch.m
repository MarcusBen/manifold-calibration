function backendResult = doa_backend_dispatch(backendName, x, scanManifold, scanAnglesDeg, backendCfg)
%DOA_BACKEND_DISPATCH Run a named DOA backend through the common contract.

if nargin < 5 || isempty(backendCfg)
    backendCfg = struct();
end

switch lower(strtrim(backendName))
    case 'music'
        backendResult = doa_backend_music_baseline(x, scanManifold, scanAnglesDeg, backendCfg);
    case 'music_pair_rescore'
        backendResult = doa_backend_music_pair_rescore(x, scanManifold, scanAnglesDeg, backendCfg);
    case 'spice'
        backendCfg.variant = 'spice';
        backendResult = doa_backend_spice(x, scanManifold, scanAnglesDeg, backendCfg);
    case 'spice_plus'
        backendCfg.variant = 'spice_plus';
        backendResult = doa_backend_spice(x, scanManifold, scanAnglesDeg, backendCfg);
    case 'pairwise_grid_ml'
        backendResult = doa_backend_pairwise_grid_ml(x, scanManifold, scanAnglesDeg, backendCfg);
    case 'triplet_grid_ml'
        backendResult = doa_backend_triplet_grid_ml(x, scanManifold, scanAnglesDeg, backendCfg);
    otherwise
        error('Unknown DOA backend: %s', backendName);
end
end
