import { z } from 'zod';
export declare const GenkitErrorSchema: z.ZodObject<{
    message: z.ZodString;
    stack: z.ZodOptional<z.ZodString>;
    details: z.ZodOptional<z.ZodAny>;
    data: z.ZodOptional<z.ZodObject<{
        genkitErrorMessage: z.ZodOptional<z.ZodString>;
        genkitErrorDetails: z.ZodOptional<z.ZodObject<{
            stack: z.ZodOptional<z.ZodString>;
            traceId: z.ZodString;
        }, "strip", z.ZodTypeAny, {
            traceId: string;
            stack?: string | undefined;
        }, {
            traceId: string;
            stack?: string | undefined;
        }>>;
    }, "strip", z.ZodTypeAny, {
        genkitErrorMessage?: string | undefined;
        genkitErrorDetails?: {
            traceId: string;
            stack?: string | undefined;
        } | undefined;
    }, {
        genkitErrorMessage?: string | undefined;
        genkitErrorDetails?: {
            traceId: string;
            stack?: string | undefined;
        } | undefined;
    }>>;
}, "strip", z.ZodTypeAny, {
    message: string;
    data?: {
        genkitErrorMessage?: string | undefined;
        genkitErrorDetails?: {
            traceId: string;
            stack?: string | undefined;
        } | undefined;
    } | undefined;
    stack?: string | undefined;
    details?: any;
}, {
    message: string;
    data?: {
        genkitErrorMessage?: string | undefined;
        genkitErrorDetails?: {
            traceId: string;
            stack?: string | undefined;
        } | undefined;
    } | undefined;
    stack?: string | undefined;
    details?: any;
}>;
export type GenkitError = z.infer<typeof GenkitErrorSchema>;
