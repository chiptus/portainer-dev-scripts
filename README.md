# portainer-dev-scripts

## Install

```bash
git clone https://github.com/chiptus/portainer-dev-scripts.git ~/.portainer
```

Add to your `~/.zshrc`:
(bash should be similar, need to test)

```bash
source $HOME/.portainer/aliases
export PATH="$PATH:$HOME/.portainer"
```

## Update

```bash
cd ~/.portainer
git pull
```

## Usage

Expect CE to be on `~/portainer-org/portainer` and ee to be on `~/portainer-org/portainer-ee`

### 1. run portainer

```bash
ee [$BRANCH] [$DATA_DIR]
# or
ce [$BRANCH] [$DATA_DIR]
```

### 2. create dev branch from release branch

expected to run inside portainer repo when the release branch is checked out

```bash
create-dev-branch-from-release $BASE_BRANCH
```

### 3. create other edition branch

expected to run inside portainer repo when the target branch is checked out, and both editions should have the "other" remote pointed to the other edition repo

````bash
create-other-edition-branch $BASE_BRANCH
```bash
````
