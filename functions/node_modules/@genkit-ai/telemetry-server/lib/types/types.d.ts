import { type TraceData } from '@genkit-ai/tools-common';
import * as z from 'zod';
export declare const TraceQuerySchema: z.ZodObject<{
    limit: z.ZodOptional<z.ZodNumber>;
    continuationToken: z.ZodOptional<z.ZodString>;
    filter: z.ZodOptional<z.ZodObject<{
        eq: z.ZodOptional<z.ZodRecord<z.ZodString, z.ZodUnion<[z.ZodString, z.ZodNumber]>>>;
        neq: z.ZodOptional<z.ZodRecord<z.ZodString, z.ZodUnion<[z.ZodString, z.ZodNumber]>>>;
    }, "strip", z.ZodTypeAny, {
        eq?: Record<string, string | number> | undefined;
        neq?: Record<string, string | number> | undefined;
    }, {
        eq?: Record<string, string | number> | undefined;
        neq?: Record<string, string | number> | undefined;
    }>>;
}, "strip", z.ZodTypeAny, {
    limit?: number | undefined;
    continuationToken?: string | undefined;
    filter?: {
        eq?: Record<string, string | number> | undefined;
        neq?: Record<string, string | number> | undefined;
    } | undefined;
}, {
    limit?: number | undefined;
    continuationToken?: string | undefined;
    filter?: {
        eq?: Record<string, string | number> | undefined;
        neq?: Record<string, string | number> | undefined;
    } | undefined;
}>;
export type TraceQuery = z.infer<typeof TraceQuerySchema>;
export interface TraceQueryResponse {
    traces: TraceData[];
    continuationToken?: string;
}
export interface TraceStore {
    init(): Promise<void>;
    save(traceId: string, trace: TraceData): Promise<void>;
    load(traceId: string): Promise<TraceData | undefined>;
    list(query?: TraceQuery): Promise<TraceQueryResponse>;
}
