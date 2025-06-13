import z from 'zod';
const EmptyPartSchema = z.object({
    text: z.never().optional(),
    media: z.never().optional(),
    toolRequest: z.never().optional(),
    toolResponse: z.never().optional(),
    data: z.unknown().optional(),
    metadata: z.record(z.unknown()).optional(),
    custom: z.record(z.unknown()).optional(),
    reasoning: z.never().optional(),
});
export const TextPartSchema = EmptyPartSchema.extend({
    text: z.string(),
});
export const ReasoningPartSchema = EmptyPartSchema.extend({
    reasoning: z.string(),
});
export const MediaSchema = z.object({
    contentType: z.string().optional(),
    url: z.string(),
});
export const MediaPartSchema = EmptyPartSchema.extend({
    media: MediaSchema,
});
export const ToolRequestSchema = z.object({
    ref: z.string().optional(),
    name: z.string(),
    input: z.unknown().optional(),
});
export const ToolRequestPartSchema = EmptyPartSchema.extend({
    toolRequest: ToolRequestSchema,
});
export const ToolResponseSchema = z.object({
    ref: z.string().optional(),
    name: z.string(),
    output: z.unknown().optional(),
});
export const ToolResponsePartSchema = EmptyPartSchema.extend({
    toolResponse: ToolResponseSchema,
});
export const DataPartSchema = EmptyPartSchema.extend({
    data: z.unknown(),
});
export const CustomPartSchema = EmptyPartSchema.extend({
    custom: z.record(z.any()),
});
export const DocumentPartSchema = z.union([TextPartSchema, MediaPartSchema]);
export const DocumentDataSchema = z.object({
    content: z.array(DocumentPartSchema),
    metadata: z.record(z.string(), z.any()).optional(),
});
//# sourceMappingURL=document.js.map