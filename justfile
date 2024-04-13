export MDBOOK_BIN := "mdbook"
export ZOLA_BIN := "zola"
export CURRENT_BRANCH := `git branch --show-current`
export TMP_GH_PAGES_SITE := "/tmp/publishing-site"

init:
    @echo "====> initializing and checking dependencies"
    rustup --version
    brew --version
    # zola --version || brew install zola
    mdbook --version || cargo install -f mdbook
    oranda --version || cargo install -f oranda --locked --profile=dist
    @echo current git branch: ${CURRENT_BRANCH}

clean:
    @echo "====> cleaning build directories"
    rm -rf public

book: init
    @echo "====> building the book"
    ${MDBOOK_BIN} build

zola: init
    @echo "====> building the zola site"
    ${ZOLA_BIN} build
    cp .nojekyll public/.nojekyll

build: book

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
    cd ${TMP_GH_PAGES_SITE} && \
        git add -A && \
        git diff --staged --quiet || \
          (git commit -m "deployed on $(shell date) by ${USER}" && \
           git push origin gh-pages)
    @just clean_worktree