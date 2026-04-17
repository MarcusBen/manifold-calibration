function models = build_sparse_models(ctx, calIdx, modelCfg)
%BUILD_SPARSE_MODELS Fit the proposed phase model and an interpolation baseline.

calIdx = sort(unique(calIdx(:).'));
testIdx = setdiff(1:ctx.numAngles, calIdx);
calAngles = ctx.thetaDeg(calIdx);

phaseTruthFull = unwrap(angle(ctx.AH .* conj(ctx.AI)), [], 2);
phaseCal = phaseTruthFull(:, calIdx);

phaseModel = local_fit_scalar_residual_model(calAngles, phaseCal, modelCfg);
phaseFitFull = local_predict_scalar_residual_model(phaseModel, ctx.thetaDeg);

interpMethod = modelCfg.interpMethod;
if strcmpi(interpMethod, 'spline') && numel(calAngles) < 4
    interpMethod = 'linear';
end
interpModel = local_fit_phase_interpolant(calAngles, phaseCal, interpMethod);
phaseInterpFull = local_apply_phase_interpolant(interpModel, ctx.thetaDeg);

aProposed = local_normalize_columns(exp(1i * phaseFitFull) .* ctx.AI);
aInterp = local_normalize_columns(exp(1i * phaseInterpFull) .* ctx.AI);

models = struct();
models.calIdx = calIdx;
models.testIdx = testIdx;
models.calAnglesDeg = calAngles;
models.testAnglesDeg = ctx.thetaDeg(testIdx);
models.phaseTruthFull = phaseTruthFull;
models.phaseFitFull = phaseFitFull;
models.phaseInterpFull = phaseInterpFull;
models.phaseModel = phaseModel;
models.interpModel = interpModel;
models.AProposed = aProposed;
models.AInterp = aInterp;
end

function model = local_fit_scalar_residual_model(thetaCalDeg, residualCal, modelCfg)
[thetaCalDeg, orderIdx] = sort(thetaCalDeg, 'ascend');
residualCal = residualCal(:, orderIdx);

uCal = sind(thetaCalDeg);
psi = local_build_basis_matrix(uCal, modelCfg.basisType, modelCfg.order);
dMat = local_build_regularization_matrix(modelCfg.order, modelCfg.regularization);

systemMatrix = psi * psi.' + modelCfg.lambda * (dMat.' * dMat);
if rcond(systemMatrix) < 1e-12
    systemMatrix = systemMatrix + 1e-9 * eye(size(systemMatrix));
end

coeff = (residualCal * psi.') / systemMatrix;

model = struct();
model.thetaCalDeg = thetaCalDeg;
model.uCal = uCal;
model.coeff = coeff;
model.basisType = modelCfg.basisType;
model.order = modelCfg.order;
model.lambda = modelCfg.lambda;
model.regularization = modelCfg.regularization;
end

function residualPred = local_predict_scalar_residual_model(model, thetaQueryDeg)
psi = local_build_basis_matrix(sind(thetaQueryDeg), model.basisType, model.order);
residualPred = model.coeff * psi;
end

function interpModel = local_fit_phase_interpolant(thetaCalDeg, phaseCal, method)
[thetaCalDeg, orderIdx] = sort(thetaCalDeg, 'ascend');
interpModel = struct();
interpModel.thetaCalDeg = thetaCalDeg;
interpModel.uCal = sind(thetaCalDeg);
interpModel.phaseCal = phaseCal(:, orderIdx);
interpModel.method = method;
end

function phasePred = local_apply_phase_interpolant(interpModel, thetaQueryDeg)
uQuery = sind(thetaQueryDeg);
phasePred = zeros(size(interpModel.phaseCal, 1), numel(thetaQueryDeg));

for rowIdx = 1:size(interpModel.phaseCal, 1)
    phasePred(rowIdx, :) = interp1( ...
        interpModel.uCal, ...
        interpModel.phaseCal(rowIdx, :), ...
        uQuery, ...
        interpModel.method, ...
        'extrap');
end
end

function psi = local_build_basis_matrix(u, basisType, order)
u = reshape(u, 1, []);
psi = zeros(order + 1, numel(u));

switch lower(strtrim(basisType))
    case 'polynomial'
        for powerIdx = 0:order
            psi(powerIdx + 1, :) = u .^ powerIdx;
        end
    case 'chebyshev'
        psi(1, :) = 1;
        if order >= 1
            psi(2, :) = u;
        end
        for orderIdx = 2:order
            psi(orderIdx + 1, :) = 2 * u .* psi(orderIdx, :) - psi(orderIdx - 1, :);
        end
    otherwise
        error('Unsupported basis type: %s', basisType);
end
end

function dMat = local_build_regularization_matrix(order, regularizationType)
switch lower(strtrim(regularizationType))
    case 'identity'
        dMat = eye(order + 1);
        dMat(1, 1) = 0;
    case 'order-weighted'
        dMat = diag([0, 1:order]);
    otherwise
        error('Unsupported regularization type: %s', regularizationType);
end
end

function manifold = local_normalize_columns(manifold)
refPhase = exp(-1i * angle(manifold(1, :)));
manifold = manifold .* refPhase;
colNorm = vecnorm(manifold, 2, 1);
colNorm(colNorm < eps) = 1;
manifold = manifold ./ colNorm;
end
