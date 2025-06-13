import type { TraceStore } from './types';
export { LocalFileTraceStore } from './localFileTraceStore.js';
export { TraceQuerySchema, type TraceQuery, type TraceStore } from './types';
export declare function startTelemetryServer(params: {
    port: number;
    traceStore: TraceStore;
    maxRequestBodySize?: string | number;
}): Promise<void>;
export declare function stopTelemetryApi(): Promise<void>;
