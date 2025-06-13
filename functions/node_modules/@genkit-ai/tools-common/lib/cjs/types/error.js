"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.GenkitErrorSchema = void 0;
const zod_1 = require("zod");
exports.GenkitErrorSchema = zod_1.z.object({
    message: zod_1.z.string(),
    stack: zod_1.z.string().optional(),
    details: zod_1.z.any().optional(),
    data: zod_1.z
        .object({
        genkitErrorMessage: zod_1.z.string().optional(),
        genkitErrorDetails: zod_1.z
            .object({
            stack: zod_1.z.string().optional(),
            traceId: zod_1.z.string(),
        })
            .optional(),
    })
        .optional(),
});
//# sourceMappingURL=error.js.map