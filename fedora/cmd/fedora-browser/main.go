package main

import (
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"time"

	"github.com/khalilpdev/fedora-scripts/internal/catalog"
	"github.com/khalilpdev/fedora-scripts/internal/webui"
)

func main() {
	root, err := findRepoRoot()
	if err != nil {
		log.Fatalf("não foi possível localizar o repositório: %v", err)
	}

	cat, err := catalog.Load(root)
	if err != nil {
		log.Fatalf("não foi possível montar o catálogo: %v", err)
	}

	srv := webui.NewServer(cat)
	addr := os.Getenv("FEDORA_SCRIPTS_ADDR")
	if addr == "" {
		addr = "127.0.0.1:0"
	}

	listener, err := net.Listen("tcp", addr)
	if err != nil {
		log.Fatalf("não foi possível iniciar o servidor: %v", err)
	}

	url := "http://" + listener.Addr().String()

	if os.Getenv("FEDORA_SCRIPTS_NO_BROWSER") == "" {
		go func() {
			time.Sleep(400 * time.Millisecond)
			if err := openBrowser(url); err != nil {
				log.Printf("não foi possível abrir o navegador automaticamente: %v", err)
			}
		}()
	}

	log.Printf("catálogo carregado a partir de %s", root)
	log.Printf("abra %s", url)
	if err := http.Serve(listener, srv); err != nil {
		log.Fatal(err)
	}
}

func findRepoRoot() (string, error) {
	wd, err := os.Getwd()
	if err != nil {
		return "", err
	}

	dir := wd
	for {
		if hasMarker(dir) {
			return dir, nil
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return "", fmt.Errorf("marcador do repositório não encontrado")
		}
		dir = parent
	}
}

func hasMarker(dir string) bool {
	if _, err := os.Stat(filepath.Join(dir, ".git")); err == nil {
		return true
	}
	if _, err := os.Stat(filepath.Join(dir, "AGENTS.md")); err == nil {
		return true
	}
	return false
}

func openBrowser(url string) error {
	commands := [][]string{
		{"xdg-open", url},
		{"gio", "open", url},
		{"open", url},
	}

	for _, command := range commands {
		if _, err := exec.LookPath(command[0]); err != nil {
			continue
		}
		cmd := exec.Command(command[0], command[1:]...)
		if err := cmd.Start(); err != nil {
			continue
		}
		if runtime.GOOS != "windows" {
			_ = cmd.Process.Release()
		}
		return nil
	}

	return fmt.Errorf("nenhum abridor de navegador disponível")
}
