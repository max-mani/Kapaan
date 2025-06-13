import { z } from 'zod';
export const GenkitErrorSchema = z.object({
    message: z.string(),
    stack: z.string().optional(),
    details: z.any().optional(),
    data: z
        .object({
        genkitErrorMessage: z.string().optional(),
        genkitErrorDetails: z
            .object({
            stack: z.string().optional(),
            traceId: z.string(),
        })
            .optional(),
    })
        .optional(),
});
//# sourceMappingURL=error.js.map