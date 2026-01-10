import { create } from 'zustand';
import { User, Document, Conversation } from './types';

interface AppState {
  user: User | null;
  documents: Document[];
  conversations: Conversation[];
  currentConversation: Conversation | null;
  isLoading: boolean;
  
  setUser: (user: User | null) => void;
  setDocuments: (documents: Document[]) => void;
  setConversations: (conversations: Conversation[]) => void;
  setCurrentConversation: (conversation: Conversation | null) => void;
  setLoading: (loading: boolean) => void;
  
  addDocument: (document: Document) => void;
  removeDocument: (id: number) => void;
  addConversation: (conversation: Conversation) => void;
  removeConversation: (id: number) => void;
  updateConversation: (conversation: Conversation) => void;
}

export const useStore = create<AppState>((set) => ({
  user: null,
  documents: [],
  conversations: [],
  currentConversation: null,
  isLoading: false,
  
  setUser: (user) => set({ user }),
  setDocuments: (documents) => set({ documents }),
  setConversations: (conversations) => set({ conversations }),
  setCurrentConversation: (conversation) => set({ currentConversation: conversation }),
  setLoading: (loading) => set({ isLoading: loading }),
  
  addDocument: (document) => set((state) => ({ 
    documents: [...state.documents, document] 
  })),
  removeDocument: (id) => set((state) => ({ 
    documents: state.documents.filter(d => d.id !== id) 
  })),
  addConversation: (conversation) => set((state) => ({ 
    conversations: [conversation, ...state.conversations] 
  })),
  removeConversation: (id) => set((state) => ({ 
    conversations: state.conversations.filter(c => c.id !== id) 
  })),
  updateConversation: (conversation) => set((state) => ({ 
    conversations: state.conversations.map(c => 
      c.id === conversation.id ? conversation : c
    ),
    currentConversation: state.currentConversation?.id === conversation.id 
      ? conversation 
      : state.currentConversation
  })),
}));
