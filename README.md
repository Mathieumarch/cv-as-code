# CV as Code — Mathieu Marchand

Pipeline **Pandoc → WeasyPrint** containerisé sous Docker pour générer un CV PDF A4 à partir d'un fichier Markdown.

## Usage

```bash
make build       # build l'image et génère build/cv.pdf
make clean       # supprime le PDF généré
```

## Structure

```
content/cv.md          — données et contenu (YAML frontmatter + Markdown)
template/template.html — structure HTML / Pandoc template
style/print.css        — mise en page CSS pour WeasyPrint
build/cv.pdf           — PDF généré (ignoré par git)
```

---

## Debugging WeasyPrint

### Bug : layout 2 colonnes cassé (sidebar empilée, contenu dupliqué page 2)

**Symptôme** : la sidebar bleue s'affiche en dessous du contenu principal au lieu d'être à côté ; tout le contenu est empilé verticalement ; le CV fait 2 pages.

**Cause** : `display: flex` sur `<body>` (et `display: flex` sur des éléments internes) est **partiellement supporté** par WeasyPrint. Le moteur de rendu ignore ou interprète mal les propriétés flexbox sur le body, ce qui empile les éléments plutôt que de les placer côte à côte.

**Solution fiable** : remplacer le layout flex par `position: absolute` avec des dimensions en mm explicites — WeasyPrint est un moteur orienté impression, `position: absolute` avec des unités physiques (`mm`) est son point fort.

```css
/* ❌ NE PAS FAIRE — flexbox sur body cassé dans WeasyPrint */
body { display: flex; }
.sidebar { width: 36%; flex-shrink: 0; }
.main-content { flex: 1; }

/* ✅ FAIRE — absolute positioning avec mm fixes */
body { position: relative; width: 210mm; height: 297mm; overflow: hidden; }
.sidebar { position: absolute; top: 0; left: 0; width: 75.6mm; height: 297mm; }
.main-content { position: absolute; top: 0; left: 75.6mm; width: 134.4mm; height: 297mm; }
```

**Même logique pour les flexbox internes** :
- `display: flex; justify-content: space-between` sur `<li>` → remplacer par `display: table` / `display: table-cell`
- `display: flex; flex-wrap: wrap` pour des listes inline → remplacer par `display: inline`

**Règle générale** : dans WeasyPrint, éviter flexbox et CSS Grid pour tout layout structurant. Utiliser `position: absolute/fixed`, `float`, ou `display: table` selon le cas.
