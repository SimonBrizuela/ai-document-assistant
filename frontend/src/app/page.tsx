'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { api } from '@/lib/api';
import { useStore } from '@/lib/store';
import { Document, QuestionRequest, QuestionResponse } from '@/lib/types';
import toast from 'react-hot-toast';
import { Upload, FileText, Trash2, Send, Loader2, MessageSquare } from 'lucide-react';

export default function Home() {
  const router = useRouter();
  const { user, documents, setDocuments, addDocument, removeDocument } = useStore();
  const [question, setQuestion] = useState('');
  const [answer, setAnswer] = useState<QuestionResponse | null>(null);
  const [isUploading, setIsUploading] = useState(false);
  const [isAsking, setIsAsking] = useState(false);
  const [selectedDocuments, setSelectedDocuments] = useState<number[]>([]);

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) {
      router.push('/login');
      return;
    }
    loadDocuments();
  }, []);

  const loadDocuments = async () => {
    try {
      const docs = await api.getDocuments();
      setDocuments(docs);
    } catch (error) {
      toast.error('Failed to load documents');
    }
  };

  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (file.size > 10 * 1024 * 1024) {
      toast.error('File size must be less than 10MB');
      return;
    }

    setIsUploading(true);
    try {
      const doc = await api.uploadDocument(file);
      addDocument(doc);
      toast.success('Document uploaded successfully');
      e.target.value = '';
    } catch (error: any) {
      toast.error(error.message || 'Failed to upload document');
    } finally {
      setIsUploading(false);
    }
  };

  const handleDelete = async (id: number) => {
    if (!confirm('Are you sure you want to delete this document?')) return;
    
    try {
      await api.deleteDocument(id);
      removeDocument(id);
      toast.success('Document deleted');
    } catch (error) {
      toast.error('Failed to delete document');
    }
  };

  const handleAskQuestion = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!question.trim()) {
      toast.error('Please enter a question');
      return;
    }

    setIsAsking(true);
    try {
      const request: QuestionRequest = {
        question: question.trim(),
        documentIds: selectedDocuments.length > 0 ? selectedDocuments : undefined,
      };
      
      const response = await api.askQuestion(request);
      setAnswer(response);
      toast.success('Question answered');
    } catch (error: any) {
      toast.error(error.message || 'Failed to get answer');
    } finally {
      setIsAsking(false);
    }
  };

  const toggleDocumentSelection = (id: number) => {
    setSelectedDocuments(prev => 
      prev.includes(id) ? prev.filter(d => d !== id) : [...prev, id]
    );
  };

  const handleLogout = () => {
    api.logout();
    router.push('/login');
  };

  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-white shadow">
        <div className="max-w-7xl mx-auto px-4 py-4 sm:px-6 lg:px-8 flex justify-between items-center">
          <h1 className="text-2xl font-bold text-gray-900">AI Document Assistant</h1>
          <button
            onClick={handleLogout}
            className="px-4 py-2 text-sm text-gray-700 hover:text-gray-900"
          >
            Logout
          </button>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 py-8 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Documents Section */}
          <div className="lg:col-span-1">
            <div className="bg-white rounded-lg shadow p-6">
              <h2 className="text-lg font-semibold text-gray-900 mb-4">Your Documents</h2>
              
              <label className="block w-full cursor-pointer">
                <div className="border-2 border-dashed border-gray-300 rounded-lg p-6 text-center hover:border-blue-500 transition">
                  <Upload className="mx-auto h-8 w-8 text-gray-400" />
                  <p className="mt-2 text-sm text-gray-600">
                    {isUploading ? 'Uploading...' : 'Click to upload'}
                  </p>
                  <p className="text-xs text-gray-500">PDF, TXT, DOCX (max 10MB)</p>
                </div>
                <input
                  type="file"
                  className="hidden"
                  accept=".pdf,.txt,.docx"
                  onChange={handleFileUpload}
                  disabled={isUploading}
                />
              </label>

              <div className="mt-6 space-y-2">
                {documents.map((doc) => (
                  <div
                    key={doc.id}
                    className={`flex items-center justify-between p-3 rounded-lg border cursor-pointer transition ${
                      selectedDocuments.includes(doc.id)
                        ? 'border-blue-500 bg-blue-50'
                        : 'border-gray-200 hover:border-gray-300'
                    }`}
                    onClick={() => toggleDocumentSelection(doc.id)}
                  >
                    <div className="flex items-center space-x-3 flex-1">
                      <FileText className="h-5 w-5 text-gray-400" />
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-medium text-gray-900 truncate">
                          {doc.filename}
                        </p>
                        <p className="text-xs text-gray-500">
                          {doc.status} - {doc.chunkCount} chunks
                        </p>
                      </div>
                    </div>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        handleDelete(doc.id);
                      }}
                      className="text-red-600 hover:text-red-700"
                    >
                      <Trash2 className="h-4 w-4" />
                    </button>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Question & Answer Section */}
          <div className="lg:col-span-2">
            <div className="bg-white rounded-lg shadow p-6">
              <h2 className="text-lg font-semibold text-gray-900 mb-4">Ask a Question</h2>
              
              <form onSubmit={handleAskQuestion} className="space-y-4">
                <div>
                  <textarea
                    value={question}
                    onChange={(e) => setQuestion(e.target.value)}
                    placeholder="Ask a question about your documents..."
                    className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
                    rows={4}
                    disabled={isAsking}
                  />
                </div>
                
                <button
                  type="submit"
                  disabled={isAsking || !question.trim()}
                  className="w-full flex items-center justify-center space-x-2 px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition"
                >
                  {isAsking ? (
                    <>
                      <Loader2 className="h-5 w-5 animate-spin" />
                      <span>Thinking...</span>
                    </>
                  ) : (
                    <>
                      <Send className="h-5 w-5" />
                      <span>Ask Question</span>
                    </>
                  )}
                </button>
              </form>

              {answer && (
                <div className="mt-6 border-t pt-6">
                  <div className="flex items-start space-x-3">
                    <MessageSquare className="h-6 w-6 text-blue-600 mt-1" />
                    <div className="flex-1">
                      <h3 className="font-semibold text-gray-900 mb-2">Answer</h3>
                      <div className="prose prose-sm max-w-none text-gray-700 whitespace-pre-wrap">
                        {answer.answer}
                      </div>
                      <div className="mt-4 flex flex-wrap gap-4 text-xs text-gray-500">
                        <span>Model: {answer.model}</span>
                        <span>Tokens: {answer.tokensUsed}</span>
                        <span>Cost: ${answer.cost.toFixed(4)}</span>
                        <span>Time: {answer.responseTimeMs}ms</span>
                      </div>
                    </div>
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
