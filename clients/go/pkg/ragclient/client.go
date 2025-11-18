package ragclient

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"
)

const defaultBaseURL = "http://127.0.0.1:8001"

// Client é um cliente HTTP para o servidor Shantilly RAG.
type Client struct {
	baseURL    string
	httpClient *http.Client
}

// Option configura o Client.
type Option func(*Client)

// WithBaseURL define a URL base do servidor RAG (ex.: http://127.0.0.1:8001).
func WithBaseURL(u string) Option {
	return func(c *Client) {
		c.baseURL = strings.TrimRight(u, "/")
	}
}

// WithHTTPClient permite injetar um *http.Client customizado.
func WithHTTPClient(hc *http.Client) Option {
	return func(c *Client) {
		if hc != nil {
			c.httpClient = hc
		}
	}
}

// New cria um novo Client.
//
// Se baseURL não for informada via Option, usa RAG_BASE_URL ou defaultBaseURL.
func New(opts ...Option) *Client {
	baseURL := os.Getenv("RAG_BASE_URL")
	if baseURL == "" {
		baseURL = defaultBaseURL
	}

	c := &Client{
		baseURL:    strings.TrimRight(baseURL, "/"),
		httpClient: &http.Client{},
	}

	for _, opt := range opts {
		opt(c)
	}

	return c
}

// Query envia uma pergunta ao servidor RAG e retorna a resposta estruturada.
func (c *Client) Query(ctx context.Context, query string, history []Message) (*Result, error) {
	query = strings.TrimSpace(query)
	if query == "" {
		return nil, errors.New("query vazia")
	}

	reqBody := QueryRequest{
		Query:   query,
		History: history,
	}

	buf, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("falha ao serializar QueryRequest: %w", err)
	}

	url := c.baseURL + "/query"
	httpreq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(buf))
	if err != nil {
		return nil, fmt.Errorf("falha ao criar requisição: %w", err)
	}
	httpreq.Header.Set("Content-Type", "application/json")

	started := time.Now()
	resp, err := c.httpClient.Do(httpreq)
	finished := time.Now()
	if err != nil {
		return nil, fmt.Errorf("falha ao chamar %s: %w", url, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		// tenta ler corpo para facilitar debug
		var bodyBuf bytes.Buffer
		_, _ = bodyBuf.ReadFrom(resp.Body)
		return nil, fmt.Errorf("resposta HTTP %d de %s: %s", resp.StatusCode, url, strings.TrimSpace(bodyBuf.String()))
	}

	var qr QueryResponse
	if err := json.NewDecoder(resp.Body).Decode(&qr); err != nil {
		return nil, fmt.Errorf("falha ao decodificar QueryResponse: %w", err)
	}

	return &Result{
		Response:   &qr,
		StartedAt:  started,
		FinishedAt: finished,
	}, nil
}
