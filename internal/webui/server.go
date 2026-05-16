package webui

import (
	"encoding/json"
	"html/template"
	"net/http"
	"sort"
	"strings"

	"github.com/khalilpdev/fedora-scripts/internal/catalog"
)

type Server struct {
	catalog *catalog.Catalog
	tpl     *template.Template
}

func NewServer(cat *catalog.Catalog) *Server {
	return &Server{
		catalog: cat,
		tpl:     template.Must(template.New("index").Parse(pageTemplate)),
	}
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	switch {
	case r.URL.Path == "/":
		s.handleIndex(w, r)
	case r.URL.Path == "/api/catalog":
		s.handleCatalog(w, r)
	case r.URL.Path == "/api/item":
		s.handleItem(w, r)
	default:
		http.NotFound(w, r)
	}
}

func (s *Server) handleIndex(w http.ResponseWriter, _ *http.Request) {
	_ = s.tpl.Execute(w, map[string]any{
		"Root":        s.catalog.Root,
		"GeneratedAt": s.catalog.GeneratedAt.Format("02/01/2006 15:04:05"),
		"Modules":     s.catalog.ModuleCount(),
		"Items":       s.catalog.ItemCount(),
	})
}

func (s *Server) handleCatalog(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	_ = json.NewEncoder(w).Encode(s.catalog)
}

func (s *Server) handleItem(w http.ResponseWriter, r *http.Request) {
	rel := strings.TrimSpace(r.URL.Query().Get("path"))
	if rel == "" {
		http.Error(w, "path ausente", http.StatusBadRequest)
		return
	}

	for _, module := range s.catalog.Modules {
		for _, item := range module.Items {
			if item.RelPath == rel {
				w.Header().Set("Content-Type", "application/json; charset=utf-8")
				_ = json.NewEncoder(w).Encode(item)
				return
			}
		}
	}

	http.NotFound(w, r)
}

func (s *Server) SortedModules() []catalog.Module {
	modules := append([]catalog.Module(nil), s.catalog.Modules...)
	sort.SliceStable(modules, func(i, j int) bool {
		return modules[i].Name < modules[j].Name
	})
	return modules
}

const pageTemplate = `<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Fedora Scripts Go</title>
  <style>
    :root {
      color-scheme: dark;
      --bg: #0b1020;
      --panel: #121a2d;
      --panel-2: #18233b;
      --text: #e7edf7;
      --muted: #8ea0bf;
      --accent: #68b0ff;
      --ok: #36d399;
      --warn: #fbbf24;
      --border: #24304b;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: Inter, system-ui, sans-serif;
      background: radial-gradient(circle at top, #14203d 0, var(--bg) 55%);
      color: var(--text);
    }
    header {
      padding: 24px 28px 16px;
      border-bottom: 1px solid var(--border);
      background: rgba(9, 14, 28, 0.6);
      backdrop-filter: blur(10px);
    }
    h1 { margin: 0 0 6px; font-size: 24px; }
    .sub { color: var(--muted); font-size: 14px; }
    .stats {
      display: flex;
      gap: 12px;
      margin-top: 16px;
      flex-wrap: wrap;
    }
    .stat {
      padding: 10px 12px;
      border: 1px solid var(--border);
      background: rgba(18, 26, 45, 0.8);
      border-radius: 12px;
      min-width: 140px;
    }
    .stat strong { display:block; font-size: 20px; }
    main {
      display: grid;
      grid-template-columns: 360px 1fr;
      min-height: calc(100vh - 130px);
    }
    .sidebar, .content { padding: 18px; }
    .sidebar {
      border-right: 1px solid var(--border);
      background: rgba(12, 18, 32, 0.55);
    }
    .search {
      width: 100%;
      padding: 12px 14px;
      border-radius: 12px;
      border: 1px solid var(--border);
      background: var(--panel);
      color: var(--text);
      margin-bottom: 14px;
      outline: none;
    }
    .module {
      margin-bottom: 12px;
      border: 1px solid var(--border);
      border-radius: 14px;
      overflow: hidden;
      background: var(--panel);
    }
    .module > button {
      width: 100%;
      border: 0;
      background: var(--panel-2);
      color: var(--text);
      padding: 12px 14px;
      text-align: left;
      font-size: 15px;
      cursor: pointer;
    }
    .module .items { display: none; padding: 8px; }
    .module.open .items { display: block; }
    .item {
      width: 100%;
      padding: 10px 12px;
      border-radius: 10px;
      border: 1px solid transparent;
      background: transparent;
      color: var(--text);
      text-align: left;
      cursor: pointer;
      display: flex;
      justify-content: space-between;
      gap: 8px;
      margin-bottom: 6px;
    }
    .item:hover, .item.active {
      border-color: var(--accent);
      background: rgba(104, 176, 255, 0.12);
    }
    .badge {
      font-size: 11px;
      padding: 3px 8px;
      border-radius: 999px;
      background: rgba(255,255,255,0.08);
      color: var(--muted);
      white-space: nowrap;
    }
    .badge.ok { color: #053; background: rgba(54, 211, 153, 0.16); }
    .badge.warn { color: #5c4300; background: rgba(251, 191, 36, 0.16); }
    .content {
      display: grid;
      grid-template-rows: auto 1fr;
      gap: 16px;
    }
    .card {
      border: 1px solid var(--border);
      border-radius: 18px;
      background: rgba(18, 26, 45, 0.82);
      padding: 18px;
    }
    .details-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: 12px;
      margin: 12px 0 16px;
    }
    .kv { padding: 12px; border: 1px solid var(--border); border-radius: 14px; background: rgba(255,255,255,0.03); }
    .kv span { color: var(--muted); display:block; font-size: 12px; margin-bottom: 5px; }
    pre {
      margin: 0;
      padding: 16px;
      border-radius: 14px;
      background: #0b1223;
      border: 1px solid var(--border);
      overflow: auto;
      white-space: pre-wrap;
      color: #d9e6ff;
    }
    .muted { color: var(--muted); }
    .row { display:flex; gap:8px; align-items:center; flex-wrap: wrap; }
  </style>
</head>
<body>
  <header>
    <h1>Fedora Scripts → Go</h1>
    <div class="sub">Catálogo gráfico gerado a partir da estrutura do repositório.</div>
    <div class="stats">
      <div class="stat"><strong id="moduleCount">{{.Modules}}</strong><span>Módulos</span></div>
      <div class="stat"><strong id="itemCount">{{.Items}}</strong><span>Itens</span></div>
      <div class="stat"><strong>{{.GeneratedAt}}</strong><span>Gerado em</span></div>
      <div class="stat"><strong id="rootPath">{{.Root}}</strong><span>Raiz</span></div>
    </div>
  </header>
  <main>
    <aside class="sidebar">
      <input id="search" class="search" placeholder="Buscar módulo, arquivo ou resumo">
      <div id="modules"></div>
    </aside>
    <section class="content">
      <div class="card">
        <div class="row">
          <h2 id="title" style="margin:0;">Selecione um item</h2>
          <span id="status" class="badge">aguardando seleção</span>
        </div>
        <div id="subtitle" class="muted" style="margin-top:6px;">A interface será preenchida com os arquivos do repositório.</div>
        <div class="details-grid">
          <div class="kv"><span>Arquivo</span><strong id="path">-</strong></div>
          <div class="kv"><span>Módulo</span><strong id="module">-</strong></div>
          <div class="kv"><span>Tipo</span><strong id="kind">-</strong></div>
          <div class="kv"><span>Tamanho</span><strong id="size">-</strong></div>
        </div>
        <div class="details-grid">
          <div class="kv"><span>Linguagem</span><strong id="lang">-</strong></div>
          <div class="kv"><span>Go</span><strong id="go">-</strong></div>
          <div class="kv"><span>Modificado</span><strong id="modified">-</strong></div>
          <div class="kv"><span>Resumo</span><strong id="summary">-</strong></div>
        </div>
      </div>
      <div class="card">
        <h3 style="margin-top:0;">Prévia</h3>
        <pre id="preview">Carregando catálogo...</pre>
      </div>
    </section>
  </main>
  <script>
    const state = { catalog: null, selected: null, query: '' };

    const els = {
      modules: document.getElementById('modules'),
      search: document.getElementById('search'),
      title: document.getElementById('title'),
      subtitle: document.getElementById('subtitle'),
      status: document.getElementById('status'),
      path: document.getElementById('path'),
      module: document.getElementById('module'),
      kind: document.getElementById('kind'),
      size: document.getElementById('size'),
      lang: document.getElementById('lang'),
      go: document.getElementById('go'),
      modified: document.getElementById('modified'),
      summary: document.getElementById('summary'),
      preview: document.getElementById('preview'),
    };

    function humanSize(bytes) {
      if (bytes < 1024) return bytes + ' B';
      if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
      return (bytes / 1024 / 1024).toFixed(1) + ' MB';
    }

    function matches(item, query) {
      if (!query) return true;
      const hay = [item.name, item.relPath, item.module, item.summary, item.ext].join(' ').toLowerCase();
      return hay.includes(query);
    }

    function selectItem(moduleName, item) {
      state.selected = { moduleName, item };
      renderDetails();
      document.querySelectorAll('.item').forEach(el => {
        el.classList.toggle('active', el.dataset.path === item.relPath);
      });
    }

    function renderDetails() {
      const selected = state.selected;
      if (!selected) return;
      const item = selected.item;
      els.title.textContent = item.name;
      els.subtitle.textContent = selected.moduleName + ' · ' + item.relPath;
      els.path.textContent = item.relPath;
      els.module.textContent = item.module;
      els.kind.textContent = item.kind;
      els.size.textContent = humanSize(item.size);
      els.lang.textContent = item.sourceLang || '-';
      els.go.textContent = item.converted ? (item.goPackage + ' · pronto') : 'pendente';
      els.modified.textContent = new Date(item.modified).toLocaleString('pt-BR');
      els.summary.textContent = item.summary;
      els.status.textContent = item.converted ? 'convertido para Go' : 'aguardando conversão';
      els.status.className = 'badge ' + (item.converted ? 'ok' : 'warn');
      els.preview.textContent = item.preview.join('\n');
    }

    function render() {
      if (!state.catalog) return;
      const q = state.query.trim().toLowerCase();
      const modules = state.catalog.modules;
      els.modules.innerHTML = '';

      modules.forEach(module => {
        const items = module.items.filter(item => matches(item, q));
        if (!items.length) return;

        const box = document.createElement('div');
        box.className = 'module open';
        box.innerHTML = '<button type="button">' + module.name + ' <span class="badge">' + items.length + '</span></button>';
        const list = document.createElement('div');
        list.className = 'items';

        items.forEach(item => {
          const btn = document.createElement('button');
          btn.className = 'item';
          btn.dataset.path = item.relPath;
          btn.innerHTML = '<span>' + item.name + '</span><span class="badge ' + (item.converted ? 'ok' : 'warn') + '">' + (item.converted ? 'Go' : 'Bash') + '</span>';
          btn.addEventListener('click', () => selectItem(module.name, item));
          list.appendChild(btn);
        });

        box.querySelector('button').addEventListener('click', () => {
          box.classList.toggle('open');
        });
        box.appendChild(list);
        els.modules.appendChild(box);
      });

      const firstModule = modules.find(module => module.items.some(item => matches(item, q)));
      if (!state.selected && firstModule) {
        const firstItem = firstModule.items.find(item => matches(item, q));
        if (firstItem) selectItem(firstModule.name, firstItem);
      }
    }

    els.search.addEventListener('input', event => {
      state.query = event.target.value;
      state.selected = null;
      render();
    });

    fetch('/api/catalog')
      .then(response => response.json())
      .then(catalog => {
        state.catalog = catalog;
        render();
      })
      .catch(err => {
        els.preview.textContent = 'Falha ao carregar o catálogo: ' + err.message;
      });
  </script>
</body>
</html>`
