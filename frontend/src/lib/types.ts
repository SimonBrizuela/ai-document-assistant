export interface User {
  id: number;
  email: string;
  username: string;
}

export interface AuthResponse {
  token: string;
  type: string;
  user: User;
}

export interface Document {
  id: number;
  filename: string;
  fileType: string;
  fileSize: number;
  status: 'UPLOADING' | 'PROCESSING' | 'COMPLETED' | 'FAILED';
  uploadedAt: string;
  processedAt?: string;
  chunkCount: number;
}

export interface Message {
  id: number;
  role: 'USER' | 'ASSISTANT';
  content: string;
  createdAt: string;
  tokenCount?: number;
  modelUsed?: string;
}

export interface Conversation {
  id: number;
  title: string;
  messages: Message[];
  createdAt: string;
  updatedAt: string;
}

export interface QuestionRequest {
  question: string;
  conversationId?: number;
  documentIds?: number[];
}

export interface QuestionResponse {
  answer: string;
  conversationId?: number;
  model: string;
  tokensUsed: number;
  cost: number;
  responseTimeMs: number;
  sources?: DocumentChunk[];
}

export interface DocumentChunk {
  id: number;
  documentId: number;
  content: string;
  chunkIndex: number;
}

export interface ApiError {
  message: string;
  status: number;
  timestamp: string;
}
