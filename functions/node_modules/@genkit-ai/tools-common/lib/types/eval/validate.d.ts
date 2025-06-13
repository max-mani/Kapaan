import type { RuntimeManager } from '../manager';
import { type ValidateDataRequest, type ValidateDataResponse } from '../types';
export declare function validateSchema(manager: RuntimeManager, request: ValidateDataRequest): Promise<ValidateDataResponse>;
