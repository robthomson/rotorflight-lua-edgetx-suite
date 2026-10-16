"""MkDocs hooks for the documentation site built from `docs/`.

`docs/` is written to read on GitHub as it is, and the site is built from the same files
unchanged. Two things GitHub gets right on its own and MkDocs does not are done here:

  * A relative link that leaves `docs/` -- `../GEMINI.md`, `../../bin/themes/README.md`
    -- resolves on GitHub because GitHub serves the whole tree. The site holds `docs/`
    only, so such a link is rewritten to the file on GitHub instead of being left broken.
    The same goes for a page the site leaves out, `_template.md`; that one is not broken
    on the site, only absent from it. A link to a page inside `docs/` that does not exist
    is left as it is, so the strict build reports it rather than pointing it at GitHub.
  * The order of a section follows `sidebar_position` in the front matter, the position
    of the tile on the radio, rather than the alphabetical order of the file names.
    Entries without one keep their alphabetical order after the ones that have it, and a
    section's `README.md` stays first.

Wired in by `hooks:` in `mkdocs.yml`; there is nothing to run by hand.
"""

import posixpath
import re

from mkdocs.structure.nav import Section
from mkdocs.structure.pages import Page

LINK = re.compile(r"(\]\()([^)\s]+)(\))")
POSITION = re.compile(r"^sidebar_position:[ \t]*([0-9]+)[ \t]*$", re.MULTILINE)


def _github_url(config, path, anchor):
    kind = "tree" if path.endswith("/") else "blob"
    return f"{config['repo_url'].rstrip('/')}/{kind}/master/{path}{anchor}"


def on_page_markdown(markdown, page, config, files):
    page_dir = posixpath.dirname(page.file.src_uri)

    def rewrite(match):
        target = match.group(2)
        if re.match(r"^[a-z][a-z0-9+.-]*:", target, re.IGNORECASE) or target.startswith(("#", "/")):
            return match.group(0)
        path, _, anchor = target.partition("#")
        resolved = posixpath.normpath(posixpath.join("docs", page_dir, path))
        if resolved == "docs" or resolved.startswith("docs/"):
            inside = files.get_file_from_path(resolved[len("docs/"):]) if resolved != "docs" else None
            if inside is None or not inside.inclusion.is_excluded():
                return match.group(0)
        if path.endswith("/"):
            resolved += "/"
        return match.group(1) + _github_url(config, resolved, f"#{anchor}" if anchor else "") + match.group(3)

    return LINK.sub(rewrite, markdown)


def _position(item):
    page = item if isinstance(item, Page) else None
    if page is None:
        return None
    try:
        with open(page.file.abs_src_path, encoding="utf-8") as handle:
            head = handle.read(1024)
    except OSError:
        return None
    if not head.startswith("---"):
        return None
    match = POSITION.search(head.split("\n---", 1)[0])
    return int(match.group(1)) if match else None


def _sort(items):
    def key(indexed):
        index, item = indexed
        if isinstance(item, Page) and item.file.name in ("README", "index"):
            return (0, 0, index)
        position = _position(item)
        return (1, position, index) if position is not None else (2, 0, index)

    items[:] = [item for _, item in sorted(enumerate(items), key=key)]
    for item in items:
        if isinstance(item, Section):
            _sort(item.children)


def _pages(items):
    for item in items:
        if isinstance(item, Page):
            yield item
        elif isinstance(item, Section):
            yield from _pages(item.children)


def on_nav(nav, config, files):
    _sort(nav.items)
    # The previous/next links at the foot of a page were set in the unsorted order.
    nav.pages = list(_pages(nav.items))
    for before, after in zip([None] + nav.pages, nav.pages + [None]):
        if before is not None:
            before.next_page = after
        if after is not None:
            after.previous_page = before
    return nav
