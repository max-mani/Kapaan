import type { RuntimeManager } from '../manager/manager';
import { type Action, type Dataset, type EvalInput, type EvalKeyAugments, type EvalRun, type EvalRunKey, type RunNewEvaluationRequest } from '../types';
export declare function runNewEvaluation(manager: RuntimeManager, request: RunNewEvaluationRequest): Promise<EvalRunKey>;
export declare function runInference(params: {
    manager: RuntimeManager;
    actionRef: string;
    inferenceDataset: Dataset;
    context?: string;
    actionConfig?: any;
}): Promise<EvalInput[]>;
export declare function runEvaluation(params: {
    manager: RuntimeManager;
    evaluatorActions: Action[];
    evalDataset: EvalInput[];
    augments?: EvalKeyAugments;
    batchSize?: number;
}): Promise<EvalRun>;
export declare function getAllEvaluatorActions(manager: RuntimeManager): Promise<Action[]>;
export declare function getMatchingEvaluatorActions(manager: RuntimeManager, evaluators?: string[]): Promise<Action[]>;
