export MDBOOK_BIN := "mdbook"
export CURRENT_BRANCH := `git branch --show-current`
export TMP_GH_PAGES_SITE := "/tmp/publishing-site"
export HICKORY_README := "https://raw.githubusercontent.com/hickory-dns/hickory-dns/refs/heads/main/README.md"
export HICKORY_REPO := "https://github.com/hickory-dns/hickory-dns"

# support sed on linux
sed_inplace := if os() == "linux" { "sed -i" } else { "sed -i ''" }

init:
    @echo "====> initializing and checking dependencies"
    rustup --version
    brew --version
    zola --version || brew install zola
    mdbook --version || cargo install -f mdbook
    mdbook-mermaid --version || cargo install -f mdbook-mermaid
    @echo current git branch: ${CURRENT_BRANCH}

clean: clean_worktree
    @echo "====> cleaning build directories"
    rm -rf public
    rm -rf target

get_readme:
    @echo "====> Fetching README.md from ${HICKORY_README}"
    curl --proto '=https' --tlsv1.2 -sSf ${HICKORY_README} -o static/hickory-dns-README.md

zola: clean get_readme
    @echo "====> building zola site"
    zola build

mdbook:
    @echo "====> building mdbook"
    mdbook build docs

build: zola mdbook
    mv docs/book public/book
    # fix up some of the things in the mdbook, css and links...
    rg 'public/mdbook.css' public/book --files-with-matches | xargs {{sed_inplace}} 's|public/mdbook.css|mdbook.css|g'
    rg "<a href=\"http" public/book -t html --files-with-matches | xargs {{sed_inplace}} 's|<a href="http|<a target="_parent" href="http|g'
    # fix up some of the links in main readme to direct to correct url
    {{sed_inplace}} 's#(\(bin\)/)#({{HICKORY_REPO}}/blob/main/\1)#g' static/hickory-dns-README.md
    {{sed_inplace}} 's#(\(crates/[^/]*\)/)#({{HICKORY_REPO}}/blob/main/\1)#g' static/hickory-dns-README.md

serve: build
    @echo "====> serving zola site"
    zola serve

gh-pages:
    @echo "====> checking for gh-pages branch"
    git show-ref --quiet refs/heads/gh-pages || \
        (git switch --orphan gh-pages && \
         git commit --allow-empty -m "Initial gh-pages branch" && \
         git push -u origin gh-pages && \
         git switch ${CURRENT_BRANCH})

clean_worktree:
    @echo "====> cleaning worktree"
    rm -rf ${TMP_GH_PAGES_SITE}
    git worktree prune

deploy: gh-pages clean build
    @echo "====> deploying to github"
    @git --version
    git worktree add ${TMP_GH_PAGES_SITE} gh-pages
    rm -rf ${TMP_GH_PAGES_SITE}/*
    cp -rp public/* ${TMP_GH_PAGES_SITE}/
    ls -l ${TMP_GH_PAGES_SITE}/
    cd ${TMP_GH_PAGES_SITE} && \
        git add -A && \
        git diff --staged --quiet || \
          (git commit -m "deployed on $(shell date) by ${USER}" && \
           git push origin gh-pages)
    @just clean_worktree
