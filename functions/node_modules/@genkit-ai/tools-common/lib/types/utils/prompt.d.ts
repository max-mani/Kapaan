import type { MessageData } from '../types/model';
import type { PromptFrontmatter } from '../types/prompt';
export declare function fromMessages(frontmatter: PromptFrontmatter, messages: MessageData[]): string;
