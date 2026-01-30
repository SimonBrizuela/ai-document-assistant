import { 
  AuthResponse, 
  Document, 
  Conversation, 
  QuestionRequest, 
  QuestionResponse 
} from './types';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080/api';

class ApiClient {
  private getHeaders(): HeadersInit {
    const headers: HeadersInit = {
      'Content-Type': 'application/json',
    };
    
    const token = localStorage.getItem('token');
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }
    
    return headers;
  }

  private async handleResponse<T>(response: Response): Promise<T> {
    if (!response.ok) {
      const error = await response.json().catch(() => ({ message: 'An error occurred' }));
      throw new Error(error.message || 'Request failed');
    }
    return response.json();
  }

  async login(email: string, password: string): Promise<AuthResponse> {
    const response = await fetch(`${API_BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    });
    const data = await this.handleResponse<AuthResponse>(response);
    localStorage.setItem('token', data.token);
    return data;
  }

  async register(username: string, email: string, password: string): Promise<AuthResponse> {
    const response = await fetch(`${API_BASE_URL}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, email, password }),
    });
    const data = await this.handleResponse<AuthResponse>(response);
    localStorage.setItem('token', data.token);
    return data;
  }

  logout(): void {
    localStorage.removeItem('token');
  }

  async uploadDocument(file: File): Promise<Document> {
    const formData = new FormData();
    formData.append('file', file);
    
    const response = await fetch(`${API_BASE_URL}/documents/upload`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${localStorage.getItem('token')}`,
      },
      body: formData,
    });
    
    return this.handleResponse<Document>(response);
  }

  async getDocuments(): Promise<Document[]> {
    const response = await fetch(`${API_BASE_URL}/documents`, {
      headers: this.getHeaders(),
    });
    return this.handleResponse<Document[]>(response);
  }

  async deleteDocument(id: number): Promise<void> {
    const response = await fetch(`${API_BASE_URL}/documents/${id}`, {
      method: 'DELETE',
      headers: this.getHeaders(),
    });
    await this.handleResponse<void>(response);
  }

  async askQuestion(request: QuestionRequest): Promise<QuestionResponse> {
    const response = await fetch(`${API_BASE_URL}/ai/ask`, {
      method: 'POST',
      headers: this.getHeaders(),
      body: JSON.stringify(request),
    });
    return this.handleResponse<QuestionResponse>(response);
  }

  async getConversations(): Promise<Conversation[]> {
    const response = await fetch(`${API_BASE_URL}/ai/conversations`, {
      headers: this.getHeaders(),
    });
    return this.handleResponse<Conversation[]>(response);
  }

  async getConversation(id: number): Promise<Conversation> {
    const response = await fetch(`${API_BASE_URL}/ai/conversations/${id}`, {
      headers: this.getHeaders(),
    });
    return this.handleResponse<Conversation>(response);
  }

  async deleteConversation(id: number): Promise<void> {
    const response = await fetch(`${API_BASE_URL}/ai/conversations/${id}`, {
      method: 'DELETE',
      headers: this.getHeaders(),
    });
    await this.handleResponse<void>(response);
  }
}

export const api = new ApiClient();
