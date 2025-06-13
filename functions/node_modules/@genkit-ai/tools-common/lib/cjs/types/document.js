"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.DocumentDataSchema = exports.DocumentPartSchema = exports.CustomPartSchema = exports.DataPartSchema = exports.ToolResponsePartSchema = exports.ToolResponseSchema = exports.ToolRequestPartSchema = exports.ToolRequestSchema = exports.MediaPartSchema = exports.MediaSchema = exports.ReasoningPartSchema = exports.TextPartSchema = void 0;
const zod_1 = __importDefault(require("zod"));
const EmptyPartSchema = zod_1.default.object({
    text: zod_1.default.never().optional(),
    media: zod_1.default.never().optional(),
    toolRequest: zod_1.default.never().optional(),
    toolResponse: zod_1.default.never().optional(),
    data: zod_1.default.unknown().optional(),
    metadata: zod_1.default.record(zod_1.default.unknown()).optional(),
    custom: zod_1.default.record(zod_1.default.unknown()).optional(),
    reasoning: zod_1.default.never().optional(),
});
exports.TextPartSchema = EmptyPartSchema.extend({
    text: zod_1.default.string(),
});
exports.ReasoningPartSchema = EmptyPartSchema.extend({
    reasoning: zod_1.default.string(),
});
exports.MediaSchema = zod_1.default.object({
    contentType: zod_1.default.string().optional(),
    url: zod_1.default.string(),
});
exports.MediaPartSchema = EmptyPartSchema.extend({
    media: exports.MediaSchema,
});
exports.ToolRequestSchema = zod_1.default.object({
    ref: zod_1.default.string().optional(),
    name: zod_1.default.string(),
    input: zod_1.default.unknown().optional(),
});
exports.ToolRequestPartSchema = EmptyPartSchema.extend({
    toolRequest: exports.ToolRequestSchema,
});
exports.ToolResponseSchema = zod_1.default.object({
    ref: zod_1.default.string().optional(),
    name: zod_1.default.string(),
    output: zod_1.default.unknown().optional(),
});
exports.ToolResponsePartSchema = EmptyPartSchema.extend({
    toolResponse: exports.ToolResponseSchema,
});
exports.DataPartSchema = EmptyPartSchema.extend({
    data: zod_1.default.unknown(),
});
exports.CustomPartSchema = EmptyPartSchema.extend({
    custom: zod_1.default.record(zod_1.default.any()),
});
exports.DocumentPartSchema = zod_1.default.union([exports.TextPartSchema, exports.MediaPartSchema]);
exports.DocumentDataSchema = zod_1.default.object({
    content: zod_1.default.array(exports.DocumentPartSchema),
    metadata: zod_1.default.record(zod_1.default.string(), zod_1.default.any()).optional(),
});
//# sourceMappingURL=document.js.map