package ragclient

import "time"

// Message representa uma mensagem de histórico de conversa enviada ao RAG.
type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

// QueryRequest é o payload enviado ao endpoint /query do servidor RAG.
type QueryRequest struct {
	Query   string    `json:"query"`
	History []Message `json:"history,omitempty"`
}

// Document representa um documento retornado pelo RAG.
type Document struct {
	ID       any            `json:"id"`
	Score    float64        `json:"score"`
	Text     string         `json:"text"`
	Metadata map[string]any `json:"metadata"`
}

// QueryResponse é a resposta de /query.
type QueryResponse struct {
	Answer    string     `json:"answer"`
	Documents []Document `json:"documents"`
}

// Result agrega a resposta e informações de latência.
type Result struct {
	Response   *QueryResponse
	StartedAt  time.Time
	FinishedAt time.Time
}
