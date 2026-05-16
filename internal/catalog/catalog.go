package catalog

import (
	"bufio"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

type Catalog struct {
	Root        string    `json:"root"`
	GeneratedAt time.Time `json:"generatedAt"`
	Modules     []Module  `json:"modules"`
}

type Module struct {
	Name  string `json:"name"`
	Path  string `json:"path"`
	Items []Item `json:"items"`
}

type Item struct {
	Name       string    `json:"name"`
	RelPath    string    `json:"relPath"`
	AbsPath    string    `json:"absPath"`
	Kind       string    `json:"kind"`
	Module     string    `json:"module"`
	Ext        string    `json:"ext"`
	Size       int64     `json:"size"`
	Modified   time.Time `json:"modified"`
	Summary    string    `json:"summary"`
	Preview    []string  `json:"preview"`
	Converted  bool      `json:"converted"`
	GoPackage  string    `json:"goPackage,omitempty"`
	GoSummary  string    `json:"goSummary,omitempty"`
	SourceLang string    `json:"sourceLang,omitempty"`
}

type itemBuilder struct {
	module string
	items  []Item
}

func Load(root string) (*Catalog, error) {
	root, err := filepath.Abs(root)
	if err != nil {
		return nil, err
	}

	builders := map[string]*itemBuilder{}

	err = filepath.WalkDir(root, func(path string, d fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if path == root {
			return nil
		}

		rel, err := filepath.Rel(root, path)
		if err != nil {
			return err
		}

		if shouldSkip(rel, d) {
			if d.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}

		if d.IsDir() {
			return nil
		}

		info, err := d.Info()
		if err != nil {
			return err
		}

		module := moduleName(rel)
		builder := builders[module]
		if builder == nil {
			builder = &itemBuilder{module: module}
			builders[module] = builder
		}

		item := buildItem(root, rel, info)
		builder.items = append(builder.items, item)
		return nil
	})
	if err != nil {
		return nil, err
	}

	moduleNames := make([]string, 0, len(builders))
	for name := range builders {
		moduleNames = append(moduleNames, name)
	}
	sort.Strings(moduleNames)

	modules := make([]Module, 0, len(moduleNames))
	for _, name := range moduleNames {
		builder := builders[name]
		sort.SliceStable(builder.items, func(i, j int) bool {
			return builder.items[i].RelPath < builder.items[j].RelPath
		})

		modules = append(modules, Module{
			Name:  prettyModuleName(name),
			Path:  modulePath(name),
			Items: builder.items,
		})
	}

	return &Catalog{
		Root:        root,
		GeneratedAt: time.Now().UTC(),
		Modules:     modules,
	}, nil
}

func buildItem(root, rel string, info fs.FileInfo) Item {
	ext := strings.ToLower(filepath.Ext(rel))
	name := filepath.Base(rel)
	module := moduleName(rel)
	preview, summary := fileSummary(filepath.Join(root, rel))

	item := Item{
		Name:       name,
		RelPath:    filepath.ToSlash(rel),
		AbsPath:    filepath.Join(root, rel),
		Kind:       "arquivo",
		Module:     prettyModuleName(module),
		Ext:        ext,
		Size:       info.Size(),
		Modified:   info.ModTime().UTC(),
		Summary:    summary,
		Preview:    preview,
		SourceLang: languageForExtension(ext),
	}

	if converted, pkg, goSummary := goConversion(rel); converted {
		item.Converted = true
		item.GoPackage = pkg
		item.GoSummary = goSummary
	}

	return item
}

func moduleName(rel string) string {
	parts := strings.Split(filepath.ToSlash(rel), "/")
	if len(parts) == 0 {
		return "root"
	}
	if len(parts) == 1 {
		return "root"
	}
	return parts[0]
}

func modulePath(name string) string {
	if name == "root" {
		return "."
	}
	return name
}

func prettyModuleName(name string) string {
	if name == "root" {
		return "raiz"
	}
	return name
}

func shouldSkip(rel string, d fs.DirEntry) bool {
	name := d.Name()
	if strings.HasPrefix(name, ".") && name != ".git" {
		return true
	}

	skippedDirs := map[string]struct{}{
		".git":     {},
		".copilot": {},
		"cmd":      {},
		"internal": {},
	}

	if d.IsDir() {
		parts := strings.Split(filepath.ToSlash(rel), "/")
		if len(parts) > 0 {
			if _, ok := skippedDirs[parts[0]]; ok {
				return true
			}
		}
	}

	if !d.IsDir() {
		switch strings.ToLower(filepath.Base(rel)) {
		case "go.mod", "go.sum":
			return true
		}
	}

	return false
}

func fileSummary(path string) ([]string, string) {
	file, err := os.Open(path)
	if err != nil {
		return nil, ""
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	preview := make([]string, 0, 4)
	summary := ""
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		if strings.HasPrefix(line, "#!") {
			continue
		}

		clean := stripCommentPrefix(line)
		if clean == "" {
			continue
		}

		preview = append(preview, clean)
		if summary == "" {
			summary = clean
		}
		if len(preview) == 4 {
			break
		}
	}

	if summary == "" {
		summary = "sem comentário de abertura"
	}
	if len(preview) == 0 {
		preview = []string{"sem prévia disponível"}
	}

	return preview, summary
}

func stripCommentPrefix(line string) string {
	line = strings.TrimSpace(line)
	for _, prefix := range []string{"#", "//", "/*", "*", "--"} {
		line = strings.TrimPrefix(line, prefix)
		line = strings.TrimSpace(line)
	}
	line = strings.TrimSuffix(line, "*/")
	line = strings.TrimSpace(line)
	return line
}

func languageForExtension(ext string) string {
	switch ext {
	case ".sh":
		return "bash"
	case ".ps1":
		return "powershell"
	case ".md":
		return "markdown"
	case ".txt":
		return "text"
	default:
		return "arquivo"
	}
}

func goConversion(rel string) (bool, string, string) {
	normalized := filepath.ToSlash(rel)
	switch {
	case strings.HasSuffix(normalized, "fix-ssh-permission.sh"):
		return true, "internal/scripts/fixssh", "port inicial do chmod em ~/.ssh"
	default:
		return false, "", ""
	}
}

func (c *Catalog) ItemCount() int {
	total := 0
	for _, module := range c.Modules {
		total += len(module.Items)
	}
	return total
}

func (c *Catalog) ModuleCount() int {
	return len(c.Modules)
}

func (c *Catalog) ModuleByName(name string) (Module, bool) {
	for _, module := range c.Modules {
		if module.Name == name {
			return module, true
		}
	}
	return Module{}, false
}

func (c *Catalog) String() string {
	return fmt.Sprintf("%s (%d módulos, %d itens)", c.Root, c.ModuleCount(), c.ItemCount())
}
