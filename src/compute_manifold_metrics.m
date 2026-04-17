function metrics = compute_manifold_metrics(referenceManifold, estimateManifold)
%COMPUTE_MANIFOLD_METRICS Evaluate manifold mismatch column by column.

if ~isequal(size(referenceManifold), size(estimateManifold))
    error('Reference and estimate manifolds must have the same size.');
end

diffManifold = estimateManifold - referenceManifold;
refNorm = vecnorm(referenceManifold, 2, 1);
refNorm(refNorm < eps) = 1;

metrics = struct();
metrics.relativeError = vecnorm(diffManifold, 2, 1) ./ refNorm;
metrics.correlation = abs(sum(conj(referenceManifold) .* estimateManifold, 1)) ./ ...
    (vecnorm(referenceManifold, 2, 1) .* vecnorm(estimateManifold, 2, 1));
metrics.phaseRmseRad = sqrt(mean(angle(estimateManifold .* conj(referenceManifold)) .^ 2, 1));
metrics.amplitudeRmse = sqrt(mean((abs(estimateManifold) - abs(referenceManifold)) .^ 2, 1));
end
