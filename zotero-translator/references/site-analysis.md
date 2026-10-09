# Analyzing a site before writing a translator

Goal: know exactly which DOM facts the translator can rely on, on every page type, before writing a line of code. Server-rendered news sites can be read with curl; anything built by client-side JavaScript must be read from a real browser with the repo's `inspect-page.mjs`.

## 1. Fetch an article and inventory its metadata (curl is fine for static HTML)

```bash
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
curl -sL -A "$UA" -H "Accept-Language: en-US,en;q=0.9" "<article url>" -o article.html -w "HTTP %{http_code} size %{size_download}\n"
```

```bash
python3 - <<'PY'
import re, json
h = open('article.html', encoding='utf-8', errors='replace').read()
print('title:', re.findall(r'<title>(.*?)</title>', h, re.S)[:1])
print('html tag:', re.findall(r'<html[^>]*>', h)[:1])
for m in re.finditer(r'<meta[^>]+>', h):
    t = m.group(0)
    if re.search(r'(og:|twitter:|article:|description|keywords|author|date|published|modified|citation_|DC\.)', t, re.I):
        print(t[:200])
for m in re.finditer(r'<script[^>]*ld\+json[^>]*>(.*?)</script>', h, re.S | re.I):
    try:
        d = json.loads(m.group(1))
        print('JSON-LD:', json.dumps(d, ensure_ascii=False)[:800])
    except Exception as e:
        print('JSON-LD parse error', e)
print('h1:', re.findall(r'<h1[^>]*>.*?</h1>', h, re.S)[:2])
for key in ('author', 'byline', 'date', 'time', 'tag', 'summary', 'lead', 'section', 'breadcrumb'):
    print(key, sorted(set(re.findall(r'class="([^"]*%s[^"]*)"' % key, h, re.I)))[:12])
PY
```

Then print the raw markup around the interesting classes (`h[i-300:i+1500]`) to see exactly how the byline, date, deck, and tags are structured. Fetch two or three article variants (unsigned news, signed opinion, video/show page, press review) and compare: byline containers often exist only on some of them.

If curl returns a challenge page, a tiny HTML shell, or `HTTP 403`, the site is JS-rendered or bot-walled; use `node .bin/inspect-page.mjs "<url>" --meta --selector h1 --selector '.byline'` (add `--headed` for Cloudflare-type walls).

## 2. Map the listing pages in a real browser

Listing, search, tag, and topic pages decide what the Connector's pick-list shows. Curl often sees only a few links because the list is rendered by JavaScript, so use the browser. This evaluation prints each article-like link with its ancestor containers, which reveals hidden menus and feeds:

```bash
node .bin/inspect-page.mjs "https://tass.com/search?searchStr=OpenAI" --eval '(function(){
  var re = /^https?:\/\/(www\.)?tass\.com\/[a-z-]+\/\d{5,}/;   // the article URL regex
  var out = [], seen = {};
  Array.from(document.querySelectorAll("a[href]")).forEach(function(a){
    if (!re.test(a.href)) return;
    var chain = [], el = a.parentElement, depth = 0;
    while (el && depth < 8) { if (el.className && typeof el.className === "string" && el.className.trim()) chain.push(el.tagName.toLowerCase() + "." + el.className.trim().split(/\s+/)[0]); el = el.parentElement; depth++; }
    var key = a.href + "|" + chain.slice(0, 3).join(">"); if (seen[key]) return; seen[key] = 1;
    var t = a.querySelector("[class*=title]");
    out.push({ href: a.href, cls: a.className, title: (t ? t.textContent : a.textContent).replace(/\s+/g, " ").trim().slice(0, 50), chain: chain.join(" > ") });
  });
  return out;
})()'
```

Read the `chain` values: links under `div.menu__content`, `header`, `.news-feed`, `.sidebar`, `.trending` are not the page's own content and must be excluded in `getSearchResults`. Links whose `cls` has no title element and whose text starts with `<img` are `<noscript>` fallbacks.

## 3. Replay the pick-list before trusting it

After writing `getSearchResults`, run the same logic in the browser and look at the result. The test runner only asserts `"multiple"`, so this is the only check of what users will actually see:

```bash
node .bin/inspect-page.mjs "https://www.rt.com/news/" --eval '(function(){
  var re = /^https?:\/\/(?:www\.)?rt\.com\/(?:[a-z-]+\/)+\d{5,}-[^\/?#]+/i;
  function lt(l){ var c = l.cloneNode(true); c.querySelectorAll("noscript").forEach(function(n){ n.remove(); }); return c.textContent.replace(/\s+/g, " ").trim(); }
  var items = {}, order = [];
  document.querySelectorAll("a[href]").forEach(function(row){
    var href = row.href; if (!re.test(href) || items[href]) return;
    if (row.closest(".menu__content, .news-feed, header")) return;      // mirror the translator
    var t = lt(row.querySelector(".card__heading, .list-card__content--title") || row); if (!t) return;
    items[href] = t; order.push(href);
  });
  return { count: order.length, markupTitles: order.filter(function(h){ return /^</.test(items[h]); }).length, first: order.slice(0, 10).map(function(h){ return items[h]; }) };
})()'
```

Expect `markupTitles: 0`, the first entries to be the page's own stories, and a count close to what the page shows.

## 4. Checklist before scaffolding

- Article URL regex matches articles only; listing URLs do not match it.
- Date source chosen (JSON-LD `datePublished` preferred).
- Byline container and format known for each article variant; organization names identified for exclusion.
- Deck/standfirst, section source, tag selector identified.
- Extra page types decided (video → `tvBroadcast`, podcasts, galleries) or explicitly left to `newspaperArticle`.
- Other editions/subdomains checked once; usually a different template, so leave them out of `target`.
- Listing containers to exclude listed from the ancestry dump.
