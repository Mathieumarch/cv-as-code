# CV as Code — Mathieu Marchand

Pipeline **Pandoc → WeasyPrint** containerisé sous Docker pour générer un CV PDF A4 à partir d'un fichier Markdown. Zéro dépendance locale hors Docker.

---

## Compiler en local

### Prérequis

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installé et en cours d'exécution

### Avec `make` (Linux / macOS / WSL)

```bash
git clone https://github.com/Mathieumarch/cv-as-code.git
cd cv-as-code
make build
```

Le PDF est généré dans **`build/cv.pdf`**.

```bash
make clean   # supprime build/cv.pdf
```

### Sans `make` (Windows natif — PowerShell ou cmd)

`make` n'est pas disponible nativement sur Windows. Utiliser les commandes Docker directement :

```powershell
git clone https://github.com/Mathieumarch/cv-as-code.git
cd cv-as-code

# 1. Construire l'image
docker build --platform linux/amd64 -t cv-builder .

# 2. Générer le PDF
docker run --rm `
  -v "${PWD}/content:/cv/content:ro" `
  -v "${PWD}/template:/cv/template:ro" `
  -v "${PWD}/style:/cv/style:ro" `
  -v "${PWD}/build:/cv/build" `
  cv-builder
```

Le PDF est généré dans **`build/cv.pdf`**.

> **Note** : sur PowerShell, le caractère de continuation de ligne est `` ` `` (backtick), pas `\`.

---

## Structure

```
content/cv.md          — données et contenu (YAML frontmatter + Markdown)
template/template.html — structure HTML / Pandoc template
style/print.css        — mise en page CSS pour WeasyPrint
Dockerfile             — debian:bookworm-slim + pandoc (apt) + weasyprint (venv pip)
Makefile               — cible build + clean
.github/workflows/     — CI/CD GitHub Actions (build + release automatique)
build/cv.pdf           — PDF généré (ignoré par git)
```

**Principe de séparation stricte (SRP) :**
| Fichier | Responsabilité |
|---|---|
| `content/cv.md` | Ce que je suis — zéro HTML, zéro mise en forme |
| `template/template.html` | Comment c'est structuré — template Pandoc, variables `$...$` |
| `style/print.css` | À quoi ça ressemble — couleurs, dimensions, layout impression |

---

## CI/CD

Le workflow `.github/workflows/build-cv.yml` se déclenche à chaque push sur `main` :

1. Build de l'image Docker
2. Génération du PDF
3. Upload en artefact GitHub Actions (rétention 30 jours)
4. Création d'une GitHub Release avec le PDF attaché, taguée par date (`cv-YYYY-MM-DD`)

Le PDF de la dernière version est donc toujours accessible depuis l'onglet **Releases** du dépôt.

---

## Arsenal IA

### Outil utilisé

**Claude Code** (CLI Anthropic) avec le modèle **Claude Sonnet 4.6**, en mode conversationnel interactif dans le terminal.

### Rôle de l'IA dans ce projet

L'IA a contribué à chaque couche du pipeline, sans jamais prendre de décision de contenu :

| Tâche | Contribution IA |
|---|---|
| Architecture initiale | Proposition de la séparation content / template / style et justification SRP |
| `template/template.html` | Génération du template Pandoc avec syntaxe `$variable$` et `$for()$` |
| `style/print.css` | Génération du CSS d'impression avec contraintes WeasyPrint explicites |
| `Dockerfile` | Choix debian:bookworm-slim, venv pip pour weasyprint, CMD Pandoc→WeasyPrint |
| `Makefile` | Cible `build` avec volumes Docker montés en `:ro` sauf `/build` |
| CI/CD | Workflow GitHub Actions avec release automatique taguée par date |
| Débogage | Diagnostic du bug flexbox WeasyPrint et réécriture du layout en `position: absolute` |

---

## Ingénierie de prompt — CSS & impression

Cette section détaille les prompts clés qui ont orienté la génération de code vers des solutions fonctionnelles. Elle illustre comment formuler explicitement les contraintes techniques connues évite plusieurs itérations d'essai-erreur.

### Prompt 1 — Architecture initiale

> *"Je veux générer mon CV en PDF à partir d'un fichier Markdown. Je veux utiliser Pandoc pour la conversion et WeasyPrint pour le rendu PDF. Génère-moi une architecture de projet propre avec une séparation stricte entre le contenu, le template HTML et le CSS. Le tout doit tourner dans Docker pour être reproductible sur n'importe quelle machine."*

**Pourquoi ce prompt a bien fonctionné :** en nommant explicitement les deux outils (Pandoc + WeasyPrint) et en énonçant le principe de séparation voulu, l'IA a pu proposer directement la structure en trois fichiers distincts (`cv.md` / `template.html` / `print.css`) plutôt qu'une solution monolithique HTML inline. La contrainte Docker a orienté vers un `Dockerfile` autonome sans supposer d'environnement local.

### Prompt 2 — CSS d'impression avec contraintes WeasyPrint

> *"Génère le CSS d'impression pour un CV A4 deux colonnes : une sidebar bleue foncée à gauche (36% de la largeur) pour le contact, les compétences et les langues, et un contenu principal à droite. Utilise des variables CSS pour les couleurs. Attention : WeasyPrint a un support partiel de flexbox et ne gère pas CSS Grid — il faut éviter `display: flex` sur le body et préférer `position: absolute` avec des dimensions en mm pour le layout principal."*

**Pourquoi formuler explicitement la limitation WeasyPrint a été déterminant :** sans cette précision, un LLM génère naturellement du flexbox — c'est la solution CSS moderne standard pour un layout deux colonnes. WeasyPrint est un moteur orienté impression (Pango/Cairo), pas un moteur de navigateur ; son support flexbox sur `body` est cassé dans la version courante. En énonçant la contrainte dans le prompt, l'IA a généré directement :

```css
body { position: relative; width: 210mm; height: 297mm; overflow: hidden; }
.sidebar { position: absolute; top: 0; left: 0; width: 75.6mm; height: 297mm; }
.main-content { position: absolute; top: 0; left: 75.6mm; width: 134.4mm; height: 297mm; }
```

...au lieu du flexbox cassé qui aurait nécessité un cycle de débogage complet.

### Prompt 3 — Débogage du layout cassé

> *"Le CV généré empile la sidebar en dessous du contenu au lieu de les afficher côte à côte. Le PDF fait 2 pages. J'utilise `display: flex` sur `body`. Voici mon CSS actuel : [CSS]. Weasyprint version X sur Debian bookworm. Comment corriger ça ?"*

**Ce que ce prompt a appris :** en fournissant le symptôme précis ("empilé", "2 pages"), l'outil exact (WeasyPrint), et le CSS incriminé, l'IA a pu identifier la cause racine (flexbox non supporté sur body) et proposer la réécriture en `position: absolute` avec unités physiques mm — sans passer par plusieurs hypothèses intermédiaires.

**Leçon générale :** avec des outils à support CSS partiel (WeasyPrint, Prince, wkhtmltopdf), énoncer les limitations connues dans le prompt économise 1 à 3 itérations de débogage.

---

## Analyse critique & débogage

### Bug 1 — Layout deux colonnes cassé dans WeasyPrint

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

---

### Bug 2 — `make` non disponible sur Windows

**Symptôme** : `make build` échoue avec `'make' is not recognized as an internal or external command` sur Windows natif (PowerShell, cmd).

**Cause** : `make` est un outil Unix standard absent de Windows hors WSL ou Chocolatey. Le `Makefile` est maintenu pour Linux/macOS et CI/CD (Ubuntu runner), mais ne peut pas être utilisé directement sur Windows sans outillage supplémentaire.

**Contournement** : appeler les commandes Docker directement depuis PowerShell. Le `Makefile` ne fait que séquencer deux commandes, donc la traduction est triviale :

```powershell
# Équivalent de make build
docker build --platform linux/amd64 -t cv-builder .
docker run --rm `
  -v "${PWD}/content:/cv/content:ro" `
  -v "${PWD}/template:/cv/template:ro" `
  -v "${PWD}/style:/cv/style:ro" `
  -v "${PWD}/build:/cv/build" `
  cv-builder
```

**Alternatives non retenues** : installer `make` via Chocolatey (`choco install make`) ou utiliser WSL. Ces options ajoutent une dépendance supplémentaire pour un cas d'usage simple ; documenter les commandes Docker directes est plus portable.
