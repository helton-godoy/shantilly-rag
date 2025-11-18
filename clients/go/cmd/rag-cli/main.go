package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/helton-godoy/shantilly-rag/clients/go/pkg/ragclient"
)

func usage() {
	fmt.Fprintf(os.Stderr, "Uso: %s [opções] <pergunta>\n", os.Args[0])
	fmt.Fprintln(os.Stderr)
	fmt.Fprintln(os.Stderr, "Opções:")
	fmt.Fprintln(os.Stderr, "  -json       Saída em JSON bruto (amigável para agentes/integrações)")
	fmt.Fprintln(os.Stderr, "  -timeout    Timeout em segundos para a requisição (default 60)")
	fmt.Fprintln(os.Stderr)
	fmt.Fprintln(os.Stderr, "Ambiente:")
	fmt.Fprintln(os.Stderr, "  RAG_BASE_URL  URL base do servidor RAG (default http://127.0.0.1:8001)")
}

func main() {
	jsonOut := flag.Bool("json", false, "Saída em JSON bruto")
	timeoutSec := flag.Int("timeout", 60, "Timeout em segundos")
	flag.Usage = usage
	flag.Parse()

	args := flag.Args()
	if len(args) == 0 {
		usage()
		os.Exit(1)
	}

	question := strings.Join(args, " ")

	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(*timeoutSec)*time.Second)
	defer cancel()

	client := ragclient.New()
	res, err := client.Query(ctx, question, nil)
	if err != nil {
		fmt.Fprintf(os.Stderr, "erro ao consultar RAG: %v\n", err)
		os.Exit(1)
	}

	if *jsonOut {
		// Modo "agent-friendly": expõe pergunta, resposta, documentos e latência.
		out := struct {
			Question  string               `json:"question"`
			Answer    string               `json:"answer"`
			Documents []ragclient.Document `json:"documents"`
			LatencyMs int64                `json:"latency_ms"`
		}{
			Question:  question,
			Answer:    res.Response.Answer,
			Documents: res.Response.Documents,
			LatencyMs: res.FinishedAt.Sub(res.StartedAt).Milliseconds(),
		}

		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		if err := enc.Encode(out); err != nil {
			fmt.Fprintf(os.Stderr, "erro ao serializar resposta em JSON: %v\n", err)
			os.Exit(1)
		}
		return
	}

	// Saída amigável para humanos
	fmt.Println("Pergunta:")
	fmt.Println("  ", question)
	fmt.Println()

	fmt.Println("Resposta:")
	fmt.Println(res.Response.Answer)
	fmt.Println()

	fmt.Printf("Tempo total: %s\n", res.FinishedAt.Sub(res.StartedAt).Round(10*time.Millisecond))

	if len(res.Response.Documents) > 0 {
		fmt.Println()
		fmt.Println("Fontes:")
		for i, d := range res.Response.Documents {
			meta := d.Metadata
			source := toString(meta["source"])
			path := toString(meta["path"])
			lang := toString(meta["lang"])

			fmt.Printf("  [%d] score=%.3f", i+1, d.Score)
			if source != "" {
				fmt.Printf(" source=%s", source)
			}
			if path != "" {
				fmt.Printf(" path=%s", path)
			}
			if lang != "" {
				fmt.Printf(" lang=%s", lang)
			}
			fmt.Println()
		}
	}
}

func toString(v any) string {
	if v == nil {
		return ""
	}
	if s, ok := v.(string); ok {
		return s
	}
	return fmt.Sprintf("%v", v)
}
