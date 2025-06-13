"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.removeToolsInfoFile = exports.writeToolsInfoFile = exports.isValidDevToolsInfo = exports.retriable = exports.waitUntilUnresponsive = exports.waitUntilHealthy = exports.checkServerHealth = exports.detectRuntime = exports.projectNameFromGenkitFilePath = exports.findServersDir = exports.findRuntimesDir = exports.findProjectRoot = void 0;
const fs = __importStar(require("fs/promises"));
const path = __importStar(require("path"));
const logger_1 = require("./logger");
async function findProjectRoot() {
    let currentDir = process.cwd();
    while (currentDir !== path.parse(currentDir).root) {
        const packageJsonPath = path.join(currentDir, 'package.json');
        const goModPath = path.join(currentDir, 'go.mod');
        const pyprojectPath = path.join(currentDir, 'pyproject.toml');
        const pyproject2Path = path.join(currentDir, 'requirements.txt');
        try {
            const [packageJsonExists, goModExists, pyprojectExists, pyproject2Exists,] = await Promise.all([
                fs
                    .access(packageJsonPath)
                    .then(() => true)
                    .catch(() => false),
                fs
                    .access(goModPath)
                    .then(() => true)
                    .catch(() => false),
                fs
                    .access(pyprojectPath)
                    .then(() => true)
                    .catch(() => false),
                fs
                    .access(pyproject2Path)
                    .then(() => true)
                    .catch(() => false),
            ]);
            if (packageJsonExists ||
                goModExists ||
                pyprojectExists ||
                pyproject2Exists) {
                return currentDir;
            }
        }
        catch {
        }
        currentDir = path.dirname(currentDir);
    }
    return process.cwd();
}
exports.findProjectRoot = findProjectRoot;
async function findRuntimesDir(projectRoot) {
    const root = projectRoot ?? (await findProjectRoot());
    return path.join(root, '.genkit', 'runtimes');
}
exports.findRuntimesDir = findRuntimesDir;
async function findServersDir(projectRoot) {
    const root = projectRoot ?? (await findProjectRoot());
    return path.join(root, '.genkit', 'servers');
}
exports.findServersDir = findServersDir;
function projectNameFromGenkitFilePath(filePath) {
    const parts = filePath.split('/');
    const basePath = parts
        .slice(0, Math.max(parts.findIndex((value) => value === '.genkit'), 0))
        .join('/');
    return basePath === '' ? 'unknown' : path.basename(basePath);
}
exports.projectNameFromGenkitFilePath = projectNameFromGenkitFilePath;
async function detectRuntime(directory) {
    const files = await fs.readdir(directory);
    for (const file of files) {
        const filePath = path.join(directory, file);
        const stat = await fs.stat(filePath);
        if (stat.isFile() && (path.extname(file) === '.go' || file === 'go.mod')) {
            return 'go';
        }
    }
    try {
        await fs.access(path.join(directory, 'package.json'));
        return 'nodejs';
    }
    catch {
        return undefined;
    }
}
exports.detectRuntime = detectRuntime;
async function checkServerHealth(url) {
    try {
        const response = await fetch(`${url}/api/__health`);
        return response.status === 200;
    }
    catch (error) {
        if (error instanceof Error &&
            error.cause.code === 'ECONNREFUSED') {
            return false;
        }
    }
    return true;
}
exports.checkServerHealth = checkServerHealth;
async function waitUntilHealthy(url, maxTimeout = 10000) {
    const startTime = Date.now();
    while (Date.now() - startTime < maxTimeout) {
        try {
            const response = await fetch(`${url}/api/__health`);
            if (response.status === 200) {
                return true;
            }
        }
        catch (error) {
        }
        await new Promise((resolve) => setTimeout(resolve, 500));
    }
    return false;
}
exports.waitUntilHealthy = waitUntilHealthy;
async function waitUntilUnresponsive(url, maxTimeout = 10000) {
    const startTime = Date.now();
    while (Date.now() - startTime < maxTimeout) {
        try {
            const health = await fetch(`${url}/api/__health`);
        }
        catch (error) {
            if (error instanceof Error &&
                error.cause.code === 'ECONNREFUSED') {
                return true;
            }
        }
        await new Promise((resolve) => setTimeout(resolve, 500));
    }
    return false;
}
exports.waitUntilUnresponsive = waitUntilUnresponsive;
async function retriable(fn, opts) {
    const maxRetries = opts.maxRetries ?? 3;
    const delayMs = opts.delayMs ?? 0;
    let attempt = 0;
    while (true) {
        try {
            return await fn();
        }
        catch (e) {
            if (attempt >= maxRetries - 1) {
                throw e;
            }
            if (delayMs > 0) {
                await new Promise((r) => setTimeout(r, delayMs));
            }
        }
        attempt++;
    }
}
exports.retriable = retriable;
function isValidDevToolsInfo(data) {
    return (typeof data === 'object' &&
        typeof data.url === 'string' &&
        typeof data.timestamp === 'string');
}
exports.isValidDevToolsInfo = isValidDevToolsInfo;
async function writeToolsInfoFile(url, projectRoot) {
    const serversDir = await findServersDir(projectRoot);
    const toolsJsonPath = path.join(serversDir, `tools-${process.pid}.json`);
    try {
        const serverInfo = {
            url,
            timestamp: new Date().toISOString(),
        };
        await fs.mkdir(serversDir, { recursive: true });
        await fs.writeFile(toolsJsonPath, JSON.stringify(serverInfo, null, 2));
        logger_1.logger.debug(`Tools Info file written: ${toolsJsonPath}`);
    }
    catch (error) {
        logger_1.logger.info('Error writing tools config', error);
    }
}
exports.writeToolsInfoFile = writeToolsInfoFile;
async function removeToolsInfoFile(fileName) {
    try {
        const serversDir = await findServersDir();
        const filePath = path.join(serversDir, fileName);
        await fs.unlink(filePath);
        logger_1.logger.debug(`Removed unhealthy toolsInfo file ${fileName} from manager.`);
    }
    catch (error) {
        logger_1.logger.debug(`Failed to delete toolsInfo file: ${error}`);
    }
}
exports.removeToolsInfoFile = removeToolsInfoFile;
//# sourceMappingURL=utils.js.map